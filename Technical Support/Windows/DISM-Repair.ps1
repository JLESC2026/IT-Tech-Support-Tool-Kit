param([ValidateSet('CheckHealth', 'ScanHealth', 'RestoreHealth')][string]$Mode = 'CheckHealth')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = "DISM $Mode"
Write-Header $A
Assert-Admin $A
switch ($Mode) {
    'CheckHealth'   { Write-Info 'Quick check of the Windows image for flagged corruption (about a minute, no changes made).' }
    'ScanHealth'    { Write-Warn 'Full scan of the Windows image. Can take 5-15 minutes. No changes are made.' }
    'RestoreHealth' { Write-Warn 'Repairs the Windows image using Windows Update as the source (internet needed). Can take 10-30 minutes and may sit at 62% or 100% for a while - that is normal.' }
}
$ok = $false
try {
    $code = Invoke-Native -FilePath 'dism.exe' -Arguments @('/Online', '/Cleanup-Image', "/$Mode")
    $t = Get-LastNativeText
    if ($t -match 'No component store corruption detected') {
        $ok = $true
        Write-Ok 'No component store corruption detected'
    } elseif ($t -match 'component store is repairable') {
        Write-Warn 'The component store is damaged but repairable.'
        Write-Info 'Run "DISM RestoreHealth" next.'
    } elseif ($code -eq 0) {
        $ok = $true
        if ($Mode -eq 'RestoreHealth') { Write-Warn 'Repair finished. Run "SFC scan and repair" next, then restart.' }
    } else {
        Write-Fail "dism.exe returned code $code"
        if ($t -match '0x800f081f|0x800f0906|source files could not be found') {
            Write-Info 'DISM could not download the repair files. Check the internet connection (or point DISM at a matching install.wim with /Source).'
        }
    }
    Write-Info "Details are in: $env:windir\Logs\DISM\dism.log"
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok
