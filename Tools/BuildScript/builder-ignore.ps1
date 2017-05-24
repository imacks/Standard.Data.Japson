properties {
    [string]$ProjectName = '<undefined>'
    [PSObject]$ProjectInfo = $null
    [string]$Configuration = 'Release'
    [switch]$Force = $false
}


# --- overrides ---

formatTaskName {
    param($taskName)

    # swallow everything to suppress printing task names
}

# --- /overrides ---


task default -depends Finalize

task Finalize {
    say ('[i] Skipping a project because "projectType" is set to "ignore": {0}' -f $ProjectName)
}
