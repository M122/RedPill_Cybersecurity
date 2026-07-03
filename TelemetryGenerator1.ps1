# Commands to execute
$script = @'
whoami
hostname
ipconfig
net user
tasklist
systeminfo
Get-Process
Get-Service
Get-ChildItem C:\Users

New-Item -ItemType File -Path C:\Users\Public\Downloads\FakeMalz.txt -Force
Remove-Item C:\Users\Public\Downloads\FakeMalz.txt -Force

ping google.com
nslookup github.com
curl https://example.com
'@

# Save a copy for reference (optional)
$tempScript = "$env:TEMP\ElasticLabCommands.ps1"
$script | Set-Content -Path $tempScript -Encoding UTF8

# Convert to PowerShell's expected Base64 format (UTF-16LE)
$bytes = [System.Text.Encoding]::Unicode.GetBytes($script)
$encoded = [Convert]::ToBase64String($bytes)

Write-Host "=================================================="
Write-Host "Base64 Encoded Command:"
Write-Host "=================================================="
Write-Host $encoded
Write-Host ""

Write-Host "Executing encoded command..."
Write-Host ""

# Execute the encoded command
powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded

# Cleanup
Remove-Item $tempScript -ErrorAction SilentlyContinue