# Migrating From AU To Chocolatey AU

With the [`1.0.0` release] of Chocolatey AU, there is a need to migrate to the new package name.

How you migrate from AU to Chocolatey AU will depend on how you used AU in your repository. Below are some scenarios, if you encounter a scenario not yet covered, please reach out in the [Chocolatey Community].

## Your Repository Currently Clones The [Original AU Repository]

If you are cloning the [original AU repository] and building the module from there, you will want to update to clone the Chocolatey Community Chocolatey AU repository: `https://github.com/chocolatey-community/chocolatey-au.git` instead. Once that has been done, you will want to [update your update scripts](#updating-your-update-scripts) to use the `Chocolatey-AU` PowerShell Module instead of `AU`.

## Your Repository Installs AU From The [Chocolatey Community Repository]

If you are installing `AU` from the [Chocolatey Community Repository], you will want to update it to `choco install chocolatey-au --confirm` instead of `choco install au --confirm`. Once that has been done, you will want to [update your update scripts](#updating-your-update-scripts) to use the `Chocolatey-AU` PowerShell Module instead of `AU`.

## Your Repository Installs AU From The [Powershell Gallery]

If you are installing `AU` from the [PowerShell Gallery], you will want to update it to `Install-Module Chocolatey-AU` instead of `Install-Module AU`. Once that has been done, you will want to [update your update scripts](#updating-your-update-scripts) to use the `Chocolatey-AU` PowerShell Module instead of `AU`.

## Updating Your Update Scripts

Once you have updated your repository to use the new module name, you will need to update your `update.ps1` scripts to use the new module name. This is as simple as replacing `AU` with `Chocolatey-AU` for any call to `Import-Module`, or any `#requires -Modules` in you `update.ps1` scripts.

[`1.0.0` release]: https://github.com/chocolatey-community/chocolatey-au/releases/tag/1.0.0
[Chocolatey Community]: https://ch0.co/community
[Chocolatey Community Repository]: https://community.chocolatey.org/
[PowerShell Gallery]: https://powershellgallery.com
[Original AU Repository]: https://github.com/majkinetor/au/
