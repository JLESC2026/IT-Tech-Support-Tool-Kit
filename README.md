# IT Technician Toolkit

A portable Windows troubleshooting dashboard for day-to-day IT support. It brings common fixes, diagnostic commands, and built-in Windows tools together in one place so a technician can quickly investigate issues with Windows, printers, scanners, networks, services, and hardware.

> **This is not a bootable Windows installer or recovery USB.** It is a toolkit that runs inside Windows.

## Project status

**Parts 1-4 are complete.** The toolkit includes the launcher, all support tools, the diagnostics and report generator, the guided Troubleshooting Wizard, the Portable Tools launcher, and the built-in self-checks.

The toolkit has so far been tested on a single development PC. Test it on a spare machine or VM before using it on production computers (see [Before using it on other computers](#before-using-it-on-other-computers)).

## Features

### Dashboard and Quick Fix

- **Dashboard:** Searchable, category-based interface with a live output pane, a Copy output button, and a log toggle.
- **Quick Fix:** Restart Explorer, Windows Update, audio, Bluetooth, common or selected services, and the PC; clear temporary files. The Troubleshooting Wizard is also available at the top of this section.

### Printers, scanners and services

- **Printer support:** Detect printers, inspect status, default printer, ports and drivers, clear the print queue, restart printer services, remove and re-detect a printer, open preferences, and print a test page.
- **Scanner support:** Detect scanners, inspect status, restart scanner services or WIA, and run scanner diagnostics.
- **Services:** Service Center window (search, start, stop, restart), status of common services, and one-click restarts.
- **Manufacturer tools:** Open vendor utilities placed in the matching manufacturer folder, or visit the configured vendor support pages.

### Network, Windows and hardware

- **Network:** Network Center live window, network and Wi-Fi information, copy IP/MAC/network details, test internet, gateway and DNS, inspect adapters, and run common network repairs. Advanced tools include `ipconfig`, route and ARP tables, `netstat`, `nslookup`, `tracert`, and `Test-NetConnection`.
- **Windows:** Run SFC and DISM repairs, analyze or clean the component store, repair Windows Update, run Disk Cleanup, and check Windows version/build information.
- **Hardware:** Inspect problem and connected devices, rescan hardware, troubleshoot USB, and view driver, audio, Bluetooth, display/GPU, storage, and general hardware information.

### Part 4: Diagnostics, Wizard, Portable Tools and Advanced

| Section | Contents |
|---|---|
| Diagnostics | Computer Information window (with **Copy All Information**), Generate diagnostic report, system / network / printer / scanner diagnostics, services, hardware, drivers, disk health, recent event-log errors, Device Manager, Event Viewer |
| Troubleshooting Wizard | Pick the problem (printer, scanner, no internet, Wi-Fi, slow Windows, no sound, USB, driver, other). It runs the checks, explains each step, asks before any fix and records the result in the log. |
| Portable Tools | Launches programs from `PortableApps\<category>`; `PortableApps\README.txt` lists the official download pages |
| Advanced / Hardcore | Windows repair (SFC, DISM, component store, Windows Update repair), network resets, routing / ARP, firewall diagnostics, CHKDSK (read-only / fix / surface), SMART, Disk Management, Registry Editor, Task Scheduler, Local Users, service configuration and dependencies |
| Self-check | Diagnostics > Toolkit self-check: a syntax check of every script and a wiring check of every button |

**Diagnostic report:** `Reports\COMPUTERNAME_yyyy-MM-dd_HHmm\` containing `System.txt`, `Network.txt`, `Printers.txt`, `Scanners.txt`, `Services.txt`, `Drivers.txt`, `Disks.txt` and `EventLogs.txt`. Run it as administrator for complete SMART, driver and event-log data.

Tools that make system changes (CHKDSK repair, registry, network resets, startup type changes and similar) show a confirmation first and need administrator rights.

## Getting started

1. Copy the toolkit folder to a Windows PC or USB drive.
2. Run `START.bat` to open the dashboard. The launcher offers to relaunch elevated only when a selected tool needs it.
3. Alternatively, run `START-AsAdmin.bat` to start the dashboard with administrator rights.
4. Select a category or search for a tool. Read any confirmation prompt before proceeding with a repair.

### Requirements

- Windows 10 or Windows 11
- Built-in Windows PowerShell 5.1
- Administrator rights for some repair and configuration actions

Most built-in troubleshooting tools work offline. Vendor support pages and any external applications require their own network access or installation as applicable. Some output parsing (for example Wi-Fi information) expects English Windows labels.

## Project layout

| Folder or file | Purpose |
|---|---|
| `START.bat`, `START-AsAdmin.bat` | Launch normally or with administrator rights |
| `Launcher\` | Dashboard (`Toolkit.ps1`) and shared helpers (`Common.ps1`, `Part3-Helpers.ps1`, `Part4-Helpers.ps1`) |
| `Config\` | Dashboard shortcuts (`shortcuts.json`) and toolkit settings (`settings.json`); `Config\backup\` holds automatic backups |
| `QuickFix\`, `Printers\`, `Scanners\`, `Services\` | Part 1-2 support scripts |
| `Network\`, `Windows\`, `Hardware\` | Part 3 support scripts |
| `Diagnostics\`, `Advanced\`, `Wizard\` | Part 4 diagnostics, advanced tools and the Troubleshooting Wizard |
| `PortableApps\` | Portable programs, one sub-folder per category (not shipped with the toolkit) |
| `Manufacturer\` | Vendor utility folders and the vendor launcher |
| `Drivers\` | Optional place for driver installers |
| `Reports\` | Generated diagnostic reports |
| `Logs\` | Optional action logs, one file per computer |

## How it works

- `Launcher\Toolkit.ps1` builds the Windows Forms dashboard from `Config\shortcuts.json`.
- Each PowerShell tool is a standalone script in its feature folder. Shortcut entries can also launch programs or Windows pages. Entries whose script file is missing are hidden automatically.
- `Launcher\Common.ps1` provides shared functionality such as output formatting, logging, service restarts, and selection dialogs. `Part3-Helpers.ps1` and `Part4-Helpers.ps1` add network, hardware and report helpers.
- Tools report results using `[ OK ]`, `[FAIL]`, `[WARN]`, and `[INFO]` messages.
- Exit codes: 0 = success, 1 = failed, 2 = needs administrator.
- When logging is enabled, actions are recorded in `Logs\<COMPUTERNAME>.log`. Logging can be toggled in the dashboard; `loggingEnabled` in `Config\settings.json` controls its default.

## Portable Tools

The toolkit does **not** include third-party programs. Download the official portable version of each tool, unzip it into the matching `PortableApps\<category>` folder, and the Portable Tools buttons will list and launch it. `PortableApps\README.txt` lists the suggested tools and their official download pages. Check each tool's licence before copying it to a USB drive.

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

3. Run **Diagnostics > Toolkit self-check** (syntax check and wiring check) to confirm the new script and button are valid.

## Manufacturer utilities

Place legitimate vendor utilities in `Manufacturer\HP`, `Manufacturer\Canon`, `Manufacturer\Epson`, `Manufacturer\Brother`, or `Manufacturer\Other`. Vendor support links are configurable in `Config\settings.json`. Printer maintenance features such as printhead cleaning and nozzle checks vary by model, so use the appropriate manufacturer's tool or driver.

## Before using it on other computers

- Test on a spare PC or VM first, ideally with deliberately created faults (stopped Print Spooler, stuck print job, wrong DNS) to confirm the fixes actually work.
- Check how the tools behave in a standard (non-admin) user session.
- Some security software may flag PowerShell launched with `-ExecutionPolicy Bypass`; test on one PC before wider use.
- Logs and reports contain computer and user names. Decide who may see them, and avoid committing `Logs\` and `Reports\` to version control.
- Get approval from whoever owns the computers before running repairs.

## Use with care

This toolkit can change Windows services, networking, system files, and device configuration. Review prompts, understand the selected operation, and make sure you have appropriate authorization and backups before applying repairs. The toolkit is intended for authorized IT support.