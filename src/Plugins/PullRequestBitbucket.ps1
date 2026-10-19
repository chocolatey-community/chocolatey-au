<#
.SYNOPSIS
    Creates a Bitbucket Server / Data Center pull request for the updated packages.

.DESCRIPTION
    This plugin will open a Bitbucket pull request for the commits created by the Git plugin, which of course needs to run first.
    It has an option to add reviewers to the created pull request, and can open one pull request per package
    from the branches created by the Git plugin's BranchPerPackage option.
#>
param(
    $Info,

    # Git branch to create a pull request for; the branch prefix when BranchPerPackage is set
    [string]$Branch,

    # Open one pull request per package from the "<Branch>-<package>" branches
    [switch]$BranchPerPackage,

    # Use updated packages instead of pushed ones; set it when the Git plugin runs with Force
    [switch]$Force,

    # Target Git branch for the pull request
    [string]$BaseBranch = "master",

    # Bitbucket usernames to be added to the list of reviewers
    [string[]]$Reviewers = @(),

    # Bitbucket base URL (e.g. https://stash.example.com). Derived from an HTTPS origin remote when omitted.
    [string]$BaseUrl,

    # Bitbucket HTTP access token, create in Profile -> Manage account -> HTTP access tokens
    [string]$ApiKey
)

[array]$packages = if ($Force) { $Info.result.updated } else { $Info.result.pushed }
if ($packages.Length -eq 0) { Write-Host "No package updated, skipping"; return }

$ErrorActionPreference = "Stop"

$origin = git config --get remote.origin.url

# HTTPS: https://host[/context]/scm/KEY/repo.git   SSH: ssh://git@host:7999/KEY/repo.git
if ($origin -notmatch '/(?:scm/)?(?<key>[^/]+)/(?<slug>[^/]+?)(?:\.git)?/?$') {
    throw "Could not parse project key and repository from git remote URL: $origin"
}
$projectKey = $Matches['key']
$repoSlug = $Matches['slug']

if (-not $BaseUrl) {
    if ($origin -notmatch '^(?<scheme>https?)://(?:[^@/]+@)?(?<host>[^/]+)(?<context>.*?)/scm/') {
        throw "BaseUrl is required when the origin remote is not an HTTPS Bitbucket URL: $origin"
    }
    $BaseUrl = "$($Matches['scheme'])://$($Matches['host'])$($Matches['context'])"
}
$BaseUrl = $BaseUrl.TrimEnd('/')

#https://github.com/majkinetor/au/issues/142
if ($PSVersionTable.PSVersion.major -ge 6) {
    $AvailableTls = [enum]::GetValues('Net.SecurityProtocolType') | Where-Object { $_ -ge 'Tls' } # PowerShell 6+ does not support SSL3, so use TLS minimum
    $AvailableTls.ForEach({[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor $_})
} else {
    [System.Net.ServicePointManager]::SecurityProtocol = 3072 -bor 768 -bor [System.Net.SecurityProtocolType]::Tls -bor [System.Net.SecurityProtocolType]::Ssl3
}

$repository = @{ slug = $repoSlug; project = @{ key = $projectKey } }

$pullRequests = if ($BranchPerPackage) {
    $packages | ForEach-Object {
        @{
            Branch      = "$Branch-$($_.Name)"
            Title       = "AU: $($_.Name) upgraded from $($_.NuspecVersion) to $($_.RemoteVersion)"
            Description = "* $($_.Name): $($_.NuspecVersion) -> $($_.RemoteVersion)"
        }
    }
} else {
    @{
        Branch      = $Branch
        Title       = if ($packages.Count -eq 1) {
            "AU: $($packages[0].Name) upgraded from $($packages[0].NuspecVersion) to $($packages[0].RemoteVersion)"
        } else {
            "AU: $($packages.Count) packages updated"
        }
        Description = ($packages | ForEach-Object { "* $($_.Name): $($_.NuspecVersion) -> $($_.RemoteVersion)" }) -join "`n"
    }
}

$failed = @()
foreach ($pr in $pullRequests) {
    $data = @{
        title       = $pr.Title
        description = $pr.Description
        state       = 'OPEN'
        fromRef     = @{ id = "refs/heads/$($pr.Branch)"; repository = $repository }
        toRef       = @{ id = "refs/heads/$BaseBranch"; repository = $repository }
    }
    if ($Reviewers) {
        $data.reviewers = @($Reviewers | ForEach-Object { @{ user = @{ name = $_ } } })
    }

    $params = @{
        ContentType     = 'application/json'
        Method          = 'POST'
        Uri             = "$BaseUrl/rest/api/1.0/projects/$projectKey/repos/$repoSlug/pull-requests"
        Body            = $data | ConvertTo-Json -Depth 6
        UseBasicParsing = $true
        Headers         = @{ 'Authorization' = "Bearer $ApiKey" }
    }
    try {
        try {
            $response = Invoke-WebRequest @params
            $prUrl = ($response.Content | ConvertFrom-Json).links.self[0].href
            Write-Host "Pull request successfully created: $prUrl"
        } catch {
            $apiError = try { ($_.ErrorDetails.Message | ConvertFrom-Json).errors[0] } catch { $null }
            if ($apiError.exceptionName -notlike '*DuplicatePullRequestException') { throw }

            # The branch was force-pushed, so the open pull request already holds the new commits; refresh its text.
            $open = $apiError.existingPullRequest
            $params['Method'] = 'PUT'
            $params['Uri'] = "$($params['Uri'])/$($open.id)"
            $params['Body'] = @{ version = $open.version; title = $pr.Title; description = $pr.Description } | ConvertTo-Json
            [void](Invoke-WebRequest @params)
            Write-Host "Pull request already open, updated: $($open.links.self[0].href)"
        }
    } catch {
        Write-Host "Failed to create pull request for $($pr.Branch): $_"
        $failed += $pr.Branch
    }
}

if ($failed) { throw "Pull request creation failed for: $($failed -join ', ')" }
