#Requires -Version 2.0

#######################################################################
#  Data
#######################################################################

if (Test-Path (Join-Path $PSScriptRoot -ChildPath 'en-US/Message.psd1') -PathType Leaf)
{
    Invoke-Expression (@(
        'DATA PBLocalizedData {'
        Get-Content (Join-Path $PSScriptRoot -ChildPath 'en-US/Message.psd1')
        '}'
    ) -join [Environment]::NewLine)
}
else
{
    $PSCmdlet.ThrowTerminatingError((
        New-Object 'System.Management.Automation.ErrorRecord' -ArgumentList ('ERR_FILE_NOT_FOUND::{0}' -f (Join-Path $PSScriptRoot -ChildPath 'en-US/Message.psd1')), 'DefaultLocalizationFileNotFound', 'ObjectNotFound', $null
    ))
}

Import-LocalizedData -BindingVariable PBLocalizedData -BaseDirectory $PSScriptRoot -FileName 'Message.psd1' -ErrorAction $(
    if ($PSVersionTable.PSVersion.Major -ge 3) { 'Ignore' } 
    else { 'SilentlyContinue' }
)


#######################################################################
#  Public Module Functions
#######################################################################

# .ExternalHelp  PowerBuild-Help.xml
function Exec
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [Alias('cmd')]
        [scriptblock]$Command,

        [Parameter(Mandatory = $false)]
        [Alias('errmsg')]
        [string]$ErrorMessage = ($PBLocalizedData.Err_BadCommand -f $Command),

        [Parameter(Mandatory = $false)]
        [Alias('r')]
        [int]$MaxRetries = 0,

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, [Int]::MaxValue)]
        [Alias('rd')]
        [int]$RetryDelay = 1,
        
        [Parameter(Mandatory = $false)]
        [Alias('errpattn')]
        [string]$RetryTriggerErrorPattern = $null
    )

    $tryCount = 1

    do 
    {
        try 
        {
            $global:LASTEXITCODE = 0
            & $Command

            if ($LASTEXITCODE -ne 0) 
            {
                Die $ErrorMessage 'ExecError'
            }

            break
        }
        catch [Exception]
        {
            if ($tryCount -gt $MaxRetries) 
            {
                Die $_ 'ExecError'
            }

            if ($RetryTriggerErrorPattern -ne $null) 
            {
                $isMatch = [RegEx]::IsMatch($_.Exception.Message, $RetryTriggerErrorPattern)

                if ($isMatch -eq $false) 
                { 
                    Die $_ 'ExecError' 
                }
            }

            Write-Output ("[Exec] " + ($PBLocalizedData.RetryMessage -f $tryCount, $MaxRetries, $RetryDelay))

            $tryCount++
            Start-Sleep -Seconds $RetryDelay
        }
    } while ($true)
}

# .ExternalHelp  PowerBuild-Help.xml
function Assert
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        $Condition,

        [Parameter(Position = 2, Mandatory = $true)]
        [Alias('msg')]
        $FailMessage
    )

    if (-not $Condition) 
    {
        Die $FailMessage 'AssertConditionFailure'
    }
}

# .ExternalHelp  PowerBuild-Help.xml
function Properties 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    $PowerBuild.Context.Peek().Properties += $ScriptBlock
}

# .ExternalHelp  PowerBuild-Help.xml
function FormatTaskName 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        $Format
    )
    $PowerBuild.Context.Peek().Config.TaskNameFormat = $Format
}

# .ExternalHelp  PowerBuild-Help.xml
function Include 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$FilePath
    )

    Assert (Test-Path $FilePath -PathType Leaf) -FailMessage ($PBLocalizedData.Err_InvalidIncludePath -f $FilePath)
    $PowerBuild.Context.Peek().Includes.Enqueue((Resolve-Path $FilePath))
}

# .ExternalHelp  PowerBuild-Help.xml
function TaskSetup 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    $PowerBuild.Context.Peek().TaskSetupScriptBlock = $ScriptBlock
}

# .ExternalHelp  PowerBuild-Help.xml
Function TaskTearDown 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [scriptblock]$ScriptBlock
    )

    $PowerBuild.Context.Peek().TaskTearDownScriptBlock = $ScriptBlock
}

# .ExternalHelp  PowerBuild-Help.xml
function Framework 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Name
    )

    $PowerBuild.Context.Peek().Config.Framework = $Name
    ConfigureBuildEnvironment
}

# .ExternalHelp  PowerBuild-Help.xml
function Invoke-Task
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$TaskName
    )

    Assert $TaskName ($PBLocalizedData.Err_InvalidTaskName)

    $taskKey = $TaskName.ToLower()

    if ($CurrentContext.Aliases.Contains($taskKey)) 
    {
        $TaskName = $CurrentContext.Aliases."$taskKey".Name
        $taskKey = $taskName.ToLower()
    }

    $CurrentContext = $PowerBuild.Context.Peek()

    Assert ($CurrentContext.Tasks.Contains($taskKey)) -FailMessage ($PBLocalizedData.Err_TaskNameDoesNotExist -f $TaskName)

    if ($CurrentContext.ExecutedTasks.Contains($taskKey)) 
    { 
        return 
    }

    Assert (-not $CurrentContext.CallStack.Contains($taskKey)) -FailMessage ($PBLocalizedData.Err_CircularReference -f $TaskName)

    $CurrentContext.CallStack.Push($taskKey)

    $task = $CurrentContext.Tasks.$taskKey

    $preconditionIsValid = & $task.Precondition

    if (-not $preconditionIsValid) 
    {
        WriteColoredOutput ($PBLocalizedData.PreconditionWasFalse -f $TaskName) -ForegroundColor Cyan
    } 
    else 
    {
        if ($taskKey -ne 'default') 
        {
            if ($task.PreAction -or $task.PostAction) 
            {
                Assert ($task.Action -ne $null) -FailMessage ($PBLocalizedData.Err_MissingActionParameter -f $TaskName)
            }

            if ($task.Action) 
            {
                try 
                {
                    foreach ($childTask in $task.DependsOn) 
                    {
                        Invoke-Task $childTask
                    }

                    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                    $CurrentContext.CurrentTaskName = $TaskName

                    & $CurrentContext.TaskSetupScriptBlock

                    if ($task.PreAction) 
                    {
                        & $task.PreAction
                    }

                    if ($CurrentContext.Config.TaskNameFormat -is [scriptblock]) 
                    {
                        & $currentContext.Config.TaskNameFormat $TaskName
                    } 
                    else 
                    {
                        WriteColoredOutput ($CurrentContext.Config.TaskNameFormat -f $TaskName) -ForegroundColor Cyan
                    }

                    foreach ($reqVar in $task.RequiredVariables) 
                    {
                        Assert ((Test-Path "Variable:$reqVar") -and ((Get-Variable $reqVar).Value -ne $null)) -FailMessage ($PBLocalizedData.RequiredVarNotSet -f $reqVar, $TaskName)
                    }

                    & $task.Action

                    if ($task.PostAction) 
                    {
                        & $task.PostAction
                    }

                    & $CurrentContext.TaskTearDownScriptBlock
                    $task.Duration = $stopwatch.Elapsed
                } 
                catch 
                {
                    if ($task.ContinueOnError) 
                    {
                        Write-Output $PBLocalizedData.Divider
                        WriteColoredOutput ($PBLocalizedData.ContinueOnError -f $TaskName, $_) -ForegroundColor Yellow
                        Write-Output $PBLocalizedData.Divider
                        $task.Duration = $stopwatch.Elapsed
                    }  
                    else 
                    {
                        Die $_ 'InvokeTaskError'
                    }
                }
            } 
            else 
            {
                # no action was specified but we still execute all the dependencies
                foreach ($childTask in $task.DependsOn) 
                {
                    Invoke-Task $childTask
                }
            }
        } 
        else 
        {
            foreach ($childTask in $task.DependsOn) 
            {
                Invoke-Task $childTask
            }
        }

        Assert (& $task.PostCondition) -FailMessage ($PBLocalizedData.PostconditionFailed -f $TaskName)
    }

    $poppedTaskKey = $CurrentContext.CallStack.Pop()
    Assert ($poppedTaskKey -eq $taskKey) -FailMessage ($PBLocalizedData.Err_CorruptCallStack -f $taskKey, $poppedTaskKey)

    $CurrentContext.ExecutedTasks.Push($taskKey)
}

# .ExternalHelp  PowerBuild-Help.xml
function Task
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Name,

        [Parameter(Position = 2, Mandatory = $false)]
        [scriptblock]$Action,

        [Parameter(Mandatory = $false)]
        [scriptblock]$PreAction,
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$PostAction,

        [Parameter(Mandatory = $false)]
        [scriptblock]$Precondition = { $true },

        [Parameter(Mandatory = $false)]
        [scriptblock]$Postcondition = { $true },

        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnError,

        [Parameter(Mandatory = $false)]
        [string[]]$Depends = @(),
 
        [Parameter(Mandatory = $false)]
        [Alias('reqvars')]
        [string[]]$RequiredVariables = @(),

        [Parameter(Mandatory = $false)]
        [Alias('desc')]
        [string]$Description,

        [Parameter(Mandatory = $false)]
        [string]$Alias
    )

    if ($Name -eq 'default') 
    {
        Assert (-not $Action) -FailMessage ($PBLocalizedData.Err_DefaultTaskCannotHaveAction)
    }

    $newTask = @{
        Name = $Name
        DependsOn = $Depends
        PreAction = $PreAction
        Action = $Action
        PostAction = $PostAction
        Precondition = $Precondition
        Postcondition = $Postcondition
        ContinueOnError = $ContinueOnError
        Description = $Description
        Duration = [System.TimeSpan]::Zero
        RequiredVariables = $RequiredVariables
        Alias = $Alias
    }

    $taskKey = $Name.ToLower()

    $CurrentContext = $PowerBuild.Context.Peek()

    Assert (-not $CurrentContext.Tasks.ContainsKey($taskKey)) -FailMessage ($PBLocalizedData.Err_DuplicateTaskName -f $Name)

    $CurrentContext.Tasks.$taskKey = $newTask

    if ($Alias)
    {
        $aliasKey = $Alias.ToLower()

        Assert (-not $CurrentContext.Aliases.ContainsKey($aliasKey)) -FailMessage ($PBLocalizedData.Err_DuplicateAliasName -f $Alias)

        $CurrentContext.Aliases.$aliasKey = $newTask
    }
}

# .ExternalHelp  PowerBuild-Help.xml
function Say
{
    [CmdletBinding(DefaultParameterSetName = 'NormalSet')]
    Param(
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'NormalSet')]
        [Parameter(Mandatory = $true, Position = 1, ParameterSetName = 'TaskSet')]
        [string]$Message,

        [Parameter(Mandatory = $true, ParameterSetName = 'DividerSet')]
        [switch]$Divider,

        [Parameter(Mandatory = $true, ParameterSetName = 'TaskSet')]
        [switch]$Task,

        [Parameter(Mandatory = $true, ParameterSetName = 'NewLineSet')]
        [switch]$NewLine,

        [Parameter(Mandatory = $false, ParameterSetName = 'NewLineSet')]
        [ValidateRange(1, [Int]::MaxValue)]
        [int]$LineCount = 1,

        [Parameter(Mandatory = $false, ParameterSetName = 'NormalSet')]
        [ValidateRange(0, 6)]
        [Alias('v')]
        [int]$VerboseLevel = 1,

        [Parameter(Mandatory = $false, ParameterSetName = 'NormalSet')]
        [Alias('fg')]
        [System.ConsoleColor]$ForegroundColor = 'Yellow',

        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    # configured verbose level = 0 --> no output except errors
    if ((-not $Force) -and ($PowerBuild.Context.Peek().Config.VerboseLevel -eq 0))
    {
        return
    }

    # this works even if $Host is not around
    $dividerMaxLength = [Math]::Max(70, $Host.UI.RawUI.WindowSize.Width - 1)
 
    if ($PSCmdlet.ParameterSetName -eq 'TaskSet')
    {
        if (-not $Message.StartsWith('Show'))
        {
            Write-Output ([Environment]::NewLine * 3)
            WriteColoredOutput ('=' * $dividerMaxLength) -ForegroundColor Magenta
            WriteColoredOutput ($Message) -ForegroundColor Magenta
            WriteColoredOutput ('=' * $dividerMaxLength) -ForegroundColor Magenta
            Write-Output ([Environment]::NewLine)
        }
        else
        {
            # tasks that starts with 'Show' will not output headline.
            # user will diy all output
            return
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'DividerSet')
    {
        Write-Output ([Environment]::NewLine)
        WriteColoredOutput ('+' * $dividerMaxLength) -ForegroundColor Cyan
        Write-Output ([Environment]::NewLine)
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'NewLineSet')
    {
        Write-Output ([Environment]::NewLine * $LineCount)
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'NormalSet')
    {
        # suppress output if verbose level > configured verbose level
        if ((-not $Force) -and ($VerboseLevel -gt $PowerBuild.Context.Peek().Config.VerboseLevel))
        {
            return
        }

        WriteColoredOutput $Message -ForegroundColor $(
            if ($VerboseLevel -eq 0) { 'Red' }
            elseif ($VerboseLevel -eq 1) { $ForegroundColor }
            elseif ($VerboseLevel -eq 2) { 'Green' }
            elseif ($VerboseLevel -eq 3) { 'Magenta' }            
            elseif ($VerboseLevel -eq 4) { 'DarkMagenta' }            
            else { 'Gray' }
        )
    }
}

# .ExternalHelp  PowerBuild-Help.xml
function Die
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 2)]
        [string]$ErrorCode = 'BuildError'
    )

    if ($Message -eq '') { $Message = 'An unknown error has occured.' }    
    $errRecord = New-Object 'System.Management.Automation.ErrorRecord' -ArgumentList $Message, $ErrorCode, 'InvalidOperation', $null
    $PSCmdlet.ThrowTerminatingError($errRecord)
}

# .ExternalHelp  PowerBuild-Help.xml
function Get-PowerBuildScriptTasks 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$BuildFile
    )

    if (-not $BuildFile) 
    {
        $BuildFile = $PowerBuild.ConfigDefault.BuildFileName
    }

    try
    {
        ExecuteInBuildFileScope {
            Param($CurrentContext, $Module)

            return GetTasksFromContext $CurrentContext
        } -BuildFile $BuildFile -Module ($MyInvocation.MyCommand.Module) 
    } 
    finally 
    {
        CleanupEnvironment
    }
}

# .ExternalHelp  PowerBuild-Help.xml
function Invoke-PowerBuild 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$BuildFile,

        [Parameter(Position = 2, Mandatory = $false)]
        [string[]]$TaskList = @(),
        
        [Parameter(Mandatory = $false)]
        [string]$Framework,

        [Parameter(Mandatory = $false)]
        [switch]$Docs,

        [Parameter(Mandatory = $false)]
        [hashtable]$Parameters = @{},

        [Parameter(Mandatory = $false)]
        $Properties = @{},
        
        [Parameter(Mandatory = $false)]
        [Alias('init')]
        [scriptblock]$Initialization = {},

        [Parameter(Mandatory = $false)]
        [switch]$NoLogo,

        [Parameter(Mandatory = $false)]
        [switch]$DetailDocs,

        [Parameter(Mandatory = $false)]
        [Alias('tr')]
        [switch]$TimeReport
    )

    try 
    {
        if (-not $NoLogo) 
        {
            $logoText = @(
                ('PowerBuild version {0}' -f $PowerBuild.Version)
                'Copyright (c) 2017 Lizoc Inc. All rights reserved.'
                ''
            ) -join [Environment]::NewLine
            Write-Output $logoText
        }

        if (-not $BuildFile) 
        {
          $BuildFile = $PowerBuild.ConfigDefault.BuildFileName
        }
        elseif (-not (Test-Path $BuildFile -PathType Leaf) -and 
            (Test-Path $PowerBuild.ConfigDefault.BuildFileName -PathType Leaf)) 
        {
            # if the $config.buildFileName file exists and the given "buildfile" isn 't found assume that the given
            # $buildFile is actually the target Tasks to execute in the $config.buildFileName script.
            $taskList = $BuildFile.Split(', ')
            $BuildFile = $PowerBuild.ConfigDefault.BuildFileName
        }

        ExecuteInBuildFileScope -BuildFile $BuildFile -Module ($MyInvocation.MyCommand.Module) -ScriptBlock {
            Param($CurrentContext, $Module)            

            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            
            if ($Docs -or $DetailDocs) 
            {
                WriteDocumentation -Detail:$DetailDocs
                return
            }
            
            foreach ($key in $Parameters.keys) 
            {
                if (Test-Path "Variable:\$key") 
                {
                    Set-Item -Path "Variable:\$key" -Value $Parameters.$key -WhatIf:$false -Confirm:$false | Out-Null
                } 
                else 
                {
                    New-Item -Path "Variable:\$key" -Value $Parameters.$key -WhatIf:$false -Confirm:$false | Out-Null
                }
            }
            
            # The initial dot (.) indicates that variables initialized/modified in the propertyBlock are available in the parent scope.
            foreach ($propertyBlock in $CurrentContext.Properties) 
            {
                . $propertyBlock
            }
            
            foreach ($key in $Properties.Keys) 
            {
                if (Test-Path "Variable:\$key") 
                {
                    Set-Item -Path "Variable:\$key" -Value $Properties.$key -WhatIf:$false -Confirm:$false | Out-Null
                }
            }
            
            # Simple dot sourcing will not work. We have to force the script block into our
            # module's scope in order to initialize variables properly.
            . $Module $Initialization
            
            # Execute the list of tasks or the default task
            if ($taskList) 
            {
                foreach ($task in $taskList) 
                {
                    Invoke-Task $task
                }
            } 
            elseif ($CurrentContext.Tasks.Default) 
            {
                Invoke-Task default
            } 
            else 
            {
                Die $PBLocalizedData.Err_NoDefaultTask 'NoDefaultTask'
            }
            
            $outputMessage = @(
                ''
                $PBLocalizedData.BuildSuccess
                ''
            ) -join [Environment]::NewLine

            WriteColoredOutput $outputMessage -ForegroundColor Green
            
            $stopwatch.Stop()
            if ($TimeReport) 
            {
                WriteTaskTimeSummary $stopwatch.Elapsed
            }
        }

        $PowerBuild.BuildSuccess = $true
    } 
    catch 
    {
        $currentConfig = GetCurrentConfigurationOrDefault
        if ($currentConfig.VerboseError) 
        {
            $errMessage = @(
                ('[{0}] {1}' -f (Get-Date).ToString('hhmm:ss'), $PBLocalizedData.ErrorHeaderText)
                ''
                ('{0}: {1}' -f $PBLocalizedData.ErrorLabel, (ResolveError $_ -Short))
                $PBLocalizedData.Divider
                (ResolveError $_)  # this will have enough blank lines appended
                $PBLocalizedData.Divider
                $PBLocalizedData.VariableLabel
                $PBLocalizedData.Divider
                (Get-Variable -Scope Script | Format-Table | Out-String)
            ) -join [Environment]::NewLine
        } 
        else 
        {
            # ($_ | Out-String) gets error messages with source information included.
            $errMessage = '[{0}] {1}: {2}' -f (Get-Date).ToString('hhmm:ss'), $PBLocalizedData.ErrorLabel, (ResolveError $_ -Short)
        }

        $PowerBuild.BuildSuccess = $false

        # if we are running in a nested scope (i.e. running a build script from within another build script) then we need to re-throw the exception
        # so that the parent script will fail otherwise the parent script will report a successful build
        $inNestedScope = ($PowerBuild.Context.Count -gt 1)
        if ($inNestedScope) 
        {
            Die $_
        } 
        else 
        {
            if (-not $PowerBuild.RunByUnitTest) 
            {
                WriteColoredOutput $errMessage -ForegroundColor Red
            }
        }
    } 
    finally 
    {
        CleanupEnvironment
    }
}


#######################################################################
#  Private Module Functions
#######################################################################

function WriteColoredOutput 
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Message,

        [Parameter(Mandatory = $true, Position = 2)]
        [System.ConsoleColor]$ForegroundColor
    )

    $currentConfig = GetCurrentConfigurationOrDefault
    if ($currentConfig.ColoredOutput -eq $true) 
    {
        if (($Host.UI -ne $null) -and 
            ($Host.UI.RawUI -ne $null) -and 
            ($Host.UI.RawUI.ForegroundColor -ne $null)) 
        {
            $previousColor = $Host.UI.RawUI.ForegroundColor
            $Host.UI.RawUI.ForegroundColor = $ForegroundColor
        }
    }

    Write-Output $message

    if ($previousColor -ne $null) 
    {
        $Host.UI.RawUI.ForegroundColor = $previousColor
    }
}

function ExecuteInBuildFileScope 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $true)]
        [string]$BuildFile, 

        [Parameter(Mandatory = $true)]
        $Module
    )
    
    # Execute the build file to set up the tasks and defaults
    Assert (Test-Path $BuildFile -PathType Leaf) -FailMessage ($PBLocalizedData.Err_BuildFileNotFound -f $BuildFile)

    $PowerBuild.BuildScriptFile = Get-Item $BuildFile
    $PowerBuild.BuildScriptDir = $PowerBuild.BuildScriptFile.DirectoryName
    $PowerBuild.BuildSuccess = $false

    $PowerBuild.Context.Push(@{
        'TaskSetupScriptBlock' = {}
        'TaskTearDownScriptBlock' = {}
        'ExecutedTasks' = New-Object System.Collections.Stack
        'CallStack' = New-Object System.Collections.Stack
        'OriginalEnvPath' = $env:Path
        'OriginalDirectory' = Get-Location
        'OriginalErrorActionPreference' = $global:ErrorActionPreference
        'Tasks' = @{}
        'Aliases' = @{}
        'Properties' = @()
        'Includes' = New-Object System.Collections.Queue
        'Config' = CreateConfigurationForNewContext -BuildFile $BuildFile -Framework $Framework
    })

    LoadConfiguration $PowerBuild.BuildScriptDir

    Set-Location $PowerBuild.BuildScriptDir

    LoadModules

    $frameworkOldValue = $Framework
    . $PowerBuild.BuildScriptFile.FullName

    $CurrentContext = $PowerBuild.Context.Peek()

    if ($Framework -ne $frameworkOldValue) 
    {
        WriteColoredOutput $PBLocalizedData.Warn_DeprecatedFrameworkVar -ForegroundColor Yellow
        $CurrentContext.Config.Framework = $Framework
    }

    ConfigureBuildEnvironment

    while ($CurrentContext.Includes.Count -gt 0) 
    {
        $includeFilename = $CurrentContext.Includes.Dequeue()
        . $includeFilename
    }

    & $ScriptBlock $CurrentContext $Module
}

function WriteDocumentation
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$Detail
    )

    $currentContext = $PowerBuild.Context.Peek()

    if ($currentContext.Tasks.Default) 
    {
        $defaultTaskDependencies = $currentContext.Tasks.Default.DependsOn
    } 
    else
    {
        $defaultTaskDependencies = @()
    }
    
    $docs = GetTasksFromContext $currentContext | where {
        $_.Name -ne 'default'
    } | ForEach-Object {
        $isDefault = $null
        if ($defaultTaskDependencies -contains $_.Name) 
        { 
            $isDefault = $true 
        }
        
        Add-Member -InputObject $_ 'Default' $isDefault -Passthru
    }

    if ($Detail) 
    {
        $docs | sort 'Name' | Format-List -Property Name, Alias, Description, @{
            Label = 'Depends On'
            Expression = { $_.DependsOn -join ', '}
        }, Default
    } 
    else 
    {
        $docs | sort 'Name' | Format-Table -AutoSize -Wrap -Property Name, Alias, @{
            Label = 'Depends On'
            Expression = { $_.DependsOn -join ', ' }
        }, Default, Description
    }
}

function ResolveError
{
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        $ErrorRecord = $Error[0],

        [Parameter(Mandatory = $false)]
        [switch]$Short
    )

    Process 
    {
        if ($_ -eq $null) 
        { 
            $_ = $ErrorRecord 
        }
        $ex = $_.Exception

        if (-not $Short) 
        {
            $errMessage = @(
                ''
                'ErrorRecord:{0}ErrorRecord.InvocationInfo:{1}Exception:'
                '{2}'
                ''
            ) -join [Environment]::NewLine

            $formattedErrRecord = $_ | Format-List * -Force | Out-String
            $formattedInvocationInfo = $_.InvocationInfo | Format-List * -Force | Out-String
            $formattedException = ''

            $i = 0
            while ($ex -ne $null) 
            {
                $i++
                $formattedException += @(
                    ("$i" * 70)
                    ($ex | Format-List * -Force | Out-String)
                    '' 
                ) -join [Environment]::NewLine

                $ex = $ex | SelectObjectWithDefault -Name 'InnerException' -Value $null
            }

            return $errMessage -f $formattedErrRecord, $formattedInvocationInfo, $formattedException
        }

        $lastException = @()
        while ($ex -ne $null) 
        {
            $lastMessage = $ex | SelectObjectWithDefault -Name 'Message' -Value ''
            $lastException += ($lastMessage -replace [Environment]::NewLine, '')

            if ($ex -is [Data.SqlClient.SqlException]) 
            {
                $lastException = '(Line [{0}] Procedure [{1}] Class [{2}] Number [{3}] State [{4}])' -f $ex.LineNumber, $ex.Procedure, $ex.Class, $ex.Number, $ex.State
            }
            $ex = $ex | SelectObjectWithDefault -Name 'InnerException' -Value $null
        }
        $shortException = $lastException -join ' --> '

        $header = $null
        $current = $_
        $header = (($_.InvocationInfo | SelectObjectWithDefault -Name 'PositionMessage' -Value '') -replace [Environment]::NewLine, ' '),
            ($_ | SelectObjectWithDefault -Name 'Message' -Value ''),
            ($_ | SelectObjectWithDefault -Name 'Exception' -Value '') | where { -not [String]::IsNullOrEmpty($_) } | select -First 1

        $delimiter = ''
        if ((-not [String]::IsNullOrEmpty($header)) -and
            (-not [String]::IsNullOrEmpty($shortException)))
        { 
            $delimiter = ' [<<==>>] ' 
        }

        return '{0}{1}Exception: {2}' -f $header, $delimiter, $shortException
    }
}

function LoadModules 
{
    $currentConfig = $PowerBuild.Context.Peek().Config
    if ($currentConfig.Modules) 
    {
        $scope = $currentConfig.ModuleScope
        $global = [string]::Equals($scope, 'global', [StringComparison]::CurrentCultureIgnoreCase)

        $currentConfig.Modules | ForEach-Object {
            Resolve-Path $_ | ForEach-Object {
                # "Loading module: $_"
                $module = Import-Module $_ -PassThru -DisableNameChecking -Global:$global -Force

                if (-not $module) 
                {
                    Die ($PBLocalizedData.Err_LoadingModule -f $_.Name) 'LoadModuleError'
                }
            }
        }

        Write-Output ''
    }
}

function LoadConfiguration 
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath = $PSScriptRoot
    )

    $pbConfigFilePath = (Join-Path $ConfigPath "PowerBuild-Config.ps1")

    if (Test-Path $pbConfigFilePath -PathType Leaf) 
    {
        try 
        {
            $config = GetCurrentConfigurationOrDefault
            . $pbConfigFilePath
        } 
        catch 
        {
            Die ($PBLocalizedData.Err_LoadConfig + ': ' + $_) 'LoadConfigError'
        }
    }
}

function GetCurrentConfigurationOrDefault() 
{
    if ($PowerBuild.Context.Count -gt 0) 
    {
        $PowerBuild.Context.Peek().Config
    } 
    else 
    {
        $PowerBuild.ConfigDefault
    }
}

function CreateConfigurationForNewContext 
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$BuildFile,

        [Parameter(Mandatory = $false)]
        [string]$Framework
    )

    $previousConfig = GetCurrentConfigurationOrDefault

    $config = New-Object PSObject -Property @{
        BuildFileName = $previousConfig.BuildFileName
        Framework = $previousConfig.Framework
        TaskNameFormat = $previousConfig.TaskNameFormat
        VerboseError = $previousConfig.VerboseError
        ColoredOutput = $previousConfig.ColoredOutput
        Modules = $previousConfig.Modules
        ModuleScope = $previousConfig.ModuleScope
        VerboseLevel = $previousConfig.VerboseLevel
    }

    if ($Framework) 
    {
        $config.Framework = $Framework
    }

    if ($BuildFile) 
    {
        $config.BuildFileName = $BuildFile
    }

    $config
}

function ConfigureBuildEnvironment 
{
    $framework = $PowerBuild.Context.Peek().Config.Framework

    if ($framework -cmatch '^((?:\d+\.\d+)(?:\.\d+){0,1})(x86|x64){0,1}$') 
    {
        $versionPart = $matches[1]
        $bitnessPart = $matches[2]
    } 
    else 
    {
        Die ($PBLocalizedData.Err_InvalidFramework -f $framework) 'FrameworkFormatError'
    }

    $versions = $null
    $buildToolsVersions = $null

    switch ($versionPart) 
    {
        '1.0' { $versions = @('v1.0.3705') }
        '1.1' { $versions = @('v1.1.4322') }
        '2.0' { $versions = @('v2.0.50727') }
        '3.0' { $versions = @('v2.0.50727') }
        '3.5' { $versions = @('v3.5', 'v2.0.50727') }
        '4.0' { $versions = @('v4.0.30319') }

        {($_ -eq '4.5.1') -or ($_ -eq '4.5.2')} 
        {
            $versions = @('v4.0.30319')
            $buildToolsVersions = @('14.0', '12.0')
        }

        {($_ -eq '4.6') -or ($_ -eq '4.6.1')} 
        {
            $versions = @('v4.0.30319')
            $buildToolsVersions = @('14.0')
        }

        default 
        {
            Die ($PBLocalizedData.Err_UnknownFramework -f $versionPart, $framework) 'UnsupportedFramework'
        }
    }

    $bitness = 'Framework'
    if ($versionPart -ne '1.0' -and $versionPart -ne '1.1') 
    {
        switch ($bitnessPart) 
        {
            'x86' 
            {
                $bitness = 'Framework'
                $buildToolsKey = 'MSBuildToolsPath32'
            }

            'x64' 
            {
                $bitness = 'Framework64'
                $buildToolsKey = 'MSBuildToolsPath'
            }

            { [string]::IsNullOrEmpty($_) } 
            {
                $ptrSize = [System.IntPtr]::Size
                switch ($ptrSize) 
                {
                    4 
                    {
                        $bitness = 'Framework'
                        $buildToolsKey = 'MSBuildToolsPath32'
                    }

                    8 
                    {
                        $bitness = 'Framework64'
                        $buildToolsKey = 'MSBuildToolsPath'
                    }

                    default 
                    {
                        Die ($PBLocalizedData.Err_UnknownPointerSize -f $ptrSize) 'UnsupportedFrameworkPlatform'
                    }
                }
            }

            default 
            {
                Die ($PBLocalizedData.Err_UnknownBitnessPart -f $bitnessPart, $framework) 'UnsupportedFrameworkPlatform'
            }
        }
    }

    $frameworkDirs = @()
    if ($buildToolsVersions -ne $null) 
    {
        foreach ($ver in $buildToolsVersions) 
        {
            if (Test-Path "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\$ver") 
            {
                $frameworkDirs += (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\$ver" -Name $buildToolsKey).$buildToolsKey
            }
        }
    }
    $frameworkDirs = $frameworkDirs + @(
        $versions | ForEach-Object { 
            Join-Path $env:windir -ChildPath "Microsoft.NET/$bitness/$_/" 
        }
    )

    for ($i = 0; $i -lt $frameworkDirs.Count; $i++) 
    {
        $dir = $frameworkDirs[$i]
        if ($dir -match '\$\(Registry:HKEY_LOCAL_MACHINE(.*?)@(.*)\)') 
        {
            $key = "HKLM:" + $matches[1]
            $name = $matches[2]
            $dir = (Get-ItemProperty -Path $key -Name $name)."$name"
            $frameworkDirs[$i] = $dir
        }
    }

    $frameworkDirs | ForEach-Object { 
        Assert (Test-Path $_ -PathType Container) -FailMessage ($PBLocalizedData.Err_NoFrameworkInstallDirFound -f $_)
    }

    $env:Path = ($frameworkDirs -join ';') + ";$env:Path"

    # if any error occurs in a PS function then "stop" processing immediately
    # this does not effect any external programs that return a non-zero exit code
    $global:ErrorActionPreference = 'Stop'
}

function CleanupEnvironment 
{
    if ($PowerBuild.Context.Count -gt 0) 
    {
        $currentContext = $PowerBuild.Context.Peek()
        $env:Path = $currentContext.OriginalEnvPath
        Set-Location $currentContext.OriginalDirectory
        $global:ErrorActionPreference = $currentContext.OriginalErrorActionPreference
        [void]$PowerBuild.Context.Pop()
    }
}

function SelectObjectWithDefault
{
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $true)]
        [psobject]$InputObject,

        [Parameter(ValueFromPipeline = $false)]
        [string]$Name,

        [Parameter(ValueFromPipeline = $false)]
        $Value
    )

    Process 
    {
        if ($_ -eq $null) 
        { 
            $Value 
        }
        elseif ($_ | Get-Member -Name $Name) 
        {
            $_."$Name"
        }
        elseif (($_ -is [Hashtable]) -and ($_.Keys -contains $Name)) 
        {
            $_."$Name"
        }
        else 
        { 
            $Value 
        }
    }
}

function GetTasksFromContext 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        $CurrentContext
    )

    $CurrentContext.Tasks.Keys | ForEach-Object {
        $task = $CurrentContext.Tasks."$_"

        New-Object PSObject -Property @{
            Name = $task.Name
            Alias = $task.Alias
            Description = $task.Description
            DependsOn = $task.DependsOn
        }
    }
}

function WriteTaskTimeSummary 
{
    [CmdletBinding()]
    Param(
        [Parameter(Position = 1, Mandatory = $true)]
        $Duration
    )

    if ($PowerBuild.Context.Count -gt 0) 
    {
        Write-Output $PBLocalizedData.Divider
        Write-Output $PBLocalizedData.BuildTimeReportTitle
        Write-Output $PBLocalizedData.Divider

        $list = @()
        $currentContext = $PowerBuild.Context.Peek()
        while ($currentContext.ExecutedTasks.Count -gt 0) 
        {
            $taskKey = $currentContext.ExecutedTasks.Pop()
            $task = $currentContext.Tasks.$taskKey
            if ($taskKey -eq 'default') 
            {
                continue
            }
            $list += New-Object PSObject -Property @{
                Name = $task.Name
                Duration = $task.Duration
            }
        }
        [Array]::Reverse($list)
        $list += New-Object PSObject -Property @{
            Name = 'Total'
            Duration = $Duration
        }

        # using "out-string | where-object" to filter out the blank line that format-table prepends
        $list | Format-Table -AutoSize -Property Name, Duration | Out-String -Stream | where { $_ }
    }
}


#######################################################################
#  Main
#######################################################################

$scriptDir = Split-Path $MyInvocation.MyCommand.Path
$manifestPath = Join-Path $scriptDir PowerBuild.psd1
$manifest = Test-ModuleManifest -Path $manifestPath -WarningAction SilentlyContinue

$script:PowerBuild = @{}

$PowerBuild.Version = $manifest.Version.ToString()
$PowerBuild.Context = New-Object System.Collections.Stack   # holds onto the current state of all variables
$PowerBuild.RunByUnitTest = $false                          # indicates that build is being run by internal unit tester

# contains default configuration, can be overriden in PowerBuild-Config.ps1 in directory with PowerBuild.psm1 or in directory with current build script
$PowerBuild.ConfigDefault = New-Object PSObject -Property @{
    BuildFileName = 'default.ps1'
    Framework = '4.0'
    TaskNameFormat = $PBLocalizedData.DefaultTaskNameFormat
    VerboseError = $false
    ColoredOutput = $true
    Modules = $null
    ModuleScope = ''
    VerboseLevel = 2
} 

$PowerBuild.BuildSuccess = $false     # indicates that the current build was successful
$PowerBuild.BuildScriptFile = $null   # contains a System.IO.FileInfo for the current build script
$PowerBuild.BuildScriptDir = ''       # contains a string with fully-qualified path to current build script
$PowerBuild.ModulePath = $PSScriptRoot

LoadConfiguration

Export-ModuleMember -Function @(
    'Invoke-PowerBuild', 'Invoke-Task', 'Get-PowerBuildScriptTasks', 
    'Task', 'Properties', 'Include', 'FormatTaskName', 'TaskSetup', 'TaskTearDown', 'Framework', 'Assert', 'Exec', 'Say', 'Die'
) -Variable @(
    'PowerBuild'
)
