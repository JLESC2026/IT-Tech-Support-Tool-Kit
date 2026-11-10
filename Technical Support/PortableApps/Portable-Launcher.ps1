# Portable Tools launcher - lists and starts the portable programs stored in PortableApps\<category>.
# The toolkit does not ship third-party programs: download the official portable version
# (see PortableApps\README.txt) and drop it in the matching folder.
param(
    [ValidateSet('All', 'File-Management', 'Hardware-Diagnostics', 'Disk-Health', 'Network-Tools', 'Text-Editors', 'Archive-Utilities', 'Other-IT-Utilities')]
    [string]$Category = 'All',
    [switch]$OpenFolder
)
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
$A = "Portable tools: $Category"
Write-Header $A

$base = $PSScriptRoot
$allCats = 'File-Management', 'Hardware-Diagnostics', 'Disk-Health', 'Network-Tools', 'Text-Editors', 'Archive-Utilities', 'Other-IT-Utilities'

# Official download pages (shown when a folder is empty). Check each tool's licence before use.
$suggest = @{
    'File-Management'      = @(@('Everything (instant file search)', 'https://www.voidtools.com'), @('WinDirStat (disk usage)', 'https://windirstat.net'))
    'Hardware-Diagnostics' = @(@('HWiNFO (hardware information)', 'https://www.hwinfo.com'), @('CPU-Z', 'https://www.cpuid.com/softwares/cpu-z.html'))
    'Disk-Health'          = @(@('CrystalDiskInfo (SMART health)', 'https://crystalmark.info/en/software/crystaldiskinfo/'), @('CrystalDiskMark (speed test)', 'https://crystalmark.info/en/software/crystaldiskmark/'))
    'Network-Tools'        = @(@('PuTTY (SSH / serial)', 'https://www.chiark.greenend.org.uk/~sgtatham/putty/'), @('WinSCP (SFTP / SCP)', 'https://winscp.net'), @('Angry IP Scanner', 'https://angryip.org'))
    'Text-Editors'         = @(,@('Notepad++', 'https://notepad-plus-plus.org'))
    'Archive-Utilities'    = @(@('7-Zip (portable build via PortableApps.com)', 'https://portableapps.com/apps/utilities/7-zip_portable'), @('7-Zip official site', 'https://www.7-zip.org'))
    'Other-IT-Utilities'   = @(@('Sysinternals Suite (Microsoft)', 'https://learn.microsoft.com/sysinternals/downloads/sysinternals-suite'), @('PortableApps.com', 'https://portableapps.com'))
}

if ($OpenFolder) {
    try {
        Start-Process explorer.exe "`"$base`""
        Write-Ok "Opened $base"
        Complete-Action -Action 'Open PortableApps folder' -Success $true
    } catch {
        Write-Fail $_.Exception.Message
        Complete-Action -Action 'Open PortableApps folder' -Success $false
    }
}

$cats = @($Category)
if ($Category -eq 'All') { $cats = $allCats }

$exts = '*.exe', '*.bat', '*.cmd', '*.lnk'
$tools = @()
foreach ($c in $cats) {
    $dir = Join-Path $base $c
    if (-not (Test-Path $dir)) { continue }
    foreach ($e in $exts) {
        $tools += @(Get-ChildItem -LiteralPath $dir -Filter $e -File -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '^(unins|uninstall|vcredist|vc_redist|dotnet)' } |
            ForEach-Object { [pscustomobject]@{ Category = $c; File = $_ } })
    }
}

if ($tools.Count -eq 0) {
    Write-Warn "No portable programs found in PortableApps\$Category yet."
    $show = $cats
    foreach ($c in $show) {
        Write-Host ''
        Write-Info "Suggested for ${c}: (download from the official site, unzip into PortableApps\$c)"
        foreach ($s in $suggest[$c]) { Write-Host ("    {0,-48} {1}" -f $s[0], $s[1]) }
    }
    Write-Host ''
    Write-Info 'See PortableApps\README.txt for details. Only use legitimate downloads and respect each licence.'
    Complete-Action -Action $A -Success $true -Detail 'Nothing installed yet'
}

$items = $tools | Sort-Object Category, @{ Expression = { $_.File.Name } } | ForEach-Object {
    $folder = $_.File.DirectoryName.Substring($base.Length).TrimStart('\', '/')
    [pscustomobject]@{ Tool = $_.File.Name; Category = $_.Category; Folder = $folder; Size = (Format-Size $_.File.Length) }
}
Write-Info 'A selection window has opened - choose a tool to launch.'
$sel = @(Show-Picker -Items $items -Title "Portable tools - $Category")
if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }

$choice = $tools | Where-Object { $_.File.Name -eq $sel[0].Tool -and $_.File.DirectoryName.Substring($base.Length).TrimStart('\', '/') -eq $sel[0].Folder } | Select-Object -First 1
$ok = $false
try {
    Start-Process -FilePath $choice.File.FullName -WorkingDirectory $choice.File.DirectoryName
    Write-Ok "Launched $($choice.File.Name)"
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action "Portable tool: $($sel[0].Tool)" -Success $ok -Detail $choice.File.FullName
