$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Disk Cleanup'
Write-Header $A
$ok = $false
try {
    $drive = $env:SystemDrive.TrimEnd(':')
    $vol = Get-Volume -DriveLetter $drive -ErrorAction SilentlyContinue
    if ($vol) {
        $pct = [math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 1)
        Write-Info "Drive ${drive}: $(Format-Size $vol.SizeRemaining) free of $(Format-Size $vol.Size) ($pct % free)"
        if ($pct -lt 10) { Write-Warn 'Less than 10 % free - Windows and updates may misbehave.' }
    }
    Write-Info 'Opening the Windows Disk Cleanup tool...'
    Write-Info 'Tip: click "Clean up system files" in it to also remove old Windows Update files and previous Windows installations.'
    Start-Process -FilePath 'cleanmgr.exe' -ArgumentList "/d $drive"
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
    Write-Info 'Alternative: Settings > System > Storage > Temporary files.'
}
Complete-Action -Action $A -Success $ok
