# Common.ps1 - shared helpers for the IT Technician Toolkit.
# Every module dot-sources this file:
#   . (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
# Exit codes used by modules: 0 = success, 1 = failed, 2 = needs administrator.

$script:ToolkitRoot = Split-Path -Parent $PSScriptRoot

function Get-ToolkitRoot { return $script:ToolkitRoot }

function Get-ToolkitSettings {
    $s = [pscustomobject]@{
        toolkitName         = 'IT Technician Toolkit'
        loggingEnabled      = $true
        restartDelaySeconds = 30
        vendorLinks         = [pscustomobject]@{
            HP      = 'https://support.hp.com'
            Canon   = 'https://www.usa.canon.com/support'
            Epson   = 'https://epson.com/support'
            Brother = 'https://support.brother.com'
            Other   = 'https://www.google.com/search?q=printer+driver+download'
        }
    }
    $path = Join-Path $script:ToolkitRoot 'Config\settings.json'
    if (Test-Path $path) {
        try {
            $json = Get-Content $path -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($p in $json.PSObject.Properties) {
                $s | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
            }
        } catch { }
    }
    return $s
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------- Output helpers (the launcher colours lines by their [TAG]) ----------
function Write-Header { param([string]$Title) Write-Host "=== $Title ===" -ForegroundColor Cyan }
function Write-Info   { param([string]$Message) Write-Host "[INFO] $Message" }
function Write-Ok     { param([string]$Message) Write-Host "[ OK ] $Message" -ForegroundColor Green }
function Write-Warn   { param([string]$Message) Write-Host "[WARN] $Message" -ForegroundColor Yellow }
function Write-Fail   { param([string]$Message) Write-Host "[FAIL] $Message" -ForegroundColor Red }

function Write-Table {
    param($Rows)
    $text = ($Rows | Format-Table -AutoSize | Out-String -Width 220).TrimEnd()
    if ($text) { Write-Host $text }
}

# ---------- Logging ----------
function Write-Log {
    param([string]$Action, [string]$Result, [string]$Detail = '')
    try {
        if ($env:TOOLKIT_LOG -eq '0') { return }
        if ($env:TOOLKIT_LOG -ne '1') {
            $s = Get-ToolkitSettings
            if (-not $s.loggingEnabled) { return }
        }
        $dir = Join-Path $script:ToolkitRoot 'Logs'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir ("{0}.log" -f $env:COMPUTERNAME)
        $lines = @(
            (Get-Date -Format 'yyyy-MM-dd HH:mm'),
            "Computer: $env:COMPUTERNAME",
            "User: $env:USERNAME",
            "Action: $Action",
            "Result: $Result"
        )
        if ($Detail) { $lines += "Detail: $Detail" }
        $lines += ''
        Add-Content -Path $file -Value $lines -Encoding UTF8
    } catch { }
}

# ---------- Finishing a module ----------
function Exit-Toolkit {
    param([int]$Code = 0)
    if (-not $env:TOOLKIT_LAUNCHER) {
        Write-Host ''
        Read-Host 'Press Enter to close' | Out-Null
    }
    exit $Code
}

function Complete-Action {
    param([string]$Action, $Success, [string]$Detail = '')
    $ok = [bool]$Success
    if ($ok) { Write-Ok "$Action - completed successfully" }
    else     { Write-Fail "$Action - did not complete, see messages above" }
    Write-Log -Action $Action -Result $(if ($ok) { 'SUCCESS' } else { 'FAILED' }) -Detail $Detail
    Exit-Toolkit -Code $(if ($ok) { 0 } else { 1 })
}

function Assert-Admin {
    param([string]$Action)
    if (-not (Test-IsAdmin)) {
        Write-Fail "'$Action' needs administrator rights."
        Write-Info 'Close the toolkit and start it with START-AsAdmin.bat (or use the Relaunch as admin button).'
        Write-Log -Action $Action -Result 'NEEDS ADMIN'
        Exit-Toolkit -Code 2
    }
}

# ---------- Dialogs ----------
function Confirm-Action {
    param([string]$Message, [string]$Title = 'Confirm')
    Add-Type -AssemblyName System.Windows.Forms
    $owner = New-Object System.Windows.Forms.Form
    $owner.TopMost = $true
    $owner.ShowInTaskbar = $false
    $owner.StartPosition = 'CenterScreen'
    $owner.Size = New-Object System.Drawing.Size(1, 1)
    $owner.Show()
    $r = [System.Windows.Forms.MessageBox]::Show($owner, $Message, $Title, 'YesNo', 'Warning')
    $owner.Dispose()
    return ($r -eq 'Yes')
}

function Show-Picker {
    # Shows a list; returns the chosen objects (empty array if cancelled).
    param([object[]]$Items, [string]$Title = 'Select', [switch]$Multiple)
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    if (-not $Items -or $Items.Count -eq 0) { return @() }

    $f = New-Object System.Windows.Forms.Form
    $f.Text = $Title
    $f.Size = New-Object System.Drawing.Size(900, 540)
    $f.StartPosition = 'CenterScreen'
    $f.TopMost = $true
    $f.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $lv = New-Object System.Windows.Forms.ListView
    $lv.View = 'Details'
    $lv.FullRowSelect = $true
    $lv.GridLines = $true
    $lv.HideSelection = $false
    $lv.MultiSelect = [bool]$Multiple
    $lv.Dock = 'Fill'

    $props = @($Items[0].PSObject.Properties.Name)
    foreach ($p in $props) { [void]$lv.Columns.Add($p, 200) }
    foreach ($item in $Items) {
        $li = New-Object System.Windows.Forms.ListViewItem([string]$item.($props[0]))
        for ($i = 1; $i -lt $props.Count; $i++) { [void]$li.SubItems.Add([string]$item.($props[$i])) }
        $li.Tag = $item
        [void]$lv.Items.Add($li)
    }

    $panel = New-Object System.Windows.Forms.Panel
    $panel.Dock = 'Bottom'
    $panel.Height = 46

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Size = New-Object System.Drawing.Size(100, 30)
    $ok.Location = New-Object System.Drawing.Point(660, 8)
    $ok.Anchor = 'Top,Right'
    $ok.DialogResult = 'OK'

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Size = New-Object System.Drawing.Size(100, 30)
    $cancel.Location = New-Object System.Drawing.Point(770, 8)
    $cancel.Anchor = 'Top,Right'
    $cancel.DialogResult = 'Cancel'

    $hint = New-Object System.Windows.Forms.Label
    $hint.Text = $(if ($Multiple) { 'Ctrl+click to select several, then OK.' } else { 'Double-click an item or select it and press OK.' })
    $hint.AutoSize = $true
    $hint.Location = New-Object System.Drawing.Point(10, 14)

    $panel.Controls.AddRange(@($hint, $ok, $cancel))
    $f.Controls.Add($lv)
    $f.Controls.Add($panel)
    $f.AcceptButton = $ok
    $f.CancelButton = $cancel
    $lv.Add_DoubleClick({ $ok.PerformClick() }.GetNewClosure())

    $result = @()
    if ($f.ShowDialog() -eq 'OK') {
        foreach ($sel in $lv.SelectedItems) { $result += , $sel.Tag }
    }
    $f.Dispose()
    return $result
}

# ---------- Services ----------
function Get-CommonServiceList {
    return @(
        [pscustomobject]@{ Group = 'Printing';   Name = 'Spooler';   Label = 'Print Spooler' }
        [pscustomobject]@{ Group = 'Scanning';   Name = 'stisvc';    Label = 'Windows Image Acquisition (WIA)' }
        [pscustomobject]@{ Group = 'Networking'; Name = 'WlanSvc';   Label = 'WLAN AutoConfig' }
        [pscustomobject]@{ Group = 'Networking'; Name = 'Dhcp';      Label = 'DHCP Client' }
        [pscustomobject]@{ Group = 'Networking'; Name = 'Dnscache';  Label = 'DNS Client' }
        [pscustomobject]@{ Group = 'Networking'; Name = 'Netman';    Label = 'Network Connections' }
        [pscustomobject]@{ Group = 'Audio';      Name = 'Audiosrv';  Label = 'Windows Audio' }
        [pscustomobject]@{ Group = 'Bluetooth';  Name = 'bthserv';   Label = 'Bluetooth Support Service' }
        [pscustomobject]@{ Group = 'Windows';    Name = 'wuauserv';  Label = 'Windows Update' }
        [pscustomobject]@{ Group = 'Windows';    Name = 'BITS';      Label = 'Background Intelligent Transfer Service (BITS)' }
    )
}

# Returns $true on success, $false on failure, $null when the service does not exist.
function Restart-ServiceByName {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Label,
        [ValidateSet('Restart', 'Start', 'Stop')][string]$Mode = 'Restart'
    )
    if (-not $Label) { $Label = $Name }
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) {
        Write-Warn "$Label ($Name) is not installed on this PC - skipped"
        return $null
    }
    $wait = [TimeSpan]::FromSeconds(20)
    try {
        if ($Mode -eq 'Stop') {
            if ($svc.Status -eq 'Stopped') { Write-Ok "$Label was already stopped"; return $true }
            Stop-Service -Name $Name -Force -ErrorAction Stop
            $svc.WaitForStatus('Stopped', $wait)
            Write-Ok "$Label stopped"
            return $true
        }
        if ($svc.StartType -eq 'Disabled') {
            Write-Warn "$Label is set to Disabled, so it cannot be started"
            return $false
        }
        if ($Mode -eq 'Start' -and $svc.Status -eq 'Running') {
            Write-Ok "$Label is already running"
            return $true
        }
        if ($svc.Status -eq 'Running') {
            Restart-Service -Name $Name -Force -ErrorAction Stop
        } else {
            Start-Service -Name $Name -ErrorAction Stop
        }
        $svc.Refresh()
        $svc.WaitForStatus('Running', $wait)
        Write-Ok "$Label is running"
        return $true
    } catch {
        Write-Fail "$Label : $($_.Exception.Message)"
        return $false
    }
}

# Services: array of strings or objects/hashtables with Name and Label.
function Invoke-ServiceGroup {
    param([object[]]$Services, [ValidateSet('Restart', 'Start', 'Stop')][string]$Mode = 'Restart')
    $ok = 0; $fail = 0; $missing = 0
    foreach ($s in $Services) {
        if ($s -is [string]) { $name = $s; $label = $s } else { $name = $s.Name; $label = $s.Label }
        $r = Restart-ServiceByName -Name $name -Label $label -Mode $Mode
        if ($null -eq $r) { $missing++ } elseif ($r) { $ok++ } else { $fail++ }
    }
    Write-Info "Summary: $ok succeeded, $fail failed, $missing not installed"
    return ($fail -eq 0 -and $ok -gt 0)
}

# ---------- Readable status / error texts ----------
function Get-DeviceProblemText {
    param($Code)
    $map = @{
        0  = 'Working properly'
        1  = 'Device is not configured correctly'
        3  = 'Driver may be corrupted, or the system is low on memory'
        10 = 'Device cannot start'
        12 = 'Not enough free resources for this device'
        14 = 'Device needs a restart to work properly'
        18 = 'Drivers need to be reinstalled'
        19 = 'Registry configuration for the device is bad'
        21 = 'Windows is removing the device'
        22 = 'Device is disabled'
        24 = 'Device is not present, not working, or has no drivers installed'
        28 = 'Drivers are not installed'
        29 = 'Device is disabled in firmware/BIOS'
        31 = 'Device is not working properly, Windows cannot load its drivers'
        32 = 'Driver (service) for this device is disabled'
        33 = 'Windows cannot determine the resources the device needs'
        34 = 'Windows cannot determine the device settings'
        35 = 'Firmware does not give enough information to configure the device'
        36 = 'IRQ translation failed'
        37 = 'Driver returned a failure when starting'
        38 = 'Previous instance of the driver is still in memory'
        39 = 'Driver is corrupted or missing'
        40 = 'Registry information for the driver service is missing or corrupted'
        41 = 'Driver loaded but the hardware was not found'
        42 = 'A duplicate device already exists'
        43 = 'Device stopped itself after reporting a problem'
        44 = 'An application or service shut the device down'
        45 = 'Device is not currently connected'
        46 = 'Device not available because Windows is shutting down'
        47 = 'Device prepared for safe removal'
        48 = 'Driver is blocked from starting (known compatibility problem)'
        49 = 'Registry size limit exceeded'
        50 = 'Windows cannot apply all the properties of the device'
        51 = 'Device is waiting on another device to start'
        52 = 'Windows cannot verify the digital signature of the driver'
    }
    $c = [int]$Code
    if ($map.ContainsKey($c)) { return "Code $c - $($map[$c])" }
    return "Code $c - Unknown problem code"
}

function Get-PrinterStatusText {
    param($Code)
    switch ([int]$Code) {
        1 { 'Other' } 2 { 'Unknown' } 3 { 'Idle (ready)' } 4 { 'Printing' }
        5 { 'Warming up' } 6 { 'Stopped printing' } 7 { 'Offline' }
        default { "Unknown ($Code)" }
    }
}

function Get-PrinterErrorText {
    param($Code)
    switch ([int]$Code) {
        0 { 'Unknown' } 1 { 'Other' } 2 { 'No error' } 3 { 'Low paper' } 4 { 'No paper' }
        5 { 'Low toner/ink' } 6 { 'No toner/ink' } 7 { 'Door open' } 8 { 'Paper jam' }
        9 { 'Offline' } 10 { 'Service requested' } 11 { 'Output bin full' }
        default { "Unknown ($Code)" }
    }
}
