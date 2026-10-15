. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Restart selected service'
Write-Header $A
Assert-Admin $A

$items = Get-Service | Sort-Object DisplayName | ForEach-Object {
    [pscustomobject]@{
        DisplayName = $_.DisplayName
        Name        = $_.Name
        Status      = [string]$_.Status
        StartType   = [string]$_.StartType
    }
}
Write-Info 'A selection window has opened - choose one or more services.'
$sel = @(Show-Picker -Items $items -Title 'Select service(s) to restart' -Multiple)
if ($sel.Count -eq 0) {
    Write-Info 'Nothing selected - cancelled.'
    Exit-Toolkit -Code 0
}
$list = $sel | ForEach-Object { @{ Name = $_.Name; Label = $_.DisplayName } }
$ok = Invoke-ServiceGroup -Services $list
Complete-Action -Action $A -Success $ok -Detail (($sel | ForEach-Object { $_.Name }) -join ', ')
