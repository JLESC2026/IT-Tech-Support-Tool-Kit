param([Parameter(Mandatory)][ValidateSet('HP', 'Canon', 'Epson', 'Brother', 'Other')][string]$Vendor)
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
$A = "Manufacturer tools: $Vendor"
Write-Header $A

$folder = Join-Path $PSScriptRoot $Vendor
$settings = Get-ToolkitSettings
$url = $settings.vendorLinks.$Vendor

# Runnable files the technician has placed in the vendor folder (searched up to 2 levels deep)
$exts = '*.exe', '*.msi', '*.bat', '*.cmd', '*.lnk', '*.ps1'
$tools = @()
if (Test-Path $folder) {
    foreach ($e in $exts) {
        $tools += @(Get-ChildItem -Path $folder -Filter $e -File -Recurse -Depth 2 -ErrorAction SilentlyContinue)
    }
}
$tools = @($tools | Sort-Object FullName -Unique)

if ($tools.Count -eq 0) {
    Write-Warn "No tools found in Manufacturer\$Vendor yet."
    Write-Info "Download the official $Vendor utility for the printer model and put it in that folder (see the README there)."
    if ($url) {
        Write-Info "Opening the $Vendor support site: $url"
        Start-Process $url
    }
    Write-Info 'Printhead cleaning, nozzle checks, ink charging and maintenance counters are model-specific. Use the vendor utility or the Maintenance tab in the printer preferences.'
    Complete-Action -Action $A -Success $true -Detail 'Opened support site'
}

$choice = $null
if ($tools.Count -eq 1) {
    $choice = $tools[0]
} else {
    $items = $tools | ForEach-Object {
        [pscustomobject]@{ Tool = $_.Name; Folder = $_.DirectoryName.Replace($folder, '.'); Type = $_.Extension }
    }
    Write-Info 'A selection window has opened - choose a tool to launch.'
    $sel = @(Show-Picker -Items $items -Title "Launch a $Vendor tool")
    if ($sel.Count -eq 0) { Write-Info 'Nothing selected - cancelled.'; Exit-Toolkit -Code 0 }
    $choice = $tools | Where-Object { $_.Name -eq $sel[0].Tool -and $_.DirectoryName.Replace($folder, '.') -eq $sel[0].Folder } | Select-Object -First 1
}

$ok = $false
try {
    if ($choice.Extension -eq '.ps1') {
        Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$($choice.FullName)`""
    } else {
        Start-Process -FilePath $choice.FullName -WorkingDirectory $choice.DirectoryName
    }
    Write-Ok "Launched $($choice.Name)"
    $ok = $true
} catch {
    Write-Fail $_.Exception.Message
}
Complete-Action -Action $A -Success $ok -Detail $choice.Name
