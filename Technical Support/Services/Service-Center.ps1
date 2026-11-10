# Service Center - friendly window for searching and controlling Windows services.
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:isAdmin = Test-IsAdmin
$script:common = Get-CommonServiceList

function Get-ServiceRows {
    $view = $script:cmbView.SelectedItem
    $q = $script:txtFilter.Text.Trim()
    $rows = @()
    if ($view -eq 'Common services') {
        foreach ($c in $script:common) {
            $s = Get-Service -Name $c.Name -ErrorAction SilentlyContinue
            $rows += [pscustomobject]@{
                Group       = $c.Group
                Name        = $c.Name
                DisplayName = $c.Label
                Status      = $(if ($s) { [string]$s.Status } else { 'Not installed' })
                Startup     = $(if ($s) { [string]$s.StartType } else { '-' })
            }
        }
    } else {
        $all = Get-Service | Sort-Object DisplayName
        if ($view -eq 'Running only') { $all = $all | Where-Object { $_.Status -eq 'Running' } }
        if ($view -eq 'Stopped only') { $all = $all | Where-Object { $_.Status -eq 'Stopped' } }
        foreach ($s in $all) {
            $rows += [pscustomobject]@{
                Group       = ''
                Name        = $s.Name
                DisplayName = $s.DisplayName
                Status      = [string]$s.Status
                Startup     = [string]$s.StartType
            }
        }
    }
    if ($q) {
        $rows = @($rows | Where-Object { $_.Name -like "*$q*" -or $_.DisplayName -like "*$q*" })
    }
    return $rows
}

function Update-Grid {
    $script:form.UseWaitCursor = $true
    $rows = @(Get-ServiceRows)
    $script:grid.DataSource = $null
    $script:grid.DataSource = [System.Collections.ArrayList]$rows
    $script:lblInfo.Text = "$($rows.Count) service(s) shown"
    $script:form.UseWaitCursor = $false
}

function Invoke-SelectedService {
    param([string]$Mode)
    if ($script:grid.SelectedRows.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show('Select a service in the list first.', 'Service Center') | Out-Null
        return
    }
    if (-not $script:isAdmin) {
        [System.Windows.Forms.MessageBox]::Show('Controlling services needs administrator rights.' + "`n`n" + 'Close this window and start the toolkit with START-AsAdmin.bat.', 'Administrator required', 'OK', 'Warning') | Out-Null
        return
    }
    $name = [string]$script:grid.SelectedRows[0].Cells['Name'].Value
    $label = [string]$script:grid.SelectedRows[0].Cells['DisplayName'].Value
    if ($Mode -eq 'Stop') {
        $r = [System.Windows.Forms.MessageBox]::Show("Stop '$label'? Other services that depend on it will stop too.", 'Confirm', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    $script:form.UseWaitCursor = $true
    $script:lblInfo.Text = "$Mode $label ..."
    [System.Windows.Forms.Application]::DoEvents()
    $res = $null
    try {
        # Output of the helper goes to the (hidden) console; the result is what we use
        $res = Restart-ServiceByName -Name $name -Label $label -Mode $Mode 6>$null
    } catch { $res = $false }
    $ok = ($res -eq $true)
    Write-Log -Action "$Mode service: $label" -Result $(if ($ok) { 'SUCCESS' } else { 'FAILED' })
    Update-Grid
    $script:lblInfo.Text = $(if ($ok) { "$Mode OK: $label" } else { "$Mode FAILED: $label (see Services.msc or the Event Viewer)" })
}

$script:form = New-Object System.Windows.Forms.Form
$form.Text = 'Service Center'
$form.ClientSize = New-Object System.Drawing.Size(980, 600)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)

$top = New-Object System.Windows.Forms.Panel
$top.Dock = 'Top'
$top.Height = 46

$lbl1 = New-Object System.Windows.Forms.Label
$lbl1.Text = 'Search:'
$lbl1.AutoSize = $true
$lbl1.Location = New-Object System.Drawing.Point(12, 14)
$script:txtFilter = New-Object System.Windows.Forms.TextBox
$txtFilter.Location = New-Object System.Drawing.Point(68, 11)
$txtFilter.Width = 260
$lbl2 = New-Object System.Windows.Forms.Label
$lbl2.Text = 'Show:'
$lbl2.AutoSize = $true
$lbl2.Location = New-Object System.Drawing.Point(346, 14)
$script:cmbView = New-Object System.Windows.Forms.ComboBox
$cmbView.DropDownStyle = 'DropDownList'
$cmbView.Location = New-Object System.Drawing.Point(392, 11)
$cmbView.Width = 170
[void]$cmbView.Items.AddRange(@('Common services', 'All services', 'Running only', 'Stopped only'))
$cmbView.SelectedIndex = 0
$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = 'Refresh'
$btnRefresh.Location = New-Object System.Drawing.Point(580, 9)
$btnRefresh.Size = New-Object System.Drawing.Size(90, 28)
$top.Controls.AddRange(@($lbl1, $txtFilter, $lbl2, $cmbView, $btnRefresh))

$script:grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.MultiSelect = $false
$grid.AutoSizeColumnsMode = 'Fill'
$grid.RowHeadersVisible = $false
$grid.BackgroundColor = [System.Drawing.Color]::White

$bottom = New-Object System.Windows.Forms.Panel
$bottom.Dock = 'Bottom'
$bottom.Height = 56

function New-ActionButton([string]$Text, [int]$X) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size(110, 32)
    $b.Location = New-Object System.Drawing.Point($X, 12)
    return $b
}
$btnStart   = New-ActionButton 'Start' 12
$btnStop    = New-ActionButton 'Stop' 130
$btnRestart = New-ActionButton 'Restart' 248
$btnMsc     = New-ActionButton 'Services.msc' 366
$script:lblInfo = New-Object System.Windows.Forms.Label
$lblInfo.AutoSize = $true
$lblInfo.Location = New-Object System.Drawing.Point(500, 20)
$bottom.Controls.AddRange(@($btnStart, $btnStop, $btnRestart, $btnMsc, $lblInfo))

$form.Controls.Add($grid)
$form.Controls.Add($top)
$form.Controls.Add($bottom)

$txtFilter.Add_TextChanged({ Update-Grid })
$cmbView.Add_SelectedIndexChanged({ Update-Grid })
$btnRefresh.Add_Click({ Update-Grid })
$btnStart.Add_Click({ Invoke-SelectedService 'Start' })
$btnStop.Add_Click({ Invoke-SelectedService 'Stop' })
$btnRestart.Add_Click({ Invoke-SelectedService 'Restart' })
$btnMsc.Add_Click({ Start-Process services.msc })

if (-not $script:isAdmin) {
    $form.Text = 'Service Center  (read-only: not running as administrator)'
}
Update-Grid
[void]$form.ShowDialog()
