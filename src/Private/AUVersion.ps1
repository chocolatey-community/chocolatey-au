enum SemVer {
    V1
    V2
    EnhancedV2
}

class AUVersion : System.IComparable {
    [version] $Version
    [string] $Prerelease
    [string] $BuildMetadata

    hidden AUVersion([version] $version, [string] $prerelease, [string] $buildMetadata) {
        if (!$version) { throw 'Version cannot be null.' }
        $this.Version       = [AUVersion]::NormalizeVersion($version)
        $this.Prerelease    = [AUVersion]::NormalizePrerelease($prerelease) -join '.'
        $this.BuildMetadata = $buildMetadata
    }

    AUVersion($value) {
        if (!$value) { throw 'Input cannot be null.' }
        $v = [AUVersion]::Parse($value -as [string])
        $this.Version       = $v.Version
        $this.Prerelease    = $v.Prerelease
        $this.BuildMetadata = $v.BuildMetadata
    }

    static [AUVersion] Parse([string] $value) {
        return [AUVersion]::Parse($value, $true)
    }

    static [AUVersion] Parse([string] $value, [bool] $strict) {
        return [AUVersion]::Parse($value, $strict, [SemVer]::V2)
    }

    static [AUVersion] Parse([string] $value, [bool] $strict, [SemVer] $semver) {
        if (!$value) { throw 'Version cannot be null.' }
        $v = [ref] $null
        if (![AUVersion]::TryParse($value, $v, $strict, $semver)) {
            throw "Invalid SemVer $semver version: `"$value`"."
        }
        return $v.Value
    }

    static [bool] TryParse([string] $value, [ref] $result) {
        return [AUVersion]::TryParse($value, $result, $true)
    }

    static [bool] TryParse([string] $value, [ref] $result, [bool] $strict) {
        return [AUVersion]::TryParse($value, $result, $strict, [SemVer]::V2)
    }

    static [bool] TryParse([string] $value, [ref] $result, [bool] $strict, [SemVer] $semver) {
        $result.Value = [AUVersion] $null
        if (!$value) { return $false }
        $pattern = [AUVersion]::GetPattern($strict)
        if ($value -notmatch $pattern) { return $false }
        $v = [ref] $null
        if (![version]::TryParse($Matches.version, $v)) { return $false }
        $pr = [ref] $null
        if (![AUVersion]::TryRefineIdentifiers($Matches.prerelease, $pr, $strict, $semver)) { return $false }
        $bm = [ref] $null
        if (![AUVersion]::TryRefineIdentifiers($Matches.buildMetadata, $bm, $strict, $semver)) { return $false }
        $result.Value = [AUVersion]::new($v.Value, $pr.Value, $bm.Value)
        return $true
    }

    hidden static [version] NormalizeVersion([version] $value) {
        if ($value.Build -eq -1) {
            return [version] "$value.0"
        }
        if ($value.Revision -eq 0) {
            return [version] $value.ToString(3)
        }
        return $value
    }

    hidden static [object[]] NormalizePrerelease([string] $value) {
        $result = @()
        if ($value) {
            $value -split '\.' | ForEach-Object {
                # if identifier is exclusively numeric, cast it to an int
                if ($_ -match '^\d+$') {
                    $result += [int] $_
                } else {
                    $result += $_
                }
            }
        }
        return $result
    }

    hidden static [string] GetPattern([bool] $strict) {
        $versionPattern = '(?<version>\d+(?:\.\d+){1,3})'
        if ($strict) {
            $identifierPattern = "[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*"
            return "^$versionPattern(?:-(?<prerelease>$identifierPattern))?(?:\+(?<buildMetadata>$identifierPattern))?`$"
        } else {
            $identifierPattern = "[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+| +\d+)*"
            return "$versionPattern(?:(?:-| *)(?<prerelease>$identifierPattern))?(?:(?:\+| *)(?<buildMetadata>$identifierPattern))?"
        }
    }

    hidden static [bool] TryRefineIdentifiers([string] $value, [ref] $result, [bool] $strict, [SemVer] $semver) {
        $result.Value = [string] ''
        if (!$value) { return $true }
        if (!$strict) { $value = $value -replace ' +', '.' }
        if ($semver -eq [SemVer]::V1) {
            # SemVer1 means no dot-separated identifiers
            if ($strict -and $value -match '\.') { return $false }
            $value = $value.Replace('.', '')
        } elseif ($semver -eq [SemVer]::EnhancedV2) {
            # Try to improve a SemVer1 version into a SemVer2 one
            # e.g. 1.24.0-beta2 becomes 1.24.0-beta.2
            if ($value -match '^(?<identifier>[A-Za-z-]+)(?<digits>\d+)$') {
                $value = '{0}.{1}' -f $Matches.identifier, $Matches.digits
            }
        }
        $result.Value = $value
        return $true
    }

    [AUVersion] WithVersion([version] $version) {
        return [AUVersion]::new($version, $this.Prerelease, $this.BuildMetadata)
    }

    [int] CompareTo($obj) {
        if ($null -eq $obj) { return 1 }
        if ($obj -isnot [AUVersion]) { throw "[AUVersion] expected, got [$($obj.GetType())]." }
        $t = $this.GetParts()
        $o = $obj.GetParts()
        for ($i = 0; $i -lt $t.Length -and $i -lt $o.Length; $i++) {
            if ($t[$i].GetType() -ne $o[$i].GetType()) {
                $t[$i] = [string] $t[$i]
                $o[$i] = [string] $o[$i]
            }
            if ($t[$i] -gt $o[$i]) { return 1 }
            if ($t[$i] -lt $o[$i]) { return -1 }
        }
        if ($t.Length -eq 1 -and $o.Length -gt 1) { return 1 }
        if ($o.Length -eq 1 -and $t.Length -gt 1) { return -1 }
        if ($t.Length -gt $o.Length) { return 1 }
        if ($t.Length -lt $o.Length) { return -1 }
        return 0
    }

    [bool] Equals($obj) { return $this.CompareTo($obj) -eq 0 }

    [int] GetHashCode() { return $this.GetParts().GetHashCode() }

    [string] ToString() {
        $result = $this.Version.ToString()
        if ($this.Prerelease) { $result += '-{0}' -f $this.Prerelease }
        if ($this.BuildMetadata) { $result += '+{0}' -f $this.BuildMetadata }
        return $result
    }

    [string] ToString([int] $fieldCount) {
        if ($fieldCount -eq -1) { return $this.Version.ToString() }
        return $this.Version.ToString($fieldCount)
    }

    hidden [object[]] GetParts() {
        $result = , $this.Version
        $result += [AUVersion]::NormalizePrerelease($this.Prerelease)
        return $result
    }
}

function ConvertTo-AUVersion($Version) {
    return [AUVersion] $Version
}
