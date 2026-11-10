# Toolkit self-check 2/2: every launcher button must point to something real.
# Checks Config\shortcuts.json against the files on disk, the parameters used in "args",
# the shared helper files each script loads, and the expected folder layout.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
$A = 'Toolkit wiring check'
Write-Header $A

$sep = [System.IO.Path]::DirectorySeparatorChar
function ConvertTo-LocalPath { param([string]$P) return ($P -replace '[\\/]', [string][System.IO.Path]::DirectorySeparatorChar) }

$fails = 0
$warns = 0

# 1. shortcuts.json loads
$cfgPath = Join-Path (Join-Path $root 'Config') 'shortcuts.json'
$cfg = $null
try {
    $cfg = Get-Content -LiteralPath $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Ok "Config\shortcuts.json loaded ($(@($cfg.categories).Count) categories)"
} catch {
    Write-Fail "Config\shortcuts.json could not be read: $($_.Exception.Message)"
    Complete-Action -Action $A -Success $false -Detail 'shortcuts.json unreadable'
}

# 2. expected main categories
$expected = 'quickfix', 'windows', 'printers', 'network', 'services', 'hardware', 'diagnostics', 'portable', 'advanced'
$ids = @($cfg.categories | ForEach-Object { $_.id })
foreach ($id in $expected) {
    if ($ids -notcontains $id) { Write-Fail "Main category '$id' is missing from shortcuts.json"; $fails++ }
}
Write-Host ''

# 3. every button
$wired = @{}
$btnCount = 0
foreach ($cat in $cfg.categories) {
    $names = @{}
    $items = @($cat.items)
    if ($items.Count -eq 0) { Write-Warn "Category '$($cat.id)' has no buttons"; $warns++ }
    foreach ($it in $items) {
        $btnCount++
        $label = "[$($cat.id)] $($it.name)"
        if (-not $it.name) { Write-Fail "[$($cat.id)] a button has no name"; $fails++; continue }
        if (-not $it.group) { Write-Warn "$label : no group"; $warns++ }
        if (-not $it.desc)  { Write-Warn "$label : no description"; $warns++ }
        $key = "$($it.name)|$($it.script)|$($it.path)|$($it.args)"
        if ($names.ContainsKey($key)) { Write-Warn "$label : duplicated button"; $warns++ }
        $names[$key] = $true

        if ($it.type -eq 'run') {
            if (-not $it.path) { Write-Fail "$label : type 'run' but no path"; $fails++; continue }
            $p = [string]$it.path
            # Only check plain executables / consoles that live in System32
            if ($p -match '^[A-Za-z0-9_\-]+\.(exe|msc|cpl)$' -and $env:windir -and (Test-Path -LiteralPath $env:windir)) {
                $found = (Test-Path -LiteralPath (Join-Path (Join-Path $env:windir 'System32') $p)) -or (Test-Path -LiteralPath (Join-Path $env:windir $p))
                if (-not $found) { Write-Warn "$label : '$p' was not found in the Windows folder (may not exist on this Windows edition)"; $warns++ }
            }
            continue
        }
        if ($it.type -and $it.type -ne 'gui') { Write-Fail "$label : unknown type '$($it.type)'"; $fails++ }
        if (-not $it.script) { Write-Fail "$label : no script"; $fails++; continue }
        $full = Join-Path $root (ConvertTo-LocalPath ([string]$it.script))
        if (-not (Test-Path -LiteralPath $full -PathType Leaf)) {
            Write-Fail "$label : script not found -> $($it.script)"
            $fails++
            continue
        }
        $wired[$full.ToLowerInvariant()] = $true

        # parameters used in args must exist in the script's param() block
        if ($it.args) {
            $tokens = $null; $perr = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($full, [ref]$tokens, [ref]$perr)
            $declared = @()
            if ($ast.ParamBlock) { $declared = @($ast.ParamBlock.Parameters | ForEach-Object { $_.Name.VariablePath.UserPath.ToLowerInvariant() }) }
            $used = @([regex]::Matches([string]$it.args, '(?<![\w])-([A-Za-z][A-Za-z0-9]*)') | ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() })
            foreach ($u in $used) {
                if ($declared -notcontains $u) {
                    Write-Fail "$label : args use -$u but $($it.script) has no such parameter"
                    $fails++
                }
            }
        }
    }
}
Write-Info "$btnCount button(s) checked"
Write-Host ''

# 4. helper files that each script loads
$scripts = @(Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -notlike "*${sep}Config${sep}backup${sep}*" -and $_.FullName -notlike "*${sep}Reports${sep}*"
})
$missingHelpers = 0
foreach ($s in $scripts) {
    $text = Get-Content -LiteralPath $s.FullName -Raw -ErrorAction SilentlyContinue
    foreach ($m in [regex]::Matches([string]$text, "'(Launcher[\\/][A-Za-z0-9_\-]+\.ps1)'")) {
        $h = Join-Path $root (ConvertTo-LocalPath $m.Groups[1].Value)
        if (-not (Test-Path -LiteralPath $h)) {
            Write-Fail "$($s.Name) loads $($m.Groups[1].Value) but that file does not exist"
            $fails++
            $missingHelpers++
        }
    }
}
if ($missingHelpers -eq 0) { Write-Ok 'All helper files loaded by the scripts exist' }

# 5. folder layout
$folders = 'Launcher', 'QuickFix', 'Windows', 'Printers', 'Scanners', 'Network', 'Services', 'Hardware', 'Diagnostics', 'Advanced', 'Wizard',
    'PortableApps', 'Drivers', 'Manufacturer', 'Manufacturer\HP', 'Manufacturer\Canon', 'Manufacturer\Epson', 'Manufacturer\Brother',
    'Manufacturer\Other', 'Reports', 'Logs', 'Config'
$missingFolders = @($folders | Where-Object { -not (Test-Path -LiteralPath (Join-Path $root (ConvertTo-LocalPath $_)) -PathType Container) })
foreach ($mf in $missingFolders) { Write-Warn "Folder missing: $mf"; $warns++ }
if ($missingFolders.Count -eq 0) { Write-Ok 'Folder layout is complete' }

# 6. start files
foreach ($bat in 'START.bat', 'START-AsAdmin.bat') {
    if (-not (Test-Path -LiteralPath (Join-Path $root $bat))) { Write-Fail "$bat is missing"; $fails++ }
}

# 7. scripts nobody can reach from a button (information only)
$skipDirs = 'Launcher', 'Config'
$orphans = @($scripts | Where-Object {
    $rel = $_.FullName.Substring($root.Length).TrimStart('\', '/')
    $top = ($rel -split '[\\/]')[0]
    ($skipDirs -notcontains $top) -and (-not $wired.ContainsKey($_.FullName.ToLowerInvariant()))
})
if ($orphans.Count -gt 0) {
    Write-Info "$($orphans.Count) script(s) are not wired to a button (they may be called by other scripts, or still to be added):"
    foreach ($o in $orphans) { Write-Host ('    ' + $o.FullName.Substring($root.Length).TrimStart('\', '/')) }
}

Write-Host ''
if ($fails -eq 0) { Write-Ok "Wiring check passed ($warns warning(s))" } else { Write-Fail "$fails problem(s) found ($warns warning(s))" }
Complete-Action -Action $A -Success ($fails -eq 0) -Detail "$btnCount buttons, $fails problems, $warns warnings"
