. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart Windows Explorer'
Write-Header $A
$ok = $false
try {
    Write-Info 'Stopping Explorer...'
    Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
        Write-Info 'Starting Explorer...'
        Start-Process explorer.exe
        Start-Sleep -Seconds 2
    }
    $ok = [bool](Get-Process -Name explorer -ErrorAction SilentlyContinue)
    if ($ok) { Write-Ok 'Explorer is running' } else { Write-Fail 'Explorer did not start' }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok
