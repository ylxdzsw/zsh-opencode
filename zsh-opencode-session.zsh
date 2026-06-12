#!/usr/bin/env zsh
# In-memory session tracking (per realpath, shared across plan/build agents).

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

function _zsh_opencode_extract_session_from_output() {
  local output="$1"
  local match

  if [[ "$output" =~ '(ses_[A-Za-z0-9]+)' ]]; then
    print -r -- "$match[1]"
    return 0
  fi

  return 1
}

function _zsh_opencode_discover_session() {
  local db dir dir_escaped

  dir=$(_zsh_opencode_pwd_key)
  db=$(opencode db path 2>/dev/null) || return 1
  [[ -f "$db" ]] || return 1

  dir_escaped=${dir//\'/\'\'}
  sqlite3 "$db" "SELECT id FROM session WHERE directory = '${dir_escaped}' ORDER BY time_updated DESC LIMIT 1;" 2>/dev/null
}

function _zsh_opencode_capture_session() {
  local output="$1"
  local discovered

  discovered=$(_zsh_opencode_extract_session_from_output "$output")
  [[ -z "$discovered" ]] && discovered=$(_zsh_opencode_discover_session)
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
  print -r -- "mode:   $(( ZSH_OPENCODE_MODE ))"
  print -r -- "agent:  ${ZSH_OPENCODE_AGENT:-}"
  print -r -- "session: $(_zsh_opencode_get_session)"
  print -r -- "pwd:    $(_zsh_opencode_pwd_key)"
}
