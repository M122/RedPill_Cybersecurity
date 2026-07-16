#requires -version 5.1
param([string]$LabPath="C:\Public\Downloads\SilentBeacon")
$ErrorActionPreference="SilentlyContinue"
Remove-Item "$env:TEMP\silent-beacon-cache.tmp" -Force
Remove-Item $LabPath -Recurse -Force
Write-Host "Operation Silent Beacon v2.0 artifacts removed." -ForegroundColor Green
