#requires -version 5.1
[CmdletBinding()]
param([string]$LabPath = "C:\Public\Downloads\SilentBeacon")
$ErrorActionPreference = "SilentlyContinue"
Remove-Item "$env:TEMP\silent-beacon-cache.tmp" -Force
Remove-Item $LabPath -Recurse -Force
Write-Host "Operation Silent Beacon artifacts removed. Wazuh/Sysmon history remains available." -ForegroundColor Green
