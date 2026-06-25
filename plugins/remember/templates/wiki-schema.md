# {Project} Wiki — Schema

> Adapted from Karpathy's LLM Wiki pattern. A self-maintaining knowledge base on top of the atomic memory layer.

## Three-Layer Architecture

### Layer 1: Raw Sources (read-only, never modify)
The actual source materials live in their original locations (project folders, attached files, atomic memory files). The wiki SYNTHESIZES from these but never modifies them.

### Layer 2: The Wiki (LLM-generated, LLM-maintained)
Structured, interlinked markdown pages organized by topic / section. Pages are created and updated by the Remember skill's Wiki Ingest step, and by the Lint wiki skill.

### Layer 3: This Schema File
The conventions and workflows that govern Layers 1 and 2.

## Page Format

Every wiki page uses this structure:

```markdown
# Page Title

> One-line summary of what this page covers.

**Last updated:** YYYY-MM-DD
**Sources:** [list of raw paths and atomic memory files]
**See also:** [[related-page-1]], [[related-page-2]]

---

[Content organized with H2 sections - synthesize, do not copy]

---

## Open Questions
- [ ] Unresolved items that need attention

---

## Changelog
- YYYY-MM-DD: Initial page created
```

## Cross-Linking Convention

- Wiki to wiki: `[[section/page-name]]`
- Wiki to atomic memory: `[short label](../../memory/projects/file.md)`
- Wiki to raw source: `[short label](path/to/file)`
- When a fact appears on multiple pages, designate ONE page as authoritative and link from others. Do not duplicate substantive content.

## Active maintenance: ON (v0.7.4)

When ON (default), the Ingest workflow below runs **continuously during conversation** — not just when the user types Remember explicitly. Wiki pages get updated as new substantive facts surface in the chat. This is in concert with the project root `CLAUDE.md`'s continuous-maintenance behavior (which handles atomic memory + journal). All three layers — wiki, atomic, journal — update continuously together.

When OFF, the Ingest workflow only fires during explicit Remember invocations (Step 6 of the Remember protocol). To turn off, change the line above to `Active maintenance: OFF`.

## Workflows

### Ingest (continuous when Active maintenance is ON, or fires from Remember Step 6 when OFF)

1. For each new substantive fact arising in conversation (or each new/updated atomic file from a Remember invocation), identify which wiki pages it affects
2. Update each affected page with new data, **preserving existing structure** (preserve + append, don't rewrite — preserves history and provenance)
3. Refresh `Last updated:` and append a Changelog entry on each modified page
4. Check cross-references — does the new info contradict or update other pages?
5. Update `gaps/dashboard.md` if any gap status changed or a new gap surfaced
6. If the new fact deserves its own page (cross-cutting topic, new entity, new person), CREATE a new page following the page format
7. **Also extend to atomic + journal layers** (per project root CLAUDE.md continuous-maintenance instructions):
   - Update or create relevant atomic files in `memory/{feedback,projects,reference,people}/`
   - Append today's `memory/journal/<date>.md` with a brief note: `- HH:MM Updated: {paths}, {reason}`
8. **Show your work** in the response — briefly note what was updated across all three layers

### Query (when answering questions from the wiki)
1. Read relevant wiki pages first (synthesized understanding)
2. If the wiki cites a raw source and the answer depends on precise details, verify against the raw source
3. If the wiki doesn't cover the topic, check raw sources, then create a new wiki page

### Lint (periodic health check)
See the `remember:lint` skill for the comprehensive layered health check.

### Compact (on context loss / new session)
1. Read this schema file
2. Read the project's primary overview page (e.g., `overview.md` or `index.md`)
3. Read `gaps/dashboard.md` for open items
4. Read whichever section pages are relevant to the user's first question
5. Proceed normally — the wiki IS the context

## Conventions

- Dates: absolute (YYYY-MM-DD), never relative
- No em dashes — use hyphens or commas
- One page per coherent topic. If a page exceeds ~500 lines, split it.
- Use sentence case for headings, not Title Case.
- Preserve historical changelog entries — never rewrite past lint findings.

## Suggested section structure

Start with these and add more as the project grows:

- `overview.md` — Project at a glance
- `{section}/` — One subdirectory per major area (e.g., companies, people, strategy)
- `gaps/dashboard.md` — Active gaps across all pages
- `gaps/lint-YYYY-MM-DD.md` — Dated lint reports
- `raw/sources.md` — Index of raw materials feeding the wiki

This is a starting template. Adapt section names to your project's domain.
