remove-module Chocolatey-AU -ea ignore
import-module $PSScriptRoot\..\Chocolatey-AU\Chocolatey-AU.psm1 # Tests require the private functions exported -force

Describe '[AUVersion]' -Tag version {
    InModuleScope Chocolatey-AU {
        Context '[AUVersion]::Parse() for a strict SemVer1 version' {
            It 'parses "<value>"' -TestCases @(
                @{Value = '01.02'                  ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02-pre05'            ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = ''}
                @{Value = '01.02+sha06'            ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha06'}
                @{Value = '01.02-pre05+sha06'      ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03'               ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03-pre05+sha06'   ; Ver = '1.2.3'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03.00'            ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04'            ; Ver = '1.2.3.4'; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04-pre05+sha06'; Ver = '1.2.3.4'; Pre = 'pre05'; Build = 'sha06'}
            ) { param([string] $Value, [version] $Ver, [string] $Pre, [string] $Build)
                $res = [AUVersion]::Parse($Value, $true, 'V1')
                $res               | Should Not BeNullOrEmpty
                $res.Version       | Should Be $Ver
                $res.Prerelease    | Should Be $Pre
                $res.BuildMetadata | Should Be $Build
            }

            It 'does not parse "<value>"' -TestCases @(
                @{Value = '01'}
                @{Value = 'v01.02'}
                @{Value = '01.02-pre.05'}
                @{Value = '01.02+sha.06'}
                @{Value = '01.02-pre.05+sha.06'}
                @{Value = '01.02.03-pre.05+sha.06'}
                @{Value = '01.02.03.04-pre.05+sha.06'}
            ) { param([string] $Value)
                { [AUVersion]::Parse($Value, $true, 'V1') } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion]::Parse() for a strict SemVer2 version' {
            It 'parses "<value>"' -TestCases @(
                @{Value = '01.02'                    ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02-pre05'              ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = ''}
                @{Value = '01.02+sha06'              ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha06'}
                @{Value = '01.02-pre05+sha06'        ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02-pre.05'             ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = ''}
                @{Value = '01.02+sha.06'             ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha.06'}
                @{Value = '01.02-pre.05+sha.06'      ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03'                 ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03-pre05+sha06'     ; Ver = '1.2.3'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03-pre.05+sha.06'   ; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.00'              ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04'              ; Ver = '1.2.3.4'; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04-pre05+sha06'  ; Ver = '1.2.3.4'; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03.04-pre.05+sha.06'; Ver = '1.2.3.4'; Pre = 'pre.5'; Build = 'sha.06'}
            ) { param([string] $Value, [version] $Ver, [string] $Pre, [string] $Build)
                $res = [AUVersion]::Parse($Value, $true, 'V2')
                $res               | Should Not BeNullOrEmpty
                $res.Version       | Should Be $Ver
                $res.Prerelease    | Should Be $Pre
                $res.BuildMetadata | Should Be $Build
            }

            It 'does not parse "<value>"' -TestCases @(
                @{Value = '01'}
                @{Value = 'v01.02'}
            ) { param([string] $Value)
                { [AUVersion]::Parse($Value, $true, 'V2') } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion]::Parse() for a strict enhanced SemVer2 version' {
            It 'parses "<value>"' -TestCases @(
                @{Value = '01.02'                    ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02-pre05'              ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = ''}
                @{Value = '01.02+sha06'              ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha.06'}
                @{Value = '01.02-pre05+sha06'        ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02-pre.05'             ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = ''}
                @{Value = '01.02+sha.06'             ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha.06'}
                @{Value = '01.02-pre.05+sha.06'      ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03'                 ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03-pre05+sha06'     ; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03-pre.05+sha.06'   ; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.00'              ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04'              ; Ver = '1.2.3.4'; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04-pre05+sha06'  ; Ver = '1.2.3.4'; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.04-pre.05+sha.06'; Ver = '1.2.3.4'; Pre = 'pre.5'; Build = 'sha.06'}
            ) { param([string] $Value, [version] $Ver, [string] $Pre, [string] $Build)
                $res = [AUVersion]::Parse($Value, $true, 'EnhancedV2')
                $res               | Should Not BeNullOrEmpty
                $res.Version       | Should Be $Ver
                $res.Prerelease    | Should Be $Pre
                $res.BuildMetadata | Should Be $Build
            }

            It 'does not parse "<value>"' -TestCases @(
                @{Value = '01'}
                @{Value = 'v01.02'}
            ) { param([string] $Value)
                { [AUVersion]::Parse($Value, $true, 'EnhancedV2') } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion]::Parse() for a non strict SemVer1 version' {
            It 'parses "<value>"' -TestCases @(
                @{Value = '01.02'                    ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = 'v01.02'                   ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02-pre05'              ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = ''}
                @{Value = '01.02+sha06'              ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha06'}
                @{Value = '01.02-pre05+sha06'        ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02-pre.05'             ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = ''}
                @{Value = '01.02+sha.06'             ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha06'}
                @{Value = '01.02-pre.05+sha.06'      ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03'                 ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03-pre05+sha06'     ; Ver = '1.2.3'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03-pre.05+sha.06'   ; Ver = '1.2.3'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03.00'              ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04'              ; Ver = '1.2.3.4'; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04-pre05+sha06'  ; Ver = '1.2.3.4'; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03.04-pre.05+sha.06'; Ver = '1.2.3.4'; Pre = 'pre05'; Build = 'sha06'}
            ) { param([string] $Value, [version] $Ver, [string] $Pre, [string] $Build)
                $res = [AUVersion]::Parse($Value, $false, 'V1')
                $res               | Should Not BeNullOrEmpty
                $res.Version       | Should Be $Ver
                $res.Prerelease    | Should Be $Pre
                $res.BuildMetadata | Should Be $Build
            }

            It 'does not parse "<value>"' -TestCases @(
                @{Value = '01'}
            ) { param([string] $Value)
                { [AUVersion]::Parse($Value, $false, 'V1') } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion]::Parse() for a non strict SemVer2 version' {
            It 'parses "<value>"' -TestCases @(
                @{Value = '01.02'                    ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = 'v01.02'                   ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02-pre05'              ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = ''}
                @{Value = '01.02+sha06'              ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha06'}
                @{Value = '01.02-pre05+sha06'        ; Ver = '1.2.0'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02-pre.05+sha.06'      ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03'                 ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03-pre05+sha06'     ; Ver = '1.2.3'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03-pre.05+sha.06'   ; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.00'              ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.00-pre05+sha06'  ; Ver = '1.2.3'  ; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03.00-pre.05+sha.06'; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.04'              ; Ver = '1.2.3.4'; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04-pre05+sha06'  ; Ver = '1.2.3.4'; Pre = 'pre05'; Build = 'sha06'}
                @{Value = '01.02.03.04-pre.05+sha.06'; Ver = '1.2.3.4'; Pre = 'pre.5'; Build = 'sha.06'}
            ) { param([string] $Value, [version] $Ver, [string] $Pre, [string] $Build)
                $res = [AUVersion]::Parse($Value, $false, 'V2')
                $res               | Should Not BeNullOrEmpty
                $res.Version       | Should Be $Ver
                $res.Prerelease    | Should Be $Pre
                $res.BuildMetadata | Should Be $Build
            }

            It 'does not parse "<value>"' -TestCases @(
                @{Value = '01'}
            ) { param([string] $Value)
                { [AUVersion]::Parse($Value, $false, 'V2') } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion]::Parse() for a non strict enhanced SemVer2 version' {
            It 'parses "<value>"' -TestCases @(
                @{Value = '01.02'                    ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = 'v01.02'                   ; Ver = '1.2.0'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02-pre05'              ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = ''}
                @{Value = '01.02+sha06'              ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha.06'}
                @{Value = '01.02-pre05+sha06'        ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02-pre.05'             ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = ''}
                @{Value = '01.02+sha.06'             ; Ver = '1.2.0'  ; Pre = ''     ; Build = 'sha.06'}
                @{Value = '01.02-pre.05+sha.06'      ; Ver = '1.2.0'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03'                 ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03-pre05+sha06'     ; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03-pre.05+sha.06'   ; Ver = '1.2.3'  ; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.00'              ; Ver = '1.2.3'  ; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04'              ; Ver = '1.2.3.4'; Pre = ''     ; Build = ''}
                @{Value = '01.02.03.04-pre05+sha06'  ; Ver = '1.2.3.4'; Pre = 'pre.5'; Build = 'sha.06'}
                @{Value = '01.02.03.04-pre.05+sha.06'; Ver = '1.2.3.4'; Pre = 'pre.5'; Build = 'sha.06'}
            ) { param([string] $Value, [version] $Ver, [string] $Pre, [string] $Build)
                $res = [AUVersion]::Parse($Value, $false, 'EnhancedV2')
                $res               | Should Not BeNullOrEmpty
                $res.Version       | Should Be $Ver
                $res.Prerelease    | Should Be $Pre
                $res.BuildMetadata | Should Be $Build
            }

            It 'does not parse "<value>"' -TestCases @(
                @{Value = '01'}
            ) { param([string] $Value)
                { [AUVersion]::Parse($Value, $false, 'EnhancedV2') } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion] conversions (strict SemVer2 version only)' {
            It 'converts from [<type>] "<value>"' -TestCases @(
                @{Type = 'string'   ; Value = '1.2.3'}
                @{Type = 'string'   ; Value = '1.2.3-pre.4+sha.05'}
                @{Type = 'version'  ; Value = [version]::Parse('1.2.3')}
                @{Type = 'AUVersion'; Value = [AUVersion]::Parse('1.2.3')}
                @{Type = 'AUVersion'; Value = [AUVersion]::Parse('1.2.3-pre.4+sha.05')}
                @{Type = 'System.Text.RegularExpressions.Capture'; Value = [regex]::Match('1.2.3', '^(.+)$').Groups[1]}
                @{Type = 'System.Text.RegularExpressions.Capture'; Value = [regex]::Match('1.2.3-pre.4+sha.05', '^(.+)$').Groups[1]}
            ) { param([object] $Value)
                $version = [AUVersion] $Value
                $version            | Should Not BeNullOrEmpty
                $version.ToString() | Should Be ($Value -as [string])
            }

            It 'does not convert from [<type>] "<value>"' -TestCases @(
                @{Type = 'string'   ; Value = '1'}
                @{Type = 'string'   ; Value = 'v1.2.3'}
                @{Type = 'System.Text.RegularExpressions.Capture'; Value = [regex]::Match('1', '^(.+)$').Groups[1]}
                @{Type = 'System.Text.RegularExpressions.Capture'; Value = [regex]::Match('v1.2.3', '^(.+)$').Groups[1]}
            ) { param([object] $Value)
                { [AUVersion] $Value } | Should Throw 'Invalid SemVer'
            }
        }

        Context '[AUVersion]::ToString()' {
            It 'formats "<value>"' -TestCases @(
                @{Value = '01.02'                    ; Result = '1.2.0'}
                @{Value = '01.02-pre05'              ; Result = '1.2.0-pre05'}
                @{Value = '01.02+sha06'              ; Result = '1.2.0+sha06'}
                @{Value = '01.02-pre05+sha06'        ; Result = '1.2.0-pre05+sha06'}
                @{Value = '01.02-pre.05'             ; Result = '1.2.0-pre.5'}
                @{Value = '01.02+sha.06'             ; Result = '1.2.0+sha.06'}
                @{Value = '01.02-pre.05+sha.06'      ; Result = '1.2.0-pre.5+sha.06'}
                @{Value = '01.02.03'                 ; Result = '1.2.3'}
                @{Value = '01.02.03-pre05+sha06'     ; Result = '1.2.3-pre05+sha06'}
                @{Value = '01.02.03-pre.05+sha.06'   ; Result = '1.2.3-pre.5+sha.06'}
                @{Value = '01.02.03.00'              ; Result = '1.2.3'}
                @{Value = '01.02.03.04'              ; Result = '1.2.3.4'}
                @{Value = '01.02.03.04-pre05+sha06'  ; Result = '1.2.3.4-pre05+sha06'}
                @{Value = '01.02.03.04-pre.05+sha.06'; Result = '1.2.3.4-pre.5+sha.06'}
            ) { param([string] $Value, [string] $Result)
                $res = [AUVersion] $Value
                $res              | Should Not BeNullOrEmpty
                $res.ToString()   | Should Be $Result
                $res.ToString(-1) | Should Be $res.Version.ToString()
                $res.ToString(2)  | Should Be $res.Version.ToString(2)
            }
        }

        Context '[AUVersion]::CompareTo()' {
            It 'compares "<a>" <result> "<b>"' -TestCases @(
                @{A = '1.2.3'    ; B = '1.2.3'     ; Result = '='}
                @{A = '1.2.3'    ; B = '1.2.33'    ; Result = '<'}
                @{A = '1.2.3'    ; B = '1.2.3.4'   ; Result = '<'}
                @{A = '1.2.3.4'  ; B = '1.2.3.4'   ; Result = '='}
                @{A = '1.2.3.4'  ; B = '1.2.3.44'  ; Result = '<'}
                @{A = '1.2.3-a1' ; B = '1.2.3-a1'  ; Result = '='}
                @{A = '1.2.3-a1' ; B = '1.2.3-a2'  ; Result = '<'}
                @{A = '1.2.3-a2' ; B = '1.2.3-a10' ; Result = '>'}
                @{A = '1.2.3-a1' ; B = '1.2.3-b1'  ; Result = '<'}
                @{A = '1.2.3-a.1'; B = '1.2.3-a.1' ; Result = '='}
                @{A = '1.2.3-a.1'; B = '1.2.3-a.2' ; Result = '<'}
                @{A = '1.2.3-a.2'; B = '1.2.3-a.10'; Result = '<'}
                @{A = '1.2.3-a.1'; B = '1.2.3-b.1' ; Result = '<'}
                @{A = '1.2.3+a'  ; B = '1.2.3+a'   ; Result = '='}
                @{A = '1.2.3+a'  ; B = '1.2.3+b'   ; Result = '='}
            ) { param([string] $A, [string] $B, [string] $Result)
                $resA = [AUVersion] $A
                $resB = [AUVersion] $B
                $resA | Should Not BeNullOrEmpty
                $resB | Should Not BeNullOrEmpty
                if ($Result -eq '=' ) {
                    $resA | Should Be $resB
                } elseif ($Result -eq '<' ) {
                    $resA | Should BeLessThan $resB
                } else {
                    $resA | Should BeGreaterThan $resB
                }
            }
        }
    }
}
