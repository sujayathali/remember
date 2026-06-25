# Maintainer notes for `cam-section.md`

**This file ships in the plugin archive but is NEVER copied to a user's CLAUDE.md.** It is reference for the plugin's maintainers (Architect + future contributors). The bootstrap mechanical `cat` step in `skills/bootstrap-memory-project/SKILL.md` only inserts `cam-section.md` content into the user's CLAUDE.md; this file's filename starts with `_MAINTAINER-` to keep it visibly out of any user-facing surface.

## The verification anchor — `three-part enforcement`

The phrase **"three-part enforcement"** appears verbatim in the section header of `cam-section.md` (`## Continuous active maintenance (v1.4 — hook-driven, three-part enforcement per PL-028; ...)`) and is the load-bearing verification anchor for:

- **Bootstrap Step X** in `skills/bootstrap-memory-project/SKILL.md` — the verification grep `grep -cE 'three-part enforcement' "$USER_CLAUDE_MD"` confirms the canonical CAM section landed correctly during install.
- **Lint Layer 4e Step 4.5** in `skills/lint/SKILL.md` — same grep for the post-migration verification.

**Do NOT paraphrase or remove this phrase in future revisions of `cam-section.md`.** If you must rephrase the section header, update the grep patterns in Bootstrap Step X and Lint Layer 4e in the same change-set, or the verification will fail and bootstraps will hard-fail.

## The v1.5.1 inline-vs-factored split

`cam-section.md` was redesigned in v1.5.1 (PL-052 directive) to be a TIGHT inline (~4 KB / ~80 lines) instead of the v1.5.0 monolithic (~15 KB / ~160 lines). The split rationale:

> "Longer inline = bigger silent-drop surface, so this is a reliability call, not just budget."
> — PL-052

Long inline templates are more vulnerable to the agent-paraphrasing failure mode that v1.5's bootstrap refactor was designed to fix (`memory/feedback/bootstrap-template-copy-is-itself-instruction-only.md`). Tight inline = smaller paraphrase surface = lower silent-drop risk.

**What stays inline in `cam-section.md`** (PL-cleared via PL-053):

- The 7-step core loop (inbox check → active-folder hint → A.1 verification → extraction → ledger append → marker delete → Maintained reply line)
- A.2 multi-folder disambiguation rule (primary = loaded-CLAUDE.md memory folder; multi-qualify = actively-worked one)
- A.1 verification step before write
- Persistent extract ledger format (PL-051 mandatory addition)
- Session-tail loss documented (PL-051 mandatory addition)
- Filename rules + Classification + Tie-break order (safety net; ~3-4 lines per PL-053 Q2 expansion)
- Toggle + Verifying-CAM-is-active note (calm register per PL-053 revision 2)

**What is factored to `cam-extraction-procedure.md`** (on-demand load):

- Full architectural framing with paper §3.3 reasoning
- Worked extraction examples
- Full filename rules (anti-pattern examples, productivity-format mirror discipline)
- YAML frontmatter spec
- Glossary atomic body convention + append-only semantics
- Auto-capture-people protocol with path discipline
- Auto-capture-glossary-terms protocol
- Anti-patterns (real failure observed)
- Journal appending rules
- Wiki refresh triggers (T1 / T2 / T3)
- Full honest limitations (one-turn lag, session-tail markers, instruction-driven-not-guarantee)

## When editing `cam-section.md`

1. Confirm the section header still contains "three-part enforcement" verbatim (per the anchor note above).
2. Run the bootstrap sandbox test (`/tmp/v15-sandbox/...` or equivalent) to confirm Step X verification still passes.
3. Keep inline length under ~5 KB / ~100 lines. If new content is needed, factor it to `cam-extraction-procedure.md` instead.
4. Preserve the four Lint Layer 4e cue strings: `memory/.cam-inbox/` ... wait, in v1.5.1 the inbox semantically lives at `<working-directory>/.cam-inbox/`. The Lint Layer 4e cue strings need updating in v1.5.1. See `skills/lint/SKILL.md` Layer 4e step 2 for the current cue list.
5. Soften user-facing tone where possible — `cam-section.md` lands in EVERY user's CLAUDE.md, loaded every session. Hostile-sounding warnings cost good will every read.

## Cross-references

- Canonical: `templates/cam-section.md`
- On-demand extraction procedure: `templates/cam-extraction-procedure.md`
- Bootstrap insertion logic: `skills/bootstrap-memory-project/SKILL.md` Step W (mechanical cat) + Step X (verification with auto-retry) + Step Y (success message)
- Lint cue check: `skills/lint/SKILL.md` Layer 4e (CLAUDE.md cue integrity) + Layer 7a (extract ledger + fire log audit) + Layer 7b (hook firing health) + Layer 7d (active-folder hint verification)
- Hook script: `scripts/cam-snapshot.sh`
- Feedback atoms (architectural lineage):
  - `memory/feedback/bootstrap-template-copy-is-itself-instruction-only.md` — why mechanical bash insertion replaces agent template-copy
  - `memory/feedback/cowork-mac-host-and-vm-session-env-mismatch.md` — why v1.5.1 changed marker location to session scratch
  - `memory/feedback/ambient-behavior-needs-constructed-boundaries.md` — the paper §3.3 architectural family
