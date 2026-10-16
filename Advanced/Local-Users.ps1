# Local users and groups. Default = read-only list. -Open also starts the Local Users and Groups console.
param([switch]$Open)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = $(if ($Open) { 'Local Users and Groups (open console)' } else { 'Local users (read-only list)' })
Write-Header $A
$ok = $false
try {
    Write-Header 'Local user accounts'
    $users = @(Get-LocalUser -ErrorAction Stop | Sort-Object Name)
    Write-Table ($users | Select-Object Name, Enabled, PasswordRequired, @{ n = 'Last logon'; e = { Format-Date $_.LastLogon 'yyyy-MM-dd HH:mm' } }, @{ n = 'Password set'; e = { Format-Date $_.PasswordLastSet } }, Description)
    $risky = @($users | Where-Object { $_.Enabled -and -not $_.PasswordRequired -and $_.Name -ne 'DefaultAccount' })
    foreach ($r in $risky) { Write-Warn "$($r.Name) is enabled and does not require a password" }
    Write-Host ''

    Write-Header 'Administrators group'
    $admins = @(Get-LocalGroupMember -Group 'Administrators' -ErrorAction Stop)
    Write-Table ($admins | Select-Object Name, ObjectClass, PrincipalSource)
    $ok = $true

    if ($Open) {
        Write-Host ''
        $msc = Join-Path $env:windir 'System32\lusrmgr.msc'
        if (Test-Path $msc) {
            Start-Process -FilePath 'mmc.exe' -ArgumentList "`"$msc`""
            Write-Info 'Local Users and Groups opened. Changes there take effect immediately.'
        } else {
            Write-Warn 'lusrmgr.msc is not available on this Windows edition (Home). Use "net user" or Settings > Accounts.'
        }
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok
