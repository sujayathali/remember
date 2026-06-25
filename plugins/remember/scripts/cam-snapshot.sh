#!/bin/bash
# CAM snapshot — v2.0.1 marker-walker architecture (PL-065 cleared design).
#
# Architectural arc:
# - v1.4: hook writes JSON marker to ${CLAUDE_PROJECT_DIR}/memory/.cam-inbox/
#   (didn't fire in Cowork because CLAUDE_PROJECT_DIR points at session scratch, not user folder)
# - v1.5.1: hook writes JSON marker to ${CLAUDE_PROJECT_DIR}/.cam-inbox/ (session scratch)
#   (worked, but next-turn agent silently skipped the drain — paper §3.3 instruction-only failure)
# - v2.0: hook writes turn transcript directly to <active-folder>/memory/journal/<today>.md
#   Folder routing via $HOME/.remember-folders registry written by Bootstrap.
#   (didn't fire in Cowork because Bootstrap's sandbox $HOME != hook's Mac $HOME — registry never bridged)
# - v2.0.1: hook does its OWN marker walk, self-builds its registry as a cache.
#   Bootstrap drops a marker file inside the user folder (via Write tool, reaches Mac through the mount).
#   Hook walks bounded roots for markers, caches resolution per session, journals if folder routes uniquely.
#   Multi-marker case = safe skip with diagnostic (no heuristic per PL-055 contamination rule).
#
# Cowork capture findings (2026-06-23 throwaway logger):
# - $CLAUDE_PLUGIN_ROOT IS set at hook invocation time (Mac-side); use directly, no bootstrap needed.
# - .cwd in payload = session scratch (basename "outputs") — useless for folder routing.
# - .last_user_message absent from Cowork payload — #102 hook-skip deferred to fast-follow B2.
#
# Privacy (PL-055):
# - Journal contains verbatim transcripts. Active maintenance: OFF in folder CLAUDE.md fully disables write.
# - Federation "never sync/cache confidential" rules apply to journals.
#
# Best-effort discipline (preserved from v1.5):
# - set -uo pipefail intentional; set -e OMITTED so failures exit 0 silently, never disrupting Stop event.
# - Lint Layer 7a catches missed captures after the fact via folder-local fire log vs journal block count.
set -uo pipefail

# Always drain stdin first to prevent blocking the runtime, even on bail paths.
PAYLOAD=$(cat 2>/dev/null || true)

# Runtime-independent fire log. Writes BEFORE folder routing or toggle checks.
# Persistent across reboots (Mac $HOME). Diagnostic visibility for Lint Layer 7b host-side health check.
DEBUG_LOG="${HOME:-/tmp}/.remember-cam-fire.log"
{
  printf '%s | hook-invoked | CLAUDE_PROJECT_DIR=%s | pid=%s\n' \
    "$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)" \
    "${CLAUDE_PROJECT_DIR:-UNSET}" \
    "$$" >> "$DEBUG_LOG"
} 2>/dev/null || true

# Parse session_id and last_assistant_message from payload via jq (best-effort).
SESSION_ID="unknown"
ASSISTANT_MSG=""
USER_MSG=""
if command -v jq >/dev/null 2>&1; then
    SESSION_ID=$(printf '%s' "$PAYLOAD" | jq -r '(.session_id // "unknown")' 2>/dev/null || echo "unknown")
    ASSISTANT_MSG=$(printf '%s' "$PAYLOAD" | jq -r '(.last_assistant_message // .assistant_message // empty)' 2>/dev/null || true)
    USER_MSG=$(printf '%s' "$PAYLOAD" | jq -r '(.last_user_message // .user_message // empty)' 2>/dev/null || true)
fi

# === v2.0.1 marker-walker (per design §3) ===
# Discover the active user folder via marker file walk through bounded Mac-$HOME roots.
# Cache per session. Self-build $HOME/.remember-folders as diagnostic visibility (not routing source).
MARKER_NAME=".cam-folder-marker"
CACHE_DIR="${HOME:-/tmp}/.remember-session-cache"
SELF_REGISTRY="${HOME:-/tmp}/.remember-folders"
mkdir -p "$CACHE_DIR" 2>/dev/null || true

# Cache hit: previous resolution for this session — use it.
CACHE_FILE="$CACHE_DIR/${SESSION_ID:-unknown}.json"
ACTIVE_FOLDER=""
if [ -f "$CACHE_FILE" ]; then
  if command -v jq >/dev/null 2>&1; then
    ACTIVE_FOLDER=$(jq -r '.folder_path // empty' "$CACHE_FILE" 2>/dev/null)
  else
    # Fallback grep: extract folder_path from JSON manually
    ACTIVE_FOLDER=$(grep -oE '"folder_path"[[:space:]]*:[[:space:]]*"[^"]+"' "$CACHE_FILE" 2>/dev/null | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)
  fi
fi

# Cache miss: walk for markers, resolve, write cache, append to self-built registry.
if [ -z "$ACTIVE_FOLDER" ]; then
  ROOTS=(
    "$HOME/Documents"
    "$HOME/Library/CloudStorage/Dropbox"
    "$HOME/Library/CloudStorage"
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs"
    "$HOME/Desktop"
    "$HOME"
  )

  # Heavy-dir prune list. `find -path ... -prune` skips these subtrees entirely.
  # Order matters: most-likely-hit pruned dirs first.
  PRUNE_DIRS=(
    ".git" "node_modules" ".Trash" "Library/Caches" "Library/Application Support"
    ".npm" ".cache" ".local/share/Trash" "tmp" "Downloads" "Movies" "Music" "Pictures"
    ".Spotlight-V100" ".fseventsd" ".DocumentRevisions-V100"
  )

  # Build the find prune expression once.
  PRUNE_EXPR=""
  for p in "${PRUNE_DIRS[@]}"; do
    if [ -z "$PRUNE_EXPR" ]; then
      PRUNE_EXPR="-name \"$p\" -prune"
    else
      PRUNE_EXPR="$PRUNE_EXPR -o -name \"$p\" -prune"
    fi
  done

  CANDIDATES=()
  for root in "${ROOTS[@]}"; do
    [ -d "$root" ] || continue
    # Bounded walk: -maxdepth 6 catches typical layouts like
    # ~/Library/CloudStorage/Dropbox/Claude/Projects/<name>/memory/.cam-folder-marker (depth 5)
    # Shallow -maxdepth 1 for $HOME root to avoid full $HOME walk.
    if [ "$root" = "$HOME" ]; then
      DEPTH=1
    else
      DEPTH=6
    fi
    # eval required because PRUNE_EXPR contains shell-special chars.
    # Expression is constructed from a fixed allowlist — no user input.
    while IFS= read -r marker; do
      [ -n "$marker" ] || continue
      # Marker lives at <folder>/memory/.cam-folder-marker; folder is dirname of dirname
      folder=$(dirname "$(dirname "$marker")")
      CANDIDATES+=("$folder")
    done < <(eval "find \"$root\" -maxdepth $DEPTH \\( $PRUNE_EXPR \\) -o -type f -name \"$MARKER_NAME\" -print" 2>/dev/null)
  done

  # Disambiguate. v2.0.1 supports:
  # - 0 candidates: no route, exit cleanly (tag fire log no-marker)
  # - 1 candidate:  deterministic routing
  # - >=2 candidates: SAFE SKIP per PL-064/PL-065 (multi-marker tag in fire log)
  case "${#CANDIDATES[@]}" in
    0)
      # No marker found — tag fire log and bail. Acceptable for sessions never bootstrapped.
      {
        printf '%s | hook-skipped | reason=no-marker | session=%s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          "${SESSION_ID:-unknown}"
      } >> "$DEBUG_LOG" 2>/dev/null || true
      exit 0
      ;;
    1)
      ACTIVE_FOLDER="${CANDIDATES[0]}"
      ;;
    *)
      # Multi-marker: v2.0.1 documented unsupported. Safe-skip with diagnostic log entry.
      # The diagnostic helps Lint surface the unsupported state to the user.
      {
        printf '%s | hook-skipped | reason=multi-marker | candidate_count=%d | candidates=%s | session=%s\n' \
          "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
          "${#CANDIDATES[@]}" \
          "$(printf '%s,' "${CANDIDATES[@]}" | sed 's/,$//')" \
          "${SESSION_ID:-unknown}"
      } >> "$DEBUG_LOG" 2>/dev/null || true
      exit 0
      ;;
  esac

  if [ -z "$ACTIVE_FOLDER" ]; then
    exit 0
  fi

  # Cache the resolution for this session.
  cat > "$CACHE_FILE" 2>/dev/null <<EOF
{"folder_path":"$ACTIVE_FOLDER","resolved_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","candidate_count":${#CANDIDATES[@]}}
EOF

  # Self-built registry: append for diagnostic visibility (not used for routing — marker is the source).
  if ! grep -Fxq "$ACTIVE_FOLDER" "$SELF_REGISTRY" 2>/dev/null; then
    {
      [ -s "$SELF_REGISTRY" ] || echo "# Remember plugin — folders self-discovered by the Stop hook via marker walk"
      echo "$ACTIVE_FOLDER"
    } >> "$SELF_REGISTRY" 2>/dev/null || true
  fi
fi

# Routing guard: if still no folder, exit cleanly.
if [ -z "$ACTIVE_FOLDER" ] || [ ! -d "$ACTIVE_FOLDER" ]; then
    exit 0
fi

# Privacy check — Active maintenance toggle in the folder's CLAUDE.md.
# OFF disables journal write entirely (PL-055 privacy requirement).
CLAUDE_MD="$ACTIVE_FOLDER/CLAUDE.md"
if [ ! -f "$CLAUDE_MD" ]; then
    {
      printf '%s | hook-skipped | reason=no-claude-md | folder=%s | session=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$ACTIVE_FOLDER" \
        "${SESSION_ID:-unknown}"
    } >> "$DEBUG_LOG" 2>/dev/null || true
    exit 0
fi
if ! grep -qE '^\*\*Active maintenance: ON\*\*' "$CLAUDE_MD" 2>/dev/null; then
    # Toggle is OFF, missing, or malformed → no journal write. Privacy preserved.
    {
      printf '%s | hook-skipped | reason=toggle-off | folder=%s | session=%s\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        "$ACTIVE_FOLDER" \
        "${SESSION_ID:-unknown}"
    } >> "$DEBUG_LOG" 2>/dev/null || true
    exit 0
fi

# === v2.0.1 folder-local fire signal (per design §4) ===
# Sandbox-readable via mount; unified clock (UTC) with the host-side fire log.
FOLDER_FIRE_LOG="$ACTIVE_FOLDER/memory/.cam-fire-log"
{
  printf '%s | hook-invoked | session=%s | folder=%s | pid=%s\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    "${SESSION_ID:-unknown}" \
    "$ACTIVE_FOLDER" \
    "$$"
} >> "$FOLDER_FIRE_LOG" 2>/dev/null || true

# Ensure the journal directory exists.
JOURNAL_DIR="$ACTIVE_FOLDER/memory/journal"
if [ ! -d "$JOURNAL_DIR" ]; then
    mkdir -p "$JOURNAL_DIR" 2>/dev/null || exit 0
fi

# Compose the journal entry. All timestamps UTC per design §4 unified-clock requirement.
TODAY=$(date -u +%Y-%m-%d 2>/dev/null) || exit 0
TIME_HHMM=$(date -u +%H:%M 2>/dev/null) || exit 0
JOURNAL_FILE="$JOURNAL_DIR/$TODAY.md"

# If parsing failed entirely (no jq, malformed payload), write the raw payload as a fallback.
# Preserves the lossless property: the journal always has SOMETHING for every fired turn.
if [ -z "$USER_MSG" ] && [ -z "$ASSISTANT_MSG" ]; then
    {
        printf '\n## %s - Turn (session %s)\n\n' "$TIME_HHMM" "$SESSION_ID"
        printf '> Raw payload (jq unavailable or payload structure unrecognized):\n\n'
        printf '```\n%s\n```\n' "$PAYLOAD"
    } >> "$JOURNAL_FILE" 2>/dev/null || true
    exit 0
fi

# Standard append: turn block under HH:MM heading (UTC).
{
    printf '\n## %s - Turn (session %s)\n\n' "$TIME_HHMM" "$SESSION_ID"
    if [ -n "$USER_MSG" ]; then
        printf '**User:** %s\n\n' "$USER_MSG"
    fi
    if [ -n "$ASSISTANT_MSG" ]; then
        printf '**Assistant:** %s\n' "$ASSISTANT_MSG"
    fi
} >> "$JOURNAL_FILE" 2>/dev/null || true

# Exit 0 — best-effort done. Stop event semantics preserved.
exit 0
