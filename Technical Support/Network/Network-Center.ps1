# Network Center - live network information with Copy buttons and quick tests.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:adapters = @()

function Add-Output {
    param([string]$Text, [string]$Level = 'INFO')
    $color = [System.Drawing.Color]::Black
    switch ($Level) {
        'OK'   { $color = [System.Drawing.Color]::FromArgb(22, 128, 61) }
        'WARN' { $color = [System.Drawing.Color]::FromArgb(180, 83, 9) }
        'FAIL' { $color = [System.Drawing.Color]::FromArgb(185, 28, 28) }
        'HEAD' { $color = [System.Drawing.Color]::FromArgb(3, 105, 161) }
    }
    $script:txtOut.SelectionStart = $script:txtOut.TextLength
    $script:txtOut.SelectionLength = 0
    $script:txtOut.SelectionColor = $color
    $script:txtOut.AppendText($Text + "`r`n")
    $script:txtOut.SelectionColor = $script:txtOut.ForeColor
    $script:txtOut.ScrollToCaret()
}

function Add-ResultOutput {
    param($Lines)
    foreach ($l in @($Lines)) { Add-Output -Text ("[{0}] {1}" -f $l.Level, $l.Text) -Level $l.Level }
}

function Get-SelectedAdapter {
    $i = $script:cmbAdapter.SelectedIndex
    if ($i -ge 0 -and $i -lt $script:adapters.Count) { return $script:adapters[$i] }
    return $null
}

function Update-Grid {
    $n = Get-SelectedAdapter
    $script:grid.Rows.Clear()
    $rows = @(
        @('Computer name', $env:COMPUTERNAME),
        @('Username', $env:USERNAME)
    )
    if ($n) {
        $rows += , @('Adapter', "$($n.Adapter)  ($($n.Type))")
        $rows += , @('Description', $n.Description)
        $rows += , @('Status / speed', "$($n.Status)  $($n.LinkSpeed)")
        if ($n.WiFi) { $rows += , @('Wi-Fi', $n.WiFi) }
        $rows += , @('IPv4 address', $n.IPv4)
        $rows += , @('IPv6', $n.IPv6)
        $rows += , @('Default gateway', $n.Gateway)
        $rows += , @('DNS servers', $n.DNS)
        $rows += , @('MAC address', $n.MAC)
        $rows += , @('DHCP', $n.DHCP)
    } else {
        $rows += , @('Network', 'No active network adapter found')
    }
    foreach ($r in $rows) { [void]$script:grid.Rows.Add([string]$r[0], [string]$r[1]) }
}

function Update-Adapters {
    $script:form.UseWaitCursor = $true
    [System.Windows.Forms.Application]::DoEvents()
    $script:adapters = @(Get-NetworkSummary)
    $script:cmbAdapter.Items.Clear()
    foreach ($a in $script:adapters) {
        $label = "$($a.Adapter)  -  $($a.IPv4)"
        if ($a.Primary) { $label += '   [primary]' }
        [void]$script:cmbAdapter.Items.Add($label)
    }
    if ($script:cmbAdapter.Items.Count -gt 0) { $script:cmbAdapter.SelectedIndex = 0 }
    Update-Grid
    $script:form.UseWaitCursor = $false
}

function Copy-Value {
    param([string]$Text, [string]$What)
    if (-not $Text) { Add-Output "Nothing to copy ($What is empty)." 'WARN'; return }
    if (Copy-ToClipboard $Text) { Add-Output "Copied $What to the clipboard: $Text" 'OK' }
    else { Add-Output "Could not use the clipboard. $What = $Text" 'FAIL' }
}

function Invoke-TestButton {
    param([string]$Title, [scriptblock]$Test)
    $script:form.UseWaitCursor = $true
    Add-Output ''
    Add-Output "--- $Title  [$(Get-Date -Format 'HH:mm:ss')] ---" 'HEAD'
    [System.Windows.Forms.Application]::DoEvents()
    try {
        $res = & $Test
        Add-ResultOutput $res.Lines
        Write-Log -Action "$Title (Network Center)" -Result $(if ($res.Success) { 'SUCCESS' } else { 'FAILED' })
    } catch {
        Add-Output $_.Exception.Message 'FAIL'
    }
    $script:form.UseWaitCursor = $false
}

# ---------- Window ----------
$script:form = New-Object System.Windows.Forms.Form
$form.Text = 'Network Center'
$form.ClientSize = New-Object System.Drawing.Size(960, 680)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$top = New-Object System.Windows.Forms.Panel
$top.Dock = 'Top'
$top.Height = 44
$lbl = New-Object System.Windows.Forms.Label
$lbl.Text = 'Adapter:'
$lbl.AutoSize = $true
$lbl.Location = New-Object System.Drawing.Point(12, 14)
$script:cmbAdapter = New-Object System.Windows.Forms.ComboBox
$cmbAdapter.DropDownStyle = 'DropDownList'
$cmbAdapter.Location = New-Object System.Drawing.Point(78, 10)
$cmbAdapter.Width = 520

$script:grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Top'
$grid.Height = 300
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.RowHeadersVisible = $false
$grid.ColumnHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.AutoSizeColumnsMode = 'Fill'
[void]$grid.Columns.Add('Property', 'Property')
[void]$grid.Columns.Add('Value', 'Value')
$grid.Columns[0].FillWeight = 22
$grid.Columns[1].FillWeight = 78
$grid.Columns[0].DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI Semibold', 9.5)

$bar = New-Object System.Windows.Forms.FlowLayoutPanel
$bar.Dock = 'Top'
$bar.Height = 84
$bar.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 0)

function New-Btn([string]$Text) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size(140, 32)
    $b.Margin = New-Object System.Windows.Forms.Padding(4)
    return $b
}
$btnRefresh = New-Btn 'Refresh'
$btnIP      = New-Btn 'Copy IP'
$btnMac     = New-Btn 'Copy MAC'
$btnAll     = New-Btn 'Copy ALL info'
$btnInet    = New-Btn 'Test internet'
$btnGw      = New-Btn 'Test gateway'
$btnDns     = New-Btn 'Test DNS'
$btnAd      = New-Btn 'Show adapters'
$btnWifi    = New-Btn 'Show Wi-Fi info'
$bar.Controls.AddRange(@($btnRefresh, $btnIP, $btnMac, $btnAll, $btnInet, $btnGw, $btnDns, $btnAd, $btnWifi))

$script:txtOut = New-Object System.Windows.Forms.RichTextBox
$txtOut.Dock = 'Fill'
$txtOut.ReadOnly = $true
$txtOut.BackColor = [System.Drawing.Color]::White
$txtOut.Font = New-Object System.Drawing.Font('Consolas', 9.5)

$top.Controls.AddRange(@($lbl, $cmbAdapter))
# Add in reverse dock order so Fill ends up in the remaining space
$form.Controls.Add($txtOut)
$form.Controls.Add($bar)
$form.Controls.Add($grid)
$form.Controls.Add($top)

$cmbAdapter.Add_SelectedIndexChanged({ Update-Grid })
$btnRefresh.Add_Click({ Update-Adapters; Add-Output 'Refreshed.' })
$btnIP.Add_Click({ $n = Get-SelectedAdapter; $v = ''; if ($n -and $n.IPv4List.Count -gt 0) { $v = [string]$n.IPv4List[0] }; Copy-Value $v 'IP address' })
$btnMac.Add_Click({ $n = Get-SelectedAdapter; $v = ''; if ($n) { $v = $n.MAC }; Copy-Value $v 'MAC address' })
$btnAll.Add_Click({ Copy-Value (Get-NetworkInfoText -Adapters $script:adapters) 'complete network information' })
$btnInet.Add_Click({ Invoke-TestButton 'Test internet connection' { Invoke-InternetTest } })
$btnGw.Add_Click({ Invoke-TestButton 'Test gateway' { Invoke-GatewayTest } })
$btnDns.Add_Click({ Invoke-TestButton 'Test DNS' { Invoke-DnsTest } })
$btnAd.Add_Click({
    Add-Output ''
    Add-Output '--- Network adapters ---' 'HEAD'
    $t = (Get-NetworkSummary -IncludeDown | Format-Table Adapter, Type, Status, MAC, IPv4, LinkSpeed -AutoSize | Out-String -Width 200).TrimEnd()
    Add-Output $t
})
$btnWifi.Add_Click({
    Add-Output ''
    Add-Output '--- Wi-Fi ---' 'HEAD'
    $w = @(Get-WifiInterfaceInfo)
    if ($w.Count -eq 0) { Add-Output 'No Wi-Fi interface reported (no adapter, Wi-Fi off, or WLAN service stopped).' 'WARN' }
    foreach ($i in $w) {
        $t = ($i | Format-List Name, State, SSID, BSSID, Signal, 'Radio type', Channel, Authentication, 'Receive rate (Mbps)', 'Transmit rate (Mbps)' | Out-String -Width 200).TrimEnd()
        Add-Output $t
    }
})

Update-Adapters
Add-Output 'Ready. Select an adapter above, then use the buttons.'
[void]$form.ShowDialog()
