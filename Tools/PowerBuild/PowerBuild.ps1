# Helper script for those who want to run PowerBuild without importing the module.
# Example run from PowerShell:
# .\powerbuild.ps1 "default.ps1" "BuildHelloWord" "4.0" 

# Must match parameter definitions for PowerBuild.psm1/Invoke-PowerBuild 
# otherwise named parameter binding fails
[CmdletBinding()]
Param(
    [Parameter(Position = 1, Mandatory = $false)]
    [String]$BuildFile,

    [Parameter(Mandatory = $false)]
    [String[]]$TaskList = @(),

    [Parameter(Mandatory = $false)]
    [String]$Framework,

    [Parameter(Mandatory = $false)]
    [Switch]$Docs = $false,

    [Parameter(Mandatory = $false)]
    [Hashtable]$Parameters = @{},

    [Parameter(Mandatory = $false)]
    [Hashtable]$Properties = @{},

    [Parameter(Mandatory = $false)]
    [Alias("Init")]
    [ScriptBlock]$Initialization = {},

    [Parameter(Mandatory = $false)]
    [Switch]$NoLogo = $false,

    [Parameter(Mandatory = $false)]
    [Switch]$Help = $false,

    [Parameter(Mandatory = $false)]
    [String]$ScriptPath,

    [Parameter(Mandatory = $false)]
    [Switch]$DetailDocs = $false
)

# setting $scriptPath here, not as default argument, to support calling as "powershell -File PowerBuild.ps1"
If (-not $ScriptPath) 
{
    $ScriptPath = $(Split-Path -Parent $MyInvocation.MyCommand.Path)
}

# '[P]owerBuild' is the same as 'powerbuild' but $Error is not polluted
Remove-Module [P]owerBuild
Import-Module (Join-Path $scriptPath PowerBuild.psm1)
If ($Help) 
{
    Get-Help Invoke-PowerBuild -Full
    Return
}

If ($BuildFile -and (-not(Test-Path $BuildFile))) 
{
    $absBuildFile = (Join-Path $ScriptPath $BuildFile)
    If (Test-Path $absBuildFile) 
    {
        $BuildFile = $absBuildFile
    }
} 

$buildParams = @{
    'BuildFile' = $BuildFile
    'TaskList' = $TaskList
    'Framework' = $Framework
    'Docs' = $Docs
    'Parameters' = $Parameters
    'Properties' = $Properties
    'Initialization' = $Initialization
    'NoLogo' = $NoLogo
    'DetailDocs' = $DetailDocs
}
Invoke-PowerBuild @buildParams
