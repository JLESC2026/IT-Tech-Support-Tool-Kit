# PC Assessment

Read-only hardware/health check. Produces ONE HTML report: system, CPU, RAM, storage (SMART/wear/free space),
graphics, battery, network, devices, drivers, security/firmware (TPM, Secure Boot, BitLocker, AV, updates,
Windows 11 readiness), event-log crashes and a performance snapshot.

Run from the terminal: `irm jlesc2026.github.io/assess | iex`
Run locally: double-click `Assess.bat`, or `powershell -ExecutionPolicy Bypass -File Assess.ps1 [-OutDir C:\path] [-NoOpen]`

Report goes to the Desktop (web run) or `Assess\Reports` (local run). It contains serial number and MAC addresses.
