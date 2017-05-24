properties {
    [string]$ProjectName = '<undefined>'
    [PSObject]$ProjectInfo = $null
    [string]$Configuration = 'Release'
    [switch]$Force = $false
}


# --- overrides ---

formatTaskName {
    param($taskName)

    $expandedTitle = @{
        'MigrateMSBuild' = 'Create MSBuild make file'
        'PackageRestore' = 'Restore NuGet packages'
        'GenTemplates' = 'Generate code from templates'
        'GenAssemblyMetaInfo' = 'Generate assembly metainfo code'
        'LocalizationResGen' = 'Generate resource code'
        'GenTestMakeFile' = 'Create project.json file for unit test'
        'GenMakeFile' = 'Create project.json file'
    }

    if ($expandedTitle.ContainsKey($taskName))
    {
        $taskName = $expandedTitle."$taskName"
    }

    say -NewLine -LineCount 2
    say "*******************************" -ForegroundColor Blue
    say "$taskName                      " -ForegroundColor Blue
    say "*******************************" -ForegroundColor Blue
}

# --- /overrides ---


# --- helpers ---

function ConvertToProjectJson
{
    Param(            
        $InputObject,
        [string]$OutFile
    )

    $projectJsonSchemaKeys = @(
        'name'
        'title'
        'version'
        'authors'
        'embedInteropTypes'
        'language'
        'copyright'
        'description'
        'userSecretsId'
        'dependencies'
        'frameworks'
        'runtimes'
        'tools'
        'configurations'
        'buildOptions'
        'packOptions'
        'scripts'
        'runtimeOptions'
        'shared'
        'files'
        'testRunner'
        'publishOptions'
    )

    $projectJsonObject = [PSObject]@{}
    $InputObject | Get-Member -MemberType NoteProperty | select -expand Name | ForEach-Object {
        if ($_ -in $projectJsonSchemaKeys)
        {
            $projectJsonObject | Add-Member -MemberType NoteProperty -Name $_ -Value $InputObject."$_"
        }
        else
        {
            # debug message
            say ('### exclude project.json: {0}' -f $_) -v 5
        }
    }

    ($projectJsonObject | ConvertTo-Json -Depth 32) | Set-Content -Path $OutFile
}

function New-AssemblyInfoFile
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            Test-Path $_ -PathType Leaf
        })]
        [String]$TemplateFile,

        [Parameter(Mandatory = $true)]
        [String]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [Hashtable]$BuildObject
    )

    $targetPath = Join-Path $SourceRoot -ChildPath ("{0}/Properties/Project.AssemblyInfo{1}" -f $BuildObject.Name, $BuildObject.ProgramLanguageExtension)
    if (-not (Test-Path $targetPath))
    {
        if (-not (Test-Path (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.Name))))
        {
            md (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.Name)) -Force | Out-Null
        }
        $tmplScript = (Get-Content $TemplateFile) -join [Environment]::NewLine
        Expand-PSTemplate -Template $tmplScript -DataBinding $BuildObject | Set-Content $targetPath -Force
    }
}

function New-ResourceFile
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({
            Test-Path $_ -PathType Leaf
        })]
        [String]$TemplateFile,

        [Parameter(Mandatory = $true, Position = 2)]
        [ValidateScript({
            Test-Path $_ -PathType Leaf
        })]
        [String]$ResxTemplateFile,

        [Parameter(Mandatory = $true)]
        [String]$SourceRoot,

        [Parameter(Mandatory = $true)]
        [Hashtable]$BuildObject
    )

    function TransformCsvStringData
    {
        Param([String]$CsvPath)

        $dataFromCsv = (Get-Content $CsvPath) | ConvertFrom-Csv -Delimiter '|' -Header Name, Locale, Value
        $adjustedProperties = @{}

        $allPrivateConsts = @()
        $dataFromCsv | sort -Property Name, Locale | % {
            # Name|Locale|Value
            # foo|en-US|some text => Foo_en_us
            $privateName = $_.Name.Substring(0, 1).ToLower() + $_.Name.Substring(1)
            $privateNameWithLocale = '{0}_{1}' -f $privateName, $_.Locale.Replace('-', '_').ToLower()
            
            # CSV value 101 (using | as separator)
            # ------------------------------------
            # !> if value doesn't contain " or |, just write it
            #    --> some text => some text
            # !> if value contains | but not ", quote the string
            #    --> "some | text" => some text
            # !> if value contains " but not |, just write it
            #    --> some "t"e""xt => some "t"e""xt
            # !> if value contains both " and |, quote it and double char to escape
            #    --> "some | ""text" => some | "text
            #
            # Custom extensions we have invented:
            # ------
            # -> `t = tab
            # -> `n = newline
            # -> `` = `
            # So if value contains '`t', write as ``t

            $valueEscaped = EscapeString $_.Value '``' '~'
            $valueEscaped = $valueEscaped.Replace(
                '`n', [Environment]::NewLine
            ).Replace(
                '`t', "`t"
            )
            $valueEscaped = UnescapeString $valueEscaped '``' '~'
            $valueEscaped = $valueEscaped.Replace('``', '`')

            # xml escaping
            # &quot; &apos; &lt; &gt; &amp;
            $valueEscaped = $valueEscaped.Replace(
                # replace & first or the rest messes up
                '&', '&amp;'
            ).Replace(
                '"', '&quot;'
            ).Replace(
                "'", '&apos;'
            ).Replace(
                '<', '&lt;'
            ).Replace(
                '>', '&gt;'
            )

            $allPrivateConsts += @{
                PrivateNameWithLocale = $privateNameWithLocale
                ValueEscaped = $valueEscaped
            }
        }
        $adjustedProperties.PrivateConsts = $allPrivateConsts

        $allPublicProperties = @()
        $uniqueNames = $dataFromCsv | select -expand Name | select -unique
        $uniqueNames | % { 
            $name = $_
            $privateName = $name.Substring(0, 1).ToLower() + $name.Substring(1)
            $publicName = $name.Substring(0, 1).ToUpper() + $name.Substring(1)

            $locales = @()
            $dataFromCsv | where { $_.Name -eq $name } | % {
                $localeName = $_.Locale
                $privateLocaleName = '{0}_{1}' -f $privateName, $localeName.Replace('-', '_').ToLower()

                $locales += @{
                    LocaleName = $localeName
                    PrivateNameForLocale = $privateLocaleName
                }
            }

            $allPublicProperties += @{
                PublicName = $publicName
                PrivateName = $privateName
                PrivateNameForDefaultLocale = '{0}_en_us' -f $privateName
                Locales = $locales
            }
        }
        $adjustedProperties.PublicProperties = $allPublicProperties

        return $adjustedProperties     
    }

    function EscapeString
    {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true, Position = 1)]
            [String]$InputObject,

            [Parameter(Mandatory = $true, Position = 2)]
            [String]$Reserved,

            [Parameter(Mandatory = $true, Position = 3)]
            [String]$EncodeAs
        )

        $InputObject.Replace($EncodeAs, $EncodeAs + '2').Replace($Reserved, $EncodeAs + '1')
    }

    function UnescapeString
    {
        [CmdletBinding()]
        Param(
            [Parameter(Mandatory = $true, Position = 1)]
            [String]$InputObject,

            [Parameter(Mandatory = $true, Position = 2)]
            [String]$Reserved,

            [Parameter(Mandatory = $true, Position = 3)]
            [String]$EncodeAs
        )

        $InputObject.Replace($EncodeAs + '1', $Reserved).Replace($EncodeAs + '2', $EncodeAs)
    }

    $dataFile = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.csv" -f $BuildObject.Name)

    if (Test-Path $dataFile -PathType Leaf)
    {
        $tmplData = @{
            AssemblyName = $BuildObject.Name
            Properties = (TransformCsvStringData -CsvPath $dataFile)
        }

        $resxTargetPath = Join-Path $SourceRoot -ChildPath ("{0}/Embed/Messages.resx" -f $BuildObject.Name)
        if (-not (Test-Path $resxTargetPath))
        {
            if (-not (Test-Path (Split-Path $resxTargetPath -Parent)))
            {
                md (Split-Path $resxTargetPath -Parent) -Force | Out-Null
            }
            $tmplScript = (Get-Content $ResxTemplateFile) -join [Environment]::NewLine
            Expand-PSTemplate -Template $tmplScript -DataBinding $tmplData | Set-Content $resxTargetPath -Force
        }




        $targetPath = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.Designer{1}" -f $BuildObject.Name, $BuildObject.ProgramLanguageExtension)
        if (-not (Test-Path $targetPath))
        {
            if (-not (Test-Path (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.Name))))
            {
                md (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.Name)) -Force | Out-Null
            }
            $tmplScript = (Get-Content $TemplateFile) -join [Environment]::NewLine
            Expand-PSTemplate -Template $tmplScript -DataBinding $tmplData | Set-Content $targetPath -Force
        }
    }

    if ($BuildObject.TestsName)
    {
        $dataFile = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.csv" -f $BuildObject.TestsName)
        if (Test-Path $dataFile -PathType Leaf)
        {
            $tmplData = @{
                AssemblyName = $BuildObject.TestsName
                Properties = (TransformCsvStringData -CsvPath $dataFile)
            }

            $targetPath = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.Designer{1}" -f $BuildObject.TestsName, $BuildObject.ProgramLanguageExtension)
            if (-not (Test-Path $targetPath))
            {
                if (-not (Test-Path (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.TestsName))))
                {
                    md (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.TestsName)) -Force | Out-Null
                }
                Expand-PSTemplate -Template $tmplScript -DataBinding $tmplData | Set-Content $targetPath -Force
            }
        }
    }
}

# --- /helpers ---


task default -depends Finalize

task Setup {
    # ~~~~~~~~~~~~~~~~~
    # set up DotNetCore
    # ~~~~~~~~~~~~~~~~~
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = 1
    if (-not $env:Path.Contains(';' + $PowerBuild.DotNetCoreDir))
    {
        say ('[i] Adding .NETCore SDK to environment path: {0}' -f $PowerBuild.DotNetCoreDir)
        $env:Path += ';' + $PowerBuild.DotNetCoreDir
    }
    assert ((dotnet --version) -eq '1.0.4') 'Requires .NETCore 1.0.4 with SDK'


    # ~~~~~~~~~~~~~~~~~
    # import helpers
    # ~~~~~~~~~~~~~~~~~
    say ('[i] Importing helper modules')
    @(
        'PowerTemplate.psm1'
        'GenResFile.ps1'
        #'GenAssemblyInfo.ps1'
    ) | ForEach-Object {
        say ('* {0}' -f $_) -v 2
        ipmo (Join-Path $PowerBuild.BuildScriptDir -ChildPath $_) -Force
    }
}

task GenMakeFile -depends Setup {
    $projectJsonFile = Join-Path $ProjectDir -ChildPath "project.json"
    $PowerBuild.ProjectJsonFile = $projectJsonFile
    
    # ----------------
    # generate project.json
    # ----------------
    ConvertToProjectJson -InputObject $ProjectInfo -OutFile $projectJsonFile

    if ($HasTestProject)
    {
        ConvertToProjectJson -InputObject $TestProjectInfo -OutFile $testProjectJsonFile

        # ensure test project is internally visible to main project
        # does not need to write back to file
        if ((-not $ProjectInfo.internalsVisibleTo) -or 
            ($ProjectInfo.internalsVisibleTo | where { ($_ -eq $ProjectName) -or ($_.name -eq $ProjectName) }))
        {
            say ('[i] Ensuring that the unit test has internal access to the project')

            if (-not ($ProjectInfo | Get-Member -MemberType NoteProperty -Name 'internalsVisibleTo'))
            {
                $ProjectInfo | Add-Member -MemberType NoteProperty -Name 'internalsVisibleTo' -Value @()
            }

            $ProjectInfo.internalsVisibleTo += $(
                if ((-not $TestProjectInfo.publicKeyToken) -or ($Configuration -eq 'Debug')) 
                { 
                    $TestProjectInfo.name 
                }
                else 
                {
                    [PSCustomObject]@{
                        Name = $TestProjectInfo.name
                        PublicKeyToken = $TestProjectInfo.publicKeyToken
                    }  
                }
            )
        }
    }

    # debug
    say ($ProjectInfo | ConvertTo-Json -Depth 32) -v 5
    if ($HasTestProject) 
    { 
        say ($TestProjectInfo | ConvertTo-Json -Depth 32) -v 5
    }
}

task GenTestMakeFile -depends Setup -precondition { $HasTestProject -eq $true } {
    $PowerBuild.TestProjectJsonFile = Join-Path $TestProjectDir -ChildPath "project.json"
    $testProjectJsonFile = $PowerBuild.TestProjectJsonFile

    ConvertToProjectJson -InputObject $TestProjectInfo -OutFile $testProjectJsonFile

    # ensure test project is internally visible to main project
    # does not need to write back to file
    if ((-not $ProjectInfo.internalsVisibleTo) -or 
        ($ProjectInfo.internalsVisibleTo | where { ($_ -eq $ProjectName) -or ($_.name -eq $ProjectName) }))
    {
        say ('[i] Ensuring that the unit test has internal access to the project')

        if (-not ($ProjectInfo | Get-Member -MemberType NoteProperty -Name 'internalsVisibleTo'))
        {
            $ProjectInfo | Add-Member -MemberType NoteProperty -Name 'internalsVisibleTo' -Value @()
        }

        $ProjectInfo.internalsVisibleTo += $(
            if ((-not $TestProjectInfo.publicKeyToken) -or ($Configuration -eq 'Debug')) 
            { 
                $TestProjectInfo.name 
            }
            else 
            {
                [PSCustomObject]@{
                     Name = $TestProjectInfo.name
                     PublicKeyToken = $TestProjectInfo.publicKeyToken
                }  
            }
        )
    }
}

task LocalizationResGen -depends Setup -precondition { 
    ((Test-Path (Join-Path $ProjectDir -ChildPath 'Properties/StringData.csv'))) -eq $true 
} {
    if ($ProjectInfo.buildOptions.compilerName -eq 'csc')
    {
        say ('[i] Generating string resource code')

        $resgenParams = @{
            TemplateFile = (Join-Path $PowerBuild.BuildScriptDir -ChildPath 'RS.Designer.cs.pstmpl')
            ResxTemplateFile = (Join-Path $PowerBuild.BuildScriptDir -ChildPath 'Messages.resx.pstmpl')
            SourceRoot = $PowerBuild.WorkingSourceDir
            BuildObject = @{
                ProgramLanguageExtension = '.cs'
                Name = $ProjectName
                TestsName = $(
                    if ($HasTestProject -and ($TestProjectInfo.buildOptions.compilerName -eq 'csc')) { "$ProjectName.Tests" } 
                    else { '' }
                )
            }
        }
        New-ResourceFile @resgenParams
    }
    else
    {
        say ('[!] String resource code cannot be generated because the compiler is unsupported: {0}' -f $ProjectInfo.buildOptions.compilerName) -v 0
    }
}

task GenAssemblyMetaInfo -depends Setup -precondition {
    (Test-Path (Join-Path $ProjectDir -ChildPath 'Properties/AssemblyInfo.cs')) -eq $false
} {
    if (-not $HasTestProject)
    {
        $targets = @($ProjectInfo)
    }
    else
    {
        $targets = @($ProjectInfo, $TestProjectInfo)
    }
    
    $targets | ForEach-Object {
        if ($_.buildOptions.compilerName -eq 'csc')
        {
            say ('[i] Generating assembly metadata code for {0}' -f $_.name)

            $assemblyFullVersion = $(
                if ($_.version -like '*-*') { $_.version.Substring(0, $_.version.IndexOf('-')) } 
                else { $_.version }
            )
            
            $assemblyVersion = @{
                major = [version]$assemblyFullVersion.Major
                minor = [version]$assemblyFullVersion.Minor
                build = [version]$assemblyFullVersion.Build
                revision = [version]$assemblyFullVersion.Revision
            }
            
            @('major', 'minor', 'build', 'revision') | ForEach-Object { 
                if ($assemblyVersion."$_" -lt 0) { $assemblyVersion."$_" = '0' } 
            }

            $assemblyInfoData = @{
                ProgramLanguageExtension = '.cs'
                Name = $_.name
                isUnitTest = $($HasTestProject -and ($_.testRunner -ne $null))
                company = $_.company
                copyright = $_.copyright 
                description = $_.description
                language = $_.language
                fileName = $_.name + $(if ($_.buildOptions.emitEntryPoint) { '.exe' } else { '.dll' })
                product = $_.product
                trademark = $_.trademark
                clsCompliant = $_.clsCompliant
                comGuid = $_.comGuid
                publicKeyToken = $_.publicKeyToken
                allowPartialTrust = $_.allowPartialTrust
                internalsVisibleTo = $_.internalsVisibleTo
                fullversion = $assemblyFullVersion
                version = $assemblyVersion
            }
            New-AssemblyInfoFile -TemplateFile (Join-Path $PowerBuild.BuildScriptDir -ChildPath 'Project.AssemblyInfo.cs.pstmpl') -SourceRoot $PowerBuild.WorkingSourceDir -BuildObject $assemblyInfoData
        }
        else
        {
            say ('Assembly metadata code cannot be generated for {0} because the compiler is unsupported: {1}' -f $_.name, $_.buildOptions.compilerName) -v 0
        }
    }
}

task GenTemplates -depends Setup {
    if (Test-Path (Join-Path $ProjectDir -ChildPath 'Templates'))
    {
        dir (Join-Path $ProjectDir -ChildPath 'Templates/*.pstmpl') | where { $_ -ne $null } | ForEach-Object {
            say ('[i] Generating code from template: {0}' -f $_)

            Expand-PSTemplate -Template $_.FullName -DataBinding $ProjectInfo | Set-Content $_.FullName.TrimEnd('.pstmpl') -Force
        }
    }

    if ($HasTestProject -and (Test-Path (Join-Path $TestProjectDir -ChildPath 'Templates')))
    {
        dir (Join-Path $TestProjectDir -ChildPath 'Templates/*.pstmpl') | where { $_ -ne $null } | ForEach-Object {
            say ('[i] Generating code from template: {0}' -f $_)

            Expand-PSTemplate -Template $_.FullName -DataBinding $TestProjectInfo | Set-Content $_.FullName.TrimEnd('.pstmpl') -Force
        }
    }
}

task MigrateMSBuild -depends GenMakeFile, GenTestMakeFile, LocalizationResGen, GenAssemblyMetaInfo {
    $projectJsonFile = $PowerBuild.ProjectJsonFile

    dotnet migrate $projectJsonFile --skip-project-references --skip-backup
    $projectFile = Join-Path (Split-Path $projectJsonFile -Parent) -ChildPath "$ProjectName.csproj"
    $PowerBuild.ProjectFile = $projectFile
    
    if ($HasTestProject)
    {
        $testProjectJsonFile = $PowerBuild.TestProjectJsonFile
        dotnet migrate $testProjectJsonFile --skip-project-references --skip-backup

        $testProjectFile = Join-Path (Split-Path $testProjectJsonFile -Parent) -ChildPath "$ProjectName.Tests.csproj"

        #patch hack for migration bug with xunit
        if ($TestProjectInfo.testRunner -eq 'xunit')
        {
            $testProjectFileContent = (Get-Content $testProjectFile) -join [Environment]::NewLine
            $testProjectFileContent = $testProjectFileContent.Replace(
                '<PackageReference Include="xunit.runner.visualstudio" Version="2.2.0-beta5-build1225" />',
                ''
            ).Replace(
                '<PackageReference Include="xunit" Version="2.2.0-beta5-build3474" />',
                ('<PackageReference Include="xunit" Version="{0}" />' -f $(
                    if ($TestProjectInfo.dependencies.xunit.version) { $TestProjectInfo.dependencies.xunit.version } 
                	elseif ($TestProjectInfo.dependencies.xunit) { $TestProjectInfo.dependencies.xunit } 
                	else { '2.3.0-beta2-build3683' }
                ))
            )

            $testProjectFileContent | Set-Content -Path $testProjectFile
        }

        $PowerBuild.TestProjectFile = $testProjectFile
    }
}

task PackageRestore -depends MigrateMSBuild {
    say ('[i] Restoring dependency packages for {0}' -f $ProjectName)
    dotnet restore $PowerBuild.ProjectFile --configfile (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'NuGet.config') --verbosity Normal | Out-Default
}

task Compile -depends PackageRestore {
    $projectFile = $PowerBuild.ProjectFile

    $projectTfmNames = $ProjectInfo | select -expand frameworks | Get-Member -MemberType NoteProperty | select -expand Name
    $PowerBuild.ProjectTfmNames = $projectTfmNames

    foreach ($tfm in $projectTfmNames) 
    {
        $buildOutputPath = Join-Path $ProjectDir -ChildPath "bin/$Configuration/$tfm"

        if (($ProjectInfo.noCompile -eq $tfm) -or ($ProjectInfo.noCompile -contains $tfm))
        {
            say ('* Compilation of target {0} has been disabled.' -f $tfm) -v 2
            continue
        }

        
        if ($ProjectInfo.buildOptions.emitEntryPoint -and 
            $ProjectInfo.runtimes -and 
            (($tfm -like 'netstandard*') -or ($tfm -like 'netcoreapp*')))
        {
            $rids = $ProjectInfo.runtimes | Get-Member -MemberType NoteProperty | select -expand Name
            foreach ($rid in $rids)
            {
                say ('* Targeting {0}/{1}' -f $tfm, $rid) -v 2
                dotnet publish $projectFile -f $tfm -r $rid -c $Configuration | Out-Default                                    
            }
        }
        else 
        {
            say ('* Targeting {0}' -f $tfm) -v 2
            dotnet build $projectFile -f $tfm -c $Configuration -o $buildOutputPath | Out-Default
        }
    }
}

task UnitTest -depends Compile -precondition { $HasTestProject -eq $true } {
    $testProjectTfmNames = $TestProjectInfo | select -expand frameworks | Get-Member -MemberType NoteProperty | select -expand Name
    $projectTfmNames = $PowerBuild.ProjectTfmNames
    $testProjectFile = $PowerBuild.TestProjectFile

    if ($TestProjectInfo.testRunner -eq 'xunit')
    {
        say ('[i] Restoring dependency packages for {0}' -f $TestProjectInfo.name)
        dotnet restore $testProjectFile --configfile (Join-Path $PowerBuild.WorkingSourceDir -ChildPath 'NuGet.config') --verbosity Normal | Out-Default

        say ('[i] Running unit test using {0}' -f 'xunit')
        foreach ($tfm in $testProjectTfmNames)
        {
            $testReportXmlFileName = "Report-$tfm-$projectName.xml"

            foreach ($tfmRedirect in $TestTFMRedirect.Keys)
            {
                if ($tfm -like $tfmRedirect)
                {
                    say ('[!] Target framework is obsolete: {0} -> {1}' -f $tfm, $PowerBuild.TestTFMRedirect."$tfmRedirect") -v 0

                    $tfm = $TestTFMRedirect."$tfmRedirect"
                    break
                }
            }
            
            say ('* Targeting {0}' -f $tfm) -v 2

            $testReportXmlPath = Join-Path $TestProjectDir -ChildPath "bin/$Configuration/$tfm/$testReportXmlFileName"
            say ('[i] See report at {0}' -f $testReportXmlPath)

            # dotnet xunit unlike dotnet test is not global. you need to exec it in the project's folder.
            Push-Location
            cd (Split-Path $testProjectFile -Parent)
            if ($tfm -like 'net4*')
            {
                dotnet xunit -f $tfm -c $Configuration -xml $testReportXmlPath -noshadow | Out-Default
            }
            else
            {
                dotnet xunit -f $tfm -c $Configuration -xml $testReportXmlPath | Out-Default
            }                
            
            Pop-Location
        }
    }
    elseif ($TestProjectInfo.testRunner -eq 'pester')
    {
        say ('[i] Running unit test using {0}' -f 'pester')
        foreach ($tfm in $projectTfmNames)
        {
            $testReportXmlFileName = "Report-$tfm-$ProjectName.xml"
            say ('* Targeting {0}' -f $tfm) -v 2

            $testReportXmlPath = Join-Path $TestProjectDir -ChildPath "bin/$Configuration/$tfm/$testReportXmlFileName"
            if (-not (Test-Path (Split-Path $testReportXmlPath -Parent)))
            {
                md (Split-Path $testReportXmlPath -Parent) -Force | Out-Null
            }
            
            say ('[i] See report at {0}' -f $testReportXmlPath)

            Invoke-Pester -Script @{ 
                Path = $(Join-Path $TestProjectDir -ChildPath 'Source/*')
                Parameters = @{ 
                    CmdletLoadPath = $(Join-Path $ProjectDir -ChildPath "bin/$Configuration/$tfm/$($ProjectInfo.psManifestFile)")
                }
            } -PassThru -OutputFile $testReportXmlPath -OutputFormat NUnitXml
        }
    }
}

task Pack -depends Compile, UnitTest -precondition { $Configuration -eq 'Release' } {
    if (-not (Test-Path $PowerBuild.OutputSymbolsDir -PathType Container))
    {
        if (Test-Path $PowerBuild.OutputSymbolsDir -PathType Leaf)
        {
            del $PowerBuild.OutputSymbolsDir -Force
        }

        md $PowerBuild.OutputSymbolsDir -Force | Out-Null
    }

    $pkgFileVersion = $(
        if ($ProjectInfo.version.EndsWith('.0')) 
        { 
            $ProjectInfo.version.Substring(0, $ProjectInfo.version.Length - 2) 
        } 
        elseif ($ProjectInfo.version -like '*.0-*')
        {
            $ProjectInfo.version.Substring(0, $ProjectInfo.version.IndexOf('-') - 2) + $ProjectInfo.version.Substring($ProjectInfo.version.IndexOf('-'))
        }
        else { $ProjectInfo.version }
    )
    $PowerBuild.PkgFileVersion = $pkgFileVersion
    
    $pkgOutputPath = Join-Path $PowerBuild.OutputDir -ChildPath ('{0}.{1}.nupkg' -f $ProjectName, $pkgFileVersion)
    $pkgSymbolsOutputPath = Join-Path $PowerBuild.OutputDir -ChildPath ('{0}.{1}.symbols.nupkg' -f $ProjectName, $pkgFileVersion)

    say ('[i] Generating project package: {0}' -f $PowerBuild.OutputDir)
    dotnet pack $ProjectDir -o $PowerBuild.OutputDir --no-build -c Release --include-symbols
    move $pkgSymbolsOutputPath $PowerBuild.OutputSymbolsDir -Force

    if ($HasTestProject)
    {
        $pkgTestFileVersion = $(
            if ($TestProjectInfo.version.EndsWith('.0')) 
            { 
                $TestProjectInfo.version.Substring(0, $TestProjectInfo.version.Length - 2) 
            }
            elseif ($testProjectInfo.version -like '*.0-*')
            {
                $TestProjectInfo.version.Substring(0, $TestProjectInfo.version.IndexOf('-') - 2) + $TestProjectInfo.version.Substring($TestProjectInfo.version.IndexOf('-'))
            }                 
            else { $TestProjectInfo.version }
        )
        $PowerBuild.PkgTestFileVersion = $pkgTestFileVersion
        
        $pkgTestOutputPath = Join-Path $PowerBuild.OutputDir -ChildPath ('{0}.Tests.{1}.nupkg' -f $ProjectName, $pkgTestFileVersion)
        $pkgTestSymbolsOutputPath = Join-Path $PowerBuild.OutputDir -ChildPath ('{0}.Tests.{1}.symbols.nupkg' -f $ProjectName, $pkgTestFileVersion)

        say ('[i] Generating unit test package: {0}' -f $PowerBuild.OutputDir)
        dotnet pack $TestProjectDir -o $PowerBuild.OutputDir --no-build -c Release --include-symbols
        move $pkgTestSymbolsOutputPath $PowerBuild.OutputSymbolsDir -Force
    }
}

task Publish -depends Pack -precondition { $Configuration -eq 'Release' } {
    $pkgUploadFile = Join-Path $PowerBuild.OutputDir -ChildPath ('{0}.{1}.nupkg' -f $ProjectName, $PowerBuild.PkgFileVersion)

    say ('[i] Copying package to local storage: {0} -> {1}' -f $pkgUploadFile, $PowerBuild.LocalPackageOutputDir)
    if (-not (Test-Path $PowerBuild.LocalPackageOutputDir -PathType Container))
    {
        if (Test-Path $PowerBuild.LocalPackageOutputDir -PathType Leaf)
        {
            del $PowerBuild.LocalPackageOutputDir -Force
        }
        md $PowerBuild.LocalPackageOutputDir | Out-Null
    }
    copy $pkgUploadFile $PowerBuild.LocalPackageOutputDir -Force

    if ($PowerBuild.UploadToNuget)
    {
        say ('[i] Pusing package to NuGet server: {0}' -f $pkgUploadFile)
        dotnet nuget push $pkgUploadFile --api-key $PowerBuild.NugetConfig.ApiKey --source $PowerBuild.NugetConfig.PushSource       
    }

    if ($HasTestProject)
    {
        $pkgTestUploadFile = Join-Path $PowerBuild.OutputDir -ChildPath ('{0}.Tests.{1}.nupkg' -f $ProjectName, $PowerBuild.PkgTestFileVersion)
        say ('[i] Copying package to local storage: {0} -> {1}' -f $pkgTestUploadFile, $PowerBuild.LocalPackageOutputDir)
        copy $pkgTestUploadFile $PowerBuild.LocalPackageOutputDir -Force

        if ($PowerBuild.UploadToNuget)
        {
            say ('[i] Pushing package to NuGet server: {0}' -f $pkgTestUploadFile)
            dotnet nuget push $pkgTestUploadFile --api-key $PowerBuild.NugetConfig.ApiKey --source $PowerBuild.NugetConfig.PushSource
        }
    }
}

task Finalize -depends Compile, UnitTest, Publish {
    say ('Build complete: {0}' -f $ProjectName)
}
