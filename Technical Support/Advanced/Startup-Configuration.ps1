. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Change service startup type'
Write-Header $A
Assert-Admin $A

$items = Get-Service | Sort-Object DisplayName | ForEach-Object {
    [pscustomobject]@{ DisplayName = $_.DisplayName; Name = $_.Name; Status = [string]$_.Status; StartType = [string]$_.StartType }
}
Write-Info 'A selection window has opened - choose the service to change.'
$sel = @(Show-Picker -Items $items -Title 'Select a service to change')
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }
$svc = $sel[0]

$types = @(
    [pscustomobject]@{ StartupType = 'Automatic';                 Meaning = 'Starts with Windows' }
    [pscustomobject]@{ StartupType = 'Automatic (Delayed Start)'; Meaning = 'Starts shortly after Windows has loaded' }
    [pscustomobject]@{ StartupType = 'Manual';                    Meaning = 'Starts only when something needs it' }
    [pscustomobject]@{ StartupType = 'Disabled';                  Meaning = 'Cannot be started - can break features' }
)
$pick = @(Show-Picker -Items $types -Title "New startup type for $($svc.DisplayName) (now: $($svc.StartType))")
if ($pick.Count -eq 0) { Write-Info 'No startup type chosen - cancelled.'; Exit-Toolkit -Code 0 }
$new = $pick[0].StartupType

$msg = "Change '$($svc.DisplayName)' from $($svc.StartType) to $new?`n`nChanging system services can stop Windows features from working."
if ($new -eq 'Disabled') { $msg += "`n`nDISABLING a service is the riskiest option." }
if (-not (Confirm-Action -Message $msg -Title 'Confirm service change')) {
    Write-Info 'Cancelled - nothing was changed.'
    Exit-Toolkit -Code 0
}

$ok = $false
try {
    switch ($new) {
        'Automatic'                 { Set-Service -Name $svc.Name -StartupType Automatic -ErrorAction Stop }
        'Manual'                    { Set-Service -Name $svc.Name -StartupType Manual -ErrorAction Stop }
        'Disabled'                  { Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop }
        'Automatic (Delayed Start)' {
            $r = & sc.exe config $svc.Name start= delayed-auto 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) { throw $r.Trim() }
        }
    }
    $now = Get-Service -Name $svc.Name
    Write-Ok "$($svc.DisplayName): startup type is now $($now.StartType) (was $($svc.StartType))"
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail "$($svc.Name): $($svc.StartType) -> $new"
