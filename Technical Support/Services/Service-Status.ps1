. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Common services status'
Write-Header $A
$notRunning = 0
$rows = foreach ($c in (Get-CommonServiceList)) {
    $s = Get-Service -Name $c.Name -ErrorAction SilentlyContinue
    if ($s -and $s.Status -ne 'Running') { $notRunning++ }
    [pscustomobject]@{
        Group   = $c.Group
        Service = $c.Label
        Name    = $c.Name
        Status  = $(if ($s) { [string]$s.Status } else { 'Not installed' })
        Startup = $(if ($s) { [string]$s.StartType } else { '-' })
    }
}
Write-Table $rows
if ($notRunning -gt 0) {
    Write-Warn "$notRunning service(s) are not running. Some (like BITS or Bluetooth) are normally set to start on demand."
} else {
    Write-Ok 'All common services are running'
}
Complete-Action -Action $A -Success $true
