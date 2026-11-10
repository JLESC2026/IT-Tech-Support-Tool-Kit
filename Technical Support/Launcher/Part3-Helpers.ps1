# Part3-Helpers.ps1 - shared helpers for the Network / Windows / Hardware modules (Part 3).
# Load it AFTER Common.ps1:
#   $root = Split-Path -Parent $PSScriptRoot
#   . (Join-Path $root 'Launcher\Common.ps1')
#   . (Join-Path $root 'Launcher\Part3-Helpers.ps1')
# Windows PowerShell 5.1 compatible (no ?: , ?. , ?? , && operators).

# ---------- Small output helpers ----------
function Write-KV {
    param([string]$Key, $Value, [int]$Width = 20)
    $v = '-'
    if ($null -ne $Value -and "$Value" -ne '') { $v = "$Value" }
    Write-Host ("{0,-$Width}: {1}" -f $Key, $v)
}

function Format-Size {
    param($Bytes)
    if ($null -eq $Bytes -or "$Bytes" -eq '') { return '-' }
    $b = [double]$Bytes
    if ($b -ge 1TB) { return ('{0:N2} TB' -f ($b / 1TB)) }
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N0} MB' -f ($b / 1MB)) }
    return ('{0:N0} KB' -f ($b / 1KB))
}

function Format-Date {
    param($Date, [string]$Format = 'yyyy-MM-dd')
    if ($null -eq $Date) { return '-' }
    try { return ([datetime]$Date).ToString($Format) } catch { return "$Date" }
}

# ---------- Running native tools (ipconfig, sfc, dism, netsh ...) ----------
# Prints the output line by line, hides the progress spam (prints every 25 %),
# removes the NUL characters sfc.exe emits, keeps the text in $script:LastNativeOutput
# and returns the exit code.
function Get-ProgressPercent {
    param([string]$Line)
    if ($Line -match '^\s*\[[=\s]*(\d+(?:\.\d+)?)%[=\s]*\]\s*$') { return [double]$Matches[1] }
    if ($Line -match '^\s*(?:Verification|Scanning)\s+(\d+)%\s+complete') { return [double]$Matches[1] }
    return $null
}

function Invoke-Native {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [switch]$Quiet
    )
    $lines = New-Object System.Collections.Generic.List[string]
    $state = @{ Last = -1 }
    & $FilePath @Arguments 2>&1 | ForEach-Object {
        $t = ([string]$_).Replace([string][char]0, '').TrimEnd()
        if ($t.Length -gt 0) {
            $show = $true
            $pct = Get-ProgressPercent $t
            if ($null -ne $pct) {
                $m = [math]::Floor($pct / 25) * 25
                if ($m -le $state.Last) { $show = $false } else { $state.Last = $m }
            }
            if ($show) {
                [void]$lines.Add($t)
                if (-not $Quiet) { Write-Host $t }
            }
        }
    }
    $code = $LASTEXITCODE
    $script:LastNativeOutput = $lines.ToArray()
    if ($null -eq $code) { $code = 0 }
    return $code
}

function Get-LastNativeText {
    if ($script:LastNativeOutput) { return ($script:LastNativeOutput -join "`n") }
    return ''
}

# ---------- Input / clipboard ----------
function Test-ValidHostName {
    param([string]$Name)
    if ([string]::IsNullOrWhiteSpace($Name)) { return $false }
    return ($Name -match '^[A-Za-z0-9][A-Za-z0-9._:\-\[\]]{0,252}$')
}

# Small input dialog. Returns the text, or $null when cancelled.
function Read-InputBox {
    param([string]$Prompt, [string]$Title = 'Input', [string]$Default = '')
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    $f = New-Object System.Windows.Forms.Form
    $f.Text = $Title
    $f.ClientSize = New-Object System.Drawing.Size(440, 130)
    $f.StartPosition = 'CenterScreen'
    $f.TopMost = $true
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox = $false
    $f.MinimizeBox = $false
    $f.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

    $l = New-Object System.Windows.Forms.Label
    $l.Text = $Prompt
    $l.Location = New-Object System.Drawing.Point(10, 10)
    $l.Size = New-Object System.Drawing.Size(420, 40)

    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point(10, 55)
    $t.Width = 420
    $t.Text = $Default

    $ok = New-Object System.Windows.Forms.Button
    $ok.Text = 'OK'
    $ok.Size = New-Object System.Drawing.Size(95, 30)
    $ok.Location = New-Object System.Drawing.Point(230, 90)
    $ok.DialogResult = 'OK'

    $cancel = New-Object System.Windows.Forms.Button
    $cancel.Text = 'Cancel'
    $cancel.Size = New-Object System.Drawing.Size(95, 30)
    $cancel.Location = New-Object System.Drawing.Point(335, 90)
    $cancel.DialogResult = 'Cancel'

    $f.Controls.AddRange(@($l, $t, $ok, $cancel))
    $f.AcceptButton = $ok
    $f.CancelButton = $cancel
    $f.Add_Shown({ $t.Focus(); $t.SelectAll() }.GetNewClosure())

    $r = $f.ShowDialog()
    $text = $t.Text.Trim()
    $f.Dispose()
    if ($r -eq 'OK') { return $text }
    return $null
}

function Copy-ToClipboard {
    param([string]$Text)
    try { Set-Clipboard -Value $Text -ErrorAction Stop; return $true } catch { }
    try { $Text | clip.exe; return ($LASTEXITCODE -eq 0) } catch { return $false }
}

# ---------- Test result lines (shared by the console modules and the Network Center window) ----------
function New-ResultLine {
    param([string]$Level, [string]$Text)
    return [pscustomobject]@{ Level = $Level; Text = $Text }
}

function Write-ResultLines {
    param($Lines)
    foreach ($l in @($Lines)) {
        switch ($l.Level) {
            'OK'    { Write-Ok $l.Text }
            'WARN'  { Write-Warn $l.Text }
            'FAIL'  { Write-Fail $l.Text }
            'HEAD'  { Write-Header $l.Text }
            default { Write-Info $l.Text }
        }
    }
}

# ---------- Wi-Fi ----------
# Parses "netsh wlan show interfaces" (English Windows labels).
function Get-WifiInterfaceInfo {
    $result = @()
    $raw = @()
    try { $raw = @(& netsh.exe wlan show interfaces 2>$null) } catch { return @() }
    $cur = $null
    foreach ($line in $raw) {
        if ($line -match '^\s+([^:]+?)\s*:\s(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim()
            if ($key -eq 'Name') {
                if ($cur) { $result += [pscustomobject]$cur }
                $cur = @{ Name = $val }
            } elseif ($cur) {
                $cur[$key] = $val
            }
        }
    }
    if ($cur) { $result += [pscustomobject]$cur }
    return $result
}

# Parses "netsh wlan show networks mode=bssid": one row per SSID (strongest signal).
function Get-WifiNearby {
    $rows = @()
    $raw = @()
    try { $raw = @(& netsh.exe wlan show networks mode=bssid 2>$null) } catch { return @() }
    $cur = $null
    foreach ($line in $raw) {
        if ($line -match '^SSID\s+\d+\s*:\s*(.*)$') {
            if ($cur) { $rows += [pscustomobject]$cur }
            $name = $Matches[1].Trim()
            if (-not $name) { $name = '(hidden)' }
            $cur = [ordered]@{ SSID = $name; Signal = 0; Authentication = ''; Channel = '' }
        } elseif ($cur) {
            if ($line -match '^\s+Authentication\s*:\s*(.+)$') { $cur.Authentication = $Matches[1].Trim() }
            elseif ($line -match '^\s+Signal\s*:\s*(\d+)%') { if ([int]$Matches[1] -gt $cur.Signal) { $cur.Signal = [int]$Matches[1] } }
            elseif ($line -match '^\s+Channel\s*:\s*(\d+)') { if (-not $cur.Channel) { $cur.Channel = $Matches[1] } }
        }
    }
    if ($cur) { $rows += [pscustomobject]$cur }
    return @($rows | Sort-Object Signal -Descending)
}

# ---------- Network summary ----------
function Get-NetworkSummary {
    param([switch]$IncludeDown)
    $rows = @()
    try {
        $wifi = @(Get-WifiInterfaceInfo)
        $adapters = @(Get-NetAdapter -ErrorAction Stop)
        $ips = @(Get-NetIPAddress -ErrorAction SilentlyContinue)
        $routes = @(Get-NetRoute -DestinationPrefix '0.0.0.0/0', '::/0' -ErrorAction SilentlyContinue |
            Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' -and $_.NextHop -ne '::' })
        $dnsAll = @(Get-DnsClientServerAddress -ErrorAction SilentlyContinue)
        $dhcpIf = @(Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue)

        foreach ($a in $adapters) {
            if ($a.Status -ne 'Up' -and -not $IncludeDown) { continue }
            $idx = [int]$a.ifIndex

            $v4 = @($ips | Where-Object { $_.InterfaceIndex -eq $idx -and $_.AddressFamily -eq 'IPv4' })
            $v6 = @($ips | Where-Object { $_.InterfaceIndex -eq $idx -and $_.AddressFamily -eq 'IPv6' })
            $v6g = @($v6 | Where-Object { $_.IPAddress -notlike 'fe80*' })
            if ($v6g.Count -eq 0) { $v6g = $v6 }
            $gw = @($routes | Where-Object { $_.InterfaceIndex -eq $idx } | ForEach-Object { [string]$_.NextHop } | Select-Object -Unique)
            $dns = @($dnsAll | Where-Object { $_.InterfaceIndex -eq $idx } | ForEach-Object { $_.ServerAddresses } | Where-Object { $_ } | Select-Object -Unique)
            $dh = @($dhcpIf | Where-Object { $_.InterfaceIndex -eq $idx } | Select-Object -First 1)
            $dhcpText = '-'
            if ($dh.Count -gt 0) { $dhcpText = [string]$dh[0].Dhcp }

            $type = 'Ethernet'
            if ($a.InterfaceDescription -match 'Hyper-V|VMware|VirtualBox|Virtual|TAP|VPN|Loopback|Tunnel') { $type = 'Virtual/VPN' }
            elseif ("$($a.PhysicalMediaType)" -match '802\.11' -or $a.InterfaceDescription -match 'Wi-?Fi|Wireless|WLAN|802\.11') { $type = 'Wi-Fi' }

            $ssid = ''
            if ($type -eq 'Wi-Fi') {
                $w = @($wifi | Where-Object { $_.Name -eq $a.Name } | Select-Object -First 1)
                if ($w.Count -gt 0 -and $w[0].State -eq 'connected') { $ssid = "$($w[0].SSID)  (signal $($w[0].Signal))" }
            }

            $v4Text = @($v4 | ForEach-Object { "$($_.IPAddress)/$($_.PrefixLength)" }) -join ', '
            $rows += [pscustomobject]@{
                Adapter     = $a.Name
                Description = $a.InterfaceDescription
                Type        = $type
                Status      = [string]$a.Status
                MAC         = $(if ($a.MacAddress) { ([string]$a.MacAddress).Replace('-', ':') } else { '' })
                IPv4        = $v4Text
                IPv6        = (@($v6g | ForEach-Object { $_.IPAddress }) -join ', ')
                Gateway     = ($gw -join ', ')
                DNS         = ($dns -join ', ')
                DHCP        = $dhcpText
                LinkSpeed   = [string]$a.LinkSpeed
                WiFi        = $ssid
                Primary     = ($gw.Count -gt 0)
                IPv4List    = @($v4 | ForEach-Object { [string]$_.IPAddress })
                GatewayList = $gw
                DnsList     = $dns
            }
        }
    } catch {
        # Fallback for very old / stripped systems: WMI
        try {
            foreach ($c in @(Get-CimInstance Win32_NetworkAdapterConfiguration -Filter 'IPEnabled=TRUE' -ErrorAction Stop)) {
                $v4l = @($c.IPAddress | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
                $v6l = @($c.IPAddress | Where-Object { $_ -match ':' })
                $rows += [pscustomobject]@{
                    Adapter = $c.Description; Description = $c.Description; Type = ''; Status = 'Up'
                    MAC = ([string]$c.MACAddress); IPv4 = ($v4l -join ', '); IPv6 = ($v6l -join ', ')
                    Gateway = (@($c.DefaultIPGateway) -join ', '); DNS = (@($c.DNSServerSearchOrder) -join ', ')
                    DHCP = $(if ($c.DHCPEnabled) { 'Enabled' } else { 'Disabled' }); LinkSpeed = ''; WiFi = ''
                    Primary = [bool]$c.DefaultIPGateway
                    IPv4List = $v4l; GatewayList = @($c.DefaultIPGateway); DnsList = @($c.DNSServerSearchOrder)
                }
            }
        } catch { }
    }
    return @($rows | Sort-Object @{ Expression = { -not $_.Primary } }, @{ Expression = { -not $_.IPv4 } })
}

function Get-PrimaryNetwork {
    $all = @(Get-NetworkSummary)
    $p = @($all | Where-Object { $_.Primary } | Select-Object -First 1)
    if ($p.Count -eq 0) { $p = @($all | Where-Object { $_.IPv4 } | Select-Object -First 1) }
    if ($p.Count -eq 0) { return $null }
    return $p[0]
}

function Get-NetworkInfoText {
    param($Adapters)
    if ($null -eq $Adapters) { $Adapters = @(Get-NetworkSummary) }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("Computer name : $env:COMPUTERNAME")
    [void]$sb.AppendLine("Username      : $env:USERNAME")
    [void]$sb.AppendLine("Date          : $(Get-Date -Format 'yyyy-MM-dd HH:mm')")
    foreach ($n in @($Adapters)) {
        [void]$sb.AppendLine('')
        $title = "$($n.Adapter) ($($n.Type))"
        if ($n.Primary) { $title += '  [primary]' }
        [void]$sb.AppendLine("--- $title ---")
        [void]$sb.AppendLine("Description   : $($n.Description)")
        [void]$sb.AppendLine("Status        : $($n.Status)   Speed: $($n.LinkSpeed)")
        [void]$sb.AppendLine("IPv4          : $($n.IPv4)")
        [void]$sb.AppendLine("IPv6          : $($n.IPv6)")
        [void]$sb.AppendLine("Gateway       : $($n.Gateway)")
        [void]$sb.AppendLine("DNS           : $($n.DNS)")
        [void]$sb.AppendLine("MAC           : $($n.MAC)")
        [void]$sb.AppendLine("DHCP          : $($n.DHCP)")
        if ($n.WiFi) { [void]$sb.AppendLine("Wi-Fi         : $($n.WiFi)") }
    }
    return $sb.ToString().TrimEnd()
}

function Write-NetworkAdapterBlock {
    param($N)
    $title = "$($N.Adapter) ($($N.Type))"
    if ($N.Primary) { $title += '  [primary]' }
    Write-Header $title
    Write-KV 'Description' $N.Description
    Write-KV 'Status' "$($N.Status)   Speed: $($N.LinkSpeed)"
    Write-KV 'IPv4' $N.IPv4
    Write-KV 'IPv6' $N.IPv6
    Write-KV 'Default gateway' $N.Gateway
    Write-KV 'DNS servers' $N.DNS
    Write-KV 'MAC address' $N.MAC
    Write-KV 'DHCP' $N.DHCP
    if ($N.WiFi) { Write-KV 'Wi-Fi' $N.WiFi }
    Write-Host ''
}

# ---------- Connectivity tests ----------
function Invoke-PingTest {
    param([string]$Target, [int]$Count = 4, [int]$TimeoutMs = 2000)
    $ping = New-Object System.Net.NetworkInformation.Ping
    $ok = 0
    $times = @()
    for ($i = 0; $i -lt $Count; $i++) {
        try {
            $r = $ping.Send($Target, $TimeoutMs)
            if ($r.Status -eq 'Success') { $ok++; $times += [int]$r.RoundtripTime }
        } catch { }
    }
    $avg = $null
    if ($times.Count -gt 0) { $avg = [int][math]::Round(($times | Measure-Object -Average).Average, 0) }
    return [pscustomobject]@{ Target = $Target; Sent = $Count; Received = $ok; Lost = ($Count - $ok); AvgMs = $avg }
}

function Add-PingLine {
    param($Lines, [string]$Label, $Result)
    # Returns the new line (caller appends it)
    if ($Result.Received -eq $Result.Sent) { return (New-ResultLine 'OK' "$Label $($Result.Target): $($Result.Received)/$($Result.Sent) replies, average $($Result.AvgMs) ms") }
    if ($Result.Received -gt 0) { return (New-ResultLine 'WARN' "$Label $($Result.Target): packet loss, $($Result.Received)/$($Result.Sent) replies, average $($Result.AvgMs) ms") }
    return (New-ResultLine 'FAIL' "$Label $($Result.Target): no reply")
}

function Invoke-GatewayTest {
    $lines = @()
    $p = Get-PrimaryNetwork
    if (-not $p) {
        $lines += New-ResultLine 'FAIL' 'No active network adapter with an IP address was found.'
        return [pscustomobject]@{ Success = $false; Lines = $lines }
    }
    $lines += New-ResultLine 'INFO' "Adapter: $($p.Adapter) ($($p.Type)) - $($p.IPv4)"
    $gw = @($p.GatewayList | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' })
    if ($gw.Count -eq 0) {
        $lines += New-ResultLine 'FAIL' 'No IPv4 default gateway is configured on this adapter (check DHCP / cable / Wi-Fi).'
        return [pscustomobject]@{ Success = $false; Lines = $lines }
    }
    $okAny = $false
    foreach ($g in $gw) {
        $r = Invoke-PingTest -Target $g
        $lines += Add-PingLine $lines 'Gateway' $r
        if ($r.Received -gt 0) { $okAny = $true }
    }
    if (-not $okAny) { $lines += New-ResultLine 'WARN' 'Some routers block ping. If the internet test works, the gateway is fine.' }
    return [pscustomobject]@{ Success = $okAny; Lines = $lines }
}

function Invoke-DnsTest {
    $lines = @()
    $names = @('www.microsoft.com', 'www.google.com')
    $resolved = 0
    foreach ($n in $names) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $addr = @([System.Net.Dns]::GetHostAddresses($n))
            $sw.Stop()
            $lines += New-ResultLine 'OK' "System resolver: $n -> $($addr[0].IPAddressToString) ($($sw.ElapsedMilliseconds) ms)"
            $resolved++
        } catch {
            $sw.Stop()
            $lines += New-ResultLine 'FAIL' "System resolver: could not resolve $n"
        }
    }
    $p = Get-PrimaryNetwork
    if ($p -and $p.DnsList.Count -gt 0) {
        $lines += New-ResultLine 'INFO' "Configured DNS servers: $($p.DNS)"
        foreach ($s in ($p.DnsList | Select-Object -First 4)) {
            try {
                $sw = [System.Diagnostics.Stopwatch]::StartNew()
                $null = Resolve-DnsName -Name 'www.microsoft.com' -Type A -Server $s -DnsOnly -QuickTimeout -ErrorAction Stop
                $sw.Stop()
                $lines += New-ResultLine 'OK' "DNS server ${s}: answered in $($sw.ElapsedMilliseconds) ms"
            } catch {
                $lines += New-ResultLine 'WARN' "DNS server ${s}: no answer"
            }
        }
    } elseif ($p) {
        $lines += New-ResultLine 'WARN' 'No DNS servers are configured on the primary adapter.'
    }
    if ($resolved -eq 0) { $lines += New-ResultLine 'INFO' 'Try: Flush DNS, then check the DNS servers above (or set 1.1.1.1 / 8.8.8.8 to compare).' }
    return [pscustomobject]@{ Success = ($resolved -gt 0); Lines = $lines }
}

function Invoke-InternetTest {
    $lines = @()
    $p = Get-PrimaryNetwork
    if (-not $p) {
        $lines += New-ResultLine 'FAIL' '1. Network connection: no active adapter with an IP address'
        $lines += New-ResultLine 'INFO' 'Diagnosis: this PC is not connected to a network (cable / Wi-Fi / adapter disabled).'
        return [pscustomobject]@{ Success = $false; Lines = $lines; Diagnosis = 'Not connected to any network' }
    }
    $lines += New-ResultLine 'OK' "1. Network connection: $($p.Adapter) ($($p.Type)) - $($p.IPv4)"
    if ($p.IPv4 -like '169.254.*') {
        $lines += New-ResultLine 'WARN' '   The address starts with 169.254 - Windows could not get an address from DHCP (use Renew IP).'
    }

    $gwOk = $false
    $gw = @($p.GatewayList | Where-Object { $_ -match '^\d+\.\d+\.\d+\.\d+$' } | Select-Object -First 1)
    if ($gw.Count -gt 0) {
        $r = Invoke-PingTest -Target $gw[0] -Count 3
        $gwOk = ($r.Received -gt 0)
        $line = Add-PingLine $lines '2. Gateway' $r
        $lines += $line
    } else {
        $lines += New-ResultLine 'WARN' '2. Gateway: none configured'
    }

    $ipOk = $false
    foreach ($t in '1.1.1.1', '8.8.8.8') {
        $r = Invoke-PingTest -Target $t -Count 3
        $lines += Add-PingLine $lines '3. Internet (by IP)' $r
        if ($r.Received -gt 0) { $ipOk = $true; break }
    }

    $dnsOk = $false
    try {
        $addr = @([System.Net.Dns]::GetHostAddresses('www.microsoft.com'))
        $dnsOk = $true
        $lines += New-ResultLine 'OK' "4. DNS: www.microsoft.com -> $($addr[0].IPAddressToString)"
    } catch {
        $lines += New-ResultLine 'FAIL' '4. DNS: could not resolve www.microsoft.com'
    }

    $webOk = $false
    try {
        $resp = Invoke-WebRequest -Uri 'http://www.msftconnecttest.com/connecttest.txt' -UseBasicParsing -TimeoutSec 8 -ErrorAction Stop
        if ("$($resp.Content)".Trim() -eq 'Microsoft Connect Test') {
            $webOk = $true
            $lines += New-ResultLine 'OK' '5. Web access: HTTP request succeeded'
        } else {
            $lines += New-ResultLine 'WARN' '5. Web access: unexpected reply (sign-in page / captive portal / proxy?)'
        }
    } catch {
        $lines += New-ResultLine 'FAIL' "5. Web access: HTTP request failed ($($_.Exception.Message))"
    }

    $diag = ''
    if ($ipOk -and $dnsOk -and $webOk) { $diag = 'Internet is working.' }
    elseif ($ipOk -and $dnsOk) { $diag = 'Internet reachable, but web requests fail - check proxy, firewall, or a Wi-Fi sign-in page.' }
    elseif ($ipOk) { $diag = 'Internet reachable by IP but DNS fails - use Flush DNS and check the DNS servers.' }
    elseif ($gwOk) { $diag = 'Router is reachable but there is no internet - modem / ISP / router uplink problem.' }
    elseif ($gw.Count -gt 0) { $diag = 'Cannot reach the router - check cable / Wi-Fi signal, then restart the adapter or renew the IP.' }
    else { $diag = 'No gateway - check DHCP (Renew IP) or the static IP settings.' }
    $level = 'FAIL'
    if ($ipOk -and $dnsOk) { $level = 'OK' }
    if ($ipOk -and $dnsOk -and -not $webOk) { $level = 'WARN' }
    $lines += New-ResultLine $level "Diagnosis: $diag"
    return [pscustomobject]@{ Success = ($ipOk -and $dnsOk); Lines = $lines; Diagnosis = $diag }
}
