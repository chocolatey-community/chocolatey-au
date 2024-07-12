remove-module Chocolatey-AU -ea ignore
import-module $PSScriptRoot\..\Chocolatey-AU\Chocolatey-AU.psm1 # Tests require the private functions exported -force

Describe 'Update-Package' -Tag update {
    $saved_pwd = $pwd

    function global:get_latest($Version='1.3', $URL='test') {
        "function global:au_GetLatest { @{Version = '$Version'; URL = '$URL'} }" | Invoke-Expression
    }

    function global:seach_replace() {
        "function global:au_SearchReplace { @{} }" | Invoke-Expression
    }

    function global:nuspec_file() { [xml](Get-Content TestDrive:\test_package\test_package.nuspec) }

    BeforeEach {
        Set-Location $TestDrive
        Remove-Item -Recurse -Force TestDrive:\test_package -ea ignore
        Copy-Item -Recurse -Force $PSScriptRoot\test_package TestDrive:\test_package
        Set-Location $TestDrive\test_package

        $global:au_Timeout             = 100
        $global:au_Force               = $false
        $global:au_NoHostOutput        = $true
        $global:au_NoCheckUrl          = $true
        $global:au_NoCheckChocoVersion = $true
        $global:au_ChecksumFor         = 'none'
        $global:au_WhatIf              = $false
        $global:au_NoReadme            = $false

        Remove-Variable -Scope global Latest -ea ignore
        'BeforeUpdate', 'AfterUpdate' | ForEach-Object { Remove-Item "Function:/au_$_" -ea ignore }
        get_latest
        seach_replace
    }

    InModuleScope Chocolatey-AU {

        Context 'Updating' {

            It 'can set description from README.md' {
                $readme = 'dummy readme & test'
                '','', $readme | Out-File $TestDrive\test_package\README.md
                $res = update

                $res.Result -match 'Setting package description from README.md' | Should Be $true
                (nuspec_file).package.metadata.description.InnerText.Trim() | Should Be $readme
            }

            It 'does not set description from README.md with NoReadme parameter' {
                $readme = 'dummy readme & test'
                '','', $readme | Out-File $TestDrive\test_package\README.md
                $res = update -NoReadme

                $res.Result -match 'Setting package description from README.md' | Should BeNullOrEmpty
                (nuspec_file).package.metadata.description | Should Be 'This is a test package for Pester'
            }

            It 'can backup and restore using WhatIf' {
                get_latest -Version 1.2.3
                $global:au_Force = $true; $global:au_Version = '1.0'
                $global:au_WhatIf = $true
                $res = update -ChecksumFor 32 6> $null

                $res.Updated  | Should Be $true
                $res.RemoteVersion | Should Be '1.0'
                (nuspec_file).package.metadata.version | Should Be 1.2.3
            }

            It 'can let user override the version' {
                get_latest -Version 1.2.3
                $global:au_Force = $true; $global:au_Version = '1.0'

                $res = update -ChecksumFor 32 6> $null

                $res.Updated  | Should Be $true
                $res.RemoteVersion | Should Be '1.0'
            }

            It 'automatically verifies the checksum' {
                $choco_path = Get-Command choco.exe | ForEach-Object Source
                $choco_hash = Get-FileHash $choco_path -Algorithm SHA256 | ForEach-Object Hash

                function global:au_GetLatest {
                    @{ PackageName = 'test'; Version = '1.3'; URL32=$choco_path; Checksum32 = $choco_hash }
                }

                $res = update -ChecksumFor 32 6> $null
                $res.Result -match 'hash checked for 32 bit version' | Should Be $true
            }

            It 'automatically calculates the checksum' {
                update -ChecksumFor 32 6> $null

                $global:Latest.Checksum32     | Should Not BeNullOrEmpty
                $global:Latest.ChecksumType32 | Should Be 'sha256'
                $global:Latest.Checksum64     | Should BeNullOrEmpty
                $global:Latest.ChecksumType64 | Should BeNullOrEmpty
            }

            It 'updates package when remote version is higher' {
                $res = update

                $res.Updated       | Should Be $true
                $res.RemoteVersion | Should Be 1.3
                $res.Result[-1]    | Should Be 'Package updated'
                (nuspec_file).package.metadata.version | Should Be 1.3
            }

            It "does not update the package when remote version is not higher" {
                get_latest -Version 1.2.3

                $res = update

                $res.Updated       | Should Be $false
                $res.RemoteVersion | Should Be 1.2.3
                $res.Result[-1]    | Should Be 'No new version found'
                (nuspec_file).package.metadata.version | Should Be 1.2.3
            }

            It "updates the package when forced using choco fix notation" {
                get_latest -Version 1.2.3

                $res = update -Force:$true

                $d = (get-date).ToString('yyyyMMdd')
                $res.Updated    | Should Be $true
                $res.Result[-1] | Should Be 'Package updated'
                $res.Result -match 'No new version found, but update is forced' | Should Not BeNullOrEmpty
                (nuspec_file).package.metadata.version | Should Be "1.2.3.$d"
            }

            It "does not use choco fix notation if the package remote version is higher" {
                $res = update -Force:$true

                $res.Updated | Should Be $true
                $res.RemoteVersion | Should Be 1.3
                (nuspec_file).package.metadata.version | Should Be 1.3
            }

            It "searches and replaces given file lines when updating" {

                function global:au_SearchReplace {
                    @{
                        'test_package.nuspec' = @{ '(<releaseNotes>)(.*)(</releaseNotes>)' = '$1test$3' }
                    }
                }

                function global:au_GetLatest {
                    @{ PackageName = 'test'; Version = '1.3'  }
                }

                update

                $nu = (nuspec_file).package.metadata
                $nu.releaseNotes | Should Be 'test'
                $nu.id           | Should Be 'test'
                $nu.version      | Should Be 1.3
            }
        }

        Context 'Checks' {
            It 'verifies semantic version' {
                get_latest -Version 1.0.1-alpha
                $res = update
                $res.Updated | Should Be $false

                get_latest 1.2.3-alpha
                $res = update
                $res.Updated | Should Be $false

                get_latest -Version 1.3-alpha
                $res = update
                $res.Updated | Should Be $true

                get_latest -Version 1.3-alpha.1
                $res = update
                $res.Updated | Should Be $true

                get_latest -Version 1.3a
                { update } | Should Throw "Invalid version"
            }

            It 'throws if latest URL is non existent' {
                { update -NoCheckUrl:$false } | Should Throw "URL syntax is invalid"
            }

            It 'throws if latest URL ContentType is text/html' {
                Mock request { @{ ContentType = 'text/html' } }
                Mock is_url { $true }
                { update -NoCheckUrl:$false } | Should Throw "Bad content type"
            }

            It 'quits if updated package version already exist in Chocolatey community feed' {
                $res = update -NoCheckChocoVersion:$false
                $res.Result[-1] | Should Match "New version is available but it already exists in the Chocolatey community feed"
            }

            It 'throws if search string is not found in given file' {
                function global:au_SearchReplace {
                    @{
                        'test_package.nuspec' = @{ 'not existing' = '' }
                    }
                }

                { update } | Should Throw "Search pattern not found: 'not existing'"
            }
        }

        Context 'Global variables' {
            Mock Write-Verbose


            It 'sets Force parameter from global variable au_Force if it is not bound' {
                $global:au_Force = $true
                $filter_msg = "Parameter Force set from global variable au_Force: $au_Force"
                update -Verbose
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $filter_msg }

            }

            It "doesn't set Force parameter from global variable au_Force if it is bound" {
                $global:au_Force = $true
                $filter_msg = "Parameter Force set from global variable au_Force: $au_Force"
                update -Verbose -Force:$false
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -ne $filter_msg }
            }

            It 'sets Timeout parameter from global variable au_Timeout if it is not bound' {
                $global:au_Timeout = 50
                $filter_msg = "Parameter Timeout set from global variable au_Timeout: $au_Timeout"
                update -Verbose
                Assert-MockCalled Write-Verbose -ParameterFilter { $Message -eq $filter_msg }
            }

        }

        Context 'Nuspec file' {

            It 'loads a nuspec file from the package directory' {
                { update } | Should Not Throw 'No nuspec file'
                $global:Latest.NuspecVersion | Should Be 1.2.3
            }

            It "throws if it can't find the nuspec file in the current directory" {
                Set-Location $TestDrive
                { update } | Should Throw 'No nuspec file'
            }

            It "uses version 0.0 on invalid nuspec version" {
                $nu = nuspec_file
                $nu.package.metadata.version = '{{PackageVersion}}'
                $nu.Save("$TestDrive\test_package\test_package.nuspec")

                update *> $null

                $global:Latest.NuspecVersion | Should Be '0.0'
            }
        }

        Context 'au_GetLatest' {

            It 'throws if au_GetLatest is not defined' {
                Remove-Item Function:/au_GetLatest
                { update } | Should Throw "'au_GetLatest' is not recognized"
            }

            It "throws if au_GetLatest doesn't return HashTable" {
                $return_value = @(1)
                function global:au_GetLatest { $return_value }
                { update } | Should Throw "doesn't return a HashTable"
                $return_value = @()
                { update } | Should Throw "returned nothing"
            }

            It "rethrows if au_GetLatest throws" {
                function global:au_GetLatest { throw 'test' }
                { update } | Should Throw "test"
            }

            It 'checks values in $Latest when entering au_GetLatest' {
                function global:au_GetLatest {
                    $Latest.Count       | Should Be 1
                    $Latest.PackageName | Should Be 'test_package'
                    @{ Version = '1.2' }
                }
                update
            }

            It 'supports returning "ignore"' {
                function global:au_GetLatest { 'ignore' }
                $res = update
                $res | Should BeExactly 'ignore'
            }

            It 'supports returning custom values' {
                function global:au_GetLatest { @{ Version = '1.2'; NewValue = 1 } }
                update
                $global:Latest.NewValue | Should Be 1
            }

            It 'supports adding values to $global:Latest' {
                function global:au_GetLatest { $global:Latest += @{ NewValue = 1 }; @{ Version = '1.2' } }
                update
                $global:Latest.NewValue | Should Be 1
            }

            It 'supports adding values to $Latest' {
                function global:au_GetLatest { $Latest.NewValue = 1; @{ Version = '1.2' } }
                update
                $global:Latest.NewValue | Should Be 1
            }

            $testCases = @(
                @{ Version = '1.2'; Type = [string] }
                @{ Version = [AUVersion] '1.2'; Type = [AUVersion] }
                @{ Version = [version] '1.2'; Type = [version] }
                @{ Version = [regex]::Match('1.2', '^(.+)$').Groups[1]; Type = [string] }
            )

            It 'supports various Version types' -TestCases $testCases { param($Version)
                function global:au_GetLatest { @{ Version = $Version } }
                { update } | Should Not Throw
            }

            It 'supports various Version types when forcing update' -TestCases $testCases { param($Version, $Type)
                function global:au_GetLatest { @{ Version = $Version } }
                function global:au_BeforeUpdate { $Latest.Version | Should BeOfType $Type }
                { update -Force } | Should Not Throw
            }
        }

        Context 'Before and after update' {
            It 'calls au_BeforeUpdate if package is updated' {
                function au_BeforeUpdate { $global:Latest.test = 1 }
                update
                $global:Latest.test | Should Be 1
            }

            It 'calls au_AfterUpdate if package is updated' {
                function au_AfterUpdate { $global:Latest.test = 1 }
                update
                $global:Latest.test | Should Be 1
            }

            It 'doesnt call au_BeforeUpdate if package is not updated' {
                get_latest -Version 1.2.3
                function au_BeforeUpdate { $global:Latest.test = 1 }
                update
                $global:Latest.test | Should BeNullOrEmpty
            }
        }
    }
    Set-Location $saved_pwd
}

