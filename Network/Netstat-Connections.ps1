$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = 'netstat (connections with process names)'
Write-Header $A
$ok = $false
try {
    $procs = @{}
    foreach ($p in @(Get-Process -ErrorAction SilentlyContinue)) { $procs[[int]$p.Id] = $p.ProcessName }
    $conns = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { $_.State -in 'Listen', 'Established', 'TimeWait', 'CloseWait', 'SynSent' })
    $rows = $conns | ForEach-Object {
        $pn = ''
        if ($procs.ContainsKey([int]$_.OwningProcess)) { $pn = $procs[[int]$_.OwningProcess] }
        [pscustomobject]@{
            State   = [string]$_.State
            Local   = "$($_.LocalAddress):$($_.LocalPort)"
            Remote  = $(if ($_.State -eq 'Listen') { '-' } else { "$($_.RemoteAddress):$($_.RemotePort)" })
            PID     = $_.OwningProcess
            Process = $pn
        }
    }
    Write-Header 'Established connections'
    Write-Table ($rows | Where-Object { $_.State -eq 'Established' } | Sort-Object Process, Remote)
    Write-Host ''
    Write-Header 'Listening ports'
    Write-Table ($rows | Where-Object { $_.State -eq 'Listen' } | Sort-Object { [int]($_.Local -replace '^.*:', '') })
    Write-Host ''
    Write-Header 'Counts by state'
    Write-Table ($rows | Group-Object State | Select-Object Name, Count)
    Write-Host ''
    Write-Header 'UDP endpoints (count only)'
    $udp = @(Get-NetUDPEndpoint -ErrorAction SilentlyContinue)
    Write-Info "$($udp.Count) UDP endpoint(s)"
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
    Write-Info 'Falling back to plain netstat -ano ...'
    $ok = ((Invoke-Native -FilePath 'netstat.exe' -Arguments @('-ano')) -eq 0)
}
Complete-Action -Action $A -Success $ok
