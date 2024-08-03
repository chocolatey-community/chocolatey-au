> NOTE: This PowerShell module is maintained by the Chocolatey Community as the original maintainer [archived the repository](https://github.com/majkinetor/au/commit/7f9c84e1e15995595dae68b4e8d8a71f50417752). To avoid confusion, and allow easier differentiation, this project has been named `chocolatey-au`. Chocolatey and the Chocolatey Community thanks [majkinetor](https://github.com/majkinetor) for their work on the module over the years.

# Chocolatey Automatic Package Updater Module

This PowerShell module implements functions that can be used to automate [Chocolatey](https://chocolatey.org) package updates.

To learn more about Chocolatey automatic packages, please refer to the relevant [documentation](https://docs.chocolatey.org/en-us/create/automatic-packages).
To see Chocolatey-AU in action see [video tutorial](https://www.youtube.com/watch?v=m2XpV2LxyEI&feature=youtu.be).

## Features

- Use only PowerShell to create automatic update script for given package.
- Handles multiple streams with a single update script.
- Automatically downloads installers and provides/verifies checksums for x32 and x64 versions.
- Verifies URLs, nuspec versions, remote repository existence etc.
- Automatically sets the nuspec descriptions from a README.md files.
- Update single package or any subset of previously created Chocolatey-AU packages with a single command.
- Multithread support when updating multiple packages.
- Repeat or ignore specific failures when updating multiple packages.
- Plugin system when updating everything, with few integrated plugins to send email notifications, save results to gist and push updated packages to git repository.
- Use of global variables to change functionality.
- Sugar functions for Chocolatey package maintainers.
- Great performance - hundreds of packages can be checked and updated in several minutes.


## Installation

Chocolatey-AU module requires minimally PowerShell version 5: `$host.Version -ge '5.0'`

To install it, use one of the following methods:
- PowerShell Gallery: [`Install-Module chocolatey-au`](https://www.powershellgallery.com/packages/Chocolatey-AU).
- Chocolatey:  [`choco install chocolatey-au`](https://chocolatey.org/packages/chocolatey-au).
- [Download](https://github.com/chocolatey-community/chocolatey-au/releases/latest) latest Chocolatey Package from GitHub.

To quickly start using Chocolatey-AU, fork [au-packages-template](https://github.com/majkinetor/au-packages-template) repository and rename it to `au-packages`.

**NOTE**: All module functions work from within specific root folder. The folder contains all of your Chocolatey packages.

## Creating the package updater script

The Chocolatey-AU uses `update.ps1` script that package maintainers should create in the package directory. No templates are used, just plain PowerShell.

To write the package update script, it is generally required to implement 2 functions: `au_GetLatest` and `au_SearchReplace`.

### `au_GetLatest`

This function is used to get the latest package information.

As an example, the following function uses [Invoke-WebRequest](https://technet.microsoft.com/en-us/library/hh849901.aspx?f=255&MSPPError=-2147217396) to download a page (#1). After that it takes a `href` attribute from the first page link that ends with `.exe` word as a latest URL for the package (#2). Then it conveniently splits the URL to get the latest version for the package (#3), a step that is highly specific to the URL but very easy to determine.

```powershell
function global:au_GetLatest {
     $download_page = Invoke-WebRequest -Uri $releases -UseBasicParsing #1
     $regex   = '.exe$'
     $url     = $download_page.links | ? href -match $regex | select -First 1 -expand href #2
     $version = $url -split '-|.exe' | select -Last 1 -Skip 2 #3
     return @{ Version = $version; URL32 = $url }
}
```

The returned version is later compared to the one in the nuspec file and if remote version is higher, the files will be updated. The returned keys of this HashTable are available via global variable `$global:Latest` (along with some keys that Chocolatey-AU generates). You can put whatever data you need in the returned HashTable - this data can be used later in `au_SearchReplace`.

### `au_SearchReplace`

Function returns HashTable containing search and replace data for any package file in the form:

```powershell
    @{
        file_path1 = @{
            search1 = replace1
            ...
            searchN = replaceN
        }
        file_path2 = @{ ... }
        ...
    }
```

Search and replace strings are operands for PowerShell [replace](http://www.regular-expressions.info/powershell.html) operator. You do not have to write them most of the time however, they are rarely changed.

File paths are relative to the package directory. The function can use `$global:Latest` variable to get any type of information obtained when `au_GetLatest` was executed along with some Chocolatey-AU generated data such as `PackageName`, `NuspecVersion` etc.

The following example illustrates the usage:

```powershell
function global:au_SearchReplace {
    @{
        "tools\chocolateyInstall.ps1" = @{
            "(^[$]url32\s*=\s*)('.*')"      = "`$1'$($Latest.URL32)'"           #1
            "(^[$]checksum32\s*=\s*)('.*')" = "`$1'$($Latest.Checksum32)'"      #2
        }
    }
}
```

Here, line of the format `$url32 = '<package_url>'` in the file `tools\chocolateyInstall.ps1` will have its quoted string replaced with latest URL (#1). The next line replaces value of the variable `$checksum32` on the start of the line with the latest checksum that is automatically injected in the `$Latest` variable by the Chocolatey-AU framework (#2). Replacement of the latest version in the nuspec file is handled automatically.

**NOTE**: The search and replace works on lines, multiple lines can not be matched with single regular expression.

### Update

With above functions implemented calling the `Update-Package` (alias `update`) function from the Chocolatey-AU module will update the package when needed.

You can then update the individual package by running the appropriate `update.ps1` script from within the package directory:

```
PS C:\chocolatey\dngrep> .\update.ps1
dngrep - checking updates using au version 2016.9.14
nuspec version: 2.8.15.0
remote version: 2.8.16.0
New version found
Automatic checksum started
Downloading dngrep 32 bit
  from 'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x86.msi'

Download of dnGREP.2.8.16.x86.msi (3.36 MB) completed.
Package downloaded and hash calculated for 32 bit version
Downloading dngrep 64 bit
  from 'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x64.msi'

Download of dnGREP.2.8.16.x64.msi (3.39 MB) completed.
Package downloaded and hash calculated for 64 bit version
Updating files
  dngrep.nuspec
    updating version:  2.8.15.0 -> 2.8.16.0
  tools\chocolateyInstall.ps1
    (^[$]url32\s*=\s*)('.*') = $1'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x86.msi'
    (^[$]url64\s*=\s*)('.*') = $1'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x64.msi'
    (^[$]checksum32\s*=\s*)('.*') = $1'CE4753735148E1F48FE0E1CD9AA4DFD019082F4F43C38C4FF4157F08D346700C'
    (^[$]checksumType32\s*=\s*)('.*') = $1'sha256'
    (^[$]checksum64\s*=\s*)('.*') = $1'025BD4101826932E954AACD3FE6AEE9927A7198FEEFFB24F82FBE5D578502D18'
    (^[$]checksumType64\s*=\s*)('.*') = $1'sha256'
Attempting to build package from 'dngrep.nuspec'.
Successfully created package 'dngrep.2.8.16.0.nupkg'
Package updated
```

This is best understood via the example - take a look at the real life package [installer script](https://github.com/majkinetor/au-packages/blob/master/dngrep/tools/chocolateyInstall.ps1) and its [AU updater](https://github.com/majkinetor/au-packages/blob/master/dngrep/update.ps1).

### Automatic package description from README.md

If a package directory contains the `README.md` file, its content will be automatically set as description of the package with first 2 lines omitted - you can put on those lines custom content that will not be visible in the package description.

To disable this option use `-NoReadme` switch with the `Update-Package` function. You can still call it manually from within `au_AfterUpdate`, which you may want to do in order to pass custom parameters to it:

```powershell
function global:au_AfterUpdate ($Package)  {
     Set-DescriptionFromReadme $Package -SkipLast 2 -SkipFirst 5
}
```

To extract descriptions from existing packages into README.md files the following script can be used:

```powershell
ls | ? PSIsContainer | ? { !(Test-Path $_\README.md) } | % {
  [xml] $package = gc $_\*.nuspec -ea 0 -Encoding UTF8
  if (!$package) { return }

  $meta = $package.package.metadata
  $readme = ('# <img src="{1}" width="48" height="48"/> [{0}](https://chocolatey.org/packages/{0})' -f $meta.id, $meta.iconUrl), ''
  $readme += $meta.description -split "`n" | % { $_.Trim() }
  $readme -join "`n" | Out-File -Encoding UTF8 $_\README.md
  $meta.id
}
```

### Checks

The `update` function does the following checks:

- The `$Latest.Version` will be checked to match a valid nuspec pattern.
- Any hash key that starts with the word `Url`, will be checked for existence and MIME textual type, since binary is expected here.
- If the remote version is higher then the nuspec version, the Chocolatey site will be checked for existence of this package version (this works for unpublished packages too). This allows multiple users to update same set of packages without a conflict. Besides, this feature makes it possible not to persist state between the updates as once the package is updated and pushed, the next update will not push the package again. To persist the state of updated packages you can use for instance [Git](Plugins/Git.ps1) plugin which saves the updated and published packages to the git repository.
- The regex patterns in `au_SearchReplace` will be checked for existence.

If any of the checks fails, package will not get updated. This feature releases you from the worries about how precise is your pattern match in both `au_` functions - if for example, a vendor site changes, the package update will fail because of the wrongly parsed data.

For some packages, you may want to disable some of the checks by specifying additional parameters of the `update` function (not all can be disabled):

| Parameter             | Description                       |
| ---------             | ------------                      |
| `NoCheckUrl`          | Disable URL checks                |
| `NoCheckChocoVersion` | Disable the Chocolatey site check |
| `ChecksumFor none`    | Disable automatic checksum        |

### Automatic checksums

**NOTE**: This feature works by invoking `chocolateyInstall.ps1` of the respective package with a [monkey-patched version of the `Get-ChocolateyWebFile` helper function](src/Public/Update-Package.ps1#L172). The install script is supposed to either call this function explicitly or indirectly (e.g. `Install-ChocolateyInstallPackage $url`, which calls the former one).
In any case, upon execution of `Get-ChocolateyWebFile`, the install script will be **terminated**. Any actions in your script occurring after the call to `Get-ChocolateyWebFile` will **not** be run. This is due to the nature of [how the function gets monkey-patched](src/Public/Update-Package.ps1#L172), which might be improved in the future.

When new version is available, the `update` function will by default download both x32 and x64 versions of the installer and calculate the desired checksum. It will inject this info in the `$global:Latest` HashTable variable so you can use it via `au_SearchReplace` function to update hashes. The parameter `ChecksumFor` can contain words `all`, `none`, `32` or `64` to further control the behavior.

You can disable this feature by calling update like this:

    update -ChecksumFor none

You can define the hash algorithm by returning corresponding `ChecksumTypeXX` hash keys in the `au_GetLatest` function:

    return @{ ... ChecksumType32 = 'sha512'; ... }

If the checksum is actually obtained from the vendor's site, you can provide it along with its type (SHA256 by default) by returning corresponding `ChecksumXX` hash keys in the `au_GetLatest` function:

    return @{ ... Checksum32 = 'xxxxxxxx'; ChecksumType32 = 'md5'; ... }

If the `ChecksumXX` hash key is present, the Chocolatey-AU will change to checksum verification mode - it will download the installer and verify that its checksum matches the one provided. If the key is not present, the Chocolatey-AU will calculate hash with the given `ChecksumTypeXX` algorithm.

### Manual checksums

Sometimes invoking `chocolateyInstall.ps1` during the automatic checksum could be problematic so you need to disable it using update option `ChecksumFor none` and get the checksum some other way. Function `Get-RemoteChecksum` can be used to simplify that:

```powershell
  function global:au_BeforeUpdate() {
     $Latest.Checksum32 = Get-RemoteChecksum $Latest.Url32
  }

  function global:au_GetLatest() {
    $download_page = Invoke-WebRequest $releases -UseBasicParsing
    $url     = $download_page.links | ? href -match '\.exe$' | select -First 1 -expand href
    $version = $url -split '/' | select -Last 1 -Skip 1
    @{
        URL32     = $url
        Version   = $version
    }
  }
```

### Force update

You can force the update even if no new version is found by using the parameter `Force` (or global variable `$au_Force`). This can be useful for testing the update and bug fixing, recalculating the checksum after the package was created and already pushed to Chocolatey or if URLs to installer changed without change in version.

**Example**:

```
PS C:\chocolatey\cpu-z.install> $au_Force = $true; .\update.ps1
cpu-z.install - checking updates
nuspec version: 1.77
remote version: 1.77
No new version found, but update is forced
Automatic checksum started
...
Updating files
  cpu-z.install.nuspec
    updating version using Chocolatey fix notation: 1.77 -> 1.77.0.20160814
...
```

Force option changes how package version is used. Without force, the `NuspecVersion` determines what is going on. Normally, if `NuspecVersion` is lower then the `RemoteVersion` update happens. With `Force` this changes:

1. If `NuspecVersion` is lower then `RemoteVersion`, Force is ignored and update happens as it would normally
2. If `NuspecVersion` is the same as the `RemoteVersion`, the version will change to chocolatey fix notation.
3. If the `NuspecVersion` is already using chocolatey fix notation, the version will be updated to fix notation for the current date.
4. If the `NuspecVersion` is higher then the `RemoteVersion` update will happen but `RemoteVersion` will be used.

Points 2-4 do not apply if you set the explicit version using the variable `au_Version`.

[Chocolatey fix notation](https://github.com/chocolatey/choco/wiki/CreatePackages#package-fix-version-notation) changes a version so that current date is added in the _revision_ component of the package version in the format `yyyyMMdd`. More precisely:

- chocolatey _fix version_ always ends up in to the _Revision_ part of the package version;
- existing _fix versions_ are changed to contain the current date;
- if _revision_ part is present in the package version and it is not in the _chocolatey fix notation_ form, Chocolatey-AU will keep the existing version but notify about it;

Force can be triggered also from the `au_GetLatest` function. This may be needed if remote version doesn't change but there was nevertheless change on the vendor site. See the [example](https://github.com/majkinetor/au-packages/blob/master/cpu-z.install/update.ps1#L18-L39) on how to update the package when remote version is unchanged but hashsum of the installer changes.

### Global variables

To avoid changing the `./update.ps1` when troubleshooting or experimenting you can set up any **already unset** `update` parameter via global variable. The names of global variables are the same as the names of parameters with the prefix `au_`. As an example, the following code will change the update behavior so that URL is not checked for existence and MIME type and update is forced:

    $au_NoCheckUrl = $au_Force = $true
    ./update.ps1

This is the same as if you added the parameters to `update` function inside the `./update.ps1` script:

    update -NoCheckUrl -Force

however, its way easier to setup global variable with manual intervention on multiple packages.

There is also a special variable `$au_GalleryPackageRootUrl` that can be added to `update.ps1` to change the URL that is used to check if package is already pushed. It defaults to `https://chocolatey.org/packages`, but you can change it if you need this option for 3rd party or internal package repositories.

* When updating all packages, `Update-AUPackages` (alias `updateall`), you should specify it as an environment variable.
* When adding to `update.ps1` you can specify it as a global variable, and it will override the environment setting.

> Note: The `$au_GalleryUrl` global variable also performs this function, but `$au_GalleryPackageRootUrl` allows more flexibility for internal and 3rd party package repositories.  The `$au_GalleryUrl` will still work for compatibility, but makes assumptions about the URL that may not work in all situations.

### Reusing the Chocolatey-AU updater with metapackages

Metapackages can reuse an Chocolatey-AU updater of its dependency by the following way:

- In the dependent updater, instead of calling the `update` directly, use construct:

  ```
    if ($MyInvocation.InvocationName -ne '.') { update ... }
  ```

- In the metapackage updater dot source the dependent updater and override `au_SearchReplace`.

This is best understood via example - take a look at the [cpu-z](https://github.com/majkinetor/au-packages/blob/master/cpu-z/update.ps1) Chocolatey-AU updater which uses the updater from the [cpu-z.install](https://github.com/majkinetor/au-packages/blob/master/cpu-z.install/update.ps1) package on which it depends. It overrides the `au_SearchReplace` function and the `update` call but keeps the `au_GetLatest`.

### Embedding binaries

Embedded packages do not download software from the Internet but contain binaries inside the package. This makes package way more stable as it doesn't depend on the network for installation - all versions of the package will **always work**, either on Chocolatey gallery or in your private cache.

AU function `Get-RemoteFiles` can download files and save them in the package's `tools` directory. It does that by using the `$Latest.URL32` and/or `$Latest.URL64`.

The following example downloads files inside `au_BeforeUpdate` function which is called before the package files are updated with the latest data (function is not called if no update is available):

```powershell
function global:au_BeforeUpdate() {
    #Download $Latest.URL32 / $Latest.URL64 in tools directory and remove any older installers.
    Get-RemoteFiles -Purge
}
```

This function will also set the appropriate `$Latest.ChecksumXX`.

**NOTE**: There is no need to use automatic checksum when embedding because `Get-RemoteFiles` will do it, so always use parameter `-ChecksumFor none`.

### Streams

The software vendor may maintain _multiple latest versions_, of specific releases because of the need for long time support. `au_GetLatest` provides an option to return multiple HashTables in order for its user to monitor each supported software _stream_. Prior to Chocolatey-AU streams, each software stream was typically treated as a separate package and maintained independently. Using Chocolatey-AU streams allows a single package updater to update multiple version streams in a single run:

```powershell
function global:au_GetLatest {
    # ...
    @{
        Streams = [ordered] @{
            '1.3' = @{ Version = $version13; URL32 = $url13 }  # $version13 = '1.3.9'
            '1.2' = @{ Version = $version12; URL32 = $url12 }  # $version12 = '1.2.3.1'
        }
    }
}
```

Though a `Hashtable` can be returned for streams, it is recommended to return an `OrderedDictionary` (see above example) that contains streams from the most recent to the oldest one. This ensures that when forcing an update, the most recent stream available will be considered by default (i.e. when no `-IncludeStream` is specified).

Latest stream versions are kept in the `<package_name>.json` file in the package directory. For real life example take a look at the [Python3](https://github.com/chocolatey/chocolatey-coreteampackages/blob/master/automatic/python3/update.ps1) package updater which automatically finds available python 3 streams and keeps them [up to date](https://gist.github.com/a14b1e5bfaf70839b338eb1ab7f8226f/78cdc99c2d7433d26c65bc721c26c1cc60ccca3d#python3).

Streams can be also used to manage multiple related packages as a single package. [LibreOffice](https://github.com/chocolatey-community/chocolatey-packages/blob/master/automatic/libreoffice-streams/update.ps1) package updater uses streams to manage [two different](https://gist.github.com/choco-bot/a14b1e5bfaf70839b338eb1ab7f8226f/78cdc99c2d7433d26c65bc721c26c1cc60ccca3d#libreoffice) variants of the software (prior to streams this was handled via 2 packages.)

In order to help working with versions, function `Get-Version` can be called in order to parse [semver](http://semver.org/) versions in a flexible manner. It returns an `AUVersion` object with all the details about the version. Furthermore, this object can be compared and sorted.

**NOTES**:
- By default only the first updated stream is pushed per run of `updateall`. In order to push all of them add among its options `PushAll = $true`.
- To force the update of the single stream, use `IncludeStream` parameter. To do so via commit message, use `[AU package\stream]` syntax.

```powershell
PS> Get-Version 'v1.3.2.7rc1'

Version Prerelease BuildMetadata
------- ---------- -------------
1.3.2.7 rc1

PS> $version = Get-Version '1.3.2-beta2+5'
PS> $version.ToString(2) + ' => ' + $version.ToString()
1.3 => 1.3.2-beta2+5
```

### WhatIf

If you don't like the fact that Chocolatey-AU changes the package inline, or just want to preview changes you can use `$WhatIf` parameter or `$au_WhatIf` global variable:

```powershell
PS C:\au-packages\copyq> $au_Force = $au_WhatIf = $true; .\update.ps1

WARNING: WhatIf passed - package files will not be changed
copyq - checking updates using au version 2017.5.21.172014
...
Successfully created package 'C:\au-packages\copyq\copyq.3.0.1.20170523.nupkg'
WARNING: Package restored and updates saved to: C:\Users\majkinetor\AppData\Local\Temp\au\copyq\_output
```

**NOTES**:
- The inline editing is intentional design choice so that Chocolatey-AU, its plugins and user scripts can use latest package data, such as latest version, checksum etc.
- WhatIf can be used when updating all packages.
- Since WhatIf saves the original package before the update and restores it after the update, interruption at specific time can cause package files to be left unrestored. In that case you can manually restore the package from `$Env:TEMP\au\<package_name>\_backup` directory. This is in general not very likely however, because restore happens very quickly after the update.

## Updating all packages

You can update all packages and optionally push them to the Chocolatey repository with a single command. Function `Update-AUPackages` (alias `updateall`) will iterate over `update.ps1` scripts and execute each in a separate thread. If it detects that a package is updated it will optionally try to push it to the Chocolatey repository and may also run configured plugins.

For the push to work, specify your Chocolatey API key in the file `api_key` in the script's directory (or its parent directory) or set the environment variable `$Env:api_key`. If none provided cached NuGet key will be used.

The function will search for packages in the current directory. To override that, use global variable `$au_Root`:

    PS> $au_root = 'c:\chocolatey_packages`
    PS> $Options = @{
        Timeout = 10
        Threads = 15
        Push    = $true
    }
    PS> updateall -Options $Options

    Updating 6 automatic packages at 2016-09-16 22:03:33
    Push is enabled
       copyq is updated to 2.6.1 and pushed
       dngrep had errors during update
           Can't validate URL 'https://github.com/dnGrep/dnGrep/releases/download/v2.8.16.0/dnGREP.2.8.16.x64.msi'
           Exception calling "GetResponse" with "0" argument(s): "The operation has timed out"
       eac has no updates
       pandoc has no updates
       plantuml has no updates
       yed had errors during update
           Can't validate URL 'https://www.yworks.com'
           Invalid content type: text/html

    Finished 6 packages after .32 minutes.
    1 updated and 1 pushed.
    2 errors - 2 update, 0 push.


Use `updateall` parameter `Name` to specify package names via glob, for instance `updateall [a-d]*` would update only packages which names start with the letter 'a' trough 'd'. Add `Push` among options to push successfully built packages to the chocolatey repository.

Take a look at the [real life example](http://tiny.cc/v1u1ey) of the update script. To see all available options for `updateall` type `man updateall -Parameter Options`.

### Plugins

It is possible to specify a custom user logic in `Options` parameter - every key that is of type `[HashTable]` will be considered plugin with the PowerShell script that is named the same as the key. The following code shows how to use 5 integrated plugins:

```powershell
    $Options = [ordered]@{
        Timeout = 100
        Threads = 15
        Push    = $true

        # Save text report in the local file report.txt
        Report = @{
            Type = 'text'
            Path = "$PSScriptRoot\report.txt"
        }

        # Then save this report as a gist using your api key and gist id
        Gist = @{
            ApiKey = $Env:github_api_key
            Id     = $Env:github_gist_id
            Path   = "$PSScriptRoot\report.txt"
        }

        # Persist pushed packages to your repository
        Git = @{
            User = ''
            Password = $Env:github_api_key
        }

        # Then save run info which can be loaded with Import-CliXML and inspected
        RunInfo = @{
            Path = "$PSScriptRoot\update_info.xml"
        }

        # Finally, send an email to the user if any error occurs and attach previously created run info
        Mail = if ($Env:mail_user) {
                @{
                   To          = $Env:mail_user
                   Server      = 'smtp.gmail.com'
                   UserName    = $Env:mail_user
                   Password    = $Env:mail_pass
                   Port        = 587
                   EnableSsl   = $true
                   Attachment  = "$PSScriptRoot\$update_info.xml"
                   UserMessage = 'Save attachment and load it for detailed inspection: <code>$info = Import-CliXCML update_info.xml</code>'
                }
        } else {}
    }
```

The plugins above - `Report`, `Gist`,`Git`,`RunInfo` and `Mail` -  are executed in the given order (hence the `[ordered]` flag) and Chocolatey-AU passes them given options and saves the run results.

To add custom plugins, specify additional plugin search path via `$Options.PluginPath`. Plugin is a normal PowerShell script and apart from parameters given in its HashTable the Chocolatey-AU will send it one more parameter `$Info` that contains current run info. The name of the script file must be the same as that of the key which value is used to pass the parameters to the plugin. If a key with the value of type `[HashTable]` doesn't point to existing PowerShell script it is not considered to be a Chocolatey-AU plugin.

To temporary disable plugins use `updateall` option `NoPlugins` or global variable `$au_NoPlugins`.
To temporary exclude the Chocolatey-AU package from `updateall` procedure add `_` prefix to the package directory name.

You can also execute a custom script via ScriptBlock specified via `BeforeEach` and `AfterEach` options. They will receive 2 parameters - package name and Options HashTable which you can use to pass any other parameter.

For more information take a look at the [plugins documentation](Plugins.md).

### Make a script

Its desirable to put everything in a single script `update_all.ps1` so it can be scheduled and called with the given options. Rename `update_all_default.ps1` and uncomment and set the options you need.

To make a local scheduled task, use the following code in the directory where your `update_all.ps1` script is found to install it:

    $At = '03:00'
    schtasks /create /tn "Update-AUPackages" /tr "powershell -File '$pwd\update_all.ps1'" /sc daily /st $At

Its preferable to run the updater on [AppVeyor](https://github.com/majkinetor/au/wiki/AppVeyor).

### Handling update errors

When errors occur during the `updateall` operation, email will be sent to the owner and report will contain [errors](https://gist.github.com/gep13/bd2eaa76f2a9ab739ca0544c502dca6e/c71d4eb3f6de2848f41c1b92e221737d775f0b6f#errors) section. Some network errors are expectable and you may want to ignore them - package that failed will get updated in one of the subsequent runs anyway. To ignore an error, use try/catch block around update and return 'ignore' word from the `update.ps1` script:

    try {
        update
    } catch {
        $ignore = 'Unable to connect to the remote server'
        if ($_ -match $ignore) { Write-Host $ignore; 'ignore' }  else { throw $_ }
    }


The package will get shown in the report as [ignored](https://gist.github.com/gep13/bd2eaa76f2a9ab739ca0544c502dca6e/db5313020d882945d8fcc3a10f5176263bb837a6#quicktime) and no errors will be shown.

Keyword `'ignore'` can also be used inside `au_GetLatest` function: returning this keyword instead of `$Latest` HashTable or as a result for particular stream will ignore that package or particular package stream.

If some errors occur in multiple packages, you can make `updateall` **repeat and/or ignore** such packages globally without any changes to `update.ps1` scripts. To do so, provide repeat/ignore options to its`$Options` HashTable parameter as in the following example:

```powershell
IgnoreOn = @(                                      #Error message parts to set the package ignore status
    'Timeout'
    'Access denied'
)
RepeatOn = @(                                      #Error message parts on which to repeat package updater
    'Unable to create secure channel'
    'Could not establish trust relationship'
    'Unable to connect'
)
RepeatSleep   = 120                                #How much to sleep between repeats in seconds, by default 0
RepeatCount   = 2                                  #How many times to repeat on errors, by default 1
```

**Notes**
- The repeat wont work if the package has its own ignore routine for the same error, because the package wont return an error in that case.
- If the same error is both in `RepeatOn` and `IgnoreOn` list, the package will first be repeated and if the error persists, it will be ignored.
- The last line returned by the package prior to the word 'ignore' is used as `IgnoreMessage` for that package and shown in reports.

#### Can't validate URL error

If you encounter `Can't validate URL` error like

```bash
Can't validate URL
Exception calling "GetResponse" with "0" argument(s): "The remote server returned an error: (401) Unauthorized.":<url>
```

you need to pass HTTP/HTTPS headers used for retrieving `url`/`url64bit` to `$Latest.Options.Headers` as `Hashtable`, where key is header name, and value are header itself. This may be `Authorization` or `Referer` header or any others.

## Linux support

AU is almost 100% usable on Linux platforms using pwsh.

The following notes apply to Linux environments:

1. Do not use automatic checksum. Use `-ChecksumFor None` instead and handle checksum manually using `Get-RemoteFiles` or similar
2. Check out how to [install choco on linux platforms](https://github.com/chocolatey/choco#other-platforms)
3. Nuspec `files` element directory separator needs to be changed to a forward slash manually

See details on adequate [issue](https://github.com/majkinetor/au/issues/234).

## Other functions

Apart from the functions used in the updating process, there are few sugars for regular maintenance of the package:

- Test-Package
Quickly test install and/or uninstall of the package from the current directory with optional parameters. This function can be used to start testing in [chocolatey-test-environment](https://github.com/majkinetor/chocolatey-test-environment) via `Vagrant` parameter.

- Push-Package
Push the latest package using your API key.

- Get-AuPackages (alias `gau` or `lsau`)
Returns the list of the packages which have `update.ps1` script in its directory and which name doesn't start with '_'.

## Community

- [Wormies AU Helpers](https://github.com/WormieCorp/Wormies-AU-Helpers)
Helper scripts to make maintaining packages using Chocolatey-AU even easier
- [Chocolatey Community Chocolatey Packages](https://github.com/chocolatey-community/chocolatey-packages)
The [largest](https://gist.github.com/choco-bot/a14b1e5bfaf70839b338eb1ab7f8226f) repository of Chocolatey-AU packages by far

## Repository

### Labels

The labels for this repository are synchronized from the [`chocolatey/.github`](https://github.com/chocolatey/.github) repository. Any labels not part of that configuration will be deleted. If you need to create additional labels, please follow the instructions for doing so over in that repository.
