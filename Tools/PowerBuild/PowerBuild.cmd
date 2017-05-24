@echo off
rem Helper script for those who want to run PowerBuild from cmd.exe
rem Example run from cmd.exe:
rem powerbuild "default.ps1" "BuildHelloWord" "4.0" 

if '%1'=='/?' goto help
if '%1'=='-help' goto help
if '%1'=='-h' goto help

powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\PowerBuild.ps1' %*; If ($PowerBuild.BuildSuccess -eq $false) { Exit 1 } Else { Exit 0 }"
exit /B %errorlevel%

:help
powershell -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\PowerBuild.ps1' -help"
