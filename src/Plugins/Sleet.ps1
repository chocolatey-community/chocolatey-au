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

if (-not (Get-Command sleet -ErrorAction SilentlyContinue)) {
    throw "Sleet is not installed or not on PATH. Install Sleet and make sure 'sleet' can be found on PATH."
}

Write-Host "Pushing packages using Sleet config: '$ConfigPath', Source: '$SourceName'"

$packagePaths = $Info.result.updated | ForEach-Object {
    if ($_.Streams) {
        $_.Streams.Values | Where-Object { $_.Updated } | ForEach-Object {
            Resolve-Path ("$($_.Path)/$($_.Name).$($_.RemoteVersion).nupkg")
        }
    } else {
        Resolve-Path ("$($_.Path)/$($_.Name).$($_.RemoteVersion).nupkg")
    }
}

if ($packagePaths.Count -eq 0) {
    Write-Host "No packages to push."
} else {
    $sleetArgs = @('push', '--verbosity', 'minimal', '--config', $ConfigPath, '--source', $SourceName)
    if ($Env:au_ForcePush) { $sleetArgs += '--force' }

    sleet @sleetArgs @packagePaths
    if ($LASTEXITCODE -ne 0) { throw "Sleet push failed with exit code $LASTEXITCODE" }
}