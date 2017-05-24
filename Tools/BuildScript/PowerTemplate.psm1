#Requires -Version 2.0

If ($PSVersionTable.PSVersion.Major -ge 3)
{
    $script:IgnoreError = 'Ignore'
}
Else
{
    $script:IgnoreError = 'SilentlyContinue'
}

#######################################################################
#  Data
#######################################################################

DATA msgs 
{
    ConvertFrom-StringData @'
'@
}


#######################################################################
#  Public Module Functions
#######################################################################

Function Expand-PSTemplate
{
    <#
        .SYNOPSIS
            Render a text template using powershell.

        .DESCRIPTION

        .EXAMPLE
            @{
                'foo' = 'bar'
                'cars' = @('honda', 'ford', 'bmw')
                'fruits' = @{
                    'apple' = 'red'
                    'banana' = 'yellow'
                }
            } | Expand-PSTemplate @'
            I am rendered by the Powershell text template engine :)

            The value of foo is <%= $data.foo %>.

            Cars at index 0 is <%= $data.cars[0] %>.
            Here are all the cars:
            <% $data.cars | ForEach-Object { %>
            * <%= $_ %>
            <% } %>

            The color of fruit apple is <%= $data.fruits.apple %>
            Here are all the fruits and their colors:
            <% $data.fruits.Keys | ForEach-Object { %>
            * <%= $_ %> = <%= $data.fruits."$_" %>
            <% } %>

            If not in strict mode, you can use full powershell functions.
            You last wrote to C: on <%= (get-item C:\ | select -expand LastWriteTime).ToString() %>

            Peace out!

            '@

            DESCRIPTION
            -----------
            Outputs text using the specified template. Commands are enclosed in '<%' and '%>' qualifiers, and raw output is prepended with the equal ('=') sign.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1)]
        [String]$Template,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        $DataBinding
    )

    $delimStart = '<%'
    $delimEnd = '%>'
    $ps = Select-Substring -InputObject $Template -Preceding $delimStart -Succeeding $delimEnd -PassThru
    # force to array
    If (($ps -ne $null) -and ($ps.Count -eq $null))
    {
        $ps  = @($ps)
    }
    
    $enc = [System.Text.Encoding]::UTF8

    # this will be invoke-expression-ed
    $evalScript = [System.Text.StringBuilder]::new()
    $evalScript.AppendLine('Param($Data)') | Out-Null
    $evalScript.AppendLine('$enc = [System.Text.Encoding]::UTF8') | Out-Null
    $evalScript.AppendLine('$sb = [System.Text.StringBuilder]::new()') | Out-Null

    For ($i = 0; $i -lt $ps.Count; $i++)
    {
        If ($i -eq 0) { $payload = $Template.Substring(0, $ps[0].Preceding.Index) }
        Else
        {
            $payload = $Template.Substring($ps[$i - 1].Succeeding.Index + $delimEnd.Length, $ps[$i].Preceding.Index - $ps[$i - 1].Succeeding.Index - $delimEnd.Length)
        }

        # add preceding payload
        If ($payload)
        {            
            $payloadEnc = [Convert]::ToBase64String($enc.GetBytes($payload), [Base64FormattingOptions]::None)
            $evalScript.AppendLine('$sb.Append($enc.GetString([Convert]::FromBase64String(''{0}''))) | Out-Null' -f $payloadEnc) | Out-Null            
        }

        # add ps command
        If ($ps[$i].Substring)
        {
            If ($ps[$i].Substring.TrimStart().StartsWith('='))
            {
                $evalScript.AppendLine('$sb.Append((' + $ps[$i].Substring.TrimStart().Substring(1) + ')) | Out-Null') | Out-Null
            }
            Else
            {
                $evalScript.AppendLine($ps[$i].Substring) | Out-Null
            }
        }

        # add last payload
        If ($i -eq ($ps.Count - 1))
        {
            $payload = $Template.Substring($ps[$i].Succeeding.Index + $delimEnd.Length)
            If ($payload)
            {
                $payloadEnc = [Convert]::ToBase64String($enc.GetBytes($payload), [Base64FormattingOptions]::None)
                $evalScript.AppendLine('$sb.Append($enc.GetString([Convert]::FromBase64String(''{0}''))) | Out-Null' -f $payloadEnc) | Out-Null            
            }
        }
    }

    # finish off
    $evalScript.AppendLine('Return $sb.ToString()') | Out-Null

    # eval in a new runspace    
    $runspace = [runspacefactory]::CreateRunspace()
    $psInstance = [powershell]::Create()
    $psInstance.Runspace = $runspace
    $runspace.Open()
    [void]$psInstance.AddScript(
        $evalScript.ToString()
    ).AddArgument(
        $DataBinding
    )
    $result = $psInstance.Invoke()
    $psInstance.Dispose()
    $runspace.Dispose()

    Return $result
}

Function Select-Substring
{
    <#
        .SYNOPSIS
            Search for a substring that has the specified text appearing before and after it.

        .DESCRIPTION
            Using regex to seaech for indeterminate length patterns can have a big performance hit when text length increases. This command uses loops and substring indexes internally to allow faster searches for long strings.

            To obtain the position of each preceding, succeeding, and substring positions, use the 'PassThru' switch.

        .Example
            Select-Substring -InputObject "a !banana, and an !apple," -Before 'a', '!' -After ','
            #banana
            #apple
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [String]$InputObject,
    
        [Parameter(Mandatory = $true, Position = 2)]
        [Alias('Before')]
        [String[]]$Preceding,
    
        [Parameter(Mandatory = $true, Position = 3)]
        [Alias('After')]
        [String[]]$Succeeding,

        [Parameter(Mandatory = $false)]
        [Switch]$CaseSensitive,

        [Parameter(Mandatory = $false)]
        [ValidateSet('FixedExactlyOnce')]
        [String]$OrderBy = 'FixedExactlyOnce',

        [Parameter(Mandatory = $false)]
        [Switch]$PassThru
    )

    Begin
    {
        Function GetIndexOfTags([Int]$startIndex)
        {
            If (-not $CaseSensitive) { $searchData = $InputObject.ToLower() }
            Else { $searchData = $InputObject }

            $lastCursor = $startIndex

            $startTags = @()
            ForEach ($stag in $Preceding)
            {
                If (-not $CaseSensitive) { $stag = $stag.ToLower() }
                $thisCursor = $searchData.IndexOf($stag, $lastCursor)
                If ($thisCursor -eq -1) { Return $null }
                Else
                {
                    $startTags += [PSCustomObject]@{
                        'Value' = $InputObject.Substring($thisCursor, $stag.Length)
                        'Index' = $thisCursor
                        'Length' = $stag.Length
                    }

                    $lastCursor = $thisCursor + $stag.Length
                }
            }

            $endTags = @()
            ForEach ($stag in $Succeeding)
            {
                If (-not $CaseSensitive) { $stag = $stag.ToLower() }
                $thisCursor = $searchData.IndexOf($stag, $lastCursor)
                If ($thisCursor -eq -1) { Return $null }
                Else
                {
                    $endTags += [PSCustomObject]@{
                        'Value' = $InputObject.Substring($thisCursor, $stag.Length)
                        'Index' = $thisCursor
                        'Length' = $stag.Length
                    }

                    $lastCursor = $thisCursor + $stag.Length
                }
            }

            Return [PSCustomObject]@{
                        'Preceding' = $startTags
                        'Succeeding' = $endTags
                        'Substring' = ''
            }
        }
    }

    Process
    {
        $startCursor = 0
        $output = @()
        While ($true)
        {
            $result = GetIndexOfTags($startCursor)
            If ($result -eq $null) { Break }
            $result.Substring = $InputObject.Substring($result.Preceding[-1].Index + $result.Preceding[-1].Length, 
                $result.Succeeding[0].Index - $result.Preceding[-1].Index - $result.Preceding[-1].Length)
            $output += $result
            $startCursor = $result.Succeeding[-1].Index + $result.Succeeding[-1].Length
        }
    }

    End
    {
        If ($PassThru) { Return $output }
        Else
        {
            Return ($output | ForEach-Object { $_.Substring })
        }
    }
}

Export-ModuleMember -Function @(
    'Expand-PSTemplate'
)
