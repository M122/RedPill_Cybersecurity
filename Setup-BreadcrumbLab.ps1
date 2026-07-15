#requires -version 5.1
<#
Creates a harmless Windows/Sysmon process-chain lab.

Expected lineage after the student double-clicks the lure:
explorer.exe
  -> cmd.exe (Q3_Bonus_Review.cmd)
     -> powershell.exe (stage1.ps1)
        -> cmd.exe (stage2.cmd)
           -> powershell.exe (stage3.ps1)
              -> cmd.exe /c whoami
              -> nslookup.exe example.com
              -> ping.exe 127.0.0.1
              -> certutil.exe -hashfile ...
              -> powershell.exe (stage4.ps1)
                 -> cmd.exe /c tasklist
                 -> cmd.exe /c net user
                 -> cmd.exe /c del ...

The activity is benign and uses localhost/example.com.
#>

[CmdletBinding()]
param(
    [string]$LabPath = "C:\WazuhBreadcrumbLab"
)

$ErrorActionPreference = "Stop"

New-Item -Path $LabPath -ItemType Directory -Force | Out-Null
New-Item -Path "$LabPath\evidence" -ItemType Directory -Force | Out-Null

$stage1 = @'
$ErrorActionPreference = "Continue"
$lab = "C:\WazuhBreadcrumbLab"
"Stage 1 started: $(Get-Date -Format o)" | Out-File "$lab\evidence\stage1.txt"
"User: $env:USERNAME`r`nComputer: $env:COMPUTERNAME" | Out-File "$lab\evidence\host_context.txt"

# Preserve a visible parent-child relationship.
Start-Process -FilePath "$env:ComSpec" `
    -ArgumentList '/d','/c',"`"$lab\stage2.cmd`"" `
    -Wait -WindowStyle Hidden
'@

$stage2 = @'
@echo off
echo Stage 2 started: %DATE% %TIME% > C:\WazuhBreadcrumbLab\evidence\stage2.txt
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\WazuhBreadcrumbLab\stage3.ps1
exit /b
'@

$stage3 = @'
$ErrorActionPreference = "Continue"
$lab = "C:\WazuhBreadcrumbLab"

"Stage 3 started: $(Get-Date -Format o)" | Out-File "$lab\evidence\stage3.txt"
"This is harmless lab data." | Out-File "$lab\evidence\quarterly_notes.txt"

Start-Process -FilePath "$env:ComSpec" -ArgumentList '/d','/c',"whoami /all > `"$lab\evidence\whoami.txt`"" -Wait -WindowStyle Hidden
Start-Process -FilePath "nslookup.exe" -ArgumentList "example.com" -Wait -WindowStyle Hidden
Start-Process -FilePath "ping.exe" -ArgumentList "-n","2","127.0.0.1" -Wait -WindowStyle Hidden
Start-Process -FilePath "certutil.exe" -ArgumentList "-hashfile","$lab\evidence\quarterly_notes.txt","SHA256" -Wait -WindowStyle Hidden

Start-Process -FilePath "powershell.exe" `
    -ArgumentList '-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',"$lab\stage4.ps1" `
    -Wait -WindowStyle Hidden
'@

$stage4 = @'
$ErrorActionPreference = "Continue"
$lab = "C:\WazuhBreadcrumbLab"
"Stage 4 started: $(Get-Date -Format o)" | Out-File "$lab\evidence\stage4.txt"

Start-Process -FilePath "$env:ComSpec" -ArgumentList '/d','/c',"tasklist > `"$lab\evidence\processes.txt`"" -Wait -WindowStyle Hidden
Start-Process -FilePath "$env:ComSpec" -ArgumentList '/d','/c',"net user > `"$lab\evidence\local_users.txt`"" -Wait -WindowStyle Hidden

"Temporary breadcrumb" | Out-File "$env:TEMP\wazuh-breadcrumb.tmp"
Start-Sleep -Seconds 2
Start-Process -FilePath "$env:ComSpec" -ArgumentList '/d','/c',"del /q `"$env:TEMP\wazuh-breadcrumb.tmp`"" -Wait -WindowStyle Hidden

"Lab completed: $(Get-Date -Format o)" | Out-File "$lab\evidence\completed.txt"
'@

$lure = @'
@echo off
title Quarterly Bonus Review
echo Preparing quarterly review...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File C:\WazuhBreadcrumbLab\stage1.ps1
echo.
echo The document could not be displayed.
timeout /t 2 /nobreak >nul
exit /b
'@

Set-Content -Path "$LabPath\stage1.ps1" -Value $stage1 -Encoding UTF8
Set-Content -Path "$LabPath\stage2.cmd" -Value $stage2 -Encoding ASCII
Set-Content -Path "$LabPath\stage3.ps1" -Value $stage3 -Encoding UTF8
Set-Content -Path "$LabPath\stage4.ps1" -Value $stage4 -Encoding UTF8
Set-Content -Path "$LabPath\Q3_Bonus_Review.cmd" -Value $lure -Encoding ASCII

Write-Host ""
Write-Host "Wazuh breadcrumb lab created at $LabPath" -ForegroundColor Green
Write-Host "Have the student double-click:" -ForegroundColor Yellow
Write-Host "  $LabPath\Q3_Bonus_Review.cmd"
Write-Host ""
Write-Host "For the clearest root-cause process, launch it from File Explorer."
