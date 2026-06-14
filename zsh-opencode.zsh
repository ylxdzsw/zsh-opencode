#!/usr/bin/env zsh
# OpenCode modal shell: plan> / build> prompts routed to `opencode run`.

: ${ZSH_OPENCODE_PLAN_KEY:='^[^P'}
: ${ZSH_OPENCODE_BUILD_KEY:='^[^B'}
: ${ZSH_OPENCODE_EXIT_KEY:='^['}
: ${ZSH_OPENCODE_SWITCH_KEY:='^I'}
: ${ZSH_OPENCODE_TRACK_SESSIONS:=1}
: ${ZSH_OPENCODE_BIND_KEYMAPS:='main viins vicmd'}

typeset -g ZSH_OPENCODE_MODE=0
typeset -g ZSH_OPENCODE_AGENT=plan
typeset -g ZSH_OPENCODE_SAVED_KEYMAP=''
typeset -gA ZSH_OPENCODE_SAVED_PROMPTS
typeset -ga ZSH_OPENCODE_PROMPT_VARS=(PROMPT RPROMPT RPROMPT2)

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
  RPROMPT=''
  RPROMPT2=''
}

function _zsh_opencode_activate_keymap() {
  ZSH_OPENCODE_SAVED_KEYMAP="${KEYMAP:-main}"
  bindkey -M opencodemode "$ZSH_OPENCODE_SWITCH_KEY" _zsh_opencode_switch_agent
  bindkey -M opencodemode "$ZSH_OPENCODE_EXIT_KEY" _zsh_opencode_exit_mode
  bindkey -M opencodemode '^M' _zsh_opencode_accept_line
  bindkey -M opencodemode '^J' _zsh_opencode_accept_line
  zle -K opencodemode
}

function _zsh_opencode_deactivate_keymap() {
  zle -K "${ZSH_OPENCODE_SAVED_KEYMAP:-main}"
}

function _zsh_opencode_enter_mode() {
  local agent="$1"

  if (( ! ZSH_OPENCODE_MODE )); then
    local v
    for v in "${ZSH_OPENCODE_PROMPT_VARS[@]}"; do
      ZSH_OPENCODE_SAVED_PROMPTS[$v]="${(P)v}"
    done
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
  local v
  for v in "${ZSH_OPENCODE_PROMPT_VARS[@]}"; do
    eval "$v=\${ZSH_OPENCODE_SAVED_PROMPTS[$v]-}"
  done
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
  local session_id discovered
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

  # Let opencode's stderr (UI chrome / progress) stream live to the
  # terminal. Stdout is also written directly so the user sees the
  # response as it's produced.
  "${cmd[@]}" -- "$msg" || exit_code=$?

  zle -I

  if (( exit_code )); then
    print -u2 -r -- "zsh-opencode: opencode run exited with status $exit_code"
  fi

  if (( ZSH_OPENCODE_TRACK_SESSIONS )) && [[ -z "$session_id" ]]; then
    discovered=$(_zsh_opencode_discover_session)
    [[ -n "$discovered" ]] && _zsh_opencode_set_session "$discovered"
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

function _zsh_opencode_chpwd() {
  if (( ZSH_OPENCODE_MODE )); then
    _zsh_opencode_exit_mode
  fi
}

function _zsh_opencode_bind_widgets() {
  zle -N _zsh_opencode_enter_plan
  zle -N _zsh_opencode_enter_build
  zle -N _zsh_opencode_exit_mode
  zle -N _zsh_opencode_switch_agent
  zle -N _zsh_opencode_accept_line
}

function _zsh_opencode_bind_keys() {
  local -a kmaps
  kmaps=(${(z)ZSH_OPENCODE_BIND_KEYMAPS})
  local km
  for km in "${kmaps[@]}"; do
    bindkey -M "$km" "$ZSH_OPENCODE_PLAN_KEY"  _zsh_opencode_enter_plan  2>/dev/null
    bindkey -M "$km" "$ZSH_OPENCODE_BUILD_KEY" _zsh_opencode_enter_build 2>/dev/null
  done
}

_zsh_opencode_bind_widgets
_zsh_opencode_bind_keys

# Create the opencodemode keymap once at load time. The four mode-specific
# widget bindings (Tab/Esc/Enter) are reapplied on each entry, but the
# keymap itself is not recreated, so any bindings a user (or another
# plugin) added to opencodemode survive mode entry/exit cycles.
bindkey -N opencodemode main

# Auto-exit OpenCode mode on directory change so the modal keymap and
# prompts don't bleed across `cd`.
autoload -Uz add-zsh-hook
add-zsh-hook chpwd _zsh_opencode_chpwd
