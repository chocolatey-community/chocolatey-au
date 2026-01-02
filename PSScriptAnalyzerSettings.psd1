@{
    IncludeRules = @(
        'PSUseBOMForUnicodeEncodedFile',
        'PSMisleadingBacktick',
        'PSAvoidUsingCmdletAliases',
        'PSAvoidTrailingWhitespace',
        'PSAvoidSemicolonsAsLineTerminators',
        'PSUseCorrectCasing',
        'PSPlaceOpenBrace',
        'PSPlaceCloseBrace',
        'PSAlignAssignmentStatement',
        'PSUseConsistentWhitespace',
        'PSUseConsistentIndentation'
    )

    Rules        = @{

        <#
        PSAvoidUsingCmdletAliases          = @{
            'allowlist' = @('')
        }#>

        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }

        PSUseCorrectCasing                 = @{
            Enable = $true
        }

        PSPlaceOpenBrace                   = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
        }

        PSPlaceCloseBrace                  = @{
            Enable             = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $false
            NoEmptyLineBefore  = $true
        }

        PSAlignAssignmentStatement         = @{
            Enable         = $true
            CheckHashtable = $true
        }

        PSUseConsistentIndentation         = @{
            Enable              = $true
            Kind                = 'space'
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            IndentationSize     = 4
        }

        PSUseConsistentWhitespace          = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $false
            CheckSeparator                          = $true
            CheckParameter                          = $false
            IgnoreAssignmentOperatorInsideHashTable = $true
        }

        PSUseCompatibleSyntax              = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0', '7.4')
        }

        PSUseCompatibleCommands            = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.316_5.1.17763.316_x64_4.0.30319.42000_framework',
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
            )
        }

        PSUseCompatibleTypes               = @{
            Enable         = $true
            TargetProfiles = @(
                'win-8_x64_10.0.17763.316_5.1.17763.316_x64_4.0.30319.42000_framework',
                'win-8_x64_10.0.14393.0_7.0.0_x64_3.1.2_core'
            )
        }
    }
}
