$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Flush DNS cache'
Write-Header $A
$ok = $false
try {
    Write-Info 'Clearing the DNS resolver cache...'
    $code = Invoke-Native -FilePath 'ipconfig.exe' -Arguments @('/flushdns')
    $ok = ($code -eq 0)
    if (-not $ok -and -not (Test-IsAdmin)) {
        Write-Warn 'Windows refused - flushing the cache may need administrator rights.'
        Write-Log -Action $A -Result 'NEEDS ADMIN'
        Exit-Toolkit -Code 2
    }
    if ($ok) { Write-Ok 'DNS resolver cache cleared' } else { Write-Fail "ipconfig returned code $code" }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok
