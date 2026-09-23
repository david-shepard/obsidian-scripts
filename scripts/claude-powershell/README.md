# Claude Vault Triage (PowerShell)
Notes are just files, and agents can read, write, and reason over them directly. In my vault, I use [claudian](https://github.com/YishenTu/claudian) — a Claude Code plugin for Obsidian vaults, along with these powershell scripts to perform some upkeep on my vault.

Scheduled, **propose-only** housekeeping for an Obsidian vault. A local PowerShell scan finds loose, untagged, and orphaned notes, then [Claude Code](https://docs.claude.com/en/docs/claude-code/overview) reads that digest and writes one dated triage note recommending where things should be filed, tagged, and linked.

It never edits, moves, renames, or deletes an existing note. You review the proposal and decide what to apply.

## How it works

```
Scheduled task ──► run-vault-triage.ps1
                      │
                      ├─ Stage 1: vault-scan.ps1  (local, cheap)
                      │     └─► .claude/.triage-cache/digest-YYYY-MM-DD-HHmm.md
                      │
                      └─ Stage 2: claude /vault-triage <digest>
                            └─► Scratch/Vault Triage/Triage YYYY-MM-DD.md
```

1. **Scan.** `vault-scan.ps1` walks the vault and writes a markdown digest of candidate notes: path, modified time, tags, inbound link count, flags (`untagged`, `orphan`, `no-frontmatter`, `no-outlinks`), a short content hint, and the vault's full folder taxonomy.
2. **Skip if clean.** If the digest reports zero candidates, Claude is never invoked.
3. **Triage.** Claude runs the `/vault-triage` slash command against the digest and sorts each candidate into one of: confident move, needs your call, tag fix, link suggestion, or leave alone.
4. **Write.** The result is a single new note under `Scratch/Vault Triage/`.

## Files

| File | Purpose |
|------|---------|
| `vault-triage.md` | Claude Code slash command (`/vault-triage`). Defines the procedure, classification rules, and output format. |
| `run-vault-triage.ps1` | Entry point. Runs the scan, invokes Claude with a locked-down tool set, logs, and cleans up old logs and digests. |
| `register-vault-triage-task.ps1` | Registers or removes the `Obsidian Vault Triage` Windows scheduled task. |

## Requirements

- Windows with **PowerShell 7+** (`pwsh`)
- **Claude Code CLI** (`claude`) on `PATH` and signed in
- **`vault-scan.ps1`** in the same folder as the runner (not included in this directory)
- A `CLAUDE.md` at the vault root that defines which folders are collaborative vs read-only (the command defers to it)

## Installation

The scripts resolve the vault root as **two levels above their own folder**, so placement matters:

```
<vault>/
├── CLAUDE.md
├── .claude/
│   ├── commands/
│   │   └── vault-triage.md
│   └── scripts/
│       ├── run-vault-triage.ps1
│       ├── register-vault-triage-task.ps1
│       └── vault-scan.ps1
└── Scratch/
    └── Vault Triage/        # created output lands here
```

Run the scripts from the vault root so the relative paths in the examples below resolve.

## Usage

### On demand, inside Claude Code

```
/vault-triage
```

With no argument, the command first checks whether today's triage note already exists. If it does, it summarizes the open items and stops without scanning or writing anything (one triage per day). If not, it runs the scan itself and writes the note.

Passing a digest path (`/vault-triage path/to/digest.md`) skips the scan. If today's note already exists in that case, a new `## Run HH:MM` section is appended rather than overwriting.

### On demand, from PowerShell

```powershell
pwsh -NoProfile -File .claude\scripts\run-vault-triage.ps1 -Days 3
```

Dry run (generates the digest and prints the Claude command without running it):

```powershell
pwsh -NoProfile -File .claude\scripts\run-vault-triage.ps1 -DryRun
```

### Scheduled

```powershell
# Daily at 9:07am (default)
pwsh -NoProfile -File .claude\scripts\register-vault-triage-task.ps1

# Every other day at 8:15am
pwsh -NoProfile -File .claude\scripts\register-vault-triage-task.ps1 -Time 08:15 -DaysInterval 2

# Run immediately
Start-ScheduledTask -TaskName 'Obsidian Vault Triage'

# Remove
pwsh -NoProfile -File .claude\scripts\register-vault-triage-task.ps1 -Unregister
```

The task runs as your user with an interactive logon, so no password is stored, and it only runs while you're logged in. If the machine was off at trigger time, it catches up at next logon. Overlapping runs are ignored and each run is capped at 30 minutes.

## Parameters

**`run-vault-triage.ps1`**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Days` | `3` | Look-back window passed to the scanner |
| `-MaxRecent` | `30` | Cap on candidate notes in the digest |
| `-DryRun` | off | Build the digest, skip the Claude call |

**`register-vault-triage-task.ps1`**

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-Time` | `09:07` | Local time of day (deliberately off the hour) |
| `-DaysInterval` | `1` | `1` = daily, `2` = every other day, up to `7` |
| `-Days` | `3` | Look-back window. Keep it `>= DaysInterval` so nothing falls through the gap |
| `-Unregister` | off | Remove the task |

## Safety model

Propose-only is enforced at two layers:

1. **Prompt level.** `vault-triage.md` forbids editing, moving, or deleting existing notes and treats `Clippings/`, `Archived/`, and `Dates/` as read-only zones (tag and link suggestions only).
2. **Harness level.** The runner launches Claude with an allowlist of `Read`, `Glob`, `Grep`, `Write` and a denylist of `Edit`, `NotebookEdit`, `Bash`, `WebFetch`, `WebSearch`. `Write` is allowed only because the triage note is a new file. Even if the prompt were ignored, the scheduled run has no tool that can modify an existing note or run a shell command.

Link suggestions are only made to notes Claude has confirmed exist via `Glob`.

## Output

`Scratch/Vault Triage/Triage YYYY-MM-DD.md` contains:

- A short read on where clutter is accumulating
- **Confident moves** (table: note, proposed home, reason)
- **Needs your call** (options with a stated lean)
- **Tag fixes** (current vs proposed, normalized to lowercase, hyphenated, slash-hierarchical)
- **Link suggestions** (1 to 3 verified targets per orphan)
- **Left alone** (one line each)
- **Apply** section. Reply to Claude with something like `apply confident moves 1-4 and all tag fixes`, or make the changes by hand.

## Logs and retention

| Path | Retention |
|------|-----------|
| `.claude/logs/vault-triage-YYYY-MM-DD.log` | 30 days |
| `.claude/.triage-cache/digest-*.md` | 7 most recent |

Consider adding both paths to `.gitignore`.

## Customizing for your vault

`vault-triage.md` contains examples tied to a specific vault layout (for example `Topics/Programming/Snippets/`, `Topics/Work/Jobs/`) and a list of tag remaps (`Kubernetes` to `kubernetes`, `Dev` to `devops`, and so on). Replace those with your own taxonomy and tag conventions before using it.