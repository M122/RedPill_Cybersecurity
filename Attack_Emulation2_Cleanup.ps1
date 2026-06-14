param(
    [string]$BasePath="$env:PUBLIC\Documents\fsociety"
)

$RunKeyName="fsociety_update"
$ServiceName="EvilCorpUpdater"
$TaskName="fsociety_stage2_task"

Remove-ItemProperty `
-Path"HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" `
-Name$RunKeyName `
-Force `
-ErrorActionSilentlyContinue

schtasks.exe/Delete/TN$TaskName/F2>$null

sc.exestop$ServiceName2>$null
sc.exedelete$ServiceName2>$null

Get-Processnotepad,calc,mspaint,powershell-ErrorActionSilentlyContinue|
Where-Object {$_.Path-like"*fsociety*"-or$_.ProcessName-eq"powershell" }|
Stop-Process-Force-ErrorActionSilentlyContinue

Remove-Item$BasePath-Recurse-Force-ErrorActionSilentlyContinue

Write-Host"[+] Mr. Robot artifact cleanup complete."