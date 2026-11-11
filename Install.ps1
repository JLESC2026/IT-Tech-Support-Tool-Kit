# IT Technician Toolkit - USB / folder installer
# Builds or updates a COPY of the toolkit on a flash drive (or any folder) so it can be started from there with
# START.bat. The copy has PortableApps\ folders where you put your own portable tools. Updating keeps your
# PortableApps\, Logs\, Reports\ and Config\settings.json.
#
# This is NOT how you run the toolkit on a customer PC without leaving a copy behind: for that use the 'toolkit'
# short link, which downloads no portable apps and deletes its temporary folder afterwards. See the README.
#
# Integrity: the release is downloaded and its SHA-256 hash is checked against
# https://jlesc2026.github.io/manifest.json before anything is copied. If the check fails nothing is copied.
# No administrator rights are needed. Windows PowerShell 5.1 and 7.
#
# Recommended command:
#   [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $r=(iwr -UseBasicParsing https://jlesc2026.github.io/install).Content; if($r -is [byte[]]){$r=[Text.Encoding]::UTF8.GetString($r)}; iex $r.TrimStart([char]0xFEFF)
# To skip the prompts set the target first, for example:  $env:ITTK_TARGET = 'E:\'

$PayloadOwner = 'JLESC2026'
$PayloadRepo  = 'IT-Tech-Support-Tool-Kit'
$FolderName   = 'IT-Toolkit'

$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
$ProgressPreference = 'SilentlyContinue'

$manifestUrl   = 'https://jlesc2026.github.io/manifest.json'
# Only release files from this repository are accepted, whatever the manifest says.
$releasePrefix = "https://github.com/$PayloadOwner/$PayloadRepo/releases/download/"

function Write-Step { param([string]$m) Write-Host "[ITTK] $m" -ForegroundColor Cyan }

function Get-WebText {
    param([string]$Url)
    $r = (Invoke-WebRequest -UseBasicParsing -Uri $Url).Content
    if ($r -is [byte[]]) { $r = [Text.Encoding]::UTF8.GetString($r) }
    return ([string]$r).TrimStart([char]0xFEFF)
}

if ($env:OS -ne 'Windows_NT') {
    Write-Host '[ITTK] This toolkit runs on Windows only.' -ForegroundColor Red
    return
}

$tmp = $null
try {
    # ---------- Where to install ----------
    $dest = $env:ITTK_TARGET
    if (-not $dest) {
        $drives = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=2' -ErrorAction SilentlyContinue)
        if ($drives.Count -gt 0) {
            Write-Host ''
            Write-Host 'Removable drives found:'
            $i = 0
            foreach ($d in $drives) {
                $i++
                $free = ''
                if ($d.FreeSpace) { $free = ('{0:N1} GB free' -f ($d.FreeSpace / 1GB)) }
                Write-Host ('  [{0}] {1}  {2}  {3}' -f $i, $d.DeviceID, $d.VolumeName, $free)
            }
            Write-Host '  [F] Type a folder path instead'
            $ans = (Read-Host 'Choose a drive number, or F').Trim()
            $n = 0
            if ([int]::TryParse($ans, [ref]$n) -and $n -ge 1 -and $n -le $drives.Count) { $dest = $drives[$n - 1].DeviceID + '\' }
        }
        if (-not $dest) { $dest = Read-Host 'Drive or folder to install into (for example E:\ or D:\Tools)' }
    }
    $dest = ([string]$dest).Trim().Trim('"')
    if (-not $dest) { throw 'No target was given. Nothing was changed.' }
    if (-not (Test-Path -LiteralPath $dest -PathType Container)) { throw "The target '$dest' does not exist. Nothing was changed." }

    $installDir = Join-Path $dest $FolderName
    $updating = Test-Path -LiteralPath (Join-Path $installDir 'Launcher\Toolkit.ps1')
    Write-Host ''
    if ($updating) {
        Write-Host "An existing toolkit was found in $installDir" -ForegroundColor Yellow
        Write-Host 'It will be updated. Your PortableApps, Logs, Reports and Config\settings.json are kept.'
    } else {
        Write-Host "A new copy will be created in $installDir"
    }
    if ((Read-Host 'Continue? (Y/N)').Trim().ToUpperInvariant() -ne 'Y') { Write-Step 'Cancelled. Nothing was changed.'; return }

    # ---------- Download and verify ----------
    $tmp = Join-Path $env:TEMP ('ittk_install_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'toolkit.zip'

    Write-Step 'Checking the published release...'
    try {
        $m = (Get-WebText $manifestUrl) | ConvertFrom-Json
    } catch {
        throw "Could not read the release manifest ($($_.Exception.Message)). Check internet/proxy/firewall access to jlesc2026.github.io. Nothing was changed."
    }
    if ([int]$m.schema -ne 1 -or -not $m.toolkit -or -not $m.toolkit.url -or -not $m.toolkit.sha256) {
        throw 'The release manifest is not in the expected format. Nothing was changed.'
    }
    $zipUrl = [string]$m.toolkit.url
    if (-not $zipUrl.StartsWith($releasePrefix, [StringComparison]::Ordinal)) {
        throw "The manifest points outside $releasePrefix - refusing to download. Nothing was changed."
    }
    $expected = ([string]$m.toolkit.sha256).Trim().ToLowerInvariant()
    if ($expected -notmatch '^[0-9a-f]{64}$') { throw 'The manifest does not contain a valid SHA-256 value. Nothing was changed.' }

    Write-Step "Downloading toolkit $($m.version)..."
    Invoke-WebRequest -Uri $zipUrl -OutFile $zip -UseBasicParsing
    $actual = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "INTEGRITY CHECK FAILED: the download does not match the published SHA-256. Nothing was changed. Expected $expected but got $actual."
    }
    Write-Step "Integrity verified (SHA-256 $($actual.Substring(0, 16))...)."

    Write-Step 'Extracting...'
    $extract = Join-Path $tmp 'x'
    Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
    $src = Get-ChildItem -LiteralPath $extract -Directory | Select-Object -First 1
    # Find the toolkit folder wherever it sits (repo root or a subfolder such as 'Technical Support').
    $launcher = Get-ChildItem -LiteralPath $src.FullName -Recurse -File -Filter 'Toolkit.ps1' |
        Where-Object { (Split-Path $_.DirectoryName -Leaf) -eq 'Launcher' } | Select-Object -First 1
    if (-not $launcher) { throw 'Launcher\Toolkit.ps1 not found in the download. Nothing was changed.' }
    $root = Split-Path $launcher.DirectoryName -Parent

    # ---------- Copy (keeps the user's files when updating) ----------
    if (-not (Test-Path -LiteralPath $installDir)) { New-Item -ItemType Directory -Path $installDir | Out-Null }
    $robo = @('/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
    if ($updating) {
        # Keep a dated copy of the old configuration, then never overwrite settings.json or touch Logs / Reports.
        $cfg = Join-Path $installDir 'Config'
        if (Test-Path -LiteralPath $cfg) {
            $bk = Join-Path $cfg ('backup\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
            New-Item -ItemType Directory -Path $bk -Force | Out-Null
            foreach ($f in 'settings.json', 'shortcuts.json') {
                $p = Join-Path $cfg $f
                if (Test-Path -LiteralPath $p) { Copy-Item -LiteralPath $p -Destination $bk -Force }
            }
            Write-Step "Previous configuration saved to $bk"
        }
        $robo += @('/XF', 'settings.json', '/XD', 'Logs', 'Reports', 'backup')
    }
    Write-Step "Copying to $installDir ..."
    & robocopy.exe $root $installDir @robo | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "Copy failed (robocopy exit code $LASTEXITCODE)." }

    # The read-only PC assessment travels with the USB copy as well.
    $assessSrc = Join-Path $src.FullName 'Assess'
    if (Test-Path -LiteralPath $assessSrc) {
        & robocopy.exe $assessSrc (Join-Path $installDir 'Assess') /E /XD Reports /NFL /NDL /NJH /NJS /NP | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Copy of the assessment failed (robocopy exit code $LASTEXITCODE)." }
    }

    Get-ChildItem -LiteralPath $installDir -Recurse -File -ErrorAction SilentlyContinue | Unblock-File -ErrorAction SilentlyContinue

    if (-not (Test-Path -LiteralPath (Join-Path $installDir 'Launcher\Toolkit.ps1'))) { throw 'The copy could not be verified: Launcher\Toolkit.ps1 is missing in the target.' }

    Write-Host ''
    Write-Step "Done. Toolkit $($m.version) is in $installDir"
    Write-Host "  Start it:        $installDir\START.bat   (or START-AsAdmin.bat)"
    Write-Host "  Assessment:      $installDir\Assess\Assess.bat"
    Write-Host "  Portable tools:  put them in $installDir\PortableApps\<category>  (see PortableApps\README.txt)"
} catch {
    Write-Host "[ITTK] Error: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host 'Press Enter to close' | Out-Null
} finally {
    if ($tmp -and (Test-Path -LiteralPath $tmp)) {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path -LiteralPath $tmp) { Write-Host "[ITTK] WARNING: could not delete the temporary download folder: $tmp" -ForegroundColor Yellow }
    }
}
