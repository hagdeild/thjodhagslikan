# run_daily.ps1 - wrapper invoked by Windows Task Scheduler.
# Runs R/run_all.R from the repo root and writes a timestamped log to logs/.
# Keeps the last 30 logs. Exit code is propagated from Rscript so the scheduled
# task's "Last Run Result" reflects fetcher/pipeline failures.

$ErrorActionPreference = 'Stop'

# Repo root = parent of this script's directory (tools/).
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot

# Locate Rscript: prefer PATH, else the known install.
$Rscript = (Get-Command Rscript -ErrorAction SilentlyContinue).Source
if (-not $Rscript) {
    $candidate = 'C:\Program Files\R\R-4.6.0\bin\x64\Rscript.exe'
    if (Test-Path $candidate) { $Rscript = $candidate }
}
if (-not $Rscript) { throw "Rscript not found on PATH or at the known install location." }

# Log file.
$LogDir = Join-Path $RepoRoot 'logs'
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Stamp   = Get-Date -Format 'yyyy-MM-dd_HHmmss'
$LogFile = Join-Path $LogDir "refresh_$Stamp.log"

"=== run_daily.ps1 starting $(Get-Date -Format o) ===" | Tee-Object -FilePath $LogFile
"Rscript: $Rscript"                                     | Tee-Object -FilePath $LogFile -Append
"RepoRoot: $RepoRoot"                                   | Tee-Object -FilePath $LogFile -Append

# Run. R sends message()/cat() to stderr; merge stderr into stdout and flatten
# each line to a plain string (PS 5.1 wraps native stderr in ErrorRecords, which
# would otherwise print as red error blocks in the log). $LASTEXITCODE still
# reflects Rscript's real exit code.
& $Rscript 'R/run_all.R' 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $LogFile -Append
$code = $LASTEXITCODE

"=== finished $(Get-Date -Format o) - exit $code ===" | Tee-Object -FilePath $LogFile -Append

# Retain only the most recent 30 logs.
Get-ChildItem $LogDir -Filter 'refresh_*.log' |
    Sort-Object LastWriteTime -Descending |
    Select-Object -Skip 30 |
    Remove-Item -Force -ErrorAction SilentlyContinue

exit $code
