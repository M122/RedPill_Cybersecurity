#requires -version 5.1
[CmdletBinding()]
param(
    [string]$LabPath = "C:\Public\Downloads\SilentBeacon",
    [int]$StageDelaySeconds = 4
)
$ErrorActionPreference = "Stop"
function Write-LabFile {
    param([string]$Path,[string]$Content,[string]$Encoding="UTF8")
    Set-Content -LiteralPath $Path -Value $Content -Encoding $Encoding -Force
}
New-Item -Path $LabPath -ItemType Directory -Force | Out-Null
New-Item -Path "$LabPath\cache","$LabPath\reports","$LabPath\working" -ItemType Directory -Force | Out-Null
$stage1 = @'
param([int]$Delay = 4)
$ErrorActionPreference = "Continue"
$lab = "C:\Public\Downloads\SilentBeacon"
"Run ID: $([guid]::NewGuid())`r`nStarted: $(Get-Date -Format o)" | Out-File "$lab\reports\session_context.txt"
Start-Sleep -Seconds $Delay
Start-Process -FilePath "$env:ComSpec" -ArgumentList '/d','/c',"`"$lab\cache\TelemetryCache.cmd`" $Delay" -Wait -WindowStyle Hidden
'@
$stage2 = @'
@echo off
set DELAY=%1
if "%DELAY%"=="" set DELAY=4
echo Stage 2 started: %DATE% %TIME% > C:\Public\Downloads\SilentBeacon\reports\stage2_marker.txt
timeout /t %DELAY% /nobreak >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\Public\Downloads\SilentBeacon\cache\SystemHealth.ps1 -Delay %DELAY%
exit /b
'@
$stage3 = @'
param([int]$Delay = 4)
$ErrorActionPreference = "Continue"
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
Start-Process nslookup.exe -ArgumentList 'example.com' -Wait -WindowStyle Hidden
Start-Process ping.exe -ArgumentList '-n','3','127.0.0.1' -Wait -WindowStyle Hidden
Start-Process reg.exe -ArgumentList 'query','HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion','/v','ProductName' -RedirectStandardOutput "$lab\working\os_registry.txt" -Wait -WindowStyle Hidden
Start-Sleep $Delay
"Quarterly workstation review`r`nGenerated: $(Get-Date -Format o)`r`nTraining data only" | Out-File "$lab\working\Quarterly_Workstation_Review.txt"
Start-Process powershell.exe -ArgumentList '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"$lab\cache\PackageReports.ps1",'-Delay',"$Delay" -Wait -WindowStyle Hidden
'@
$stage4 = @'
param([int]$Delay = 4)
$ErrorActionPreference = "Continue"
$lab = "C:\Public\Downloads\SilentBeacon"
"Packaging started: $(Get-Date -Format o)" | Out-File "$lab\reports\packaging_started.txt"
Start-Process certutil.exe -ArgumentList '-hashfile',"$lab\working\Quarterly_Workstation_Review.txt",'SHA256' -RedirectStandardOutput "$lab\working\review_hash.txt" -Wait -WindowStyle Hidden
Start-Sleep $Delay
[pscustomobject]@{ComputerName=$env:COMPUTERNAME;UserName=$env:USERNAME;CollectedAt=(Get-Date -Format o);ReportCount=(Get-ChildItem "$lab\working" -File).Count} | Export-Csv "$lab\working\collection_summary.csv" -NoTypeInformation
$zip="$lab\reports\Workstation_Health_Package.zip"
if(Test-Path $zip){Remove-Item $zip -Force}
Compress-Archive -Path "$lab\working\*" -DestinationPath $zip -Force
Start-Sleep $Delay
Start-Process "$env:ComSpec" -ArgumentList '/d','/c',"`"$lab\cache\FinalizeUpdate.cmd`" $Delay" -Wait -WindowStyle Hidden
'@
$stage5 = @'
@echo off
set DELAY=%1
if "%DELAY%"=="" set DELAY=4
echo Finalization started: %DATE% %TIME% > C:\Public\Downloads\SilentBeacon\reports\finalization_started.txt
timeout /t %DELAY% /nobreak >nul
copy /y C:\Public\Downloads\SilentBeacon\working\collection_summary.csv C:\Public\Downloads\SilentBeacon\reports\System_Update_Status.csv >nul
echo Temporary package marker > %TEMP%\silent-beacon-cache.tmp
timeout /t 2 /nobreak >nul
del /q %TEMP%\silent-beacon-cache.tmp
echo Completed: %DATE% %TIME% > C:\Public\Downloads\SilentBeacon\reports\completed.txt
exit /b
'@
$lure = @'
@echo off
title Microsoft Office Compatibility Update
echo Checking document compatibility...
echo Please wait while the update verifies local Office components.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\Public\Downloads\SilentBeacon\cache\CompatibilityCheck.ps1 -Delay %1
echo.
echo Compatibility check completed.
timeout /t 2 /nobreak >nul
exit /b
'@
Write-LabFile "$LabPath\cache\CompatibilityCheck.ps1" $stage1
Write-LabFile "$LabPath\cache\TelemetryCache.cmd" $stage2 ASCII
Write-LabFile "$LabPath\cache\SystemHealth.ps1" $stage3
Write-LabFile "$LabPath\cache\PackageReports.ps1" $stage4
Write-LabFile "$LabPath\cache\FinalizeUpdate.cmd" $stage5 ASCII
Write-LabFile "$LabPath\Office_Compatibility_Update.cmd" $lure ASCII
Write-LabFile "$LabPath\README.txt" "Harmless Wazuh training scenario. No persistence, credential access, exploitation, or downloads."
Write-Host "Operation Silent Beacon prepared at $LabPath" -ForegroundColor Green
Write-Host "Open the folder in File Explorer and double-click Office_Compatibility_Update.cmd" -ForegroundColor Yellow
