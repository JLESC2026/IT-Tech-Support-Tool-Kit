. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Check scanner status'
Write-Header $A
$problems = 0

Write-Info 'Related services:'
foreach ($c in @(
        @{ Name = 'stisvc';          Label = 'Windows Image Acquisition (WIA)'; Needed = $true },
        @{ Name = 'ShellHWDetection'; Label = 'Shell Hardware Detection';        Needed = $false },
        @{ Name = 'WiaRpc';          Label = 'Still Image Service RPC (WIA)';   Needed = $false })) {
    $s = Get-Service -Name $c.Name -ErrorAction SilentlyContinue
    if (-not $s) { Write-Info "$($c.Label): not present on this version of Windows"; continue }
    if ($s.Status -eq 'Running') { Write-Ok "$($c.Label): Running ($($s.StartType))" }
    elseif ($c.Needed) { Write-Fail "$($c.Label): $($s.Status) ($($s.StartType))"; $problems++ }
    else { Write-Warn "$($c.Label): $($s.Status) ($($s.StartType))" }
}

Write-Host ''
Write-Info 'Device status:'
$devs = @(Get-CimInstance -ClassName Win32_PnPEntity -ErrorAction SilentlyContinue | Where-Object { $_.PNPClass -eq 'Image' })
if ($devs.Count -eq 0) {
    Write-Fail 'No imaging/scanner devices found'
    $problems++
}
foreach ($d in $devs) {
    $text = Get-DeviceProblemText $d.ConfigManagerErrorCode
    if ($d.ConfigManagerErrorCode -eq 0) { Write-Ok "$($d.Name): $text" }
    else { Write-Fail "$($d.Name): $text"; $problems++ }
}
if ($problems -gt 0) {
    Write-Info 'Tip: for code 28/39 reinstall the scanner driver; for code 22 enable the device in Device Manager; for code 45 check the cable.'
}
Complete-Action -Action $A -Success ($problems -eq 0) -Detail "$problems problem(s)"
