Describe 'Snippet plugin' -Tag plugins {
    $plugin_path = "$PSScriptRoot\..\Chocolatey-AU\Plugins\Snippet.ps1"

    It 'should use basic parsing for the web request' {
        'report' | Set-Content TestDrive:\report.md
        Mock Invoke-WebRequest {}

        & $plugin_path -Info $null -Id 1 -ApiToken 'apiToken' -Path TestDrive:\report.md | Out-Null

        Assert-MockCalled Invoke-WebRequest -Exactly 1 -Scope It -ParameterFilter { $UseBasicParsing }
    }
}
