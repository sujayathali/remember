#!/bin/bash
# bootstrap-finalize.sh — Remember plugin v2.0.2
#
# PRODUCER-SIDE CLASS-FIX (per PL-066). Bootstrap's mechanical operations
# (Step W mechanical CAM cat, Step X cue verify, Step Z marker drop, memory
# subfolder + MEMORY.md skeleton creation) extracted into ONE script the
# agent invokes verbatim. SKILL.md instructs the agent to call this with the
# right arguments; the script does the rest. No procedure for the agent to
# paraphrase.
#
# Why this script exists: empirical evidence (capture-test field test on
# 2026-06-24) showed that even when SKILL.md prescribes "mechanical bash"
# blocks for Steps W and Z, the agent paraphrases them. Five confirmed
# instances of the ambient-instruction failure family. Per PL-066: any
# producer-side mechanical operation must be a single verbatim command,
# not a described procedure.
#
# DUAL-PATH REQUIREMENT (per PL-066 #2): this script runs in Cowork sandbox
# bash. Bash redirection CANNOT reach /Users/<user>/... Mac paths — only
# /sessions/<id>/mnt/<folder>/ sandbox mount paths. So the script:
#   - Takes BOTH paths as arguments
#   - Writes everything via the sandbox mount path (which lands on Mac via
#     the bidirectional mount)
#   - Embeds the Mac-absolute path in the marker JSON (because the Mac-side
#     Stop hook walks Mac roots and needs the Mac path)
#   - Verifies all writes by reading back through the sandbox mount
#
# Usage:
#   bootstrap-finalize.sh <sandbox-mount-path> <mac-abs-path> <scope> <wiki-y-or-n> [project-name]
#
# Args:
#   $1 = SANDBOX_MOUNT — /sessions/<id>/mnt/<folder>/ (where bash writes)
#   $2 = MAC_ABS_PATH  — /Users/<user>/<...>/<folder>/ (embedded in marker JSON)
#   $3 = SCOPE         — one-sentence project scope (free-form string)
#   $4 = WIKI          — 'y' or 'n' (case-insensitive)
#   $5 = PROJECT_NAME  — optional; default is basename of MAC_ABS_PATH
#
# Output: JSON on stdout describing the result.
# Exit: 0 on success, 1 on hard fail.
set -uo pipefail

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

# ----------------------------------------------------------------------------
# Helper: emit structured error JSON and exit 1
# ----------------------------------------------------------------------------
fail() {
  local stage="$1"
  local message="$2"
  local detail="${3:-}"
  printf '{"status":"error","stage":"%s","message":"%s","detail":"%s"}\n' \
    "$stage" "$(printf '%s' "$message" | sed 's/"/\\"/g')" "$(printf '%s' "$detail" | sed 's/"/\\"/g')" >&2
  exit 1
}

# ----------------------------------------------------------------------------
# Validate args
# ----------------------------------------------------------------------------
if [ $# -lt 4 ]; then
  fail "args" "Usage: bootstrap-finalize.sh <sandbox-mount> <mac-abs-path> <scope> <wiki-y-n> [project-name]" "got $# args"
fi

SANDBOX_MOUNT="$1"
MAC_ABS_PATH="$2"
SCOPE="$3"
WIKI_RAW="$4"
PROJECT_NAME="${5:-$(basename "$MAC_ABS_PATH")}"

# Normalize WIKI to 'y' or 'n'
WIKI=$(printf '%s' "$WIKI_RAW" | tr '[:upper:]' '[:lower:]' | head -c 1)
case "$WIKI" in
  y|n) ;;
  *) fail "args" "wiki arg must be 'y' or 'n'" "got: $WIKI_RAW" ;;
esac

# Validate SANDBOX_MOUNT looks like a sandbox path
case "$SANDBOX_MOUNT" in
  /sessions/*/mnt/*) ;;
  *) fail "args" "sandbox-mount-path must match /sessions/*/mnt/*" "got: $SANDBOX_MOUNT" ;;
esac

# Validate MAC_ABS_PATH looks like a Mac path
case "$MAC_ABS_PATH" in
  /Users/*) ;;
  *) fail "args" "mac-abs-path must start with /Users/" "got: $MAC_ABS_PATH" ;;
esac

# Strip trailing slashes for consistency
SANDBOX_MOUNT="${SANDBOX_MOUNT%/}"
MAC_ABS_PATH="${MAC_ABS_PATH%/}"

# Validate the sandbox mount exists and is writable
[ -d "$SANDBOX_MOUNT" ] || fail "args" "sandbox mount path does not exist" "$SANDBOX_MOUNT"
# Write probe to confirm we can actually write there
TEST_PROBE="$SANDBOX_MOUNT/.bootstrap-finalize-probe.$$"
echo "probe" > "$TEST_PROBE" 2>/dev/null \
  || fail "args" "sandbox mount path is not writable" "$SANDBOX_MOUNT"
rm -f "$TEST_PROBE" 2>/dev/null || true

# Validate canonical templates are reachable from $PLUGIN_ROOT
CAM_TEMPLATE="$PLUGIN_ROOT/templates/cam-section.md"
CUES_FILE="$PLUGIN_ROOT/templates/v2.0-cues.txt"
CLAUDE_MD_SKELETON="$PLUGIN_ROOT/templates/claude-md-skeleton.md"
[ -f "$CAM_TEMPLATE" ]      || fail "plugin" "CAM template missing"      "$CAM_TEMPLATE"
[ -f "$CUES_FILE" ]         || fail "plugin" "v2.0 cues file missing"    "$CUES_FILE"
[ -f "$CLAUDE_MD_SKELETON" ] || fail "plugin" "CLAUDE.md skeleton missing" "$CLAUDE_MD_SKELETON"

# ----------------------------------------------------------------------------
# cd into the sandbox mount; all subsequent writes are mount-relative
# ----------------------------------------------------------------------------
cd "$SANDBOX_MOUNT" || fail "cd" "could not cd into sandbox mount" "$SANDBOX_MOUNT"

# ----------------------------------------------------------------------------
# Step 1: Write CLAUDE.md from skeleton with scope + project name substituted
# ----------------------------------------------------------------------------
# Use python for safe template substitution (no shell escaping headaches)
python3 - "$CLAUDE_MD_SKELETON" "CLAUDE.md" "$PROJECT_NAME" "$SCOPE" <<'PYEOF'
import sys
skeleton_path, out_path, project_name, scope = sys.argv[1:5]
with open(skeleton_path, 'r') as f:
    content = f.read()
content = content.replace('{{PROJECT_NAME}}', project_name)
content = content.replace('{{SCOPE}}', scope)
with open(out_path, 'w') as f:
    f.write(content)
PYEOF
[ -f "CLAUDE.md" ] || fail "claude-md-write" "CLAUDE.md was not written" "$SANDBOX_MOUNT/CLAUDE.md"

# ----------------------------------------------------------------------------
# Step W: mechanical CAM section insertion via sed
# ----------------------------------------------------------------------------
# Replace {{INSERT_CAM_SECTION_FROM_FILE}} with CAM template content via sed
sed -i.bak -e "/{{INSERT_CAM_SECTION_FROM_FILE}}/r $CAM_TEMPLATE" \
           -e "/{{INSERT_CAM_SECTION_FROM_FILE}}/d" "CLAUDE.md" \
  || fail "step-w" "sed CAM section insertion failed"
rm -f "CLAUDE.md.bak" 2>/dev/null || true

# ----------------------------------------------------------------------------
# Step X: cue verification — read CLAUDE.md back through the sandbox mount
# (this IS the consumer-env verification: the Mac-side hook will read CLAUDE.md
# at the same Mac path that maps to this sandbox mount)
# ----------------------------------------------------------------------------
verify_cues() {
  local ok=0
  while IFS= read -r cue; do
    [ -n "$cue" ] || continue
    if grep -qF "$cue" "CLAUDE.md"; then
      ok=$((ok + 1))
    fi
  done < "$CUES_FILE"
  echo "$ok"
}

CUES_PRESENT=$(verify_cues)
CUES_EXPECTED=$(grep -c . "$CUES_FILE")

if [ "$CUES_PRESENT" -lt "$CUES_EXPECTED" ]; then
  # Retry Step W once before hard-failing
  sed -i.bak -e "/{{INSERT_CAM_SECTION_FROM_FILE}}/r $CAM_TEMPLATE" \
             -e "/{{INSERT_CAM_SECTION_FROM_FILE}}/d" "CLAUDE.md" 2>/dev/null
  rm -f "CLAUDE.md.bak" 2>/dev/null || true
  CUES_PRESENT=$(verify_cues)
  if [ "$CUES_PRESENT" -lt "$CUES_EXPECTED" ]; then
    fail "step-x" "CAM cue verification failed after auto-retry" "$CUES_PRESENT of $CUES_EXPECTED cues present in CLAUDE.md after retry"
  fi
fi

# ----------------------------------------------------------------------------
# Step memory-subfolders: create memory/{feedback,projects,reference,people,glossary,journal}/
# ----------------------------------------------------------------------------
for sub in feedback projects reference people glossary journal; do
  mkdir -p "memory/$sub" || fail "subfolders" "could not create memory/$sub" "$SANDBOX_MOUNT/memory/$sub"
done

# Verify all 6 subfolders exist
for sub in feedback projects reference people glossary journal; do
  [ -d "memory/$sub" ] || fail "subfolders" "memory/$sub missing after mkdir" "$SANDBOX_MOUNT/memory/$sub"
done

# ----------------------------------------------------------------------------
# Step Z: drop marker file with Mac-absolute path embedded
# ----------------------------------------------------------------------------
BOOTSTRAPPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Write marker JSON. folder_path = MAC path (what the Mac-side hook walks for).
cat > "memory/.cam-folder-marker" <<EOF
{
  "folder_path": "$MAC_ABS_PATH",
  "bootstrapped_at": "$BOOTSTRAPPED_AT",
  "plugin_version": "2.0.2",
  "schema_version": 1
}
EOF

[ -f "memory/.cam-folder-marker" ] || fail "step-z" "marker file was not written" "$SANDBOX_MOUNT/memory/.cam-folder-marker"

# Verify marker readable + JSON parses + folder_path matches
MARKER_FOLDER_PATH=$(python3 -c "
import json, sys
try:
    with open('memory/.cam-folder-marker') as f:
        data = json.load(f)
    print(data.get('folder_path', ''))
except Exception as e:
    print('PARSE_ERROR:' + str(e), file=sys.stderr)
    sys.exit(1)
")
if [ "$MARKER_FOLDER_PATH" != "$MAC_ABS_PATH" ]; then
  fail "step-z" "marker folder_path does not match expected Mac path" "marker has '$MARKER_FOLDER_PATH', expected '$MAC_ABS_PATH'"
fi

# ----------------------------------------------------------------------------
# Step glossary.md: create skeleton
# ----------------------------------------------------------------------------
cat > "memory/glossary.md" <<'EOF'
# Glossary

> Terms, acronyms, nicknames, and codenames used in this project. Append-only — existing rows are never modified.

| Term | Meaning | Notes |
|---|---|---|
EOF
[ -f "memory/glossary.md" ] || fail "glossary" "glossary.md was not written"

# ----------------------------------------------------------------------------
# Step TASKS.md: create skeleton
# ----------------------------------------------------------------------------
cat > "TASKS.md" <<EOF
# $PROJECT_NAME — TASKS

> Live task list. Append-only.

## Active

## Waiting On

## Done
EOF
[ -f "TASKS.md" ] || fail "tasks" "TASKS.md was not written"

# ----------------------------------------------------------------------------
# Step MEMORY.md: write SKELETON (per docs/v2.0.1-memory-md-template-reference.md)
# Closes task #108.
# ----------------------------------------------------------------------------
TODAY=$(date -u +%Y-%m-%d)
cat > "memory/MEMORY.md" <<EOF
# MEMORY.md — $PROJECT_NAME

> Auto-generated index of atomic memory. Regenerated $TODAY.

## Glossary

> Terms, acronyms, nicknames, and codenames used in this project. Append-only — existing rows are never modified.

| Term | Meaning | Notes |
|---|---|---|

## Feedback

_(none yet — atoms appear here as \`Remember\` commits them)_

## Projects

_(none yet)_

## Reference

_(none yet)_

## People

_(none yet)_

## Glossary atomic mirrors

> One row per atomic glossary file. The prose Glossary table above is the canonical reading view; this section is the file-by-file mirror for navigation.

| Term | File |
|---|---|

## Snapshots

_(no snapshots taken)_

> Periodic roll-ups produced by Lint runs or Checkin's weekly/monthly milestone atoms land here.

## Notes

_(user-authored editorial section — preserved across regenerations)_

> Anything you write below this line stays. The regenerator does not touch this section.

## Subfolders

- \`feedback/\` — preferences, working rules, style decisions
- \`projects/\` — active workstream context
- \`reference/\` — durable facts that rarely change
- \`people/\` — per-person profiles
- \`glossary/\` — terms, acronyms, nicknames, codenames
- \`journal/\` — daily turn + maintenance log

---
_Regenerated $TODAY._
EOF
[ -f "memory/MEMORY.md" ] || fail "memory-md" "MEMORY.md skeleton was not written"

# ----------------------------------------------------------------------------
# Step wiki (optional): create wiki/ skeleton if requested
# ----------------------------------------------------------------------------
WIKI_CREATED="false"
if [ "$WIKI" = "y" ]; then
  mkdir -p "wiki" || fail "wiki" "could not create wiki/" "$SANDBOX_MOUNT/wiki"
  WIKI_SCHEMA="$PLUGIN_ROOT/templates/wiki-schema.md"
  if [ -f "$WIKI_SCHEMA" ]; then
    cp "$WIKI_SCHEMA" "wiki/CLAUDE.md" 2>/dev/null || true
  fi
  WIKI_CREATED="true"
fi

# ----------------------------------------------------------------------------
# Write first journal entry (Bootstrap record)
# ----------------------------------------------------------------------------
TIME_HHMM=$(date -u +%H:%M)
JOURNAL_FILE="memory/journal/$TODAY.md"
if [ ! -f "$JOURNAL_FILE" ]; then
  cat > "$JOURNAL_FILE" <<EOF
# $TODAY

## $TIME_HHMM - Bootstrap

Set up the Remember memory system in \`$MAC_ABS_PATH/\`.

Created:
- CLAUDE.md (project scope + how-to + Quick Glossary placeholder + v2.0 CAM section, $CUES_PRESENT/$CUES_EXPECTED v2.0 cues verified)
- TASKS.md (empty task tracker)
- memory/{feedback,projects,reference,people,glossary,journal}/ (6 subdirectories)
- memory/glossary.md (empty glossary table, append-only)
- memory/.cam-folder-marker (Mac path embedded for Stop hook walk)
- memory/MEMORY.md (skeleton with all sections, regenerated on first Remember/Ingest pass)

Wiki created: $([ "$WIKI" = "y" ] && echo yes || echo "no — atomic-only this folder")
EOF
fi

# ----------------------------------------------------------------------------
# Success — emit JSON
# ----------------------------------------------------------------------------
cat <<EOF
{
  "status": "ok",
  "project_name": "$PROJECT_NAME",
  "mac_folder_path": "$MAC_ABS_PATH",
  "sandbox_mount_path": "$SANDBOX_MOUNT",
  "cam_cues_present": $CUES_PRESENT,
  "cam_cues_expected": $CUES_EXPECTED,
  "marker_path": "$MAC_ABS_PATH/memory/.cam-folder-marker",
  "memory_subdirs_created": 6,
  "memory_md_created": true,
  "wiki_created": $WIKI_CREATED,
  "bootstrapped_at": "$BOOTSTRAPPED_AT",
  "honest_followup": "Section installed, marker dropped. Send one substantive turn, then run /lint to verify CAM is firing end-to-end. Layer 7a confirms the hook routed to this folder."
}
EOF

exit 0
