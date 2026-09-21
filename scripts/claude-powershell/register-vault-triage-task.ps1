#Requires -Version 7.0
<#
.SYNOPSIS
    Register (or remove) the "Obsidian Vault Triage" Windows scheduled task.

.DESCRIPTION
    Runs run-vault-triage.ps1 on a daily or every-other-day cadence in the current
    user's context. Runs only while logged on (no stored password needed), and
    catches up on the next logon if the machine was off at trigger time.

.EXAMPLE
    # Daily at 9:07am (default)
    pwsh -NoProfile -File .claude\scripts\register-vault-triage-task.ps1

.EXAMPLE
    # Every other day at 8:15am
    pwsh -NoProfile -File .claude\scripts\register-vault-triage-task.ps1 -Time 08:15 -DaysInterval 2

.EXAMPLE
    pwsh -NoProfile -File .claude\scripts\register-vault-triage-task.ps1 -Unregister
#>
[CmdletBinding()]
param(
    # Local time of day to run. Off-the-hour by default on purpose.
    [string]$Time = '09:07',
    # 1 = daily, 2 = every other day.
    [ValidateRange(1, 7)][int]$DaysInterval = 1,
    # Look-back window handed to the scanner. Keep >= DaysInterval so nothing is missed.
    [int]$Days = 3,
    [switch]$Unregister
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TaskName  = 'Obsidian Vault Triage'
$VaultRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$Runner    = Join-Path $VaultRoot '.claude\scripts\run-vault-triage.ps1'

if ($Unregister) {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Removed scheduled task '$TaskName'."
    } else {
        Write-Host "No scheduled task named '$TaskName' — nothing to remove."
    }
    return
}

if (-not (Test-Path -LiteralPath $Runner)) { throw "Runner not found: $Runner" }

$pwshPath = (Get-Command pwsh).Source
$action = New-ScheduledTaskAction `
    -Execute $pwshPath `
    -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -File `"$Runner`" -Days $Days" `
    -WorkingDirectory $VaultRoot

$trigger = New-ScheduledTaskTrigger -Daily -DaysInterval $DaysInterval -At $Time

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopIfGoingOnBatteries `
    -AllowStartIfOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 30) `
    -MultipleInstances IgnoreNew

# Interactive logon type => runs as you, when you're logged in, no password stored.
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Limited

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Scans vault for loose/untagged/orphan notes and writes a propose-only triage note to Scratch/Vault Triage/. Never edits existing notes." `
    -Force | Out-Null

$cadence = if ($DaysInterval -eq 1) { 'daily' } else { "every $DaysInterval days" }
Write-Host "Registered '$TaskName' — $cadence at $Time (look-back ${Days}d)."
Write-Host "Run now:    Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "Remove:     pwsh -NoProfile -File `"$PSCommandPath`" -Unregister"
