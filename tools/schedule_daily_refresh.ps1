# schedule_daily_refresh.ps1 - register (or re-register) the daily data refresh
# as a Windows Scheduled Task. Idempotent: re-running replaces the task.
#
# Run once, in an ELEVATED PowerShell (Run as Administrator):
#     powershell -ExecutionPolicy Bypass -File tools\schedule_daily_refresh.ps1
#
# To remove:  Unregister-ScheduledTask -TaskName 'Thjodhagslikan daily refresh' -Confirm:$false

$ErrorActionPreference = 'Stop'

$TaskName = 'Thjodhagslikan daily refresh'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$Wrapper  = Join-Path $RepoRoot 'tools\run_daily.ps1'

if (-not (Test-Path $Wrapper)) { throw "Wrapper not found: $Wrapper" }

# Action: run the wrapper hidden, no profile.
$Action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$Wrapper`"" `
    -WorkingDirectory $RepoRoot

# Trigger: daily at 02:00.
$Trigger = New-ScheduledTaskTrigger -Daily -At 2:00AM

# Settings: wake the machine, allow running on battery, retry on failure,
# allow a long run, and start late if the scheduled time was missed (PC off).
$Settings = New-ScheduledTaskSettingsSet `
    -WakeToRun `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RestartCount 2 -RestartInterval (New-TimeSpan -Minutes 15) `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

# Run as the current user, only when logged on (no stored password needed).
# This means the PC must be logged in (or set up auto-logon) for the wake/run to
# fire. If you want it to run while logged off, switch to -LogonType Password and
# supply credentials.
$Principal = New-ScheduledTaskPrincipal `
    -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) `
    -LogonType Interactive `
    -RunLevel Limited

# Replace any existing task of the same name.
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing task '$TaskName'."
}

Register-ScheduledTask `
    -TaskName $TaskName `
    -Description 'Runs all thjodhagslikan raw fetchers then pipeline.R, daily at 02:00. See R/run_all.R.' `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Principal $Principal | Out-Null

Write-Host "Registered scheduled task '$TaskName' (daily 02:00)."
Write-Host "Test it now with:  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Logs land in:      $(Join-Path $RepoRoot 'logs')"
