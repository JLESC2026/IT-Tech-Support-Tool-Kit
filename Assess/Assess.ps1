# Assess.ps1 - PC hardware and health assessment.
# Reads (never changes) the hardware, firmware, security and event-log state of a laptop or PC
# and writes ONE self-contained HTML report. A summary is printed in the terminal too.
#
# Run locally:   powershell -NoProfile -ExecutionPolicy Bypass -File .\Assess.ps1
# Run from web:  irm jlesc2026.github.io/assess | iex
# Switches:      -OutDir <folder>  where to save the report
#                -NoOpen           do not open the report when finished
#                -NoElevate        do not ask for administrator rights
#                -Pause            wait for Enter at the end (used when the window would close)
#
# Windows PowerShell 5.1 and 7 compatible. ASCII only (no ternary, ?. , ?? , && operators).
[CmdletBinding()]
param(
    [string]$OutDir = '',
    [switch]$NoOpen,
    [switch]$NoElevate,
    [switch]$Pause
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$ToolVersion = '1.0'

# All state lives in one hashtable so the helper functions can reach it.
$AS = @{
    Sections = (New-Object System.Collections.Generic.List[object])
    Issues   = (New-Object System.Collections.Generic.List[object])
    Cur      = $null
    Step     = 0
    Total    = 12
    IsLaptop = $false
    IsAdmin  = $false
}

# ---------------------------------------------------------------- helpers
function Test-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Format-Bytes {
    param($Bytes)
    if ($null -eq $Bytes -or "$Bytes" -eq '') { return '-' }
    $b = [double]$Bytes
    if ($b -ge 1TB) { return ('{0:N2} TB' -f ($b / 1TB)) }
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N0} MB' -f ($b / 1MB)) }
    return ('{0:N0} KB' -f ($b / 1KB))
}

function Format-When {
    param($Date, [string]$Format = 'yyyy-MM-dd')
    if ($null -eq $Date) { return '-' }
    try { return ([datetime]$Date).ToString($Format) } catch { return "$Date" }
}

function Get-CimSafe {
    param([string]$Class, [string]$Namespace = 'root\cimv2', [string]$Filter = '')
    try {
        if ($Filter) { return @(Get-CimInstance -Namespace $Namespace -ClassName $Class -Filter $Filter -ErrorAction Stop) }
        return @(Get-CimInstance -Namespace $Namespace -ClassName $Class -ErrorAction Stop)
    } catch { return @() }
}

function ConvertFrom-CharArray {
    param($Arr)
    if (-not $Arr) { return '' }
    return ((@($Arr) | Where-Object { $_ -ne 0 } | ForEach-Object { [string][char]$_ }) -join '')
}

function Get-DeviceProblemText {
    param($Code)
    $map = @{
        1 = 'Device is not configured correctly'; 3 = 'Driver may be corrupted or the system is low on memory'
        10 = 'Device cannot start'; 12 = 'Not enough free resources'; 14 = 'Needs a restart to work properly'
        18 = 'Drivers need to be reinstalled'; 19 = 'Registry configuration is bad'; 22 = 'Device is disabled'
        24 = 'Device is not present or not working'; 28 = 'Drivers are not installed'
        29 = 'Disabled in firmware/BIOS'; 31 = 'Windows cannot load the drivers'
        32 = 'Driver service is disabled'; 37 = 'Driver failed when starting'; 39 = 'Driver is corrupted or missing'
        41 = 'Driver loaded but hardware not found'; 43 = 'Device stopped itself after reporting a problem'
        48 = 'Driver is blocked (compatibility problem)'; 52 = 'Driver signature cannot be verified'
    }
    $c = [int]$Code
    if ($map.ContainsKey($c)) { return "Code $c - $($map[$c])" }
    return "Code $c - problem reported by Device Manager"
}

function Start-Section {
    param([string]$Title)
    $s = [pscustomobject]@{
        Title  = $Title
        Items  = (New-Object System.Collections.Generic.List[object])
        Tables = (New-Object System.Collections.Generic.List[object])
    }
    $AS.Sections.Add($s)
    $AS.Cur = $s
    $AS.Step++
    Write-Host ('[{0,2}/{1}] {2} ...' -f $AS.Step, $AS.Total, $Title) -ForegroundColor Cyan
}

# Status: OK, WARN, FAIL or INFO. Note = advice shown when the status is not OK/INFO.
function Add-Item {
    param([string]$Label, $Value, [string]$Status = 'INFO', [string]$Note = '')
    $v = '-'
    if ($null -ne $Value -and "$Value" -ne '') { $v = "$Value" }
    $AS.Cur.Items.Add([pscustomobject]@{ Label = $Label; Value = $v; Status = $Status; Note = $Note })
    if ($Status -eq 'WARN' -or $Status -eq 'FAIL') {
        $AS.Issues.Add([pscustomobject]@{ Section = $AS.Cur.Title; Label = $Label; Value = $v; Status = $Status; Note = $Note })
    }
}

function Add-Table {
    param([string]$Title, $Rows)
    $r = @($Rows | Where-Object { $null -ne $_ })
    if ($r.Count -eq 0) { return }
    $AS.Cur.Tables.Add([pscustomobject]@{ Title = $Title; Rows = $r })
}

function Invoke-Check {
    param([string]$Title, [scriptblock]$Block)
    Start-Section $Title
    try { & $Block } catch {
        Add-Item 'This check' ('could not complete: ' + $_.Exception.Message) 'WARN' 'Run the assessment as administrator and try again.'
    }
}

function Get-EventsSafe {
    param([hashtable]$Filter, [int]$Max = 500)
    try { return @(Get-WinEvent -FilterHashtable $Filter -MaxEvents $Max -ErrorAction SilentlyContinue) } catch { return @() }
}

function Resolve-OutDir {
    param([string]$Dir)
    $cands = @()
    if ($Dir) { $cands += $Dir }
    if ($env:ASSESS_OUT) { $cands += $env:ASSESS_OUT }
    if ($PSScriptRoot) { $cands += (Join-Path $PSScriptRoot 'Reports') }
    try { $cands += [Environment]::GetFolderPath('Desktop') } catch { }
    $cands += $env:TEMP
    foreach ($c in $cands) {
        if (-not $c) { continue }
        try {
            if (-not (Test-Path -LiteralPath $c)) { New-Item -ItemType Directory -Path $c -Force -ErrorAction Stop | Out-Null }
            $probe = Join-Path $c ('.w' + [guid]::NewGuid().ToString('N'))
            [System.IO.File]::WriteAllText($probe, 'x')
            Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
            return $c
        } catch { }
    }
    return $env:TEMP
}

function Test-PingHost {
    param([string]$Target, [int]$Count = 4, [int]$TimeoutMs = 2000)
    $p = New-Object System.Net.NetworkInformation.Ping
    $ok = 0
    $times = @()
    for ($i = 0; $i -lt $Count; $i++) {
        try {
            $r = $p.Send($Target, $TimeoutMs)
            if ($r.Status -eq 'Success') { $ok++; $times += [int]$r.RoundtripTime }
        } catch { }
    }
    $avg = $null
    if ($times.Count -gt 0) { $avg = [int][math]::Round(($times | Measure-Object -Average).Average, 0) }
    return [pscustomobject]@{ Sent = $Count; Received = $ok; AvgMs = $avg }
}

function Get-GpuMemoryBytes {
    param([string]$Name)
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    foreach ($k in @(Get-ChildItem -Path $base -ErrorAction SilentlyContinue)) {
        if ($k.PSChildName -notmatch '^\d{4}$') { continue }
        $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
        if (-not $p -or $p.DriverDesc -ne $Name) { continue }
        $v = $p.'HardwareInformation.qwMemorySize'
        if ($null -eq $v) { $v = $p.'HardwareInformation.MemorySize' }
        if ($null -eq $v) { continue }
        if ($v -is [byte[]]) {
            if ($v.Length -ge 8) { return [double][BitConverter]::ToUInt64($v, 0) }
            if ($v.Length -ge 4) { return [double][BitConverter]::ToUInt32($v, 0) }
            continue
        }
        try { return [double]([uint64]$v) } catch { continue }
    }
    return $null
}

function ConvertTo-Html5 {
    param($Text)
    return [System.Net.WebUtility]::HtmlEncode([string]$Text)
}

# ---------------------------------------------------------------- start
if ($env:OS -ne 'Windows_NT') {
    Write-Host 'This assessment runs on Windows only.' -ForegroundColor Red
    return
}

$AS.IsAdmin = Test-IsAdmin
if (-not $AS.IsAdmin -and -not $NoElevate -and $PSCommandPath) {
    Write-Host 'Requesting administrator rights (needed for disk health, TPM, BitLocker and event logs)...' -ForegroundColor Yellow
    try {
        $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Pause"
        if ($OutDir) { $argList += " -OutDir `"$OutDir`"" }
        if ($NoOpen) { $argList += ' -NoOpen' }
        Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -ArgumentList $argList
        return
    } catch {
        Write-Host 'Elevation was cancelled - continuing without administrator rights (some checks will be limited).' -ForegroundColor Yellow
    }
}

$started = Get-Date
Write-Host ''
Write-Host "=== PC Assessment v$ToolVersion - $env:COMPUTERNAME ===" -ForegroundColor White
if ($AS.IsAdmin) { Write-Host 'Running as administrator.' -ForegroundColor Green }
else { Write-Host 'Not running as administrator: SMART, BitLocker, TPM and some event data will be limited.' -ForegroundColor Yellow }
Write-Host 'Read-only: nothing on this computer is changed.' -ForegroundColor DarkGray
Write-Host ''

# ---------------------------------------------------------------- 1. System
Invoke-Check 'System' {
    $os = Get-CimSafe -Class Win32_OperatingSystem | Select-Object -First 1
    $cs = Get-CimSafe -Class Win32_ComputerSystem | Select-Object -First 1
    $bios = Get-CimSafe -Class Win32_BIOS | Select-Object -First 1
    $enc = Get-CimSafe -Class Win32_SystemEnclosure | Select-Object -First 1
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue

    $laptopTypes = 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32
    $kind = 'Desktop / other'
    if ($enc -and (@($enc.ChassisTypes) | Where-Object { $laptopTypes -contains [int]$_ })) { $kind = 'Laptop / portable'; $AS.IsLaptop = $true }

    Add-Item 'Computer name' $env:COMPUTERNAME
    Add-Item 'Signed-in user' $env:USERNAME
    if ($cs) {
        $dom = [string]$cs.Workgroup
        if ($cs.PartOfDomain) { $dom = [string]$cs.Domain }
        Add-Item 'Domain / workgroup' $dom
        Add-Item 'Manufacturer' $cs.Manufacturer
        Add-Item 'Model' $cs.Model
    }
    Add-Item 'Type' $kind
    if ($bios) { Add-Item 'Serial number' $bios.SerialNumber }

    if ($os) {
        $name = [string]$os.Caption
        $build = 0
        [void][int]::TryParse([string]$os.BuildNumber, [ref]$build)
        if ($build -ge 22000) { $name = $name -replace 'Windows 10', 'Windows 11' }
        $ver = ''
        if ($cv -and $cv.DisplayVersion) { $ver = [string]$cv.DisplayVersion } elseif ($cv -and $cv.ReleaseId) { $ver = [string]$cv.ReleaseId }
        $ubr = ''
        if ($cv -and $null -ne $cv.UBR) { $ubr = ".$($cv.UBR)" }
        Add-Item 'Windows' ("$name $ver  (build $build$ubr, $($os.OSArchitecture))").Replace('  ', ' ')
        Add-Item 'Installed on' (Format-When $os.InstallDate)
        Add-Item 'Last boot' (Format-When $os.LastBootUpTime 'yyyy-MM-dd HH:mm')
        $up = (Get-Date) - $os.LastBootUpTime
        $upText = '{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes
        if ($up.TotalDays -ge 14) { Add-Item 'Uptime' $upText 'WARN' 'Not restarted for 2+ weeks. Restart to apply updates and clear memory.' }
        else { Add-Item 'Uptime' $upText 'OK' }
    }
    try { Add-Item 'Time zone' (Get-TimeZone).Id } catch { }

    $pending = @()
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $pending += 'component servicing' }
    if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $pending += 'Windows Update' }
    if ($pending.Count -gt 0) { Add-Item 'Restart pending' ($pending -join ', ') 'WARN' 'Restart the computer, then run the assessment again.' }
    else { Add-Item 'Restart pending' 'No' 'OK' }
}

# ---------------------------------------------------------------- 2. Processor
Invoke-Check 'Processor' {
    $cpus = Get-CimSafe -Class Win32_Processor
    if ($cpus.Count -eq 0) { Add-Item 'Processor' 'not reported by Windows' 'WARN'; return }
    foreach ($c in $cpus) {
        Add-Item 'Processor' ([string]$c.Name).Trim()
        Add-Item 'Cores / threads' "$($c.NumberOfCores) / $($c.NumberOfLogicalProcessors)"
        Add-Item 'Clock (current / max)' "$($c.CurrentClockSpeed) MHz / $($c.MaxClockSpeed) MHz"
        if ($c.L3CacheSize) { Add-Item 'Cache (L2 / L3)' "$([math]::Round($c.L2CacheSize / 1024, 1)) MB / $([math]::Round($c.L3CacheSize / 1024, 1)) MB" }
        if ($c.VirtualizationFirmwareEnabled -eq $true) { Add-Item 'Virtualization' 'Enabled in firmware' 'OK' }
        else { Add-Item 'Virtualization' 'Disabled or not reported' 'INFO' }
        if ($c.Status -and $c.Status -ne 'OK') { Add-Item 'Processor status' $c.Status 'FAIL' 'Windows reports a processor problem.' }
    }

    $samples = @()
    for ($i = 0; $i -lt 3; $i++) {
        $p = Get-CimSafe -Class Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" | Select-Object -First 1
        if ($p) { $samples += [double]$p.PercentProcessorTime }
        Start-Sleep -Milliseconds 700
    }
    if ($samples.Count -gt 0) {
        $avg = [math]::Round(($samples | Measure-Object -Average).Average, 0)
        if ($avg -ge 90) { Add-Item 'CPU load (3 samples)' "$avg %" 'WARN' 'CPU is nearly maxed out while idle - check Task Manager for the busy program.' }
        else { Add-Item 'CPU load (3 samples)' "$avg %" 'OK' }
    }

    $temps = Get-CimSafe -Class MSAcpi_ThermalZoneTemperature -Namespace 'root\wmi'
    if ($temps.Count -gt 0) {
        $t = [math]::Round((($temps | Measure-Object -Property CurrentTemperature -Maximum).Maximum / 10) - 273.15, 0)
        if ($t -ge 85) { Add-Item 'Thermal zone temperature' "$t C" 'FAIL' 'Overheating. Clean the vents/fan and check the cooling.' }
        elseif ($t -ge 75) { Add-Item 'Thermal zone temperature' "$t C" 'WARN' 'Running hot. Check the vents, fan and dust.' }
        else { Add-Item 'Thermal zone temperature' "$t C" 'OK' }
    } else {
        Add-Item 'CPU temperature' 'Not exposed by this PC (use HWiNFO from PortableApps for live sensors)' 'INFO'
    }
}

# ---------------------------------------------------------------- 3. Memory
Invoke-Check 'Memory' {
    $os = Get-CimSafe -Class Win32_OperatingSystem | Select-Object -First 1
    $cs = Get-CimSafe -Class Win32_ComputerSystem | Select-Object -First 1
    if ($os -and $cs) {
        $total = [double]$cs.TotalPhysicalMemory
        $free = [double]$os.FreePhysicalMemory * 1KB
        $usedPct = [math]::Round((1 - ($free / $total)) * 100, 0)
        $totalGb = [math]::Round($total / 1GB, 1)
        if ($totalGb -lt 4) { Add-Item 'Installed RAM' (Format-Bytes $total) 'FAIL' 'Less than 4 GB is too little for Windows 10/11. Upgrade the RAM.' }
        elseif ($totalGb -lt 8) { Add-Item 'Installed RAM' (Format-Bytes $total) 'WARN' '8 GB is the practical minimum today. Consider adding RAM.' }
        else { Add-Item 'Installed RAM' (Format-Bytes $total) 'OK' }
        $line = "$(Format-Bytes $free) free ($usedPct % in use)"
        if ($usedPct -ge 90) { Add-Item 'Memory in use' $line 'FAIL' 'Memory is almost full. Close programs or add RAM.' }
        elseif ($usedPct -ge 80) { Add-Item 'Memory in use' $line 'WARN' 'High memory use. Check Task Manager for large programs.' }
        else { Add-Item 'Memory in use' $line 'OK' }
    }

    $typeMap = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 28 = 'LPDDR'; 29 = 'LPDDR2'; 30 = 'LPDDR3'; 31 = 'LPDDR4'; 34 = 'DDR5'; 35 = 'LPDDR5' }
    $mods = Get-CimSafe -Class Win32_PhysicalMemory
    $arr = Get-CimSafe -Class Win32_PhysicalMemoryArray | Select-Object -First 1
    if ($arr) {
        $maxGb = ''
        if ($arr.MaxCapacity) { $maxGb = ", max supported $(Format-Bytes ([double]$arr.MaxCapacity * 1KB))" }
        Add-Item 'Memory slots' "$($mods.Count) used of $($arr.MemoryDevices)$maxGb"
    }
    if ($mods.Count -gt 0) {
        Add-Table 'Memory modules' ($mods | ForEach-Object {
            $t = '-'
            if ($typeMap.ContainsKey([int]$_.SMBIOSMemoryType)) { $t = $typeMap[[int]$_.SMBIOSMemoryType] }
            $spd = $_.Speed
            if ($_.ConfiguredClockSpeed) { $spd = $_.ConfiguredClockSpeed }
            [pscustomobject]@{ Slot = $_.DeviceLocator; Size = (Format-Bytes $_.Capacity); Type = $t; 'Speed (MHz)' = $spd; Maker = ([string]$_.Manufacturer).Trim(); 'Part number' = ([string]$_.PartNumber).Trim() }
        })
        $sizes = @($mods | ForEach-Object { $_.Capacity } | Select-Object -Unique)
        if ($mods.Count -eq 1 -and -not $AS.IsLaptop) { Add-Item 'Memory channels' 'Single module (single-channel)' 'INFO' 'Two matching modules give noticeably better performance.' }
        if ($sizes.Count -gt 1) { Add-Item 'Module sizes' 'Mixed sizes installed' 'INFO' 'Mixed modules can run in a slower mode.' }
    }

    $pf = Get-CimSafe -Class Win32_PageFileUsage | Select-Object -First 1
    if ($pf) { Add-Item 'Page file' "$($pf.CurrentUsage) MB used of $($pf.AllocatedBaseSize) MB" }

    $md = Get-EventsSafe -Filter @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-MemoryDiagnostics-Results' } -Max 5 | Sort-Object TimeCreated -Descending
    if ($md.Count -gt 0) {
        $last = $md[0]
        $when = Format-When $last.TimeCreated 'yyyy-MM-dd'
        if ($last.Id -eq 1202) { Add-Item 'Windows Memory Diagnostic' "Last test ($when): ERRORS found" 'FAIL' 'The RAM has faults. Replace the failing module.' }
        else { Add-Item 'Windows Memory Diagnostic' "Last test ($when): no errors" 'OK' }
    } else {
        Add-Item 'Windows Memory Diagnostic' 'No test on record' 'INFO' 'Run mdsched.exe (needs a restart) if the PC crashes or freezes.'
    }
}

# ---------------------------------------------------------------- 4. Storage
Invoke-Check 'Storage' {
    $pds = @()
    try { $pds = @(Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId) } catch { }
    if ($pds.Count -eq 0) { Add-Item 'Physical disks' 'Could not be listed' 'WARN' 'Storage cmdlets are unavailable or need administrator rights.' }
    $diskRows = @()
    foreach ($p in $pds) {
        $h = [string]$p.HealthStatus
        $line = "$($p.MediaType) | $($p.BusType) | $(Format-Bytes $p.Size) | $h"
        if ($h -eq 'Healthy') { Add-Item "Disk $($p.DeviceId): $($p.FriendlyName)" $line 'OK' }
        elseif ($h -eq 'Warning') { Add-Item "Disk $($p.DeviceId): $($p.FriendlyName)" $line 'WARN' 'The drive reports a warning. Back up your data now.' }
        else { Add-Item "Disk $($p.DeviceId): $($p.FriendlyName)" $line 'FAIL' 'The drive is unhealthy. Back up your data and replace the disk.' }
        $c = $null
        try { $c = $p | Get-StorageReliabilityCounter -ErrorAction Stop } catch { }
        if ($c) {
            $diskRows += [pscustomobject]@{ Disk = $p.FriendlyName; 'Temp C' = $c.Temperature; 'Wear %' = $c.Wear; 'Power-on hours' = $c.PowerOnHours; 'Read errors' = $c.ReadErrorsTotal; 'Write errors' = $c.WriteErrorsTotal }
            if ($null -ne $c.Temperature -and $c.Temperature -ge 70) { Add-Item "$($p.FriendlyName) temperature" "$($c.Temperature) C" 'FAIL' 'Drive is too hot. Check airflow.' }
            elseif ($null -ne $c.Temperature -and $c.Temperature -ge 60) { Add-Item "$($p.FriendlyName) temperature" "$($c.Temperature) C" 'WARN' 'Drive is running hot.' }
            if ($null -ne $c.Wear -and $c.Wear -ge 90) { Add-Item "$($p.FriendlyName) wear" "$($c.Wear) % used" 'FAIL' 'SSD is nearly worn out. Replace it soon.' }
            elseif ($null -ne $c.Wear -and $c.Wear -ge 80) { Add-Item "$($p.FriendlyName) wear" "$($c.Wear) % used" 'WARN' 'SSD wear is high. Plan a replacement.' }
            if (($c.ReadErrorsTotal -gt 0) -or ($c.WriteErrorsTotal -gt 0)) { Add-Item "$($p.FriendlyName) errors" "read $($c.ReadErrorsTotal) / write $($c.WriteErrorsTotal)" 'WARN' 'The drive has recorded read/write errors.' }
        }
    }
    if ($diskRows.Count -gt 0) { Add-Table 'Drive reliability counters' $diskRows }
    elseif ($pds.Count -gt 0) { Add-Item 'Reliability counters' 'Not available (needs administrator, or the drive does not report them)' 'INFO' }

    $pred = Get-CimSafe -Class MSStorageDriver_FailurePredictStatus -Namespace 'root\wmi'
    if ($pred.Count -eq 0) { Add-Item 'SMART failure prediction' 'Not reported (normal for NVMe/USB drives, or needs administrator)' 'INFO' }
    foreach ($d in $pred) {
        if ($d.PredictFailure) { Add-Item 'SMART failure prediction' 'Drive predicts FAILURE' 'FAIL' 'Back up now and replace the drive.' }
        else { Add-Item 'SMART failure prediction' 'No failure predicted' 'OK' }
    }

    $sysLetter = $env:SystemDrive.TrimEnd(':')
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.Size } | Sort-Object DriveLetter)) {
        $pct = [math]::Round(($v.SizeRemaining / $v.Size) * 100, 1)
        $line = "$(Format-Bytes $v.SizeRemaining) free of $(Format-Bytes $v.Size) ($pct % free) $($v.FileSystem)"
        $label = "Volume $($v.DriveLetter): $($v.FileSystemLabel)".Trim()
        if ($v.HealthStatus -and [string]$v.HealthStatus -ne 'Healthy') { Add-Item $label $line 'FAIL' "Volume health: $($v.HealthStatus). Run CHKDSK and back up." }
        elseif ($pct -lt 5) { Add-Item $label $line 'FAIL' 'Almost full. Free up space.' }
        elseif ($pct -lt 10) { Add-Item $label $line 'WARN' 'Low free space. Windows may slow down.' }
        else { Add-Item $label $line 'OK' }
    }

    try {
        $part = Get-Partition -DriveLetter $sysLetter -ErrorAction Stop
        $sysDisk = $pds | Where-Object { [string]$_.DeviceId -eq [string]$part.DiskNumber } | Select-Object -First 1
        if ($sysDisk -and [string]$sysDisk.MediaType -eq 'HDD') {
            Add-Item 'Windows drive type' 'Hard disk (HDD)' 'INFO' 'An SSD would make this PC much faster.'
        } elseif ($sysDisk) {
            Add-Item 'Windows drive type' ([string]$sysDisk.MediaType) 'OK'
        }
    } catch { }

    $ev = Get-EventsSafe -Filter @{ LogName = 'System'; ProviderName = 'disk'; Id = 7, 11, 51, 52, 153; StartTime = (Get-Date).AddDays(-30) } -Max 200
    if ($ev.Count -eq 0) { Add-Item 'Disk errors in the event log (30 days)' 'None' 'OK' }
    else {
        $serious = @($ev | Where-Object { $_.Id -in 7, 52 }).Count
        $txt = "$($ev.Count) event(s), latest $(Format-When $ev[0].TimeCreated)"
        if ($serious -gt 0) { Add-Item 'Disk errors in the event log (30 days)' $txt 'FAIL' 'Bad blocks or imminent failure reported. Back up and replace the drive.' }
        else { Add-Item 'Disk errors in the event log (30 days)' $txt 'WARN' 'Disk retries/controller errors. Check cables, then run CHKDSK.' }
    }
}

# ---------------------------------------------------------------- 5. Graphics & display
Invoke-Check 'Graphics and display' {
    $gpus = Get-CimSafe -Class Win32_VideoController
    if ($gpus.Count -eq 0) { Add-Item 'Graphics adapter' 'None found' 'FAIL' 'No display adapter is detected.' }
    foreach ($g in $gpus) {
        $mem = Get-GpuMemoryBytes -Name $g.Name
        if ($null -eq $mem -and $g.AdapterRAM) { $mem = [double]$g.AdapterRAM }
        $memTxt = '-'
        if ($mem) { $memTxt = Format-Bytes $mem }
        $date = '-'
        if ($g.DriverDate) { $date = Format-When $g.DriverDate }
        $line = "$($g.Name) | video memory $memTxt | driver $($g.DriverVersion) ($date)"
        if ([int]$g.ConfigManagerErrorCode -ne 0) { Add-Item 'Graphics adapter' $line 'FAIL' (Get-DeviceProblemText $g.ConfigManagerErrorCode) }
        elseif ($g.Name -match 'Basic Display|Basic Render') { Add-Item 'Graphics adapter' $line 'WARN' 'Generic Microsoft driver: install the NVIDIA / AMD / Intel driver.' }
        elseif ($g.DriverDate -and ((Get-Date) - $g.DriverDate).TotalDays -gt 1095) { Add-Item 'Graphics adapter' $line 'INFO' 'Driver is older than 3 years. Update it if there are display problems.' }
        else { Add-Item 'Graphics adapter' $line 'OK' }
        if ($g.CurrentHorizontalResolution) { Add-Item '  Current mode' "$($g.CurrentHorizontalResolution) x $($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate) Hz" }
    }
    $mons = Get-CimSafe -Class WmiMonitorID -Namespace 'root\wmi'
    if ($mons.Count -eq 0) { Add-Item 'Monitors' 'No monitor information reported' 'INFO' }
    foreach ($m in $mons) {
        $maker = ConvertFrom-CharArray $m.ManufacturerName
        $model = ConvertFrom-CharArray $m.UserFriendlyName
        Add-Item 'Monitor' "$maker $model (made $($m.YearOfManufacture))".Trim() 'OK'
    }
}

# ---------------------------------------------------------------- 6. Battery & power
Invoke-Check 'Battery and power' {
    $bat = Get-CimSafe -Class Win32_Battery
    if ($bat.Count -eq 0) {
        if ($AS.IsLaptop) { Add-Item 'Battery' 'No battery detected in a laptop' 'WARN' 'The battery is missing, dead or not recognised.' }
        else { Add-Item 'Battery' 'None (desktop)' 'INFO' }
        return
    }
    $b = $bat[0]
    $statusMap = @{ 1 = 'Discharging'; 2 = 'On AC power'; 3 = 'Fully charged'; 4 = 'Low'; 5 = 'Critical'; 6 = 'Charging'; 7 = 'Charging (high)'; 8 = 'Charging (low)'; 9 = 'Charging (critical)'; 11 = 'Partially charged' }
    $st = 'Unknown'
    if ($statusMap.ContainsKey([int]$b.BatteryStatus)) { $st = $statusMap[[int]$b.BatteryStatus] }
    Add-Item 'Charge' "$($b.EstimatedChargeRemaining) % - $st"

    $design = Get-CimSafe -Class BatteryStaticData -Namespace 'root\wmi' | Select-Object -First 1
    $full = Get-CimSafe -Class BatteryFullChargedCapacity -Namespace 'root\wmi' | Select-Object -First 1
    $cyc = Get-CimSafe -Class BatteryCycleCount -Namespace 'root\wmi' | Select-Object -First 1
    if ($design -and $full -and $design.DesignedCapacity -gt 0) {
        $health = [math]::Round(($full.FullChargedCapacity / $design.DesignedCapacity) * 100, 0)
        $line = "$health % of original ($($full.FullChargedCapacity) of $($design.DesignedCapacity) mWh)"
        if ($health -lt 50) { Add-Item 'Battery health' $line 'FAIL' 'The battery holds less than half of its original charge. Replace it.' }
        elseif ($health -lt 80) { Add-Item 'Battery health' $line 'WARN' 'The battery is worn. Expect shorter runtime.' }
        else { Add-Item 'Battery health' $line 'OK' }
    } else {
        Add-Item 'Battery health' 'Capacity data not reported (see: powercfg /batteryreport)' 'INFO'
    }
    if ($cyc -and $cyc.CycleCount) { Add-Item 'Charge cycles' $cyc.CycleCount }
    try {
        $plan = (& powercfg.exe /getactivescheme 2>$null | Out-String).Trim()
        if ($plan) { Add-Item 'Power plan' ($plan -replace '^.*\(([^)]+)\).*$', '$1') }
    } catch { }
}

# ---------------------------------------------------------------- 7. Network
Invoke-Check 'Network' {
    $adapters = @()
    try { $adapters = @(Get-NetAdapter -ErrorAction Stop | Sort-Object Status, Name) } catch { }
    if ($adapters.Count -eq 0) { Add-Item 'Network adapters' 'None found' 'FAIL' 'No network adapter is installed or enabled.' }
    else {
        Add-Table 'Network adapters' ($adapters | ForEach-Object {
            [pscustomobject]@{ Name = $_.Name; Description = $_.InterfaceDescription; Status = [string]$_.Status; Speed = [string]$_.LinkSpeed; MAC = [string]$_.MacAddress }
        })
        $physUp = @($adapters | Where-Object { $_.Status -eq 'Up' -and $_.InterfaceDescription -notmatch 'Virtual|VPN|TAP|Loopback|Hyper-V|VMware|VirtualBox' })
        if ($physUp.Count -eq 0) { Add-Item 'Connection' 'No physical adapter is connected' 'WARN' 'Check the cable or Wi-Fi.' }
    }

    $primaryGw = ''
    try {
        foreach ($c in @(Get-NetIPConfiguration -ErrorAction Stop | Where-Object { $_.NetAdapter.Status -eq 'Up' })) {
            $ip = (@($c.IPv4Address | ForEach-Object { $_.IPAddress }) -join ', ')
            $gw = (@($c.IPv4DefaultGateway | ForEach-Object { $_.NextHop }) -join ', ')
            $dns = (@($c.DNSServer | ForEach-Object { $_.ServerAddresses }) -join ', ')
            if ($gw -and -not $primaryGw) { $primaryGw = (@($c.IPv4DefaultGateway | ForEach-Object { $_.NextHop }))[0] }
            $line = "IP $ip | gateway $gw | DNS $dns"
            if ($ip -like '169.254.*') { Add-Item "Adapter $($c.InterfaceAlias)" $line 'WARN' 'Self-assigned address: no DHCP answer from the router.' }
            else { Add-Item "Adapter $($c.InterfaceAlias)" $line 'OK' }
        }
    } catch { }

    if ($primaryGw) {
        $r = Test-PingHost -Target $primaryGw -Count 4
        $line = "$primaryGw : $($r.Received)/$($r.Sent) replies, average $($r.AvgMs) ms"
        if ($r.Received -eq 0) { Add-Item 'Router (gateway) ping' $line 'WARN' 'Router did not answer (some routers block ping).' }
        elseif ($r.Received -lt $r.Sent) { Add-Item 'Router (gateway) ping' $line 'WARN' 'Packet loss to the router: weak Wi-Fi, bad cable or faulty adapter.' }
        else { Add-Item 'Router (gateway) ping' $line 'OK' }
    }
    $r = Test-PingHost -Target '1.1.1.1' -Count 4
    $line = "1.1.1.1 : $($r.Received)/$($r.Sent) replies, average $($r.AvgMs) ms"
    if ($r.Received -eq 0) { Add-Item 'Internet ping' $line 'WARN' 'No internet reply (or ping is blocked by the network).' }
    elseif ($r.Received -lt $r.Sent) { Add-Item 'Internet ping' $line 'WARN' 'Packet loss to the internet.' }
    else { Add-Item 'Internet ping' $line 'OK' }
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $a = @([System.Net.Dns]::GetHostAddresses('www.microsoft.com'))
        $sw.Stop()
        Add-Item 'DNS lookup' "www.microsoft.com -> $($a[0].IPAddressToString) ($($sw.ElapsedMilliseconds) ms)" 'OK'
    } catch { Add-Item 'DNS lookup' 'Could not resolve www.microsoft.com' 'WARN' 'Check the DNS servers and the internet connection.' }

    try {
        $raw = @(& netsh.exe wlan show interfaces 2>$null)
        $kv = @{}
        foreach ($l in $raw) { if ($l -match '^\s+([^:]+?)\s*:\s(.*)$') { $kv[$Matches[1].Trim()] = $Matches[2].Trim() } }
        if ($kv.ContainsKey('State') -and $kv['State'] -eq 'connected') {
            $sig = 0
            if ($kv['Signal'] -match '(\d+)') { $sig = [int]$Matches[1] }
            $line = "$($kv['SSID']) | signal $($kv['Signal']) | $($kv['Radio type']) | channel $($kv['Channel']) | $($kv['Receive rate (Mbps)']) Mbps"
            if ($sig -gt 0 -and $sig -lt 40) { Add-Item 'Wi-Fi' $line 'WARN' 'Weak signal. Move closer to the access point.' }
            else { Add-Item 'Wi-Fi' $line 'OK' }
        }
    } catch { }

    try {
        foreach ($s in @(Get-NetAdapterStatistics -ErrorAction Stop)) {
            $errs = [double]$s.ReceivedPacketErrors + [double]$s.OutboundPacketErrors
            if ($errs -gt 100) { Add-Item "Adapter errors: $($s.Name)" "$errs packet errors" 'WARN' 'Possible bad cable, port or driver.' }
        }
    } catch { }
}

# ---------------------------------------------------------------- 8. Devices & peripherals
Invoke-Check 'Devices and peripherals' {
    $pnp = Get-CimSafe -Class Win32_PnPEntity
    $bad = @($pnp | Where-Object { [int]$_.ConfigManagerErrorCode -notin 0, 45 })
    if ($bad.Count -eq 0) { Add-Item 'Devices with errors' 'None' 'OK' }
    foreach ($d in ($bad | Select-Object -First 15)) {
        $nm = [string]$d.Name
        if (-not $nm) { $nm = '(unnamed device)' }
        $sev = 'FAIL'
        if ([int]$d.ConfigManagerErrorCode -eq 22) { $sev = 'WARN' }
        Add-Item $nm "[$($d.PNPClass)] $(Get-DeviceProblemText $d.ConfigManagerErrorCode)" $sev 'Open Device Manager and update, enable or reinstall the driver.'
    }

    $present = @()
    try { $present = @(Get-PnpDevice -PresentOnly -ErrorAction Stop) } catch { }
    $kb = @($present | Where-Object { $_.Class -eq 'Keyboard' -and $_.FriendlyName })
    $mouse = @($present | Where-Object { $_.Class -eq 'Mouse' -and $_.FriendlyName })
    if ($kb.Count -gt 0) { Add-Item 'Keyboard' (($kb | ForEach-Object { $_.FriendlyName } | Select-Object -Unique) -join '; ') 'OK' } else { Add-Item 'Keyboard' 'Not detected' 'INFO' }
    if ($mouse.Count -gt 0) { Add-Item 'Mouse / touchpad' (($mouse | ForEach-Object { $_.FriendlyName } | Select-Object -Unique) -join '; ') 'OK' }
    elseif ($AS.IsLaptop) { Add-Item 'Mouse / touchpad' 'Not detected' 'WARN' 'Touchpad driver missing or disabled.' }
    else { Add-Item 'Mouse / touchpad' 'Not detected' 'INFO' }

    $cams = @($present | Where-Object { $_.Class -in 'Camera', 'Image' -and $_.FriendlyName -match 'camera|webcam|integrated|IR ' })
    if ($cams.Count -gt 0) { Add-Item 'Camera' (($cams | ForEach-Object { $_.FriendlyName } | Select-Object -Unique) -join '; ') 'OK' }
    else { Add-Item 'Camera' 'None detected' 'INFO' 'No problem on a desktop. On a laptop check the camera privacy switch or driver.' }

    $snd = Get-CimSafe -Class Win32_SoundDevice
    if ($snd.Count -eq 0) { Add-Item 'Audio device' 'None found' 'WARN' 'No sound hardware or driver. Install the audio driver.' }
    foreach ($s in $snd) {
        if ([int]$s.ConfigManagerErrorCode -eq 0) { Add-Item 'Audio device' $s.Name 'OK' }
        else { Add-Item 'Audio device' $s.Name 'FAIL' (Get-DeviceProblemText $s.ConfigManagerErrorCode) }
    }
    foreach ($n in 'Audiosrv', 'AudioEndpointBuilder') {
        $sv = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($sv -and $sv.Status -ne 'Running') { Add-Item "Service: $($sv.DisplayName)" ([string]$sv.Status) 'WARN' 'Start the audio services (no sound otherwise).' }
    }

    $bt = @($present | Where-Object { $_.Class -eq 'Bluetooth' -and $_.InstanceId -match '^(USB|PCI|ACPI|ROOT)\\' -and $_.FriendlyName -notmatch 'Enumerator|Service|Protocol|Transport|RFCOMM|LE Generic' })
    if ($bt.Count -gt 0) { Add-Item 'Bluetooth' ($bt[0].FriendlyName) 'OK' } else { Add-Item 'Bluetooth' 'No Bluetooth adapter detected' 'INFO' }

    $usbCtl = @($pnp | Where-Object { $_.Name -match 'USB.*(Host Controller|xHCI|eXtensible)' })
    Add-Item 'USB controllers' "$($usbCtl.Count) found"
    $usbDisks = @(Get-Disk -ErrorAction SilentlyContinue | Where-Object { $_.BusType -eq 'USB' })
    if ($usbDisks.Count -gt 0) { Add-Item 'USB storage connected' (($usbDisks | ForEach-Object { "$($_.FriendlyName) $(Format-Bytes $_.Size)" }) -join '; ') }
    $prn = Get-CimSafe -Class Win32_Printer
    if ($prn.Count -gt 0) { Add-Item 'Printers installed' (($prn | ForEach-Object { $_.Name } | Select-Object -First 6) -join '; ') }
}

# ---------------------------------------------------------------- 9. Drivers
Invoke-Check 'Drivers' {
    $drv = @(Get-CimSafe -Class Win32_PnPSignedDriver | Where-Object { $_.DeviceName })
    if ($drv.Count -eq 0) { Add-Item 'Installed drivers' 'Could not be read' 'WARN'; return }
    Add-Item 'Devices with a driver' $drv.Count
    $unsigned = @($drv | Where-Object { $_.IsSigned -eq $false })
    if ($unsigned.Count -eq 0) { Add-Item 'Unsigned drivers' 'None' 'OK' }
    else {
        Add-Item 'Unsigned drivers' "$($unsigned.Count) found" 'WARN' 'Unsigned drivers can cause crashes and are a security risk.'
        Add-Table 'Unsigned drivers' ($unsigned | Select-Object -First 15 | ForEach-Object {
            [pscustomobject]@{ Device = $_.DeviceName; Maker = $_.Manufacturer; Version = $_.DriverVersion; Class = $_.DeviceClass }
        })
    }
    $classes = 'DISPLAY', 'NET', 'MEDIA', 'BLUETOOTH', 'SCSIADAPTER', 'HDC', 'SYSTEM', 'CAMERA', 'IMAGE'
    $key = @($drv | Where-Object { $classes -contains $_.DeviceClass -and $_.Manufacturer -and $_.Manufacturer -notmatch '^\(Standard' -and $_.Manufacturer -ne 'Microsoft' })
    Add-Table 'Key drivers (display, network, audio, Bluetooth, storage, chipset)' ($key | Sort-Object DeviceClass, DeviceName | Select-Object -First 40 | ForEach-Object {
        [pscustomobject]@{ Class = $_.DeviceClass; Device = $_.DeviceName; Maker = $_.Manufacturer; Version = $_.DriverVersion; Date = (Format-When $_.DriverDate) }
    })
    $old = @($drv | Where-Object { $_.DriverDate -and $_.Manufacturer -ne 'Microsoft' -and $_.Manufacturer -notmatch '^\(Standard' -and ((Get-Date) - $_.DriverDate).TotalDays -gt 1825 })
    if ($old.Count -gt 0) {
        Add-Item 'Third-party drivers older than 5 years' "$($old.Count) found" 'INFO' 'Only update these if the device misbehaves; chipset drivers are often old but fine.'
        Add-Table 'Oldest drivers' ($old | Sort-Object DriverDate | Select-Object -First 10 | ForEach-Object {
            [pscustomobject]@{ Device = $_.DeviceName; Maker = $_.Manufacturer; Version = $_.DriverVersion; Date = (Format-When $_.DriverDate) }
        })
    } else { Add-Item 'Third-party drivers older than 5 years' 'None' 'OK' }
}

# ---------------------------------------------------------------- 10. Security & firmware
Invoke-Check 'Security and firmware' {
    # Firmware
    $fwType = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction SilentlyContinue).PEFirmwareType
    $uefi = ($fwType -eq 2)
    if ($uefi) { Add-Item 'Firmware mode' 'UEFI' 'OK' } elseif ($fwType -eq 1) { Add-Item 'Firmware mode' 'Legacy BIOS' 'INFO' 'Windows 11 needs UEFI.' } else { Add-Item 'Firmware mode' 'Unknown' 'INFO' }
    $sb = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\SecureBoot\State' -Name UEFISecureBootEnabled -ErrorAction SilentlyContinue).UEFISecureBootEnabled
    if ($sb -eq 1) { Add-Item 'Secure Boot' 'Enabled' 'OK' }
    elseif ($sb -eq 0) { Add-Item 'Secure Boot' 'Disabled' 'WARN' 'Enable Secure Boot in the UEFI settings (needed for Windows 11).' }
    else { Add-Item 'Secure Boot' 'Not supported (legacy BIOS)' 'INFO' }
    $bios = Get-CimSafe -Class Win32_BIOS | Select-Object -First 1
    if ($bios) {
        $line = "$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion) ($(Format-When $bios.ReleaseDate))"
        if ($bios.ReleaseDate -and ((Get-Date) - $bios.ReleaseDate).TotalDays -gt 1825) { Add-Item 'BIOS / UEFI version' $line 'WARN' 'Firmware is over 5 years old. Check the manufacturer site for updates.' }
        else { Add-Item 'BIOS / UEFI version' $line 'OK' }
    }

    # TPM
    $tpmOk = $false
    $tpmVer = ''
    $wtpm = Get-CimSafe -Class Win32_Tpm -Namespace 'root\cimv2\Security\MicrosoftTpm' | Select-Object -First 1
    if ($wtpm) { $tpmVer = ([string]$wtpm.SpecVersion -split ',')[0].Trim() }
    $gt = $null
    try { $gt = Get-Tpm -ErrorAction Stop } catch { }
    if ($wtpm -or ($gt -and $gt.TpmPresent)) {
        $ready = ''
        if ($gt) { $ready = " | enabled: $($gt.TpmEnabled), ready: $($gt.TpmReady)" }
        if ($tpmVer -like '2.*') { $tpmOk = $true; Add-Item 'TPM' "Present, version $tpmVer$ready" 'OK' }
        else { Add-Item 'TPM' "Present, version $tpmVer$ready" 'WARN' 'Windows 11 needs TPM 2.0.' }
    } else {
        Add-Item 'TPM' 'Not detected (or needs administrator, or disabled in firmware)' 'WARN' 'Enable TPM / fTPM / PTT in the UEFI settings. Windows 11 needs TPM 2.0.'
    }

    # BitLocker
    try {
        $bl = @(Get-BitLockerVolume -ErrorAction Stop)
        foreach ($v in $bl) {
            $line = "protection $($v.ProtectionStatus), $($v.VolumeStatus), $($v.EncryptionPercentage) % encrypted"
            if ([string]$v.ProtectionStatus -eq 'On') { Add-Item "BitLocker $($v.MountPoint)" $line 'OK' }
            else { Add-Item "BitLocker $($v.MountPoint)" $line 'INFO' 'Not encrypted. Consider BitLocker / device encryption on laptops.' }
        }
    } catch { Add-Item 'BitLocker' 'Not available (needs administrator, or this Windows edition has none)' 'INFO' }

    # Antivirus
    $avProducts = @()
    try { $avProducts = @(Get-CimInstance -Namespace 'root\SecurityCenter2' -ClassName AntiVirusProduct -ErrorAction Stop) } catch { }
    $avActive = $false
    foreach ($a in $avProducts) {
        $st = [uint32]$a.productState
        $on = (($st -band 0x1000) -ne 0)
        $stale = (($st -band 0x10) -ne 0)
        if ($on) { $avActive = $true }
        if ($on -and -not $stale) { Add-Item "Antivirus: $($a.displayName)" 'Enabled, definitions up to date' 'OK' }
        elseif ($on) { Add-Item "Antivirus: $($a.displayName)" 'Enabled, definitions OUT OF DATE' 'WARN' 'Update the antivirus definitions.' }
        else { Add-Item "Antivirus: $($a.displayName)" 'Not active' 'INFO' }
    }
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        $age = $mp.AntivirusSignatureAge
        $line = "real-time protection: $($mp.RealTimeProtectionEnabled) | signatures $age day(s) old | last quick scan $($mp.QuickScanAge) day(s) ago"
        if ($mp.RealTimeProtectionEnabled) {
            $avActive = $true
            if ($age -gt 14) { Add-Item 'Microsoft Defender' $line 'FAIL' 'Defender signatures are badly out of date. Run Windows Update.' }
            elseif ($age -gt 7) { Add-Item 'Microsoft Defender' $line 'WARN' 'Defender signatures are a week old. Run Windows Update.' }
            else { Add-Item 'Microsoft Defender' $line 'OK' }
        } else { Add-Item 'Microsoft Defender' $line 'INFO' 'Defender is passive or off (normal when another antivirus is active).' }
    } catch { }
    if (-not $avActive) { Add-Item 'Antivirus protection' 'No active antivirus found' 'FAIL' 'Turn on Windows Security or install an antivirus.' }

    # Firewall
    try {
        foreach ($p in @(Get-NetFirewallProfile -ErrorAction Stop)) {
            if ([string]$p.Enabled -eq 'True') { Add-Item "Firewall: $($p.Name)" 'On' 'OK' }
            else { Add-Item "Firewall: $($p.Name)" 'Off' 'WARN' 'Turn the firewall on unless another firewall product manages it.' }
        }
    } catch { }

    # UAC & activation
    $lua = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name EnableLUA -ErrorAction SilentlyContinue).EnableLUA
    if ($lua -eq 0) { Add-Item 'User Account Control' 'Disabled' 'WARN' 'Turn UAC back on.' } elseif ($lua -eq 1) { Add-Item 'User Account Control' 'Enabled' 'OK' }
    $lic = Get-CimSafe -Class SoftwareLicensingProduct -Filter "ApplicationId='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" | Select-Object -First 1
    if ($lic) {
        if ([int]$lic.LicenseStatus -eq 1) { Add-Item 'Windows activation' 'Activated' 'OK' }
        else { Add-Item 'Windows activation' "Not activated (status $($lic.LicenseStatus))" 'WARN' 'Activate Windows in Settings > System > Activation.' }
    }

    # Windows Update recency
    $last = $null
    $rv = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install' -Name LastSuccessTime -ErrorAction SilentlyContinue).LastSuccessTime
    if ($rv) { try { $last = [datetime]::Parse($rv).ToLocalTime() } catch { } }
    try {
        $hf = Get-HotFix -ErrorAction Stop | Where-Object { $_.InstalledOn } | Sort-Object InstalledOn -Descending | Select-Object -First 1
        if ($hf -and (-not $last -or $hf.InstalledOn -gt $last)) { $last = [datetime]$hf.InstalledOn }
    } catch { }
    if ($last) {
        $days = [int]((Get-Date) - $last).TotalDays
        $line = "$(Format-When $last) ($days days ago)"
        if ($days -gt 180) { Add-Item 'Last Windows update installed' $line 'FAIL' 'Updates are badly overdue. Run Windows Update now.' }
        elseif ($days -gt 45) { Add-Item 'Last Windows update installed' $line 'WARN' 'No update for over 6 weeks. Check Windows Update.' }
        else { Add-Item 'Last Windows update installed' $line 'OK' }
    } else { Add-Item 'Last Windows update installed' 'Could not be determined' 'INFO' }

    # Windows 11 readiness
    $os = Get-CimSafe -Class Win32_OperatingSystem | Select-Object -First 1
    $cs = Get-CimSafe -Class Win32_ComputerSystem | Select-Object -First 1
    $cpu = Get-CimSafe -Class Win32_Processor | Select-Object -First 1
    $build = 0
    if ($os) { [void][int]::TryParse([string]$os.BuildNumber, [ref]$build) }
    if ($build -ge 22000) { Add-Item 'Windows 11 readiness' 'Already running Windows 11' 'OK' }
    else {
        $rows = @()
        $fails = 0
        $ramGb = 0
        if ($cs) { $ramGb = [math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 1) }
        $cpuOk = ($cpu -and $cpu.AddressWidth -eq 64 -and $cpu.NumberOfCores -ge 2 -and $cpu.MaxClockSpeed -ge 1000)
        $sysSize = 0
        try {
            $part = Get-Partition -DriveLetter $env:SystemDrive.TrimEnd(':') -ErrorAction Stop
            $sysSize = [double](Get-Disk -Number $part.DiskNumber -ErrorAction Stop).Size
        } catch { }
        $checks = @(
            @('64-bit CPU, 2+ cores, 1 GHz+', $cpuOk),
            @('RAM 4 GB or more', ($ramGb -ge 4)),
            @('System disk 64 GB or more', ($sysSize -ge 64GB)),
            @('UEFI firmware', $uefi),
            @('Secure Boot capable (UEFI)', $uefi),
            @('TPM 2.0', $tpmOk)
        )
        foreach ($c in $checks) {
            $res = 'Pass'
            if (-not $c[1]) { $res = 'FAIL'; $fails++ }
            $rows += [pscustomobject]@{ Requirement = $c[0]; Result = $res }
        }
        Add-Table 'Windows 11 readiness (hardware requirements)' $rows
        if ($fails -eq 0) { Add-Item 'Windows 11 readiness' 'Meets the checked requirements (CPU model support list not checked)' 'INFO' 'Run Microsoft PC Health Check to confirm the CPU is on the supported list.' }
        else { Add-Item 'Windows 11 readiness' "$fails requirement(s) not met" 'INFO' 'See the readiness table. Windows 10 support has ended, so plan an upgrade or replacement.' }
    }
}

# ---------------------------------------------------------------- 11. Events & reliability
Invoke-Check 'Events and reliability' {
    $since7 = (Get-Date).AddDays(-7)
    $since30 = (Get-Date).AddDays(-30)

    foreach ($log in 'System', 'Application') {
        $ev = Get-EventsSafe -Filter @{ LogName = $log; Level = 1, 2; StartTime = $since7 } -Max 1000
        $line = "$($ev.Count) critical/error event(s) in 7 days"
        if ($ev.Count -gt 100) { Add-Item "$log log" $line 'WARN' 'Many errors. See the top sources below.' }
        else { Add-Item "$log log" $line 'INFO' }
        if ($ev.Count -gt 0) {
            Add-Table "$log log - top error sources (7 days)" ($ev | Group-Object ProviderName | Sort-Object Count -Descending | Select-Object -First 8 | ForEach-Object {
                [pscustomobject]@{ Source = $_.Name; Count = $_.Count; 'Latest' = (Format-When ($_.Group | Sort-Object TimeCreated -Descending | Select-Object -First 1).TimeCreated 'yyyy-MM-dd HH:mm') }
            })
        }
    }

    $kp = Get-EventsSafe -Filter @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 41; StartTime = $since30 } -Max 100
    if ($kp.Count -eq 0) { Add-Item 'Unexpected shutdowns (30 days)' 'None' 'OK' }
    elseif ($kp.Count -ge 3) { Add-Item 'Unexpected shutdowns (30 days)' "$($kp.Count) (latest $(Format-When $kp[0].TimeCreated 'yyyy-MM-dd HH:mm'))" 'FAIL' 'Repeated power loss/crashes: check the power supply, battery, overheating and RAM.' }
    else { Add-Item 'Unexpected shutdowns (30 days)' "$($kp.Count) (latest $(Format-When $kp[0].TimeCreated 'yyyy-MM-dd HH:mm'))" 'WARN' 'The PC lost power or crashed. Holding the power button also logs this.' }

    $bc = Get-EventsSafe -Filter @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporting'; Id = 1001; StartTime = $since30 } -Max 50
    $dumpDir = Join-Path $env:SystemRoot 'Minidump'
    $dumps = @()
    if (Test-Path -LiteralPath $dumpDir) { $dumps = @(Get-ChildItem -LiteralPath $dumpDir -Filter '*.dmp' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending) }
    if ($bc.Count -eq 0 -and $dumps.Count -eq 0) { Add-Item 'Blue screens (30 days)' 'None' 'OK' }
    else {
        $msg = ''
        if ($bc.Count -gt 0) { $msg = (([string]$bc[0].Message) -split "`r?`n")[0]; if ($msg.Length -gt 150) { $msg = $msg.Substring(0, 150) + '...' } }
        $dtxt = ''
        if ($dumps.Count -gt 0) { $dtxt = " | $($dumps.Count) dump file(s), latest $(Format-When $dumps[0].LastWriteTime)" }
        $cnt = $bc.Count
        Add-Item 'Blue screens (30 days)' "$cnt crash(es)$dtxt $msg".Trim() 'FAIL' 'Windows crashed with a stop code. Check drivers and RAM; analyze the dump with WinDbg or BlueScreenView.'
    }

    $wh = Get-EventsSafe -Filter @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WHEA-Logger'; StartTime = $since30 } -Max 100
    if ($wh.Count -eq 0) { Add-Item 'Hardware errors - WHEA (30 days)' 'None' 'OK' }
    else { Add-Item 'Hardware errors - WHEA (30 days)' "$($wh.Count) event(s), latest $(Format-When $wh[0].TimeCreated 'yyyy-MM-dd HH:mm')" 'WARN' 'The CPU/RAM/PCIe/disk reported hardware errors. Check temperatures, reseat RAM, update firmware.' }

    $crash = Get-EventsSafe -Filter @{ LogName = 'Application'; ProviderName = 'Application Error'; Id = 1000; StartTime = $since7 } -Max 300
    if ($crash.Count -eq 0) { Add-Item 'Application crashes (7 days)' 'None' 'OK' }
    else {
        $names = @()
        foreach ($e in $crash) { try { $names += [string]$e.Properties[0].Value } catch { } }
        $top = @($names | Group-Object | Sort-Object Count -Descending | Select-Object -First 6)
        if ($crash.Count -gt 15) { Add-Item 'Application crashes (7 days)' "$($crash.Count) crash(es)" 'WARN' 'Programs crash often. See the table; reinstall or update the listed programs.' }
        else { Add-Item 'Application crashes (7 days)' "$($crash.Count) crash(es)" 'INFO' }
        Add-Table 'Programs that crashed (7 days)' ($top | ForEach-Object { [pscustomobject]@{ Program = $_.Name; Crashes = $_.Count } })
    }

    $rel = Get-CimSafe -Class Win32_ReliabilityStabilityMetrics | Sort-Object StartMeasurementDate -Descending | Select-Object -First 1
    if ($rel) {
        $idx = [math]::Round([double]$rel.SystemStabilityIndex, 1)
        if ($idx -lt 4) { Add-Item 'Reliability index (1-10)' "$idx" 'WARN' 'Low stability score. Open Reliability Monitor to see what failed.' }
        else { Add-Item 'Reliability index (1-10)' "$idx" 'OK' }
    }

    $bt = Get-EventsSafe -Filter @{ LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'; Id = 100 } -Max 5
    $times = @()
    foreach ($e in $bt) {
        try {
            $x = [xml]$e.ToXml()
            $d = $x.Event.EventData.Data | Where-Object { $_.Name -eq 'BootTime' } | Select-Object -First 1
            if ($d) { $times += [double]$d.'#text' / 1000 }
        } catch { }
    }
    if ($times.Count -gt 0) {
        $avg = [math]::Round(($times | Measure-Object -Average).Average, 0)
        if ($avg -gt 120) { Add-Item 'Boot time (average of last boots)' "$avg seconds" 'WARN' 'Slow boot. Reduce startup programs; an SSD helps the most.' }
        else { Add-Item 'Boot time (average of last boots)' "$avg seconds" 'OK' }
    }
}

# ---------------------------------------------------------------- 12. Performance snapshot
Invoke-Check 'Performance snapshot' {
    $procs = @(Get-Process -ErrorAction SilentlyContinue)
    Add-Item 'Running processes' $procs.Count
    Add-Table 'Top 8 processes by memory' ($procs | Sort-Object WorkingSet64 -Descending | Select-Object -First 8 | ForEach-Object {
        [pscustomobject]@{ Process = $_.ProcessName; PID = $_.Id; Memory = (Format-Bytes $_.WorkingSet64) }
    })
    $su = Get-CimSafe -Class Win32_StartupCommand
    if ($su.Count -gt 20) { Add-Item 'Startup programs' "$($su.Count) entries" 'WARN' 'Too many programs start with Windows. Disable the ones you do not need.' }
    elseif ($su.Count -gt 0) { Add-Item 'Startup programs' "$($su.Count) entries" 'INFO' }
    if ($su.Count -gt 0) { Add-Table 'Startup programs' ($su | Select-Object -First 25 | ForEach-Object { [pscustomobject]@{ Name = $_.Name; Where = $_.Location; User = $_.User } }) }
    $svc = Get-CimSafe -Class Win32_Service -Filter "StartMode='Auto' AND State<>'Running'"
    $failed = @($svc | Where-Object { $_.ExitCode -notin 0, 1077 })
    if ($failed.Count -gt 0) {
        Add-Item 'Automatic services that failed' "$($failed.Count) service(s)" 'WARN' 'These services should be running but stopped with an error.'
        Add-Table 'Automatic services that failed' ($failed | Select-Object -First 12 | ForEach-Object { [pscustomobject]@{ Service = $_.DisplayName; Name = $_.Name; 'Exit code' = $_.ExitCode } })
    } else { Add-Item 'Automatic services that failed' 'None' 'OK' }
}

# ---------------------------------------------------------------- verdict
$counts = @{ OK = 0; WARN = 0; FAIL = 0; INFO = 0 }
foreach ($s in $AS.Sections) { foreach ($i in $s.Items) { $counts[$i.Status]++ } }
$verdict = 'Healthy'
$verdictClass = 'OK'
if ($counts.FAIL -gt 0) { $verdict = 'Problems found'; $verdictClass = 'FAIL' }
elseif ($counts.WARN -gt 0) { $verdict = 'Needs attention'; $verdictClass = 'WARN' }

function Get-SectionStatus {
    param($Section)
    $w = 'OK'
    foreach ($i in $Section.Items) {
        if ($i.Status -eq 'FAIL') { return 'FAIL' }
        if ($i.Status -eq 'WARN') { $w = 'WARN' }
    }
    return $w
}

# ---------------------------------------------------------------- HTML report
$sb = New-Object System.Text.StringBuilder
$cn = ConvertTo-Html5 $env:COMPUTERNAME
$now = Get-Date
[void]$sb.AppendLine('<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
[void]$sb.AppendLine("<title>PC Assessment - $cn</title><style>")
[void]$sb.AppendLine(@'
:root{--bg:#f3f4f6;--card:#fff;--text:#111827;--muted:#6b7280;--line:#e5e7eb;--ok:#15803d;--okbg:#dcfce7;--warn:#b45309;--warnbg:#fef3c7;--fail:#b91c1c;--failbg:#fee2e2;--info:#1d4ed8;--infobg:#dbeafe}
@media (prefers-color-scheme:dark){:root{--bg:#0f172a;--card:#1e293b;--text:#e5e7eb;--muted:#94a3b8;--line:#334155;--okbg:#14532d;--warnbg:#78350f;--failbg:#7f1d1d;--infobg:#1e3a8a;--ok:#86efac;--warn:#fcd34d;--fail:#fca5a5;--info:#93c5fd}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 "Segoe UI",system-ui,sans-serif}
main{max-width:1000px;margin:0 auto;padding:20px 16px 60px}h1{font-size:24px;margin:0 0 4px}h2{font-size:17px;margin:0 0 10px}h3{font-size:14px;margin:16px 0 6px;color:var(--muted)}
.sub{color:var(--muted);margin-bottom:16px}.card{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:16px;margin-bottom:14px}
.verdict{display:flex;gap:14px;align-items:center;flex-wrap:wrap}.vbig{font-size:22px;font-weight:700;padding:8px 16px;border-radius:8px}
.chips span{display:inline-block;margin-right:8px;padding:2px 10px;border-radius:12px;font-weight:600}
.OK{color:var(--ok);background:var(--okbg)}.WARN{color:var(--warn);background:var(--warnbg)}.FAIL{color:var(--fail);background:var(--failbg)}.INFO{color:var(--info);background:var(--infobg)}
table{border-collapse:collapse;width:100%}th,td{text-align:left;padding:6px 8px;border-bottom:1px solid var(--line);vertical-align:top}th{color:var(--muted);font-weight:600;font-size:12px;text-transform:uppercase}
td.l{width:30%;font-weight:600}.badge{display:inline-block;min-width:44px;text-align:center;padding:1px 8px;border-radius:10px;font-size:12px;font-weight:700}
.note{color:var(--muted);font-size:13px;margin-top:2px}.issue{padding:8px 0;border-bottom:1px solid var(--line)}.issue:last-child{border:0}
.tbl{overflow-x:auto}.banner{padding:10px 14px;border-radius:8px;margin-bottom:14px}.foot{color:var(--muted);font-size:12px;margin-top:20px}
@media print{body{background:#fff}.card{break-inside:avoid}}
'@)
[void]$sb.AppendLine('</style></head><body><main>')
[void]$sb.AppendLine("<h1>PC Assessment - $cn</h1>")
[void]$sb.AppendLine("<div class=`"sub`">Created $(ConvertTo-Html5 ($now.ToString('yyyy-MM-dd HH:mm'))) by $(ConvertTo-Html5 $env:USERNAME) | Assess v$ToolVersion | Administrator: $(if ($AS.IsAdmin) { 'yes' } else { 'no' })</div>")
if (-not $AS.IsAdmin) {
    [void]$sb.AppendLine('<div class="banner WARN">Not run as administrator: SMART data, BitLocker, TPM and some event-log data may be missing. Run it again as administrator for the full picture.</div>')
}

[void]$sb.AppendLine('<div class="card"><div class="verdict">')
[void]$sb.AppendLine("<div class=`"vbig $verdictClass`">$verdict</div>")
[void]$sb.AppendLine("<div class=`"chips`"><span class=`"FAIL`">$($counts.FAIL) problem(s)</span><span class=`"WARN`">$($counts.WARN) warning(s)</span><span class=`"OK`">$($counts.OK) OK</span></div>")
[void]$sb.AppendLine('</div></div>')

[void]$sb.AppendLine('<div class="card"><h2>Hardware scorecard</h2><table><tr><th>Area</th><th>Status</th><th>Issues</th></tr>')
foreach ($s in $AS.Sections) {
    $st = Get-SectionStatus $s
    $n = @($s.Items | Where-Object { $_.Status -in 'WARN', 'FAIL' }).Count
    $label = 'Good'
    if ($st -eq 'WARN') { $label = 'Attention' }
    if ($st -eq 'FAIL') { $label = 'Problem' }
    [void]$sb.AppendLine("<tr><td class=`"l`">$(ConvertTo-Html5 $s.Title)</td><td><span class=`"badge $st`">$label</span></td><td>$n</td></tr>")
}
[void]$sb.AppendLine('</table></div>')

[void]$sb.AppendLine('<div class="card"><h2>Issues and recommendations</h2>')
if ($AS.Issues.Count -eq 0) { [void]$sb.AppendLine('<div>No problems or warnings were found.</div>') }
else {
    $ordered = @($AS.Issues | Sort-Object @{ Expression = { if ($_.Status -eq 'FAIL') { 0 } else { 1 } } }, Section)
    foreach ($i in $ordered) {
        [void]$sb.AppendLine("<div class=`"issue`"><span class=`"badge $($i.Status)`">$($i.Status)</span> <b>$(ConvertTo-Html5 $i.Section)</b> - $(ConvertTo-Html5 $i.Label): $(ConvertTo-Html5 $i.Value)")
        if ($i.Note) { [void]$sb.AppendLine("<div class=`"note`">Advice: $(ConvertTo-Html5 $i.Note)</div>") }
        [void]$sb.AppendLine('</div>')
    }
}
[void]$sb.AppendLine('</div>')

foreach ($s in $AS.Sections) {
    $st = Get-SectionStatus $s
    [void]$sb.AppendLine("<div class=`"card`"><h2>$(ConvertTo-Html5 $s.Title) <span class=`"badge $st`">$st</span></h2><table>")
    foreach ($i in $s.Items) {
        $note = ''
        if ($i.Note -and $i.Status -ne 'OK') { $note = "<div class=`"note`">$(ConvertTo-Html5 $i.Note)</div>" }
        [void]$sb.AppendLine("<tr><td class=`"l`">$(ConvertTo-Html5 $i.Label)</td><td>$(ConvertTo-Html5 $i.Value)$note</td><td><span class=`"badge $($i.Status)`">$($i.Status)</span></td></tr>")
    }
    [void]$sb.AppendLine('</table>')
    foreach ($t in $s.Tables) {
        [void]$sb.AppendLine("<h3>$(ConvertTo-Html5 $t.Title)</h3><div class=`"tbl`"><table><tr>")
        $cols = @($t.Rows[0].PSObject.Properties.Name)
        foreach ($c in $cols) { [void]$sb.Append("<th>$(ConvertTo-Html5 $c)</th>") }
        [void]$sb.AppendLine('</tr>')
        foreach ($r in $t.Rows) {
            [void]$sb.Append('<tr>')
            foreach ($c in $cols) {
                $val = $r.$c
                $cls = ''
                if ($c -eq 'Result' -and "$val" -eq 'FAIL') { $cls = ' class="FAIL"' }
                [void]$sb.Append("<td$cls>$(ConvertTo-Html5 $val)</td>")
            }
            [void]$sb.AppendLine('</tr>')
        }
        [void]$sb.AppendLine('</table></div>')
    }
    [void]$sb.AppendLine('</div>')
}
$secs = [int]((Get-Date) - $started).TotalSeconds
[void]$sb.AppendLine("<div class=`"foot`">Read-only assessment finished in $secs seconds. This report contains the computer name, user name, serial number and MAC addresses - share it only with people who support this PC.</div>")
[void]$sb.AppendLine('</main></body></html>')

$dir = Resolve-OutDir -Dir $OutDir
$file = Join-Path $dir ('Assessment_{0}_{1}.html' -f $env:COMPUTERNAME, $now.ToString('yyyy-MM-dd_HHmm'))
$saved = $false
try {
    [System.IO.File]::WriteAllText($file, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
    $saved = $true
} catch {
    Write-Host "Could not save the report: $($_.Exception.Message)" -ForegroundColor Red
}

# ---------------------------------------------------------------- console summary
Write-Host ''
$vc = 'Green'
if ($verdictClass -eq 'WARN') { $vc = 'Yellow' }
if ($verdictClass -eq 'FAIL') { $vc = 'Red' }
Write-Host "=== Result: $verdict  ($($counts.FAIL) problem(s), $($counts.WARN) warning(s), $($counts.OK) OK) ===" -ForegroundColor $vc
foreach ($i in @($AS.Issues | Sort-Object @{ Expression = { if ($_.Status -eq 'FAIL') { 0 } else { 1 } } }, Section)) {
    $c = 'Yellow'
    if ($i.Status -eq 'FAIL') { $c = 'Red' }
    Write-Host ("[{0}] {1} - {2}: {3}" -f $i.Status, $i.Section, $i.Label, $i.Value) -ForegroundColor $c
    if ($i.Note) { Write-Host ("       {0}" -f $i.Note) -ForegroundColor DarkGray }
}
if ($saved) {
    Write-Host ''
    Write-Host "Report saved: $file" -ForegroundColor Cyan
    if (-not $NoOpen) { try { Start-Process -FilePath $file } catch { } }
}
if ($Pause) { Write-Host ''; Read-Host 'Press Enter to close' | Out-Null }
