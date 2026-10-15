$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Audio devices'
Write-Header $A
$issues = 0
try {
    Write-Header '1. Audio services'
    foreach ($n in 'Audiosrv', 'AudioEndpointBuilder') {
        $s = Get-Service -Name $n -ErrorAction SilentlyContinue
        if (-not $s) { Write-Fail "$n is not installed"; $issues++ }
        elseif ($s.Status -eq 'Running') { Write-Ok "$($s.DisplayName): Running" }
        else { Write-Fail "$($s.DisplayName): $($s.Status) ($($s.StartType)) - use 'Restart Windows Audio'"; $issues++ }
    }
    Write-Host ''

    Write-Header '2. Sound hardware'
    $snd = @(Get-CimInstance Win32_SoundDevice -ErrorAction SilentlyContinue)
    if ($snd.Count -eq 0) { Write-Fail 'No sound device found (driver missing or device disabled in BIOS)'; $issues++ }
    foreach ($d in $snd) {
        if ([int]$d.ConfigManagerErrorCode -eq 0) { Write-Ok "$($d.Name)  [$($d.Manufacturer)]" }
        else { Write-Fail "$($d.Name): $(Get-DeviceProblemText $d.ConfigManagerErrorCode)"; $issues++ }
    }
    if ($snd | Where-Object { $_.Name -match 'Generic|High Definition Audio Device' }) {
        Write-Info '  A generic "High Definition Audio Device" driver is in use - the manufacturer (Realtek etc.) driver may give better results.'
    }
    Write-Host ''

    Write-Header '3. Playback / recording endpoints'
    $ep = @(Get-PnpDevice -Class AudioEndpoint -ErrorAction SilentlyContinue)
    $active = @($ep | Where-Object { $_.Status -eq 'OK' })
    $inactive = @($ep | Where-Object { $_.Status -ne 'OK' })
    if ($active.Count -eq 0) { Write-Warn 'No active playback or recording device (all unplugged or disabled)'; $issues++ }
    foreach ($e in ($active | Sort-Object FriendlyName)) { Write-Ok $e.FriendlyName }
    foreach ($e in ($inactive | Sort-Object FriendlyName)) { Write-Info "$($e.FriendlyName)  [$($e.Status) - unplugged or disabled]" }
    Write-Host ''
    Write-Info 'Muted or wrong default device? Open "Sound settings" from this menu to check the output device and volume.'
} catch {
    Write-Fail $_.Exception.Message
    $issues++
}
Write-Host ''
if ($issues -eq 0) { Write-Ok 'Audio looks healthy' } else { Write-Warn "$issues issue(s) found" }
Complete-Action -Action $A -Success ($issues -eq 0) -Detail "$issues issue(s)"
