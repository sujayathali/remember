# Remember.Plugin

> A plugin for Claude Cowork and Claude Code that captures your conversations as you chat, then distills them into structured markdown notes you control.

Open any Claude Cowork conversation. Type `/remember` and your chat gets distilled into typed markdown files — decisions, preferences, facts, people, and a glossary that builds itself from the acronyms and codenames you use — saved into a folder you control.

As you keep talking, every turn is captured automatically to a daily journal — the durable record of what was said. Type `/remember` to distill those entries into typed, classified notes (decisions, people, facts, glossary). `/lint` checks the automatic capture is firing. Bring in existing documents with `/ingest`. Run `/checkin` for a daily-status briefing pulled from your calendar/email/messaging/tasks (or just from your journal, if you don't have those connected). Run `/lint` every few weeks to keep things tidy.

**Zero infrastructure. Pure markdown. Your data stays on your machine. Plays well with other plugins — never modifies files written by another tool.**

## Install

1. Download `remember.plugin` from the [latest release](https://github.com/sujayathali/remember/releases/latest)
2. Open a new Cowork chat and drag the downloaded file into the chat input
3. Type: Show this plugin file as a card so I can save it.
4. A card appears with a **Save plugin** button — click it
5. Go to any Claude Code / Cowork chat and type `/remember` to get started

## Privacy & data

- **Everything stays local.** Files are created in folders you choose. The plugin makes zero network calls beyond Claude's normal conversation traffic.
- **No telemetry.** The plugin doesn't phone home. It doesn't know who you are or how often you use it.
- **No accounts.** No signup. No login. No vendor lock-in.
- **Open source.** MIT licensed. Read the code, fork it, modify it.
- **Your data is portable.** If you ever uninstall, every file the plugin created is still readable in any text editor. Move it to Obsidian, Notion, your own scripts, whatever.

## What you get (7 skills)

| Skill | What it does |
|---|---|
| **Remember** | Capture durable facts from the current chat into typed atomic files (5 types: feedback, projects, reference, people, glossary) + daily journal. Auto-captures acronyms, nicknames, and project codenames into a glossary that builds itself. |
| **Ingest** | Bring existing documents (MD, TXT, PDF, Word, PowerPoint) into memory. Only new and changed files processed by default. Also enriches files written by other memory plugins (creates Remember-format mirrors with provenance, never modifies originals). |
| **Checkin** | Daily productivity ritual — `/checkin` pulls a daily-status briefing from any connected calendar/email/messaging/task-tracker MCPs, plus your project's memory. Degrades gracefully when no connectors are configured. Also auto-generates weekly + monthly milestone atoms at period boundaries (Sunday-start weeks), which flow through Refresh-wiki to `wiki/achievements/` pages. |
| **Refresh-wiki** | Synthesize existing atomic memory into the wiki layer. Type `/refresh-wiki` to detect drift and fill gaps. **Auto-fires** when atoms touch wiki entities (T1, targeted+batched+cooldowned), when you ask "is the wiki updated?" (T2, targeted to your query), or when 5+ daily journal files accumulate without a refresh (T3). Updates are additive; contradictions flagged not applied; foreign-format pages read-only. |
| **Start memory folder** | When you don't have a folder yet, sets up one for you |
| **Bootstrap** | Set up the memory structure in any folder; chains to Ingest if documents are found |
| **Lint** | Layered health check across atomic memory, journal, CLAUDE.md, and wiki. Auto-fixes legacy patterns. Silently tolerates files written by other memory plugins. |

## What it does for you

- **Notes that organize themselves.** Your conversations become markdown files — decisions, references, people, preferences — automatically sorted into the right folders.
- **Captured as you talk.** Every turn is written to a journal automatically — no commands, nothing to remember. When you want it distilled into typed notes, type `/remember`; `/lint` confirms the automatic capture never silently stopped.
- **Bring in existing documents.** Drop PDFs, Word docs, presentations, or markdown into your folder. The plugin reads them, extracts the durable facts, and adds them to your memory. Add more later — only the new ones get processed.
- **Per-project, not one big brain.** Each project has its own memory. Share a project's folder for work without exposing your personal notes. Archive a project without entangling others.
- **Auto-captures people.** When you mention someone with real context (a role, a decision attributed, an action they took), a profile gets created or updated. No more "wait, who was that person again?"
- **Glossary that writes itself.** Acronyms, nicknames, project codenames — when you define one in conversation ("PSR stands for Pipeline Status Report", "Everyone calls Todd 'Toddy'", "Phoenix is the Q3 migration project"), it lands in `memory/glossary.md` and `memory/glossary/`. Next session, Claude knows your shorthand.
- **Daily check-in (no setup required).** Type `/checkin` and get an end-of-day briefing — what's on your calendar, what's in your inbox, what's pending in Slack, what's overdue in your task tracker, what got worked on, what's next. Works fully with connected MCPs; gracefully degrades to journal-only if none are connected. Weekly + monthly milestone roll-ups happen automatically at period boundaries.
- **Wiki that stays in sync.** Type `/refresh-wiki` anytime to sync your wiki layer with your atomic memory — or let it happen on its own. Three auto-triggers: new atoms touching wiki entities (T1, targeted + cooldowned so it stays cheap), conversational cues ("did we document X?", "is the X page up to date?" — T2 runs before answering), or journal accumulation (T3 fires when 5+ daily journal files pile up without a refresh). The auto-triggers are best-effort; `/refresh-wiki` is the reliable way to force a sync.
- **Plays well with other plugins.** Remember never modifies files written by another tool. If you also use Anthropic's productivity:memory-management plugin (or any other plugin that writes to `memory/`), Remember reads alongside it, creates its own atomic-format mirrors with provenance, and appends to the shared glossary without touching existing rows. Use both in the same folder; they coexist by design.
- **Works with Obsidian.** Open your folder as an Obsidian vault for a graph view of how everything connects. The plugin uses Obsidian-compatible markdown.
- **Files you own forever.** Pure markdown in folders you choose. Open in any text editor. MIT licensed and open source. Uninstall the plugin and your notes keep working.
- **Educational chaining.** When the plugin does something automatically, it tells you the underlying command so you can use it directly next time. The plugin teaches itself through use.

**Note on Migrate.** In v0.7.0–v0.8.0, Migrate was a separate skill that converted legacy memory layouts (flat-layout files, underscored filenames, inlined CLAUDE.md protocols) to the current plugin convention. v0.8.1 absorbed Migrate's logic into Lint — Lint detects legacy patterns AND auto-fixes them in one pass. Typing "Migrate" still works (it triggers Lint with migration auto-fix mode). Lint's migration auto-fix has continued to absorb later additions: v1.1 patterns (4-types → 5-types, mirror_of for productivity-format files, glossary surfaces) and v1.2 patterns (`## Checkin configuration` section) are all handled by the same Lint pass.

## How it works (in 30 seconds)

When you type **"Remember"** in a chat, Claude:

1. Looks at the conversation and picks out the things worth keeping (decisions, preferences, facts, people, glossary terms)
2. Classifies each into one of five types: `feedback`, `projects`, `reference`, `people`, `glossary`
3. Writes each as a small markdown file in `memory/{type}/{slug}.md`
4. Glossary terms also get a row appended to `memory/glossary.md` (the shared interface file — append-only, never modifies existing rows)
5. Adds an entry to today's journal at `memory/journal/YYYY-MM-DD.md`
6. Regenerates `memory/MEMORY.md` — an auto-built index of everything
7. If you have a `wiki/` folder (the optional synthesis layer), updates any pages affected by the new facts
8. Tells you exactly what was saved and where (with bash verification — the plugin shows the actual filesystem state so you can verify nothing was fabricated)

When you type **"/checkin"** in a chat, Claude:

1. Determines the time window — since your last checkin (the journal remembers), or whatever you specify (`/checkin 48h`, `/checkin since 2026-06-08`, `/checkin today`)
2. Detects which MCPs are connected (calendar, email, messaging, task tracker) using tool-name verbs (works even when MCP servers have opaque GUID names)
3. Runs each connected category through a safe-by-default content frame: connector content is treated as data, never as instructions (no prompt-injection risk from emails saying "ignore your previous instructions...")
4. Synthesizes a daily overview from journal + atomic memory (always available — works with zero connectors)
5. Drafts 3-5 priorities for tomorrow
6. Captures durable facts as atoms (per the same Remember rules, with source attribution and `confidence: medium` capped — connector content is third-party)
7. Writes the full briefing to today's journal, adds new asks to TASKS.md with provenance, replies with an executive summary in chat

Everything stays in plain markdown in folders you control. You can read, edit, version-control, back up, share — same as any other text files.

## Documented lookup flow

When Claude needs to resolve a reference in conversation ("who's Casey?", "what's PSR?", "where are we on Phoenix?"), it consults sources in a predictable order:

1. **CLAUDE.md hot cache** — top ~20 glossary terms, ~10 people, ~5 active projects, kept fresh by Lint
2. **`memory/glossary.md`** — full decoder ring
3. **`memory/{glossary,people,projects,reference,feedback}/`** — atomic files with full provenance
4. **Ask you**, then capture the answer into the right layer

Predictable resolution order makes Claude's behavior more reliable across sessions. The hot cache stays bounded (~150 lines total, with `## Quick Glossary` capped at ~20 entries) so it doesn't bloat your token budget — Lint enforces the budget and suggests what to promote/demote based on what you actually use.

## Getting started

Once installed, you only need to know one word: **Remember**.

Open any Cowork chat — with or without a folder selected, doesn't matter. Have a conversation. Type **Remember** at the end. Depending on the state of the chat:

- **Folder selected, all set up** → Claude captures the facts. Done.
- **Folder selected, not set up yet** → Claude offers to set it up first (asks 1-2 quick questions), then captures the facts.
- **No folder selected** → Claude offers to create a brand-new folder (asks what it's about + where to put it), creates and mounts it, sets it up, then captures the facts.

After that, Remember works for every chat in that folder forever.

Example:
> "I'm flying Dubai → London on EK001, June 12, PNR ABC123. Window seat preferred. Remember"

Claude saves:
- `memory/projects/dubai-london-jun-2026.md` (the trip)
- `memory/feedback/flight-booking-prefs.md` (the seat preference)
- Today's journal entry
- Updated `memory/MEMORY.md` index

Replies with the exact file paths so you can verify.

## What gets created

After bootstrap + a few Remember runs, your folder looks like this:

```
your-project/
├── CLAUDE.md              ← project context, loads every chat
│                            (includes Quick Glossary, lookup flow,
│                             hot-cache budget, and an optional
│                             ## Checkin configuration section)
├── TASKS.md               ← simple task list
├── memory/
│   ├── feedback/          ← preferences, working rules
│   ├── projects/          ← active workstreams
│   ├── reference/         ← durable facts that rarely change
│   ├── people/            ← per-person profiles
│   ├── glossary/          ← atomic glossary entries (one file per term)
│   ├── glossary.md        ← shared glossary table (append-only; productivity-compatible)
│   ├── journal/           ← daily journal entries (Remember + Checkin)
│   │   └── 2026-06-05.md
│   ├── .cam-folder-marker ← v2.0.1 marker file the Mac-side hook walks for
│   ├── .cam-fire-log      ← v2.0.1 folder-local hook fire log (UTC; Lint 7a reads this)
│   └── MEMORY.md          ← auto-regenerated index
└── wiki/                  ← (optional) synthesized knowledge layer
```

**Plugin internals (v2.0.2 — relevant for maintainers, not users).** The shipping plugin exposes a small `scripts/` + `templates/` layer that the agent invokes verbatim instead of paraphrasing procedural prose. `scripts/bootstrap-finalize.sh` does ALL of Bootstrap's mechanical work (CLAUDE.md write + cue verify + marker JSON + memory subfolders + MEMORY.md skeleton). `scripts/migrate-cam-section.sh` does Lint Layer 4e's CAM section migration. `scripts/regen-memory-index.py` is the single canonical MEMORY.md regen path (called by Remember Step 5, Ingest Step 6, Checkin Step 10, Lint Layer 1d). `templates/claude-md-skeleton.md` and `templates/cam-section.md` are the single sources of truth for the CLAUDE.md skeleton and the CAM section the scripts read. This producer-side class-fix per PL-066 closed the ambient-instruction failure family by making the agent's role "invoke script verbatim → read JSON → present `honest_followup` line" instead of "narrate a multi-step procedure."

## Using Remember in code repos

When you use Remember inside a code repository (Claude Code use case, or a Cowork chat mounted on a code repo), the plugin handles things differently to avoid polluting your source tree.

**Detection.** When Remember is invoked in a folder that contains `.git/`, `package.json`, `Cargo.toml`, `go.mod`, `requirements.txt`, or similar code-repo markers, it offers to bootstrap inside a `remember/` subfolder rather than at the repo root.

**What gets created in code repos:**

```
your-repo/
├── .git/
├── .gitignore             ← updated to include "remember/"
├── CLAUDE.md              ← your existing project context, with a pointer
│                           section added linking to remember/CLAUDE.md
├── src/...                ← your code stays clean
└── remember/                 ← visible folder, gitignored
    ├── CLAUDE.md          ← personal-memory protocol for this project
    ├── TASKS.md
    ├── memory/
    │   ├── feedback/, projects/, reference/, people/, glossary/, journal/
    │   ├── glossary.md    ← shared glossary table
    │   └── MEMORY.md
    └── wiki/              ← optional, same as personal folders
```

**Why visible (not hidden)?** So you can open `your-repo/remember/wiki/` as an Obsidian vault, grep your notes from the command line, or browse them in Finder. The whole point of Remember is that you own the files in any tool — hiding the folder would defeat that.

**Why inside the repo (not separate)?** So your Cowork or Claude Code chat — which is already mounted on the repo — can read and write to memory without re-mounting elsewhere. Same chat, same context, just a clean separation from your code.

**The root CLAUDE.md gets a small pointer section** so Claude knows about the personal-memory layer when answering questions in future chats. If you ever delete that section by accident, the `Lint` command will catch it and offer to add it back.

## Why type "Remember" instead of just letting Claude save automatically?

Two reasons:

1. **Control.** You decide what gets saved. The system never writes to disk unless you ask.
2. **Cadence.** Most chats produce some noise and some signal. Remember is the natural break — after a decision or a research session — where you tell Claude to extract the signal and discard the noise.

## File naming rules (Claude follows these, so you don't have to)

- Files go in typed subfolders: `memory/{feedback,projects,reference,people,glossary}/` (5 types)
- Filenames are lowercase, hyphenated: `passport-expiry.md`, not `passport_expiry.md` or `PassportExpiry.md`
- The `type:` YAML field exactly matches the folder name: `type: projects` (plural), `type: glossary`, etc.
- Daily journal: `memory/journal/YYYY-MM-DD.md`
- Mirrors of files written by other plugins use the `-r` suffix to coexist (e.g., `memory/people/todd-r.md` is Remember's mirror of `memory/people/todd.md` written by another plugin) and carry a `mirror_of:` YAML field pointing back to the source

You don't need to remember these rules. The Remember skill enforces them automatically.

## Plays well with other plugins

Remember treats the `memory/` folder as shared space — multiple plugins can write there, and Remember is designed to never modify what another plugin wrote. This is a deliberate architectural commitment (Tenet 14 — Non-interference with other plugins), not a productivity-plugin-specific patch. It applies to any plugin past, present, or future that writes to your `memory/` folder.

Three rules govern Remember's behavior toward foreign files:

1. **Never modify** files written by another plugin (any plugin, not just one). Detected by their format — files without YAML frontmatter at `memory/people/`, `memory/projects/`, `memory/context/`, or content rows in `memory/glossary.md` that Remember didn't write — are left untouched. Bootstrap, Remember, Ingest, Checkin, and Lint all honor this.
2. **Read alongside** them. Ingest treats foreign-format files as valid sources for extracting durable facts into Remember's own format.
3. **Mirror with provenance.** When Remember enriches a foreign-format file, it writes a Remember-format mirror at the disambiguated path (`{slug}-r.md`) with a `mirror_of:` YAML field pointing back to the source. Both files coexist. The user wins twice — the original plugin's behavior is preserved, AND Remember's richer features (provenance, journal, lookup flow, lint, wiki propagation) become available for that entity.

The most concrete example today is **Anthropic's productivity:memory-management plugin**. Both plugins:

- Use the same per-folder model
- Write to `memory/people/` and `memory/projects/`
- Treat CLAUDE.md as the always-loaded hot cache

Without Remember's non-interference layer, the two would corrupt each other's files. With it, you can install both and they work together. Productivity's quick-comprehension surface (its glossary, its hot cache) keeps doing what it does; Remember adds depth (provenance, daily journal, lint, wiki, ingest, checkin) on top.

The same rules will apply to any future plugin that writes to `memory/`. The architecture isn't tied to a specific peer plugin — it's a tenet.

## The optional wiki layer

For larger projects, it's worth turning on the wiki — a synthesized knowledge layer on top of atomic memory. Pages organized by topic with cross-links between them, plus an `Open Questions` section per page and a central `gaps/dashboard.md`.

The recommended threshold for opting into the wiki is **25 atomic files**. The canonical value lives in `skills/refresh-wiki/SKILL.md`; this README and `bootstrap-memory-project/SKILL.md` quote it here for readability. **If the threshold ever changes, grep for the value in those files and update each quoted reference** — there's no machinery making them auto-follow the canonical owner. (The convention is "one canonical owner, all other consumers carry an attribution comment.")

`/refresh-wiki` checks the count and offers to create the wiki layer when explicitly invoked past the threshold; auto-fire surfaces a once-per-session suggestion instead of silently creating structure.

The wiki is **self-maintaining**:
- Remember propagates new facts to affected wiki pages (via "Wiki Ingest" step 6)
- The Lint skill does periodic health checks across the whole system, including the wiki (find drift, resolve open questions, fix cross-references)

If you don't want a wiki, just say "no wiki" when Bootstrap asks. Remember works fine without it.

## What this is NOT

- **Not a TODO app.** Use `TASKS.md` for to-dos. Memory is for durable facts.
- **Not a Notion replacement.** Memory files are minimal — small, focused, machine-readable. The wiki layer is the human-readable surface.
- **Not cloud-locked.** Everything is markdown files in your folder. Cancel the plugin and the files keep working with any text editor.

## Adding your own commands later

This plugin is built to be extended. To add a custom command (e.g., a project-specific workflow), drop a new skill folder inside the plugin's `skills/` directory:

```
remember/
└── skills/
    ├── remember/                 ← the canonical capture command
    ├── ingest/                   ← bring existing documents into memory
    ├── checkin/                  ← daily productivity ritual
    ├── bootstrap-memory-project/ ← sets up memory in a folder (zero-state or existing; v2.0 absorbed start-memory-folder)
    ├── refresh-wiki/             ← syncs wiki layer with atoms
    ├── lint/                     ← periodic health check
    └── your-new-skill/           ← yours
        └── SKILL.md
```

The SKILL.md format is documented in any of the existing skills. Cowork picks up new skills automatically — no plugin re-packaging needed if you're editing your local install.

## Compatibility

- Works with Cowork (Anthropic's desktop knowledge-work app)
- Also works with Claude Code if you happen to use it (CLAUDE.md files load the same way)
- File outputs are pure markdown — readable by any text editor, Obsidian, Logseq, etc.
- `/checkin` works with any connected MCP that exposes recognizable verbs (`list_events`, `search_threads`, `slack_*`, `list_tasks`, etc.) — calendar, email, messaging, and task tracker integrations from any vendor work without configuration. Degrades gracefully when no connectors are configured — the journal + memory layer alone produce a useful daily overview.
- Coexists with any other Cowork plugin that writes to `memory/` — non-interference is a tenet, not a special case (see "Plays well with other plugins" above).

## Why Remember vs alternatives

The personal-memory space has several good tools. Here's where Remember fits:

| Tool | Storage model | Scope | Install complexity | Best for |
|---|---|---|---|---|
| **Remember** | Pure markdown, per-folder | Per-project | Drop in a `.plugin` file | Non-technical users; folders you want to keep separate (work, hobby, family); markdown-everywhere setups |
| **gBrain** (Garry Tan) | Markdown + embedded Postgres + pgvector | One global brain per user | Install Bun, run a daemon, configure MCP | Power users who want vector search, knowledge graphs, and cross-tool MCP |
| **Mem.ai** | Cloud SaaS | One global brain | Sign up for an account | Users who want zero-effort AI organization and don't mind cloud storage |
| **Notion AI** | Notion DB | Wherever you organize in Notion | Already use Notion | Teams already living in Notion |
| **Obsidian + AI plugins** | Markdown vault | One vault, you organize | Install Obsidian + plugins | People who already use Obsidian and want a chat layer on top |
| **CLAUDE.md** (native) | Markdown per-folder | Per-project | Built into Claude | Lightweight project context; doesn't capture conversations into structured memory |
| **productivity:memory-management** (Anthropic) | Markdown per-folder | Per-project | Built into Anthropic's productivity plugin suite | Quick decoder-ring style memory — helps Claude understand workplace shorthand. Comprehension layer rather than system of record. Coexists with Remember in the same folder (Remember treats it as a peer, not a competitor). |

**Pick Remember if:** you want zero-infra, per-folder isolation, markdown-only, a daily-ritual `/checkin` workflow, capture-with-verification, and a workflow centered on the Cowork chat. You're fine without vector search, knowledge graphs, or cloud-anything.

**Pick something else if:** you need vector retrieval at scale (gBrain), you live in Notion (Notion AI), you already have an Obsidian habit (Obsidian + AI plugin), or you want zero decision-making about organization (Mem).

**Use Remember WITH productivity:memory-management** if you're already on Anthropic's productivity plugin suite — Remember adds depth (provenance, daily journal, lint, wiki, checkin) without disturbing productivity's quick-comprehension surface.

## Troubleshooting & FAQ

**Q: I typed Remember in a chat and nothing happened.**
Check that the plugin is installed: in Cowork's `<available_skills>` list (visible at the top of any chat), you should see `remember:remember`. If not, install the `.plugin` file. If yes, try `/remember:remember` to invoke explicitly.

**Q: Cowork didn't prompt me to mount the new folder.**
The `request_cowork_directory` tool may not be available in your version, or you may have declined the prompt. Fallback: close the chat, open a fresh one, and select the new folder when Cowork asks which folder to mount. Then type Remember to continue.

**Q: Can I rename my memory folder later?**
Yes — it's just a folder on disk. Rename it in Finder. Re-open the chat with the new path. The internal files don't care about the folder name.

**Q: How do I uninstall the plugin?**
Remove it from Cowork's plugins UI. Your memory files stay on disk and remain readable in any markdown editor.

**Q: What happens if Claude's knowledge is wrong about something I said?**
You see the result before it's saved (Claude shows the file paths and content). Edit any file by hand at any time. Run **Lint** periodically to catch drift.

**Q: Can I share a memory folder with someone else?**
Yes — share the folder via Dropbox, Google Drive, etc. They'll see all the markdown files. If they install the plugin, Remember works for them too in that folder.

**Q: Should I use one big "Claude" folder for everything, or separate folders per topic?**
**Separate folders per topic.** One for your work, one for your hobby, one for household admin, etc. Don't nest sub-projects until a single folder is large enough that subdivisions become useful — the folder-splitting heuristic is about cognitive scope ("does this still feel like ONE topic?"), which is a different judgment from the wiki-worthiness threshold (25 atomic files — that judgment is about whether synthesis pays off). They're related but not the same: a 50-atom folder on a single tightly-scoped project might not need splitting; a 20-atom folder with three unrelated sub-topics might. Use the wiki threshold as a rough hint, but split based on whether the content feels like one project or several. Don't make a global "Claude" folder unless you have rules that apply *everywhere* (timezone, formatting preferences).

**Q: Can I have multiple Cowork chats mounted on the same folder?**
**Yes — and it's a powerful pattern.** All chats share the same `CLAUDE.md`, `memory/`, `wiki/`, and `TASKS.md`. Updates from any chat are visible to all others.

Example: a single MyProject project folder might have multiple specialized chats:
- A "Data Room" chat focused on document tracking
- A "To-Do" chat focused on task management
- A "Tech" chat focused on architecture decisions
- A "Strategy" chat focused on product or planning discussions

Each chat develops its own conversation history and short-term context, but they all read from and write to the same memory layer. Run `Remember` in any of them, and the captured facts become available in all the others (you'll see them on the next chat's first response, because `CLAUDE.md` and `MEMORY.md` load automatically).

This works because Cowork's mount model is per-chat but file access is shared. You don't need to do anything special — just mount each chat on the same folder.

**Q: Does Remember work in Claude Code?**
The skills are written for Cowork specifically but the markdown output is compatible with Claude Code's `CLAUDE.md` convention. You can use the files in either environment.

**Q: My files got out of sync somehow. Can I fix them?**
Run **Lint**. It catches filename drift, missing frontmatter, MEMORY.md orphans, journal-date mismatches, and (if you have a wiki) cross-reference + contradiction issues. Reply `yes` to its closing prompts to auto-fix what it can.

**Q: I already use Anthropic's productivity:memory-management plugin (or any other plugin that writes to `memory/`). Will Remember fight with it?**
**No** — Remember is designed to coexist with any other plugin that writes to `memory/`. The "non-interference" rule (Tenet 14) means Remember never modifies files it didn't write. If you run both plugins in the same folder:
- Files without YAML frontmatter at `memory/people/`, `memory/projects/`, `memory/context/` (the format the productivity plugin uses) are left untouched.
- Glossary rows in `memory/glossary.md` are append-only — Remember adds new rows at the bottom but never modifies existing ones.
- When Remember wants to enrich a foreign-format file with its own metadata (provenance, maturity, confidence), it writes a sibling file at `{slug}-r.md` with a `mirror_of:` YAML field pointing to the original. Both files coexist.
- Lint silently tolerates foreign-format files in its reports — never flags them as malformed.

Productivity's quick-comprehension surface keeps working. Remember adds depth without disturbing it.

**Q: What's the difference between `memory/glossary.md` and `memory/glossary/`?**
Two layers of the same concept:
- **`memory/glossary.md`** is a shared single-file table — the **interface**. Compatible with the productivity plugin's format. Append-only (Remember never modifies existing rows). When you read this file in any text editor, you see all your terms in one place.
- **`memory/glossary/`** is a folder of one-file-per-term atomic files — the **provenance layer**. Each file has full YAML frontmatter (maturity, confidence, `ingested_from` source attribution). This is where Remember's deep features (lookup flow, lint checks, wiki propagation) operate.

Bootstrap creates both. Remember writes to both simultaneously when capturing a new term. You can think of `glossary.md` as the human-readable index and `glossary/` as the machine-readable archive.

**Q: I have a hand-rolled "checkin" workflow saved as a behavior rule in `memory/feedback/`. What happens?**
The `/checkin` skill generalizes that pattern into a project-agnostic command. On the first `/checkin` run in your folder, Checkin auto-detects the old behavior atom and offers to port its specifics (email accounts, calendar names, Slack workspace, focus areas) into a new `## Checkin configuration` section in your CLAUDE.md. After porting, retire the old atom (delete it or move it to `memory/feedback/archive/`) — otherwise the two will duel on every "checkin" trigger.

**Q: How does Remember keep my wiki in sync with my atoms?**
`/refresh-wiki` plus three auto-trigger mechanisms keep the wiki in sync:
- **T1** fires when a new atom matches an entity covered by a wiki page. Targeted to the affected pages, batched per turn, per-page cooldown of 1 hour — so it stays cheap even on chatty days.
- **T2** fires when you ask Claude "did we document X?", "is the wiki updated?", or "is the X page up to date?" Claude refreshes the relevant pages BEFORE answering, so the answer reflects current state. Navigation queries ("where's the X page?") don't trigger T2 — they're reads.
- **T3** fires when 5+ daily journal files have accumulated since the last wiki refresh. This is the migration path for users who started atomic-only — over time, journals pile up and trigger a full wiki sync without any individual fact crossing the threshold.

You can also run `/refresh-wiki` explicitly anytime — useful for targeted refreshes (`/refresh-wiki achievements`), dry-runs (`/refresh-wiki dry-run` shows what WOULD change without applying), or since-date scans (`/refresh-wiki since 2026-06-01`). Updates are additive (preserve narrative, append to `## Changelog` with source attribution); contradictions are FLAGGED, not applied; foreign-format pages are read-only per the non-interference tenet.

**Q: Where do weekly and monthly summaries come from?**
Checkin auto-generates them at period boundaries. The first `/checkin` run of a new Sunday-start week writes a `memory/projects/weekly-milestones-{YYYY-W##}.md` atom synthesizing the previous week's journal entries + atoms with mtimes in the period + completed TASKS items. Same for months: first checkin of a new calendar month writes `monthly-milestones-{YYYY-MM}.md`. These atoms then flow through Refresh-wiki's T1 trigger to update `wiki/achievements/` pages automatically.

Catch-up: if you skip multiple periods, Checkin synthesizes the 4 most recent complete weeks and collapses older missing periods into one gap-period atom (so a 6-month-dormant folder doesn't generate 26 weekly atoms in one run). Quiet periods with no meaningful captures get a one-line journal note instead of a placeholder atom.

Note: weeks are Sunday-start (US convention), using `%U` notation in filenames. So `weekly-milestones-2026-W24.md` is the week beginning Sunday June 14, 2026.

**Q: My checkin journal entries now contain email subjects, attendee names, and message excerpts. Is it safe to share this folder?**
Be aware: yes, `/checkin` writes connector content (email senders/subjects, calendar attendees, Slack snippets) into the daily journal. If you share the folder via Dropbox, Google Drive, or git, the people you share with will see that content. The plugin has no "redact" mode — you have three options:
1. Don't share folders that run `/checkin` against sensitive connectors.
2. Use a separate folder for shared work; run `/checkin` only against your personal folder.
3. Edit the journal entries before sharing (they're plain markdown).

A future version may add a `## Checkin configuration` knob to suppress detailed content from journal entries while keeping the summary. For now, manage this at the folder-sharing level.

## License

MIT — see [LICENSE](LICENSE).

## Credits

Built by **Sujayath and Shayan**. Inspired by Andrej Karpathy's LLM-Wiki insight (local markdown as the LLM's context substrate), structured using Andy Matuschak's evergreen + structure notes pattern, with Niklas Luhmann's Strukturzettel as the wiki layer. Iterated through extensive real-world use across multiple project domains.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
