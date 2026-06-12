#!/usr/bin/env zsh
# OpenCode modal shell: plan> / build> prompts routed to `opencode run`.

: ${ZSH_OPENCODE_PLAN_KEY:='^[^P'}
: ${ZSH_OPENCODE_BUILD_KEY:='^[^B'}
: ${ZSH_OPENCODE_EXIT_KEY:='^['}
: ${ZSH_OPENCODE_SWITCH_KEY:='^I'}
: ${ZSH_OPENCODE_TRACK_SESSIONS:=1}

typeset -g ZSH_OPENCODE_MODE=0
typeset -g ZSH_OPENCODE_AGENT=plan
typeset -g ZSH_OPENCODE_SAVED_PROMPT=''

function _zsh_opencode_update_prompt() {
  case "$ZSH_OPENCODE_AGENT" in
    plan)
      PROMPT=$'%F{cyan}plan>%f '
      ;;
    build)
      PROMPT=$'%F{green}build>%f '
      ;;
    *)
      PROMPT=$'%F{yellow}opencode>%f '
      ;;
  esac
}

function _zsh_opencode_activate_keymap() {
  bindkey -A main opencodemode 2>/dev/null || bindkey -N opencodemode main
  bindkey -M opencodemode "$ZSH_OPENCODE_SWITCH_KEY" _zsh_opencode_switch_agent
  bindkey -M opencodemode "$ZSH_OPENCODE_EXIT_KEY" _zsh_opencode_exit_mode
  bindkey -M opencodemode '^M' _zsh_opencode_accept_line
  bindkey -M opencodemode '^J' _zsh_opencode_accept_line
  zle -K opencodemode
}

function _zsh_opencode_deactivate_keymap() {
  zle -K main
}

function _zsh_opencode_enter_mode() {
  local agent="$1"

  if (( ! ZSH_OPENCODE_MODE )); then
    ZSH_OPENCODE_SAVED_PROMPT="$PROMPT"
  fi

  ZSH_OPENCODE_MODE=1
  ZSH_OPENCODE_AGENT="$agent"
  _zsh_opencode_update_prompt
  _zsh_opencode_activate_keymap
  zle reset-prompt
}

function _zsh_opencode_enter_plan() {
  _zsh_opencode_enter_mode plan
}

function _zsh_opencode_enter_build() {
  _zsh_opencode_enter_mode build
}

function _zsh_opencode_exit_mode() {
  if (( ! ZSH_OPENCODE_MODE )); then
    return 0
  fi

  ZSH_OPENCODE_MODE=0
  PROMPT="$ZSH_OPENCODE_SAVED_PROMPT"
  BUFFER=""
  _zsh_opencode_deactivate_keymap
  zle reset-prompt
}

function _zsh_opencode_switch_agent() {
  if (( ! ZSH_OPENCODE_MODE )); then
    zle expand-or-complete
    return
  fi

  if [[ "$ZSH_OPENCODE_AGENT" == plan ]]; then
    ZSH_OPENCODE_AGENT=build
  else
    ZSH_OPENCODE_AGENT=plan
  fi

  _zsh_opencode_update_prompt
  zle reset-prompt
}

function _zsh_opencode_run() {
  local msg="$1"
  local session_id output discovered
  local -a cmd=(opencode run --agent "$ZSH_OPENCODE_AGENT")
  local exit_code=0

  if ! command -v opencode >/dev/null 2>&1; then
    print -u2 -r -- "zsh-opencode: opencode not found in PATH"
    return 127
  fi

  session_id="$(_zsh_opencode_get_session)"
  if [[ -n "$session_id" ]]; then
    cmd+=(-s "$session_id")
  elif (( ! ZSH_OPENCODE_TRACK_SESSIONS )); then
    cmd+=(-c)
  fi

  output=$("${cmd[@]}" -- "$msg" 2>&1) || exit_code=$?
  print -r -- "$output"

  if (( ZSH_OPENCODE_TRACK_SESSIONS )) && [[ -z "$session_id" ]]; then
    _zsh_opencode_capture_session "$output"
  fi

  return "$exit_code"
}

function _zsh_opencode_accept_line() {
  local msg

  if (( ! ZSH_OPENCODE_MODE )); then
    zle .accept-line
    return
  fi

  msg="${BUFFER##[[:space:]]#}"
  msg="${msg%%[[:space:]]#}"
  if [[ -z "$msg" ]]; then
    return 0
  fi

  BUFFER=""
  zle reset-prompt
  _zsh_opencode_run "$msg"
}

function _zsh_opencode_bind_widgets() {
  zle -N _zsh_opencode_enter_plan
  zle -N _zsh_opencode_enter_build
  zle -N _zsh_opencode_exit_mode
  zle -N _zsh_opencode_switch_agent
  zle -N _zsh_opencode_accept_line
}

function _zsh_opencode_bind_keys() {
  bindkey "$ZSH_OPENCODE_PLAN_KEY" _zsh_opencode_enter_plan
  bindkey "$ZSH_OPENCODE_BUILD_KEY" _zsh_opencode_enter_build
}

_zsh_opencode_bind_widgets
_zsh_opencode_bind_keys
