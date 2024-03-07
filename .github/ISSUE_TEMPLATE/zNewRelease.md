---
name: Create new Release Template
about: Use this template when starting to prepare a new release
title: "Release: Chocolatey AU v1.0.0"
labels: TaskItem, "2 - Working"
---

# Release Procedure

This documents the procedure that should be followed when releasing a new version of the Chocolatey AU project.
Most of the steps outlined in this document can be done by anyone with write access to the repository, with the exception of the built artifacts that need to come from a Chocolatey Team Member.

For the steps requiring a Chocolatey Team Member, reach out to one of the team members associated with the repository and ask them for the package artifact once a tag has been created.

- [ ] Update the issue title with the new version number of the release.
- [ ] All tagged releases of Chocolatey AU should come from:
  - [ ] The **master** branch for a normal release, or
  - [ ] A **support/*** branch if doing a backport/bugfix release for an earlier supported version, or
  - [ ] The **hotfix/*** or **release/*** branch, if a beta package is being released, or
  - [ ] The **develop** branch, if an alpha package is being released.
- [ ] Before moving forward, run `build.ps1 -Task CI` locally, to verify that everything builds as expected.
- [ ] Make sure all issues in the upcoming milestone have only one type label associated (A type label would be labels such as `Feature`, `Improvement`, `Enhancement`, `Bug Fix`, etc).
- [ ] If the GitHub milestone issues are still open, confirm that they are done before moving on. If they are in fact done, apply the `Done` label and close the issue.
- [ ] Update the GitHub milestones description if there is a need for any custom words that should be part of the release notes.
- [ ] Run the following command to generate release notes `gitreleasemanager.exe -m <release_version_here> --token $env:GITRELEASEMANAGER_PAT -o chocolatey-community -r chocolatey-au`
  - [ ] **NOTE:** This expects that you have GitReleaseManager installed. If you do not, it can be installed with `choco install gitreleasemanager.portable --confirm`
  - [ ] **NOTE:** If doing an alpha/beta release, don't run this step, instead generate the release notes manually. GitReleaseManager uses labels and milestones to generate the release notes, and therefore won't understand what needs to be done, especially when there are multiple alpha/beta releases.
  - [ ] Before running the above command, make sure you have set the environment variable `GITRELEASEMANAGER_PAT` to your own access token. This can be set through PowerShell with `$env:GITRELEASEMANAGER_PAT = "<token>"`. This token requires access to the labels, milestones, issues, pull requests and releases API.
  - [ ] This will generate a new draft release on GitHub - the URL to the release should be output from the above command.
  - [ ] If doing a release from a **develop**, **support**, **release** or **hotfix** branch, verify that the target branch for creating the new tag is correctly set, and we are **not** tagging against **master** for this release.
- [ ] Review the generated release notes to make sure that they are ok, with appropriate names, etc, make any changes if needed.
- [ ] **This step should only be done if this is NOT an alpha or beta release**. Merge the **hotfix** or **release** branch into the **master** or **support/*** base branches.
  - [ ] `git checkout master` OR `git checkout support/*` (**NOTE:** If you do not have access to push to the master branch, ask a Chocolatey Team Member to be granted bypass access).
  - [ ] `git merge --no-ff <branch name>` i.e. **hotfix/4.1.1** or **release/4.2.0**, whatever branch you are working on just now.
- [ ] Push the changes to the [upstream repository][], and to your fork of the repository.
  - [ ] `git push upstream` - here upstream is assumed to be the above repository.
  - [ ] `git push origin` - here origin is assumed to be your fork on the above repository
- [ ] Assuming everyone is happy, Publish the GitHub release.
  - [ ] This will trigger a tagged build on a private CI system. **NOTE:** Contact a Chocolatey Team Member about sending you the package artifact once it has been built if you have no access to internal systems.
  - [ ] Save the package acquired from the internal systems, or a Team Member to a local directory on your local system.
- [ ] Verify that the package can be installed and that it can be uninstalled.
  - [ ] Run `choco install chocolatey-au --source="'C:\testing'"` (_replace `C:\testing` with the location you sawed the package to_) and ensure that it successfully installs (_use upgrade if it was already installed_).
  - [ ] Run `choco uninstall chocolatey-au` and verify the package was successfully uninstalled.
- [ ] Go back to the releases page, and upload the package artifact `chocolatey-au` to the release.
- [ ] Push or ask a Chocolatey Team Member to push the previously uploaded artifact to the Chocolatey Community Repository (_Wait on confirmation that this has been pushed, and is pending moderation before moving further_).
- [ ] Move closed issues to `5 - Released` with the [Done Label][].
  - [ ] **NOTE:** This step should only be performed if this is a stable release. If an alpha/beta release, these issues won't be moved to released until the stable release is completed.
- [ ] Use GitReleaseManager to close the milestone so that all issues are updated with a message saying this has been released
  - [ ] **NOTE:** This step should only be performed if this is a stable release. While on alpha/beta release we don't want to update the issues, since this will happen in the final stable release.
  - [ ] Before running the below command, make sure you have set the environment variable `GITRELEASEMANAGER_PAT` to your own access token. This can be set through PowerShell with `$env:GITRELEASEMANAGER_PAT = "<token>"`. This token requires access to the labels, milestones, issues, pull requests and releases API.
  - [ ] Use a command similar to the following `gitreleasemanager.exe close -m <release_version_here> --token $env:GITRELEASEMANAGER_PAT -o chocolatey-community -r chocolatey-au`. This should become an automated step at some point in the build process.
- [ ] Once the package is available and approved on Chocolatey Community Repository, announce this release on the public [Discord Server][] under the channel `#community-maintainers` (_There is currently no format for this, but ensure a link to the release notes are included_).
- [ ] Next up, we need to finalise the merging of changes back to the **develop** branch. Depending on what type of release you were performing, the steps are going to be different.
  - [ ] If this release comes from the **master** branch:
    - [ ] `git switch develop`
    - [ ] `git merge --no-ff master`
    - [ ] There may be conflicts at this point, depending on if any changes have been made on the **develop** branch whilst the release was being done, these will need to be handled on a case by case basis.
  - [ ] If this release comes from a **support/*** branch, the following steps should be completed if changes made in this release need to be pulled into **develop**. This may not be necessary but check with folks before doing these steps:
    - [ ] Create a new branch, for example `merge-release-VERSION-change` from **develop**.
      - [ ] `git switch develop`
      - [ ] `git switch -c merge-release-1.2.3-changes`
    - [ ] Cherry-pick relevant commits from the release into this new branch.
      - [ ] `git cherry-pick COMMIT_HASH` (_multiple commit hashes may be added_).
      - [ ] Repeat until all relevant commits are incorporated.
      - [ ] If all commits since the last release on the **support/*** branch should be included, you can select these all at once with `git cherry-pick PREVIOUS_VERSION_TAG..support/*` (selecting the previous version tag and correct **support/*** base branch that the tag comes from).
    - [ ] Push this branch to you own fork of the repository, and PR the changes into the `develop` branch on GitHub.
- [ ] Delete the **hotfix** or **release** branch that was used during this process
  - [ ] **NOTE:** This steps should only be completed if there are no plans to do subsequent alpha/beta releases for this package version.
  - [ ] `git branch -d <hotfix or release branch name>`
  - [ ] If the hotfix or release branch was pushed to the upstream repository, delete it from there as well.
- [ ] Push the changes to [upstream repository][]
  - [ ] `git push upstream` - here upstream is assumed to be the above repository.
  - [ ] `git push origin` - here origin is assumed to be your fork off the above repository
- [ ] Update the information in the [Chocolatey Community Packages repository][]
  - [ ] In the `.appveyor.yml` script, find the mention of `chocolatey-au` and update its version to the released version number.
  - [ ] Submit a PR with the changes made.

[Discord Server]: https://ch0.co/community
[Done Label]: https://github.com/chocolatey-community/chocolatey-au/issues/?q=is%3Aissue+is%3Aclosed+label%3A%224+-+Done%22
[Releases]: https://github.com/chocolatey-community/chocolatey-au/releases
[upstream repository]: https://github.com/chocolatey-community/chocolatey-au
[Chocolatey Community Packages repository]: https://github.com/chocolatey-community/chocolatey-packages
