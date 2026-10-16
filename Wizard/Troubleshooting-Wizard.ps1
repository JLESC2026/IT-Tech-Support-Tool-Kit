# Troubleshooting Wizard - pick the problem; the toolkit runs the checks and fixes step by step
# and explains what it is doing. Fixes always ask first. The result is written to the log.
$root = Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'Launcher\Common.ps1')
. (Join-Path $root 'Launcher\Part3-Helpers.ps1')
. (Join-Path $root 'Launcher\Part4-Helpers.ps1')
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$script:Root = $root
$script:IsAdmin = Test-IsAdmin
$script:Running = $false
$script:StopRequested = $false
$script:Proc = $null
$script:LastCheckOk = $null
# Child scripts must not wait for "Press Enter"
$env:TOOLKIT_LAUNCHER = '1'

# ---------- Step helpers ----------
# Kind: check = runs automatically | fix = explains and asks first | open = opens a Windows tool | note = advice only
# RunIf: 'always' or 'problem' (fix runs only when the latest check found a problem)
function New-Step {
    param([string]$Kind, [string]$Title, [string]$Why, [string]$Script = '', [string]$StepArgs = '', [bool]$Admin = $false, [string]$Ask = '', [string]$RunIf = 'always')
    return [pscustomobject]@{ Kind = $Kind; Title = $Title; Why = $Why; Script = $Script; StepArgs = $StepArgs; Admin = $Admin; Ask = $Ask; RunIf = $RunIf }
}

function Get-WizardFlows {
    $f = @()

    $f += [pscustomobject]@{
        Id = 'printer'; Title = "Printer isn't printing"
        Intro = 'I will check that the printer is detected, look for a stuck queue, a stopped Print Spooler or driver problems, repair what is wrong, then print a test page.'
        NextIfNot = 'Try "Remove and re-detect printer" (Printer / Scanner Issues), reinstall the driver from the vendor tool (Manufacturer folder), and check the cable / network connection and the printer display for errors.'
        Steps = @(
            (New-Step 'check' 'Is the printer detected?' 'Lists installed printers with their status, driver and port.' 'Printers\Detect-Printers.ps1'),
            (New-Step 'check' 'Printer diagnostics' 'Checks the Print Spooler, offline printers, stuck jobs in the spool folder, missing drivers and recent print errors.' 'Printers\Printer-Diagnostics.ps1'),
            (New-Step 'fix' 'Clear the print queue' 'A single stuck job blocks every job behind it. This stops the spooler, deletes all pending jobs and starts it again.' 'Printers\Clear-Print-Queue.ps1' '' $true 'This deletes ALL pending print jobs on this computer. Continue?' 'problem'),
            (New-Step 'fix' 'Restart the Print Spooler' 'Restarting the spooler fixes many "printer offline" and "job stays in queue" problems.' 'Printers\Restart-Print-Spooler.ps1' '' $true 'Restart the Print Spooler now?' 'problem'),
            (New-Step 'fix' 'Print a test page' 'Confirms that Windows can really print to the default printer.' 'Printers\Print-Test-Page.ps1' '' $false 'Print a test page on the default printer?')
        )
    }

    $f += [pscustomobject]@{
        Id = 'scanner'; Title = "Scanner isn't working"
        Intro = 'I will check that Windows sees the scanner and that the scanner services (WIA) run, then restart them if something is wrong.'
        NextIfNot = 'Check the USB cable / power / network, reinstall the scanner driver or the vendor scan utility (Manufacturer folder), and try another USB port.'
        Steps = @(
            (New-Step 'check' 'Is the scanner detected?' 'Lists scanners and imaging devices known to Windows and WIA.' 'Scanners\Detect-Scanners.ps1'),
            (New-Step 'check' 'Scanner status' 'Checks the device status and problem codes of the scanner.' 'Scanners\Check-Scanner-Status.ps1'),
            (New-Step 'check' 'Scanner diagnostics' 'Checks WIA and related services, drivers and recent errors.' 'Scanners\Scanner-Diagnostics.ps1'),
            (New-Step 'fix' 'Restart Windows Image Acquisition (WIA)' 'WIA is the service every scanning program talks to; restarting it clears most "scanner not found" errors.' 'Scanners\Restart-WIA.ps1' '' $true 'Restart the WIA service now?' 'problem'),
            (New-Step 'fix' 'Restart all scanner services' 'Also restarts the services WIA depends on.' 'Scanners\Restart-Scanner-Services.ps1' '' $true 'Restart the scanner services now?' 'problem'),
            (New-Step 'check' 'Detect scanners again' 'Verifies whether the scanner shows up now.' 'Scanners\Detect-Scanners.ps1')
        )
    }

    $f += [pscustomobject]@{
        Id = 'internet'; Title = 'No internet'
        Intro = 'I will test the router (gateway), DNS and the internet in that order to find where the connection breaks, then apply the matching fix.'
        NextIfNot = 'Check the cable, router and modem lights, and whether other devices have internet. If only this PC is affected, restart it and run the full network reset again.'
        Steps = @(
            (New-Step 'check' 'Network information' 'Shows the IP address, gateway and DNS this PC is using.' 'Network\Show-Network-Info.ps1'),
            (New-Step 'check' 'Test the gateway (router)' 'If the router does not answer, the problem is the cable / Wi-Fi / IP address, not the internet.' 'Network\Test-Gateway.ps1'),
            (New-Step 'check' 'Test DNS' 'If names do not resolve but the router answers, DNS is the problem.' 'Network\Test-DNS.ps1'),
            (New-Step 'check' 'Test the internet' 'Final test: can this PC reach the internet and a web page?' 'Network\Test-Internet.ps1'),
            (New-Step 'fix' 'Flush the DNS cache' 'Removes old or wrong name lookups.' 'Network\Flush-DNS.ps1' '' $false 'Flush the DNS cache now?' 'problem'),
            (New-Step 'fix' 'Renew the IP address' 'Releases the DHCP address and asks the router for a new one.' 'Network\Renew-IP.ps1' '' $true 'Renew the IP address now? The connection drops briefly.' 'problem'),
            (New-Step 'check' 'Test the internet again' 'Checks whether the fixes worked.' 'Network\Test-Internet.ps1'),
            (New-Step 'fix' 'Restart a network adapter' 'A selection window will open - pick the active adapter. The connection drops briefly.' 'Network\Restart-Network-Adapter.ps1' '' $true 'Restart a network adapter now?' 'problem'),
            (New-Step 'check' 'Test the internet once more' 'Checks the result after the adapter restart.' 'Network\Test-Internet.ps1'),
            (New-Step 'fix' 'Full network reset (needs a restart)' 'Last resort: resets Winsock and the TCP/IP stack. The PC must be restarted afterwards.' 'Network\Network-Reset.ps1' '' $true 'Reset Winsock and TCP/IP now? A restart is required afterwards.' 'problem')
        )
    }

    $f += [pscustomobject]@{
        Id = 'wifi'; Title = "Wi-Fi isn't working"
        Intro = 'I will look at the Wi-Fi connection, test the router and internet, and restart the Wi-Fi service / IP address if needed.'
        NextIfNot = 'Forget and re-join the Wi-Fi network, update the Wi-Fi driver (Hardware > Driver information), and check that the Wi-Fi switch / airplane mode is off.'
        Steps = @(
            (New-Step 'check' 'Wi-Fi information' 'Shows the connected network, signal strength, channel and nearby networks.' 'Network\Show-WiFi-Info.ps1'),
            (New-Step 'check' 'Test the gateway (router)' 'Checks that the router answers.' 'Network\Test-Gateway.ps1'),
            (New-Step 'fix' 'Restart the Wi-Fi (WLAN AutoConfig) service' 'This service manages all Wi-Fi connections; restarting it fixes many "no networks found" problems.' 'Network\Restart-WLAN-Service.ps1' '' $true 'Restart the Wi-Fi service now? Wi-Fi drops briefly.' 'problem'),
            (New-Step 'fix' 'Renew the IP address' 'Gets a fresh address from the router.' 'Network\Renew-IP.ps1' '' $true 'Renew the IP address now?' 'problem'),
            (New-Step 'check' 'Test the internet' 'Checks whether the connection works now.' 'Network\Test-Internet.ps1'),
            (New-Step 'fix' 'Restart a network adapter' 'A selection window will open - pick the Wi-Fi adapter.' 'Network\Restart-Network-Adapter.ps1' '' $true 'Restart a network adapter now? The connection drops briefly.' 'problem')
        )
    }

    $f += [pscustomobject]@{
        Id = 'slow'; Title = 'Windows is slow'
        Intro = 'I will check memory, free disk space and pending restarts, offer to clear temporary files, and open the tools that show what is using the computer.'
        NextIfNot = 'Look at Task Manager for programs using a lot of CPU / disk / memory, remove unneeded startup apps, run the SFC scan (Windows Issues) and check the disk health (Advanced > SMART information).'
        Steps = @(
            (New-Step 'check' 'System diagnostics' 'Checks uptime, free memory, free space on the Windows drive and a pending restart.' 'Diagnostics\System-Diagnostics.ps1'),
            (New-Step 'check' 'Storage health and free space' 'A nearly full or failing disk makes Windows very slow.' 'Hardware\Storage-Info.ps1'),
            (New-Step 'fix' 'Clear temporary files' 'Deletes user and Windows temp files (locked files are skipped).' 'QuickFix\Clear-Temp-Files.ps1' '' $false 'Delete temporary files from this computer?'),
            (New-Step 'open' 'Open Task Manager' 'Sort by CPU, Memory and Disk to find the program that is slowing the PC.' 'taskmgr.exe'),
            (New-Step 'open' 'Open Startup apps' 'Turn off programs you do not need at start-up.' 'ms-settings:startupapps'),
            (New-Step 'fix' 'Verify system files (SFC, read-only)' 'Checks Windows system files for damage without changing anything.' 'Windows\SFC-Scan.ps1' '-VerifyOnly' $true 'The SFC verification takes 10-30 minutes. Run it now?')
        )
    }

    $f += [pscustomobject]@{
        Id = 'sound'; Title = 'No sound'
        Intro = 'I will list the audio devices, restart the Windows Audio services and open the sound settings so the right output can be chosen.'
        NextIfNot = 'Check the volume / mute, the selected output device (speakers vs headphones vs HDMI), the cable, and reinstall the audio driver (Hardware > Driver information).'
        Steps = @(
            (New-Step 'check' 'Audio devices' 'Shows the sound devices and their driver status.' 'Hardware\Audio-Devices.ps1'),
            (New-Step 'fix' 'Restart Windows Audio' 'Restarts the audio services - fixes "no sound" after sleep or a device change.' 'QuickFix\Restart-Audio.ps1' '' $true 'Restart Windows Audio now?'),
            (New-Step 'open' 'Open Sound settings' 'Make sure the correct output device is selected and not muted.' 'ms-settings:sound'),
            (New-Step 'check' 'Devices with problems' 'Looks for audio devices with a driver error.' 'Hardware\Problem-Devices.ps1')
        )
    }

    $f += [pscustomobject]@{
        Id = 'usb'; Title = "USB device isn't detected"
        Intro = 'I will list the USB devices, look for devices with errors, and rescan the hardware if there is a problem.'
        NextIfNot = 'Try another USB port and cable, plug directly into the PC (no hub), test the device on another computer, and check USB power saving settings.'
        Steps = @(
            (New-Step 'check' 'USB devices' 'Shows the connected USB devices and controllers.' 'Hardware\USB-Devices.ps1'),
            (New-Step 'check' 'USB troubleshooting' 'Checks the USB controllers, power management and recent USB errors.' 'Hardware\USB-Troubleshoot.ps1'),
            (New-Step 'check' 'Devices with problems' 'Lists devices that Windows reports with an error code.' 'Hardware\Problem-Devices.ps1'),
            (New-Step 'fix' 'Rescan hardware' 'Asks Windows to look for new or changed devices again.' 'Hardware\Rescan-Hardware.ps1' '' $true 'Rescan for hardware changes now?' 'problem'),
            (New-Step 'check' 'USB devices again' 'Checks whether the device shows up now.' 'Hardware\USB-Devices.ps1')
        )
    }

    $f += [pscustomobject]@{
        Id = 'driver'; Title = 'Device / driver problem'
        Intro = 'I will list devices with errors, check the installed drivers, rescan the hardware and open Device Manager for the details.'
        NextIfNot = 'Download the driver from the PC or device manufacturer (Drivers folder / vendor site), uninstall the device in Device Manager and restart so Windows reinstalls it.'
        Steps = @(
            (New-Step 'check' 'Devices with problems' 'Lists devices that Windows reports with an error code and explains the code.' 'Hardware\Problem-Devices.ps1'),
            (New-Step 'check' 'Driver information' 'Shows unsigned, missing and very old drivers.' 'Hardware\Driver-Info.ps1'),
            (New-Step 'fix' 'Rescan hardware' 'Asks Windows to detect and configure devices again.' 'Hardware\Rescan-Hardware.ps1' '' $true 'Rescan for hardware changes now?' 'problem'),
            (New-Step 'check' 'Devices with problems (after the rescan)' 'Checks whether the problem is gone.' 'Hardware\Problem-Devices.ps1'),
            (New-Step 'open' 'Open Device Manager' 'Right-click the device to update, roll back or uninstall its driver.' 'devmgmt.msc')
        )
    }

    $f += [pscustomobject]@{
        Id = 'other'; Title = 'Something else'
        Intro = 'I will run a general health check (system, devices, services, event logs) and offer to create a full diagnostic report.'
        NextIfNot = 'Use the category buttons in the main window, or send the diagnostic report to the next support level.'
        Steps = @(
            (New-Step 'check' 'System diagnostics' 'Uptime, memory, disk space and pending restarts.' 'Diagnostics\System-Diagnostics.ps1'),
            (New-Step 'check' 'Devices with problems' 'Hardware and drivers that report an error.' 'Hardware\Problem-Devices.ps1'),
            (New-Step 'check' 'Common services' 'Print, scan, network, audio, Bluetooth and Windows Update services.' 'Services\Service-Status.ps1'),
            (New-Step 'check' 'Recent errors in the event logs' 'The latest critical / error events often name the failing component.' 'Diagnostics\Recent-Events.ps1'),
            (New-Step 'fix' 'Generate a diagnostic report' 'Saves everything to the Reports folder so it can be attached to a ticket.' 'Diagnostics\Generate-Report.ps1' '' $false 'Generate the full diagnostic report now? It takes about a minute.')
        )
    }
    return $f
}
$script:Flows = @(Get-WizardFlows)

# ---------- Colours / fonts ----------
$cDark = [System.Drawing.Color]::FromArgb(17, 24, 39)
$cBlue = [System.Drawing.Color]::FromArgb(37, 99, 235)
$cBg   = [System.Drawing.Color]::FromArgb(243, 244, 246)
$cText = [System.Drawing.Color]::FromArgb(17, 24, 39)
$cMuted = [System.Drawing.Color]::FromArgb(107, 114, 128)
$fontUI = New-Object System.Drawing.Font('Segoe UI', 9.5)
$fontBig = New-Object System.Drawing.Font('Segoe UI', 15, [System.Drawing.FontStyle]::Bold)
$fontBtn = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$fontMono = New-Object System.Drawing.Font('Consolas', 9.5)

# ---------- Form ----------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Troubleshooting Wizard'
$form.ClientSize = New-Object System.Drawing.Size(1000, 720)
$form.MinimumSize = New-Object System.Drawing.Size(860, 600)
$form.StartPosition = 'CenterScreen'
$form.Font = $fontUI
$form.BackColor = $cBg

$header = New-Object System.Windows.Forms.Panel
$header.Dock = 'Top'
$header.Height = 58
$header.BackColor = $cDark
$title = New-Object System.Windows.Forms.Label
$title.Text = 'TROUBLESHOOTING WIZARD'
$title.Font = $fontBig
$title.ForeColor = [System.Drawing.Color]::White
$title.AutoSize = $true
$title.Location = New-Object System.Drawing.Point(16, 14)
$lblAdmin = New-Object System.Windows.Forms.Label
$lblAdmin.AutoSize = $true
$lblAdmin.Anchor = 'Top,Right'
$lblAdmin.Location = New-Object System.Drawing.Point(760, 22)
if ($script:IsAdmin) {
    $lblAdmin.Text = "$env:COMPUTERNAME  |  ADMIN"
    $lblAdmin.ForeColor = [System.Drawing.Color]::FromArgb(134, 239, 172)
} else {
    $lblAdmin.Text = "$env:COMPUTERNAME  |  not admin (repair steps will be skipped)"
    $lblAdmin.ForeColor = [System.Drawing.Color]::FromArgb(252, 211, 77)
    $lblAdmin.Location = New-Object System.Drawing.Point(560, 22)
}
$header.Controls.AddRange(@($title, $lblAdmin))

# Home panel
$pnlHome = New-Object System.Windows.Forms.Panel
$pnlHome.Dock = 'Fill'
$pnlHome.Padding = New-Object System.Windows.Forms.Padding(24)
$lblAsk = New-Object System.Windows.Forms.Label
$lblAsk.Text = "WHAT'S THE PROBLEM?"
$lblAsk.Font = New-Object System.Drawing.Font('Segoe UI', 20, [System.Drawing.FontStyle]::Bold)
$lblAsk.ForeColor = $cText
$lblAsk.AutoSize = $true
$lblAsk.Location = New-Object System.Drawing.Point(24, 20)
$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = 'Pick the closest match. The wizard runs the checks, explains each step and asks before it changes anything.'
$lblSub.ForeColor = $cMuted
$lblSub.AutoSize = $true
$lblSub.Location = New-Object System.Drawing.Point(26, 64)
$flowBtns = New-Object System.Windows.Forms.FlowLayoutPanel
$flowBtns.Location = New-Object System.Drawing.Point(18, 100)
$flowBtns.Size = New-Object System.Drawing.Size(940, 560)
$flowBtns.Anchor = 'Top,Left,Right,Bottom'
$flowBtns.AutoScroll = $true
foreach ($fl in $script:Flows) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = "[ $($fl.Title) ]"
    $b.Tag = $fl.Id
    $b.Size = New-Object System.Drawing.Size(295, 78)
    $b.Margin = New-Object System.Windows.Forms.Padding(8)
    $b.FlatStyle = 'Flat'
    $b.FlatAppearance.BorderColor = $cBlue
    $b.FlatAppearance.BorderSize = 2
    $b.BackColor = [System.Drawing.Color]::White
    $b.ForeColor = $cText
    $b.Font = $fontBtn
    $b.Add_Click({ param($s, $e) Start-Flow ([string]$s.Tag) })
    $flowBtns.Controls.Add($b)
}
$pnlHome.Controls.AddRange(@($lblAsk, $lblSub, $flowBtns))

# Run panel
$pnlRun = New-Object System.Windows.Forms.Panel
$pnlRun.Dock = 'Fill'
$pnlRun.Visible = $false
$lblProblem = New-Object System.Windows.Forms.Label
$lblProblem.Font = New-Object System.Drawing.Font('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$lblProblem.ForeColor = $cText
$lblProblem.AutoSize = $true
$lblProblem.Location = New-Object System.Drawing.Point(16, 12)
$lblStep = New-Object System.Windows.Forms.Label
$lblStep.ForeColor = $cBlue
$lblStep.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$lblStep.AutoSize = $true
$lblStep.Location = New-Object System.Drawing.Point(16, 44)
$progress = New-Object System.Windows.Forms.ProgressBar
$progress.Location = New-Object System.Drawing.Point(16, 74)
$progress.Size = New-Object System.Drawing.Size(960, 10)
$progress.Anchor = 'Top,Left,Right'
$log = New-Object System.Windows.Forms.RichTextBox
$log.Location = New-Object System.Drawing.Point(16, 96)
$log.Size = New-Object System.Drawing.Size(960, 500)
$log.Anchor = 'Top,Left,Right,Bottom'
$log.ReadOnly = $true
$log.BackColor = $cDark
$log.ForeColor = [System.Drawing.Color]::FromArgb(209, 213, 219)
$log.Font = $fontMono
$log.BorderStyle = 'None'
$bar = New-Object System.Windows.Forms.FlowLayoutPanel
$bar.Dock = 'Bottom'
$bar.Height = 52
$bar.Padding = New-Object System.Windows.Forms.Padding(14, 10, 0, 0)
function New-WizButton([string]$Text, [int]$Width) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $Text
    $b.Size = New-Object System.Drawing.Size($Width, 34)
    $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 8, 0)
    return $b
}
$btnBack = New-WizButton 'Back to problems' 160
$btnStop = New-WizButton 'Stop' 90
$btnReport = New-WizButton 'Generate diagnostic report' 210
$btnCopy = New-WizButton 'Copy output' 120
$bar.Controls.AddRange(@($btnBack, $btnStop, $btnReport, $btnCopy))
$pnlRun.Controls.AddRange(@($lblProblem, $lblStep, $progress, $log, $bar))

$form.Controls.Add($pnlHome)
$form.Controls.Add($pnlRun)
$form.Controls.Add($header)

# ---------- Output ----------
function Write-Wiz {
    param([string]$Text, [string]$Kind = '')
    $color = $log.ForeColor
    if ($Text.StartsWith('[ OK ]'))      { $color = [System.Drawing.Color]::FromArgb(134, 239, 172) }
    elseif ($Text.StartsWith('[FAIL]'))  { $color = [System.Drawing.Color]::FromArgb(252, 165, 165) }
    elseif ($Text.StartsWith('[WARN]'))  { $color = [System.Drawing.Color]::FromArgb(252, 211, 77) }
    elseif ($Text.StartsWith('[INFO]'))  { $color = [System.Drawing.Color]::FromArgb(147, 197, 253) }
    elseif ($Kind -eq 'head' -or $Text.StartsWith('===')) { $color = [System.Drawing.Color]::White }
    elseif ($Kind -eq 'why') { $color = [System.Drawing.Color]::FromArgb(196, 181, 253) }
    $log.SelectionStart = $log.TextLength
    $log.SelectionLength = 0
    $log.SelectionColor = $color
    $log.AppendText($Text + "`r`n")
    $log.SelectionColor = $log.ForeColor
    $log.ScrollToCaret()
}

function Show-Box {
    param([string]$Text, [string]$Caption, [string]$Buttons = 'YesNo', [string]$Icon = 'Question')
    return [System.Windows.Forms.MessageBox]::Show($form, $Text, $Caption, $Buttons, $Icon)
}

# Runs one toolkit script in a child PowerShell and streams its output into the log. Returns the exit code.
function Invoke-WizardScript {
    param([string]$RelPath, [string]$StepArgs = '')
    $path = Join-Path $script:Root $RelPath
    if (-not (Test-Path $path)) { Write-Wiz "[FAIL] Module not found: $RelPath"; return 1 }
    $esc = $path.Replace("'", "''")
    $code = 1
    try {
        $cmd = "[Console]::OutputEncoding=[Text.Encoding]::UTF8; try { & '$esc' $StepArgs *>&1 } catch { Write-Output ('[FAIL] ' + `$_) ; exit 1 }; exit `$LASTEXITCODE"
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = Join-Path $PSHOME 'powershell.exe'
        $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -Command `"$cmd`""
        $psi.UseShellExecute = $false
        $psi.RedirectStandardOutput = $true
        $psi.CreateNoWindow = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $p = [System.Diagnostics.Process]::Start($psi)
        $script:Proc = $p
        $task = $p.StandardOutput.ReadLineAsync()
        while ($true) {
            if ($task.IsCompleted) {
                $line = $task.Result
                if ($null -eq $line) { break }
                Write-Wiz $line
                $task = $p.StandardOutput.ReadLineAsync()
            } else {
                [System.Windows.Forms.Application]::DoEvents()
                Start-Sleep -Milliseconds 25
            }
        }
        $p.WaitForExit()
        $code = $p.ExitCode
    } catch {
        Write-Wiz "[FAIL] $($_.Exception.Message)"
    }
    $script:Proc = $null
    return $code
}

function Set-RunningState {
    param([bool]$Running)
    $script:Running = $Running
    $btnStop.Enabled = $Running
    $btnBack.Enabled = (-not $Running)
    $btnReport.Enabled = (-not $Running)
    $form.UseWaitCursor = $false
}

# ---------- The wizard ----------
function Start-Flow {
    param([string]$Id)
    if ($script:Running) { return }
    $flow = $script:Flows | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $flow) { return }

    $pnlHome.Visible = $false
    $pnlRun.Visible = $true
    $log.Clear()
    $lblProblem.Text = $flow.Title
    $script:StopRequested = $false
    $script:LastCheckOk = $null
    Set-RunningState $true

    $steps = @($flow.Steps)
    $n = $steps.Count
    $progress.Minimum = 0
    $progress.Maximum = $n
    $progress.Value = 0
    $summary = @()
    $skippedAdmin = 0

    Write-Wiz "PROBLEM: $($flow.Title)" 'head'
    Write-Wiz $flow.Intro 'why'
    Write-Wiz "Computer: $env:COMPUTERNAME   User: $env:USERNAME   Administrator: $(if ($script:IsAdmin) { 'yes' } else { 'no' })"

    $i = 0
    foreach ($st in $steps) {
        if ($script:StopRequested) { break }
        $i++
        $lblStep.Text = "Step $i of ${n}: $($st.Title)"
        Write-Wiz ''
        Write-Wiz "--- Step $i/${n}: $($st.Title) ---" 'head'
        Write-Wiz "What and why: $($st.Why)" 'why'

        switch ($st.Kind) {
            'check' {
                $code = Invoke-WizardScript -RelPath $st.Script -StepArgs $st.StepArgs
                if ($script:StopRequested) { $summary += "STOPPED   $($st.Title)"; break }
                if ($code -eq 0) { $script:LastCheckOk = $true; Write-Wiz '[ OK ] No problem found in this step'; $summary += "OK        $($st.Title)" }
                elseif ($code -eq 2) { $script:LastCheckOk = $false; Write-Wiz '[WARN] This check needs administrator rights'; $skippedAdmin++; $summary += "NEEDS ADMIN  $($st.Title)" }
                else { $script:LastCheckOk = $false; Write-Wiz '[WARN] A problem was found - see above'; $summary += "PROBLEM   $($st.Title)" }
            }
            'fix' {
                if ($st.RunIf -eq 'problem' -and $script:LastCheckOk -eq $true) {
                    Write-Wiz '[ OK ] Skipped - the previous check found no problem, so this fix is not needed'
                    $summary += "SKIPPED   $($st.Title) (not needed)"
                    break
                }
                if ($st.Admin -and -not $script:IsAdmin) {
                    Write-Wiz '[WARN] Skipped - this step needs administrator rights. Start the toolkit with START-AsAdmin.bat and run the wizard again.'
                    $skippedAdmin++
                    $summary += "SKIPPED   $($st.Title) (needs admin)"
                    break
                }
                $answer = Show-Box -Text "$($st.Why)`n`n$($st.Ask)" -Caption $st.Title
                if ($answer -ne 'Yes') {
                    Write-Wiz '[INFO] Skipped by the technician'
                    $summary += "SKIPPED   $($st.Title)"
                    break
                }
                $code = Invoke-WizardScript -RelPath $st.Script -StepArgs $st.StepArgs
                if ($script:StopRequested) { $summary += "STOPPED   $($st.Title)"; break }
                if ($code -eq 0) { Write-Wiz '[ OK ] Done'; $summary += "DONE      $($st.Title)" }
                elseif ($code -eq 2) { Write-Wiz '[WARN] Needs administrator rights'; $skippedAdmin++; $summary += "NEEDS ADMIN  $($st.Title)" }
                else { Write-Wiz '[FAIL] The step reported a problem - see above'; $summary += "FAILED    $($st.Title)" }
            }
            'open' {
                try {
                    if ($st.StepArgs) { Start-Process -FilePath $st.Script -ArgumentList $st.StepArgs } else { Start-Process -FilePath $st.Script }
                    Write-Wiz "[INFO] Opened: $($st.Title)"
                    $summary += "OPENED    $($st.Title)"
                } catch {
                    Write-Wiz "[FAIL] Could not open: $($_.Exception.Message)"
                    $summary += "FAILED    $($st.Title)"
                }
            }
            default { Write-Wiz '[INFO] Advice only'; $summary += "NOTE      $($st.Title)" }
        }
        $progress.Value = [math]::Min($i, $n)
        [System.Windows.Forms.Application]::DoEvents()
    }

    $lblStep.Text = 'Finished'
    Write-Wiz ''
    Write-Wiz "=== Summary: $($flow.Title) ===" 'head'
    foreach ($s in $summary) { Write-Wiz $s }
    if ($skippedAdmin -gt 0) { Write-Wiz "[WARN] $skippedAdmin step(s) need administrator rights. Start START-AsAdmin.bat and run the wizard again." }

    if ($script:StopRequested) {
        Write-Wiz '[WARN] Wizard stopped.'
        Write-Log -Action "Wizard: $($flow.Title)" -Result 'STOPPED' -Detail ($summary -join '; ')
        Set-RunningState $false
        return
    }

    $res = Show-Box -Text "All steps for '$($flow.Title)' are finished.`n`nIs the problem resolved now?" -Caption 'Problem resolved?'
    if ($res -eq 'Yes') {
        Write-Wiz '[ OK ] Marked as resolved.'
        Write-Log -Action "Wizard: $($flow.Title)" -Result 'RESOLVED' -Detail ($summary -join '; ')
        Set-RunningState $false
    } else {
        Write-Wiz '[WARN] Not resolved yet.'
        Write-Wiz "Next: $($flow.NextIfNot)" 'why'
        Write-Log -Action "Wizard: $($flow.Title)" -Result 'NOT RESOLVED' -Detail ($summary -join '; ')
        Set-RunningState $false
        $rep = Show-Box -Text "The problem is not resolved.`n`nCreate a full diagnostic report now so it can be escalated?" -Caption 'Escalate'
        if ($rep -eq 'Yes') { Start-Report }
    }
}

function Start-Report {
    if ($script:Running) { return }
    Set-RunningState $true
    $lblStep.Text = 'Generating the diagnostic report...'
    Write-Wiz ''
    Write-Wiz '--- Diagnostic report ---' 'head'
    $null = Invoke-WizardScript -RelPath 'Diagnostics\Generate-Report.ps1'
    $lblStep.Text = 'Report finished'
    Set-RunningState $false
}

# ---------- Events ----------
$btnBack.Add_Click({
    if ($script:Running) { return }
    $pnlRun.Visible = $false
    $pnlHome.Visible = $true
})
$btnStop.Add_Click({
    $script:StopRequested = $true
    try { if ($script:Proc -and -not $script:Proc.HasExited) { $script:Proc.Kill() } } catch { }
    Write-Wiz '[WARN] Stop requested...'
})
$btnReport.Add_Click({ Start-Report })
$btnCopy.Add_Click({ if ($log.TextLength -gt 0) { [System.Windows.Forms.Clipboard]::SetText($log.Text) } })
$form.Add_FormClosing({
    param($s, $e)
    if ($script:Running) {
        $e.Cancel = $true
        $script:StopRequested = $true
        try { if ($script:Proc -and -not $script:Proc.HasExited) { $script:Proc.Kill() } } catch { }
    }
})
Set-RunningState $false

[void]$form.ShowDialog()
