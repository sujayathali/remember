---
name: bootstrap-memory-project
description: Sets up a memory project from any starting point. If no folder is mounted, asks topic + location, creates the folder, asks Cowork to mount it. Then invokes scripts/bootstrap-finalize.sh which mechanically creates CLAUDE.md (with v2.0 CAM section), TASKS.md, memory/ subfolders (feedback, projects, reference, people, glossary, journal), glossary.md, memory/MEMORY.md skeleton, drops memory/.cam-folder-marker, and optionally adds a wiki layer. Use when the user types "Bootstrap memory", "set up a memory system in this folder", "create memory structure here", "initialize memory", "set up Remember in this folder", "make this folder a memory project", "start a new memory folder", "create a new project", "set up a new topic", "make a new folder for [topic]", or "I want to remember things about [topic]". Also auto-invoked by remember Step 0 when no folder is mounted.
---

# Bootstrap a New Memory Project

Set up the file structure that the Remember skill needs to work in a folder. Handles both "folder already mounted" and "zero state — no folder yet" entry points.

## v2.0.2 — producer-side class-fix (PL-066)

All of Bootstrap's mechanical operations — writing CLAUDE.md (with the v2.0 CAM section), verifying v2.0 cues via the consumer-readable Read tool, creating the 6 memory subfolders, writing TASKS.md / memory/glossary.md / memory/MEMORY.md skeleton, dropping the `memory/.cam-folder-marker` JSON, optionally creating the wiki layer — now live in a single script: `scripts/bootstrap-finalize.sh`. The agent invokes the script verbatim with the 5 arguments below. The script emits JSON on stdout; the agent reads `honest_followup` and presents that VERBATIM to the user.

**Why this exists.** Field-testing on 2026-06-24 (`~/Documents/capture-test/`) showed that even when Bootstrap's SKILL.md prescribed "mechanical bash" blocks for Steps W (CAM section cat) and Z (marker drop), the agent paraphrased them. Five confirmed instances of the ambient-instruction failure family. v2.0.2 closes the entire failure mode by removing the procedural prose — a single verbatim command cannot be paraphrased.

## Step 0 — zero-state vs already-mounted entry detection

BEFORE doing anything else, decide which branch this invocation takes:

**Branch A — user folder already mounted.** The cwd / working directory resolves to a Mac-absolute user folder path (under `/Users/<you>/CloudStorage/Dropbox/...`, `/Users/<you>/Library/CloudStorage/Dropbox/...`, `/Users/<you>/Documents/...`, or any explicit Cowork mount the user selected). This is the common case — the user already opened a chat mounted to where they want memory set up.

→ Proceed directly to "Step F — invoke bootstrap-finalize.sh" below. Skip Step 0.1–0.4.

**Branch B — zero state, no user folder mounted.** The cwd resolves only to `/sessions/*/mnt/outputs/` (session scratch) or there is no user folder selected for this chat. The user typed "Bootstrap" or "start a new memory folder" or similar without first selecting a folder.

→ Run Step 0.1–0.4 below to create + mount the folder FIRST, then continue to "Step F" with the newly-mounted folder as target.

### Step 0.1 — ask the user what this folder is about (Branch B only)

Immediate acknowledgment, plain language:

> "No folder mounted yet — I'll set one up. Two quick questions, then I'll create + bootstrap it."

Then ask:

> "What's this folder going to be about? One sentence — the topic, project, or area of life you want to remember things about."

If the user already named the topic in their initial request, skip the question and proceed with the named topic as the working title. Derive a folder display name in Title Case (or kebab-case if the user prefers).

### Step 0.2 — pick a location (Branch B only)

Check which of these parent locations exist on disk via bash. Use the first one that exists:

1. `~/Library/CloudStorage/Dropbox/Claude/`
2. `~/Documents/Claude/`
3. `~/Documents/`

If none exist, default to `~/Documents/Claude/` and `mkdir -p` the parent.

Tell the user:

> "I'll create the folder at: **`{parent}/{Topic Title}/`**. Want me to put it somewhere else instead, or proceed with this location?"

Wait for confirmation. If the user names a different location, use that. If they say "proceed" / "yes" / "ok" / "go", continue.

### Step 0.3 — create the folder on disk (Branch B only)

Use bash to `mkdir -p` the new folder path. Verify with `ls -la`. If the folder doesn't appear after mkdir, surface the verbatim error and STOP — do not attempt to mount a non-existent folder.

### Step 0.4 — ask Cowork to mount the folder (Branch B only)

Call `mcp__cowork__request_cowork_directory` with the new folder's Mac-absolute path. This prompts the user (in Cowork's UI) to confirm mounting.

**On success** → the folder is now mounted. Continue to "Step F" below using the new folder.

**On failure** (tool unavailable or user declined the mount):

> "I've created the folder at `{path}`, but I can't auto-mount it for this chat. Please:
> 1. Open Finder and verify the folder exists
> 2. Close this chat
> 3. Start a fresh Cowork chat and select `{Topic Title}` as the folder
> 4. Type **Bootstrap** in the new chat — I'll pick up from where you left off
>
> Sorry for the friction. The folder is ready when you are."

STOP. Do not proceed to file creation in this chat.

## What to ask the user

Before invoking the script, gather:

1. **What is this project about?** One sentence describing the project scope (e.g., "personal visa applications", "angel investment portfolio", "my professional development planning"). This becomes the `<scope>` argument to bootstrap-finalize.sh.

2. **Do you want a wiki layer?**

   A wiki is a set of summary pages on top of your notes — useful for bigger projects where you'll want overview pages organized by topic.

   Pick **no** if this folder is for narrow personal admin (e.g. visa, tickets, household). Most first-time users start here.

   Pick **yes** if this is a larger project (work, investments, multi-month research, larger creative project). You can always add the wiki later by running bootstrap again.

   This becomes the `<wiki-y-or-n>` argument (literal `y` or `n`).

3. **Any project-specific conventions** to add later? (Optional. Capture mentally; the user can add them via Remember after Bootstrap completes.)

Skip any question the user already answered in their initial request.

## Step F — invoke bootstrap-finalize.sh (the only mechanical step)

After Step 0 completes (Branch A direct, or Branch B with successful mount) and you have the user's scope + wiki answers, do exactly this:

1. **Look at the mounted-folders list in this chat's system prompt.** Identify TWO paths for the target folder:
   - The **sandbox mount path**, of the form `/sessions/<session-id>/mnt/<folder-name>/`. This is where the bash script writes.
   - The **Mac absolute path**, of the form `/Users/<you>/.../<folder-name>/`. This is what gets embedded in the marker JSON so the Mac-side Stop hook can route to the folder.

2. **Derive a project name.** Use the basename of the Mac path (e.g., `MyProject` from `/Users/sujayath/Documents/MyProject/`) unless the user named a different display name in Step 0.1.

3. **Run the script VERBATIM.** Substitute the 5 arguments inline. Do not write any other procedural code:

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

bash "$PLUGIN_ROOT/scripts/bootstrap-finalize.sh" \
  "<sandbox-mount-path>" \
  "<mac-abs-path>" \
  "<scope-string>" \
  "<wiki-y-or-n>" \
  "<project-name>"
```

4. **Read the JSON the script emits on stdout.** It has a `status` field (`ok` or `error`).

5. **If `status` is `ok`:** present a friendly summary to the user that uses the script's `honest_followup` field VERBATIM. The honest_followup line is the load-bearing claim about what was installed vs what still needs verification — do not paraphrase or soften it. A natural chat reply pattern:

   > "Memory system set up in `<mac-abs-path>`. {honest_followup}
   >
   > To capture your first fact, tell me something durable about this project and type **Remember**."

6. **If `status` is `error`:** the script's JSON contains structured failure context (`reason`, `details`, etc.). Surface it to the user as a loud failure — do NOT mark Bootstrap complete:

   > "Bootstrap did NOT complete. {script JSON dump}. The CLAUDE.md / marker may be partial; the next chat will not have CAM working end-to-end. Diagnose by running the script's listed `details`; rerun **Bootstrap** once resolved."

   STOP. Do not proceed to the friendly summary.

## Target subfolder parameter (code-repo case)

This skill accepts an optional `target_subfolder` parameter:
- `target_subfolder = "."` (default) — bootstrap at the project folder root.
- `target_subfolder = "remember/"` — bootstrap inside a `remember/` subfolder. Used for code repos to keep the source tree clean.

When called by `remember:remember` Step 0, the value is set based on whether the folder is a code repo. When invoked directly by the user, default to `"."` unless the user specifies otherwise.

If `target_subfolder = "remember/"`, append `remember/` to BOTH paths before passing to the script. The `.gitignore` + root-CLAUDE.md pointer edits described historically in this skill remain the agent's responsibility BEFORE invoking bootstrap-finalize.sh — the script operates on `<mount>/remember/` regardless.

### Code-repo prep (only if target_subfolder is `"remember/"`)

Before invoking bootstrap-finalize.sh, do these four things in order:

1. **Check for existing `remember/` folder.** If it exists with plugin structure already, note that and continue. If git-tracked, auto-untrack via `git rm --cached -r remember/`. If it exists with unrelated content, ask the user for an alternate folder name.

2. **Update `.gitignore`** to include `remember/`. Create the file if missing.

3. **Add a pointer block to the root `CLAUDE.md`** referencing `remember/CLAUDE.md` and the `@import remember/CLAUDE.md` line.

4. **Then invoke `bootstrap-finalize.sh`** with the `remember/` paths.

## Non-interference scan (light pre-check)

Before invoking bootstrap-finalize.sh, do a quick check on `<active>/CLAUDE.md` (the sandbox-mount path is fine for reading):

- If `<active>/CLAUDE.md` doesn't exist or is ≤ 50 chars → bootstrap-finalize.sh will overwrite cleanly. Proceed.
- If `<active>/CLAUDE.md` exists with v2.0 CAM cues (`journal-first`, `Maintained:`, `Stop hook`, `three-part enforcement`) all present → folder is already Bootstrapped at v2.0. Tell the user it looks set up; ask if they want to re-run anyway (e.g., to refresh the marker). If yes, invoke bootstrap-finalize.sh (idempotent for same JSON content).
- If `<active>/CLAUDE.md` exists WITHOUT the v2.0 cues → this is a productivity-format, user-authored, or pre-v2.0 Remember file. Surface this to the user:

  > "I see an existing CLAUDE.md ({N} chars). It doesn't have the v2.0 Remember CAM section. Two options:
  > 1. Run **Lint** — its Layer 4e migrates v1.x → v2.0 CAM sections via `scripts/migrate-cam-section.sh` (preserves your existing content).
  > 2. Continue with Bootstrap, which will OVERWRITE your CLAUDE.md with the Remember skeleton (your prior content is lost).
  >
  > Pick 1 or 2."

  On 1 → invoke Lint instead. On 2 → continue to Step F.

## After Bootstrap completes — Ingest chain

After bootstrap-finalize.sh returns `status: ok`, scan the folder recursively (excluding `memory/`, `wiki/`, `.git/`, `node_modules/`, hidden files) for supported documents (`.md`, `.markdown`, `.txt`, `.pdf`). Exclude `CLAUDE.md`, `TASKS.md`, `MEMORY.md`, `memory/glossary.md`, `wiki/CLAUDE.md` (just-created plugin infrastructure).

If 1+ supported documents are found:

> "I found {N} documents in this folder. I'm running **Ingest** now to bring them into memory. Next time you add documents, type **Ingest** directly."

Then invoke the `ingest` skill.

If 0 documents are found, skip Ingest and proceed to the friendly summary.

## Friendly summary (when Ingest was not chained)

```
Memory system set up in {folder}.

{honest_followup from bootstrap-finalize.sh — VERBATIM}

As you chat in this folder, I'll keep your memory updated continuously in
the background. For explicit capture passes, type "Remember". To bring
existing documents into memory later, type "Ingest". To run a daily-status
briefing, type "/checkin". To sync your wiki with atoms, type "/refresh-wiki".
To keep things tidy every few weeks, type "Lint".

To capture your first fact, tell me something durable about this project
and type "Remember". For example: "My passport expires 2031-03-15. Remember"
```

## What is NOT in this SKILL.md anymore (v2.0.2)

All of the following moved into `scripts/bootstrap-finalize.sh` and are no longer the agent's responsibility:

- Step W (mechanical CAM cat from `templates/cam-section.md`)
- Step X (consumer-env cue verification + auto-retry)
- Step Y wording (now: the script emits `honest_followup`, the agent presents it verbatim)
- Step Z (marker JSON drop + Read-tool verify)
- Pre-flight `.bootstrap-preflight` probe + cleanup dance
- 6-subfolder mkdir loop + TASKS.md + memory/glossary.md skeleton + memory/MEMORY.md skeleton
- The full CLAUDE.md template body (was inline prose; now `templates/claude-md-skeleton.md`)
- The verification ls-la pass against every created path

If you find yourself wanting to do any of those things in the agent loop, STOP — the script does them, and doing them yourself reintroduces the paraphrase risk PL-066 cleared.
