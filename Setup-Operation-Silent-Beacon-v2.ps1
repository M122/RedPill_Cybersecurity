#requires -version 5.1
[CmdletBinding()]
param(
    [string]$LabPath = "C:\Public\Downloads\SilentBeacon",
    [ValidateRange(1,30)][int]$StageDelaySeconds = 4
)

$ErrorActionPreference = "Stop"

function Save-File {
    param([string]$Path,[string]$Content,[string]$Encoding="UTF8")
    $folder = Split-Path -Parent $Path
    if (-not (Test-Path $folder)) { New-Item $folder -ItemType Directory -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Content -Encoding $Encoding -Force
}

New-Item "$LabPath\cache","$LabPath\working","$LabPath\reports" -ItemType Directory -Force | Out-Null

$stage1 = @'
param([ValidateRange(1,30)][int]$Delay = 4)
$lab = "C:\Public\Downloads\SilentBeacon"
@"
Computer: $env:COMPUTERNAME
User: $env:USERNAME
Started: $(Get-Date -Format o)
"@ | Out-File "$lab\reports\session_context.txt"
Start-Sleep $Delay
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"`"$lab\cache\TelemetryCache.cmd`" $Delay" -Wait -WindowStyle Hidden
'@

$stage2 = @'
@echo off
setlocal
set "DELAY=%~1"
if not defined DELAY set "DELAY=4"
echo Stage 2 started: %DATE% %TIME% > "C:\Public\Downloads\SilentBeacon\reports\stage2_marker.txt"
timeout /t %DELAY% /nobreak >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\Public\Downloads\SilentBeacon\cache\SystemHealth.ps1" -Delay %DELAY%
endlocal
exit /b
'@

$stage3 = @'
param([ValidateRange(1,30)][int]$Delay = 4)
$lab = "C:\Public\Downloads\SilentBeacon"
"Collection started: $(Get-Date -Format o)" | Out-File "$lab\reports\collection_started.txt"

Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"whoami /all > `"$lab\working\identity.txt`"" -Wait -WindowStyle Hidden
Start-Sleep $Delay
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"hostname > `"$lab\working\hostname.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"systeminfo > `"$lab\working\system_profile.txt`"" -Wait -WindowStyle Hidden
Start-Sleep $Delay
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"tasklist /v > `"$lab\working\running_processes.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"net user > `"$lab\working\local_accounts.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"sc.exe query state^= all > `"$lab\working\services.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"schtasks.exe /query /fo LIST > `"$lab\working\scheduled_tasks.txt`"" -Wait -WindowStyle Hidden
Start-Sleep $Delay
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"ipconfig /all > `"$lab\working\network_config.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"route print > `"$lab\working\routes.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"arp -a > `"$lab\working\arp_cache.txt`"" -Wait -WindowStyle Hidden
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"netstat -ano > `"$lab\working\network_connections.txt`"" -Wait -WindowStyle Hidden
Start-Sleep $Delay
Start-Process "nslookup.exe" -ArgumentList "example.com" -Wait -WindowStyle Hidden
Start-Process "ping.exe" -ArgumentList "-n","3","127.0.0.1" -Wait -WindowStyle Hidden
Start-Process "reg.exe" -ArgumentList "query","HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion","/v","ProductName" -RedirectStandardOutput "$lab\working\os_registry.txt" -Wait -WindowStyle Hidden

@"
Quarterly workstation review
Generated: $(Get-Date -Format o)
Classification: Internal Training Data
"@ | Out-File "$lab\working\Quarterly_Workstation_Review.txt"

Get-Service | Select-Object -First 40 Name,Status,StartType | Export-Csv "$lab\working\service_sample.csv" -NoTypeInformation
Get-ChildItem "$env:WINDIR\System32" -File | Select-Object -First 25 Name,Length,LastWriteTime | Export-Csv "$lab\working\system32_sample.csv" -NoTypeInformation

Start-Process "powershell.exe" -ArgumentList '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"$lab\cache\PackageReports.ps1",'-Delay',"$Delay" -Wait -WindowStyle Hidden
'@

$stage4 = @'
param([ValidateRange(1,30)][int]$Delay = 4)
$lab = "C:\Public\Downloads\SilentBeacon"
"Packaging started: $(Get-Date -Format o)" | Out-File "$lab\reports\packaging_started.txt"

Start-Process "certutil.exe" -ArgumentList "-hashfile","$lab\working\Quarterly_Workstation_Review.txt","SHA256" -RedirectStandardOutput "$lab\working\review_hash.txt" -Wait -WindowStyle Hidden
Start-Sleep $Delay

[pscustomobject]@{
    ComputerName=$env:COMPUTERNAME
    UserName=$env:USERNAME
    CollectedAt=(Get-Date -Format o)
    ReportCount=(Get-ChildItem "$lab\working" -File).Count
} | Export-Csv "$lab\working\collection_summary.csv" -NoTypeInformation

Get-ChildItem "$lab\working" -File | Select-Object Name,Length,LastWriteTime | Export-Csv "$lab\working\evidence_manifest.csv" -NoTypeInformation

$zip="$lab\reports\Workstation_Health_Package.zip"
if(Test-Path $zip){Remove-Item $zip -Force}
Compress-Archive "$lab\working\*" $zip -Force
Start-Sleep $Delay
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"`"$lab\cache\FinalizeUpdate.cmd`" $Delay" -Wait -WindowStyle Hidden
'@

$stage5 = @'
@echo off
setlocal
set "DELAY=%~1"
if not defined DELAY set "DELAY=4"
echo Finalization started: %DATE% %TIME% > "C:\Public\Downloads\SilentBeacon\reports\finalization_started.txt"
timeout /t %DELAY% /nobreak >nul
copy /y "C:\Public\Downloads\SilentBeacon\working\collection_summary.csv" "C:\Public\Downloads\SilentBeacon\reports\System_Update_Status.csv" >nul
echo Temporary package marker > "%TEMP%\silent-beacon-cache.tmp"
timeout /t 2 /nobreak >nul
del /q "%TEMP%\silent-beacon-cache.tmp"
echo Completed: %DATE% %TIME% > "C:\Public\Downloads\SilentBeacon\reports\completed.txt"
endlocal
exit /b
'@

$launcher = @'
@echo off
setlocal
title Microsoft Office Compatibility Update
set "DELAY=%~1"
if not defined DELAY set "DELAY=4"
echo Checking document compatibility...
echo Please wait while the update verifies local Office components.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\Public\Downloads\SilentBeacon\cache\CompatibilityCheck.ps1" -Delay %DELAY%
set "RESULT=%ERRORLEVEL%"
echo.
if "%RESULT%"=="0" (echo Compatibility check completed.) else (echo Compatibility check returned error code %RESULT%.)
timeout /t 2 /nobreak >nul
endlocal
exit /b %RESULT%
'@

Save-File "$LabPath\cache\CompatibilityCheck.ps1" $stage1
Save-File "$LabPath\cache\TelemetryCache.cmd" $stage2 ASCII
Save-File "$LabPath\cache\SystemHealth.ps1" $stage3
Save-File "$LabPath\cache\PackageReports.ps1" $stage4
Save-File "$LabPath\cache\FinalizeUpdate.cmd" $stage5 ASCII
Save-File "$LabPath\Office_Compatibility_Update.cmd" $launcher ASCII

@"
Operation Silent Beacon v2.0
Default delay: $StageDelaySeconds seconds

Open $LabPath in File Explorer and double-click:
Office_Compatibility_Update.cmd

The launcher now works when double-clicked without an argument.
"@ | Set-Content "$LabPath\README.txt"

Write-Host "Operation Silent Beacon v2.0 prepared at $LabPath" -ForegroundColor Green
Write-Host "Double-click Office_Compatibility_Update.cmd to begin." -ForegroundColor Yellow
