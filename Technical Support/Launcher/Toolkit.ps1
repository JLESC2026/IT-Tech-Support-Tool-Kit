# Toolkit.ps1 - IT Technician Toolkit launcher (Windows PowerShell 5.1 + WinForms)
# Start it with START.bat or START-AsAdmin.bat.
# Menu entries come from Config\shortcuts.json - add a module by adding an entry there.

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

try {
    . (Join-Path $PSScriptRoot 'Common.ps1')

    $script:Root     = Get-ToolkitRoot
    $script:Settings = Get-ToolkitSettings
    $script:IsAdmin  = Test-IsAdmin
    $script:Busy     = $false
    $script:CurrentCat = $null

    $cfgPath = Join-Path $script:Root 'Config\shortcuts.json'
    if (-not (Test-Path $cfgPath)) { throw 'Config\shortcuts.json is missing.' }
    $script:Config = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json

    # Child scripts inherit these
    $env:TOOLKIT_LAUNCHER = '1'
    $env:TOOLKIT_LOG = $(if ($script:Settings.loggingEnabled) { '1' } else { '0' })

    # ---------- Colours / fonts ----------
    $cDark    = [System.Drawing.Color]::FromArgb(17, 24, 39)
    $cSide    = [System.Drawing.Color]::FromArgb(31, 41, 55)
    $cSideSel = [System.Drawing.Color]::FromArgb(37, 99, 235)
    $cBg      = [System.Drawing.Color]::FromArgb(243, 244, 246)
    $cCard    = [System.Drawing.Color]::White
    $cText    = [System.Drawing.Color]::FromArgb(17, 24, 39)
    $cMuted   = [System.Drawing.Color]::FromArgb(107, 114, 128)
    $fontUI   = New-Object System.Drawing.Font('Segoe UI', 9.5)
    $fontBold = New-Object System.Drawing.Font('Segoe UI', 9.5, [System.Drawing.FontStyle]::Bold)
    $fontBig  = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
    $fontHead = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
    $fontMono = New-Object System.Drawing.Font('Consolas', 9.5)

    # ---------- Form ----------
    $script:form = New-Object System.Windows.Forms.Form
    $form.Text = $script:Settings.toolkitName
    $form.ClientSize = New-Object System.Drawing.Size(1180, 740)
    $form.MinimumSize = New-Object System.Drawing.Size(1000, 640)
    $form.StartPosition = 'CenterScreen'
    $form.Font = $fontUI
    $form.BackColor = $cBg

    $script:tip = New-Object System.Windows.Forms.ToolTip
    $tip.InitialDelay = 300

    # Content (fill)
    $script:flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'
    $flow.AutoScroll = $true
    $flow.Padding = New-Object System.Windows.Forms.Padding(14)
    $flow.BackColor = $cBg

    # Bottom: output pane
    $bottom = New-Object System.Windows.Forms.Panel
    $bottom.Dock = 'Bottom'
    $bottom.Height = 250
    $bottom.BackColor = $cDark

    $script:out = New-Object System.Windows.Forms.RichTextBox
    $out.Dock = 'Fill'
    $out.ReadOnly = $true
    $out.BackColor = $cDark
    $out.ForeColor = [System.Drawing.Color]::FromArgb(209, 213, 219)
    $out.Font = $fontMono
    $out.BorderStyle = 'None'

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock = 'Top'
    $bar.Height = 38
    $bar.BackColor = $cSide
    $bar.Padding = New-Object System.Windows.Forms.Padding(8, 5, 8, 0)

    function New-BarButton([string]$Text) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $Text
        $b.FlatStyle = 'Flat'
        $b.ForeColor = [System.Drawing.Color]::White
        $b.BackColor = [System.Drawing.Color]::FromArgb(55, 65, 81)
        $b.FlatAppearance.BorderSize = 0
        $b.AutoSize = $true
        $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
        return $b
    }
    $btnCopy  = New-BarButton 'Copy output'
    $btnClear = New-BarButton 'Clear'
    $btnLogs  = New-BarButton 'Open Logs'
    $btnRep   = New-BarButton 'Open Reports'
    $chkLog = New-Object System.Windows.Forms.CheckBox
    $chkLog.Text = 'Log actions'
    $chkLog.ForeColor = [System.Drawing.Color]::White
    $chkLog.AutoSize = $true
    $chkLog.Checked = [bool]$script:Settings.loggingEnabled
    $chkLog.Margin = New-Object System.Windows.Forms.Padding(8, 4, 8, 0)
    $script:status = New-Object System.Windows.Forms.Label
    $status.ForeColor = [System.Drawing.Color]::FromArgb(156, 163, 175)
    $status.AutoSize = $true
    $status.Margin = New-Object System.Windows.Forms.Padding(8, 7, 0, 0)
    $status.Text = 'Ready'
    $bar.Controls.AddRange(@($btnCopy, $btnClear, $btnLogs, $btnRep, $chkLog, $status))
    $bottom.Controls.Add($out)
    $bottom.Controls.Add($bar)

    # Sidebar
    $side = New-Object System.Windows.Forms.FlowLayoutPanel
    $side.Dock = 'Left'
    $side.Width = 230
    $side.FlowDirection = 'TopDown'
    $side.WrapContents = $false
    $side.BackColor = $cSide
    $side.Padding = New-Object System.Windows.Forms.Padding(0, 8, 0, 0)

    # Header
    $header = New-Object System.Windows.Forms.Panel
    $header.Dock = 'Top'
    $header.Height = 58
    $header.BackColor = $cDark
    $title = New-Object System.Windows.Forms.Label
    $title.Text = 'IT TECHNICIAN TOOLKIT'
    $title.Font = $fontBig
    $title.ForeColor = [System.Drawing.Color]::White
    $title.AutoSize = $true
    $title.Location = New-Object System.Drawing.Point(16, 14)

    $right = New-Object System.Windows.Forms.FlowLayoutPanel
    $right.Dock = 'Right'
    $right.AutoSize = $true
    $right.WrapContents = $false
    $right.Padding = New-Object System.Windows.Forms.Padding(0, 14, 12, 0)
    $lblSearch = New-Object System.Windows.Forms.Label
    $lblSearch.Text = 'Search:'
    $lblSearch.ForeColor = [System.Drawing.Color]::White
    $lblSearch.AutoSize = $true
    $lblSearch.Margin = New-Object System.Windows.Forms.Padding(0, 5, 4, 0)
    $script:txtSearch = New-Object System.Windows.Forms.TextBox
    $txtSearch.Width = 200
    $lblAdmin = New-Object System.Windows.Forms.Label
    $lblAdmin.AutoSize = $true
    $lblAdmin.Margin = New-Object System.Windows.Forms.Padding(14, 5, 6, 0)
    $lblAdmin.Font = $fontBold
    $btnAdmin = New-BarButton 'Relaunch as admin'
    $btnAdmin.Margin = New-Object System.Windows.Forms.Padding(4, 0, 0, 0)
    if ($script:IsAdmin) {
        $lblAdmin.Text = "$env:COMPUTERNAME  |  ADMIN"
        $lblAdmin.ForeColor = [System.Drawing.Color]::FromArgb(134, 239, 172)
        $btnAdmin.Visible = $false
    } else {
        $lblAdmin.Text = "$env:COMPUTERNAME  |  not admin"
        $lblAdmin.ForeColor = [System.Drawing.Color]::FromArgb(252, 211, 77)
    }
    $right.Controls.AddRange(@($lblSearch, $txtSearch, $lblAdmin, $btnAdmin))
    $header.Controls.Add($title)
    $header.Controls.Add($right)

    # Docking order matters: fill first, header last
    $form.Controls.Add($flow)
    $form.Controls.Add($bottom)
    $form.Controls.Add($side)
    $form.Controls.Add($header)

    # ---------- Output pane ----------
    function Write-Pane {
        param([string]$Text, [string]$Kind = '')
        $color = $script:out.ForeColor
        if ($Text.StartsWith('[ OK ]'))      { $color = [System.Drawing.Color]::FromArgb(134, 239, 172) }
        elseif ($Text.StartsWith('[FAIL]'))  { $color = [System.Drawing.Color]::FromArgb(252, 165, 165) }
        elseif ($Text.StartsWith('[WARN]'))  { $color = [System.Drawing.Color]::FromArgb(252, 211, 77) }
        elseif ($Text.StartsWith('[INFO]'))  { $color = [System.Drawing.Color]::FromArgb(147, 197, 253) }
        elseif ($Text.StartsWith('===') -or $Kind -eq 'head') { $color = [System.Drawing.Color]::White }
        $script:out.SelectionStart = $script:out.TextLength
        $script:out.SelectionLength = 0
        $script:out.SelectionColor = $color
        $script:out.AppendText($Text + "`r`n")
        $script:out.SelectionColor = $script:out.ForeColor
        $script:out.ScrollToCaret()
    }

    # ---------- Items ----------
    function Get-VisibleItems {
        param($Items)
        $visible = @()
        $hidden = 0
        foreach ($it in $Items) {
            if ($it.type -eq 'run' -or (Test-Path (Join-Path $script:Root $it.script))) { $visible += $it } else { $hidden++ }
        }
        return [pscustomobject]@{ Items = $visible; Hidden = $hidden }
    }

    function Restart-ToolkitAsAdmin {
        try {
            Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$PSCommandPath`""
            $script:form.Close()
        } catch {
            Write-Pane '[WARN] Administrator prompt was cancelled.'
        }
    }

    function Start-ToolkitItem {
        param($It)
        if ($script:Busy) { Write-Pane '[WARN] Another action is still running.'; return }

        if ($It.type -eq 'run') {
            try {
                if ($It.args) { Start-Process -FilePath $It.path -ArgumentList $It.args }
                else { Start-Process -FilePath $It.path }
                Write-Pane "[INFO] Opened: $($It.name)"
            } catch {
                Write-Pane "[FAIL] Could not open $($It.name): $($_.Exception.Message)"
            }
            return
        }

        $path = Join-Path $script:Root $It.script
        if (-not (Test-Path $path)) { Write-Pane "[FAIL] Module not found: $($It.script)"; return }

        if ($It.admin -and -not $script:IsAdmin) {
            $r = [System.Windows.Forms.MessageBox]::Show("'$($It.name)' needs administrator rights.`n`nRelaunch the toolkit as administrator now?", 'Administrator required', 'YesNo', 'Question')
            if ($r -eq 'Yes') { Restart-ToolkitAsAdmin }
            return
        }
        if ($It.confirm) {
            $r = [System.Windows.Forms.MessageBox]::Show([string]$It.confirm, $It.name, 'YesNo', 'Warning')
            if ($r -ne 'Yes') { Write-Pane "[INFO] Cancelled: $($It.name)"; return }
        }

        $argStr = $(if ($It.args) { [string]$It.args } else { '' })
        $esc = $path.Replace("'", "''")

        if ($It.type -eq 'gui') {
            try {
                Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -ArgumentList "-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$path`" $argStr"
                Write-Pane "[INFO] Opened: $($It.name)"
            } catch {
                Write-Pane "[FAIL] Could not open $($It.name): $($_.Exception.Message)"
            }
            return
        }

        $script:Busy = $true
        $script:form.UseWaitCursor = $true
        $script:status.Text = "Running: $($It.name) ..."
        Write-Pane ''
        Write-Pane ("--- {0}  [{1}] ---" -f $It.name, (Get-Date -Format 'HH:mm:ss')) 'head'
        $code = 1
        try {
            $cmd = "[Console]::OutputEncoding=[Text.Encoding]::UTF8; try { & '$esc' $argStr *>&1 } catch { Write-Output ('[FAIL] ' + `$_) ; exit 1 }; exit `$LASTEXITCODE"
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = Join-Path $PSHOME 'powershell.exe'
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.CreateNoWindow = $true
            $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
            $p = [System.Diagnostics.Process]::Start($psi)
            $task = $p.StandardOutput.ReadLineAsync()
            while ($true) {
                if ($task.IsCompleted) {
                    $line = $task.Result
                    if ($null -eq $line) { break }
                    Write-Pane $line
                    $task = $p.StandardOutput.ReadLineAsync()
                } else {
                    [System.Windows.Forms.Application]::DoEvents()
                    Start-Sleep -Milliseconds 25
                }
            }
            $p.WaitForExit()
            $code = $p.ExitCode
        } catch {
            Write-Pane "[FAIL] $($_.Exception.Message)"
        }
        if ($code -eq 0)     { Write-Pane "[ OK ] Finished: $($It.name)"; $script:status.Text = "Done: $($It.name)" }
        elseif ($code -eq 2) { Write-Pane "[WARN] $($It.name) needs administrator rights"; $script:status.Text = "Needs admin: $($It.name)" }
        else                 { Write-Pane "[FAIL] $($It.name) reported a problem (exit code $code)"; $script:status.Text = "Failed: $($It.name)" }
        $script:form.UseWaitCursor = $false
        $script:Busy = $false
    }

    function New-ItemButton {
        param($It)
        $b = New-Object System.Windows.Forms.Button
        $b.Size = New-Object System.Drawing.Size(250, 56)
        $b.Margin = New-Object System.Windows.Forms.Padding(5)
        $b.FlatStyle = 'Flat'
        $b.BackColor = $cCard
        $b.ForeColor = $cText
        $b.TextAlign = 'MiddleLeft'
        $b.Padding = New-Object System.Windows.Forms.Padding(8, 0, 4, 0)
        $label = [string]$It.name
        if ($It.admin) {
            $label += '   [admin]'
            $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
        } else {
            $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(209, 213, 219)
        }
        if ($It.confirm) { $b.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(220, 38, 38) }
        $b.Text = $label
        $b.Tag = $It
        $script:tip.SetToolTip($b, [string]$It.desc)
        $b.Add_Click({ param($s, $e) Start-ToolkitItem $s.Tag })
        return $b
    }

    function Show-Items {
        param($Items, [string]$Heading, [int]$Hidden = 0)
        $script:flow.SuspendLayout()
        $script:flow.Controls.Clear()
        $h = New-Object System.Windows.Forms.Label
        $h.Text = $Heading
        $h.Font = $fontBig
        $h.ForeColor = $cText
        $h.AutoSize = $true
        $h.Margin = New-Object System.Windows.Forms.Padding(5, 0, 5, 4)
        $script:flow.Controls.Add($h)
        $script:flow.SetFlowBreak($h, $true)

        $note = New-Object System.Windows.Forms.Label
        $note.ForeColor = $cMuted
        $note.AutoSize = $true
        $note.Margin = New-Object System.Windows.Forms.Padding(5, 0, 5, 6)
        $note.Text = 'Blue border = needs administrator   |   Red border = asks for confirmation   |   Hover for details'
        $script:flow.Controls.Add($note)
        $script:flow.SetFlowBreak($note, $true)

        if (-not $Items -or @($Items).Count -eq 0) {
            $e = New-Object System.Windows.Forms.Label
            $e.Text = 'No modules installed in this section yet.'
            $e.ForeColor = $cMuted
            $e.AutoSize = $true
            $e.Margin = New-Object System.Windows.Forms.Padding(5, 14, 5, 5)
            $script:flow.Controls.Add($e)
        } else {
            $last = $null
            foreach ($it in $Items) {
                if ($it.group -ne $last) {
                    $last = $it.group
                    $g = New-Object System.Windows.Forms.Label
                    $g.Text = [string]$it.group
                    $g.Font = $fontHead
                    $g.ForeColor = [System.Drawing.Color]::FromArgb(37, 99, 235)
                    $g.AutoSize = $true
                    $g.Margin = New-Object System.Windows.Forms.Padding(5, 12, 5, 2)
                    $script:flow.Controls.Add($g)
                    $script:flow.SetFlowBreak($g, $true)
                }
                $script:flow.Controls.Add((New-ItemButton $it))
            }
        }
        if ($Hidden -gt 0) {
            $hl = New-Object System.Windows.Forms.Label
            $hl.Text = "($Hidden entries hidden because their module files are not installed yet)"
            $hl.ForeColor = $cMuted
            $hl.AutoSize = $true
            $hl.Margin = New-Object System.Windows.Forms.Padding(5, 18, 5, 5)
            $script:flow.Controls.Add($hl)
        }
        $script:flow.ResumeLayout()
    }

    function Select-Category {
        param($Cat)
        $script:CurrentCat = $Cat
        foreach ($c in $side.Controls) {
            if ($c.Tag -eq $Cat.id) { $c.BackColor = $cSideSel } else { $c.BackColor = $cSide }
        }
        $script:txtSearch.Text = ''
        $v = Get-VisibleItems $Cat.items
        Show-Items -Items $v.Items -Heading $Cat.title -Hidden $v.Hidden
    }

    # Sidebar buttons
    foreach ($cat in $script:Config.categories) {
        $b = New-Object System.Windows.Forms.Button
        $b.Text = '  ' + $cat.title
        $b.Tag = $cat.id
        $b.Size = New-Object System.Drawing.Size(230, 48)
        $b.Margin = New-Object System.Windows.Forms.Padding(0)
        $b.FlatStyle = 'Flat'
        $b.FlatAppearance.BorderSize = 0
        $b.ForeColor = [System.Drawing.Color]::White
        $b.BackColor = $cSide
        $b.TextAlign = 'MiddleLeft'
        $b.Font = New-Object System.Drawing.Font('Segoe UI', 10.5)
        $b.Add_Click({
            param($s, $e)
            $id = $s.Tag
            foreach ($c in $script:Config.categories) { if ($c.id -eq $id) { Select-Category $c; break } }
        })
        $side.Controls.Add($b)
    }

    # ---------- Events ----------
    $txtSearch.Add_TextChanged({
        $q = $script:txtSearch.Text.Trim()
        if (-not $q) {
            if ($script:CurrentCat) {
                $v = Get-VisibleItems $script:CurrentCat.items
                Show-Items -Items $v.Items -Heading $script:CurrentCat.title -Hidden $v.Hidden
            }
            return
        }
        $found = @()
        foreach ($c in $script:Config.categories) {
            foreach ($it in (Get-VisibleItems $c.items).Items) {
                if (("$($it.name) $($it.desc) $($it.group)") -like "*$q*") { $found += $it }
            }
        }
        Show-Items -Items $found -Heading "Search: $q"
    })
    $btnCopy.Add_Click({ if ($script:out.TextLength -gt 0) { [System.Windows.Forms.Clipboard]::SetText($script:out.Text); $script:status.Text = 'Output copied to clipboard' } })
    $btnClear.Add_Click({ $script:out.Clear(); $script:status.Text = 'Ready' })
    $btnLogs.Add_Click({ $d = Join-Path $script:Root 'Logs'; if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }; Start-Process explorer.exe "`"$d`"" })
    $btnRep.Add_Click({ $d = Join-Path $script:Root 'Reports'; if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }; Start-Process explorer.exe "`"$d`"" })
    $btnAdmin.Add_Click({ Restart-ToolkitAsAdmin })
    $chkLog.Add_CheckedChanged({ $env:TOOLKIT_LOG = $(if ($chkLog.Checked) { '1' } else { '0' }) }.GetNewClosure())

    # ---------- Start ----------
    Write-Pane ("IT Technician Toolkit  |  Computer: {0}  |  User: {1}  |  Admin: {2}" -f $env:COMPUTERNAME, $env:USERNAME, $(if ($script:IsAdmin) { 'yes' } else { 'no' })) 'head'
    Write-Pane "Toolkit folder: $($script:Root)"
    if (-not $script:IsAdmin) { Write-Pane '[WARN] Not running as administrator - tools marked [admin] will offer to relaunch.' }
    Write-Pane 'Pick a category on the left, then click a tool. Results appear here.'
    if ($script:Config.categories.Count -gt 0) { Select-Category $script:Config.categories[0] }
    [void]$form.ShowDialog()
}
catch {
    [System.Windows.Forms.MessageBox]::Show("The toolkit could not start:`n`n$($_.Exception.Message)", 'IT Technician Toolkit', 'OK', 'Error') | Out-Null
}
