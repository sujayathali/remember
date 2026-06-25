## Continuous active maintenance (v2.0 — journal-first, three-part enforcement per PL-055)

**Active maintenance: ON**

The Remember plugin's Stop hook (`scripts/cam-snapshot.sh`) writes every turn directly to today's journal. No agent loop, no marker drain, no per-turn extraction. The journal is the durable record of what you and Claude said. When you want to commit typed atoms (the structured summary view), type **Remember**.

### How it works — the three-part enforcement

CAM's reliability rests on three structural pieces. None of them depends on this prose instruction succeeding turn-by-turn.

**Part 1 — Journal append (mechanical, always reliable).** At the end of every assistant turn, Cowork fires a Stop hook. The hook script (`scripts/cam-snapshot.sh`) reads the `$HOME/.remember-folders` registry that Bootstrap wrote, determines which user folder this chat belongs to (single registry entry → deterministic; multi-entry → cwd basename match), checks the `Active maintenance: ON` toggle in this folder's CLAUDE.md, then appends the turn's user message + assistant reply to `memory/journal/YYYY-MM-DD.md` under a `## HH:MM - Turn (session)` heading. The append is bash, deterministic, no LLM judgment required.

**Part 2 — Remember commits atoms.** When you type **Remember**, the skill reads the recent journal entries (since the last `## HH:MM - Continuous maintenance` block), extracts durable facts, writes typed atomic files to `memory/{feedback,projects,reference,people,glossary}/`, appends a Continuous-maintenance block to the journal, and surfaces a `Maintained: N atoms` reply line. This is when typed memory commits; the conversation transcript is already in the journal before this runs.

**Part 3 — Lint audit (after-the-fact detection).** Lint Layer 7a joins the host-side fire log (`$HOME/.remember-cam-fire.log`, persistent) against the journal block count to detect turns that fired the hook but produced no journal entry (the hook's `Active maintenance: ON` check or routing skipped the write). Layer 7b confirms hook firing health overall.

### Privacy

The journal contains verbatim transcripts of the conversation. Treat it accordingly.

- **`Active maintenance: OFF` fully disables the journal write.** The hook reads the toggle in this CLAUDE.md before appending; OFF means no transcript is written to disk this turn. To turn off: change the line at the top of this section from `ON` to `OFF`.
- **Federation rules apply to journals.** If this folder participates in a federated sync (team or organization scope), the same "never sync / never cache confidential content" discipline that applies to atoms applies to journal entries. Confidential conversations should happen with maintenance OFF or in a non-federated folder.
- **Journal entries are not encrypted at rest.** The plain-markdown format is the protocol's deliberate choice (human-readable, machine-greppable, editor-agnostic). Disk-level encryption is the user's responsibility.

### Filename rules + Classification (safety net; full rules in extraction-procedure.md)

When Remember commits atoms from the journal, files MUST land at `memory/{type}/{slug}.md` where `{type}` is one of `feedback`, `projects`, `reference`, `people`, `glossary` (the folder name verbatim) and `{slug}` is lowercase-hyphen-separated with NO type prefix.

**Five atomic types:**

- `feedback` — preferences, working rules, style decisions
- `projects` — active workstream context (state, decisions, next steps)
- `reference` — durable facts that rarely change (titles, account numbers, processes)
- `people` — per-person profiles (role, relationship, contact)
- `glossary` — terms, acronyms, nicknames, codenames

**Tie-break order (most durable wins):** reference > glossary > projects > feedback > people.

### Verifying CAM is active

After your first substantive turn in this folder, run `/lint` — Layer 7a confirms the hook is firing AND writing to the journal. If 7a flags a mismatch between host fire log and journal block count, the lint output names the diagnostic procedure (folder routing problem, toggle state, or hook script failure).

The full extraction procedure (worked examples, YAML format, auto-capture-people, glossary semantics, anti-patterns) lives at `$CLAUDE_PLUGIN_ROOT/templates/cam-extraction-procedure.md` and is loaded on demand when Remember runs.
