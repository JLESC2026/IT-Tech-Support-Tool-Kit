# PC Assessment

Read-only hardware/health check. Produces ONE HTML report: system, CPU, RAM, storage (SMART/wear/free space),
graphics, battery, network, devices, drivers, security/firmware (TPM, Secure Boot, BitLocker, AV, updates,
Windows 11 readiness), event-log crashes and a performance snapshot.

Run from the terminal: `irm jlesc2026.github.io/assess | iex`
Run locally: double-click `Assess.bat`, or `powershell -ExecutionPolicy Bypass -File Assess.ps1 [-OutDir C:\path] [-NoOpen]`

The short-link launcher source is `ShortLinks\assess` in the repository. The release workflow publishes it to the website as `/assess`; keep it outside the repository root to avoid a Windows filename collision with this `Assess` folder.

The web run asks where the report should go (a folder or USB drive you choose, the Desktop, or show-then-delete); a local run saves it under `Assess\Reports`. It contains serial number and MAC addresses.
