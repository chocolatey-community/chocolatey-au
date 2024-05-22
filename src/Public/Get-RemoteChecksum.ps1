# Author: Miodrag Milic <miodrag.milic@gmail.com>
# Last Change: 22-May-2024.

<#
.SYNOPSIS
    Download file from internet and calculate its checksum

#>
function Get-RemoteChecksum( [string] $Url, $Algorithm='sha256', $Headers ) {
    $fn = [System.IO.Path]::GetTempFileName()
    $wc = New-Object net.webclient
    $wc.DownloadFile($Url, $fn)
    $res = Get-FileHash $fn -Algorithm $Algorithm | ForEach-Object Hash
    Remove-Item $fn -ea ignore
    return $res.ToLower()
}

