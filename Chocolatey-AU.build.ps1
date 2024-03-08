param(
    [string]
    $OutputDirectory = "$PSScriptRoot/code_drop",


    [string]
    $TimeStampServer = $(
        if ($env:CERT_TIMESTAMP_URL) {
            $env:CERT_TIMESTAMP_URL
        }
        else {
            'http://timestamp.digicert.com'
        }
    ),

    [string]
    $CertificatePath = $env:CHOCOLATEY_OFFICIAL_CERT,

    [string]
    $CertificatePassword = $env:CHOCOLATEY_OFFICIAL_CERT_PASSWORD,


    [string]
    $CertificateAlgorithm = $(
        if ($env:CERT_ALGORITHM) {
            $env:CERT_ALGORITHM
        }
        else {
            'Sha256'
        }
    ),

    [string]
    $CertificateSubjectName = "Chocolatey Software, Inc.",


    [string]
    $NugetApiKey = $env:POWERSHELLPUSH_API_KEY,


    [string]
    $PublishUrl = $env:POWERSHELLPUSH_SOURCE,


    [string]
    $ChocolateyNugetApiKey = $env:CHOCOOPSPUSH_API_KEY,


    [string]
    $ChocolateyPublishUrl = $env:CHOCOOPSPUSH_SOURCE,


    [string]
    $ModuleName = 'Chocolatey-AU',


    [switch]
    $ThrowOnPSSAViolation
)

$ErrorActionPreference = 'Stop'

$script:SourceFolder = "$PSScriptRoot/src"
$script:ReleaseBuild = -not [string]::IsNullOrEmpty((git tag --points-at HEAD 2> $null) -replace '^v')
$script:BuildVersion = $null
$script:IsPrerelease = $false
$script:ModuleOutputDir = "$OutputDirectory/$ModuleName"


# Fix for Register-PSRepository not working with https from StackOverflow:
# https://stackoverflow.com/questions/35296482/invalid-web-uri-error-on-register-psrepository/35296483#35296483
function Register-PSRepositoryFix {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Name,

        [Parameter(Mandatory = $true)]
        [Uri]
        $SourceLocation,

        [ValidateSet('Trusted', 'Untrusted')]
        $InstallationPolicy = 'Trusted'
    )

    $ErrorActionPreference = 'Stop'

    try {
        Write-Verbose 'Trying to register via Register-PSRepository'
        Register-PSRepository -Name $Name -SourceLocation $SourceLocation -InstallationPolicy $InstallationPolicy -ErrorAction Stop
        Write-Verbose 'Registered via Register-PSRepository'
    }
    catch {
        Write-Verbose 'Register-PSRepository failed, registering via workaround'

        # Adding PSRepository directly to file
        Register-PSRepository -Name $Name -SourceLocation $env:TEMP -InstallationPolicy $InstallationPolicy -ErrorAction Stop
        $PSRepositoriesXmlPath = "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\PowerShellGet\PSRepositories.xml"
        $repos = Import-Clixml -Path $PSRepositoriesXmlPath
        $repos[$Name].SourceLocation = $SourceLocation.AbsoluteUri
        $repos[$Name].PublishLocation = [uri]::new($SourceLocation, 'package').AbsoluteUri
        $repos[$Name].ScriptSourceLocation = ''
        $repos[$Name].ScriptPublishLocation = ''
        $repos | Export-Clixml -Path $PSRepositoriesXmlPath

        # Reloading PSRepository list
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-Verbose 'Registered via workaround'
    }
}

# Synopsis: ensure GitVersion is installed
task InstallGitVersion {
    if ((-not (Get-Command gitversion -ErrorAction Ignore)) -and (-not (Get-Command dotnet-gitversion -ErrorAction Ignore))) {
        Write-Host "Gitversion not installed. Attempting to install"

        if (-not ([Security.Principal.WindowsPrincipal]([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){
            throw "You are not an administrator. We cannot use Chocolatey to install gitversion.portable."
        }

        choco install gitversion.portable -y --no-progress
    }
}

# Synopsis: ensure PowerShellGet has the NuGet provider installed
task BootstrapPSGet {
    if (-not (Get-PackageProvider NuGet -ErrorAction Ignore)) {
        Write-Host "Installing NuGet package provider"
        Install-PackageProvider NuGet -MinimumVersion 2.8.5.201 -ForceBootstrap -Force
    }

    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

    if (-not (Get-InstalledModule PowerShellGet -MinimumVersion 2.0 -MaximumVersion 2.99 -ErrorAction Ignore)) {
        Install-Module PowerShellGet -MaximumVersion 2.99 -Force -AllowClobber -Scope CurrentUser
        Remove-Module PowerShellGet -Force
        Import-Module PowerShellGet -MinimumVersion 2.0 -Force
        Import-PackageProvider -Name PowerShellGet -MinimumVersion 2.0 -Force
    }
}

# Synopsis: ensure Pester is installed
task InstallPester BootstrapPSGet, {
    if (-not (Get-InstalledModule Pester -MaximumVersion 4.99 -ErrorAction SilentlyContinue)) {
        Write-Host "Installing Pester"
        Install-Module Pester -MaximumVersion 4.99 -SkipPublisherCheck -Force -Scope CurrentUser -ErrorAction Stop -Verbose:$false
    }
}

# Synopsis: ensure PSScriptAnalyzer is installed
task InstallScriptAnalyzer BootstrapPSGet, {
    if (-not (Get-InstalledModule PSScriptAnalyzer -MinimumVersion 1.20 -ErrorAction SilentlyContinue)) {
        Write-Host "Installing PSSA"
        Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -MinimumVersion 1.20 -ErrorAction Stop -Verbose:$false
    }
}

# Synopsis: cleanup build artifacts
task Clean {
    remove $OutputDirectory
    New-Item -Path $OutputDirectory -ItemType Directory | Out-Null
}

# Synopsis: run PSScriptAnalyzer on project files
task ScriptAnalyzer InstallScriptAnalyzer, {
    $results = Invoke-ScriptAnalyzer -Path $script:SourceFolder -Recurse -Settings "$PSScriptRoot/PSScriptAnalyzerSettings.psd1"
    if ($results) {
        Write-Warning "$($results.Count) PSSA rule violations found."
        $results
        # Chocolatey-AU currently has lots of PSSA violations. None of them are errors in PSSA.
        # For now, the build will not fail on PSSA unless asked.
        if ($ThrowOnPSSAViolation) {
            throw "PSSA rule violations detected, see above errors for more information"
        }
    }
}

# Synopsis: build the project
task Build Clean, InstallGitVersion, ScriptAnalyzer, {
    New-Item $script:ModuleOutputDir -ItemType Directory | Out-Null

    Copy-Item "$script:SourceFolder/*" -Destination $script:ModuleOutputDir -Recurse
    $manifest = Get-ChildItem "$OutputDirectory/$ModuleName/$ModuleName.psd1"

    $gitversion = if (Get-Command gitversion -ErrorAction Ignore)
    {
        gitversion.exe
    }
    else {
        dotnet-gitversion.exe
    }

    $gitversion | Out-String -Width 120 | Write-Host
    $versionInfo = $gitversion 2>$null | ConvertFrom-Json
    $manifestUpdates = @{
        Path          = $manifest.FullName
        ModuleVersion = $versionInfo.MajorMinorPatch
    }

    $prerelease = $versionInfo.NuGetPreReleaseTagV2 -replace '[^a-z0-9]'

    if ($prerelease) {
        if ($prerelease -notmatch '^(alpha|beta)') {
            $prerelease = "alpha$prerelease"
        }

        if ($prerelease.Length -gt 20) {
            $prerelease = $prerelease.Substring(0, 20)
        }

        $manifestUpdates.Prerelease = $prerelease
        $script:IsPrerelease = $true
    }

    $script:BuildVersion = if ($prerelease) {
        "$($versionInfo.MajorMinorPatch)-$prerelease"
    }
    else {
        $versionInfo.MajorMinorPatch
    }

    $help_dir = "${script:ModuleOutputDir}/en-US"
    New-Item -Type Directory -Force $help_dir | Out-Null
    Get-Content $PSScriptRoot/README.md | Select-Object -Skip 4 | Set-Content "$help_dir/about_$ModuleName.help.txt" -Encoding ascii

    Update-ModuleManifest @manifestUpdates
}

# Synopsis: Create the Chocolatey Package
task CreateChocolateyPackage -After Sign {
    $ReadmePath = "$PSScriptRoot/README.md"
    $Readme = Get-Content $ReadmePath -Raw

    if (-not ($Readme -match '## Features(.|\n)+?(?=\n##)'))
    {
        throw "No 'Features' found in '$ReadmePath'"
    }

    $features = $Matches[0]
    $ChocolateyPackageDir = "$OutputDirectory/temp/chocolateyPackage"
    New-Item $ChocolateyPackageDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
    Copy-Item $PSScriptRoot/chocolatey/* $ChocolateyPackageDir -Recurse
    $nuspecPath = "$ChocolateyPackageDir/chocolatey-au.nuspec"
    [xml]$chocolateyPackage = Get-Content $nuspecPath
    $description = $chocolateyPackage.package.metadata.summary + ".`n`n" + $features
    $chocolateyPackage.package.metadata.description = $description
    $chocolateyPackage.Save($nuspecPath)
    Copy-Item $script:ModuleOutputDir $ChocolateyPackageDir/tools -Recurse -Force
    choco pack $nuspecPath --outputdirectory $OutputDirectory --version $script:BuildVersion
    $script:ChocolateyPackagePath = Get-ChildItem $OutputDirectory -Filter *.nupkg | Select-Object -ExpandProperty FullName

    if (-not (Test-Path $script:ChocolateyPackagePath)) {
        throw 'Chocolatey Package failed to pack.'
    }
}

# Synopsis: zip up the built project
task Create7zipArchive -After Sign {
    $zip_path = "$OutputDirectory\${ModuleName}_${script:BuildVersion}.7z"
    $cmd = "$Env:ChocolateyInstall/tools/7z.exe a '$zip_path' '$OutputDirectory/$ModuleName' '$PSScriptRoot/chocolatey/tools/install.ps1'"
    $cmd | Invoke-Expression | Out-Null
    if (!(Test-Path $zip_path)) { throw "Failed to build 7z package" }
}

task ImportChecks -After Build {
    $publicFunctions = Get-Item "$script:SourceFolder/Public/*.ps1"

    Remove-Module $ModuleName -ErrorAction Ignore
    Import-Module $script:ModuleOutputDir -Force
    $actualFunctions = (Get-Module $ModuleName).ExportedFunctions
    if ($actualFunctions.Count -lt $publicFunctions.Count) {
        $missingFunctions = $publicFunctions.BaseName | Where-Object { $_ -notin $actualFunctions.Keys }
        $message = @(
            "src/Public: $($publicFunctions.Count) files"
            "${ModuleName}: $($actualFunctions.Count) exported functions"
            "some functions in the Public folder may not be exported"
            "missing functions may include: $($missingFunctions -join ', ')"
        ) -join "`n"
        Write-Warning $message
    }
    elseif ($publicFunctions.Count -lt $actualFunctions.Count) {
        $message = @(
            "src/Public: $($publicFunctions.Count) files"
            "${ModuleName}: $($actualFunctions.Count) exported functions"
            "there seems to be fewer files in the Public folder than public functions exported"
        ) -join "`n"
        Write-Warning $message
    }
}

# Synopsis: CI-specific build operations to run after the normal build
task CIBuild Build, {
    Write-Host $env:GitVersionTool

    Write-Host "##teamcity[buildNumber '$script:BuildVersion']"
}

# Synopsis: run Pester tests
task Test InstallPester, Build, {
    Import-Module Pester -MaximumVersion 4.99

    Copy-Item -Path "$script:SourceFolder/../Tests" -Destination "$OutputDirectory/Tests" -Recurse
    $results = Invoke-Pester (Resolve-Path "$OutputDirectory/Tests") -OutputFile "$OutputDirectory/test.results.xml" -OutputFormat NUnitXml -PassThru

    assert ($results.FailedCount -eq 0) "Pester test failures found, see above or the '$OutputDirectory/test.results.xml' result file for details"
}

# Synopsis: generate documentation files
task GenerateDocs {
    & "$PSScriptRoot/mkdocs.ps1"
}

# Synopsis: sign PowerShell scripts
task Sign -After Build {
    $ScriptsToSign = Get-ChildItem -Path $script:ModuleOutputDir -Recurse -Include '*.ps1', '*.psm1'

    if ($CertificatePath) {
        $CertificatePath = $CertificatePath
        $CertificatePassword = $CertificatePassword
    }
    else {
        $CertificateSubjectName = $CertificateSubjectName
    }


    $cert = if ($CertificatePath) {
        New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($CertificatePath, $CertificatePassword)
    }
    else {
        Get-ChildItem Cert:\LocalMachine\My | Where-Object Subject -Like "*$CertificateSubjectName*"
    }

    if ($null -eq $cert) {
        Write-Warning "No certificate found for signing. Module not being signed."
        return
    }

    Set-AuthenticodeSignature -FilePath $ScriptsToSign -Certificate $cert -TimestampServer $TimeStampServer -IncludeChain NotRoot -HashAlgorithm $CertificateAlgorithm
}

# Synopsis: publish $ModuleName either internally or to the PSGallery
task Publish -If ($script:ReleaseBuild -or $PublishUrl) Build, {
    if (-not (Test-Path $OutputDirectory)) {
        throw 'Build the module with `Invoke-Build` or `build.ps1` before attempting to publish the module'
    }

    if (-not $NugetApiKey -or -not $ChocolateyNugetApiKey) {
        throw 'Please pass the API key for publishing to both the `-NugetApiKey` and `-ChocolateyNugetApiKey` parameter or set $env:POWERSHELLPUSH_API_KEY and $env:CHOCOOPSPUSH_API_KEY before publishing'
    }

    $psdFile = Resolve-Path $script:ModuleOutputDir
    $publishParams = @{
        Path        = $psdFile
        NugetApiKey = $NugetApiKey
    }

    if ($PublishUrl) {
        Write-Verbose "Publishing to '$PublishUrl'"
        $repo = Get-PSRepository | Where-Object PublishLocation -EQ $PublishUrl
        if ($repo) {
            $publishParams.Repository = $repo.Name
        }
        else {
            $testRepo = @{
                Name               = "$ModuleName"
                SourceLocation     = $PublishUrl
                InstallationPolicy = 'Trusted'
            }

            Register-PSRepositoryFix @testRepo
            $publishParams.Repository = "$ModuleName"
        }

        Publish-Module @publishParams
    }

    if ($ChocolateyPublishUrl) {
        Write-Verbose "Publishing to '$ChocolateyPublishUrl'"
        choco push $script:ChocolateyPackagePath --source $ChocolateyPublishUrl --key $ChocolateyNugetApiKey

        if ($LASTEXITCODE -ne 0) {
            throw "Chocolatey push to $ChocolateyPublishUrl failed."
        }
    }

    if ($script:ReleaseBuild) {
        Write-Verbose "Publishing to PSGallery"
        $publishParams.NugetApiKey = $env:POWERSHELLGALLERY_API_KEY
        $publishParams.Repository = 'PSGallery'

        Publish-Module @publishParams
    }
}

# Synopsis: CI configuration; test, build, sign the module, and publish
task CI CIBuild, Sign, Test, Publish

# Synopsis: default task; build and test
task . Build, Test
