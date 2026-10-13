<#
.SYNOPSIS
  Publishes the package update status to Discord.

.LINK
  https://discord.com/developers/docs/resources/webhook#execute-webhook
#>
[CmdletBinding(DefaultParameterSetName="Url")]
param(
  [Parameter(Mandatory)]
  $Info,

  # This is the Discord Webhook ID
  [Parameter(Mandatory, ParameterSetName="Id")]
  [string]$WebhookId,

  # This is the Discord webhook token.
  [Parameter(Mandatory, ParameterSetName="Id")]
  [string]$WebhookToken,

  # This is the full custom webhook url created in Discord.
  [Parameter(Mandatory, ParameterSetName="Url")]
  [string]$WebHookUrl = "https://discord.com/api/webhooks/$($WebhookId)/$($WebhookToken)",

  # If set, just sends a simple text message.
  [switch]$Simple
)

if ($WebHookUrl -eq "https://discord.com/api/webhooks//") { return } # If we don't have a valid webhookurl we can't push status messages, so ignore.

$updatedPackages   = @($Info.result.updated).Count
$publishedPackages = @($Info.result.pushed).Count
$failedPackages    = $Info.error_count.total
$gistUrl           = $Info.plugin_results.Gist -split '\n' | Select-Object -Last 1
$packageCount      = $Info.result.all.Length

$Body = if ($Simple) {
  @{
    content = 
      "[Update Status: $($packageCount) packages.`n" +
      "$($updatedPackages) updated, $($publishedPackages) Published, $($failedPackages) Failed]($($gistUrl))"
  }
} else {
  @{
    embeds = @(
      @{
        title = "Packages Updated"
        description = "$($packageCount) packages were updated$(if ($failedPackages -gt 0) {", with **$($failedPackages) failure**"})."
        timestamp = Get-Date $Info.startTime -Format "yyyy-MM-ddThh:mm:ss.000zzz"
        url = $gistUrl
        color = if ($failedPackages -gt 0) {"15548997"} else {"0"}
        fields = @(
          @{name = "Total"; value = "$($packageCount)"; inline = $false}
          @{name = "Updated"; value = "$($updatedPackages)"; inline = $true}
          @{name = "Published"; value = "$($publishedPackages)"; inline = $true}
          @{name = "Failed"; value = "$($failedPackages)"; inline = $true}
        )
        footer = @{
          text = "Run took $($Info.minutes) minutes."
        }
      }
    )
  }
}

$arguments = @{
  Body             = $Body | ConvertTo-Json -Depth 5
  UseBasicParsing  = $true
  Uri              = $WebHookUrl
  ContentType      = 'application/json'
  Method           = 'POST'
}

Write-Host "Submitting message to Discord"
Invoke-RestMethod @arguments
Write-Host "Message submitted to Discord"