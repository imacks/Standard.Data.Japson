Function New-ResourceFile
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

    Function TransformCsvStringData
    {
        Param([String]$CsvPath)

        $dataFromCsv = (Get-Content $CsvPath) | ConvertFrom-Csv -Header Name, Locale, Value
        $adjustedProperties = @{}

        $allPrivateConsts = @()
        $dataFromCsv | sort -Property Name, Locale | % {
            $privateName = $_.Name.Substring(0, 1).ToLower() + $_.Name.Substring(1)
            $privateNameWithLocale = '{0}_{1}' -f $privateName, $_.Locale.Replace('-', '_').ToLower()

            $valueEscaped = EscapeString $_.Value '``' '~'
            $valueEscaped = $valueEscaped.Replace(
                '`n', [Environment]::NewLine
            ).Replace(
                '`"', '""'
            ).Replace(
                '`t', "`t"
            )
            $valueEscaped = UnescapeString $valueEscaped '``' '~'
            $valueEscaped = $valueEscaped.Replace('``', '`')

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
                PrivateNameForDefaultLocale = '{0}_en_us' -f $privateName
                Locales = $locales
            }
        }
        $adjustedProperties.PublicProperties = $allPublicProperties

        return $adjustedProperties     
    }

    Function EscapeString
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

    Function UnescapeString
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

    If (Test-Path $dataFile -PathType Leaf)
    {
        # $tmplData.NamePadLength = $tmplData.Properties | % { $_.Name.Length } | sort -Descending | select -First 1

        $tmplData = @{
            AssemblyName = $BuildObject.Name
            Properties = (TransformCsvStringData -CsvPath $dataFile)
        }

        $targetPath = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.Designer{1}" -f $BuildObject.Name, $BuildObject.ProgramLanguageExtension)
        If (-not (Test-Path $targetPath))
        {
            if (-not (Test-Path (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.Name))))
            {
                md (Join-Path $SourceRoot -ChildPath ("{0}/Properties" -f $BuildObject.Name)) -Force | Out-Null
            }
            $tmplScript = (Get-Content $TemplateFile) -join [Environment]::NewLine
            Expand-PSTemplate -Template $tmplScript -DataBinding $tmplData | Set-Content $targetPath -Force
        }
    }

    If ($BuildObject.TestsName)
    {
        $dataFile = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.csv" -f $BuildObject.TestsName)
        If (Test-Path $dataFile -PathType Leaf)
        {
            $tmplData = @{
                AssemblyName = $BuildObject.TestsName
                Properties = (TransformCsvStringData -CsvPath $dataFile)
            }

            $targetPath = Join-Path $SourceRoot -ChildPath ("{0}/Properties/StringData.Designer{1}" -f $BuildObject.TestsName, $BuildObject.ProgramLanguageExtension)
            If (-not (Test-Path $targetPath))
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
