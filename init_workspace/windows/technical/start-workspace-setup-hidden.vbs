Option Explicit

Dim shell
Dim fso
Dim scriptDir
Dim scriptPath
Dim command
Dim index

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(scriptDir, "start-workspace-setup.ps1")

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & QuoteArgument(scriptPath)

For index = 0 To WScript.Arguments.Count - 1
    command = command & " " & QuoteArgument(WScript.Arguments(index))
Next

WScript.Quit shell.Run(command, 0, False)

Function QuoteArgument(ByVal value)
    QuoteArgument = """" & Replace(value, """", "\""") & """"
End Function
