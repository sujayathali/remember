# CAM extraction procedure (v2.0 — Remember-triggered)

This file is the full extraction procedure for the Remember plugin. v2.0 changes the trigger from "agent's next-turn drain" (instruction-only, field-tested as silently-skipped) to "explicit Remember runs against accumulated journal entries." The hook writes turns to the journal mechanically; this procedure runs when the user types **Remember**.

The tight inline `cam-section.md` (which lands in every user's CLAUDE.md via Bootstrap Step W) names this file as the on-demand load. Read this when Remember runs.

## Architectural framing (paper §3.3, post-v2.0 wording)

The hook captures every turn to the journal mechanically. The journal IS the durable record — verbatim transcript, append-only, persistent. When the user types Remember, this procedure reads the journal entries since the last extraction and commits typed atoms (the structured summary view) plus updates the index.

**The three-part structural enforcement:**

- **Part 1 — Journal write (mechanical).** Hook script appends turn block per turn. Audit signal: journal block count.
- **Part 2 — Atom commit (Remember-triggered).** This procedure. User explicitly invokes Remember.
- **Part 3 — Lint audit.** Layer 7a joins host fire log against journal block count to detect missed captures. Layer 7b confirms hook firing.

Compared to v1.5.1: Part 1 moved from "session-scratch marker" to "journal block." Part 2 moved from "agent's per-turn drain (silently skipped)" to "user-typed Remember." Part 3 keeps the same audit shape with a simplified join (no extract-ledger needed; the atoms ARE the extraction signal).

## Full extraction procedure

### Step 1 — Read journal entries since last extraction

Find the most recent `## HH:MM - Continuous maintenance` block in the active folder's journal files (most recent date first). Read all `## HH:MM - Turn (session ...)` blocks AFTER that marker. These are the unprocessed turns.

If no Continuous-maintenance block exists yet (first Remember run in the folder), read all turn blocks in today's journal + any prior days' journals back to the bootstrap date.

### Step 2 — Scan for durable facts

For each Turn block, scan both the User: and Assistant: content for facts that a 6-months-later version of you would want to know. Categories that consistently produce durable facts:

- **People with substantive context** — role/title stated, action attributed, decision attributed, commitment/timeline, relationship described
- **Decisions** — what was chosen, why, by whom, when
- **Dates** — deadlines, milestones, scheduled events that affect future action
- **Role changes** — who took on what
- **Glossary terms** — acronyms, codenames, nicknames, project names
- **Working preferences** — style decisions, conventions the principal stated
- **Project state** — current status, next steps, blockers, dependencies

Skip:

- Chit-chat, questions, opinions in flux
- One-off mentions without substantive context
- Procedural housekeeping (the agent's own meta-discussion)
- Anything you would be embarrassed about if it was wrong

When in doubt, skip. The user can re-run Remember if they want borderline cases captured.

### Step 3 — Write atomic files

Atomic file format uses YAML frontmatter:

```
---
name: Short title
description: One-line summary (this lands in MEMORY.md)
type: feedback|projects|reference|people|glossary
maturity: budding  # seedling | budding | evergreen
confidence: medium # high | medium | low (Remember-triggered defaults medium-high)
date: YYYY-MM-DD
captured_in_chat: YYYY-MM-DD
tags: [optional, taxonomy, tags]
---

Body content here.
```

**Maturity field:** `seedling` (captured but unreviewed), `budding` (some confidence; default), `evergreen` (confirmed durable; user-promoted).

**Confidence field:** Remember-triggered captures default `high` (user explicitly invoked; signals importance). Auto-extracted from inferred context defaults `medium`.

**Slug convention:** slugs describe **concepts, not sources**.
- Good: `alpha-q4-strategy-decisions.md` (concept: strategy decisions for Alpha Q4)
- Bad: `project-board-meeting-2026-q2.md` (source: a specific meeting)

### Step 4 — Auto-capture new people (MANDATORY)

When a proper name appears with ANY substantive context in the journal, write a profile to `<active-folder>/memory/people/<slug>.md`. Default `maturity: budding`, `confidence: medium`. ONLY skip pure name-drops ("reminded me of something Tim Cook said").

**Path discipline for existing files (Non-interference Tenet 14):**

| Existing file state | Action |
|---|---|
| File exists AND first non-blank line is `---` (Remember-format with YAML) | UPDATE in place — add today's date + "chat" to `mentioned_in` |
| File exists WITHOUT YAML frontmatter (productivity:memory-management format) | DO NOT modify. Check for Remember mirror at `<slug>-r.md`. If mirror exists → update it. If not → CREATE mirror at `<slug>-r.md` with YAML including `mirror_of: memory/people/<slug>.md` |
| No file at either path | CREATE at `memory/people/<slug>.md` (Remember format with full YAML) |

Same path discipline applies to `memory/projects/` updates.

### Step 5 — Auto-capture glossary terms (MANDATORY)

When a term appears with ANY of these contexts in the journal, append a row to `<active-folder>/memory/glossary.md` AND create an atomic file at `<active-folder>/memory/glossary/<slug>.md`:

- Explicit definition: "PSR stands for Pipeline Status Report"
- Acronym expansion in parentheses: "We use the PSR (Pipeline Status Report) format"
- Nickname declaration: "Everyone calls Todd Martinez 'Toddy'"
- Project codename declaration: "Phoenix is the Q3 migration project"

Skip ambient acronym use without explanation.

**Append-only writes to `glossary.md` (Non-interference Tenet 14):** NEVER modify existing rows. Only add new rows at the bottom of the table. Before appending, grep the file for the term — if a row already exists, update the atomic file at `glossary/<slug>.md` only.

### Step 6 — Append the Continuous-maintenance journal block

After writing atoms, append to `<active-folder>/memory/journal/{today}.md`:

```markdown
## HH:MM - Continuous maintenance

Captured N atom(s) from {M} journal turn(s) since last extraction: {brief summary of what was captured}.

#### Verification

```bash
ls memory/feedback/ | wc -l
# (output)
ls memory/glossary/ | wc -l
# (output)
```

This block is the marker that Step 1 reads on the NEXT Remember run to know where to start. It also serves as the audit anchor for Lint Layer 7a's journal-block-count signal.

### Step 7 — Surface the load-bearing reply line

At the start of your response:

```
Maintained: N atom(s) | journal at HH:MM
```

If N = 0 (no durable facts found in the journal since last extraction): `Maintained: 0 atom(s) | journal at HH:MM` — the line is still present.

## Wiki refresh triggers (T1 fires on Remember-triggered atom writes)

When the wiki layer exists and Remember writes an atom whose entity matches an existing wiki page, fire Refresh-wiki targeted to that page. Discipline: targeted (not full); batched per Remember invocation; per-page cooldown of 1 hour.

T2 and T3 triggers unchanged (user freshness query; journal-accumulation threshold).

## Honest limitations

**Journal grows over time.** A heavy user (50 turns/day, ~2 KB per block) produces ~100 KB/day = ~3 MB/month. Manageable. Splitting by month is the natural evolution if a single day's file grows beyond ~1 MB.

**Atom freshness depends on Remember frequency.** The journal captures everything continuously; atoms only commit when Remember runs. If the user goes weeks without Remember, atoms reflect old state; the journal is up to date.

**Privacy is on the user.** Verbatim transcripts in the journal contain whatever the conversation contained. `Active maintenance: OFF` disables the journal write. Federation rules apply to journals. Encryption at rest is the user's setup, not the plugin's.

## Cross-references

- Tight inline core: `templates/cam-section.md`
- Maintainer notes: `templates/_MAINTAINER-cam-section.md`
- Hook script: `scripts/cam-snapshot.sh`
- Lint audit: `skills/lint/SKILL.md` Layers 7a + 7b
- Bootstrap installation: `skills/bootstrap-memory-project/SKILL.md` Step W (mechanical cat) + Step X (verification) + Step Y (boundary message) + registry write
- Architectural atoms:
  - `memory/feedback/bootstrap-template-copy-is-itself-instruction-only.md`
  - `memory/feedback/cowork-mac-host-and-vm-session-env-mismatch.md`
  - `memory/feedback/agent-drain-loop-is-instruction-only-in-practice.md` (the failure mode v2.0 sidesteps)
- Paper: §3.3 (architectural framing); §4 fourth design rationale (deterministic regeneration); §6 (limitations including no built-in cross-folder query)
