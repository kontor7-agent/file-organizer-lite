<#
.SYNOPSIS
Finds duplicate files by content (SHA256) and prints / saves a report. Read-only.

.DESCRIPTION
Groups files by size, hashes only same-size files, and lists the groups.
This lite version never moves or deletes anything. The optional CSV report is written
to the path you give with -ReportCsv (it must not already exist).

.EXAMPLE
.\Find-Duplicates.ps1 -Path "$HOME\Pictures"

.EXAMPLE
.\Find-Duplicates.ps1 -Path "$HOME\Downloads" -MinSizeKB 100 -ReportCsv "$HOME\dups.csv"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Path,
    [int]$MinSizeKB = 1,
    [string]$ReportCsv
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Folder not found: $Path" }
if ($ReportCsv -and (Test-Path -LiteralPath $ReportCsv)) { throw "Report file already exists, choose another name: $ReportCsv" }

$min = [int64]$MinSizeKB * 1024
$files = @(Get-ChildItem -LiteralPath $Path -File -Recurse | Where-Object { $_.Length -ge $min })
Write-Host ("Scanning {0}: {1} file(s)." -f $Path, $files.Count)

$rows = New-Object System.Collections.ArrayList
$gid = 0
$wasted = [int64]0
foreach ($sg in ($files | Group-Object Length | Where-Object { $_.Count -gt 1 })) {
    $hashed = foreach ($f in $sg.Group) {
        try { [pscustomobject]@{ Hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash; File = $f } }
        catch { Write-Warning "Cannot read: $($f.FullName)" }
    }
    foreach ($hg in ($hashed | Group-Object Hash | Where-Object { $_.Count -gt 1 })) {
        $gid++
        $sorted = @($hg.Group | ForEach-Object { $_.File } | Sort-Object LastWriteTime, FullName)
        Write-Host ("`nGroup {0} ({1:N0} bytes each, {2} copies)" -f $gid, $sorted[0].Length, $sorted.Count) -ForegroundColor Cyan
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            if ($i -eq 0) { $role = 'Oldest'; Write-Host "  OLDEST $($sorted[$i].FullName)" }
            else { $role = 'Duplicate'; $wasted += $sorted[$i].Length; Write-Host "  DUP    $($sorted[$i].FullName)" -ForegroundColor Yellow }
            [void]$rows.Add([pscustomobject]@{ Group = $gid; Role = $role; Path = $sorted[$i].FullName; SizeBytes = $sorted[$i].Length })
        }
    }
}

Write-Host ''
if ($gid -eq 0) { Write-Host 'No duplicates found.' -ForegroundColor Green }
else { Write-Host ("{0} group(s); extra copies use {1:N1} MB. No files were changed." -f $gid, ($wasted / 1MB)) -ForegroundColor Green }
if ($ReportCsv -and $rows.Count -gt 0) {
    $rows | Export-Csv -LiteralPath $ReportCsv -NoTypeInformation -Encoding UTF8
    Write-Host "Report saved: $ReportCsv"
}
