# Author: Thomas Démoulins <tdemoulins@gmail.com>

<#
.SYNOPSIS
    Parses a SemVer-like object from a string in a flexible manner.

.DESCRIPTION
    This function parses a string containing a SemVer-like version
    and returns an object that represents both the version (with up to 4 parts)
    and optionally a pre-release and a build metadata.

    The parsing is quite flexible:
    - the version can be in the middle of a url or sentence
    - first version found is returned
    - there can be no hyphen between the version and the pre-release
    - extra spaces are ignored
    - optional delimiters can be provided to help parsing the string

    Parameter -SemVer allows to specify the max supported SemVer version:
    V1 (default) or V2 (requires choco v2.0.0). EnhancedV2 is about
    transforming a SemVer1-like version into a SemVer2-like one when
    possible (e.g. 1.61.0-beta.0 instead of 1.61.0-beta0).

    Resulting version is normalized the same way chocolatey/nuget does.
    See https://learn.microsoft.com/en-us/nuget/concepts/package-versioning#normalized-version-numbers

.EXAMPLE
    Get-Version 'Current version 2.1.1 beta 2.'

    Returns 2.1.1-beta2

.EXAMPLE
    Get-Version -SemVer V2 'Current version 2.1.1 beta 2.'

    Returns 2.1.1-beta.2

.EXAMPLE
    Get-Version -SemVer V2 '4.0.3Beta1'

    Returns 4.0.3-Beta1

.EXAMPLE
    Get-Version -SemVer EnhancedV2 '4.0.3Beta1'

    Returns 4.0.3-Beta.1

.EXAMPLE
    Get-Version 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi' -Delimiter '-'

    Returns 5.6.3
#>
function Get-Version {
    [CmdletBinding()]
    param(
        # Supported SemVer version: V1 (default) or V2 (requires choco v2.0.0).
        # EnhancedV2 allows to transform a SemVer1-like version into SemVer2-like one (e.g. 1.2.0-rc.3 instead of 1.2.0-rc3)
        [ValidateSet('V1', 'V2', 'EnhancedV2')]
        [string] $SemVer = 'V1',
        # Version string to parse.
        [Parameter(Mandatory, Position=0)]
        [string] $Version,
        # Optional delimiter(s) to help locate the version in the string: the version must start and end with one of these chars.
        [char[]] $Delimiter
    )
    if ($Delimiter) {
        $delimiters = $Delimiter -join ''
        @('\', ']', '^', '-') | ForEach-Object { $delimiters = $delimiters.Replace($_, "\$_") }
        $regex = $Version | Select-String -Pattern "[$delimiters](\d+\.\d+[^$delimiters]*)[$delimiters]" -AllMatches
        foreach ($match in $regex.Matches) {
            $reference = [ref] $null
            if ([AUVersion]::TryParse($match.Groups[1], $reference, $false, $SemVer)) {
                return $reference.Value
            }
        }
    }
    return [AUVersion]::Parse($Version, $false, $SemVer)
}
