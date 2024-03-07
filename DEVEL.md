# Development

The development requires Powershell 5+.

The `build.ps1` script used during development and has the following tasks:

- `Clean`
  - Remove the Output directory.
- `Build`
  - Build the module into a usable state.
- `Test`
  - Run the Pester tests on the module.
- `CreateChocolateyPackage`
  - Turn the built module into a Chocolatey package.


## Build and test

The builded module will be available in the `Output` directory.

```
./build.ps1
```
The following example commands can be run from the repository root:

| Description                                             | Command                                           |
| :---                                                    | :---                                              |
| Run just the build and do not run the Pester Tests      | `./build -Task Build`                             |
| Run the build the same way that CI will run it          | `./build.ps1 -Task CI -Verbose -ErrorAction Stop` |
| Clean temporary build files                             | `./build.ps1 -Task Clean`                         |
| Create a Chocolatey package                             | `./build.ps1 -Task CreateChocolateyPackage`       |
