import jetbrains.buildServer.configs.kotlin.v2019_2.*
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.XmlReport
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.xmlReport
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.PullRequests
import jetbrains.buildServer.configs.kotlin.v2019_2.buildFeatures.pullRequests
import jetbrains.buildServer.configs.kotlin.v2019_2.buildSteps.powerShell
import jetbrains.buildServer.configs.kotlin.v2019_2.triggers.vcs

project {
    buildType(ChocolateyAU)
}

object ChocolateyAU : BuildType({
    id = AbsoluteId("ChocolateyAU")
    name = "Build"

    artifactRules = """
        +:code_drop/**
    """.trimIndent()

    params {
        param("env.vcsroot.branch", "%vcsroot.branch%")
        param("env.Git_Branch", "%teamcity.build.vcs.branch.ChocolateyAU_ChocolateyAUVcsRoot%")
        param("teamcity.git.fetchAllHeads", "true")
        password("env.GITHUB_PAT", "%system.GitHubPAT%", display = ParameterDisplay.HIDDEN, readOnly = true)
    }

    vcs {
        root(DslContext.settingsRoot)

        branchFilter = """
            +:*
        """.trimIndent()
    }

    steps {
        step {
            name = "Include Signing Keys"
            type = "PrepareSigningEnvironment"
        }
        powerShell {
            name = "Build Module"
            formatStderrAsError = true
            scriptMode = script {
                content = """
                    try {
                        & .\build.ps1 -Task CI -Verbose -ErrorAction Stop
                    }
                    catch {
                    	${'$'}_ | Out-String | Write-Host -ForegroundColor Red
                        exit 1
                    }
                """.trimIndent()
            }
            noProfile = false
            param("jetbrains_powershell_script_file", "build.ps1")
        }
    }

    triggers {
        vcs {
            branchFilter = """

            """.trimIndent()
        }
    }

    features {
        xmlReport {
            reportType = XmlReport.XmlReportType.NUNIT
            rules = "code_drop/**/*.xml"
        }
        pullRequests {
            provider = github {
                authType = token {
                    token = "%system.GitHubPAT%"
                }
            }
        }
    }
})
