# IT Technician Toolkit - web installer (keeps a copy on this PC; use the 'toolkit' short link for zero-trace runs)
# Run:  irm https://raw.githubusercontent.com/JLESC2026/IT-Tech-Support-Tool-Kit/main/Install.ps1 | iex
$Owner = 'JLESC2026'; $Repo = 'IT-Tech-Support-Tool-Kit'; $Branch = 'main'
$InstallDir = Join-Path $env:USERPROFILE 'Desktop\IT-Toolkit'

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
$ProgressPreference = 'SilentlyContinue'
$tmp = Join-Path $env:TEMP ('ittk_' + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zip = Join-Path $tmp 'toolkit.zip'
    Write-Host '[ITTK] Downloading...' -ForegroundColor Cyan
    Invoke-WebRequest -Uri "https://github.com/$Owner/$Repo/archive/refs/heads/$Branch.zip" -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $tmp 'x') -Force
    $src = Get-ChildItem -LiteralPath (Join-Path $tmp 'x') -Directory | Select-Object -First 1
    # Find the toolkit folder wherever it sits (repo root or a subfolder such as 'Technical Support').
    $launcher = Get-ChildItem -LiteralPath $src.FullName -Recurse -File -Filter 'Toolkit.ps1' |
        Where-Object { (Split-Path $_.DirectoryName -Leaf) -eq 'Launcher' } | Select-Object -First 1
    if (-not $launcher) { throw 'Launcher\Toolkit.ps1 not found in the download.' }
    $root = Split-Path $launcher.DirectoryName -Parent
    if (Test-Path -LiteralPath $InstallDir) { Remove-Item -LiteralPath $InstallDir -Recurse -Force }
    Copy-Item -LiteralPath $root -Destination $InstallDir -Recurse -Force
    Get-ChildItem -LiteralPath $InstallDir -Recurse -File | Unblock-File -ErrorAction SilentlyContinue
    Write-Host "[ITTK] Installed to $InstallDir" -ForegroundColor Green
    $ps = (Get-Process -Id $PID).Path
    Start-Process -FilePath $ps -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -File `"$InstallDir\Launcher\Toolkit.ps1`"" -WorkingDirectory "$InstallDir\Launcher"
} catch {
    Write-Host "[ITTK] Error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Press Enter to close' | Out-Null
} finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
