Function New-AssemblyInfoFile
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
