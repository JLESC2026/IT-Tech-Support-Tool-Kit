param([string]$Printer = '')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Print test page'
Write-Header $A

$ok = $false
$target = $null
try {
    $all = @(Get-CimInstance -ClassName Win32_Printer -ErrorAction Stop)
    if ($Printer) {
        $target = $all | Where-Object { $_.Name -eq $Printer } | Select-Object -First 1
    } else {
        $target = $all | Where-Object { $_.Default } | Select-Object -First 1
    }
    if (-not $target) {
        if ($Printer) { Write-Fail "Printer '$Printer' not found" }
        else { Write-Fail 'No default printer is set. Use "Print test page (choose printer)".' }
    } else {
        Write-Info "Sending test page to: $($target.Name)"
        if ($target.WorkOffline) { Write-Warn 'This printer is set to "Use Printer Offline" - the page may not print.' }
        $r = Invoke-CimMethod -InputObject $target -MethodName PrintTestPage -ErrorAction Stop
        if ($r.ReturnValue -eq 0) {
            Write-Ok 'Test page was sent to the printer queue - check the printer for the page'
            $ok = $true
        } else {
            Write-Warn "Windows method returned code $($r.ReturnValue) - trying the classic print dialog method..."
            & rundll32.exe printui.dll,PrintUIEntry /k /n"$($target.Name)"
            Write-Ok 'Test page requested (classic method) - check the printer for the page'
            $ok = $true
        }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail $(if ($target) { $target.Name } else { 'no printer' })
