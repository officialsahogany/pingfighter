#!/usr/bin/env bash
# Lightweight auto-commit watcher for this repo.
# - Commits any pending changes at a fixed interval.
# - Optional auto-push when an upstream is configured.
#
# Usage:
#   tools/auto-commit.sh start   # start background watcher
#   tools/auto-commit.sh stop    # stop watcher
#   tools/auto-commit.sh status  # show status
#   tools/auto-commit.sh run     # internal: run loop (used by start)

set -euo pipefail

INTERVAL_SECS=${AUTO_COMMIT_INTERVAL:-20}
MSG_PREFIX=${AUTO_COMMIT_PREFIX:-"chore(auto): save"}
DO_PUSH=${AUTO_PUSH:-0}
# Sound options (default off per repo guidelines)
AUTO_SOUND=${AUTO_SOUND:-0}
AUTO_SOUND_FILE=${AUTO_SOUND_FILE:-}
AUTO_SOUND_VOLUME=${AUTO_SOUND_VOLUME:-1.0}

# Use repo-local state dir instead of .git to avoid sandbox restrictions
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || true
STATE_DIR="${AUTO_COMMIT_STATE_DIR:-${REPO_ROOT}/.autocommit}"
# Path relative to repo root (for git pathspec excludes)
REL_STATE_DIR="${STATE_DIR#${REPO_ROOT}/}"
mkdir -p "$STATE_DIR" 2>/dev/null || true
PIDFILE="${STATE_DIR}/pid"
LOGFILE="${STATE_DIR}/log"

ensure_git_repo() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "[auto-commit] Not inside a git repository." >&2
    exit 1
  fi
}

ensure_identity() {
  # Allow skipping identity writes in restricted environments
  if [[ "${AUTO_SKIP_IDENTITY:-0}" == "1" ]]; then
    return 0
  fi
  # If any level has identity, do nothing
  if git -c safe.directory="*" config --get user.name >/dev/null 2>&1 \
     && git -c safe.directory="*" config --get user.email >/dev/null 2>&1; then
    return 0
  fi
  # Try to set local identity; ignore failures (e.g., read-only .git/config)
  git config --local user.name "Auto Save"  >/dev/null 2>&1 || \
    echo "[auto-commit] warn: cannot set git user.name (readonly?)" | tee -a "$LOGFILE" >/dev/null
  git config --local user.email "autocommit@local" >/dev/null 2>&1 || \
    echo "[auto-commit] warn: cannot set git user.email (readonly?)" | tee -a "$LOGFILE" >/dev/null
}

has_changes() {
  # Only consider repo changes excluding our state dir
  local out
  out=$(git status --porcelain -- . ":(exclude)${REL_STATE_DIR}")
  [[ -n "$out" ]]
}

maybe_push() {
  if [[ "$DO_PUSH" != "1" ]]; then
    return 0
  fi
  # Only push if upstream is set
  if git rev-parse --abbrev-ref --symbolic-full-name @{u} >/dev/null 2>&1; then
    local branch
    branch=$(git rev-parse --abbrev-ref HEAD)
    git push -q --set-upstream origin "$branch" 2>>"$LOGFILE" || true
  fi
}

commit_once() {
  local ts msg
  ts=$(date '+%Y-%m-%d %H:%M:%S')
  msg="$MSG_PREFIX: $ts"
  # Stage everything except our state dir
  git add -A -- . ":(exclude)${REL_STATE_DIR}"
  # If nothing to commit, `git commit` exits non-zero; guard via conditional
  if git commit -qm "$msg"; then
    echo "[auto-commit] committed: $msg" | tee -a "$LOGFILE"
    maybe_push
    play_sound || true
  fi
}

loop() {
  # Run from repo root for stable behavior
  cd "$(git rev-parse --show-toplevel)"
  echo "[auto-commit] starting loop (every ${INTERVAL_SECS}s, push=${DO_PUSH}, sound=${AUTO_SOUND})" | tee -a "$LOGFILE"
  while true; do
    if has_changes; then
      commit_once
    fi
    sleep "$INTERVAL_SECS"
  done
}

start() {
  ensure_git_repo
  ensure_identity
  if [[ -f "$PIDFILE" ]] && ps -p "$(cat "$PIDFILE" 2>/dev/null)" >/dev/null 2>&1; then
    echo "[auto-commit] already running (pid $(cat "$PIDFILE"))"
    exit 0
  fi
  # Spawn detached background process
  nohup env \
    AUTO_COMMIT_INTERVAL="$INTERVAL_SECS" \
    AUTO_COMMIT_PREFIX="$MSG_PREFIX" \
    AUTO_PUSH="$DO_PUSH" \
    AUTO_SOUND="$AUTO_SOUND" \
    AUTO_SOUND_FILE="$AUTO_SOUND_FILE" \
    AUTO_SOUND_VOLUME="$AUTO_SOUND_VOLUME" \
    AUTO_SKIP_IDENTITY="${AUTO_SKIP_IDENTITY:-0}" \
    GIT_AUTHOR_NAME="${GIT_AUTHOR_NAME:-Auto Save}" \
    GIT_AUTHOR_EMAIL="${GIT_AUTHOR_EMAIL:-autocommit@local}" \
    GIT_COMMITTER_NAME="${GIT_COMMITTER_NAME:-Auto Save}" \
    GIT_COMMITTER_EMAIL="${GIT_COMMITTER_EMAIL:-autocommit@local}" \
    bash -c "$(printf '%q ' "$0") run" >>"$LOGFILE" 2>&1 &
  local pid=$!
  echo "$pid" >"$PIDFILE"
  echo "[auto-commit] started (pid $pid). Log: $LOGFILE"
}

stop() {
  ensure_git_repo
  if [[ -f "$PIDFILE" ]]; then
    local pid
    pid=$(cat "$PIDFILE" 2>/dev/null || echo "")
    if [[ -n "$pid" ]] && ps -p "$pid" >/dev/null 2>&1; then
      kill "$pid" || true
      echo "[auto-commit] stopped (pid $pid)"
    fi
    rm -f "$PIDFILE"
  else
    echo "[auto-commit] not running"
  fi
}

status() {
  ensure_git_repo
  local pid=""
  if [[ -f "$PIDFILE" ]]; then pid=$(cat "$PIDFILE" 2>/dev/null || true); fi
  if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
    echo "[auto-commit] running (pid $pid)"
  else
    echo "[auto-commit] stopped"
  fi
  echo "[auto-commit] interval=${INTERVAL_SECS}s prefix='${MSG_PREFIX}' push=${DO_PUSH}"
  # Report the last started runtime config from log if available
  if [[ -f "$LOGFILE" ]]; then
    local last
    last=$(grep -n "starting loop (every" "$LOGFILE" | tail -n1 | sed 's/^[0-9]*://')
    if [[ -n "$last" ]]; then
      echo "[auto-commit] last-start: ${last}"
    fi
  fi
  echo "[auto-commit] log: $LOGFILE"
}

# --- Sound playback (best-effort, non-fatal) ---
play_sound() {
  [[ "${AUTO_SOUND}" == "1" ]] || return 0
  local os cmd f
  os=$(uname -s 2>/dev/null || echo "")
  f="${AUTO_SOUND_FILE}"
  if [[ "$os" == "Darwin" ]]; then
    # macOS: prefer afplay with a default system sound
    if [[ -z "$f" ]]; then
      # Choose a well-known bundled sound
      for cand in \
        /System/Library/Sounds/Glass.aiff \
        /System/Library/Sounds/Ping.aiff \
        /System/Library/Sounds/Pop.aiff; do
        if [[ -f "$cand" ]]; then f="$cand"; break; fi
      done
    fi
    if command -v afplay >/dev/null 2>&1 && [[ -f "$f" ]]; then
      afplay -v "${AUTO_SOUND_VOLUME}" "$f" >/dev/null 2>&1 || true
      return 0
    fi
    # Fallback: system beep
    if command -v osascript >/dev/null 2>&1; then osascript -e 'beep 1' || true; return 0; fi
    printf '\a' || true
    return 0
  fi
  # Linux candidates
  if command -v paplay >/dev/null 2>&1 && [[ -n "$f" && -f "$f" ]]; then
    paplay "$f" >/dev/null 2>&1 || true; return 0
  fi
  if command -v canberra-gtk-play >/dev/null 2>&1; then
    canberra-gtk-play -i complete >/dev/null 2>&1 || true; return 0
  fi
  if command -v aplay >/dev/null 2>&1 && [[ -n "$f" && -f "$f" ]]; then
    aplay "$f" >/dev/null 2>&1 || true; return 0
  fi
  # Windows (Git Bash / MSYS with PowerShell available)
  if command -v powershell >/dev/null 2>&1; then
    powershell -NoProfile -Command "[console]::beep(1000,200)" >/dev/null 2>&1 || true
    return 0
  fi
  # Terminal bell as last resort
  printf '\a' || true
}

case "${1:-}" in
  start) start ;;
  stop)  stop  ;;
  status) status ;;
  run)   loop  ;;
  start-fg|fg)
    ensure_git_repo; ensure_identity; loop ;;
  once)
    ensure_git_repo; ensure_identity; if has_changes; then commit_once; else echo "[auto-commit] no changes"; fi ;;
  sound|beep|test-sound)
    # One-shot sound test
    AUTO_SOUND=1 play_sound ;;
  *)
    echo "Usage: $0 {start|stop|status|run|start-fg|once|sound}" >&2
    exit 2
    ;;
esac
