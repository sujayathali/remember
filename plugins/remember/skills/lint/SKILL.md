---
name: lint
description: Runs a layered health-check across the memory system — atomic files (5 types incl. glossary, v1.1), journal, TASKS.md, CLAUDE.md (with hot-cache budget + promotion/demotion suggestions, v1.1), wiki. Catches filename violations, missing YAML, duplicates, MEMORY.md orphans, journal drift, stale tasks, broken cross-references, contradictions, stale content. Silently tolerates productivity-format files (non-interference, v1.1). v0.8.1+ absorbs the Migrate skill — auto-fixes legacy layouts. Writes a dated report. Use when the user types "Lint" or "Migrate" or asks to "check my memory", "audit my system", "find drift", "run a health check", "clean up my system", "upgrade my memory layout", "fix my memory structure", or "clean up legacy memory".
---

# Lint — Memory System Health Check

A periodic audit across every layer of the memory system. Catches the kinds of drift that accumulate silently and degrade the system over time.

**Immediate acknowledgment (NEW in v0.8.4):** Before doing any tool calls, IMMEDIATELY output a one-line acknowledgment so the user knows Lint is running. Pattern:

> "Running the memory health check now. I'll scan atomic files, journal, CLAUDE.md, and the wiki if present."

Then proceed with Step 0 below.

## When to run this

- The user types "Lint" or similar
- Every 2–4 weeks as housekeeping
- After a big content push (lots of Remember runs in a short period)
- Before sharing a folder externally

## Step 0: Layer detection

Before running any checks, determine the **active layout** for this folder by looking for memory in two possible locations:

- `<root>/memory/` — personal-folder layout (memory at root)
- `<root>/remember/memory/` — code-repo layout (memory inside `remember/` wrapper)

Whichever exists is the active layout. Set `<active>` to that location (either `<root>` or `<root>/remember/`). All subsequent checks use the active layout's paths.

If NEITHER exists → there's nothing to lint. Report "no memory system found at this folder" and stop.

### Step 0a: Remember-bootstrapped vs productivity-only detection (new in v1.1)

A folder may have a `memory/` subfolder that was created by another plugin (productivity:memory-management uses the same path). Before treating it as "Remember-bootstrapped", confirm. Classification:

- **Remember-bootstrapped**: `<active>/CLAUDE.md` contains the marker `## Continuous active maintenance` OR `Active maintenance:` line — OR — at least 3 of the 5 Remember type subfolders exist (`feedback`, `projects`, `reference`, `people`, `glossary`).
- **Productivity-only**: `<active>/memory/` exists but neither marker matches. Likely productivity:memory-management's structure (people/projects/context/glossary.md but no feedback/ or reference/, and no Remember CLAUDE.md sections).
- **Mixed**: both signals present — common when coexistence is active. Treat as Remember-bootstrapped; Lint will use productivity-tolerance checks for the productivity-format files within.

For productivity-only folders: Lint reports the layout and offers to chain to Bootstrap to convert into Remember-bootstrapped (which preserves the productivity files per Tenet 14). Does NOT auto-Bootstrap — that would surprise the user.

For Remember-bootstrapped (the common path): proceed with all checks below.

Then scan for which layers are present within the active layout:

| Layer | Present if | Checks to run |
|---|---|---|
| Atomic memory | `<active>/memory/{feedback,projects,reference,people,glossary}/` exists (5 atomic-type folders as of v1.1) | Always |
| Glossary (v1.1) | `<active>/memory/glossary/` OR `<active>/memory/glossary.md` exists | If present (new checks 1k, 1l) |
| Journal | `<active>/memory/journal/` exists | Always (foundational) |
| MEMORY.md | `<active>/memory/MEMORY.md` exists | Always |
| TASKS.md | `<active>/TASKS.md` | If present |
| CLAUDE.md (active) | `<active>/CLAUDE.md` | If present (light pass; v1.1 hot-cache checks) |
| CLAUDE.md (root, code-repo) | `<root>/CLAUDE.md` (when `<active>` ≠ `<root>`, i.e., code-repo layout) | If code-repo layout, check for pointer (Layer 4c) |
| Wiki | `<active>/wiki/` folder with `CLAUDE.md` or pages | If present (six checks) |

Skip cleanly any layer that's not present — don't flag absence as an error. A narrow personal-admin folder with no wiki is a valid configuration. A code repo with no wiki is also valid.

Report at the top of the lint output which layers were checked vs skipped, AND which layout was detected (personal-folder layout vs code-repo `remember/` layout).

## Layer 1: Atomic memory checks

For all `memory/{feedback,projects,reference,people,glossary}/*.md` files (5 atomic-type folders as of v1.1):

### 1a. Filename rule violations
- Files at `memory/` root (should be in a type subfolder) — EXCEPT `memory/glossary.md` and `memory/MEMORY.md` which are intentional root files
- Files with underscores in filename (e.g. `passport_expiry.md` — should be hyphenated)
- Files with type prefix in the slug (`feedback_visa.md`, `project_london.md`, `reference_passport.md`, `user_alex.md`, `glossary_psr.md` — the subfolder IS the type)
- Filenames that aren't lowercase

For each violation, propose the correct path. Flag in the report; offer auto-fix in the closing prompt (v0.8.1 absorbs Migrate's auto-execution into Lint — see "Migration auto-fix" section near the end of this skill).

### 1b. Missing or malformed YAML frontmatter
- Files missing the opening `---`
- Files missing required fields (`name:`, `description:`, `type:`)
- Files where `type:` doesn't EXACTLY match the subfolder name (e.g. `feedback/x.md` with `type: project`, or `glossary/psr.md` with `type: reference`)
- **Canonical type values (v1.1):** `type:` is the literal folder name. The 5 allowed values are `feedback`, `projects` (plural), `reference`, `people`, `glossary`. Legacy `type: project` (singular) from v1.0 atoms is read transparently but flagged with auto-fix offer (rename to `projects`).

For each, show the file path and what's missing.

**Exception (v1.1, Tenet 14):** files in `memory/people/`, `memory/projects/`, `memory/context/` WITHOUT YAML frontmatter are productivity-format files written by another plugin. DO NOT flag these in check 1b. They are tracked separately by check 1l (silent tolerance) and informed about there.

### 1c. Duplicate-concept files
Cluster filenames by token similarity (split on `-`, compare token sets). Flag clusters of 2+ files in the same type subfolder that look like they cover the same topic.

Example: `feedback/visa-doc-rules.md` and `feedback/visa-document-organization.md` → flag as potential duplicate; recommend consolidation.

**Exemptions (v1.3+):**
- Filenames matching `^(weekly|monthly)-milestones-` are period-indexed roll-ups, NOT duplicates. `weekly-milestones-2026-W24.md` and `weekly-milestones-2026-W25.md` share 3 of 4 tokens but represent distinct periods (PL S2). Exempt from clustering.
- Filenames matching `^weekly-milestones-gap-` (PL S8 catch-up gap pattern) — same exemption.

Do NOT auto-merge.

### 1d. MEMORY.md orphans (v1.4 — auto-fix via canonical regen script per TD-25)
- Entries listed in `MEMORY.md` whose underlying file no longer exists → flag, then offer auto-fix via the canonical regen script
- Files that exist on disk but aren't in `MEMORY.md` → flag, then offer auto-fix via the canonical regen script

**Auto-fix path (v1.4 TD-25):** if 1d flags any orphan or missing entry, surface a single closing prompt:

> "MEMORY.md has {N} orphan(s) and {M} missing entry/entries. Regenerate the index now? (yes / no)"

If the user replies **yes**, run this command VERBATIM (v2.0.2 — single verbatim invocation per PL-066):

```bash
# === v2.0.1 plugin-root inline bootstrap (DO NOT MODIFY) ===
# Resolves $PLUGIN_ROOT to the Mac-absolute mount path of this plugin's install dir.
# Disambiguates by plugin name (not install-ID) so it works across Cowork sandbox + Claude Code.
PLUGIN_ROOT=""
for _d in "${CLAUDE_PLUGIN_ROOT:-}" /sessions/*/mnt/.remote-plugins/*/; do
  [ -d "$_d" ] || continue
  _pj="$_d/.claude-plugin/plugin.json"
  [ -f "$_pj" ] || continue
  if grep -q '"name"[[:space:]]*:[[:space:]]*"remember"' "$_pj" 2>/dev/null; then
    PLUGIN_ROOT="${_d%/}"
    break
  fi
done
unset _d _pj
if [ -z "$PLUGIN_ROOT" ]; then
  echo "BOOTSTRAP ERROR: cannot resolve Remember plugin root. Searched: \$CLAUDE_PLUGIN_ROOT, /sessions/*/mnt/.remote-plugins/*. The plugin install may be missing or this script is running outside a supported runtime." >&2
  exit 1
fi
# Optional: source the richer helper for downstream operations
[ -f "$PLUGIN_ROOT/scripts/plugin-helper.sh" ] && . "$PLUGIN_ROOT/scripts/plugin-helper.sh"
# === end inline bootstrap ===

python3 "$PLUGIN_ROOT/scripts/regen-memory-index.py" --memory-dir "<sandbox-mount-path>/memory/"
```

Substitute `<sandbox-mount-path>` from the system prompt's mounted-folders list. Exit 0 = regenerated. Non-zero = surface stderr to the user; do NOT hand-build MEMORY.md.

### 1e. Stale "open" projects
For `memory/projects/*.md`:
- mtime > 6 months AND content mentions "open", "in progress", "to do", "pending" without a recent dated update → flag for review

Don't archive automatically. Just suggest the user revisit.

**Exemption (PL NB3 v1.3 fix):** filenames matching `^(weekly|monthly)-milestones-` and `^weekly-milestones-gap-` are period snapshots — historical by design. They will always have "Open questions carrying forward" sections (matching the prose pattern) and will always age past 6 months (no recent update is correct — milestones describe their period). **Skip 1e entirely for milestone atoms.**

### 1g. Concept-oriented slug check (new in v0.8.0)

Per Matuschak — Evergreen Notes should be concept-oriented, not source-oriented. Slugs that describe the document a fact came from (rather than the concept the fact is about) reduce reusability.

**Heuristic for "source-oriented":** the slug contains markers that look like sources rather than concepts:
- Date stamps: `*-2026-q2.md`, `*-may-2026.md`, `*-2026-05-15.md`
- Meeting markers: `*-board-meeting.md`, `*-1on1.md`, `*-call-notes.md`
- Document markers: `*-from-pdf.md`, `*-doc-extract.md`, `*-readme-summary.md`

For each atomic file whose slug matches a source-oriented pattern, flag it (warn, don't error). Suggest a concept-oriented alternative:

```
- memory/projects/project-board-meeting-2026-q2.md
  Suggests: rename to a concept-oriented slug like alpha-q4-strategy-decisions.md
  Source attribution (which meeting, when) belongs in `ingested_from` YAML field,
  not the filename.
```

**Skip the warning if:**
- The slug actually IS the concept (e.g., `wedding-2026.md` is a concept — the wedding is the project)
- The file was created less than 7 days ago (let the user settle on naming before flagging)
- A prior lint already flagged this same file (check `lint-*.md` history)
- **The slug matches `^(weekly|monthly)-milestones-` (v1.3+) — Checkin auto-generates these as the canonical milestone period containers. The period IS the concept; flagging them as source-oriented is wrong.** Also covers the catch-up gap pattern `^weekly-milestones-gap-` (PL S8).

Do NOT auto-rename. The user knows their concepts better than the heuristic.

### 1h. People mentioned without profile (new in v0.8.0)

The plugin now auto-captures new people with substantive context (via Remember + Ingest + continuous maintenance). This check verifies the auto-capture is working — any person referenced across atomic files but lacking a profile is either (a) an entity the plugin missed, or (b) a name-drop that shouldn't have been mentioned in a durable atom.

**Method:**

1. Glob `memory/{projects,reference,feedback}/*.md`
2. For each file, scan for proper-name mentions (capitalized names that aren't at start of sentence; or names appearing in patterns like "{name} approved/decided/said/told")
3. For each unique name found, check if `memory/people/{name-slug}.md` exists
4. If not → flag as a potential missing profile

**Report format:**

```
- "Alex" referenced in: memory/projects/alpha-status.md, memory/projects/alpha-q4-strategy.md
  No profile found at memory/people/alex.md
  Action: create profile with substantive context (role at MyProject, etc.), or — if name-drop only — consider removing the reference
```

**Skip:**
- Pure name-drops mentioned once in passing
- Names that are clearly external references (e.g., "as Karpathy said")
- Common first names without distinguishing context

This is a warn-not-error check.

### 1j. Scratch-space atoms (new in v0.8.6)

A failure mode observed on 2026-06-09: Claude wrote atomic files to `/sessions/*/mnt/memory/` (session VM root, invisible to user's Mac) instead of the actual mounted folder. Pre-flight checks now prevent this prospectively, but historical atoms might still exist in scratch paths if anyone hit this bug before upgrading.

**Detection:**

Run bash to check if `/sessions/*/mnt/memory/` exists at the session VM root (not inside a connected folder). If atomic files exist there:

1. List them in the lint report with verbatim ls output
2. Offer recovery: "Found {N} atomic files at session scratch space. These won't persist to your Mac. I can migrate them to the active layout at `<active>/memory/` — merging with existing files where slugs match. Want me to do that? (yes / show-each / no)"

**Recovery execution (on yes):**

For each file at `/sessions/*/mnt/memory/<type>/<slug>.md`:
- If `<active>/memory/<type>/<slug>.md` exists → read both, merge content (preserve unique facts), update `ingested_from` array
- If not exists → move the file to `<active>/memory/<type>/<slug>.md` (Write at new path, then delete scratch original)
- After migration, regenerate MEMORY.md

**Why this is important:** users on older plugin versions (pre-v0.8.5) may have had captures land in scratch space without realizing it. This check finds and recovers them.

### 1i. Legacy `ingested_from` schema (new in v0.8.2)

v0.8.2 changed the `ingested_from` field in atomic YAML frontmatter from a string array to an object array (with `path`, `hash`, `ingested_on`). Atoms written by v0.8.0 or v0.8.1 may still have the legacy string-array format. The plugin reads both formats transparently, but the legacy format misses change detection (no hash recorded) — every re-ingest will see those atoms as "potentially changed" because the hash is unknown.

**Detection:**

For each atomic file with an `ingested_from` field, check the schema:
- Items are strings → legacy format. Flag for migration.
- Items are objects with `path`, `hash`, `ingested_on` → current format (filesystem source). No action.
- **Items are objects whose `path` matches `^[a-z][a-z0-9+-]*:` URI-scheme regex (v1.2 — connector references)** → current format (connector source). `source:` field expected instead of `hash:` (connector content has no stable file hash). **No action — DO NOT offer normalization. DO NOT attempt to compute a hash.** See `skills/checkin/SKILL.md` security frame for the convention definition.
- Mixed (some strings, some objects) → flag as broken; offer to normalize.

**Migration auto-fix offer:**

If 1+ atoms have legacy `ingested_from`:

```
{N} atoms still use the legacy v0.8.0/v0.8.1 ingested_from schema (string array). 
Migrating to v0.8.2+ object array would enable change detection — Ingest could 
then automatically detect when a source document was edited.

Migration is non-destructive: for each existing entry, recompute the hash from 
the current file (if it exists), or mark as "unknown-pre-v0.8.2" if the file is 
gone. The `path` field is preserved.

Apply migration? (yes / show-each / no)
```

If user picks **yes**:
- For each affected atom, read the YAML
- For each legacy string entry in `ingested_from`:
  - **If the string matches `^[a-z][a-z0-9+-]*:` URI-scheme regex (v1.2 — pre-existing connector ref)** → convert to `{path: <string>, source: "legacy-connector", ingested_on: <today>}`. Do NOT attempt hash computation.
  - Otherwise (filesystem path): check if `{folder root}/{path}` exists
  - If yes: compute hash via `md5sum {file} | cut -d' ' -f1`
  - If no: use `hash: "unknown-pre-v0.8.2"` and add an `orphan: true` flag
- Write back with new object-array format
- Preserve `last_ingested_on` (or set to today's date if missing)

If user picks **show-each**: walk one atom at a time with confirm.

If user picks **no**: leave the legacy schema; next Ingest will read it correctly via fallback path. Lint will surface again next time.

### 1f. Suspected contradictions across atomic memory (new in v0.7.0)

Scan all atomic memory files to detect conflicting facts about the same entity.

**Method:**

1. Build an entity index. For each file in `memory/{reference,people,projects}/`:
   - Extract entity name from YAML `name:` field
   - Extract entity name from filename slug (e.g., `alex.md` → entity = "alex")
   - Group files that look like they're about the same entity (loose match — same slug, similar tokens, or shared name fields)

2. For each entity group with 2+ files, check for contradictions in:
   - **Numeric values** — different amounts, dates, counts, identifiers
   - **Status assertions** — "active" vs "inactive", "complete" vs "open", "married" vs "single"
   - **Entity attributes** — different titles, roles, employers, addresses, phone numbers
   - **Entity name spelling** — "Alex" vs "Alexis" — flag as possible typo or different entity

3. For each suspected contradiction, capture:
   - Which files conflict
   - The exact conflicting claims (quoted with line numbers)
   - Suggestion: which is likely correct (the more recent file usually wins, unless dated otherwise)

**Examples that should flag:**
- `memory/reference/alex-contact.md` says "phone: +91-9000111222" AND `memory/people/alex.md` says "phone: +91-9000222333" → flag
- `memory/projects/project-investment.md` says "stake: 2.5%" AND `memory/reference/project-cap-table.md` says "stake: 1.8%" → flag
- `memory/people/alex.md` says "Alex" AND `memory/people/alexis.md` exists → flag (probable duplicate)

**What NOT to flag:**
- Same entity, different attributes (e.g., "phone" vs "email" for the same person)
- Different entities with similar names but distinguishing context (e.g., "Alex (MyProject)" vs "Alex (ProjectB)" if both files make the distinction clear)
- Facts that evolve naturally (e.g., a project's status changing over time — that's history, not contradiction)

**Do NOT auto-resolve.** Always flag for human review. Contradictions are judgment calls; the wrong "fix" can lose context.

**Exemption for milestone atoms (PL NB3 v1.3 fix):** atoms matching `^(weekly|monthly)-milestones-` and `^weekly-milestones-gap-` are **period snapshots** — their assertions describe the state DURING the period, not the current state. A weekly milestone saying "Phoenix: in-review → closed" for week W24 is not a contradiction with a current `phoenix.md` saying "status: active" — Phoenix may have been reopened after the milestone period. **Treat milestone assertions as dated-historical claims; never pair them against live atoms in 1f.** When checking for contradictions, only compare milestone atoms against OTHER milestone atoms for the same period (and even then, only if the periods overlap, which they normally don't by design).

**Report format:**
For each contradiction:
```
- Entity: "{entity name}"
  - File A: `memory/reference/alex-contact.md:8` — "phone: +91-9000111222"
  - File B: `memory/people/alex.md:12` — "phone: +91-9000222333"
  - Likely correct: File B (more recent, mtime 2026-05-15 vs A's 2026-01-08)
  - Action: review and consolidate; older file may have a stale value
```

### 1k. Glossary structure consistency (new in v1.1)

The glossary has two surfaces: the shared `memory/glossary.md` table (productivity-compatible) and the atomic mirror folder `memory/glossary/`. They should be roughly aligned.

**Checks:**

1. **glossary.md exists if atomic mirrors exist.** Glob `memory/glossary/*.md`. If 1+ files exist but `memory/glossary.md` is missing → flag as inconsistency. Offer auto-fix: regenerate `memory/glossary.md` from the atomic mirrors.

2. **Atomic mirror coverage.** For each row in `memory/glossary.md` (parse the table), check if a corresponding atomic file exists at `memory/glossary/{slug}.md`. Missing mirrors are OK (they're optional, especially for productivity-authored rows), but flag the count:
   > "{N} rows in memory/glossary.md don't have atomic mirrors. To enrich them with provenance, run Ingest."

3. **Reverse coverage.** For each atomic file in `memory/glossary/`, check if its term has a row in `memory/glossary.md`. If not, that's a bug — Remember should have appended the row when creating the atom. Flag:
   > "Atomic mirror exists without corresponding glossary.md row: memory/glossary/{slug}.md. Action: append a row to glossary.md (Remember should have done this; possible historical capture bug)."

4. **Append-only audit.** Compare `memory/glossary.md` mtime to the last lint report (if any). If the file's content shows any rows that were modified (not just appended), that's a tenet violation. Hard to detect statically — Lint warns ONLY if the file content has shrunk between lint runs (would indicate row deletion). Reports informationally only.

**Do NOT auto-modify `memory/glossary.md`.** The append-only rule applies to Lint too — Lint may suggest fixes but only applies them to atomic mirror files, never to `memory/glossary.md`.

### 1l. Productivity-format file tolerance (new in v1.1 — Tenet 14)

If the user has the productivity:memory-management plugin installed alongside Remember, some files in `memory/people/`, `memory/projects/`, `memory/context/` will be written in productivity's format (plain markdown, no YAML frontmatter). Same for content rows in `memory/glossary.md` that productivity authored.

**Per Tenet 14 (Non-interference), these files are LEFT ALONE.** Lint:
- Does NOT flag them as malformed (check 1b explicitly excludes them)
- Does NOT auto-convert them
- Does NOT include them in duplicate-concept clustering (check 1c)
- Does NOT include them in MEMORY.md orphan checks (check 1d)
- Does NOT include them in stale-open project checks (check 1e — v1.1)
- Does NOT include them in contradiction detection (check 1f) — see special handling below
- Does NOT include them in slug-heuristic checks (check 1g)
- Does NOT include them in people-without-profile checks (check 1h)

**Special handling for check 1f (contradiction detection):** a Remember mirror is RELATED to its productivity-format source by `mirror_of:` (e.g., `memory/people/todd-r.md` mirrors `memory/people/todd.md`). They cover the same entity by design. Check 1f must NOT flag a `mirror_of:` pair as a probable duplicate. Instead, compare the mirror against the source: if the mirror's body asserts facts that contradict the source (factual divergence), surface that as **informational** ("mirror appears stale vs source"). This is the only case where Lint reads productivity-format content — read-only, for divergence detection only.

**Mirror identification (v1.1):** check 1l identifies mirrors via the `mirror_of:` YAML field, NOT the `-r` filename suffix. The suffix is a human affordance (alphabetical adjacency in Finder/Obsidian); the YAML field is the authoritative signal. This handles the edge case of a real person whose slug naturally ends in `-r` (e.g., "Omar R" → `omar-r`).

**What Lint DOES do:**

Report their presence informationally so the user knows what coexists:

```
## Productivity-format files (v1.1 silent tolerance)

Detected {N} files in productivity:memory-management format:
- memory/people/: {N} files (e.g., todd.md, alice.md)
- memory/projects/: {N} files (e.g., phoenix.md)
- memory/context/: {N} files (e.g., company.md, teams.md)
- memory/glossary.md content rows: {N} rows likely productivity-authored

These files are NEVER modified by Remember. To create Remember atomic mirrors (with full provenance, maturity, confidence), type Ingest — mirrors get the `-r` suffix (e.g., memory/people/todd-r.md) and the originals stay untouched.

Mirrors detected: {N} files (identified via `mirror_of:` YAML field — the authoritative signal; the `-r` filename suffix is a human affordance only).
Productivity files without mirrors: {N} (could be enriched on next Ingest).
```

This is purely informational — never an error, never a warning, never blocks Lint.

## Layer 2: Journal checks

For `memory/journal/*.md`:

### 2a. Date-mismatch (the bug from 2026-06-06)
For each journal file, parse the top-level `# YYYY-MM-DD` header (if present) and compare to the filename. Flag mismatches.

Also flag files containing a `## HH:MM — PM session` or `## continued` or `## session 2` style subheader where the file's date is in the past — that's the classic "Claude appended today's content to yesterday's file" signature.

### 2b. Format consistency
- Files not following the `YYYY-MM-DD.md` filename pattern
- Files missing the top-level `# YYYY-MM-DD` header

### 2c. Date gaps (informational only)

### 2e. Verification-block fabrication backstop (new in v1.3 — TD-16 cross-check)

For the most recent journal entry (today + yesterday) carrying a `#### Verification` sub-header:
- Extract claimed file paths from the verification block (look for `ls -la` output lines)
- Compare each claimed path against the actual filesystem: does the file exist? Is the byte size within ±5% of the claimed size?
- If a claimed file does not exist OR its size deviates by more than ±5%, flag as **fabrication risk**:
  > "⚠️ Journal verification block at `{journal-path}` references files that don't match disk. Claimed: `{path}` ({claimed-bytes} bytes). Actual: {missing | actual-bytes bytes}. The verification may have been fabricated rather than read from bash. Run `/checkin` to refresh, OR investigate manually."

**Why this exists (TD-16 trust-anchor):** v1.3's TD-16 fix moves the verification block from chat to journal (Casey-voice cleanup). The chat one-liner ("Saved 5 notes ...") is derived from the journal block — never independently composed. If a future Claude were to skip the bash run and fabricate the journal block to produce a plausible chat one-liner, this check catches it within one lint cycle. The journal block is the trust anchor; this check verifies the anchor anchors.

### 2d. Milestone-atom gap nudge (new in v1.3 — TD-14 belt-and-suspenders, Tenet 1)

Detect: journals span **at least one complete week** (Sunday-start `%U` weeks; latest journal date ≥ 7 days after earliest journal in `<active>/memory/journal/`) AND `<active>/memory/projects/` contains **zero** files matching `^(weekly|monthly)-milestones-` (excluding `weekly-milestones-gap-*` which counts as coverage). When both conditions hold, surface:

> "{N} complete week(s) and {M} complete month(s) have passed since your first journal entry, but no milestone atoms exist. Run `/checkin` to synthesize them — Checkin Step 7.5 will catch up on overdue periods (capped at the 4 most recent complete weeks per PL S8)."

**Why this exists:** Checkin Step 7.5 is the actor for milestone synthesis; this Lint check is the auditor that catches the case where Step 7.5 has never been run, or was historically skipped before the v1.3 TD-14 fix made it mandatory. Tenet 1 (graceful guidance) — the user gets a one-line nudge, not an error.

**Backstop role:** if a future Step 7.5 silent skip ever happens (the v1.3 fix added the mandatory framing + load-bearing `Milestones:` line in the reply, but defense-in-depth is cheap here), Lint catches it on the next periodic run.
Count the gap between the most recent journal and today. If >14 days, note it as "memory system may be inactive — no Remember runs in the last N days." Not a defect — just a signal.

## Layer 3: TASKS.md checks (if present)

### 3a. Stale active tasks
For items in the `## Active` section:
- Items without dates anywhere → flag for adding context
- Items mentioning dates >90 days past with no `[x]` mark → flag as likely stale

### 3b. Done items pending archive (cosmetic)
If `## Done` has >30 items, suggest archiving the oldest to a dated snapshot file.

### 3c. Format checks
- Items not using `- [ ]` / `- [x]` markdown checkbox format
- Items under the wrong heading (e.g. completed items not yet moved to `## Done`)

## Layer 4: CLAUDE.md checks (light pass)

### 4a. Conventions consistency
If CLAUDE.md declares a convention (e.g. "no em dashes", "dates absolute YYYY-MM-DD"), spot-check a sample of recent atomic files and journal entries for violations. Flag a couple of examples; don't enumerate every violation.

### 4b. Mount-aware load order present for narrow-mount folders
If the project is at a path deeper than `Claude/Projects/<name>/` (e.g. `Claude/Projects/Personal/<sub>/`), check that CLAUDE.md includes the "Mount-aware load order" section. Flag if missing.

### 4c. Code-repo pointer integrity (new in v0.6.0)

If this is the **code-repo layout** (active layout is `<root>/remember/`), the root CLAUDE.md should contain a pointer section that tells Claude to read `remember/CLAUDE.md`.

Check: read `<root>/CLAUDE.md`. Does it contain `remember/CLAUDE.md` (either as a reference, an `@import` line, or in a "Personal notes & memory" section)?

- If yes → pass
- If no → flag as a high-priority issue. Without this pointer, future chats in this code repo won't auto-discover the personal-memory layer, and Claude won't know to read it when answering questions that need that context.

When flagging, also offer to auto-fix: include the standard pointer section in the lint's closing prompt for the user to add back. (The standard pointer block is defined in `bootstrap-memory-project`'s Code-repo prep section.)

Also check: does `<root>/.gitignore` exist AND contain `remember/`?
- If yes → pass
- If no → flag. Without this, the user's personal memory will accidentally get committed to git on their next `git add .`. Offer to auto-fix by appending `remember/` to `.gitignore` (or creating it).

### 4e. Continuous-maintenance section integrity (new in v0.7.4 — extended in v1.5 with pre-v1.4 detection + auto-migration)

The v0.7.4+ plugin generates project CLAUDE.md files with a "Continuous active maintenance" section that contains the always-loaded filename rules, classification guidance, conservative threshold, and the `Active maintenance: ON/OFF` toggle. This section is what gives Claude permission to update memory continuously during conversation (vs. only on explicit Remember invocations). v1.4 reimplemented CAM as a hook-driven three-part enforcement and added a next-turn extraction directive to the section; the v1.5 Lint check detects pre-v1.4 sections still in the field and offers migration.

Check `<active>/CLAUDE.md` (the project CLAUDE.md):

1. **Does it contain a `## Continuous active maintenance` section?**
   - Yes → proceed to step 2 (v1.4 cue check).
   - No → flag as a high-priority issue. Without this section, continuous behavior will not work — Claude will not have always-loaded permission to update files between Remember invocations. Offer to add the canonical v1.4 section (see `bootstrap-memory-project` SKILL.md lines 467-528 for the template).

2. **Does the section contain the v2.0 journal-first three-part cues?** (v2.0)
   - The phrase `journal-first` (Part 1 — distinguishes v2.0 from v1.4/v1.5.1 markers-based architectures)
   - The phrase `Maintained:` (Part 2 load-bearing reply line; in v2.0 surfaces on Remember-triggered atom commit)
   - The phrase `Stop hook` or `cam-snapshot.sh` (Part 1 mechanical boundary)
   - The phrase `three-part enforcement` (the architectural framing anchor)

   - **All four cues present** → v2.0 CAM section installed correctly. Pass. Note in the lint report that the v2.0 section is installed.
   - **Section exists but is missing any of the four cues** → classify by which cues ARE present:
     - If `.cam-inbox/` is present but `journal-first` is not → **v1.5.1 (or earlier) CAM section** that needs the v1.5.1 → v2.0 migration. The agent-side drain loop was the architectural defect the paper §3.3 named; v2.0's journal-first hook bypasses it. Flag as **medium-priority** and offer auto-migration (see step 4 below; the migration is mechanical and replaces the section with the v2.0 canonical).
     - If neither `.cam-inbox/` nor `journal-first` is present → **pre-v1.4 instruction-only CAM section**. The paper §3.3 names this exact shape as the failure mode. Flag as **high-priority** and offer the same auto-migration.

3. **Does the section contain an `Active maintenance: ON` or `Active maintenance: OFF` line?**
   - Yes → pass; note which state is set.
   - No → flag; missing the toggle makes the section ambiguous. Offer to add the line.

4. **v2.0.2 auto-migration — single verbatim invocation per PL-066**

   When step 2 detects a v1.x or pre-v1.4 CAM section, offer auto-migration. Surface in the lint report:

   > "Your CLAUDE.md is on a pre-v2.0 CAM section. The v2.0 architecture replaces the agent-side drain loop with a hook-driven journal-first append + Remember-triggered atom commit. The paper §3.3 names the pre-v2.0 shape as the failure mode v2.0 was designed to fix.
   >
   > Migrate? **Y/N**
   >
   > If Y, the existing `## Continuous active maintenance` section will be backed up to `CLAUDE.md.pre-v2.0-cam-backup` and replaced with the canonical v2.0 template. The marker file at `memory/.cam-folder-marker` will also be dropped/refreshed."

   On Y, look at the mounted-folders list in the system prompt. Identify TWO paths for the target folder:
   - The sandbox mount path (`/sessions/<id>/mnt/<folder>/`)
   - The Mac absolute path (`/Users/<you>/.../<folder>/`)

   Then run this command VERBATIM (substituting the 2 args):

   ```bash
# === v2.0.1 plugin-root inline bootstrap (DO NOT MODIFY) ===
# Resolves $PLUGIN_ROOT to the Mac-absolute mount path of this plugin's install dir.
# Disambiguates by plugin name (not install-ID) so it works across Cowork sandbox + Claude Code.
PLUGIN_ROOT=""
for _d in "${CLAUDE_PLUGIN_ROOT:-}" /sessions/*/mnt/.remote-plugins/*/; do
  [ -d "$_d" ] || continue
  _pj="$_d/.claude-plugin/plugin.json"
  [ -f "$_pj" ] || continue
  if grep -q '"name"[[:space:]]*:[[:space:]]*"remember"' "$_pj" 2>/dev/null; then
    PLUGIN_ROOT="${_d%/}"
    break
  fi
done
unset _d _pj
if [ -z "$PLUGIN_ROOT" ]; then
  echo "BOOTSTRAP ERROR: cannot resolve Remember plugin root. Searched: \$CLAUDE_PLUGIN_ROOT, /sessions/*/mnt/.remote-plugins/*. The plugin install may be missing or this script is running outside a supported runtime." >&2
  exit 1
fi
# Optional: source the richer helper for downstream operations
[ -f "$PLUGIN_ROOT/scripts/plugin-helper.sh" ] && . "$PLUGIN_ROOT/scripts/plugin-helper.sh"
# === end inline bootstrap ===

bash "$PLUGIN_ROOT/scripts/migrate-cam-section.sh" \
  "<sandbox-mount-path>" \
  "<mac-abs-path>"
   ```

   Read the JSON output from stdout. It contains a `status` field (`ok` or `error`) and an `honest_followup` field.

   **If `status` is `ok`:** present the friendly summary using the `honest_followup` field VERBATIM. The script handles: backup of the existing section, awk-replace with the v2.0 canonical template (read from `$PLUGIN_ROOT/templates/cam-section.md`), cue verification against `$PLUGIN_ROOT/templates/v2.0-cues.txt`, marker file drop at `memory/.cam-folder-marker`. The honest_followup line is the load-bearing claim about what was installed vs what still needs end-to-end verification — do NOT paraphrase or soften it.

   **If `status` is `error`:** surface the JSON dump to the user as a structured error. Do NOT mark the migration complete. The script may indicate the existing CLAUDE.md was restored from backup if a hard-fail happened mid-replace.

   This single verbatim invocation is the v2.0.2 PL-066 close: no awk/sed/grep procedure for the agent to paraphrase. The script is the single source of truth for the migration.

5. **Does the section contain inlined filename rules + classification?**
   - Yes → pass.
   - No → flag. Without these, continuous updates may write to wrong paths or with wrong types.

Same check for `<active>/wiki/CLAUDE.md` if a wiki exists:
- Does it contain `Active maintenance: ON/OFF` at the top?
- If no → flag; offer to add the standard section.

When flagging without the auto-migration path (steps 1, 3, 5 above), offer to auto-fix by adding the standard sections from the plugin's bootstrap template. Show the user what would be added before applying.

### 4d. Stale plugin-protocol references (new in v0.7.0)

The plugin has evolved through versions. Earlier versions used inlined CLAUDE.md protocols (Commit instead of Remember, `lint-wiki` instead of `lint`, etc.). Users who have CLAUDE.md files written before adopting the plugin (or from earlier plugin versions) may have stale references that no longer match current behavior.

Check `<active>/CLAUDE.md` and `<root>/CLAUDE.md` (if different) for these stale patterns:

| Stale pattern | Flag as | Suggested fix |
|---|---|---|
| "Commit protocol" / "Commit Protocol" / `"Commit"` as a trigger keyword | Legacy v0.0.x reference | Rename to "Remember Protocol" / "Remember" |
| "lint-wiki" as a trigger or skill name | Legacy v0.1.x reference | Rename to "lint" |
| `notes/CLAUDE.md` / `notes/memory/` / `@import notes/` | Legacy v0.6.0 reference (renamed in v0.6.1) | Rename to `remember/CLAUDE.md` / `remember/memory/` / `@import remember/` |
| Inlined Remember Protocol section with the old single-line Step 4 (just "Append a journal entry to `memory/journal/YYYY-MM-DD.md`") | Pre-v0.3.0 inlined protocol | Suggest removing the inlined version since the plugin now provides it |
| References to skills that no longer exist (e.g., `Goal`, `Checkpoint` in non-project-specific contexts) | Legacy commands from prior iterations | Flag for review; user may want to keep or remove |

For each found, flag in the lint report. Don't auto-rewrite — these often involve judgment about the user's prior intent. Offer the standard pointer/section content in the closing prompt so the user can choose to update.

**Skip this check if:**
- CLAUDE.md is very short (<200 chars) — probably a placeholder, no protocol to be stale
- CLAUDE.md was modified within the last 24 hours — likely just edited; let it settle
- The patterns above were already flagged in a prior lint report (check `lint-*.md` files for repetition)

**v0.8.1: Auto-fix legacy patterns inline (Migrate fully absorbed into Lint).**

If any of the patterns above triggered (especially the inlined Remember Protocol section), surface them in the lint report AND offer auto-fix in the closing prompt — Lint now handles all the migration logic directly (see "Migration auto-fix" section near the end of this skill).

**Why full absorption in v0.8.1:** Educational chaining (Tenet 9) means auto-chains should announce both what's happening and how to invoke directly next time. But for the Migrate → Lint case, there's no value in keeping Migrate as a separate command: every Migrate invocation already comes through Lint's detection. Folding the logic into Lint reduces the public surface area from 6 skills to 5 without any user-facing loss. Users who type "Migrate" still get Lint (via the absorbed trigger phrases in Lint's description). If demand emerges later for a separate "import from external systems" skill (Obsidian, Notion, etc.), we can reintroduce it under a different name (e.g., `import`).

### 4f. CLAUDE.md hot-cache budget (new in v1.1 — Tenet 15)

CLAUDE.md loads on every session — every line costs tokens forever. The hot-cache discipline target is ~150 lines total, with soft caps per section.

**Method:**

Read `<active>/CLAUDE.md`. Count lines (excluding the YAML front-matter block if present). Compare to targets.

**The budget targets user-content sections only — NOT the protocol boilerplate (v1.1; budget figure grew in v1.3).** The Bootstrap template's continuous-maintenance protocol block grew from ~95 lines (v1.1/v1.2) to **~130 lines (v1.3)** with the addition of T1/T2/T3 wiki refresh trigger rules. Counting boilerplate against a ~150-line total would make the budget unsatisfiable from day one. Lint excludes the following standard sections from the user-content budget (count their lines separately):

- `## Continuous active maintenance` (the protocol rules — Lint-protected boilerplate, NEVER edited by promote/demote; includes the v1.3 wiki refresh trigger sub-section)
- `## How to use this folder`
- `## Folder structure`
- `## Documented lookup flow`
- `## Hot-cache budget`
- `## Checkin configuration` (v1.2 — optional per-project config, varies in length per user; Lint never modifies)
- `## Refresh-wiki configuration` (v1.3 — optional per-project config, varies in length; Lint never modifies)

The user-content budget covers: `## Scope`, `## Quick Glossary`, `## Top people`, `## Active projects`, `## Project conventions`, and any user-added sections.

| Section | Target | Detection |
|---|---|---|
| User content (sum) | ~50 lines | Total minus boilerplate sections |
| Protocol boilerplate (sum) | ~130 lines (v1.3; grew from ~95 in v1.1) | Standard sections above |
| Total file | ~150 lines | `wc -l` |
| Quick Glossary table | ~20 rows | Count rows in `## Quick Glossary` table |
| Top people | ~10 entries | Count rows in `## Top people` (if section exists) |
| Active projects | ~5 entries | Count rows in `## Active projects` |

**Flag:**

- **User-content sum > 80 lines** → "CLAUDE.md user-content sections total {N} lines (target ~50). Suggest demoting unused entries to memory/."
- **Total > 200 lines** (informational) → "CLAUDE.md is {N} lines. Protocol boilerplate accounts for {B} lines; user content for {U}. Hot-cache action: demote user content if {U} > 80."
- **Quick Glossary > 30 rows** → "Quick Glossary has {N} rows (target ~20). Suggest demoting infrequent terms."
- **Total > 300 lines** → high priority. Token cost is meaningful — check whether boilerplate has bloated (compare against Bootstrap template length).

**Skip the check entirely if** the project's CLAUDE.md has no Quick Glossary section AND no hot-cache budget note (i.e., it was bootstrapped before v1.1 and the user hasn't run a Bootstrap re-run since). Lint reports informationally that this is a pre-v1.1 CLAUDE.md and could be upgraded via the Migration auto-fix (v1.1 patterns).

### 4g. Quick Glossary staleness + promotion/demotion suggestions (new in v1.1)

The Quick Glossary in CLAUDE.md should reflect the terms ACTUALLY used recently. Stale entries waste hot-cache budget; missing entries make Claude resolve references the slow way.

**Method:**

1. **Read `<active>/CLAUDE.md`** Quick Glossary section. Extract the list of terms currently in hot cache.

2. **Read recent journal entries.** Glob `memory/journal/*.md` for the last 30 days. Concatenate.

3. **Count term mentions in recent journal:**
   - For each term in Quick Glossary, count occurrences in the last 30 days of journal
   - For each term in `memory/glossary.md` NOT in Quick Glossary, also count

4. **Demotion candidates:** terms in Quick Glossary with 0 mentions in last 30 days. Flag for demotion.

5. **Promotion candidates:** terms in `memory/glossary.md` with 5+ mentions in last 30 days, NOT currently in Quick Glossary. Flag for promotion.

**Report format:**

```
## Quick Glossary suggestions (v1.1)

**Demote (no recent use, freeing hot-cache budget):**
- "OKR" — 0 mentions in last 30 days (still in memory/glossary.md)
- "PSR" — 0 mentions in last 30 days

**Promote (frequently used, would benefit from hot cache):**
- "Phoenix" — 14 mentions in last 30 days, currently only in memory/glossary.md
- "GTM" — 8 mentions in last 30 days

Apply these promotions/demotions? (yes / show-each / no)
```

**Same logic for top people and active projects.** If those sections exist in CLAUDE.md, apply the same promote/demote logic. If they DON'T exist yet (Bootstrap template only ships `## Quick Glossary` as the v1.1 placeholder), Lint creates them on first promotion — with this format:

```markdown
## Top people (Lint-managed, v1.1)

> Top ~10 most-mentioned people in the last 30 days of journal. Promoted by Lint; demoted by Lint when unused 30+ days.

| Name | Role | atom |
|---|---|---|

## Active projects (Lint-managed, v1.1)

> Top ~5 projects with status = active. Promoted by Lint; demoted by Lint when status changes.

| Project | Status | atom |
|---|---|---|
```

Mention in the report whether sections were created or pre-existing.

**Single-owner principle (cross-references Tenet 15):** Lint is the sole writer of these three sections (`## Quick Glossary`, `## Top people`, `## Active projects`). Remember NEVER touches them. If a user manually edits, the next Lint will preserve the manual edits but won't reconcile them against `memory/` — Lint maintains them as a hot-cache surface, not a sync source.

### 4h. Reference lookup flow section present (new in v1.1)

Check `<active>/CLAUDE.md` for the v1.1 documented lookup flow section:

- Does it contain a `## Documented lookup flow` (or `## Reference lookup`) section?
- Yes → pass
- No → flag informationally. Lookup behavior still works without it (Claude can resolve references heuristically), but the section makes resolution order predictable.

Offer to add the standard section from the Bootstrap CLAUDE.md template via the v1.1 patterns in Migration auto-fix.

### 4i. Checkin configuration section presence (new in v1.2 — informational only)

Check `<active>/CLAUDE.md` for the v1.2 `## Checkin configuration` section. **Never flag absence as an error** (Tenet 6 — skip what isn't there; the section is optional).

Report informationally:
- **Present** → "Checkin configuration: present ({N} recognized keys parsed)" — for debugging echo-back mismatches
- **Absent** → "Checkin configuration: not configured (Checkin defaults to all detected connectors with no project-specific filtering — run `/checkin` to verify)"

Offer to add the standard placeholder section via Migration auto-fix's v1.2 patterns (see below). The offer routes through the **B4 CLAUDE.md classification guard** (v1.1 — Bootstrap-aware): productivity-format or user-authored CLAUDE.md gets the Append/Skip/Replace prompt, not silent appending.

### 4j. Refresh-wiki configuration section presence (new in v1.3 — informational only)

Check `<active>/CLAUDE.md` for the v1.3 `## Refresh-wiki configuration` section. **Never flag absence as an error** (Tenet 6 — skip what isn't there; the section is optional). Also check for the T1/T2/T3 trigger rules sub-section within `## Continuous active maintenance` (v1.3+ Bootstrap template).

Report informationally:
- **Present** → "Refresh-wiki configuration: present ({N} recognized keys parsed)" — for debugging echo-back mismatches
- **Absent** → "Refresh-wiki configuration: not configured (Refresh-wiki defaults — T3 threshold = 5, all auto-triggers ON, no pages excluded. Run `/refresh-wiki` to verify.)"
- **Trigger rules sub-section missing** (pre-v1.3 CLAUDE.md) → "v1.3 wiki refresh trigger rules (T1/T2/T3) missing from the `## Continuous active maintenance` section. Auto-fire is inactive in this folder until migrated. Migration auto-fix can add them."

Offer to add the standard placeholder section AND the trigger rules sub-section via Migration auto-fix's v1.3 patterns (see below). Routed through the **B4 CLAUDE.md classification guard** — productivity-format or user-authored CLAUDE.md gets the Append/Skip/Replace prompt, not silent appending.

### 4k. T3 last-refresh marker check (new in v1.3 — informational only)

If a wiki exists, check for the most recent `## HH:MM - Wiki refresh` (or em-dash / en-dash variant) journal header. If found, report "Wiki last refreshed: {date}; {N} daily journal files since then ({M} from T3 threshold)." If not found AND atoms ≥ the recommended wiki threshold (currently 25, defined in `skills/refresh-wiki/SKILL.md` — PL NS2 fix: reference the canonical value, don't re-quote it) AND wiki exists, recommend "Wiki has never been refreshed. Run `/refresh-wiki` to populate Changelog provenance for existing pages."

## Layer 5: Wiki checks (only if wiki/ exists)

Same six checks as the prior `lint-wiki` skill:

### 5a. Open Questions audit
Read every `## Open Questions` section across all wiki pages. For each item:
- Answerable now from elsewhere in the wiki? → mark `[x]` and add a one-line resolution.
- Still open? → leave it.

### 5b. Dates audit
Find every absolute date (YYYY-MM-DD) in the wiki. Flag:
- Deadlines already past (compare to today's date from system clock)
- Dates within 14 days (upcoming)
- Dates marked "estimated" / "TBD" / similar

For past deadlines, update status if inferable from other pages.

### 5c. Cross-references
Grep for `[[...]]` link patterns. For each:
- Verify target page exists at expected path
- Flag phantom links; suggest closest existing page if plausible

### 5d. Contradictions
Compare facts that appear on multiple pages (numbers, statuses, spellings of entity names). When two pages disagree, identify the correct one (usually the page citing the most recent source) and fix the other. Flag any you can't resolve.

### 5e. Dashboard sync
Read `wiki/gaps/dashboard.md`. For each gap listed:
- Verify it's still active (check the referenced page)
- If resolved elsewhere, mark resolved with a note on how

Scan other wiki pages for gaps in Open Questions but missing from `dashboard.md`. Promote to dashboard.

### 5f. Stale content
Look for:
- Content describing future events that have already happened
- Decisions phrased as "pending" / "to decide" that are clearly resolved elsewhere
- Status fields not updated in a long time

### 5h. Milestone-atom newer than corresponding wiki page (new in v1.3 — TD-15 backstop)

For each `memory/projects/{weekly|monthly}-milestones-{period}.md` atom:
- Compute the period's matching wiki page (Sunday-start week → `wiki/achievements/{YYYY-W##}.md` if section exists; monthly → `wiki/achievements/{YYYY-MM}.md`)
- If the matching wiki page exists AND its mtime is OLDER than the milestone atom's mtime, flag:
  > "Milestone atom `memory/projects/{weekly|monthly}-milestones-{period}.md` (modified {date}) is newer than its wiki page `wiki/achievements/{period}.md` (modified {date}). Wiki may be stale; consider `/refresh-wiki {page-name}`."

**Why this exists (TD-15 backstop):** v1.3's TD-15 fix made Step 11 of Checkin a MANDATORY pass that fires T1 (Refresh-wiki's atom-write trigger) when atoms are written. If a future regression silently skips Step 11, milestone atoms accumulate without wiki updates — this check catches the drift on the next periodic lint run. Same belt-and-suspenders pattern as TD-14's check 2d.

### 5g. Atomic-to-wiki alignment (cross-layer schema-gap detection)

This is the check that catches cross-cutting entities sitting in atomic memory with no wiki home — the kind of failure mode where a Suj-Nav settlement ledger gets typed-up as `projects/sujnav-ledger-state.md` but never gets a synthesized wiki page because the schema has no obvious section for it.

**v1.3 role:** Lint 5g remains for periodic audits — surfaces gaps without applying changes. `/refresh-wiki` is the **action verb** that fills them. When 5g identifies gaps during Lint, it suggests running `/refresh-wiki` (and notes that auto-fire via T3 may eventually catch them too). The detection logic in 5g and the drift-detection logic in Refresh-wiki Step 3 are conceptually identical; 5g is the auditor, /refresh-wiki is the actor.

For each atomic file in `memory/{projects,reference,people}/*.md` (skip `feedback/` — those are working rules and rarely need wiki pages):

1. **Extract the entity** — read YAML `name:` field, fall back to filename slug
2. **Check for wiki coverage** — does any wiki page substantively cover this entity?
   - Look for a page whose title or filename matches the entity name
   - Grep wiki content for the entity name (full and key tokens); a single passing mention is NOT coverage — the page must have a section about it
3. **Check schema fit** — if no page exists, does `wiki/CLAUDE.md` describe a section that the entity would naturally fit into?
   - Yes → flag as "missing page, section exists" (lower priority — straightforward to create)
   - No → flag as "missing page AND missing section" (higher priority — schema gap)

Build two lists:
- **Missing pages (section fits)**: atomic entities that could just be new pages in an existing section
- **Schema gaps**: atomic entities that need a whole new section before they can have pages

For each flagged entity, suggest:
- The atomic file path
- A reasonable section name (e.g. `settlements/`, `partnerships/`, `people/`)
- A reasonable page filename

**Skip** entities that are clearly transient or single-use (e.g. project files marked "Closed" / "Completed" / "Archived" in their content). Also skip if mtime > 12 months AND content has no recent updates — could be ghost atoms.

### 5i. Orphan wiki backlinks (new in v1.4 — TD-27 inverse check, declared-schema scoped per PL-022 NIT 1)

The inverse of 5g: detects entities referenced from wiki pages that do NOT exist as atoms. This catches "the wiki mentions someone but we never captured them" — the failure mode where wiki narratives accrete entities (people, projects, decisions) that should have atomic backing but don't.

**Scoped to declared-schema entities only (per PL-022 NIT 1):** every backlink would produce noise — wikis reference many entities tangentially. The check is restricted to entities that fall under a section declared in `wiki/CLAUDE.md` as a content section (e.g., `people/`, `projects/`, `achievements/`). Entities referenced only in prose context — historical names, geographic references, acronyms not declared as glossary — are NOT flagged.

For each `[[link]]`-style or `[text](path)`-style markdown reference in wiki page bodies:

1. **Resolve the target.** If the link points to a wiki path (`wiki/section/page.md`), skip — that's intra-wiki navigation, not an atomic backlink. If the link points to an atomic path (`memory/{type}/{slug}.md`), proceed.
2. **Check schema fit.** Read `wiki/CLAUDE.md` and identify the section the linked entity would belong to (e.g., a link to `memory/people/sankar.md` falls under the `people` section if declared). If no declared section fits, **skip** — out of scope per NIT 1.
3. **Check atom existence.** Does the target atom file exist on disk?
   - Exists → no flag (the backlink is satisfied).
   - Missing → flag as orphan backlink.

For each flagged orphan, surface:
- The wiki page making the reference
- The line of the reference
- The expected atomic path
- The declared section the entity falls under

Lint output format:
> "Orphan wiki backlink: `wiki/people/maya-page.md` line 18 references `memory/people/sankar.md` (declared section: `people`) but no atom file exists. Either create the atom or rephrase the reference."

**Why this exists (TD-27 inverse):** if Remember Step 6 fires correctly going forward, this check should remain near-zero. Non-zero results indicate either: (a) historical drift before TD-27 fix landed, (b) wiki edits made outside Remember/Refresh-wiki that referenced entities not yet captured, or (c) a regression in Step 6's mandatory-pass enforcement. The check is the disk-side audit trail that proves Step 6's reply-line gate is doing its job.

## Layer 6: Plugin source checks (only if `.claude-plugin/` exists)

This layer fires only when the project folder is also a Cowork plugin source (i.e. `.claude-plugin/plugin.json` is present at the project root, OR `.claude-plugin/marketplace.json` exists). Sujayath's own RememberPlugin folder is the canonical example — his memory folder IS the plugin source.

The check exists because of the **June 12 2026 plugin.json description-limit incident**: every Remember release from v1.1.0 through v1.3.0 silently failed Cowork's "Plugin validation failed" check at install time, because Cowork enforces a tighter description limit on `plugin.json` than on `SKILL.md` (≤1024 chars). Our local "validate" step caught neither, because we didn't know the constraint existed. See `memory/feedback/cowork-plugin-json-desc-limit.md` for the full debug trace.

### 6a. plugin.json description length (new in v1.3.x)

Read `.claude-plugin/plugin.json` and check the `description` field length:
- **≤ 475 chars** — pass silently
- **476–500 chars** — warning: "plugin.json description is {N} chars; observed-safe upper bound is 475. If Cowork rejects install, trim further."
- **> 500 chars** — error: "plugin.json description is {N} chars. Cowork plugin.json descriptions ≥ 598 chars FAIL validation (June 12 2026 evidence). Trim to ≤ 475 chars before shipping."

### 6b. marketplace.json plugin description length (new in v1.3.x)

If `.claude-plugin/marketplace.json` exists, walk `plugins[]` and check each entry's `description`. Apply the same thresholds as 6a. Flag mismatches between `plugin.json.description` and the corresponding `marketplace.json.plugins[i].description` — they should be byte-identical.

### 6c. SKILL.md descriptions ≤ 1024 chars (existing constraint, re-verified)

For each `skills/*/SKILL.md`, parse YAML frontmatter and confirm `description` is ≤ 1024 chars. (This was known and previously enforced; folded into Layer 6 so all plugin-source checks live together.)

### 6d. Required plugin.json fields

Verify presence of: `name`, `version`. Verify `version` matches SemVer pattern `^\d+\.\d+\.\d+$`. Flag if missing.

## Layer 7: CAM hook health (v1.4 — third piece of the three-part TD-26 enforcement per PL-028; redesigned in v2.0 for journal-first architecture per PL-055)

Layer 7 has three sub-checks in v2.0:

- **7a** is the v2.0 redesign. The hook now writes turn transcripts directly to the journal (no intermediate markers). 7a joins the persistent host fire log (`$HOME/.remember-cam-fire.log`) against the persistent journal block count (`## HH:MM - Turn` headers in `<folder>/memory/journal/*.md`). Fires with no corresponding journal block = the hook ran but the journal write was skipped (routing missed, `Active maintenance: OFF`, or hook script bailed early).
- **7b** fires unconditionally. Verifies hook firing via `$HOME/.remember-cam-fire.log`. Same logic as v1.5/v1.5.1.
- **7c** is the cue-integrity check; secondary to Layer 4e and runs unconditionally.

v1.5.1's Layer 7d (active-folder hint verification) is **removed in v2.0** — the hint mechanism is replaced by the `$HOME/.remember-folders` registry, which is mechanical (written by Bootstrap, not the agent) and does not have the silent-skip failure mode the hint had.

Together they complete the three-part CAM enforcement:

1. **`scripts/cam-snapshot.sh`** — mechanical, lossless inbox snapshot at every Stop event (the boundary)
2. **Bootstrap CLAUDE.md template — next-turn extraction instruction** — load-bearing `Maintained:` line in each reply (visibility)
3. **This Layer 7 check** — disk-detectable backlog count (after-the-fact detection)

A future maintainer must understand that none of these alone is the guarantee. The mechanical half is reliable. The instruction half is made safe by being visible AND by Layer 7 catching the failures.

### 7a. Folder-local fire-vs-block exact join (v2.0.1 redesign per PL-064/PL-065)

**Why this redesign (v2.0.1).** The v2.0 join read `$HOME/.remember-cam-fire.log` from sandbox bash — but sandbox `$HOME` is not Mac `$HOME`, so the file was always missing from the auditor's view (silent skip). v2.0.1 moves to a **folder-local fire log** that the hook writes inside the user folder (`<active>/memory/.cam-fire-log`). The user folder is mounted in sandbox; the log is reachable from both Mac (writer) and sandbox (auditor). Single source of truth, unified UTC clock with the journal.

The check is an **exact join** — no fudge tolerance — because every fire outcome is tagged:

- A **journal Turn block** (substantive turn, journal write succeeded), OR
- A **journal Continuous-maintenance block** (Remember/Bootstrap/Lint/Refresh-wiki/Ingest/Checkin produce CM blocks during their run), OR
- A **route-bail tag** in the fire log: `reason=multi-marker | reason=no-marker | reason=toggle-off | reason=no-claude-md`.

Exact identity: `FIRES = TURN_COUNT + CM_COUNT + ROUTE_BAILS`.

**Note (PL-065 deferred):** v2.0.1 does NOT count a `skipped=command` tag — the #102 self-referencing-turn hook-skip is deferred to fast-follow B2. Each Remember/Bootstrap/Lint/Refresh-wiki/Ingest/Checkin invocation produces a cosmetic extra Turn block; this is a known limitation, not a correctness gap.

**The check.**

```bash
# === v2.0.1 plugin-root inline bootstrap (DO NOT MODIFY) ===
# Resolves $PLUGIN_ROOT to the Mac-absolute mount path of this plugin's install dir.
# Disambiguates by plugin name (not install-ID) so it works across Cowork sandbox + Claude Code.
PLUGIN_ROOT=""
for _d in "${CLAUDE_PLUGIN_ROOT:-}" /sessions/*/mnt/.remote-plugins/*/; do
  [ -d "$_d" ] || continue
  _pj="$_d/.claude-plugin/plugin.json"
  [ -f "$_pj" ] || continue
  if grep -q '"name"[[:space:]]*:[[:space:]]*"remember"' "$_pj" 2>/dev/null; then
    PLUGIN_ROOT="${_d%/}"
    break
  fi
done
unset _d _pj
if [ -z "$PLUGIN_ROOT" ]; then
  echo "BOOTSTRAP ERROR: cannot resolve Remember plugin root. Searched: \$CLAUDE_PLUGIN_ROOT, /sessions/*/mnt/.remote-plugins/*. The plugin install may be missing or this script is running outside a supported runtime." >&2
  exit 1
fi
# Optional: source the richer helper for downstream operations
[ -f "$PLUGIN_ROOT/scripts/plugin-helper.sh" ] && . "$PLUGIN_ROOT/scripts/plugin-helper.sh"
# === end inline bootstrap ===

FOLDER_FIRE_LOG="<active>/memory/.cam-fire-log"
JOURNAL_DIR="<active>/memory/journal"

if [ ! -f "$FOLDER_FIRE_LOG" ]; then
  echo "Layer 7a: WARN — no folder-local fire log at $FOLDER_FIRE_LOG."
  echo "  Either (a) the hook has never fired in this folder, or"
  echo "  (b) the v2.0.1 fire-signal write is missing in the installed cam-snapshot.sh."
  echo "  Run a substantive turn in this folder, then re-run /lint."
  exit 0  # informational, not failure
fi

# Compute the join window: from the first fire-log entry to today.
FIRST_FIRE=$(head -1 "$FOLDER_FIRE_LOG" | awk -F' \\| ' '{print $1}')
LAST_FIRE=$(tail -1 "$FOLDER_FIRE_LOG" | awk -F' \\| ' '{print $1}')

# Count fires (hook-invoked lines).
FIRE_COUNT=$(grep -c " | hook-invoked | " "$FOLDER_FIRE_LOG")

# Count Turn blocks in journals.
TURN_COUNT=0
for jf in "$JOURNAL_DIR"/*.md; do
  [ -f "$jf" ] || continue
  TURN_COUNT=$((TURN_COUNT + $(grep -c "^## .* - Turn (session" "$jf")))
done

# Count Continuous-maintenance blocks (Remember/Bootstrap/etc. produce CM blocks).
CM_COUNT=0
for jf in "$JOURNAL_DIR"/*.md; do
  [ -f "$jf" ] || continue
  CM_COUNT=$((CM_COUNT + $(grep -c "^## .* - Continuous maintenance" "$jf")))
done

# Count route bails in the fire log (multi-marker / no-marker / toggle-off / no-claude-md).
# Note: route bails are written to the host-side fire log ($HOME/.remember-cam-fire.log) per design.
# Folder-local fire log contains only successful routes. ROUTE_BAILS in folder-local context = 0.
# (Future enhancement: hook could mirror route-bail tags to folder-local log too. For v2.0.1, route
# bails affecting THIS folder don't appear in the folder-local log because the hook bailed before
# resolving the folder. The join therefore reduces to: FIRES = TURN_COUNT + CM_COUNT.)
ROUTE_BAILS=0

EXPECTED=$((TURN_COUNT + CM_COUNT + ROUTE_BAILS))
DELTA=$((FIRE_COUNT - EXPECTED))

echo "Layer 7a: folder-local fire-vs-block exact join"
echo "  Window:           $FIRST_FIRE -> $LAST_FIRE"
echo "  Fires:            $FIRE_COUNT"
echo "  Turn blocks:      $TURN_COUNT"
echo "  Continuous-maint: $CM_COUNT"
echo "  Route bails:      $ROUTE_BAILS"
echo "  Expected total:   $EXPECTED"
echo "  Delta:            $DELTA"

if [ "$DELTA" -eq 0 ]; then
  echo "  Layer 7a PASS: exact join. Every fire accounted for."
elif [ "$DELTA" -lt 0 ]; then
  echo "  Layer 7a FAIL: more journal blocks than fires. Journal may have been edited or the fire log truncated."
  exit 1
else
  echo "  Layer 7a FAIL: $DELTA fires unaccounted for. The hook fired but the result didn't land in the journal."
  echo "    Diagnose: inspect recent fire-log entries for those without a corresponding journal block."
  exit 1
fi
```

**Why this works.** Folder-local fire log is in the mounted user folder — sandbox CAN read it. Same env as the consumer. Both timestamps are UTC (closes the v2.0 timezone drift). Every fire that reaches the journal is accounted for via the matching Turn block or Continuous-maintenance block; if the hook bailed before writing the folder-local log, it tagged the host-side log with the reason — that's where Layer 7b's diagnostic surface lives.

**Multi-marker safe-skip (v2.0.1 known limitation):** if the user has multiple Bootstrap'd folders open simultaneously, the hook safe-skips routing per PL-064. Those fires appear in the host log tagged `reason=multi-marker` and do NOT write to any folder-local log. From a single folder's 7a perspective, those fires aren't "missing" — they belonged to the user, not to THIS folder. The exact join holds.

### 7a-legacy. v1.5.1 extract-ledger join (deprecated; kept for folders mid-migration to v2.0)

Pre-v2.0 folders may still have `<folder>/memory/.cam-extract-log` files from v1.5.1 sessions. The v1.5.1 join logic remains operational for those folders during the v1.5.1 → v2.0 migration window. After Layer 4e's v2.0 migration runs, the extract-ledger join becomes irrelevant; 7a primary is the journal-block-count join above.

### 7a-deprecated-v1.5. Unprocessed `.cam-inbox/` markers (pre-v1.5.1 — kept for backward compatibility)

**Why this redesign.** Pre-v1.5.1 (and v1.5) Layer 7a counted markers in `<folder>/memory/.cam-inbox/` because v1.4's architecture put markers in the user folder. v1.5.1's Cowork-env fix moved markers to session scratch (`${CLAUDE_PROJECT_DIR}/.cam-inbox/`), which Cowork cleans on session end. After session cleanup, Lint cannot see undrained markers — they are gone. The new 7a does NOT count markers (it can't); it joins two PERSISTENT signals on the `local_<UUID>` session tag:

1. **Host fire log** at `$HOME/.remember-cam-fire.log` — one line per Stop hook fire, includes `CLAUDE_PROJECT_DIR=.../local_<UUID>/outputs`. Persistent (Mac home). Records every fire across all sessions.
2. **Folder extract ledger** at `<active>/memory/.cam-extract-log` — one line per extraction, includes `session=<local_UUID-or-unparseable>`. Persistent (in user folder). Records every extraction that landed atoms in this folder.

**The check.**

```bash
# Extract the set of session tags from the host fire log.
HOST_LOG="${HOME}/.remember-cam-fire.log"
if [ ! -f "$HOST_LOG" ]; then
  # Layer 7b will catch the "hook not firing at all" case; 7a is silent here.
  echo "7a: skipped — host fire log missing (Layer 7b will surface)"
  exit 0
fi

# Extract all local_<UUID> session tags seen in the host log.
HOST_SESSIONS=$(grep -oE 'local_[a-f0-9-]+' "$HOST_LOG" | sort -u)

# Extract all session tags seen in the folder extract ledger.
EXTRACT_LOG="<active>/memory/.cam-extract-log"
if [ ! -f "$EXTRACT_LOG" ]; then
  EXTRACT_SESSIONS=""
else
  EXTRACT_SESSIONS=$(grep -oE 'session=[^[:space:]|]+' "$EXTRACT_LOG" | sed 's/^session=//' | grep -v '^unparseable$' | sort -u)
fi

# Sessions that fired the hook but produced no extraction in THIS folder.
MISSING_EXTRACTIONS=$(comm -23 <(echo "$HOST_SESSIONS") <(echo "$EXTRACT_SESSIONS"))
MISSING_COUNT=$(echo "$MISSING_EXTRACTIONS" | grep -c .)
```

**Three outcomes:**

- **`MISSING_COUNT == 0`** AND extract ledger has recent entries: pass silently. Every hook fire produced an extraction in this folder.
- **`MISSING_COUNT > 0` for chats that touched THIS folder:** warning. Some hook fires from sessions that touched this folder did not produce extractions. Surface:
  > "CAM extraction completeness audit: {MISSING_COUNT} session(s) fired the Stop hook with no corresponding extract-ledger entry in this folder. The next-turn extraction was silently skipped on those sessions. Type **Remember** in a chat in this folder to drain any session-scratch markers that may still exist (or, if those sessions are closed, the markers are lost — bounded session-tail loss per the v1.5.1 architecture)."
- **`MISSING_COUNT > 0` AND all the missing sessions are very recent (<5 min):** likely a session that hasn't reached next-turn-extraction yet. Pass silently; the audit fires on the next Lint after extraction has had time to happen.

**Why this works for the v1.5.1 architecture.** The folder extract ledger persists across session boundaries. Even when markers in session scratch are lost (session-tail loss), the absence of extraction-ledger entries for sessions that DID fire the hook is the audit signal. The join on `local_<UUID>` requires the session tag to be present in extract-ledger entries — that is why the inline `cam-section.md` Step 5 instructs the agent to write the tag (with `unparseable` fallback).

**Why the unparseable fallback is acceptable.** If the agent cannot parse `local_<UUID>` from its system prompt's working-directory path, the extract-ledger entry has `session=unparseable`. These entries are excluded from the join (filter `grep -v '^unparseable$'`). The audit becomes weaker for these sessions (they cannot be matched against host-log entries) but the capture itself proceeds. Per PL-052: "make parse failure non-fatal to capture."

**Thresholds (starting values, calibrate after first field data):** the very-recent-session window for the "haven't reached extraction yet" branch is 5 minutes; the warning trigger is any `MISSING_COUNT > 0` outside that window.

### 7a-legacy. Unprocessed `.cam-inbox/` markers (pre-v1.5.1 — kept for backward compatibility)

**Why this signature, not the earlier draft.** The first-draft Lint 6e used a "CAM-share vs explicit-burst" ratio over journal blocks. PL-022 caught that the denominator was circular (journal blocks are the thing that fails when CAM under-fires) and the architect's PL-023 re-spec to "CAM-share vs explicit-burst" had a structural blind spot: pure-CAM users (the protocol's USP cohort, who never type `Remember` or `/checkin`) produce no explicit burst to anchor against, so the signature stayed silent regardless of CAM behavior. Path B's `.cam-inbox/` markers solve both problems — markers accumulate from the mechanical Stop hook regardless of explicit captures, so the signature is non-circular AND covers the pure-CAM cohort directly.

**The check.** For the `memory/.cam-inbox/` folder:

1. Count `*.json` markers currently present in the inbox.
2. Find the most recent `## HH:MM - Continuous maintenance` block in any journal file. Extract its timestamp; call it `last-processing-pass`.
3. **Undefined-baseline case (per PL-029 NIT 5):** if no `## HH:MM - Continuous maintenance` block has ever been written to any journal file in this folder, treat `last-processing-pass` as **far-past (epoch / 1970-01-01T00:00:00Z)** — every existing marker counts as stale. This makes the math deterministic when CAM extraction has never run (either fresh install or extraction silently broken from the start). The outcome handling below applies: `stale-backlog > 0` warning triggers normally; if `stale-backlog > 25` AND the journal has 7+ days of files with no Continuous-maintenance blocks, the escalation rule fires.
4. Count markers whose filename timestamp is older than `last-processing-pass` — these are markers that should have been processed by now but weren't. Call this `stale-backlog`.

Three outcomes:

- **`stale-backlog == 0`** AND total inbox count is small (≤ {threshold}): pass silently. The CAM next-turn extraction is keeping up.
- **`stale-backlog > 0`**: flag as warning. Surface in the report:
  > "CAM inbox has {N} marker(s) older than the last Continuous maintenance journal block ({timestamp}). Next-turn extraction is falling behind. Type **Remember** to drain the backlog, or check that the Bootstrap CLAUDE.md template's Continuous maintenance section is intact (Layer 4 verifies)."
- **`stale-backlog > 25`** AND no journal entry tagged `Continuous maintenance` exists in the last 7 days: escalate to error. The hook is firing but extraction is fully under-firing — likely cause is the Bootstrap CLAUDE.md template was edited or replaced. Suggest re-running Bootstrap or auto-fixing via Lint's CLAUDE.md migration logic.

**Thresholds (starting values, calibrate after first Tester data):** small-backlog threshold = 5 markers; warning threshold for `stale-backlog` = any non-zero count; escalation threshold = 25 stale + 7 days of journal silence.

**Why this works for pure-CAM users.** A user who never types `Remember` or `/checkin` — the protocol's USP cohort — produces no explicit burst. Their inbox markers accumulate from the mechanical Stop hook regardless. If extraction is happening (Maintained: lines surfacing in replies → journal blocks landing → markers draining), `stale-backlog` stays near zero. If extraction is silently skipping (next-turn instruction not honored), markers pile up — Layer 7 catches it on the next lint, the user sees the backlog, can recover by typing `Remember` once.

### 7b. CAM hook firing health (v2.0.1 — targets v2.0 paths, drops v1.4 .cam-inbox/.fire-log)

**The blind spot this check closes.** If the Stop hook never fires (because Cowork is not honoring the plugin's `hooks.json`, or because the plugin is not actually registered, or because `cam-snapshot.sh` is not executable), the user has no signal that CAM is non-functional. The disk state of "user just started; nothing has fired yet" is indistinguishable from "the hook is broken." This check uses three structural signals to disambiguate.

**When this check fires:** ALWAYS, unconditionally.

**The check.** Three signals combined:

1. **`hooks.json` present in the installed plugin** (Primitive 1 reaches the plugin tree).
2. **`cam-snapshot.sh` executable in the installed plugin** (Cowork will refuse to invoke a non-executable script).
3. **Folder-local fire log exists AND has a recent entry** (v2.0.1 path: `<active>/memory/.cam-fire-log`, NOT v1.4's `.cam-inbox/.fire-log`).

```bash
# === v2.0.1 plugin-root inline bootstrap (DO NOT MODIFY) ===
# Resolves $PLUGIN_ROOT to the Mac-absolute mount path of this plugin's install dir.
# Disambiguates by plugin name (not install-ID) so it works across Cowork sandbox + Claude Code.
PLUGIN_ROOT=""
for _d in "${CLAUDE_PLUGIN_ROOT:-}" /sessions/*/mnt/.remote-plugins/*/; do
  [ -d "$_d" ] || continue
  _pj="$_d/.claude-plugin/plugin.json"
  [ -f "$_pj" ] || continue
  if grep -q '"name"[[:space:]]*:[[:space:]]*"remember"' "$_pj" 2>/dev/null; then
    PLUGIN_ROOT="${_d%/}"
    break
  fi
done
unset _d _pj
if [ -z "$PLUGIN_ROOT" ]; then
  echo "BOOTSTRAP ERROR: cannot resolve Remember plugin root. Searched: \$CLAUDE_PLUGIN_ROOT, /sessions/*/mnt/.remote-plugins/*. The plugin install may be missing or this script is running outside a supported runtime." >&2
  exit 1
fi
# Optional: source the richer helper for downstream operations
[ -f "$PLUGIN_ROOT/scripts/plugin-helper.sh" ] && . "$PLUGIN_ROOT/scripts/plugin-helper.sh"
# === end inline bootstrap ===

echo "Layer 7b: hook firing health"

# Signal 1 — hooks.json present
if [ -f "$PLUGIN_ROOT/hooks/hooks.json" ]; then
  echo "  hooks.json present"
else
  echo "  hooks.json missing in plugin install"
  exit 1
fi

# Signal 2 — cam-snapshot.sh executable
if [ -x "$PLUGIN_ROOT/scripts/cam-snapshot.sh" ]; then
  echo "  cam-snapshot.sh is executable"
else
  echo "  cam-snapshot.sh not executable — Cowork will not invoke it"
  exit 1
fi

# Signal 3 — v2.0.1 folder-local fire log (NOT v1.4 .cam-inbox/.fire-log)
FOLDER_FIRE_LOG="<active>/memory/.cam-fire-log"
if [ -f "$FOLDER_FIRE_LOG" ]; then
  LAST_FIRE_TS=$(tail -1 "$FOLDER_FIRE_LOG" | awk -F' \\| ' '{print $1}')
  # Convert UTC ISO 8601 to epoch (best-effort; date -d isn't on BSD).
  LAST_FIRE_EPOCH=$(date -d "$LAST_FIRE_TS" +%s 2>/dev/null || python3 -c "import datetime,sys; print(int(datetime.datetime.fromisoformat(sys.argv[1].replace('Z','+00:00')).timestamp()))" "$LAST_FIRE_TS" 2>/dev/null || echo 0)
  NOW_EPOCH=$(date -u +%s)
  LAST_FIRE_AGE=$((NOW_EPOCH - LAST_FIRE_EPOCH))
  if [ "$LAST_FIRE_AGE" -lt 3600 ]; then
    echo "  folder-local fire log has recent entry (within last hour)"
  else
    echo "  folder-local fire log exists but newest entry is over 1 hour old"
  fi
else
  echo "  no folder-local fire log yet. Run a substantive turn in this folder, then re-check."
fi
```

**Outcome:**

- All three pass → CAM hook is firing correctly in this runtime.
- Signal 1 or 2 fails → plugin install is corrupt or runtime is not invoking the hook. Surface install/runtime guidance.
- Signal 3 missing AND folder has substantive recent journal activity → hook may not be firing for THIS folder. Surface:

  > "**CAM hook may not be firing in this folder.** `hooks.json` and `cam-snapshot.sh` look correct in the install, but the folder-local fire log at `memory/.cam-fire-log` is missing or empty despite substantive activity. The hook may be firing but routing to a different folder (multi-marker safe-skip), or `Active maintenance: OFF` is set. Run one substantive turn in this folder and re-run /lint; if still missing, check the host-side fire log at `$HOME/.remember-cam-fire.log` (Mac-side) for `reason=multi-marker` or `reason=toggle-off` tags."

**Note on v1.4 path.** v2.0.1 does NOT check `memory/.cam-inbox/.fire-log` — that was a v1.4-era path that the v2.0 architecture never wrote. Folders bootstrapped on v1.4 may still have a vestigial `.cam-inbox/` directory; Lint Layer 4e migration handles it.

### 7c. CAM section cue integrity (v1.5 — was 7b pre-v1.5; cue check moved here as the secondary verification after Layer 4e migration runs)

Read `<active>/CLAUDE.md`. Verify the `## Continuous active maintenance` section contains the cues from Layer 4e step 2. If Layer 4e already passed (v1.4/v1.5.1 cues all present), this check is redundant and passes silently. If Layer 4e flagged and the user declined migration, this check surfaces the same warning as Layer 4e and re-offers migration.

This is the "the prose instruction is not the enforcement, but the prose instruction has to exist for the enforcement to work" check. Honest about what the structural pieces guarantee and what the prose is responsible for.

### 7d (REMOVED in v2.0)

v1.5.1's Layer 7d verified the agent-written `.remember-active-folder` hint. In v2.0, the hint mechanism is removed entirely — folder routing is the mechanical `$HOME/.remember-folders` registry that Bootstrap writes (no agent involvement). The registry is per-user, write-once-per-folder, and read by the hook on every fire. There is no per-session per-chat hint to verify, so 7d has no work to do.

If you are reading lint reports from v1.5.1 folders that haven't migrated to v2.0 yet, the historical 7d output is in those reports. After Layer 4e's v2.0 migration runs on a folder, 7d emits nothing further.

## Output: the lint report

Determine today's date from system clock (`date +%Y-%m-%d`). Write findings inside the **active layout** (the location detected in Step 0 — either `<root>/` for personal-folder layout or `<root>/remember/` for code-repo layout):

- **`<active>/wiki/gaps/lint-YYYY-MM-DD.md`** if a wiki exists (keeps with existing convention)
- **`<active>/memory/lint-YYYY-MM-DD.md`** if no wiki

For code repos, this means the lint report lands inside `remember/`, which is gitignored — exactly right (lint reports are personal artifacts, not project documentation).

Format:

```markdown
# Lint Report — YYYY-MM-DD

## Layers checked
- ✓ Atomic memory ({N} files across feedback / projects / reference / people / glossary)
- ✓ Glossary (v1.1) ({N} rows in glossary.md, {M} atomic mirrors, {K} productivity-authored rows)
- ✓ Journal ({N} entries, most recent {date})
- ✓ MEMORY.md
- ✓ TASKS.md ({N} active, {N} waiting-on, {N} done)
- ✓ CLAUDE.md ({N} lines, hot-cache budget: pass/over)
- ✓ Wiki ({N} pages)  — OR — ⊘ Wiki (not present, skipped)
- ✓ Plugin source (.claude-plugin/) — OR — ⊘ Plugin source (not present, skipped)

## Summary
- {N} filename-rule violations
- {N} frontmatter issues
- {N} duplicate-concept clusters
- {N} MEMORY.md orphans
- {N} stale "open" projects flagged
- {N} glossary structure issues (v1.1)
- {N} productivity-format files detected (v1.1 — informational, never errors)
- {N} CLAUDE.md hot-cache budget issues (v1.1)
- {N} Quick Glossary promotion/demotion suggestions (v1.1)
- {N} lookup-flow section missing (v1.1 — informational)
- {N} journal date-mismatches
- {N} journal format issues
- {N} stale tasks
- {N} CLAUDE.md convention violations
- (wiki, if checked) {N} Open Questions resolved, {N} dates flagged, {N} broken cross-references, {N} contradictions, {N} gaps promoted, {N} stale items, {N} atomic-to-wiki orphans

## Details

### Atomic memory
- **Filename rules:**
  - {path} → suggest renaming to {correct-path}
- **Frontmatter:**
  - {path} → missing `description:` field
- **Duplicates:**
  - {path1} + {path2} — appear to cover the same topic; recommend consolidation
- **MEMORY.md orphans:**
  - {path in MEMORY.md} — underlying file not found
- **Stale "open" projects:**
  - {path} — last touched {date}, still marked open

### Glossary (v1.1)
- **Structure consistency:**
  - {N} rows in glossary.md without atomic mirrors (run Ingest to enrich with provenance)
  - {N} atomic mirrors without corresponding glossary.md rows (auto-fix offered)
- **Append-only audit:** glossary.md mtime/size summary; warn only if shrank vs prior lint

### Productivity-format files (v1.1 — informational, never errors)
- memory/people/: {N} files, of which {M} have Remember mirrors via `mirror_of:`
- memory/projects/: {N} files, of which {M} have Remember mirrors
- memory/context/: {N} files (productivity-specific folder)
- memory/glossary.md content rows: {N} likely productivity-authored

### CLAUDE.md hot-cache budget (v1.1)
- Total: {N} lines (target ~150)
- User content: {N} lines (target ~50)
- Protocol boilerplate: {N} lines
- Quick Glossary: {N} rows (target ~20)
- Top people: {N} rows (target ~10)
- Active projects: {N} rows (target ~5)

### Quick Glossary suggestions (v1.1)
- **Promote (5+ mentions in last 30 days):** {list of terms not currently in Quick Glossary}
- **Demote (0 mentions in last 30 days):** {list of terms in Quick Glossary unused recently}
- Apply now? (yes / show-each / no)

### Documented lookup flow (v1.1)
- Section present in `<active>/CLAUDE.md`? (yes / no)
- If no → offered to add via Migration auto-fix

### Journal
- **Date mismatches:**
  - {path} — filename says {date1} but top header says {date2}; "{snippet from PM-session header}"
- **Format:**
  - {path} — missing top-level `# YYYY-MM-DD` header
- **Activity gap:**
  - Most recent journal {N} days ago

### TASKS.md
- **Stale:**
  - "{task text}" — referenced date is {N} days past, no completion mark
- **Done section size:** {N} items — consider archiving oldest {M} to a dated snapshot

### CLAUDE.md
- **Convention violations (sample):**
  - {path} contains an em dash (CLAUDE.md says "no em dashes")
- **Mount-aware load order:** present / MISSING

### Wiki (if checked)
- **Resolved Open Questions:**
  - {page}: "{question}" → resolved by {source}
- **Date flags:** ...
- **Broken cross-references:** ...
- **Contradictions fixed:** ...
- **Dashboard updates:** ...
- **Stale content:** ...

### Atomic-to-wiki alignment (if wiki checked)
- **Missing pages (section fits):**
  - {atomic-file-path} ("{entity name}") — would fit under `wiki/{section}/{suggested-slug}.md`
- **Schema gaps (no section fits — needs new section):**
  - {atomic-file-path} ("{entity name}") — suggests new `wiki/{section}/` section + `{suggested-slug}.md` page

## Pages / files modified by this lint
- {path} (Open Questions updated)
- {path} (date refreshed)

## What to do next
{1-2 sentences on highest-priority follow-ups}
```

## Update each modified file

For any wiki page or atomic file touched during the lint:
- Refresh `Last updated:` (if the file uses it)
- Append `- YYYY-MM-DD: Lint pass — {brief}` to the file's Changelog (if it has one)

## Reply with concrete numbers

After writing the lint report:
- Lint report path: `{wiki/gaps/lint-YYYY-MM-DD.md OR memory/lint-YYYY-MM-DD.md}` (N KB)
- Layers checked vs skipped
- Summary counts from the report
- Files modified during the lint (with paths)
- Any deferred items the lint couldn't resolve

## Closing prompt: atomic-to-wiki gaps (only if 5g found orphans)

If check 5g produced any "missing pages" or "schema gaps", append this block to the reply (after the concrete-numbers report):

```
## Atomic entities without wiki home

Found {N} atomic memory file(s) that don't have a wiki page yet:

**Missing pages (existing section fits):**
- "{entity name}" ({atomic path}) → would create `wiki/{section}/{slug}.md`

**Schema gaps (needs new section):**
- "{entity name}" ({atomic path}) → suggests new `wiki/{section}/` + `{slug}.md`

Want me to extend the schema and create the page(s)? (yes / all / no / pick)

- **yes** or **all** → I'll create all of the above
- **no** → leave it; I'll surface the same gaps next lint
- **pick** → tell me which entities to handle and which to skip
```

If the user replies **yes** / **all** in the next turn:
- For schema gaps: edit `wiki/CLAUDE.md` to add the new section descriptions
- Create wiki page(s) following the wiki's standard page format (read `wiki/CLAUDE.md` for page format conventions)
- Link from related existing pages to each new page
- Append `- YYYY-MM-DD: Created from lint atomic-to-wiki alignment pass` to each new page's Changelog
- Confirm with concrete paths and byte sizes

If the user replies **pick**: list each gap one at a time as a yes/no, or accept a list.

If the user replies **no** / ignores: do nothing further. The gaps stay flagged in the lint report and will resurface next lint.

## Migration auto-fix (v0.8.1 — absorbed from former Migrate skill)

When Lint detects legacy patterns (filename violations in checks 1a, inlined Remember Protocol in 4d, missing continuous-maintenance section in 4e, etc.), surface a unified auto-fix prompt at the end of the lint report. Lint now executes the migration directly — no separate skill chain needed.

### Trigger conditions

Auto-fix prompt fires if ANY of these were detected:

| Trigger | From Lint check | Auto-fix action |
|---|---|---|
| Flat-layout files at `memory/` root (e.g., `feedback_xxx.md`) | 1a | Move to `memory/{type}/{slug}.md` |
| Underscored filenames | 1a | Rename underscores → hyphens |
| Files at `memory/` root without type prefix | 1a | Ask user to classify, then move |
| Missing `memory/glossary/` subfolder (v1.1) | Layer 0 | Create the empty subfolder |
| Missing `memory/glossary.md` (v1.1) | Layer 0 | Create the empty header + table |
| Atomic mirror exists without glossary.md row (v1.1) | 1k | APPEND missing rows to glossary.md (never modify existing) |
| Pre-v1.1 CLAUDE.md missing Quick Glossary + lookup flow + hot-cache budget sections | 4f, 4g, 4h | Add the three v1.1 sections (preserve existing content) |
| Inlined Remember Protocol in project CLAUDE.md | 4d | Replace section with continuous-maintenance section (auto-loaded from bootstrap-memory-project template) |
| Missing continuous-maintenance section in project CLAUDE.md | 4e | Add the section |
| Missing continuous-maintenance section in wiki/CLAUDE.md (if wiki) | 4e | Add the section to wiki/CLAUDE.md (matched pair) |
| `notes/` references in CLAUDE.md (legacy v0.6.0) | 4d | Rename to `remember/` |
| "Commit Protocol" references in CLAUDE.md (pre-Remember) | 4d | Rename to "Remember Protocol" |
| "lint-wiki" references (pre-v0.2.0) | 4d | Rename to "lint" |
| 4 atomic types referenced (pre-v1.1) | 4d | Update mentions to 5 atomic types incl. glossary |
| v1.0 atoms with `type: project` (singular) | 1b | Normalize to `type: projects` to match the folder name canonical value |
| v1.0 mirror files using `-r` suffix only without `mirror_of:` YAML field | 1l | Add `mirror_of: memory/{type}/{slug}.md` field (where the suffix-less file exists) |
| CLAUDE.md `## Quick Glossary` / `## Top people` / `## Active projects` sections lacking the v1.1 "Lint-managed" owner comment | 4g | Mark as Lint-owned; rewrite the section comment to reflect Lint-only management |
| Pre-v1.2 CLAUDE.md missing the `## Checkin configuration` section | 4i | Offer to add the standard placeholder section, **routed through B4 classification guard** (productivity-format / user-authored CLAUDE.md gets Append/Skip/Replace prompt; Remember-format gets silent append) |
| Pre-v1.3 CLAUDE.md missing the `## Refresh-wiki configuration` section | 4j | Offer to add the standard placeholder section, **routed through B4 classification guard** |
| Pre-v1.3 CLAUDE.md missing the T1/T2/T3 trigger rules sub-section within `## Continuous active maintenance` | 4j | Offer to add the trigger rules sub-section. **CRITICAL: routed through B4 classification guard** — never silently extends a productivity-format or user-authored CLAUDE.md. State explicitly to user: "Auto-fire wiki refresh is currently inactive in this folder. Adding the T1/T2/T3 rules will enable it." |

### Closing prompt format

After the standard lint report, if any of the above triggers fired, append:

```
## Auto-fixable legacy patterns detected

I can fix the following automatically:

**File moves (X files):**
- `memory/feedback_visa_doc_prefs.md` → `memory/feedback/visa-doc-prefs.md`
- `memory/project_london_trip.md` → `memory/projects/london-trip.md`
- [etc.]

**File renames (X files, underscores → hyphens):**
- `memory/feedback/passport_expiry.md` → `memory/feedback/passport-expiry.md`
- [etc.]

**Files needing your input (X files at memory/ root, no clear type):**
- `memory/random-note.md` — which type? (feedback / projects / reference / people / glossary / skip)
- [etc.]

**CLAUDE.md cleanup:**
- Lines XX-YY: inlined Remember Protocol → replace with continuous-maintenance section from current plugin template
- Lines AA-BB: stale references to "Commit Protocol" / "lint-wiki" / "notes/" → rename

**Wiki CLAUDE.md cleanup (if wiki exists):**
- wiki/CLAUDE.md missing continuous-maintenance section → add

Want me to apply all of these? (yes / show-each / no / pick)

- **yes** — apply everything at once, then regenerate MEMORY.md
- **show-each** — walk through each fix with confirmation
- **no** — leave the flags in the lint report; nothing changes
- **pick** — tell me which to apply and which to skip
```

### Execution behavior

#### For "yes" (apply all)

For each file move/rename:
1. Read the file content
2. Write the file at the new path with `Write`
3. Delete the old file with `Bash rm` (or instructions for user if file tools can't)
4. Track: "{old} → {new}"

For files at `memory/` root needing classification (if user picked "yes" without specifying):
- Ask one at a time: "What type is `<file>`? (feedback / projects / reference / people / glossary / skip / show-content)"
- If user says "show-content", display the first 30 lines
- Move based on their answer; skip if they say skip

For CLAUDE.md inlined-protocol replacement:
1. Read `<active>/CLAUDE.md` fully
2. Identify the inlined Remember Protocol section (typically starts with `## Remember Protocol (CANONICAL...)` or `## Commit Protocol` and ends before `## Scope` or similar project content)
3. Auto-load the replacement template (Primitive 1 plugin-tree reach):
   ```bash
# === v2.0.1 plugin-root inline bootstrap (DO NOT MODIFY) ===
# Resolves $PLUGIN_ROOT to the Mac-absolute mount path of this plugin's install dir.
# Disambiguates by plugin name (not install-ID) so it works across Cowork sandbox + Claude Code.
PLUGIN_ROOT=""
for _d in "${CLAUDE_PLUGIN_ROOT:-}" /sessions/*/mnt/.remote-plugins/*/; do
  [ -d "$_d" ] || continue
  _pj="$_d/.claude-plugin/plugin.json"
  [ -f "$_pj" ] || continue
  if grep -q '"name"[[:space:]]*:[[:space:]]*"remember"' "$_pj" 2>/dev/null; then
    PLUGIN_ROOT="${_d%/}"
    break
  fi
done
unset _d _pj
if [ -z "$PLUGIN_ROOT" ]; then
  echo "BOOTSTRAP ERROR: cannot resolve Remember plugin root. Searched: \$CLAUDE_PLUGIN_ROOT, /sessions/*/mnt/.remote-plugins/*. The plugin install may be missing or this script is running outside a supported runtime." >&2
  exit 1
fi
# Optional: source the richer helper for downstream operations
[ -f "$PLUGIN_ROOT/scripts/plugin-helper.sh" ] && . "$PLUGIN_ROOT/scripts/plugin-helper.sh"
# === end inline bootstrap ===

   SIBLING_SKILL="$PLUGIN_ROOT/skills/bootstrap-memory-project/SKILL.md"
   ```
   - Read `$SIBLING_SKILL` (Bootstrap SKILL.md)
   - Extract the "Continuous active maintenance" section through to the end of the "Folder structure" section in the CLAUDE.md template
   - This becomes the replacement content — no user input needed
4. Show the user the diff: what's being removed (lines X-Y), what's being added (lines A-B)
5. Apply with `Edit`
6. Preserve all project-specific content (scope, people, projects, conventions)

For wiki/CLAUDE.md (if wiki exists and section is missing):
1. Read `<active>/wiki/CLAUDE.md`
2. Check if it has `Active maintenance: ON/OFF` line or a "Continuous active maintenance" section
3. If missing → propose the same continuous-maintenance section + wiki-specific Ingest workflow notes
4. Show the diff
5. Apply on confirmation

For text fixes ("Commit" → "Remember", "lint-wiki" → "lint", `notes/` → `remember/`):
1. Read the affected CLAUDE.md
2. Replace each pattern; show before/after for verification
3. Apply with `Edit`

After all fixes execute:
- Regenerate MEMORY.md (same as Remember Step 5 protocol):
  ```bash
# === v2.0.1 plugin-root inline bootstrap (DO NOT MODIFY) ===
# Resolves $PLUGIN_ROOT to the Mac-absolute mount path of this plugin's install dir.
# Disambiguates by plugin name (not install-ID) so it works across Cowork sandbox + Claude Code.
PLUGIN_ROOT=""
for _d in "${CLAUDE_PLUGIN_ROOT:-}" /sessions/*/mnt/.remote-plugins/*/; do
  [ -d "$_d" ] || continue
  _pj="$_d/.claude-plugin/plugin.json"
  [ -f "$_pj" ] || continue
  if grep -q '"name"[[:space:]]*:[[:space:]]*"remember"' "$_pj" 2>/dev/null; then
    PLUGIN_ROOT="${_d%/}"
    break
  fi
done
unset _d _pj
if [ -z "$PLUGIN_ROOT" ]; then
  echo "BOOTSTRAP ERROR: cannot resolve Remember plugin root. Searched: \$CLAUDE_PLUGIN_ROOT, /sessions/*/mnt/.remote-plugins/*. The plugin install may be missing or this script is running outside a supported runtime." >&2
  exit 1
fi
# Optional: source the richer helper for downstream operations
[ -f "$PLUGIN_ROOT/scripts/plugin-helper.sh" ] && . "$PLUGIN_ROOT/scripts/plugin-helper.sh"
# === end inline bootstrap ===

  python3 "$PLUGIN_ROOT/scripts/regen-memory-index.py" \
    --memory-dir "<active>/memory" \
    --project-name "{project-name}"
  ```
- Report what was done with concrete file paths

#### For "show-each" (interactive)

Same actions but pause for `(apply / skip / show-content)` confirmation after each individual fix.

#### For "no"

Stop. The flags stay in the lint report; the user can run Lint again later to re-trigger.

#### For "pick"

Ask the user which fixes to apply and which to skip. Then execute the selected fixes.

### Safety guardrails (absorbed from Migrate)

- **Never delete content.** Always move (read + write at new path + delete old). If the new file write fails, abort the delete.
- **Never auto-classify** files at memory/ root without type prefix — always ask the user.
- **Show diffs for CLAUDE.md changes.** Never edit a user-authored file without showing exactly what's being removed and added.
- **Preserve project content** in CLAUDE.md — only replace the inlined protocol section; preserve scope, people, projects, conventions, all other content.
- **Run in a single transaction-like batch** — if any step fails, report the partial state so user can investigate.
- **Append-only to `memory/glossary.md` (v1.1, Tenet 14).** Lint may append missing rows (when atomic mirrors exist without corresponding glossary.md rows) but must NEVER modify or delete existing rows. Same rule applies to productivity-format files in `memory/people/`, `memory/projects/`, `memory/context/` — Lint never touches them.
- **Hot-cache budget changes are interactive.** Promotions and demotions from check 4g require user confirmation; Lint never auto-applies them.

### Final report

After the auto-fix executes, append to the lint reply:

```
## Migration auto-fix complete

Moved: X files (flat layout → type subfolders)
Renamed: X files (underscores → hyphens)
Classified: X files (you assigned types)
Skipped: X files (you said skip)
CLAUDE.md: X lines of legacy inlined protocol replaced with continuous-maintenance section
wiki/CLAUDE.md (if applicable): updated with continuous-maintenance section

MEMORY.md regenerated: {size} KB, {N} entries.

Your memory is now in the current plugin format.
```

## What lint is NOT

- **Not a quality / writing review** — lint is structural, not editorial
- **Not a content audit** — lint doesn't critique what's said, only consistency / freshness / structural integrity
- **Not destructive** — never deletes content; only updates, flags, or moves files to corrected paths
- **Not a substitute for `Remember`** — lint is maintenance, Remember is capture
- **Not just detection** — v0.8.1 absorbed Migrate's auto-fix execution; Lint handles legacy-pattern detection AND fixing in one pass

## Adjacent commands

- **Remember** — captures from current chat into atomic memory + journal + wiki
- **Ingest** — brings existing documents (MD, TXT, PDF, DOCX, PPTX) into memory
- **Bootstrap** — sets up the memory structure in a new folder
- **Start memory folder** — for when you don't have a folder yet

(Migrate is no longer a separate skill as of v0.8.1 — its logic is absorbed into Lint. Users typing "Migrate" or "upgrade my memory layout" now trigger Lint with migration auto-fix mode.)

## Conventions

- Don't promote every page-level Open Question to the wiki dashboard — only ones that are actively blocking or cross-cutting
- Preserve historical accuracy in Changelogs — never rewrite past lint findings
- If a lint pass finds nothing, still write the report (it's evidence the lint ran)
- For non-technical users: lead the report with the layers checked and a one-line "what to do next" — they shouldn't have to read the whole detail section to know if action is needed
- Productivity-format files in `memory/people/`, `memory/projects/`, `memory/context/` and productivity-authored rows in `memory/glossary.md` are silently tolerated — never flagged as errors, never modified (Tenet 14, v1.1)
- Hot-cache budget enforcement (CLAUDE.md ~150 lines) is advisory — Lint suggests promotions/demotions but never auto-applies them (v1.1)
