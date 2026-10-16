# IT Technician Toolkit

A portable Windows troubleshooting dashboard for day-to-day IT support. It brings common fixes, diagnostic commands, and built-in Windows tools together in one place so a technician can quickly investigate issues with Windows, printers, scanners, networks, services, and hardware.

> **This is not a bootable Windows installer or recovery USB.** It is a toolkit that runs inside Windows.

## Project status

**Parts 1–3 are complete. Part 4 has not started.**

The current build contains the launcher and support tools described below. The planned diagnostics/reporting workflow, guided troubleshooting wizard, and portable-application collection are future work; their presence in the original plan does not mean they are implemented.

## Current features

### Parts 1–2: Launcher and support tools

- **Dashboard:** Searchable, category-based interface with a live output pane.
- **Quick Fix:** Restart Explorer, Windows Update, audio, Bluetooth, common or selected services, and the PC; clear temporary files.
- **Printer support:** Detect printers, inspect status, default printer, ports and drivers, clear the print queue, restart printer services, remove and re-detect a printer, open preferences, and print a test page.
- **Scanner support:** Detect scanners, inspect status, restart scanner services or WIA, and run scanner diagnostics.
- **Services:** Search and control services, view common service status, and open the Windows Services manager.
- **Advanced service tools:** Inspect or change service configuration and startup settings, and inspect service dependencies.
- **Manufacturer tools:** Open vendor utilities placed in the appropriate manufacturer folder or visit configured vendor support pages.

### Part 3: Network, Windows, and hardware

- **Network:** View network and Wi-Fi information, copy IP/MAC/network details, test internet, gateway, and DNS connectivity, inspect adapters, and run common network repairs. Advanced tools include `ipconfig`, route and ARP tables, `netstat`, `nslookup`, `tracert`, and `Test-NetConnection`.
- **Windows:** Run SFC and DISM repairs, analyze or clean the component store, repair Windows Update, run Disk Cleanup, and check Windows version/build information.
- **Hardware:** Inspect problem and connected devices, rescan hardware, troubleshoot USB, and view driver, audio, Bluetooth, display/GPU, storage, and general hardware information.

Tools that make system changes may require administrator rights and request confirmation. The dashboard hides script-backed entries when their script files are missing.

## Planned work: Part 4

Part 4 has **not started**. The plan includes a guided troubleshooting wizard, a diagnostics section with generated reports, and a collection of portable applications. These features are not part of the current usable build.

## Getting started

1. Copy the toolkit folder to a Windows PC or USB drive.
2. Run `START.bat` to open the dashboard. The launcher requests elevation only when a selected tool needs it.
3. Alternatively, run `START-AsAdmin.bat` to start the dashboard with administrator rights.
4. Select a category or search for a tool. Read any confirmation prompt before proceeding with a repair.

### Requirements

- Windows 10 or Windows 11
- Built-in Windows PowerShell 5.1
- Administrator rights for some repair and configuration actions

Most built-in troubleshooting tools work offline. Vendor support pages and any external applications require their own network access or installation as applicable.

## Project layout

| Folder or file | Purpose |
|---|---|
| `START.bat`, `START-AsAdmin.bat` | Launch normally or with administrator rights |
| `Launcher\` | Dashboard, shared helpers, and launcher logic |
| `Config\` | Dashboard shortcuts and toolkit settings |
| `QuickFix\`, `Printers\`, `Scanners\`, `Services\`, `Advanced\` | Part 1–2 support scripts |
| `Network\`, `Windows\`, `Hardware\` | Part 3 support scripts |
| `Manufacturer\` | Vendor utility folders and vendor launcher |
| `Logs\` | Optional action logs |
| `Diagnostics\`, `Reports\`, `PortableApps\` | Reserved for planned work; Part 4 has not started |

## How it works

- `Launcher\Toolkit.ps1` builds the Windows Forms dashboard from `Config\shortcuts.json`.
- Each PowerShell tool is a standalone script in its feature folder. Shortcut entries can also launch programs or Windows pages.
- `Launcher\Common.ps1` provides shared functionality such as output formatting, logging, service restarts, and selection dialogs.
- Tools report results in the dashboard using `[ OK ]`, `[FAIL]`, `[WARN]`, and `[INFO]` messages.
- When logging is enabled, actions are recorded in `Logs\<COMPUTERNAME>.log`. Logging can be toggled in the dashboard; `loggingEnabled` in `Config\settings.json` controls its default.
- Repairs that require elevation can request administrator rights when started from the normal launcher.

## Adding a tool

1. Add a PowerShell script to the relevant feature folder. For a tool using the shared helpers, start it with:

   ```powershell
   . (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')
   ```

   Finish by reporting the outcome with `Complete-Action -Action 'Name' -Success $ok`.

2. Add an entry to `Config\shortcuts.json`, for example:

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

   Use a `"type": "run"` entry with `"path"` and `"args"` to open a program or Windows page, or `"type": "gui"` to launch a script that displays its own window.

## Manufacturer utilities

Place legitimate vendor utilities in `Manufacturer\HP`, `Manufacturer\Canon`, `Manufacturer\Epson`, `Manufacturer\Brother`, or `Manufacturer\Other`. Vendor support links are configurable in `Config\settings.json`. Printer maintenance features such as printhead cleaning and nozzle checks vary by model, so use the appropriate manufacturer's tool or driver.

## Use with care

This toolkit can change Windows services, networking, system files, and device configuration. Review prompts, understand the selected operation, and make sure you have appropriate authorization and backups before applying repairs. The toolkit is intended for authorized IT support.

## Part 4 - Diagnostics, Advanced, Wizard and Finish
| Section | Contents |
|---|---|
| Diagnostics | Computer Information window (with **Copy All Information**), Generate diagnostic report, system / network / printer / scanner diagnostics, services, hardware, drivers, disk health, recent event-log errors, Device Manager, Event Viewer |
| Advanced / Hardcore | Windows repair (SFC, DISM, component store, Windows Update repair), network resets, routing / ARP, firewall diagnostics, CHKDSK (read-only / fix / surface), SMART, Disk Management, Registry Editor, Task Scheduler, Local Users, service configuration |
| Troubleshooting Wizard | Pick the problem (printer, scanner, no internet, Wi-Fi, slow Windows, no sound, USB, driver, other). It runs the checks, explains each step, asks before any fix and records the result in the log. Also at the top of Quick Fix. |
| Portable Tools | Launches programs from `PortableApps\<category>`; `PortableApps\README.txt` lists the official download pages |
| Self-check | Diagnostics > Toolkit self-check: syntax check of every script and a wiring check of every button |

Diagnostic report: `Reports\COMPUTERNAME_yyyy-MM-dd_HHmm\` with `System.txt`, `Network.txt`, `Printers.txt`, `Scanners.txt`, `Services.txt`, `Drivers.txt`, `Disks.txt`, `EventLogs.txt`.
Run it as administrator for complete SMART, driver and event-log data.

Part 4 files: `Diagnostics\`, `Advanced\`, `Wizard\`, `PortableApps\`, `Launcher\Part4-Helpers.ps1`.
Anything that changes the system (CHKDSK repair, registry, resets) shows a confirmation first and needs administrator rights.
