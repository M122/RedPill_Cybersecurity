schtasks /Delete /TN "FSociety Daily Update" /F
sc.exe stop FSocietyUpdaterSvc
sc.exe delete FSocietyUpdaterSvc
Remove-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "FSocietyUpdater" -ErrorAction SilentlyContinue
Remove-Item "C:\Users\Public\Documents\fsociety-lab" -Recurse -Force