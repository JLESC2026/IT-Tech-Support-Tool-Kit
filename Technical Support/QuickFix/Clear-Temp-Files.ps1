. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = 'Clear temporary files'
Write-Header $A

function Get-FolderBytes {
    param([string]$Path)
    $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($null -eq $sum) { return [long]0 }
    return [long]$sum
}

$targets = @($env:TEMP)
if (Test-IsAdmin) {
    $targets += (Join-Path $env:SystemRoot 'Temp')
} else {
    Write-Warn 'Not running as administrator - C:\Windows\Temp will be skipped.'
}

$freed = [long]0
$ok = $true
foreach ($t in ($targets | Select-Object -Unique)) {
    if (-not (Test-Path -LiteralPath $t)) { Write-Warn "$t not found - skipped"; continue }
    try {
        $before = Get-FolderBytes $t
        Write-Info "Cleaning $t ($([math]::Round($before / 1MB, 1)) MB)..."
        Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $after = Get-FolderBytes $t
        $gain = [math]::Max(0, $before - $after)
        $freed += $gain
        Write-Ok "$t : freed $([math]::Round($gain / 1MB, 1)) MB, $([math]::Round($after / 1MB, 1)) MB left (files in use are skipped)"
    } catch {
        Write-Fail "$t : $($_.Exception.Message)"
        $ok = $false
    }
}
Write-Info "Total freed: $([math]::Round($freed / 1MB, 1)) MB"
Complete-Action -Action $A -Success $ok -Detail "Freed $([math]::Round($freed / 1MB, 1)) MB"
