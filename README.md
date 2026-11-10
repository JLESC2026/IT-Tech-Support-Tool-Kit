# IT Tech Support Tool Kit

| Folder | What it is |
|---|---|
| `Technical Support/` | Diagnose-and-fix dashboard (`Launcher\Toolkit.ps1`) with portable apps |
| `Assess/` | Separate read-only full-PC assessment -> single HTML report |
| `toolkit`, `assess` | Short-link loaders; copy both into the `JLESC2026.github.io` repo |

```powershell
irm jlesc2026.github.io/toolkit | iex     # zero-trace support dashboard
irm jlesc2026.github.io/assess  | iex     # hardware assessment report on the Desktop
irm "https://raw.githubusercontent.com/JLESC2026/IT-Tech-Support-Tool-Kit/main/Install.ps1" | iex   # keep a copy on the PC
```
The repository must be public for these links to work.
