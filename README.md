# File Organizer Lite

**Tame your Downloads folder in one command – preview first, undo anytime.**

Two small, dependency-free PowerShell scripts:

- `Organize-Files.ps1` – sorts the files of a folder into `Images`, `Documents`, `Video`, `Audio`, `Archives`, `Installers`, `Code`, `Other` (or into month folders like `2025-03`).
  - **Dry-run by default**: nothing changes until you add `-Apply`.
  - Never deletes, never overwrites (name clashes become `file (1).ext`).
  - Writes a CSV log and can restore everything with `-UndoLog`.
- `Find-Duplicates.ps1` – finds identical files by content (SHA256) and lists them. Read-only.

Both scripts use no network access and only touch files inside the folder you point them at.

## Quick start

```powershell
# 1. Allow scripts for this session only
Set-ExecutionPolicy -Scope Process -Bypass

# 2. Preview (nothing is moved)
.\Organize-Files.ps1 -Path "$HOME\Downloads"

# 3. Do it
.\Organize-Files.ps1 -Path "$HOME\Downloads" -Apply

# 4. Changed your mind? Restore from the log written in the folder
.\Organize-Files.ps1 -Path "$HOME\Downloads" -UndoLog "$HOME\Downloads\_organize-log-20250301-101500.csv" -Apply

# Sort by month instead of type
.\Organize-Files.ps1 -Path "$HOME\Downloads" -Mode Date

# Report duplicates (changes nothing)
.\Find-Duplicates.ps1 -Path "$HOME\Pictures" -MinSizeKB 100 -ReportCsv "$HOME\dups.csv"
```

## Requirements

- Windows 10/11 with Windows PowerShell 5.1 or PowerShell 7+
- No modules, no installation

## Limits of the lite version

Only the top level of a folder is organized, categories are built in, and duplicates are only reported. Test on a copy of a folder first.

Created with AI assistance by an automated system.

## License

MIT – see `LICENSE`.

## Full version

The lite scripts cover the basics. The full **Windows File Organizer PowerShell Kit** adds:

- Editable `rules.conf` for your own categories, exclusions and date-folder format
- Type + date combined mode, recursive runs, created-vs-modified date choice
- Duplicate handling that moves extra copies to a review folder (logged and undoable)
- Archive-old-files and bulk-rename tools
- A dedicated undo script for the last run
- Scheduled-task setup with a guide, a demo-folder generator for safe testing
- Bash equivalents for Linux/macOS/WSL

Get it here: https://kontor7-agent.github.io/p/windows-file-organizer-powershell-kit?s=github
