remove-module Chocolatey-AU -ea ignore
import-module $PSScriptRoot\..\Chocolatey-AU\Chocolatey-AU.psm1 # Tests require the private functions exported

Describe 'Get-Version' -Tag version {
    InModuleScope Chocolatey-AU {
        Context 'Get-Version [-SemVer V1]' {
            It 'parses "<value>"' -TestCases @(
                @{Result = '4.28.0'                       ; Value = '4.28'}
                @{Result = '2.5.0'                        ; Value = 'v2.5.0'}
                @{Result = '4.0.3-Beta1'                  ; Value = '4.0.3Beta1'}
                @{Result = '4.0.3-Beta1'                  ; Value = '4.0.3Beta.1'}
                @{Result = '8.0.0-rc1'                    ; Value = 'v8.0-rc1'}
                @{Result = '8.0.0-rc1'                    ; Value = 'v8.0-rc.1'}
                @{Result = '1.61.0-beta0'                 ; Value = 'v1.61.0-beta0'}
                @{Result = '1.61.0-beta0'                 ; Value = 'v1.61.0-beta.0'}
                @{Result = '1.79.2.23166'                 ; Value = '1.79.2.23166'}
                @{Result = '2.1.1-beta2'                  ; Value = 'Current version 2.1.1 beta 2.'}
                @{Result = '2.1.1-beta2'                  ; Value = 'Current version 2.1.1 beta.2.'}
                @{Result = '5.6.3-x86msi'                 ; Value = 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi'}
                @{Result = '5.6.3'       ; Delimiter = '-'; Value = 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi'}
                @{Result = '5.32.1.1'                     ; Value = 'https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-32bit.msi'}
            ) { param([string] $Value, [string] $Delimiter, [string] $Result)
                $res = Get-Version $Value -Delimiter $Delimiter
                $res            | Should Not BeNullOrEmpty
                $res.ToString() | Should Be $Result
            }
        }

        Context 'Get-Version -SemVer V2' {
            It 'parses "<value>"' -TestCases @(
                @{Result = '4.28.0'                        ; Value = '4.28'}
                @{Result = '2.5.0'                         ; Value = 'v2.5.0'}
                @{Result = '4.0.3-Beta1'                   ; Value = '4.0.3Beta1'}
                @{Result = '4.0.3-Beta.1'                  ; Value = '4.0.3Beta.1'}
                @{Result = '8.0.0-rc1'                     ; Value = 'v8.0-rc1'}
                @{Result = '8.0.0-rc.1'                    ; Value = 'v8.0-rc.1'}
                @{Result = '1.61.0-beta0'                  ; Value = 'v1.61.0-beta0'}
                @{Result = '1.61.0-beta.0'                 ; Value = 'v1.61.0-beta.0'}
                @{Result = '1.79.2.23166'                  ; Value = '1.79.2.23166'}
                @{Result = '2.1.1-beta.2'                  ; Value = 'Current version 2.1.1 beta 2.'}
                @{Result = '2.1.1-beta.2'                  ; Value = 'Current version 2.1.1 beta.2.'}
                @{Result = '5.6.3-x86.msi'                 ; Value = 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi'}
                @{Result = '5.6.3'        ; Delimiter = '-'; Value = 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi'}
                @{Result = '5.32.1.1'                      ; Value = 'https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-32bit.msi'}
            ) { param([string] $Value, [string] $Delimiter, [string] $Result)
                $res = Get-Version -SemVer V2 $Value -Delimiter $Delimiter
                $res            | Should Not BeNullOrEmpty
                $res.ToString() | Should Be $Result
            }
        }

        Context 'Get-Version -SemVer EnhancedV2' {
            It 'parses "<value>"' -TestCases @(
                @{Result = '4.28.0'                        ; Value = '4.28'}
                @{Result = '2.5.0'                         ; Value = 'v2.5.0'}
                @{Result = '4.0.3-Beta.1'                  ; Value = '4.0.3Beta1'}
                @{Result = '4.0.3-Beta.1'                  ; Value = '4.0.3Beta.1'}
                @{Result = '8.0.0-rc.1'                    ; Value = 'v8.0-rc1'}
                @{Result = '8.0.0-rc.1'                    ; Value = 'v8.0-rc.1'}
                @{Result = '1.61.0-beta.0'                 ; Value = 'v1.61.0-beta0'}
                @{Result = '1.61.0-beta.0'                 ; Value = 'v1.61.0-beta.0'}
                @{Result = '1.79.2.23166'                  ; Value = '1.79.2.23166'}
                @{Result = '2.1.1-beta.2'                  ; Value = 'Current version 2.1.1 beta 2.'}
                @{Result = '2.1.1-beta.2'                  ; Value = 'Current version 2.1.1 beta.2.'}
                @{Result = '5.6.3-x86.msi'                 ; Value = 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi'}
                @{Result = '5.6.3'        ; Delimiter = '-'; Value = 'https://dl.airserver.com/pc32/AirServer-5.6.3-x86.msi'}
                @{Result = '5.32.1.1'                      ; Value = 'https://strawberryperl.com/download/5.32.1.1/strawberry-perl-5.32.1.1-32bit.msi'}
            ) { param([string] $Value, [string] $Delimiter, [string] $Result)
                $res = Get-Version -SemVer EnhancedV2 $Value -Delimiter $Delimiter
                $res            | Should Not BeNullOrEmpty
                $res.ToString() | Should Be $Result
            }
        }
    }
}
