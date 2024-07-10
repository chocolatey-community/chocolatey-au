# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 3-June-2024.

<#
.SYNOPSIS
    Download file from internet and calculate its checksum

#>
function Get-RemoteChecksum( [string] $Url, $Algorithm='sha256', $Headers ) {
    $fn = [System.IO.Path]::GetTempFileName()
    
	$originalShowProgress=$ProgressPreference
	if (-not $showProgress)
	{
		$ProgressPreference = 'SilentlyContinue'
	}
	Invoke-WebRequest $Url -OutFile $fn -UseBasicParsing -Headers $Headers
	if (-not $showProgress)
	{
		$ProgressPreference = $originalShowProgress
	}
    
	$res = Get-FileHash $fn -Algorithm $Algorithm | ForEach-Object Hash
    Remove-Item $fn -ea ignore
    return $res.ToLower()
}