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
        'GenerateTemplates' = 'Generate code from templates'
        'CopySourceToOutput' = 'Copy source scripts to output'
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


task default -depends Finalize

task Setup {
    $PowerBuild.ProjectSourceDir = Join-Path $ProjectDir -ChildPath 'Source'
    $PowerBuild.ProjectOutputDir = Join-Path $ProjectDir -ChildPath "bin/$Configuration"
    $PowerBuild.ProjectTemplateDir = Join-Path $ProjectDir -ChildPath 'Templates'

    say ('[i] Importing helper modules')
    @(
        'PowerTemplate.psm1'
    ) | ForEach-Object {
        say ('* {0}' -f $_) -v 2
        ipmo (Join-Path $PowerBuild.BuildScriptDir -ChildPath $_) -Force
    }

    $projectOutputDir = $PowerBuild.ProjectOutputDir
    if (-not (Test-Path $projectOutputDir -PathType Container))
    {
        md $projectOutputDir -Force | Out-Null
    }
    else
    {
        del $projectOutputDir -Recurse -Force
    }
}

task GenerateTemplates -depends Setup {
    $projectTemplateDir = $PowerBuild.ProjectTemplateDir

    if (Test-Path $projectTemplateDir -PathType Container)
    {
        $ProjectInfo.templates | Get-Member -MemberType NoteProperty | select -expand Name | ForEach-Object {
            $tmplWildcard = Join-Path $projectTemplateDir -ChildPath $_
            $tmplFiles = dir $tmplWildcard -Recurse | select -expand FullName
            $tmplDataRootPath = $ProjectInfo.templates."$_".dataPath
            $tmplOutputRootPath = $ProjectInfo.templates."$_".outputDir
            say ('[i] Templates {0}' -f $tmplWildcard)

            foreach ($tmplFile in $tmplFiles)
            {
                $tmplName = $tmplFile.Substring($projectTemplateDir.Length + 1).Replace('\', '/')
        	    if ($tmplName.EndsWith('.pstmpl')) 
        	    { 
        	        $tmplName = $tmplName.Substring(0, $tmplName.Length - '.pstmpl'.Length) 
        	    }

        	    $tmplData = $projectInfo."$tmplDataRootPath"."$tmplName"
                if ($ProjectInfo."$tmplDataRootPath".shared)
                {
                    $ProjectInfo."$tmplDataRootPath".shared | Get-Member -MemberType NoteProperty | select -expand Name | ForEach-Object {
                        if (-not $tmplData."$_")
                        {
                            $tmplData | Add-Member -MemberType NoteProperty -Name $_ -Value $ProjectInfo."$tmplDataRootPath".shared."$_"
                        }
                    }
                }
        	    $tmplOutputPath = Join-Path $tmplOutputRootPath -ChildPath $tmplName

        	    say ('* {0} -> {1}' -f $tmplFile, $tmplOutputPath) -v 2
        	    Expand-PSTemplate -Template ((Get-Content $tmplFile) -join [Environment]::NewLine) -DataBinding $tmplData | Set-Content -Path $tmplOutputPath -Force
            }
        }
    }
}

task CopySourceToOutput -depends Setup {
    $projectSourceDir = $PowerBuild.ProjectSourceDir
    $projectOutputDir = $PowerBuild.ProjectOutputDir

    if (Test-Path $projectSourceDir -PathType Container)
    {
        say ('[i] Copying source to output folder...')
        copy "$projectSourceDir\*" $projectOutputDir -Recurse -Force
    }
    else
    {
        say ('[i] No source to copy.')
    }
}

task Finalize -depends GenerateTemplates, CopySourceToOutput {
    say ('All done.')
}
