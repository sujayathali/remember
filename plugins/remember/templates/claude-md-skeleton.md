# {{PROJECT_NAME}} - Project Memory

## Scope

{{SCOPE}}

## How to use this folder

This project uses the Remember memory system. Type **"Remember"** in chat
to capture durable facts. They get saved as typed atomic files inside
`memory/`, plus a daily journal entry. The `MEMORY.md` index regenerates
automatically.

If a wiki exists at `wiki/`, Remember also propagates new facts to
affected wiki pages.

For the full Remember protocol, see the Remember skill in the `remember`
plugin (installed at the Cowork user level).

## Quick Glossary (hot cache)

> Top ~20 most-referenced terms in this project. **Lint-owned** — Remember
> captures terms into `memory/glossary.md` and `memory/glossary/`; Lint
> promotes the most-used here (5+ mentions in last 30 days of journal),
> demotes the unused (no mentions in 30+ days). Do not edit manually
> between Lint runs — your edits will be reconciled on the next Lint.
> Full glossary at `memory/glossary.md`; atomic files at `memory/glossary/`.

| Term | Meaning |
|---|---|
| (empty — Lint populates from `memory/glossary.md` on next Lint pass) | |

## Documented lookup flow

When resolving a reference (e.g., "who's X?", "what's Y?"),
consult sources in this order:

1. **This CLAUDE.md** — Quick Glossary, top people, active projects
2. **`memory/glossary.md`** — full decoder ring
3. **`memory/{glossary,people,projects,reference,feedback}/`** — atomic files
4. **Ask the user**, then capture into the appropriate layer

## Hot-cache budget

This CLAUDE.md is the **hot cache**, not full storage. CLAUDE.md
loads on every session, so every line costs tokens forever.

| Surface | Target |
|---|---|
| User-content sections (Scope + Quick Glossary + Top people + Active projects + Project conventions) | ~50 lines |
| Protocol boilerplate (How to use + Continuous active maintenance + Documented lookup flow + Hot-cache budget + Folder structure) | ~95 lines (fixed) |
| Total file | ~150 lines |

Within user-content, soft caps per section:
- Quick Glossary: ~20 terms
- Top people: ~10
- Active projects: ~5

## Project conventions

(none yet — add via Remember or directly)

## CRITICAL FILENAME RULES

Files MUST live in a type subfolder with hyphenated lowercase names:

- `memory/feedback/booking-preferences.md`
- `memory/projects/q3-migration-status.md`
- `memory/reference/account-numbers.md`
- `memory/people/jane-doe.md`
- `memory/glossary/psr.md`

The path MUST be `memory/{type}/{slug}.md` — no type prefix in the filename
(the subfolder IS the type), hyphens not underscores, no files at `memory/` root.

{{INSERT_CAM_SECTION_FROM_FILE}}

## Folder structure

- `memory/feedback/` — preferences, working rules, style decisions
- `memory/projects/` — active workstream context
- `memory/reference/` — durable facts that rarely change
- `memory/people/` — per-person profiles
- `memory/glossary/` — atomic mirror of glossary terms
- `memory/journal/` — daily journal entries
- `memory/glossary.md` — shared glossary table (append-only)
- `TASKS.md` — simple task tracker
- `MEMORY.md` — auto-regenerated index
