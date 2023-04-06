# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 15-Nov-2016.

<#
.SYNOPSIS
    Test Chocolatey package

.DESCRIPTION
    The function can test install, uninistall or both and provide package parameters during test.
    It will force install and then remove the Chocolatey package if called without arguments.

    It accepts either nupkg or nuspec path. If none specified, current directory will be searched
    for any of them.

.EXAMPLE
    Test-Package -Install

    Test the install of the package from the current directory.

.LINK
    https://github.com/chocolatey/choco/wiki/CreatePackages#testing-your-package
#>
function Test-Package {
    [CmdletBinding(DefaultParameterSetName="Local")]
    param(
        # If file, path to the .nupkg or .nuspec file for the package.
        # If directory, latest .nupkg or .nuspec file wil be looked in it.
        # If ommited current directory will be used.
        [Parameter(Position=0)]
        $Nu,

        # Test chocolateyInstall.ps1 only.
        [switch] $Install,

        # Test chocolateyUninstall.ps1 only.
        [switch] $Uninstall,

        # Package parameters
        [string] $Parameters,

        # Path to chocolatey-test-environment: https://github.com/majkinetor/chocolatey-test-environment
        [Parameter(ParameterSetName="Vagrant")]
        [string] $Vagrant = $env:au_Vagrant,

        [Parameter(ParameterSetName="Vagrant")]
        # Open new shell window
        [switch] $VagrantOpen,

        # Do not remove existing packages from vagrant package directory
        [Parameter(ParameterSetName="Vagrant")]
        [switch] $VagrantNoClear,

        # Invokes the package test within Windows Sandbox, if available
        [Parameter(ParameterSetName="Sandbox")]
        [switch] $Sandbox,

        # If set, does not destroy the Windows Sandbox instance or files.
        [Parameter(ParameterSetName="Sandbox")]
        [switch] $NoDestroy,

        # Timeout for attempt to install and uninstall to Windows Sandbox, in minutes.
        [Parameter(ParameterSetName="Sandbox")]
        [uint16] $Timeout = 5
    )

    if (!$Install -and !$Uninstall) { $Install = $true }

    if (!$Nu) { $dir = Get-Item $pwd }
    else {
        if (!(Test-Path $Nu)) { throw "Path not found: $Nu" }
        $Nu = Get-Item $Nu
        $dir = if ($Nu.PSIsContainer) { $Nu; $Nu = $null } else { $Nu.Directory }
    }

    if (!$Nu) {
        $Nu = Get-Item $dir/*.nupkg | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
        if (!$Nu) { $Nu = Get-Item $dir/*.nuspec }
        if (!$Nu) { throw "Can't find nupkg or nuspec file in the directory" }
    }

    if ($Nu.Extension -eq '.nuspec') {
        Write-Host "Nuspec file given, running choco pack"
        choco pack -r $Nu.FullName --OutputDirectory $Nu.DirectoryName | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco pack failed with $LastExitCode"}
        $Nu = Get-Item ([System.IO.Path]::Combine($Nu.DirectoryName, '*.nupkg')) | Sort-Object -Property CreationTime -Descending | Select-Object -First 1
    } elseif ($Nu.Extension -ne '.nupkg') { throw "File is not nupkg or nuspec file" }

    # At this point Nu is nupkg file

    $package_name    = $Nu.Name -replace '(\.\d+)+(-[^-]+)?\.nupkg$'
    $package_version = ($Nu.BaseName -replace $package_name).Substring(1)

    Write-Host "`nPackage info"
    Write-Host "  Path:".PadRight(15)      $Nu
    Write-Host "  Name:".PadRight(15)      $package_name
    Write-Host "  Version:".PadRight(15)   $package_version
    if ($Parameters) { Write-Host "  Parameters:".PadRight(15) $Parameters }

    if ($Sandbox) {
        if (-not (Get-Command WindowsSandbox -ErrorAction SilentlyContinue)) {
            Write-Error "Windows Sandbox is not available. Please try Local or Vagrant methods." -ErrorAction Stop
        }
        Write-Host "`nTesting package using Windows Sandbox"

        $SandboxTempFolder = Join-Path $env:TEMP "$(New-Guid)"
        $null = New-Item -Path $SandboxTempFolder\ChocoTestingSandbox.wsb -Force -Value @"
            <Configuration>
                <Networking>Enable</Networking>
                <MappedFolders>
                    <MappedFolder>
                        <HostFolder>$($SandboxTempFolder)</HostFolder>
                        <SandboxFolder>C:\packages\</SandboxFolder>
                        <ReadOnly>false</ReadOnly>
                    </MappedFolder>
                </MappedFolders>
                <LogonCommand>
                    <Command>C:\packages\Test-Package.cmd</Command>
                </LogonCommand>
            </Configuration>
"@

        $TestCommand = @(
            'Start-Transcript -Path c:\packages\log.txt'
            '$Results = @{}'
            if ($Install) {
                "choco install -y $package_name --version $package_version --no-progress --source `"'C:\packages\;https://community.chocolatey.org/api/v2/'`"$(if ($Parameters) {[string]::format(' --packageParameters="''{0}''"', $Parameters)}) | Write-Host"
                '$Results.InstallExitCode = $LASTEXITCODE'
            }
            if ($Uninstall) {
                "choco uninstall -y $package_name | Write-Host"
                '$Results.UninstallExitCode = $LASTEXITCODE'
            }
            'Stop-Transcript'
            'Copy-Item C:\ProgramData\chocolatey\logs\* -Destination C:\packages\'
            '$Results | Export-Clixml -Path C:\packages\results.clixml'
        ) -join '; '
        $null = New-Item -Path $SandboxTempFolder\Test-Package.cmd -Value @"
            @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))" && SET "PATH=%PATH%;%ALLUSERSPROFILE%\chocolatey\bin"
            @"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -InputFormat None -ExecutionPolicy Bypass -Command "$($TestCommand)"
"@
        Copy-Item -Path $Nu -Destination $SandboxTempFolder

        try {
            & WindowsSandbox "$SandboxTempFolder\ChocoTestingSandbox.wsb"

            $Timer = [System.Diagnostics.Stopwatch]::StartNew()
            $BytesShown = 0  # Nothing shown yet
            while ($Timer.IsRunning -and $Timer.Elapsed.TotalMinutes -lt $Timeout) {
                if (Test-Path $SandboxTempFolder\log.txt) {
                    $Log = Get-Content $SandboxTempFolder\log.txt -Raw
                    -join $Log[$BytesShown..$Log.Length] | Write-Host -NoNewLine
                    $BytesShown = $Log.Length
                }

                if (Test-Path $SandboxTempFolder\results.clixml) {
                    $Timer.Stop()
                }

                Start-Sleep -Milliseconds 500
            }
        } finally {
            if (Test-Path $SandboxTempFolder\results.clixml) {
                $Results = Import-Clixml $SandboxTempFolder\results.clixml

                if ($Install) {
                    if ($Results.InstallExitCode -ne 0) { throw "choco install failed with $($Results.InstallExitCode)"}
                }
                if ($Uninstall) {
                    if ($Results.UninstallExitCode -ne 0) { throw "choco install failed with $($Results.UninstallExitCode)"}
                }
            } else {
                Write-Error "Test failed after $($Timeout) minutes without a results file."
            }

            if (-not $NoDestroy) {
                Get-Process WindowsSandboxClient | Stop-Process

                $Tries = 0
                while ($Tries++ -lt 4 -and (Test-Path $SandboxTempFolder)) {
                    try {
                        Remove-Item $SandboxTempFolder -Recurse -Force -ErrorAction Stop
                    } catch {
                        Start-Sleep -Seconds 1
                    }
                }
            } else {
                Write-Host "Logs and Results can be found in '$($SandboxTempFolder)'"
            }
        }
        return
    }

    if ($Vagrant) {
        Write-Host "  Vagrant: ".PadRight(15) $Vagrant
        Write-Host "`nTesting package using vagrant"

        if (!$VagrantNoClear)  {
            Write-Host 'Removing existing vagrant packages'
            Remove-Item ([System.IO.Path]::Combine($Vagrant, 'packages', '*.nupkg')) -ea ignore
            Remove-Item ([System.IO.Path]::Combine($Vagrant, 'packages', '*.xml'))   -ea ignore
        }

        Copy-Item $Nu (Join-Path $Vagrant 'packages')
        $options_file = "$package_name.$package_version.xml"
        @{ Install = $Install; Uninstall = $Uninstall; Parameters = $Parameters } | Export-CliXML ([System.IO.Path]::Combine($Vagrant, 'packages', $options_file))
        if ($VagrantOpen) {
            Start-Process powershell -Verb Open -ArgumentList "-NoProfile -NoExit -Command `$Env:http_proxy=`$Env:https_proxy=`$Env:ftp_proxy=`$Env:no_proxy=''; cd $Vagrant; vagrant up"
        } else {
            powershell -NoProfile -Command "`$Env:http_proxy=`$Env:https_proxy=`$Env:ftp_proxy=`$Env:no_proxy=''; cd $Vagrant; vagrant up"
        }
        return
    }

    if ($Install) {
        Write-Host "`nTesting package install"
        choco install -y -r $package_name --version $package_version --source "'$($Nu.DirectoryName);https://community.chocolatey.org/api/v2/'" --force --packageParameters "'$Parameters'" | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco install failed with $LastExitCode"}
    }

    if ($Uninstall) {
        Write-Host "`nTesting package uninstall"
        choco uninstall -y -r $package_name | Write-Host
        if ($LASTEXITCODE -ne 0) { throw "choco uninstall failed with $LastExitCode"}
    }
}
