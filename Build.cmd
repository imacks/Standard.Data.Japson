@echo off
rem Starts the build process from console.
rem Example run from cmd.exe:
rem build release

if '%1'=='/?' goto help
if '%1'=='/help' goto help
if '%1'=='-h' goto help
if '%1'=='--help' goto help

if '%1'=='' goto defaultbuild
if '%2'=='' goto configbuild

set CONFIGVAR=%1
shift
set RESTVAR=%1
shift
:loop1
if "%1"=="" goto after_loop
set RESTVAR=%RESTVAR% %1
shift
goto loop1

:after_loop
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\Tools\PowerBuild\PowerBuild.ps1' '%~dp0\Tools\BuildScript\booter.ps1' -properties @{ Configuration = '%CONFIGVAR%'; BuildTarget = ('%RESTVAR%'.Split(' ') | where { $_ -ne '' } | ForEach-Object { $_.Trim() }) }; if ($PowerBuild.BuildSuccess -eq $false) { exit 1 } else { exit 0 }"
exit /B %errorlevel%

:configbuild
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\Tools\PowerBuild\PowerBuild.ps1' '%~dp0\Tools\BuildScript\booter.ps1' -properties @{ Configuration = '%1' }; if ($PowerBuild.BuildSuccess -eq $false) { exit 1 } else { exit 0 }"
exit /B %errorlevel%

:defaultbuild
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\Tools\PowerBuild\PowerBuild.ps1' '%~dp0\Tools\BuildScript\booter.ps1'; if ($PowerBuild.BuildSuccess -eq $false) { exit 1 } else { exit 0 }"
exit /B %errorlevel%

:help
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0\Tools\PowerBuild\PowerBuild.ps1' '%~dp0\Tools\BuildScript\booter.ps1' -properties @{ help = $true }"
