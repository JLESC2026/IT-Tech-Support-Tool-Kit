param([string]$Name = '', [string]$Server = '')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'nslookup'
Write-Header $A
if (-not $Name) {
    $in = Read-InputBox -Prompt 'Host name or IP to look up.  Optional: add a DNS server after a space, e.g.  www.microsoft.com 8.8.8.8' -Title 'nslookup' -Default 'www.microsoft.com'
    if (-not $in) { Write-Info 'Cancelled.'; Exit-Toolkit -Code 0 }
    $parts = @($in -split '\s+' | Where-Object { $_ })
    $Name = $parts[0]
    if ($parts.Count -gt 1) { $Server = $parts[1] }
}
if (-not (Test-ValidHostName $Name) -or ($Server -and -not (Test-ValidHostName $Server))) {
    Write-Fail 'That is not a valid host name / IP address.'
    Complete-Action -Action $A -Success $false -Detail $Name
}
$args2 = @($Name)
if ($Server) { $args2 += $Server }
Write-Info ("nslookup " + ($args2 -join ' '))
$code = Invoke-Native -FilePath 'nslookup.exe' -Arguments $args2
$txt = Get-LastNativeText
$ok = ($code -eq 0) -and ($txt -notmatch "can't find|Non-existent domain|timed out|No response")
Complete-Action -Action $A -Success $ok -Detail ("$Name $Server").Trim()
