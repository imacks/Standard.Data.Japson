properties {
    [string]$Configuration = 'Debug'

    [string[]]$BuildTarget = @()

    [switch]$Help = $false
}


# --- overrides ---

formatTaskName {
	param($taskName)

    say -Task $taskName
}

# --- /overrides ---


# --- helpers ---

function ResolveProjectBsdFileList
{
    Param(
        [switch]$UseGlobalBsd,
        [string]$GlobalBsdPath,
        [string]$ProjectBsdPath            
    )

    $result = @()
    if ($UseGlobalBsd)
    {
        $result += $GlobalBsdPath
    }

    $allIncludes = Get-Content $ProjectBsdPath | where { $_ -ne '' } | select -First 1 | ForEach-Object { $_.Trim() }
    if ($allIncludes -and ($allIncludes -like '#include *'))
    {
        $bsdResolutionPaths = @(
            $PowerBuild.WorkingSourceDir, 
            $PowerBuild.BuildConfigDir, 
            (Split-Path $ProjectBsdPath -Parent)
        )
        foreach ($bsdBaseName in $allIncludes.Substring('#include '.Length).Split(','))
        {
            $bsdFileName = $bsdBaseName.Trim() + '.bsd'
            $foundBsdFile = $false
            foreach ($resPath in $bsdResolutionPaths)
            {
                if (Test-Path (Join-Path $resPath -ChildPath $bsdFileName) -PathType Leaf)
                {
                    $result += Join-Path $resPath -ChildPath $bsdFileName
                    $foundBsdFile = $true
                    break
                }
            }
            if ($foundBsdFile -eq $false)
            {
                say "[i] Unable to find file: $baseFileName" -v 0
            }
        }
    }

    $result += $ProjectBsdPath

    return $result
}

function ParseBsdFiles
{
    Param(
        [string[]]$BsdFiles,
        [hashtable]$Prefix
    )

    $result = @()

    $Prefix.Keys | ForEach-Object {
        $result += "'{0}' = '{1}'" -f $_, $Prefix."$_"
    }

    foreach ($bsdFile in $BsdFiles)
    {
        $result += Get-Content $bsdFile
    }

    return (ConvertFrom-Japson ($result -join [Environment]::NewLine))
}

# --- /helpers ---


task default -depends Finish

task Help -precondition { $Help -eq $true } {
    say @'
build [debug|release|publish] [project1.name] [project2.name] [...]
build /?|/help|-h|--help

EXAMPLE #1
    build

    DESCRIPTION
    -----------
    Build all projects in this repo. Configuration by default is 'debug'.


EXAMPLE #2
    build release

    DESCRIPTION
    -----------
    Build all projects in this repo. Configuration by 'release'. You can also specify 'debug' or 'publish':
    * Debug   -> No optimization. Assembly will not be strong signed.
    * Release -> Optimization, strong signed and packaged.
    * Publish -> Same as release, plus pushing to NuGet.


EXAMPLE #3
    build debug MyProject1 MyProject2

    DESCRIPTION
    -----------
    Build selective projects in this repo. Project names are folders under the '/Source' folder that do not end with '.Tests'. 


REMARKS
    Version 1.0.128.0
    Created by the Build Team @Lizoc.

'@

    exit
}

task Precheck {
    say "[i] Preparing to build"

    $supportedConfigs = @('Release', 'Debug', 'Publish')
    assert ($Configuration -in $supportedConfigs) ('Invalid configuration. Expects one of the following: {0}' -f ($supportedConfigs -join ', '))
    $PowerBuild.UploadToNuget = $false
    if ($Configuration -eq 'Publish')
    {
        $Configuration = 'Release'
        $PowerBuild.UploadToNuget = $true
    }
    say "* Configuration is $Configuration" -v 2
    if ($PowerBuild.UploadToNuget)
    {
        say '* This project will be uploaded to NuGet server if successfully compiled.' -v 2        
    }
}

task Setup -depends Help, Precheck {
    # ~~~~~~~~~~~~~~~~~
    # folder paths
    # ~~~~~~~~~~~~~~~~~
    $PowerBuild.RepoDir = Get-Item $PSScriptRoot/../../ | select -expand FullName
    $PowerBuild.ToolsDir = Join-Path $PowerBuild.RepoDir -ChildPath 'Tools'
    $PowerBuild.BuildConfigDir = Join-Path $PowerBuild.BuildScriptDir -ChildPath 'configs'
    $PowerBuild.DotNetCoreDir = Join-Path $PowerBuild.ToolsDir -ChildPath 'DotNetCore'
    $PowerBuild.WorkingDir = Join-Path $PowerBuild.RepoDir -ChildPath 'Working'
    $PowerBuild.WorkingPkgDir = Join-Path $PowerBuild.WorkingDir -ChildPath 'packages'
    $PowerBuild.WorkingSourceDir = Join-Path $PowerBuild.WorkingDir -ChildPath 'Source'
    $PowerBuild.SourceDir = Join-Path $PowerBuild.RepoDir -ChildPath 'Source'
    $PowerBuild.OutputDir = Join-Path $PowerBuild.WorkingDir -ChildPath "bin/$Configuration"
    $PowerBuild.OutputSymbolsDir = Join-Path $PowerBuild.OutputDir -ChildPath 'Symbols'
    $PowerBuild.CredentialDir = Join-Path $PowerBuild.RepoDir -ChildPath 'Credential'
    $PowerBuild.LocalPackageOutputDir = Join-Path (Get-Item $PSScriptRoot | select -expand Root) -ChildPath 'Packages'
    $PowerBuild.RepoName = Split-Path $PowerBuild.RepoDir -Leaf


    # ~~~~~~~~~~~~~~~~~
    # import helpers
    # ~~~~~~~~~~~~~~~~~
    say ('[i] Importing helper modules')
    @(
        'Lizoc.PowerShell.Japson.dll'
    ) | ForEach-Object {
        say ('* {0}' -f $_) -v 2
        ipmo (Join-Path $PowerBuild.BuildScriptDir -ChildPath $_) -Force
    }


    # ~~~~~~~~~~~~~~~~~
    # set up working dir
    # ~~~~~~~~~~~~~~~~~
    if (-not (Test-Path $PowerBuild.WorkingSourceDir -PathType Container))
    {
        if (Test-Path $PowerBuild.WorkingSourceDir -PathType Leaf) 
        {
            say ("Trying to remove unexpected file at working path: {0}" -f $PowerBuild.WorkingSourceDir) -v 0
            del $WorkingSourceDir 
        }

        say ('[i] Creating working folder: {0}' -f $PowerBuild.WorkingSourceDir)
        md $PowerBuild.WorkingSourceDir -Force | Out-Null
    }

    say ('[i] Copying source code to working folder: {0} -> {1}' -f $PowerBuild.SourceDir, $PowerBuild.WorkingSourceDir)
    $robocopyParams = @{
        'SourcePath' = $PowerBuild.SourceDir
        'WorkingPath' = $PowerBuild.WorkingSourceDir
        'ExcludeFolders' = @('bin', 'obj', 'TestResults', 'AppPackages', 'packages', '.vs', 'artifacts')
        'ExcludeFiles' = @('*.suo', '*.user', '*.lock.json')
    }
    robocopy $robocopyParams.SourcePath $robocopyParams.WorkingPath /MIR /NP /NS /NC /NFL /NDL /NJS /XD $robocopyParams.ExcludeFolders /XF $robocopyParams.ExcludeFiles | Out-Default


    # ~~~~~~~~~~~~~~~~~
    # preinit data
    # ~~~~~~~~~~~~~~~~~
    say ('[i] Initializing common configuration')
    $bsdConfigData = @()
    @(
        'fx-redirection',
        'repos-nuget'
        'paths'
    ) | ForEach-Object {
        if (Test-Path (Join-Path $PowerBuild.BuildConfigDir -ChildPath "$_.bsd") -PathType Leaf)
        {
            say ('* {0}' -f $_) -v 2
            $bsdConfigData += Get-Content (Join-Path $PowerBuild.BuildConfigDir -ChildPath "$_.bsd")
        }
        else
        {
            say ("Missing configuration file: {0}" -f (Join-Path $BuildConfigDir -ChildPath "$_.bsd")) -v 0
        }
    }
    $PowerBuild.BSDCommonConfig = ConvertFrom-Japson ($bsdConfigData -join [Environment]::NewLine)

    # test tfm redirections
    $testTfmRedirect = [ordered]@{}
    if ($PowerBuild.BSDCommonConfig.'framework-redirection'.tests)
    {
        $PowerBuild.BSDCommonConfig.'framework-redirection'.tests | Get-Member -MemberType NoteProperty | select -expand Name | ForEach-Object {
            $testTfmRedirect.Add($_, $PowerBuild.BSDCommonConfig.'framework-redirection'.tests."$_")
        }
    }
    $PowerBuild.TestTFMRedirect = $testTfmRedirect


    # ~~~~~~~~~~~~~~~~~
    # override default paths if required
    # ~~~~~~~~~~~~~~~~~
    @(
        'DotNetCoreDir', 'WorkingPkgDir', 'LocalPackageOutputDir', 'CredentialDir'
    ) | ForEach-Object {
        if ($PowerBuild.BSDCommonConfig."$_")
        {
            $PowerBuild."$_" = $PowerBuild.BSDCommonConfig."$_"
        }
    }


    # ~~~~~~~~~~~~~~~~~
    # set up Nuget
    # ~~~~~~~~~~~~~~~~~
    if ($PowerBuild.UploadToNuget)
    {
        $nugetPushApiKeyPath = Join-Path $PowerBuild.CredentialDir -ChildPath 'NugetPushApiKey.json'
        if (-not (Test-Path $nugetPushApiKeyPath -PathType Leaf))
        {
            say ("[!] Cannot push package because api key file is missing: {0}" -f $nugetPushApiKeyPath) -v 0
        }
        else 
        {
            say ('[i] Reading NuGet server management credentials: {0}' -f $nugetPushApiKeyPath)
            $PowerBuild.NugetConfig = ConvertFrom-Json ((Get-Content $nugetPushApiKeyPath) -join [Environment]::NewLine)
        }
    }



    # ~~~~~~~~~~~~~~~~~
    # generate common files
    # ~~~~~~~~~~~~~~~~~
    say ('[i] Generating Nuget configuration')

    # https://docs.microsoft.com/en-us/nuget/schema/nuget-config-file
    $nugetConfigXmlContent = @(
        '<?xml version="1.0" encoding="utf-8" standalone="yes"?>'
        '<configuration>'
        '  <config>'
        '    <add key="globalPackagesFolder" value="{{ pkgdir }}" />'
        '    <add key="repositoryPath" value="{{ pkgdir }}" />'    
        '  </config>'        
        '  <packageSources>'
        '{{ clear }}'
        '{{ sources }}'
        '  </packageSources>'
        '</configuration>'
    ) -join [Environment]::NewLine

    $nugetConfigXmlContent = $nugetConfigXmlContent.Replace('{{ pkgdir }}', $PowerBuild.WorkingPkgDir)

    if ($PowerBuild.BSDCommonConfig.repos.nuget.sources)
    {
        $nugetSourceXml = @()
        $PowerBuild.BSDCommonConfig.repos.nuget.sources | Get-Member -MemberType NoteProperty | select -expand Name | ForEach-Object {
            $nugetSourceXml += '    <add key="{0}" value="{1}" />' -f $_, $PowerBuild.BSDCommonConfig.repos.nuget.sources."$_"
        }
        $nugetConfigXmlContent = $nugetConfigXmlContent.Replace(
            '{{ clear }}', '    <clear />'
        ).Replace(
            '{{ sources }}', ($nugetSourceXml -join [Environment]::NewLine)
        ) 
        $nugetConfigXmlContent | Set-Content -Path (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'NuGet.config')
    }
    else
    {
        $nugetConfigXmlContent = $nugetConfigXmlContent.Replace(
            '{{ clear }}', ''
        ).Replace(
            '{{ sources }}', ''
        ) 
        $nugetConfigXmlContent | Set-Content -Path (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'NuGet.config')
    }

    say ('[i] Generating global.json')
    '{ "projects": ["Source"] }' | Set-Content (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'global.json')
}

task Discovery -depends Setup {
    say ('[i] Getting list of projects available in this repository')
    $availableProjectTargets = dir $PowerBuild.WorkingSourceDir -Directory | select -expand Name

    $projectNameList = @()
    if ($BuildTarget)
    {
        $BuildTarget | ForEach-Object {
            if ($_.EndsWith('.Tests'))
            {
                say ("[!] Do not specify test projects: {0}" -f $_) -v 0
            }
            elseif ($_ -in $availableProjectTargets) 
            { 
                $projectNameList += $_ 
            }
            else 
            {
                say ("[!] Project target not found: {0}" -f $_) -v 0
            }
        }
    }
    else
    {
        if (Test-Path (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'BuildOrder.ini'))
        {
            Get-Content (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'BuildOrder.ini') | where { $_ -ne '' } | ForEach-Object {
                if ($_.EndsWith('.Tests'))
                {
                    say ("[!] Do not specify test projects: {0}" -f $_) -v 0
                }
                elseif ($_ -in $availableProjectTargets) 
                { 
                    $projectNameList += $_ 
                }
                else 
                {
                    say ("[!] Project target not found: {0}" -f $_) -v 0            
                }
            } 
        }    
        else
        {
            $projectNameList = $availableProjectTargets
        }
    }

    $PowerBuild.AvailableProjectTargets = $availableProjectTargets

    $PowerBuild.ProjectNameList = $projectNameList
    say "[i] Projects will be built in the resolved order."
    $PowerBuild.ProjectNameList | ForEach-Object {
        say ('* {0}' -f $_) -v 2
    }    
}

task Build -depends Discovery {
    # ~~~~~~~~~~~~~~~~~
    # Global.bsd
    # ~~~~~~~~~~~~~~~~~
    say "[i] Attempting to discover global configuration file"
    $PowerBuild.GlobalBsdFile = Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'global.bsd'
    $PowerBuild.HasGlobalBsdFile = $true
    if (-not (Test-Path $PowerBuild.GlobalBsdFile -PathType Leaf))
    {
        say "[i] Global configuration file not found."
        $PowerBuild.HasGlobalBsdFile = $false
    }


    # ~~~~~~~~~~~~~~~~~
    # Auto build number
    # ~~~~~~~~~~~~~~~~~
    $globalBuildNum = 0
    if (Test-Path (Join-Path $PowerBuild.SourceDir -ChildPath 'buildnum.ini') -PathType Leaf)
    {
        if ([uint32]::TryParse((Get-Content (Join-Path $PowerBuild.SourceDir -ChildPath "buildnum.ini") | select -First 1), [ref]$globalBuildNum) -eq $false)
        {
            say "[!] Automated build number file is corrupted and I have fixed it. Try not to modify the file 'buildnum.ini'." -v 0
        }

        if ($globalBuildNum -eq [uint32]::MaxValue)
        {
            say "[!] Unable to increment the build number anymore because it will overflow." -v 0
        }
        else
        {
            $globalBuildNum = $globalBuildNum + 1
        }
        $globalBuildNum | Set-Content (Join-Path $PowerBuild.SourceDir -ChildPath "buildnum.ini")
    }
    $PowerBuild.GlobalBuildNum = $globalBuildNum
    say "[i] Global build number is: $globalBuildNum"

    # get a list of supported builders
    $supportedBuilders = dir "$PSScriptRoot/builder-*.ps1" -File | select -expand Name

    # a list of properties that comes with PowerBuild.
    $pbStockProperties = @('Version', 'Context', 'RunByUnitTest', 'ConfigDefault', 'BuildSuccess', 'BuildScriptFile', 'BuildScriptDir', 'ModulePath')

    # ~~~~~~~~~~~~~~~~~
    # Compile each
    # ~~~~~~~~~~~~~~~~~
    foreach ($projectName in ($PowerBuild.ProjectNameList | where { $_ -notlike '*.Tests' }))
    {
        say -Divider
        say "[i] Compiling $projectName"


        # --------
        # important project paths
        # --------
        $projectDir = Join-Path $PowerBuild.WorkingSourceDir -ChildPath "$projectName"
        $projectBsdFile = Join-Path $projectDir -ChildPath 'project.bsd'
        $projectJsonFile = Join-Path $projectDir -ChildPath "project.json"

        $testProjectName = "$projectName.Tests"
        $testProjectDir = Join-Path $PowerBuild.WorkingSourceDir -ChildPath $testProjectName
        $testProjectBsdFile = Join-Path $testProjectDir -ChildPath 'project.bsd'
        $testProjectJsonFile = Join-Path $testProjectDir -ChildPath "project.json"

        Push-Location
        cd $projectDir
        $repoRelativeDir = (Resolve-Path -Path $PowerBuild.RepoDir -Relative).Replace('\', '/')
        Pop-Location


        # --------
        # skip if project file not found
        # --------
        if (-not (Test-Path $projectBsdFile -PathType Leaf))
        {
            say "Unable to find project file. Project will not be compiled: $projectBsdFile" -v 0
            continue
        }

        $hasTestProject = $false
        if ($PowerBuild.AvailableProjectTargets -contains "$projectName.Tests")
        {
            if (-not (Test-Path $testProjectBsdFile -PathType Leaf))
            {
                Write-Warning "Unable to find test project file. Unit test will not be performed: $testProjectBsdFile"
            }
            else
            {
                $hasTestProject = $true
            }
        }


        # --------
        # resolve project bsd files
        # source\*.bsd > tools\buildscript\configs\*.bsd > (projectDir)\*.bsd
        # source\global.bsd is implied
        # --------

        # resolve all include files
        # globalBsdFile is not empty. hasGlobalBsdFile has the test-path result
        $projectBsdIncludeFiles = ResolveProjectBsdFileList -UseGlobalBsd:$PowerBuild.HasGlobalBsdFile -GlobalBsdPath $PowerBuild.GlobalBsdFile -ProjectBsdPath $projectBsdFile

        # parse all bsd
        $projectInfo = ParseBsdFiles -BsdFiles $projectBsdIncludeFiles -Prefix @{
            'repoName' = $PowerBuild.RepoName
            'projectDir' = $projectName
            'projectPath' = $projectDir.Replace('\', '/').TrimEnd('/')
            'repoDir' = $PowerBuild.RepoDir.Replace('\', '/').TrimEnd('/')
            'repoDir-relative' = $repoRelativeDir
            'credentialDir' = $PowerBuild.CredentialDir
            'version-build' = $PowerBuild.GlobalBuildNum
        }

        # check
        if (-not $projectInfo.projectType)
        {
            say "[!] Project type is undefined." -v 0
            continue
        }
        elseif ("builder-$($projectInfo.projectType).ps1" -notin $supportedBuilders)
        {
            say "[!] The project type is not supported. Install a compatible builder and try again: $($projectInfo.projectType)" -v 0
            continue
        }
        else
        {
            say ("[i] Project is of type: {0}" -f $projectInfo.projectType)
        }

        Push-Location
        cd $projectDir
        $repoRelativeDir = (Resolve-Path -Path $PowerBuild.RepoDir -Relative).Replace('\', '/')

        if ($hasTestProject)
        {
            say ('[i] Unit test will be performed')

            $testProjectBsdIncludeFiles = ResolveProjectBsdFileList -UseGlobalBsd:$PowerBuild.HasGlobalBsdFile -GlobalBsdPath $PowerBuild.GlobalBsdFile -ProjectBsdPath $testProjectBsdFile
            $testProjectInfo = ParseBsdFiles -BsdFiles $testProjectBsdIncludeFiles -Prefix @{
	            'repoName' = $PowerBuild.RepoName
	            'repoDir' = $PowerBuild.RepoDir.Replace('\', '/').TrimEnd('/')
                'repoDir-relative' = $repoRelativeDir
                'projectDir' = $testProjectName
	            'projectPath' = $testProjectDir.Replace('\', '/').TrimEnd('/')
	            'credentialDir' = $PowerBuild.CredentialDir
                'version-build' = $PowerBuild.GlobalBuildNum
            }
        }
        else
        {
            $testProjectInfo = [PSObject]@{}
        }


        # launch builder
        $builderProperties = @{
            ProjectName = $projectName
            ProjectInfo = $projectInfo
            TestProjectInfo = $testProjectInfo
            Configuration = $Configuration
            RepoRelativeDir = $repoRelativeDir
            ProjectDir = $projectDir
            ProjectBsdFile = $projectBsdFile
            HasTestProject = $hasTestProject
            TestProjectName = $testProjectName
            TestProjectDir = $testProjectDir
            TestProjectBsdFile = $testProjectBsdFile
            CredentialDir = $PowerBuild.CredentialDir
        }

        Invoke-PowerBuild (Join-Path $PSScriptRoot -ChildPath "builder-$($projectInfo.projectType).ps1") -NoLogo -Properties $builderProperties
        continue
    }
}

task Finish -depends Build {
    say 'My work here is done'
    say 'Good bye :)'
    say -NewLine -LineCount 5
}
