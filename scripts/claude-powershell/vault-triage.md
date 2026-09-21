---
description: Scan the vault for disorganized notes and write a dated triage proposal (never edits existing notes)
argument-hint: [path to a pre-generated scan digest]
allowed-tools: Read, Glob, Grep, Write, Bash
---

Produce a **vault triage proposal** — a single new note recommending how to file,
tag, and link the vault's loose ends.

## Hard constraints

**This command must not modify, move, rename, or delete any existing note.**
Per `CLAUDE.md`, `Topics/` and `Incoming/` are COLLABORATIVE (suggest, never edit)
and `Clippings/`, `Archived/`, `Dates/` are READ-ONLY. Every recommendation goes
into the triage note as a *proposal for the user to approve*. The only file you
create is the triage note itself.

If you catch yourself reaching for `Edit`, or a `mv`/`Move-Item`/`git` command —
stop. That is the user's decision, not yours.

## Procedure

1. **Get the scan digest.**
   - If `$ARGUMENTS` names a file, `Read` it. (The scheduled job pre-generates it.)
   - Otherwise, check for `Scratch/Vault Triage/Triage YYYY-MM-DD.md` using today's date.
     - **If it EXISTS: do not scan.** `Read` it, tell the user today's triage is
       already written, summarize the still-open items in 3-5 lines, and **stop**.
       Write nothing. One triage per day — the scan is expensive and a same-day
       re-run has no new data to work from.
     - If it does NOT exist, run:
       `pwsh -NoProfile -File .claude/scripts/vault-scan.ps1 -Days 3`

   The digest lists candidate notes with path, mtime, tags, inbound-link count,
   flags (`untagged`, `orphan`, `no-frontmatter`, `no-outlinks`), a content hint,
   and the vault's full existing folder taxonomy.

2. **Work from the digest first.** The content hint plus path is usually enough to
   place a note. Only `Read` a note when the hint is genuinely ambiguous and the
   placement decision hinges on it — cap this at ~8 reads per run so the scheduled
   job stays cheap.

3. **Classify each candidate** into one of:

   - **Confident file** — an obvious home exists in the taxonomy. A Bash-snippet
     note belongs in `Topics/Programming/Snippets/`; a job posting in
     `Topics/Work/Jobs/`; a game entry in `Topics/Gaming/Games list/`.
   - **Needs a call** — plausibly fits two or more folders, or would require a new
     subfolder. Present the options and your lean; do not pick silently.
   - **Tag fix** — missing/empty tags, or tags that violate the normalized
     conventions (lowercase, hyphen-separated, slashes for hierarchy). Watch for
     stragglers from the Aug 2026 remap: `Game`→`game`, `Gaming`/`games`/`pcgaming`
     →`gaming`, `Kubernetes`/`kubernetes-and-docker`→`kubernetes`, `Dev`→`devops`.
   - **Link suggestion** — an orphan that has a natural parent or sibling. Verify the
     target exists (`Glob`) before suggesting `[[Target]]`; never propose a link to a
     note you have not confirmed. Prefer 1-3 high-value links over a shotgun.
   - **Leave alone** — deliberately transient (`TODO/`, `Dates/`, `Scratch/`),
     already well-filed, or too thin to place. Say so in one line and move on.

4. **Respect the zones.** Never propose moving anything out of `Clippings/`,
   `Archived/`, or `Dates/` — for those, tag and link suggestions only.

5. **Write the triage note** to `Scratch/Vault Triage/Triage YYYY-MM-DD.md` using
   today's date. Normally the file will not exist — step 1 stops the run if it does.
   The one exception is an explicit `$ARGUMENTS` digest: there, append a new
   `## Run HH:MM` section rather than overwriting.

## Triage note format

```markdown
---
tags: [vault-maintenance]
date created: <Weekday, Month Nth YYYY, h:mm:ss am/pm>
date modified: <same>
---

## Triage — YYYY-MM-DD

<One-paragraph read on the vault's current state. What is actually accumulating,
and where. Skip this if nothing meaningful changed since the last run.>

### Confident moves (N)

| Note | → Proposed home | Why |
|------|-----------------|-----|
| `Incoming/Foo.md` | `Topics/DevOps/Terraform/` | Terraform module walkthrough; matches 12 existing notes there |

### Needs your call (N)

- `path/to/Note.md` — could go to `A/` (reason) or `B/` (reason). **Lean: `A/`** because …

### Tag fixes (N)

| Note | Current | Proposed |
|------|---------|----------|
| `path.md` | `Kubernetes, kubernetes-and-docker` | `kubernetes` |

### Link suggestions (N)

- `path/to/Orphan.md` → add `[[Verified Target]]` (both cover X)

### Left alone

<One line each, grouped — do not pad this section.>

### Apply

Reply to Claude with e.g. `apply confident moves 1-4 and all tag fixes`,
or edit by hand in Obsidian.
```

## Conventions

- Wikilinks: `[[Note Name]]` — Title Case, no path, no `.md`.
- Frontmatter dates use the vault's long format, e.g.
  `Thursday, August 6th 2026, 3:16:00 am`.
- Be decisive and brief. A triage note the user won't read is worthless — if a
  section is empty, write `_None._` and move on. Do not restate the digest.
- Never invent a destination folder that isn't in the taxonomy without flagging it
  explicitly as a new-folder proposal.
