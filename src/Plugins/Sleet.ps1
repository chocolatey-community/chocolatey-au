<#
.SYNOPSIS
    Pushes updated packages to a Sleet repository.

.DESCRIPTION
    This plugin uses the Sleet command-line tool to push packages to a feed.
    It requires Sleet to be installed locally and have a configured JSON settings file. 
    It accepts configuration parameters from the options hashtable of the path to the sleet.json file and the sleet source name.
    The push parameter in the options hashtable is not respected, as that is for choco push. 
    Enable and disable the Sleet push by including the plugin configuration in the options or not
#>

param(
    $Info,

    # Path to the Sleet configuration JSON file
    [string] $ConfigPath = 'sleet.json',

    # Name of the source to push to in the Sleet configuration
    [string] $SourceName = 'default-source'
)

Write-Host "Pushing packages using Sleet config: '$ConfigPath', Source: '$SourceName'"

$packagePaths = $Info.result.updated | ForEach-Object { $_.Path }

if ($packagePaths.Count -eq 0) {
    Write-Host "No packages to push."
} else {
    $forceParam = if ($Env:au_forcepush -eq $true) { '--force' } else { '' }
    sleet push -c "$ConfigPath" -s "$SourceName" $forceParam $packagePaths
}