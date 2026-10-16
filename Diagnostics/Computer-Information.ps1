# Computer Information - one window with the key facts about this PC and a Copy All button.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
. (Join-Path $root 'Launcher\Part4-Helpers.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:rows = @()

$form = New-Object System.Windows.Forms.Form
$form.Text = 'Computer Information'
$form.ClientSize = New-Object System.Drawing.Size(760, 620)
$form.MinimumSize = New-Object System.Drawing.Size(640, 480)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9.5)
$form.BackColor = [System.Drawing.Color]::FromArgb(243, 244, 246)

$grid = New-Object System.Windows.Forms.DataGridView
$grid.Dock = 'Fill'
$grid.ReadOnly = $true
$grid.AllowUserToAddRows = $false
$grid.AllowUserToDeleteRows = $false
$grid.AllowUserToResizeRows = $false
$grid.RowHeadersVisible = $false
$grid.ColumnHeadersVisible = $false
$grid.SelectionMode = 'FullRowSelect'
$grid.BackgroundColor = [System.Drawing.Color]::White
$grid.BorderStyle = 'None'
$grid.CellBorderStyle = 'SingleHorizontal'
$grid.AutoSizeRowsMode = 'AllCells'
$c1 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$c1.Width = 190
$c2 = New-Object System.Windows.Forms.DataGridViewTextBoxColumn
$c2.AutoSizeMode = 'Fill'
$c2.DefaultCellStyle.WrapMode = 'True'
[void]$grid.Columns.Add($c1)
[void]$grid.Columns.Add($c2)

$panel = New-Object System.Windows.Forms.FlowLayoutPanel
$panel.Dock = 'Bottom'
$panel.Height = 54
$panel.Padding = New-Object System.Windows.Forms.Padding(10, 10, 10, 0)

function New-Btn([string]$Text, [int]$Width = 170) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size($Width, 34)
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    return $b
}
$btnCopy = New-Btn 'Copy All Information' 190
$btnSave = New-Btn 'Save to Reports folder' 190
$btnRefresh = New-Btn 'Refresh' 100
$status = New-Object System.Windows.Forms.Label
$status.AutoSize = $true
$status.Margin = New-Object System.Windows.Forms.Padding(8, 9, 0, 0)
$status.ForeColor = [System.Drawing.Color]::FromArgb(107, 114, 128)
$panel.Controls.AddRange(@($btnCopy, $btnSave, $btnRefresh, $status))

$form.Controls.Add($grid)
$form.Controls.Add($panel)

function Update-Info {
    $status.Text = 'Reading information...'
    $form.UseWaitCursor = $true
    [System.Windows.Forms.Application]::DoEvents()
    $script:rows = @(Get-ComputerInfoRows)
    $grid.Rows.Clear()
    $last = ''
    foreach ($r in $script:rows) {
        if ($r.Section -ne $last) {
            $last = $r.Section
            $i = $grid.Rows.Add($last.ToUpper(), '')
            $grid.Rows[$i].DefaultCellStyle.BackColor = [System.Drawing.Color]::FromArgb(219, 234, 254)
            $grid.Rows[$i].DefaultCellStyle.Font = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
        }
        [void]$grid.Rows.Add([string]$r.Label, [string]$r.Value)
    }
    $grid.ClearSelection()
    $form.UseWaitCursor = $false
    $status.Text = 'Ready'
}

$btnCopy.Add_Click({
    $text = Get-ComputerInfoText -Rows $script:rows
    if (Copy-ToClipboard $text) {
        $status.Text = 'All information copied to the clipboard'
        Write-Log -Action 'Computer Information - Copy All' -Result 'SUCCESS'
    } else {
        $status.Text = 'Could not access the clipboard'
        Write-Log -Action 'Computer Information - Copy All' -Result 'FAILED'
    }
})
$btnSave.Add_Click({
    try {
        $dir = Join-Path $root 'Reports'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $file = Join-Path $dir ('ComputerInfo_{0}_{1}.txt' -f $env:COMPUTERNAME, (Get-Date -Format 'yyyy-MM-dd_HHmm'))
        [System.IO.File]::WriteAllText($file, (Get-ComputerInfoText -Rows $script:rows), (New-Object System.Text.UTF8Encoding($true)))
        $status.Text = "Saved: $file"
        Write-Log -Action 'Computer Information - Save' -Result 'SUCCESS' -Detail $file
    } catch {
        $status.Text = "Could not save: $($_.Exception.Message)"
    }
})
$btnRefresh.Add_Click({ Update-Info })
$form.Add_Shown({ Update-Info })

[void]$form.ShowDialog()
Write-Log -Action 'Computer Information - opened' -Result 'SUCCESS'
