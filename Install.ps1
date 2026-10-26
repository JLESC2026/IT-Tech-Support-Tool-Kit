# IT Technician Toolkit - web installer / launcher
# Usage (Windows PowerShell 5.1 or 7):
#   irm https://raw.githubusercontent.com/JLESC2026/IT-Tech-Support-Tool-Kit/main/Install.ps1 | iex
#
# What it does: downloads the toolkit from GitHub, installs it to
#   %LOCALAPPDATA%\ITTechToolkit   (Logs and Reports are kept on update)
# and starts the dashboard. Re-running it updates the toolkit.
# ASCII only, Windows PowerShell 5.1 compatible.

# ---------- Settings: change OWNER / REPO / BRANCH ----------
$Owner  = 'JLESC2026'
$Repo   = 'IT-Tech-Support-Tool-Kit'
$Branch = 'main'
$InstallDir = Join-Path $env:LOCALAPPDATA 'ITTechToolkit'
# Set $env:ITTK_NOADMIN = '1' before running to skip the automatic admin relaunch.
# ------------------------------------------------------------

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'

$installerUrl = "https://raw.githubusercontent.com/$Owner/$Repo/$Branch/Install.ps1"
$zipUrl       = "https://github.com/$Owner/$Repo/archive/refs/heads/$Branch.zip"

function Write-Step { param([string]$m) Write-Host "[ITTK] $m" -ForegroundColor Cyan }

if ($Owner -eq 'OWNER' -or $Repo -eq 'REPO') {
    Write-Host '[ITTK] Edit Install.ps1 first: set $Owner and $Repo to your GitHub account and repository.' -ForegroundColor Yellow
    return
}

if ($env:OS -ne 'Windows_NT') {
    Write-Host '[ITTK] This toolkit runs on Windows only.' -ForegroundColor Red
    return
}

# ---------- Elevate (piped scripts have no file, so re-run the one-liner) ----------
$id = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and $env:ITTK_NOADMIN -ne '1') {
    Write-Step 'Administrator rights are needed for most repair tools - requesting elevation...'
    try {
        $cmd = "irm '$installerUrl' | iex"
        Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        return
    } catch {
        Write-Host '[ITTK] Elevation was cancelled - continuing without administrator rights.' -ForegroundColor Yellow
    }
}

$tmp = Join-Path $env:TEMP ("ittk_" + [guid]::NewGuid().ToString('N'))
try {
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $zip = Join-Path $tmp 'toolkit.zip'

    Write-Step "Downloading $Owner/$Repo ($Branch)..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing

    Write-Step 'Extracting...'
    $extract = Join-Path $tmp 'x'
    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $src = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
    if (-not $src -or -not (Test-Path (Join-Path $src.FullName 'Launcher\Toolkit.ps1'))) {
        throw 'The download does not look like the toolkit (Launcher\Toolkit.ps1 not found).'
    }

    Write-Step "Installing to $InstallDir ..."
    if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null }
    # Copy over the existing install without deleting Logs / Reports / PortableApps content
    & robocopy.exe $src.FullName $InstallDir /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed (code $LASTEXITCODE)" }

    Get-ChildItem -LiteralPath $InstallDir -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

    # Desktop shortcut (created once)
    try {
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'IT Technician Toolkit.lnk'
        if (-not (Test-Path $lnk)) {
            $ws = New-Object -ComObject WScript.Shell
            $s = $ws.CreateShortcut($lnk)
            $s.TargetPath = Join-Path $InstallDir 'START.bat'
            $s.WorkingDirectory = $InstallDir
            $s.Save()
            Write-Step 'Desktop shortcut created.'
        }
    } catch { }

    Write-Step 'Starting the toolkit...'
    $ps = Join-Path $PSHOME 'powershell.exe'
    Start-Process -FilePath $ps -WorkingDirectory $InstallDir `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$(Join-Path $InstallDir 'Launcher\Toolkit.ps1')`""
    Write-Step 'Done. You can close this window.'
} catch {
    Write-Host "[ITTK] Install failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}