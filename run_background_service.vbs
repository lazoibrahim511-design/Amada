Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "attendance_app.exe" & chr(34) & " --silent", 0
Set WshShell = Nothing
