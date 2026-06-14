#!/usr/bin/env zsh
# In-memory session tracking (per realpath, shared across plan/build agents).
# Sessions are discovered via `opencode session list --format json`; python3
# is used to pick the most recent session for the current directory.

typeset -gA ZSH_OPENCODE_SESSIONS

function _zsh_opencode_pwd_key() {
  print -r -- "${PWD:A}"
}

function _zsh_opencode_get_session() {
  print -r -- "${ZSH_OPENCODE_SESSIONS[$(_zsh_opencode_pwd_key)]:-}"
}

function _zsh_opencode_set_session() {
  [[ -n "$1" ]] || return 1
  ZSH_OPENCODE_SESSIONS[$(_zsh_opencode_pwd_key)]="$1"
}

function _zsh_opencode_clear_session() {
  unset "ZSH_OPENCODE_SESSIONS[$(_zsh_opencode_pwd_key)]"
}

function _zsh_opencode_discover_session() {
  local dir json
  dir=$(_zsh_opencode_pwd_key)

  json=$(opencode session list --format json 2>/dev/null) || return 1
  [[ -n "$json" ]] || return 1

  if command -v python3 >/dev/null 2>&1; then
    python3 -c '
import json, sys
target = sys.argv[1]
try:
    sessions = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
for s in sessions:
    if isinstance(s, dict) and s.get("directory") == target:
        sid = s.get("id") or s.get("sessionID") or ""
        if sid:
            print(sid)
            break
' "$dir" <<<"$json"
  else
    local line
    while IFS= read -r line; do
      if [[ "$line" == *"$dir"* ]] && [[ "$line" =~ (ses_[A-Za-z0-9]+) ]]; then
        print -r -- "$match[1]"
        return 0
      fi
    done <<< "$json"
  fi
}

function _zsh_opencode_capture_session() {
  local discovered
  discovered=$(_zsh_opencode_discover_session)
  [[ -n "$discovered" ]] && _zsh_opencode_set_session "$discovered"
}

function oc-reset() {
  _zsh_opencode_clear_session
  print -r -- "opencode session cleared for $(_zsh_opencode_pwd_key)"
}

function oc-continue() {
  if [[ $# -lt 1 ]]; then
    print -u2 -r -- "usage: oc-continue <session-id>"
    return 1
  fi
  _zsh_opencode_set_session "$1"
  print -r -- "opencode session set to $1 for $(_zsh_opencode_pwd_key)"
}

function oc-status() {
  print -r -- "mode:    $ZSH_OPENCODE_MODE"
  print -r -- "agent:   ${ZSH_OPENCODE_AGENT:-}"
  print -r -- "session: $(_zsh_opencode_get_session)"
  print -r -- "pwd:     $(_zsh_opencode_pwd_key)"
}
