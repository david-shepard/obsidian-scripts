#Requires -Version 7.0
<#
.SYNOPSIS
    Scheduled entry point: scan octo-vault, then have Claude write a dated triage
    proposal note. Invoked by the "Obsidian Vault Triage" scheduled task.

.DESCRIPTION
    Two stages:
      1. vault-scan.ps1 produces a markdown digest of candidate notes (cheap, local).
      2. `claude -p /vault-triage <digest>` reasons over the digest and writes
         Scratch/Vault Triage/Triage YYYY-MM-DD.md.

    PROPOSE-ONLY is enforced twice: the /vault-triage prompt forbids edits, AND
    this launcher denies Edit/Bash at the harness level, so the run structurally
    cannot move, rewrite, or delete an existing note. Write is permitted because
    the triage note itself is a new file.

.EXAMPLE
    pwsh -NoProfile -File .claude\scripts\run-vault-triage.ps1 -Days 3
#>
[CmdletBinding()]
param(
    [int]$Days = 3,
    [int]$MaxRecent = 30,
    # Generate the digest and print what would run, without invoking Claude.
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VaultRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).Path
$LogDir    = Join-Path $VaultRoot '.claude\logs'
$CacheDir  = Join-Path $VaultRoot '.claude\.triage-cache'
$Stamp     = Get-Date -Format 'yyyy-MM-dd'
$LogFile   = Join-Path $LogDir "vault-triage-$Stamp.log"
$Digest    = Join-Path $CacheDir "digest-$Stamp-$((Get-Date).ToString('HHmm')).md"

foreach ($d in @($LogDir, $CacheDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
}

function Log([string]$Message, [string]$Level = 'INFO') {
    $line = "[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding utf8NoBOM
    Write-Host $line
}

$exitCode = 0
try {
    Log "=== Vault (interactive) triage run starting ==="
    Log "Vault: $VaultRoot | window: ${Days}d | cap: $MaxRecent"

    # --- Stage 1: scan -----------------------------------------------------
    # vault-scan.ps1 runs with -ErrorActionPreference Stop, so a failure throws
    # rather than setting an exit code.
    & (Join-Path $PSScriptRoot 'vault-scan.ps1') -Days $Days -MaxRecent $MaxRecent -OutFile $Digest
    if (-not (Test-Path -LiteralPath $Digest)) { throw "vault-scan.ps1 produced no digest at '$Digest'." }

    $digestText = Get-Content -LiteralPath $Digest -Raw
    $candidates = if ($digestText -match '## Totals: (\d+) candidate') { [int]$Matches[1] } else { -1 }
    Log "Digest written: $Digest ($candidates candidates)"

    if ($candidates -eq 0) {
        Log "Nothing to triage. Skipping Claude invocation."
        return
    }

    # --- Stage 2: triage ---------------------------------------------------
    $claude = (Get-Command claude -ErrorAction SilentlyContinue)?.Source
    if (-not $claude) { throw "'claude' CLI not found on PATH." }

    # Note: removed `-p` arg for interactive mode
    $claudeArgs = @(
        "/vault-triage $Digest"
        '--permission-mode', 'acceptEdits'
        # Allowlist: read the vault, write ONE new triage note.
        '--allowedTools', 'Read', 'Glob', 'Grep', 'Write'
        # Denylist is the real guarantee: no mutation of existing notes, no shell.
        '--disallowedTools', 'Edit', 'NotebookEdit', 'Bash', 'WebFetch', 'WebSearch'
    )

    if ($DryRun) {
        Log "DRY RUN — would invoke: claude $($claudeArgs -join ' ')"
        return
    }

    Log "Invoking Claude..."
    Push-Location $VaultRoot
    try {
        # commenting this out to run interactively
        # $output = & $claude @claudeArgs 2>&1 | Out-String
        & $claude @claudeArgs
        $claudeExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }

    # Add-Content -LiteralPath $LogFile -Value $output -Encoding utf8NoBOM
    if ($claudeExit -ne 0) { throw "claude exited $claudeExit" }

    $triageNote = Join-Path $VaultRoot "Scratch\Vault Triage\Triage $Stamp.md"
    if (Test-Path $triageNote) {
        Log "Triage note ready: Scratch/Vault Triage/Triage $Stamp.md"
    } else {
        Log "Claude finished but no triage note was found at '$triageNote'." 'WARN'
    }
    Log "=== Run complete ==="
    Log "=== Output ==="
    Get-Content $triageNote
}
catch {
    Log $_.Exception.Message 'ERROR'
    Log ($_.ScriptStackTrace) 'ERROR'
    $exitCode = 1
}
finally {
    # Retention: 30 days of logs, 7 most recent digests.
    Get-ChildItem $LogDir  -Filter 'vault-triage-*.log' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } |
        Remove-Item -Force -ErrorAction SilentlyContinue
    Get-ChildItem $CacheDir -Filter 'digest-*.md' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -Skip 7 |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

exit $exitCode
