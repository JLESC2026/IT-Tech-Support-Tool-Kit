. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Service configuration (read-only)'
Write-Header $A

$items = Get-Service | Sort-Object DisplayName | ForEach-Object {
    [pscustomobject]@{ DisplayName = $_.DisplayName; Name = $_.Name; Status = [string]$_.Status; StartType = [string]$_.StartType }
}
Write-Info 'A selection window has opened - choose a service.'
$sel = @(Show-Picker -Items $items -Title 'Select a service')
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }

$name = $sel[0].Name
$svc = Get-CimInstance -ClassName Win32_Service -Filter "Name='$name'" -ErrorAction SilentlyContinue
if (-not $svc) {
    Write-Fail "Could not read the configuration of '$name'"
    Complete-Action -Action $A -Success $false -Detail $name
}
Write-Table ([pscustomobject]@{
    Name           = $svc.Name
    DisplayName    = $svc.DisplayName
    State          = $svc.State
    StartMode      = $svc.StartMode
    DelayedStart   = $svc.DelayedAutoStart
    LogOnAccount   = $svc.StartName
    ProcessId      = $svc.ProcessId
    ServiceType    = $svc.ServiceType
})
Write-Host ''
Write-Host "Executable : $($svc.PathName)"
if ($svc.Description) { Write-Host "Description: $($svc.Description)" }
Write-Host ''
Write-Info 'Recovery actions (what Windows does when the service fails):'
(& sc.exe qfailure $name 2>&1 | Out-String).TrimEnd() | Write-Host
Complete-Action -Action $A -Success $true -Detail $name
