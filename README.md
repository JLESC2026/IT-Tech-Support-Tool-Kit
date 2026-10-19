# IT Technician Toolkit

A portable Windows troubleshooting dashboard for day-to-day IT support. It puts common fixes, diagnostic commands and built-in Windows tools in one window, so a technician can quickly investigate and repair problems with Windows, printers, scanners, networks, services and hardware, without remembering commands or hunting through menus.

> **This is not a bootable Windows installer or recovery USB.** It runs inside Windows, on a PC that already starts.

## What it does

- Gives you one dashboard with a button for each common support task.
- Runs checks and fixes (restart a service, clear a print queue, reset the network, repair system files) and shows the result in plain language.
- Guides you through common problems with a **Troubleshooting Wizard** that runs the checks in order, explains each step, and asks before changing anything.
- Collects information about a PC (hardware, network, drivers, disks, event logs) and saves it as a **diagnostic report** you can attach to a ticket.
- Launches portable utilities you add yourself (disk health, hardware info, file search and so on) and vendor tools for printers and scanners.
- Keeps a log of what was run on each computer.

## Getting started

1. Copy the toolkit folder to a Windows PC or USB drive.
2. Run `START.bat` to open the dashboard. When you click a tool that needs administrator rights, it offers to relaunch elevated.
3. Or run `START-AsAdmin.bat` to start with administrator rights straight away.
4. Pick a category on the left, then click a tool. Results appear in the output pane at the bottom.

**Requirements:** Windows 10 or 11 with the built-in Windows PowerShell 5.1. No internet is needed for most tools. Some output (for example Wi-Fi information) expects an English version of Windows.

## How it is organized

The sidebar is split into categories:

| Category | What you will find |
|---|---|
| Quick Fix | One-click fixes: restart Explorer, Windows Update, audio, Bluetooth, services, the PC; clear temp files. The Troubleshooting Wizard is at the top. |
| Windows Issues | SFC and DISM repairs, component store cleanup, Windows Update repair, Disk Cleanup, version and build information, and shortcuts to built-in Windows tools |
| Printer / Scanner Issues | Detect printers and scanners, check status, ports and drivers, clear the print queue, restart printer and scanner services, test pages, and vendor tools (HP, Canon, Epson, Brother, others) |
| Network Issues | Network Center window, IP/MAC/Wi-Fi information with copy buttons, internet / gateway / DNS tests, and fixes such as flush DNS, renew IP, adapter restart and full network reset |
| Services | Service Center window (search, start, stop, restart), status of common services, one-click restarts |
| Hardware / Devices | Problem devices, connected devices, USB troubleshooting, drivers, audio, Bluetooth, display/GPU, storage |
| Diagnostics | Computer Information window with Copy All, diagnostic report generator, system / network / printer / scanner checks, recent event-log errors, and the toolkit self-check |
| Portable Tools | Launcher for portable programs stored in `PortableApps\` |
| Advanced / Hardcore | CHKDSK, SMART data, registry editor, firewall diagnostics, local users, service configuration and dependencies, and the riskiest repairs |

### Folder layout

| Folder or file | Purpose |
|---|---|
| `START.bat`, `START-AsAdmin.bat` | Start the toolkit normally or as administrator |
| `Launcher\` | The dashboard and shared helper scripts |
| `Config\` | `shortcuts.json` (the buttons) and `settings.json` (options); automatic backups are kept in `Config\backup\` |
| `QuickFix\`, `Windows\`, `Printers\`, `Scanners\`, `Network\`, `Services\`, `Hardware\`, `Diagnostics\`, `Advanced\`, `Wizard\` | The scripts behind the buttons, grouped by topic |
| `Manufacturer\` | Vendor utilities, one sub-folder per brand |
| `PortableApps\` | Portable programs you download yourself, one sub-folder per category |
| `Drivers\` | Optional place for driver installers |
| `Reports\` | Diagnostic reports, one folder per computer and date |
| `Logs\` | Action logs, one file per computer |

## How it works

- `Launcher\Toolkit.ps1` draws the dashboard and reads `Config\shortcuts.json` to build the buttons. A button whose script file is missing is hidden automatically.
- Each tool is its own PowerShell script. The dashboard runs it in a separate process and shows its output live.
- Shared code (output formatting, logging, service restarts, selection dialogs, network and report helpers) lives in `Launcher\`.
- Output lines start with a tag: `[ OK ]`, `[FAIL]`, `[WARN]` or `[INFO]`, shown in color.
- Exit codes: 0 = success, 1 = failed, 2 = needs administrator.
- Button borders show what to expect: **blue** needs administrator rights, **red** asks for confirmation first. Hover over a button for a description.
- Actions are logged to `Logs\COMPUTERNAME.log`. Tick or untick **Log actions** in the dashboard, or change `loggingEnabled` in `Config\settings.json`.

### The Troubleshooting Wizard

Choose the closest problem (printer not printing, scanner not working, no internet, Wi-Fi, slow Windows, no sound, USB device, driver problem, or something else). The wizard runs read-only checks automatically, explains why each step matters, skips fixes that are not needed, asks before each fix, and finishes by asking whether the problem is solved. If it is not, it suggests next steps and offers to create a diagnostic report.

### Diagnostic report

**Diagnostics > Generate diagnostic report** creates `Reports\COMPUTERNAME_yyyy-MM-dd_HHmm\` with `System.txt`, `Network.txt`, `Printers.txt`, `Scanners.txt`, `Services.txt`, `Drivers.txt`, `Disks.txt` and `EventLogs.txt`. Run it as administrator for complete SMART, driver and event-log data.

### Portable tools and vendor utilities

The toolkit does not include third-party software. Download the official portable version of each tool and unzip it into the matching `PortableApps\<category>` folder; `PortableApps\README.txt` lists suggested tools and their official download pages. Put printer and scanner utilities from the manufacturer in `Manufacturer\<brand>`. Check each tool's licence before copying it to a USB drive.

## Precautions

This toolkit can change Windows services, networking, system files and device settings. Before using it:

- **Get permission.** Only use it on computers you are authorized to support, and get approval from the owner before running repairs.
- **Back up first** when a repair can affect data or the system (CHKDSK repair, Windows Update repair, resets). Read every confirmation prompt.
- **Start with read-only tools.** The checks, diagnostics and information tools change nothing. Use fixes only when a check points to a problem.
- **Be careful with the Advanced category.** The registry editor, CHKDSK /F and /R, startup type changes and network resets can stop Windows or the network from working. Network resets need a restart afterwards.
- **Test before wider use.** Try the toolkit on a spare PC or VM, ideally with a deliberately created fault, before using it on other people's computers.
- **Expect some security software to react.** PowerShell started with `-ExecutionPolicy Bypass` may be flagged. Check with whoever manages security on that PC.
- **Protect the logs and reports.** They contain computer and user names. Decide who may see them, and keep `Logs\` and `Reports\` out of version control.
- **Avoid running it on unattended machines** unless you are sure of what each tool does; some actions (restart, service stops) interrupt users.

## Adding your own tool

1. Add a script to the matching folder. Start it with:

   ```powershell
   . (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
   ```

   and finish with `Complete-Action -Action 'Name' -Success $ok`.

2. Add an entry to `Config\shortcuts.json`:

   ```json
   {
     "group": "My tools",
     "name": "Do thing",
     "desc": "What it does",
     "script": "QuickFix\\Do-Thing.ps1",
     "admin": true,
     "confirm": "Are you sure?"
   }
   ```

   - `"type": "run"` with `"path"` and `"args"` opens any program or Windows page (for example `services.msc`).
   - `"type": "gui"` starts a script that shows its own window.

3. Run **Diagnostics > Toolkit self-check** (syntax check and wiring check) to confirm the script and button are valid.