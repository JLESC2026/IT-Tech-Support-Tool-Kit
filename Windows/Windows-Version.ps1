$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'Windows version and build information'
Write-Header $A
$ok = $false
try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
    $build = [int]$os.BuildNumber
    $name = [string]$os.Caption
    if ($build -ge 22000) { $name = $name -replace 'Windows 10', 'Windows 11' }
    $ver = ''
    if ($cv.DisplayVersion) { $ver = [string]$cv.DisplayVersion } elseif ($cv.ReleaseId) { $ver = [string]$cv.ReleaseId }
    $ubr = ''
    if ($null -ne $cv.UBR) { $ubr = ".$($cv.UBR)" }

    Write-KV 'Computer name' $env:COMPUTERNAME
    Write-KV 'Windows' $name
    Write-KV 'Edition ID' $cv.EditionID
    Write-KV 'Version' $ver
    Write-KV 'Build' "$build$ubr"
    Write-KV 'Architecture' $os.OSArchitecture
    Write-KV 'Install date' (Format-Date $os.InstallDate)
    Write-KV 'Last boot' (Format-Date $os.LastBootUpTime 'yyyy-MM-dd HH:mm')
    $up = (Get-Date) - $os.LastBootUpTime
    Write-KV 'Uptime' ("{0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
    Write-KV 'System drive' $os.SystemDirectory
    Write-KV 'Registered owner' $os.RegisteredUser
    Write-Host ''

    $drive = $env:SystemDrive.TrimEnd(':')
    $vol = Get-Volume -DriveLetter $drive -ErrorAction SilentlyContinue
    if ($vol) {
        $pct = [math]::Round(($vol.SizeRemaining / $vol.Size) * 100, 1)
        $line = "Drive ${drive}: $(Format-Size $vol.SizeRemaining) free of $(Format-Size $vol.Size) ($pct %)"
        if ($pct -lt 10) { Write-Warn $line } else { Write-Ok $line }
    }

    $pending = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $pending += 'component servicing' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $pending += 'Windows Update' }
    $pfr = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations
    if ($pfr) { $pending += 'pending file operations' }
    if ($pending.Count -gt 0) { Write-Warn "A restart is pending ($($pending -join ', ')). Restart before running repairs." }
    else { Write-Ok 'No restart pending' }

    if ($up.TotalDays -gt 14) { Write-Warn "This PC has not been restarted for $([int]$up.TotalDays) days." }
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok
