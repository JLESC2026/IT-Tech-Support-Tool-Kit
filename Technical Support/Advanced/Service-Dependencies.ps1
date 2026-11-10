. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Service dependencies'
Write-Header $A

$items = Get-Service | Sort-Object DisplayName | ForEach-Object {
    [pscustomobject]@{ DisplayName = $_.DisplayName; Name = $_.Name; Status = [string]$_.Status }
}
Write-Info 'A selection window has opened - choose a service.'
$sel = @(Show-Picker -Items $items -Title 'Select a service')
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }

function Show-DependencyTree {
    param($Service, [string]$Direction, [int]$Level, $Seen)
    if ($Level -gt 6) { return }
    if ($Direction -eq 'Needs') { $children = $Service.ServicesDependedOn } else { $children = $Service.DependentServices }
    foreach ($c in $children) {
        $pad = ('    ' * $Level) + '- '
        Write-Host ("{0}{1} ({2}) [{3}]" -f $pad, $c.DisplayName, $c.Name, $c.Status)
        if (-not $Seen.Contains($c.Name)) {
            [void]$Seen.Add($c.Name)
            Show-DependencyTree -Service $c -Direction $Direction -Level ($Level + 1) -Seen $Seen
        }
    }
}

$svc = Get-Service -Name $sel[0].Name
Write-Host ''
Write-Host "Service: $($svc.DisplayName) ($($svc.Name)) [$($svc.Status)]" -ForegroundColor Cyan
Write-Host ''
Write-Host 'NEEDS (this service cannot run unless these are running):'
if (@($svc.ServicesDependedOn).Count -eq 0) { Write-Host '    (nothing)' }
else { Show-DependencyTree -Service $svc -Direction 'Needs' -Level 1 -Seen (New-Object System.Collections.Generic.HashSet[string]) }
Write-Host ''
Write-Host 'NEEDED BY (these stop if you stop this service):'
if (@($svc.DependentServices).Count -eq 0) { Write-Host '    (nothing)' }
else { Show-DependencyTree -Service $svc -Direction 'NeededBy' -Level 1 -Seen (New-Object System.Collections.Generic.HashSet[string]) }
Write-Host ''
Complete-Action -Action $A -Success $true -Detail $svc.Name
