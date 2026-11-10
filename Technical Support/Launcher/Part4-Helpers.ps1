# Part4-Helpers.ps1 - shared helpers for the Diagnostics / Report / Advanced / Wizard modules (Part 4).
# Load it AFTER Common.ps1 and Part3-Helpers.ps1:
#   $root = Split-Path -Parent $PSScriptRoot
#   . (Join-Path $root 'Launcher\Common.ps1')
#   . (Join-Path $root 'Launcher\Part3-Helpers.ps1')
#   . (Join-Path $root 'Launcher\Part4-Helpers.ps1')
# Windows PowerShell 5.1 compatible (no ternary, ?. , ?? , && operators). ASCII only.

# ---------- Safe value reader ----------
# Runs a script block and returns its text, or $Default when it fails / returns nothing.
function Get-SafeValue {
    param([scriptblock]$Block, [string]$Default = '-')
    try {
        $r = & $Block
        if ($null -eq $r) { return $Default }
        $t = (@($r) | ForEach-Object { [string]$_ }) -join ', '
        if ([string]::IsNullOrWhiteSpace($t)) { return $Default }
        return $t.Trim()
    } catch {
        return $Default
    }
}

# ---------- Computer information ----------
# Returns rows: Section / Label / Value (used by the Computer Information window and the reports).
function Get-ComputerInfoRows {
    $rows = New-Object System.Collections.Generic.List[object]
    function Add-InfoRow {
        param([string]$Section, [string]$Label, [string]$Value)
        $rows.Add([pscustomobject]@{ Section = $Section; Label = $Label; Value = $Value })
    }

    $os = $null; $cs = $null; $bios = $null; $cv = $null
    try { $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop } catch { }
    try { $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop } catch { }
    try { $bios = Get-CimInstance Win32_BIOS -ErrorAction Stop } catch { }
    try { $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop } catch { }

    $caption = '-'
    $build = '-'
    $ver = '-'
    if ($os) {
        $caption = [string]$os.Caption
        $b = 0
        if ([int]::TryParse([string]$os.BuildNumber, [ref]$b)) {
            if ($b -ge 22000) { $caption = $caption -replace 'Windows 10', 'Windows 11' }
        }
        $build = [string]$os.BuildNumber
        if ($cv -and $null -ne $cv.UBR) { $build = "$build.$($cv.UBR)" }
    }
    if ($cv) {
        if ($cv.DisplayVersion) { $ver = [string]$cv.DisplayVersion }
        elseif ($cv.ReleaseId) { $ver = [string]$cv.ReleaseId }
    }

    Add-InfoRow 'System' 'Computer Name' $env:COMPUTERNAME
    Add-InfoRow 'System' 'Username' $env:USERNAME
    Add-InfoRow 'System' 'Windows Edition' $caption
    Add-InfoRow 'System' 'Windows Version' $ver
    Add-InfoRow 'System' 'Windows Build' $build
    $arch = '-'
    if ($os) { $arch = [string]$os.OSArchitecture }
    Add-InfoRow 'System' 'Architecture' $arch
    Add-InfoRow 'System' 'CPU' (Get-SafeValue { (Get-CimInstance Win32_Processor -ErrorAction Stop | ForEach-Object { ([string]$_.Name).Trim() }) })
    $ram = '-'
    if ($cs) { $ram = Format-Size $cs.TotalPhysicalMemory }
    Add-InfoRow 'System' 'RAM' $ram
    Add-InfoRow 'System' 'GPU' (Get-SafeValue { (Get-CimInstance Win32_VideoController -ErrorAction Stop | ForEach-Object { $_.Name }) })
    $mf = '-'; $md = '-'
    if ($cs) { $mf = [string]$cs.Manufacturer; $md = [string]$cs.Model }
    Add-InfoRow 'System' 'Manufacturer' $mf
    Add-InfoRow 'System' 'Model' $md
    $biosText = '-'; $serial = '-'
    if ($bios) {
        $biosText = "$($bios.SMBIOSBIOSVersion)  ($(Format-Date $bios.ReleaseDate))"
        $serial = [string]$bios.SerialNumber
    }
    Add-InfoRow 'System' 'BIOS' $biosText
    Add-InfoRow 'System' 'Serial Number' $serial
    $sysDrive = '-'
    try {
        $dl = $env:SystemDrive.TrimEnd(':')
        $vol = Get-Volume -DriveLetter $dl -ErrorAction Stop
        $sysDrive = "$($env:SystemDrive)  $(Format-Size $vol.SizeRemaining) free of $(Format-Size $vol.Size)"
    } catch {
        $sysDrive = [string]$env:SystemDrive
    }
    Add-InfoRow 'System' 'System Drive' $sysDrive

    $n = $null
    try { $n = Get-PrimaryNetwork } catch { }
    if ($n) {
        Add-InfoRow 'Network' 'IPv4' $(if ($n.IPv4) { [string]$n.IPv4 } else { '-' })
        Add-InfoRow 'Network' 'IPv6' $(if ($n.IPv6) { [string]$n.IPv6 } else { '-' })
        Add-InfoRow 'Network' 'Gateway' $(if ($n.Gateway) { [string]$n.Gateway } else { '-' })
        Add-InfoRow 'Network' 'DNS' $(if ($n.DNS) { [string]$n.DNS } else { '-' })
        Add-InfoRow 'Network' 'MAC Address' $(if ($n.MAC) { [string]$n.MAC } else { '-' })
        Add-InfoRow 'Network' 'Network Adapter' "$($n.Adapter) ($($n.Type))"
    } else {
        Add-InfoRow 'Network' 'Network' 'No active network adapter found'
    }
    return $rows.ToArray()
}

function Get-ComputerInfoText {
    param($Rows)
    if ($null -eq $Rows) { $Rows = @(Get-ComputerInfoRows) }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Computer information - $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    $last = ''
    foreach ($r in @($Rows)) {
        if ($r.Section -ne $last) {
            $last = $r.Section
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("[$last]")
        }
        [void]$sb.AppendLine(("{0,-18}: {1}" -f $r.Label, $r.Value))
    }
    return $sb.ToString().TrimEnd()
}

# ---------- Event log helper ----------
# Returns recent Critical/Error (and optionally Warning) events as simple objects.
function Get-RecentEventRows {
    param([string]$LogName, [int]$Days = 7, [int]$Max = 40, [int[]]$Levels = @(1, 2))
    $rows = @()
    try {
        $ev = @(Get-WinEvent -FilterHashtable @{ LogName = $LogName; Level = $Levels; StartTime = (Get-Date).AddDays(-$Days) } -MaxEvents $Max -ErrorAction Stop)
        foreach ($e in $ev) {
            $msg = ''
            try { $msg = (([string]$e.Message) -split "`r?`n")[0] } catch { }
            if ($msg.Length -gt 160) { $msg = $msg.Substring(0, 160) + '...' }
            $rows += [pscustomobject]@{
                Time    = $e.TimeCreated.ToString('yyyy-MM-dd HH:mm')
                Level   = [string]$e.LevelDisplayName
                Source  = [string]$e.ProviderName
                EventId = [int]$e.Id
                Message = $msg
            }
        }
    } catch {
        # "No events were found" is normal; anything else is reported by the caller through an empty list
    }
    return $rows
}

# ---------- Report sections ----------
# Each Get-Report*Text function returns the full text of one report file.
function New-ReportBlock {
    param([string]$Title, [scriptblock]$Block)
    $text = ''
    try {
        $text = (& $Block 2>&1 | Out-String -Width 200).TrimEnd()
        if (-not $text) { $text = '(no data)' }
    } catch {
        $text = "(unavailable: $($_.Exception.Message))"
    }
    return ("---- {0} ----`r`n{1}`r`n`r`n" -f $Title, $text)
}

function Get-ReportHeaderText {
    param([string]$Title)
    $t = "IT Technician Toolkit - $Title`r`n"
    $t += "Computer : $env:COMPUTERNAME`r`n"
    $t += "User     : $env:USERNAME`r`n"
    $t += "Created  : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`r`n"
    $t += "Admin    : $(if (Test-IsAdmin) { 'yes' } else { 'no (some details need administrator rights)' })`r`n"
    $t += "=" * 70 + "`r`n`r`n"
    return $t
}

function Get-ReportSystemText {
    $t = Get-ReportHeaderText 'System'
    $t += New-ReportBlock 'Computer information' { Get-ComputerInfoText }
    $t += New-ReportBlock 'Operating system' {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        $up = (Get-Date) - $os.LastBootUpTime
        [pscustomobject]@{
            Install_Date = Format-Date $os.InstallDate
            Last_Boot    = Format-Date $os.LastBootUpTime 'yyyy-MM-dd HH:mm'
            Uptime       = ('{0}d {1}h {2}m' -f $up.Days, $up.Hours, $up.Minutes)
            Free_RAM     = Format-Size ($os.FreePhysicalMemory * 1KB)
            Total_RAM    = Format-Size ($os.TotalVisibleMemorySize * 1KB)
            Time_Zone    = (Get-TimeZone).Id
        } | Format-List
    }
    $t += New-ReportBlock 'Pending restart indicators' {
        $p = @()
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $p += 'Component servicing' }
        if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $p += 'Windows Update' }
        if (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue) { $p += 'Pending file rename' }
        if ($p.Count -eq 0) { 'No pending restart detected' } else { 'Restart pending: ' + ($p -join ', ') }
    }
    $t += New-ReportBlock 'Top 10 processes by memory' {
        Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 10 Name, Id, @{ n = 'Memory'; e = { Format-Size $_.WorkingSet64 } } | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Latest installed updates (15)' {
        Get-HotFix -ErrorAction Stop | Sort-Object InstalledOn -Descending | Select-Object -First 15 HotFixID, Description, InstalledOn | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Battery' {
        $b = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue)
        if ($b.Count -eq 0) { 'No battery (desktop)' } else { $b | Select-Object @{ n = 'Charge %'; e = { $_.EstimatedChargeRemaining } }, @{ n = 'Status code'; e = { $_.BatteryStatus } } | Format-Table -AutoSize }
    }
    return $t
}

function Get-ReportNetworkText {
    $t = Get-ReportHeaderText 'Network'
    $t += New-ReportBlock 'Adapter summary' { Get-NetworkInfoText }
    $t += New-ReportBlock 'Connectivity test' {
        $res = Invoke-InternetTest
        foreach ($l in @($res.Lines)) { "[{0}] {1}" -f $l.Level, $l.Text }
    }
    $t += New-ReportBlock 'ipconfig /all' { & ipconfig.exe /all }
    $t += New-ReportBlock 'route print' { & route.exe print }
    $t += New-ReportBlock 'arp -a' { & arp.exe -a }
    $t += New-ReportBlock 'Wi-Fi interface' { & netsh.exe wlan show interfaces }
    $t += New-ReportBlock 'DNS client servers' { Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.ServerAddresses } | Select-Object InterfaceAlias, ServerAddresses | Format-Table -AutoSize }
    $t += New-ReportBlock 'Firewall profiles' { Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction | Format-Table -AutoSize }
    return $t
}

function Get-ReportPrintersText {
    $t = Get-ReportHeaderText 'Printers'
    $t += New-ReportBlock 'Print services' {
        Get-Service -Name Spooler, PrintNotify -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Installed printers' {
        Get-CimInstance Win32_Printer -ErrorAction Stop | Sort-Object Name | Select-Object Name,
            @{ n = 'Default'; e = { $_.Default } },
            @{ n = 'Status'; e = { Get-PrinterStatusText $_.PrinterStatus } },
            @{ n = 'Error'; e = { Get-PrinterErrorText $_.DetectedErrorState } },
            @{ n = 'Offline'; e = { $_.WorkOffline } },
            PortName, DriverName, Shared | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Printer ports' { Get-PrinterPort -ErrorAction Stop | Select-Object Name, PrinterHostAddress, PortNumber, Description | Format-Table -AutoSize }
    $t += New-ReportBlock 'Printer drivers' { Get-PrinterDriver -ErrorAction Stop | Select-Object Name, Manufacturer, DriverVersion, PrinterEnvironment | Format-Table -AutoSize }
    $t += New-ReportBlock 'Queued print jobs' {
        $jobs = @()
        foreach ($p in @(Get-Printer -ErrorAction SilentlyContinue)) { $jobs += @(Get-PrintJob -PrinterName $p.Name -ErrorAction SilentlyContinue) }
        if ($jobs.Count -eq 0) { 'No queued jobs' } else { $jobs | Select-Object PrinterName, Id, DocumentName, UserName, JobStatus | Format-Table -AutoSize }
    }
    $t += New-ReportBlock 'Spool folder' {
        $f = @(Get-ChildItem -LiteralPath (Join-Path $env:SystemRoot 'System32\spool\PRINTERS') -Force -ErrorAction Stop)
        "$($f.Count) file(s) in the spool folder"
    }
    $t += New-ReportBlock 'Recent PrintService warnings/errors' {
        Get-WinEvent -FilterHashtable @{ LogName = 'Microsoft-Windows-PrintService/Admin'; Level = 1, 2, 3 } -MaxEvents 10 -ErrorAction Stop |
            Select-Object @{ n = 'Time'; e = { $_.TimeCreated.ToString('yyyy-MM-dd HH:mm') } }, Id, @{ n = 'Message'; e = { (([string]$_.Message) -split "`r?`n")[0] } } | Format-Table -AutoSize -Wrap
    }
    return $t
}

function Get-ReportScannersText {
    $t = Get-ReportHeaderText 'Scanners'
    $t += New-ReportBlock 'Scanner-related services' {
        Get-Service -Name stisvc, FrameServer -ErrorAction SilentlyContinue | Select-Object Name, DisplayName, Status, StartType | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Imaging devices (Device Manager)' {
        $d = @(Get-PnpDevice -Class 'Image' -ErrorAction SilentlyContinue)
        if ($d.Count -eq 0) { 'No imaging devices found' } else { $d | Select-Object FriendlyName, Status, Present, InstanceId | Format-Table -AutoSize -Wrap }
    }
    $t += New-ReportBlock 'Devices registered with WIA' {
        $mgr = New-Object -ComObject WIA.DeviceManager
        $rows = @()
        foreach ($d in $mgr.DeviceInfos) {
            $name = ''
            try { $name = [string]$d.Properties.Item('Name').Value } catch { }
            $rows += [pscustomobject]@{ Name = $name; Type = [int]$d.Type; DeviceID = [string]$d.DeviceID }
        }
        if ($rows.Count -eq 0) { 'No WIA devices registered' } else { $rows | Format-Table -AutoSize -Wrap }
    }
    $t += New-ReportBlock 'Devices with a problem code (scanner-like names)' {
        $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { $_.Name -match 'scan|imaging|wia' -and [int]$_.ConfigManagerErrorCode -ne 0 })
        if ($bad.Count -eq 0) { 'None' } else { $bad | Select-Object Name, @{ n = 'Problem'; e = { Get-DeviceProblemText $_.ConfigManagerErrorCode } } | Format-Table -AutoSize -Wrap }
    }
    return $t
}

function Get-ReportServicesText {
    $t = Get-ReportHeaderText 'Services'
    $t += New-ReportBlock 'Common services' {
        $svcRows = foreach ($c in (Get-CommonServiceList)) {
            $s = Get-Service -Name $c.Name -ErrorAction SilentlyContinue
            [pscustomobject]@{
                Group   = $c.Group
                Service = $c.Label
                Name    = $c.Name
                Status  = $(if ($s) { [string]$s.Status } else { 'Not installed' })
                Startup = $(if ($s) { [string]$s.StartType } else { '-' })
            }
        }
        $svcRows | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Automatic services that are NOT running' {
        $x = @(Get-CimInstance Win32_Service -Filter "StartMode='Auto' AND State<>'Running'" -ErrorAction Stop | Sort-Object DisplayName)
        if ($x.Count -eq 0) { 'None' } else { $x | Select-Object Name, DisplayName, State, ExitCode | Format-Table -AutoSize }
    }
    $t += New-ReportBlock 'All services' {
        Get-Service | Sort-Object DisplayName | Select-Object Status, StartType, Name, DisplayName | Format-Table -AutoSize
    }
    return $t
}

function Get-ReportDriversText {
    $t = Get-ReportHeaderText 'Drivers'
    $t += New-ReportBlock 'Devices with problems' {
        $bad = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop | Where-Object { [int]$_.ConfigManagerErrorCode -notin 0, 45 })
        if ($bad.Count -eq 0) { 'None' } else { $bad | Select-Object Name, @{ n = 'Problem'; e = { Get-DeviceProblemText $_.ConfigManagerErrorCode } } | Format-Table -AutoSize -Wrap }
    }
    $t += New-ReportBlock 'Installed drivers' {
        Get-CimInstance Win32_PnPSignedDriver -ErrorAction Stop | Where-Object { $_.DeviceName } | Sort-Object DeviceClass, DeviceName |
            Select-Object @{ n = 'Class'; e = { $_.DeviceClass } }, @{ n = 'Device'; e = { $_.DeviceName } }, Manufacturer, DriverVersion,
                @{ n = 'Date'; e = { Format-Date $_.DriverDate } }, IsSigned | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'USB devices' {
        Get-PnpDevice -Class USB -PresentOnly -ErrorAction Stop | Select-Object FriendlyName, Status | Format-Table -AutoSize
    }
    return $t
}

function Get-ReportDisksText {
    $t = Get-ReportHeaderText 'Disks'
    $t += New-ReportBlock 'Physical disks' {
        Get-PhysicalDisk -ErrorAction Stop | Sort-Object DeviceId | Select-Object FriendlyName, MediaType, BusType, @{ n = 'Size'; e = { Format-Size $_.Size } }, HealthStatus, @{ n = 'Status'; e = { (@($_.OperationalStatus) | ForEach-Object { [string]$_ }) -join '/' } } | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Disks' {
        Get-Disk -ErrorAction Stop | Sort-Object Number | Select-Object Number, FriendlyName, @{ n = 'Size'; e = { Format-Size $_.Size } }, PartitionStyle, IsOffline, IsReadOnly | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Volumes' {
        Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter } | Sort-Object DriveLetter | Select-Object DriveLetter, FileSystemLabel, FileSystem,
            @{ n = 'Size'; e = { Format-Size $_.Size } }, @{ n = 'Free'; e = { Format-Size $_.SizeRemaining } },
            @{ n = 'Free %'; e = { if ($_.Size) { [math]::Round(($_.SizeRemaining / $_.Size) * 100, 1) } else { '-' } } }, HealthStatus | Format-Table -AutoSize
    }
    $t += New-ReportBlock 'Reliability counters (temperature / wear / errors)' {
        $out = @(Get-PhysicalDisk -ErrorAction Stop | ForEach-Object {
            $c = $_ | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
            if ($c) { [pscustomobject]@{ Disk = $_.FriendlyName; 'Temp C' = $c.Temperature; 'Wear %' = $c.Wear; 'Power-on h' = $c.PowerOnHours; 'Read errors' = $c.ReadErrorsTotal; 'Write errors' = $c.WriteErrorsTotal } }
        })
        if ($out.Count -eq 0) { 'Not available (needs administrator rights or the drive does not report it)' } else { $out | Format-Table -AutoSize }
    }
    $t += New-ReportBlock 'SMART failure prediction (needs administrator)' {
        Get-CimInstance -Namespace root\wmi -ClassName MSStorageDriver_FailurePredictStatus -ErrorAction Stop | Select-Object InstanceName, PredictFailure | Format-Table -AutoSize
    }
    return $t
}

function Get-ReportEventLogsText {
    param([int]$Days = 7)
    $t = Get-ReportHeaderText "Event logs (last $Days days, Critical + Error)"
    foreach ($log in 'System', 'Application') {
        $name = $log
        $t += New-ReportBlock "$name log - Critical/Error (max 50)" {
            $r = @(Get-RecentEventRows -LogName $name -Days $Days -Max 50)
            if ($r.Count -eq 0) { 'No critical or error events found' } else { $r | Format-Table -AutoSize -Wrap }
        }
    }
    $t += New-ReportBlock 'Event count by source (System + Application, Error/Critical)' {
        $all = @()
        foreach ($log in 'System', 'Application') { $all += @(Get-RecentEventRows -LogName $log -Days $Days -Max 500) }
        if ($all.Count -eq 0) { 'None' } else { $all | Group-Object Source | Sort-Object Count -Descending | Select-Object -First 15 Count, Name | Format-Table -AutoSize }
    }
    return $t
}

# ---------- Report folder ----------
function New-ReportFolder {
    $root = Get-ToolkitRoot
    $name = '{0}_{1}' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyy-MM-dd_HHmm')
    $dir = Join-Path (Join-Path $root 'Reports') $name
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    return $dir
}

function Save-ReportFile {
    param([string]$Folder, [string]$Name, [string]$Text)
    $path = Join-Path $Folder $Name
    [System.IO.File]::WriteAllText($path, $Text, (New-Object System.Text.UTF8Encoding($true)))
    return $path
}
