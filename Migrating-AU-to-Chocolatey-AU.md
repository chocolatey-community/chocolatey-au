# Migrating From `AU` To `Chocolatey-AU`

With the [`1.0.0` release](https://github.com/chocolatey-community/chocolatey-au/releases/tag/1.0.0) of `Chocolatey-AU`, there is a need to migrate to the new package name.

How you migrate from `AU` to `Chocolatey-AU` will depend on how you used `AU` in your repository. Below are some scenarios, but if you encounter a scenario not yet covered, please reach out in the [Chocolatey Community](https://ch0.co/community).

## Your Repository Currently Clones the Original `AU` Repository

If you are cloning the [original `AU` repository](https://github.com/majkinetor/au/) and building the module from there, you will want to update to clone the Chocolatey Community `Chocolatey-AU` repository: `https://github.com/chocolatey-community/chocolatey-au.git` instead. Once that has been done, you will want to [amend your update scripts](#amending-your-update-scripts) to use the `Chocolatey-AU` PowerShell Module instead of `AU`.

## Your Repository Installs AU From the Chocolatey Community Repository

If you are installing `AU` from the [Chocolatey Community Repository](https://community.chocolatey.org/), you will want to update it to `choco install chocolatey-au --confirm` instead of `choco install au -y`. Once that has been done, you will want to [update your update scripts](#amending-your-update-scripts) to use the `Chocolatey-AU` PowerShell Module instead of `AU`.

## Your Repository Installs AU From the Powershell Gallery

If you are installing `AU` from the [PowerShell Gallery](https://powershellgallery.com), you will want to amend your code to `Install-Module Chocolatey-AU` from `Install-Module AU`. Once that has been done, you will want to [amend your update scripts](#amending-your-update-scripts) to use the `Chocolatey-AU` PowerShell Module instead of `AU`.

## Amending Your Update Scripts

Once  your repository uses the new module name, you will need to amend your `update.ps1` scripts to use the new module name. This is as simple as replacing `AU` with `Chocolatey-AU` for the `Import-Module` calls, or any `#requires -Modules` in your scripts.
