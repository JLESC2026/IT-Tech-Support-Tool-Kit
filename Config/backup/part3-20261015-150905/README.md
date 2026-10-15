# IT Technician USB Toolkit

Portable troubleshooting dashboard for Windows PCs. Not a bootable installer/recovery USB.

## Start it
- `START.bat` - opens the dashboard (tools marked **[admin]** offer to relaunch elevated)
- `START-AsAdmin.bat` - opens it with administrator rights straight away

Requires Windows 10/11 with built-in Windows PowerShell 5.1. No internet needed.

## What is in this build (Parts 1 + 2)
| Section | Contents |
|---|---|
| Quick Fix | Explorer, Windows Update, temp files, restart PC, common services, printer, scanner, audio, Bluetooth, restart any service |
| Printer / Scanner | detect, status, ports, drivers, queue, spooler, remove/re-detect, test page, preferences/maintenance, diagnostics, WIA, scanner diagnostics, manufacturer tools |
| Services | Service Center window (search, start, stop, restart), status of common services, one-click restarts |
| Advanced | service configuration, startup type, service dependencies |

Network fixes, Windows repair, Hardware, Diagnostics report, Wizard, Portable Tools and the rest of Advanced
are the next parts. Menu entries whose module file is missing are hidden automatically,
so they appear as soon as the files are added.

## How it works
- `Launcher\Toolkit.ps1` draws the dashboard and reads `Config\shortcuts.json`.
- Each fix is its own script (QuickFix, Printers, Scanners, Services, Advanced, Manufacturer ...).
- `Launcher\Common.ps1` holds the shared helpers (output tags, logging, service restarts, pickers).
- Exit codes: 0 success, 1 failed, 2 needs admin. Output lines start with `[ OK ]`, `[FAIL]`, `[WARN]`, `[INFO]`.
- Actions are logged to `Logs\COMPUTERNAME.log` (untick "Log actions" to pause; `loggingEnabled` in `Config\settings.json` sets the default).

## Add your own tool
1. Drop a script in the matching folder. Start it with:
   `. (Join-Path (Split-Path -Parent $PSScriptRoot) 'Launcher\Common.ps1')` and finish with `Complete-Action -Action 'Name' -Success $ok`.
2. Add an entry to `Config\shortcuts.json`:
   `{ "group": "My tools", "name": "Do thing", "desc": "What it does", "script": "QuickFix\\Do-Thing.ps1", "admin": true, "confirm": "Are you sure?" }`
   - `"type": "run"` with `"path"` / `"args"` opens any program or Windows page (for example `services.msc`)
   - `"type": "gui"` starts a script that shows its own window

## Manufacturer tools
Put official vendor utilities in `Manufacturer\HP`, `Canon`, `Epson`, `Brother` or `Other`.
The vendor buttons list what is in the folder, or open the vendor support site (links are editable in `Config\settings.json`).
Printhead cleaning, nozzle checks and maintenance counters are model specific - use the vendor tool or the driver's Maintenance tab.
