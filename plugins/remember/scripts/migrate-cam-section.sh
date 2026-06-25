#!/bin/bash
# migrate-cam-section.sh — Remember plugin v2.0.2
#
# PRODUCER-SIDE CLASS-FIX (per PL-066 #1c). Extracts Lint Layer 4e's
# CAM-section migration (mechanical cat + awk replace + cue verify) into
# ONE script the Lint skill invokes verbatim. Same architectural shape as
# bootstrap-finalize.sh — no procedure for the agent to paraphrase.
#
# DUAL-PATH REQUIREMENT (per PL-066 #2): runs in Cowork sandbox bash; cannot
# touch /Users/<user>/... directly. Writes via the sandbox mount; reads
# files back through the mount for consumer-env verification.
#
# Usage:
#   migrate-cam-section.sh <sandbox-mount-path> <mac-abs-path>
#
# Args:
#   $1 = SANDBOX_MOUNT — /sessions/<id>/mnt/<folder>/ (where bash writes)
#   $2 = MAC_ABS_PATH  — /Users/<user>/<...>/<folder>/ (Mac path, used in JSON output)
#
# What it does:
#   1. Inline Primitive 1 to resolve $PLUGIN_ROOT
#   2. cd into sandbox mount
#   3. Validate CLAUDE.md exists and HAS an old CAM section needing migration
#      (look for pre-v2.0 cues like memory/.cam-inbox/ — if absent, no migration needed)
#   4. Back up existing CLAUDE.md to CLAUDE.md.pre-v2.0-cam-backup
#   5. awk-extract everything BEFORE the old `## Continuous active maintenance` header
#      and everything AFTER the old CAM section's closing
#   6. Concatenate: pre-CAM + new v2.0 CAM section (from $PLUGIN_ROOT/templates/cam-section.md) + post-CAM
#   7. Verify cue count from $PLUGIN_ROOT/templates/v2.0-cues.txt
#   8. Drop marker file if missing (matches v2.0.2 Bootstrap pattern)
#   9. Emit JSON
#
# Output: JSON on stdout describing the migration result.
# Exit: 0 on success or no-migration-needed, 1 on hard fail.
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

fail() {
  local stage="$1"
  local message="$2"
  local detail="${3:-}"
  printf '{"status":"error","stage":"%s","message":"%s","detail":"%s"}\n' \
    "$stage" "$(printf '%s' "$message" | sed 's/"/\\"/g')" "$(printf '%s' "$detail" | sed 's/"/\\"/g')" >&2
  exit 1
}

# Args
if [ $# -lt 2 ]; then
  fail "args" "Usage: migrate-cam-section.sh <sandbox-mount> <mac-abs-path>" "got $# args"
fi

SANDBOX_MOUNT="${1%/}"
MAC_ABS_PATH="${2%/}"

case "$SANDBOX_MOUNT" in
  /sessions/*/mnt/*) ;;
  *) fail "args" "sandbox-mount-path must match /sessions/*/mnt/*" "got: $SANDBOX_MOUNT" ;;
esac
case "$MAC_ABS_PATH" in
  /Users/*) ;;
  *) fail "args" "mac-abs-path must start with /Users/" "got: $MAC_ABS_PATH" ;;
esac
[ -d "$SANDBOX_MOUNT" ] || fail "args" "sandbox mount path does not exist" "$SANDBOX_MOUNT"

# Resources
CAM_TEMPLATE="$PLUGIN_ROOT/templates/cam-section.md"
CUES_FILE="$PLUGIN_ROOT/templates/v2.0-cues.txt"
[ -f "$CAM_TEMPLATE" ] || fail "plugin" "CAM template missing" "$CAM_TEMPLATE"
[ -f "$CUES_FILE" ] || fail "plugin" "cues file missing" "$CUES_FILE"

cd "$SANDBOX_MOUNT" || fail "cd" "could not cd into sandbox mount" "$SANDBOX_MOUNT"

[ -f "CLAUDE.md" ] || fail "claude-md" "CLAUDE.md not found in folder — nothing to migrate" "$SANDBOX_MOUNT/CLAUDE.md"

# Verify which cues are currently present (v2.0 cues from canonical)
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

CUES_BEFORE=$(verify_cues)
CUES_EXPECTED=$(grep -c . "$CUES_FILE")

# If already 4/4 cues — no migration needed for the CAM section
# (but we still drop the marker if it's missing)
if [ "$CUES_BEFORE" -ge "$CUES_EXPECTED" ]; then
  MARKER_ACTION="unchanged"
  if [ ! -f "memory/.cam-folder-marker" ]; then
    mkdir -p "memory" 2>/dev/null
    BOOTSTRAPPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    cat > "memory/.cam-folder-marker" <<EOF
{
  "folder_path": "$MAC_ABS_PATH",
  "bootstrapped_at": "$BOOTSTRAPPED_AT",
  "plugin_version": "2.0.2",
  "schema_version": 1,
  "added_by": "migrate-cam-section.sh"
}
EOF
    MARKER_ACTION="created"
  fi
  cat <<EOF
{
  "status": "ok",
  "action": "no-migration-needed",
  "cues_before": $CUES_BEFORE,
  "cues_after": $CUES_BEFORE,
  "cues_expected": $CUES_EXPECTED,
  "marker_action": "$MARKER_ACTION",
  "honest_followup": "CAM section already at v2.0 (4/4 cues). Marker $MARKER_ACTION."
}
EOF
  exit 0
fi

# Migration needed. Back up.
BACKUP_PATH="CLAUDE.md.pre-v2.0-cam-backup"
cp "CLAUDE.md" "$BACKUP_PATH" || fail "backup" "could not back up CLAUDE.md" "$BACKUP_PATH"

# Extract pre-CAM and post-CAM segments using awk.
# Old CAM section is between `## Continuous active maintenance` heading and the next `## ` heading.
awk '
  BEGIN { state = "pre" }
  /^## Continuous active maintenance/ { state = "in"; next }
  state == "in" && /^## / { state = "post" }
  state == "pre" { print > "/tmp/migrate-pre.tmp" }
  state == "post" { print > "/tmp/migrate-post.tmp" }
' "CLAUDE.md"

# Compose the new CLAUDE.md
{
  cat /tmp/migrate-pre.tmp 2>/dev/null || true
  cat "$CAM_TEMPLATE"
  echo ""
  cat /tmp/migrate-post.tmp 2>/dev/null || true
} > "CLAUDE.md.new"

mv "CLAUDE.md.new" "CLAUDE.md"
rm -f /tmp/migrate-pre.tmp /tmp/migrate-post.tmp

CUES_AFTER=$(verify_cues)
if [ "$CUES_AFTER" -lt "$CUES_EXPECTED" ]; then
  # Restore backup on hard fail
  cp "$BACKUP_PATH" "CLAUDE.md"
  fail "migrate" "post-migration cue count is insufficient; restored backup" "$CUES_AFTER of $CUES_EXPECTED cues after migration; expected at least $CUES_EXPECTED"
fi

# Drop marker if missing
MARKER_ACTION="unchanged"
if [ ! -f "memory/.cam-folder-marker" ]; then
  mkdir -p "memory" 2>/dev/null
  BOOTSTRAPPED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  cat > "memory/.cam-folder-marker" <<EOF
{
  "folder_path": "$MAC_ABS_PATH",
  "bootstrapped_at": "$BOOTSTRAPPED_AT",
  "plugin_version": "2.0.2",
  "schema_version": 1,
  "added_by": "migrate-cam-section.sh"
}
EOF
  MARKER_ACTION="created"
fi

cat <<EOF
{
  "status": "ok",
  "action": "migrated",
  "cues_before": $CUES_BEFORE,
  "cues_after": $CUES_AFTER,
  "cues_expected": $CUES_EXPECTED,
  "backup_path": "$MAC_ABS_PATH/$BACKUP_PATH",
  "marker_action": "$MARKER_ACTION",
  "honest_followup": "CAM section migrated v1.x → v2.0 ($CUES_AFTER/$CUES_EXPECTED cues now present). Backup at $BACKUP_PATH. Marker $MARKER_ACTION. Send one substantive turn, then run /lint to verify Layer 7a sees the new section."
}
EOF

exit 0
