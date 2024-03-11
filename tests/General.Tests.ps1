remove-module Chocolatey-AU -ea ignore
import-module $PSScriptRoot\..\Chocolatey-AU\Chocolatey-AU.psm1 # Tests require the private functions exported

Describe 'General' {
    $saved_pwd = $pwd

    BeforeEach {
        Set-Location $TestDrive
        Remove-Item -Recurse -Force TestDrive:\test_package -ea ignore
        Copy-Item -Recurse -Force $PSScriptRoot\test_package TestDrive:\test_package
    }

    It 'considers au_root global variable when looking for packages' {
        $path = 'TestDrive:\packages\test_package2'
        New-Item -Type Directory $path -Force
        Copy-Item -Recurse -Force $PSScriptRoot\test_package\* $path

        $global:au_root = Split-Path $path
        $res = lsau

        $res | Should Not BeNullOrEmpty
        $res[0].Name | Should Be 'test_package2'
    }

    Set-Location $saved_pwd
}
