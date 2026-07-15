#requires -version 5.1
[CmdletBinding()]
param(
    [string]$LabPath = "C:\Users\Public\Downloads\WazuhBreadcrumbLab"
)

$ErrorActionPreference = "SilentlyContinue"

Remove-Item "$env:TEMP\wazuh-breadcrumb.tmp" -Force
Remove-Item $LabPath -Recurse -Force

Write-Host "Wazuh breadcrumb lab artifacts removed." -ForegroundColor Green
