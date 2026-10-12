<#
.SYNOPSIS
Sorts the files of one folder into sub-folders by type or by month. Dry-run by default.

.DESCRIPTION
Moves files (never deletes, never overwrites) into folders such as Images, Documents, Video
or into month folders such as 2025-03. Only the top level of the folder is processed.
Without -Apply nothing is changed: you only see what WOULD happen.
With -Apply every move is written to a CSV log; use -UndoLog <file> to move everything back.
Network is never used. Files are only moved inside the target folder.

.PARAMETER Path
Folder to organize (for example your Downloads folder).

.PARAMETER Mode
Type (default): Path\Images\photo.jpg      Date: Path\2025-03\photo.jpg

.PARAMETER Apply
Really move the files. Without this switch it is a preview.

.PARAMETER UndoLog
Path of a log written by an earlier -Apply run. Restores the files (preview unless -Apply is given).

.EXAMPLE
.\Organize-Files.ps1 -Path "$HOME\Downloads"

.EXAMPLE
.\Organize-Files.ps1 -Path "$HOME\Downloads" -Apply

.EXAMPLE
.\Organize-Files.ps1 -Path "$HOME\Downloads" -UndoLog "$HOME\Downloads\_organize-log-20250301-101500.csv" -Apply
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Path,
    [ValidateSet('Type', 'Date')][string]$Mode = 'Type',
    [switch]$Apply,
    [string]$UndoLog
)

$ErrorActionPreference = 'Stop'

$map = [ordered]@{
    'Images'    = 'jpg jpeg png gif bmp webp tif tiff heic svg ico raw'
    'Documents' = 'pdf doc docx odt rtf txt md xls xlsx ods csv ppt pptx odp epub'
    'Video'     = 'mp4 mkv avi mov wmv webm flv m4v'
    'Audio'     = 'mp3 wav flac aac ogg m4a wma'
    'Archives'  = 'zip rar 7z tar gz bz2 xz iso'
    'Installers'= 'exe msi msix appx'
    'Code'      = 'ps1 py js ts json xml html css sh bat cmd sql yml yaml'
}
$extToCat = @{}
foreach ($k in $map.Keys) { foreach ($e in ($map[$k] -split ' ')) { $extToCat[$e] = $k } }

if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw "Folder not found: $Path" }
$root = (Resolve-Path -LiteralPath $Path).ProviderPath.TrimEnd('\', '/')
if ($root.Length -le 3) { throw "Refusing to run on a drive root: $root" }

function Get-FreeName([string]$dir, [string]$name) {
    $target = Join-Path $dir $name
    $i = 1
    $base = [System.IO.Path]::GetFileNameWithoutExtension($name)
    $ext = [System.IO.Path]::GetExtension($name)
    while (Test-Path -LiteralPath $target) {
        $target = Join-Path $dir ("{0} ({1}){2}" -f $base, $i, $ext)
        $i++
    }
    return $target
}

function Test-Inside([string]$p) {
    return $p.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

# ---------- Undo ----------
if ($UndoLog) {
    if (-not (Test-Path -LiteralPath $UndoLog -PathType Leaf)) { throw "Log not found: $UndoLog" }
    $rows = @(Import-Csv -LiteralPath $UndoLog)
    [array]::Reverse($rows)
    $n = 0
    foreach ($r in $rows) {
        $from = $r.Destination; $to = $r.Source
        if (-not ((Test-Inside $from) -and (Test-Inside $to))) { Write-Warning "Skipped (outside target folder): $from"; continue }
        if (-not (Test-Path -LiteralPath $from)) { Write-Warning "Missing, skipped: $from"; continue }
        $toDir = Split-Path -Parent $to
        $to = Get-FreeName $toDir (Split-Path -Leaf $to)
        Write-Host ("RESTORE {0} -> {1}" -f $from, $to)
        if ($Apply) {
            if (-not (Test-Path -LiteralPath $toDir)) { [void](New-Item -ItemType Directory -Path $toDir) }
            Move-Item -LiteralPath $from -Destination $to
        }
        $n++
    }
    if ($Apply) { Write-Host "$n file(s) restored." } else { Write-Host "Preview only: $n file(s) would be restored. Add -Apply." }
    return
}

# ---------- Organize ----------
$files = @(Get-ChildItem -LiteralPath $root -File)   # hidden/system files are not listed
Write-Host ("Scanning {0}: {1} file(s)." -f $root, $files.Count)
$log = New-Object System.Collections.ArrayList
$inv = [System.Globalization.CultureInfo]::InvariantCulture

foreach ($f in $files) {
    if ($f.Name -like '_organize-log-*.csv') { continue }
    $ext = $f.Extension.TrimStart('.').ToLowerInvariant()
    if ($Mode -eq 'Type') {
        if ($extToCat.ContainsKey($ext)) { $sub = $extToCat[$ext] } else { $sub = 'Other' }
    }
    else { $sub = $f.LastWriteTime.ToString('yyyy-MM', $inv) }

    $destDir = Join-Path $root $sub
    $dest = Get-FreeName $destDir $f.Name
    Write-Host ("MOVE {0}  ->  {1}" -f $f.Name, $dest.Substring($root.Length + 1))
    if ($Apply) {
        try {
            if (-not (Test-Path -LiteralPath $destDir)) { [void](New-Item -ItemType Directory -Path $destDir) }
            Move-Item -LiteralPath $f.FullName -Destination $dest
            [void]$log.Add([pscustomobject]@{ Source = $f.FullName; Destination = $dest })
        }
        catch { Write-Warning ("Could not move '{0}': {1}" -f $f.Name, $_.Exception.Message) }
    }
    else { [void]$log.Add($f) }
}

if ($Apply) {
    if ($log.Count -gt 0) {
        $logFile = Join-Path $root ('_organize-log-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.csv')
        $log | Export-Csv -LiteralPath $logFile -NoTypeInformation -Encoding UTF8
        Write-Host ("{0} file(s) moved. Undo log: {1}" -f $log.Count, $logFile)
    }
    else { Write-Host 'Nothing to move.' }
}
else {
    Write-Host ("Preview only: {0} file(s) would be moved. Re-run with -Apply to do it." -f $log.Count)
}
