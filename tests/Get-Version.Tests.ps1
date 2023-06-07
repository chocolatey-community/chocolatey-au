remove-module Chocolatey-AU -ea ignore
import-module $PSScriptRoot\..\Chocolatey-AU\Chocolatey-AU.psm1 # Tests require the private functions exported

Describe 'ConvertTo-AUVersion' -Tag getversion {
    InModuleScope Chocolatey-AU {
        $testCases = @(
            @{Value = '01.02.03.04-beta.01+xyz.01'; ExpectedVersion = '1.2.3.4'; ExpectedPrerelease = 'beta.1'; ExpectedBuildMetadata = 'xyz.01'}
            @{Value = '01.02.03-beta01+xyz01'     ; ExpectedVersion = '1.2.3'  ; ExpectedPrerelease = 'beta01'; ExpectedBuildMetadata = 'xyz01'}
            # The following test cases are intended to match chocolatey normalized versions
            @{Value = '01.02-beta+xyz'            ; ExpectedVersion = '1.2.0'  ; ExpectedPrerelease = 'beta'  ; ExpectedBuildMetadata = 'xyz'}
            @{Value = '01.02.03.00-beta+xyz'      ; ExpectedVersion = '1.2.3'  ; ExpectedPrerelease = 'beta'  ; ExpectedBuildMetadata = 'xyz'}
        )

        It 'should convert a strict version: <value>' -TestCases $testCases { param([string] $Value, [version] $ExpectedVersion, [string] $ExpectedPrerelease, [string] $ExpectedBuildMetadata)
            $res = ConvertTo-AUVersion $Value
            $res | Should Not BeNullOrEmpty
            $res.Version | Should Be $ExpectedVersion
            $res.Prerelease | Should BeExactly $ExpectedPrerelease
            $res.BuildMetadata | Should BeExactly $ExpectedBuildMetadata
            $res.ToString() | Should BeExactly "$ExpectedVersion-$ExpectedPrerelease+$ExpectedBuildMetadata"
            $res.ToString(2) | Should BeExactly $ExpectedVersion.ToString(2)
            $res.ToString(-1) | Should BeExactly $ExpectedVersion.ToString()
        }

        $testCases = @(
            @{Value = '1.2.3.4a'}
            @{Value = 'v1.2.3.4-beta.1+xyz.01'}
        )

        It 'should not convert a non strict version: <value>' -TestCases $testCases { param([string] $Value)
            { ConvertTo-AUVersion $Value } | Should Throw
        }

        $testCases = @(
            @{A = '1.9.0'           ; B = '1.9.0'           ; ExpectedResult = '='}
            @{A = '1.9.0'           ; B = '1.10.0'          ; ExpectedResult = '<'}
            @{A = '1.10.0'          ; B = '1.11.0'          ; ExpectedResult = '<'}
            @{A = '1.0.0'           ; B = '2.0.0'           ; ExpectedResult = '<'}
            @{A = '2.0.0'           ; B = '2.1.0'           ; ExpectedResult = '<'}
            @{A = '2.1.0'           ; B = '2.1.1'           ; ExpectedResult = '<'}
            @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha'     ; ExpectedResult = '='}
            @{A = '1.0.0-alpha'     ; B = '1.0.0'           ; ExpectedResult = '<'}
            @{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.1'   ; ExpectedResult = '='}
            @{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.01'  ; ExpectedResult = '='}
            @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha.1'   ; ExpectedResult = '<'}
            @{A = '1.0.0-alpha.1'   ; B = '1.0.0-alpha.beta'; ExpectedResult = '<'}
            @{A = '1.0.0-alpha.beta'; B = '1.0.0-beta'      ; ExpectedResult = '<'}
            @{A = '1.0.0-beta'      ; B = '1.0.0-beta.2'    ; ExpectedResult = '<'}
            @{A = '1.0.0-beta.2'    ; B = '1.0.0-beta.11'   ; ExpectedResult = '<'}
            @{A = '1.0.0-beta.11'   ; B = '1.0.0-rc.1'      ; ExpectedResult = '<'}
            @{A = '1.0.0-rc.1'      ; B = '1.0.0'           ; ExpectedResult = '<'}
            @{A = '1.0.0'           ; B = '1.0.0+1'         ; ExpectedResult = '='}
            @{A = '1.0.0+1'         ; B = '1.0.0+2'         ; ExpectedResult = '='}
            @{A = '1.0.0-alpha'     ; B = '1.0.0-alpha+1'   ; ExpectedResult = '='}
            @{A = '1.0.0-alpha+1'   ; B = '1.0.0-alpha+2'   ; ExpectedResult = '='}
        )

        It 'should compare 2 versions successfully: <a> <expectedResult> <b>' -TestCases $testCases { param([string] $A, [string] $B, [string] $ExpectedResult)
            $VersionA = ConvertTo-AUVersion $A
            $VersionB = ConvertTo-AUVersion $B
            if ($ExpectedResult -eq '>' ) {
                $VersionA | Should BeGreaterThan $VersionB
            } elseif ($ExpectedResult -eq '<' ) {
                $VersionA | Should BeLessThan $VersionB
            } else {
                $VersionA | Should Be $VersionB
            }
        }
    }
}

Describe 'Get-Version' -Tag getversion {
    InModuleScope AU {
        $testCases = @(
            @{Value = 'v01.02.03.04beta.01+xyz.01'; ExpectedVersion = '1.2.3.4'; ExpectedPrerelease = 'beta.1'; ExpectedBuildMetadata = 'xyz.01'}
            @{Value = 'v01.02.03 beta 01 xyz 01 z'; ExpectedVersion = '1.2.3'  ; ExpectedPrerelease = 'beta.1'; ExpectedBuildMetadata = 'xyz.01'}
            @{Value = 'v01.02.03 beta01 xyz01'    ; ExpectedVersion = '1.2.3'  ; ExpectedPrerelease = 'beta.1'; ExpectedBuildMetadata = 'xyz.01'}
        )

        It 'should parse a non strict version: <value>' -TestCases $testCases { param([string] $Value, [version] $ExpectedVersion, [string] $ExpectedPrerelease, [string] $ExpectedBuildMetadata)
            $res = Get-Version $Value
            $res | Should Not BeNullOrEmpty
            $res.Version | Should Be $ExpectedVersion
            $res.Prerelease | Should BeExactly $ExpectedPrerelease
            $res.BuildMetadata | Should BeExactly $ExpectedBuildMetadata
        }

        $testCases = @(
            @{ExpectedResult = '5.4.9'    ; Delimiter = '-' ; Value = 'http://dl.airserver.com/pc32/AirServer-5.4.9-x86.msi'}
            @{ExpectedResult = '1.24.0-beta.2'              ; Value = 'https://github.com/atom/atom/releases/download/v1.24.0-beta2/AtomSetup.exe'}
            @{ExpectedResult = '2.4.0.24-beta'              ; Value = 'https://github.com/gurnec/HashCheck/releases/download/v2.4.0.24-beta/HashCheckSetup-v2.4.0.24-beta.exe'}
            @{ExpectedResult = '2.0.9'                      ; Value = 'http://www.ltr-data.se/files/imdiskinst_2.0.9.exe'}
            @{ExpectedResult = '17.6'     ; Delimiter = '-' ; Value = 'http://mirrors.kodi.tv/releases/windows/win32/kodi-17.6-Krypton-x86.exe'}
            @{ExpectedResult = '0.70.2'                     ; Value = 'https://github.com/Nevcairiel/LAVFilters/releases/download/0.70.2/LAVFilters-0.70.2-Installer.exe'}
            @{ExpectedResult = '2.2.0-1'                    ; Value = 'https://files.kde.org/marble/downloads/windows/Marble-setup_2.2.0-1_x64.exe'}
            @{ExpectedResult = '2.3.2'                      ; Value = 'https://github.com/sabnzbd/sabnzbd/releases/download/2.3.2/SABnzbd-2.3.2-win-setup.exe'}
            @{ExpectedResult = '1.9'      ; Delimiter = '-' ; Value = 'http://download.serviio.org/releases/serviio-1.9-win-setup.exe'}
            @{ExpectedResult = '0.17.0'                     ; Value = 'https://github.com/Stellarium/stellarium/releases/download/v0.17.0/stellarium-0.17.0-win32.exe'}
            @{ExpectedResult = '5.24.3.1'                   ; Value = 'http://strawberryperl.com/download/5.24.3.1/strawberry-perl-5.24.3.1-32bit.msi'}
            @{ExpectedResult = '3.5.4'                      ; Value = 'https://github.com/SubtitleEdit/subtitleedit/releases/download/3.5.4/SubtitleEdit-3.5.4-Setup.zip'}
            @{ExpectedResult = '1.2.3-beta.4'               ; Value = 'v 1.2.3 beta 4'}
            @{ExpectedResult = '1.2.3-beta.3'               ; Value = 'Last version: 1.2.3 beta 3.'}
        )

        It 'should parse any non strict version: <value>' -TestCases $testCases { param($Value, $Delimiter, $ExpectedResult)
            $version = Get-Version $Value -Delimiter $Delimiter
            $version | Should Be ([AUVersion] $ExpectedResult)
        }
    }
}

Describe '[AUVersion]' -Tag getversion {
    InModuleScope AU {
        $testCases = @(
            @{Type = 'string'   ; Value = '1.2'}
            @{Type = 'string'   ; Value = '1.2-beta+03'}
            @{Type = 'AUVersion'; Value = [AUVersion] '1.2'}
            @{Type = 'AUVersion'; Value = [AUVersion] '1.2-beta+03'}
            @{Type = 'version'  ; Value = [version] '1.2'}
            @{Type = 'System.Text.RegularExpressions.Capture'; Value = [regex]::Match('1.2', '^(.+)$').Groups[1]}
            @{Type = 'System.Text.RegularExpressions.Capture'; Value = [regex]::Match('1.2-beta+03', '^(.+)$').Groups[1]}
        )

        It 'converts from: [<type>] <value>' -TestCases $testCases { param($Value)
            $version = [AUVersion] $Value
            $version | Should Not BeNullOrEmpty
        }
    }
}
