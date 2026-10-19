# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 09-Nov-2016.

# https://www.appveyor.com/docs/how-to/git-push/

param(
    $Info,

    # Git username
    [string] $User,

    # Git password. You can use Github Token here if you omit username.
    [string] $Password,

    # Force git commit when package is updated but not pushed.
    [switch] $Force,

    # Add the package to the repository if it was created during the update process.
    [switch] $AddNew,

    # Commit strategy:
    #  single    - 1 commit with all packages
    #  atomic    - 1 commit per package
    #  atomictag - 1 commit and tag per package
    [ValidateSet('single', 'atomic', 'atomictag')]
    [string]$commitStrategy = 'single',

    # Branch name
    [string]$Branch = 'master',

    # Overwrite the remote branch (with lease) instead of merging it; for topic branches rebuilt on every run
    [switch] $ForcePush,

    # Commit each package on its own "<Branch>-<package>" branch, for one pull request per package. Needs an atomic commit strategy.
    [switch] $BranchPerPackage
)

# Local scope only: git writes progress and server "remote:" lines to stderr, which 'Stop' would turn into a terminating error.
function Invoke-Git {
    $ErrorActionPreference = 'Continue'
    git @args
    if ($LASTEXITCODE -ne 0) { throw "git $args failed with exit code $LASTEXITCODE" }
}

[array]$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }
if ($packages.Length -eq 0) { Write-Host "No package updated, skipping"; return }
if ($BranchPerPackage -and $commitStrategy -notlike 'atomic*') { throw "BranchPerPackage needs commitStrategy 'atomic' or 'atomictag'" }

$root = Split-Path $packages[0].Path
Push-Location $root
$origin  = git config --get remote.origin.url

# Extract hostname from both HTTPS and SSH URLs
if ($origin -match '(?<=:/+)[^/]+')
{
    # HTTPS: https://github.com/user/repo
    $machine = $Matches[0]
}
elseif ($origin -match '(?<=@)[^:]+')
{
    # SSH: git@github.com:user/repo
    $machine = $Matches[0]
}
else
{
    throw "Could not parse hostname from git remote URL: $origin"
}

if ($User -and $Password) {
    Write-Host "Setting credentials for: $machine"

    if ( "machine $server" -notmatch (Get-Content ~/_netrc)) {
        Write-Host "Credentials already found for machine: $machine"
    }
    "machine $machine", "login $User", "password $Password" | Out-File -Append ~/_netrc -Encoding ascii
} elseif ($Password) {
    Write-Host "Setting oauth token for: $machine"
    git config --global credential.helper store
    Add-Content "$env:USERPROFILE\.git-credentials" "https://${Password}:x-oauth-basic@$machine`n"
}

$startSha = git rev-parse HEAD
$startRef = git symbolic-ref -q --short HEAD

if (-not $BranchPerPackage) {
    Write-Host "Checking out & resetting $Branch branch"
    Invoke-Git checkout -q -B $Branch
}

if ($ForcePush -or $BranchPerPackage) {
    Invoke-Git fetch -q origin
} else {
    Write-Host "Executing git pull"
    Invoke-Git pull -q origin $Branch
}

$gitAddArgs = @()
if (-not $AddNew)
{
    $gitAddArgs += @('--update')
}

if  ($commitStrategy -like 'atomic*') {
    $failedPushes = @()
    $packages | ForEach-Object {
        $package = $_
        if ($BranchPerPackage) {
            $packageBranch = "$Branch-$($_.Name)"
            Write-Host "Checking out & resetting $packageBranch branch"
            Invoke-Git checkout -q -B $packageBranch $startSha
        }

        Write-Host "Adding update package to git repository: $($_.Name)"
        Invoke-Git add @gitAddArgs $_.Path
        git status

        Write-Host "Commiting $($_.Name)"
        $message = "AU: $($_.Name) upgraded from $($_.NuspecVersion) to $($_.RemoteVersion)"
        $gist_url = $Info.plugin_results.Gist -split '\n' | Select-Object -Last 1
        $snippet_url = $Info.plugin_results.Snippet -split '\n' | Select-Object -Last 1
        Invoke-Git commit -m "$message`n[skip ci] $gist_url $snippet_url" --allow-empty

        if ($commitStrategy -eq 'atomictag') {
          Invoke-Git tag -a "$($_.Name)-$($_.RemoteVersion)" -m "$($_.Name)-$($_.RemoteVersion)"
        }

        if ($BranchPerPackage) {
            # A rejected push must not stop the remaining packages; failures are reported after the loop.
            try {
                Invoke-Git push -q --force-with-lease origin $packageBranch
            } catch {
                Write-Host "Push failed for $($package.Name): $_"
                $failedPushes += $package.Name
                if ($commitStrategy -eq 'atomictag') { git tag -d "$($package.Name)-$($package.RemoteVersion)" | Out-Null }
            }
        }
    }
}
else {
    Write-Host "Adding updated packages to git repository: $( $packages | % Name)"
    $packages | ForEach-Object { Invoke-Git add @gitAddArgs $_.Path }
    git status

    Write-Host "Commiting"
    $message = "AU: $($packages.Length) updated - $($packages | % Name)"
    $gist_url = $Info.plugin_results.Gist -split '\n' | Select-Object -Last 1
    $snippet_url = $Info.plugin_results.Snippet -split '\n' | Select-Object -Last 1
    Invoke-Git commit -m "$message`n[skip ci] $gist_url $snippet_url" --allow-empty

}
Write-Host "Pushing changes"
if ($BranchPerPackage) {
    Invoke-Git checkout -q $(if ($startRef) { $startRef } else { $startSha })
} elseif ($ForcePush) {
    Invoke-Git push -q --force-with-lease origin $Branch
} else {
    Invoke-Git push -q origin $Branch
}
if ($commitStrategy -eq 'atomictag') {
    write-host 'Atomic Tag Push'
    Invoke-Git push -q --tags
}
Pop-Location
if ($failedPushes) { throw "Git push failed for: $($failedPushes -join ', ')" }
