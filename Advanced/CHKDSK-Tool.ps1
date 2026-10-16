# CHKDSK - check a drive for file system errors.
#   ReadOnly : chkdsk X:        (reports problems, changes nothing)
#   Fix      : chkdsk X: /f     (fixes file system errors - may lock the drive or schedule a check at next restart)
#   Surface  : chkdsk X: /r     (fixes errors AND scans the whole surface for bad sectors - can take hours)
param([ValidateSet('ReadOnly', 'Fix', 'Surface')][string]$Mode = 'ReadOnly', [string]$Drive = '')
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = "CHKDSK ($Mode)"
Write-Header $A
Assert-Admin $A
$ok = $false
try {
    if (-not $Drive) {
        $vols = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.FileSystem } | Sort-Object DriveLetter | ForEach-Object {
            [pscustomobject]@{ Drive = "$($_.DriveLetter):"; Label = [string]$_.FileSystemLabel; FileSystem = [string]$_.FileSystem; Size = (Format-Size $_.Size); Free = (Format-Size $_.SizeRemaining) }
        })
        if ($vols.Count -eq 0) { Write-Fail 'No fixed drives found.'; Complete-Action -Action $A -Success $false }
        Write-Info 'A selection window has opened - choose the drive to check.'
        $sel = @(Show-Picker -Items $vols -Title 'CHKDSK - which drive?')
        if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }
        $Drive = $sel[0].Drive
    }
    if ($Drive -notmatch '^[A-Za-z]:?$') { Write-Fail "Invalid drive '$Drive'."; Complete-Action -Action $A -Success $false }
    $Drive = $Drive.Substring(0, 1).ToUpper() + ':'

    $ckArgs = @($Drive)
    if ($Mode -eq 'Fix') { $ckArgs += '/f' }
    if ($Mode -eq 'Surface') { $ckArgs += '/r' }

    if ($Mode -ne 'ReadOnly') {
        $isSystem = ($Drive -eq $env:SystemDrive)
        $msg = "Run CHKDSK $($ckArgs -join ' ') on drive $Drive ?`n`n"
        if ($isSystem) { $msg += "This is the Windows drive. The check will be scheduled for the next restart.`n" }
        else { $msg += "The drive will be locked while it is checked; open files may be closed.`n" }
        if ($Mode -eq 'Surface') { $msg += "A surface scan (/r) can take several hours.`n" }
        $msg += "`nMake sure important data is backed up. Continue?"
        if (-not (Confirm-Action -Message $msg -Title 'CHKDSK')) {
            Write-Info 'Cancelled - nothing was changed.'
            Write-Log -Action $A -Result 'CANCELLED' -Detail $Drive
            Exit-Toolkit -Code 0
        }
    }

    Write-Info "Running: chkdsk $($ckArgs -join ' ')"
    $lines = New-Object System.Collections.Generic.List[string]
    # 'Y' answers the "schedule at next restart?" question that chkdsk asks for a drive in use.
    'Y' | & chkdsk.exe @ckArgs 2>&1 | ForEach-Object {
        $t = ([string]$_).Replace([string][char]0, '').TrimEnd()
        if ($t.Length -gt 0) { [void]$lines.Add($t); Write-Host $t }
    }
    $code = $LASTEXITCODE
    $text = $lines.ToArray() -join "`n"
    Write-Host ''
    if ($text -match 'scheduled|next time the system restarts|next restart') {
        Write-Warn 'The check is scheduled and will run when the computer restarts.'
        $ok = $true
    } elseif ($code -eq 0) {
        Write-Ok 'No problems found'
        $ok = $true
    } elseif ($code -eq 1 -and $Mode -ne 'ReadOnly') {
        Write-Ok 'Errors were found and fixed'
        $ok = $true
    } elseif ($code -eq 1) {
        Write-Warn 'Errors were found. Run "CHKDSK repair" to fix them.'
    } elseif ($code -eq 2) {
        Write-Warn 'The drive needs cleanup (not run in read-only mode). Run "CHKDSK repair" if problems continue.'
    } else {
        Write-Fail "CHKDSK could not check or fix the drive (exit code $code)."
    }
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail $Drive
