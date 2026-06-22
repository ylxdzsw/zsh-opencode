#!/usr/bin/env zsh
# In-memory session tracking (per realpath, shared across plan/build agents).
# Local sessions are discovered via `opencode session list --format json`.
# jq is preferred for parsing, with python3 as a fallback.
# Attach mode does not use local discovery; `opencode run --attach` resolves
# remote continuation against the current ${PWD:A} workspace.

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

function _zsh_opencode_parse_session_ids() {
  local dir="$1"

  if command -v jq >/dev/null 2>&1; then
    command jq -r --arg dir "$dir" \
      '.[] | select(.directory == $dir) | (.id // .sessionID // empty)'
  elif command -v python3 >/dev/null 2>&1; then
    command python3 -c '
import json, sys
target = sys.argv[1]
try:
    sessions = json.load(sys.stdin)
except Exception:
    sys.exit(1)
for session in sessions:
    if isinstance(session, dict) and session.get("directory") == target:
        session_id = session.get("id") or session.get("sessionID")
        if session_id:
            print(session_id)
' "$dir"
  else
    print -u2 -r -- "zsh-opencode: session tracking requires jq or python3"
    return 1
  fi
}

function _zsh_opencode_list_session_ids() {
  local dir json
  dir=$(_zsh_opencode_pwd_key)

  json=$(command opencode session list --format json 2>/dev/null) || return 1
  [[ -n "$json" ]] || return 0
  _zsh_opencode_parse_session_ids "$dir" <<< "$json"
}

function _zsh_opencode_find_new_session() {
  local before="$1" after="$2" id
  local -a before_ids new_ids
  local -A known

  before_ids=("${(@f)before}")
  for id in "${before_ids[@]}"; do
    [[ -n "$id" ]] && known[$id]=1
  done

  for id in "${(@f)after}"; do
    [[ -n "$id" && -z "${known[$id]:-}" ]] && new_ids+=("$id")
  done

  (( ${#new_ids} == 1 )) || return 1
  print -r -- "$new_ids[1]"
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
  print -r -- "attach:  ${ZSH_OPENCODE_ATTACH_URL:-}"
  print -r -- "pwd:     $(_zsh_opencode_pwd_key)"
}
