<#
-------------------------------------------------------------------
Defaults
-------------------------------------------------------------------
$config.BuildFileName = "default.ps1"
$config.Framework = "4.0"
$config.TaskNameFormat = "Executing {0}"
$config.VerboseError = $false
$config.ColoredOutput = $true
$config.Modules = $null

-------------------------------------------------------------------
Load modules from .\modules folder and from file my_module.psm1
-------------------------------------------------------------------
$config.Modules = (".\modules\*.psm1",".\my_module.psm1")

-------------------------------------------------------------------
Use scriptblock for taskNameFormat
-------------------------------------------------------------------
$config.TaskNameFormat = { param($taskName) "Executing $taskName at $(get-date)" }
#>
