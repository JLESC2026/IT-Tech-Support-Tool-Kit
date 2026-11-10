. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Detect printers'
Write-Header $A

$sp = Get-Service -Name 'Spooler' -ErrorAction SilentlyContinue
if (-not $sp) {
    Write-Fail 'Print Spooler service not found on this PC'
} elseif ($sp.Status -ne 'Running') {
    Write-Warn "Print Spooler is $($sp.Status) - printers may not be listed. Use 'Restart Print Spooler'."
} else {
    Write-Ok 'Print Spooler is running'
}

$printers = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction SilentlyContinue)
if ($printers.Count -eq 0) {
    Write-Fail 'No printers are installed on this computer'
} else {
    Write-Info "$($printers.Count) printer(s) installed:"
    $rows = $printers | Sort-Object Name | ForEach-Object {
        [pscustomobject]@{
            Default = $(if ($_.Default) { 'YES' } else { '' })
            Name    = $_.Name
            Driver  = $_.DriverName
            Port    = $_.PortName
            Status  = Get-PrinterStatusText $_.PrinterStatus
            Offline = $(if ($_.WorkOffline) { 'YES' } else { 'no' })
            Shared  = $(if ($_.Shared) { 'YES' } else { 'no' })
        }
    }
    Write-Table $rows
}

Write-Host ''
Write-Info 'Printer devices Windows can see (plug and play):'
$pnp = @()
foreach ($class in 'Printer', 'PrintQueue') {
    $pnp += @(Get-PnpDevice -Class $class -ErrorAction SilentlyContinue)
}
if ($pnp.Count -eq 0) {
    Write-Host '    (none)'
} else {
    Write-Table ($pnp | Sort-Object FriendlyName | ForEach-Object {
        [pscustomobject]@{ Device = $_.FriendlyName; Class = $_.Class; Status = $_.Status; Present = $_.Present }
    })
}
Complete-Action -Action $A -Success ($printers.Count -gt 0) -Detail "$($printers.Count) printer(s)"
