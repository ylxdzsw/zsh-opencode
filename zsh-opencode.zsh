#!/usr/bin/env zsh
# OpenCode modal shell: plan> / build> prompts routed to `opencode run`.

: ${ZSH_OPENCODE_TRACK_SESSIONS:=1}
: ${ZSH_OPENCODE_BIND_KEYMAPS:='main viins vicmd'}

typeset -g ZSH_OPENCODE_MODE=0
typeset -g ZSH_OPENCODE_AGENT=plan
typeset -g ZSH_OPENCODE_SAVED_KEYMAP=''
typeset -g ZSH_OPENCODE_HISTORY_AGENT=''
typeset -g ZSH_OPENCODE_HISTORY_BUFFER=''
typeset -gi ZSH_OPENCODE_HISTORY_CURSOR=0
typeset -gi ZSH_OPENCODE_HISTORY_HISTNO=0
typeset -g ZSH_OPENCODE_HAD_HIGHLIGHTERS=0
typeset -g ZSH_OPENCODE_DISABLED_AUTOSUGGESTIONS=0
typeset -gA ZSH_OPENCODE_SAVED_PROMPTS
typeset -gA ZSH_OPENCODE_SHELL_TAB_WIDGETS
typeset -gA ZSH_OPENCODE_SHELL_DOWN_WIDGETS
typeset -ga ZSH_OPENCODE_PROMPT_VARS=(PROMPT RPROMPT RPROMPT2)
typeset -ga ZSH_OPENCODE_SAVED_HIGHLIGHTERS
typeset -ga ZSH_OPENCODE_ENTER_HOOKS
typeset -ga ZSH_OPENCODE_EXIT_HOOKS

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

function _zsh_opencode_save_prompt() {
  local v
  for v in "${ZSH_OPENCODE_PROMPT_VARS[@]}"; do
    ZSH_OPENCODE_SAVED_PROMPTS[$v]="${(P)v}"
  done
}

function _zsh_opencode_restore_prompt() {
  local v
  for v in "${ZSH_OPENCODE_PROMPT_VARS[@]}"; do
    eval "$v=\${ZSH_OPENCODE_SAVED_PROMPTS[$v]-}"
  done
}

function _zsh_opencode_disable_editor_plugins() {
  if (( $+ZSH_HIGHLIGHT_HIGHLIGHTERS )); then
    ZSH_OPENCODE_HAD_HIGHLIGHTERS=1
    ZSH_OPENCODE_SAVED_HIGHLIGHTERS=("${ZSH_HIGHLIGHT_HIGHLIGHTERS[@]}")
    ZSH_HIGHLIGHT_HIGHLIGHTERS=()
  else
    ZSH_OPENCODE_HAD_HIGHLIGHTERS=0
    ZSH_OPENCODE_SAVED_HIGHLIGHTERS=()
  fi

  ZSH_OPENCODE_DISABLED_AUTOSUGGESTIONS=0
  if (( ! ${+_ZSH_AUTOSUGGEST_DISABLED} )) && zle -l autosuggest-disable >/dev/null 2>&1; then
    if zle autosuggest-disable; then
      ZSH_OPENCODE_DISABLED_AUTOSUGGESTIONS=1
    fi
  fi
}

function _zsh_opencode_restore_editor_plugins() {
  if (( ZSH_OPENCODE_HAD_HIGHLIGHTERS )); then
    ZSH_HIGHLIGHT_HIGHLIGHTERS=("${ZSH_OPENCODE_SAVED_HIGHLIGHTERS[@]}")
  else
    unset ZSH_HIGHLIGHT_HIGHLIGHTERS
  fi

  if (( ZSH_OPENCODE_DISABLED_AUTOSUGGESTIONS )) && zle -l autosuggest-enable >/dev/null 2>&1; then
    zle autosuggest-enable
  fi
  ZSH_OPENCODE_DISABLED_AUTOSUGGESTIONS=0
}

function _zsh_opencode_run_hooks() {
  local hook
  for hook in "$@"; do
    if (( $+functions[$hook] )); then
      "$hook"
    else
      print -u2 -r -- "zsh-opencode: hook function not found: $hook"
    fi
  done
}

function _zsh_opencode_configure_agent_keymap() {
  bindkey -M opencodemode '^M' _zsh_opencode_accept_line
  bindkey -M opencodemode '^I' _zsh_opencode_agent_tab
  bindkey -M opencodemode $'\e[A' _zsh_opencode_agent_up
  bindkey -M opencodemode $'\eOA' _zsh_opencode_agent_up
  bindkey -M opencodemode $'\e[B' _zsh_opencode_agent_down
  bindkey -M opencodemode $'\eOB' _zsh_opencode_agent_down
  bindkey -M opencodemode '^?' _zsh_opencode_backspace
  bindkey -M opencodemode '^D' _zsh_opencode_delete_or_exit
  bindkey -M opencodemode '^C' _zsh_opencode_cancel_line
  bindkey -M opencodemode '^[[13;2u' _zsh_opencode_newline
  bindkey -r -M opencodemode '^[' 2>/dev/null
  bindkey -r -M opencodemode '^J' 2>/dev/null
}

function _zsh_opencode_activate_keymap() {
  ZSH_OPENCODE_SAVED_KEYMAP="${KEYMAP:-main}"
  zle -K opencodemode
}

function _zsh_opencode_deactivate_keymap() {
  zle -K "${ZSH_OPENCODE_SAVED_KEYMAP:-main}" 2>/dev/null || zle -K main
}

function _zsh_opencode_enter_mode() {
  local agent="$1"
  local entering=$(( ! ZSH_OPENCODE_MODE ))

  if (( entering )); then
    _zsh_opencode_save_prompt
    _zsh_opencode_disable_editor_plugins
  fi

  ZSH_OPENCODE_MODE=1
  ZSH_OPENCODE_AGENT="$agent"
  _zsh_opencode_update_prompt
  if (( entering )); then
    _zsh_opencode_activate_keymap
  else
    zle -K opencodemode
  fi
  (( entering )) && _zsh_opencode_run_hooks "${ZSH_OPENCODE_ENTER_HOOKS[@]}"
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

  _zsh_opencode_run_hooks "${ZSH_OPENCODE_EXIT_HOOKS[@]}"
  ZSH_OPENCODE_MODE=0
  _zsh_opencode_restore_prompt
  _zsh_opencode_restore_editor_plugins
  _zsh_opencode_deactivate_keymap
  zle reset-prompt
}

function _zsh_opencode_clear_history_return() {
  ZSH_OPENCODE_HISTORY_AGENT=''
  ZSH_OPENCODE_HISTORY_BUFFER=''
  ZSH_OPENCODE_HISTORY_CURSOR=0
  ZSH_OPENCODE_HISTORY_HISTNO=0
}

function _zsh_opencode_switch_agent() {
  if [[ "$ZSH_OPENCODE_AGENT" == plan ]]; then
    ZSH_OPENCODE_AGENT=build
  else
    ZSH_OPENCODE_AGENT=plan
  fi

  _zsh_opencode_update_prompt
  zle reset-prompt
}

function _zsh_opencode_shell_tab() {
  local km widget

  if (( ZSH_OPENCODE_MODE )); then
    _zsh_opencode_agent_tab
    return
  fi

  if [[ -z "$BUFFER" ]]; then
    _zsh_opencode_enter_plan
    return
  fi

  km="${KEYMAP:-main}"
  widget="${ZSH_OPENCODE_SHELL_TAB_WIDGETS[$km]:-expand-or-complete}"
  if [[ -z "$widget" || "$widget" == _zsh_opencode_shell_tab ]]; then
    widget=expand-or-complete
  fi
  zle "$widget"
}

function _zsh_opencode_shell_down() {
  local km key widget

  km="${KEYMAP:-main}"
  key="${km}:${KEYS}"
  widget="${ZSH_OPENCODE_SHELL_DOWN_WIDGETS[$key]:-down-line-or-history}"
  if [[ -z "$widget" || "$widget" == _zsh_opencode_shell_down ]]; then
    widget=down-line-or-history
  fi
  zle "$widget"

  if [[ -n "$ZSH_OPENCODE_HISTORY_AGENT" ]] &&
     (( HISTNO == ZSH_OPENCODE_HISTORY_HISTNO )) &&
     [[ "$BUFFER" == "$ZSH_OPENCODE_HISTORY_BUFFER" ]]; then
    local agent="$ZSH_OPENCODE_HISTORY_AGENT"
    local cursor="$ZSH_OPENCODE_HISTORY_CURSOR"
    _zsh_opencode_clear_history_return
    CURSOR=$cursor
    _zsh_opencode_enter_mode "$agent"
  fi
}

function _zsh_opencode_agent_tab() {
  if (( CURSOR == 0 )); then
    _zsh_opencode_switch_agent
    return
  fi

  LBUFFER+=$'\t'
  CURSOR=${#LBUFFER}
}

function _zsh_opencode_agent_up() {
  local before_histno="$HISTNO"
  local before_buffer="$BUFFER"
  local before_cursor="$CURSOR"
  local agent="$ZSH_OPENCODE_AGENT"

  zle .up-line-or-history

  if (( HISTNO != before_histno )); then
    ZSH_OPENCODE_HISTORY_AGENT="$agent"
    ZSH_OPENCODE_HISTORY_BUFFER="$before_buffer"
    ZSH_OPENCODE_HISTORY_CURSOR="$before_cursor"
    ZSH_OPENCODE_HISTORY_HISTNO="$before_histno"
    _zsh_opencode_exit_mode
  fi
}

function _zsh_opencode_agent_down() {
  zle .down-line-or-history
}

function _zsh_opencode_newline() {
  LBUFFER+=$'\n'
  CURSOR=${#LBUFFER}
}

function _zsh_opencode_backspace() {
  if (( CURSOR == 0 )); then
    _zsh_opencode_exit_mode
    return
  fi

  zle backward-delete-char
}

function _zsh_opencode_delete_or_exit() {
  if [[ -z "$BUFFER" ]]; then
    _zsh_opencode_exit_mode
    return
  fi

  if (( CURSOR < ${#BUFFER} )); then
    zle delete-char
  fi
}

function _zsh_opencode_cancel_line() {
  BUFFER=''
  CURSOR=0
  zle -I
  print -r -- '^C'
  _zsh_opencode_update_prompt
  zle reset-prompt
}

function _zsh_opencode_record_history() {
  local msg="$1"
  shift
  local -a cmd=("$@")
  local line="${(j: :)${(@q)cmd}} <<< ${(qqqq)msg}"
  print -sr -- "$line"
}

function _zsh_opencode_run() {
  local msg="$1"
  local session_id before_sessions after_sessions discovered
  local -a cmd=(opencode run --agent "$ZSH_OPENCODE_AGENT")
  local exit_code=0
  local snapshot_ok=0

  session_id="$(_zsh_opencode_get_session)"
  if [[ -n "$session_id" ]]; then
    cmd+=(-s "$session_id")
  elif (( ! ZSH_OPENCODE_TRACK_SESSIONS )); then
    cmd+=(-c)
  fi

  if ! command -v opencode >/dev/null 2>&1; then
    _zsh_opencode_record_history "$msg" "${cmd[@]}"
    print -u2 -r -- "zsh-opencode: opencode not found in PATH"
    return 127
  fi

  if (( ZSH_OPENCODE_TRACK_SESSIONS )) && [[ -z "$session_id" ]]; then
    if before_sessions="$(_zsh_opencode_list_session_ids)"; then
      snapshot_ok=1
    fi
  fi

  _zsh_opencode_record_history "$msg" "${cmd[@]}"

  # Let opencode own the terminal as a normal foreground command. The prompt
  # text is sent on stdin so shell parsing never interprets user prose.
  command "${cmd[@]}" <<< "$msg" || exit_code=$?

  if (( exit_code )); then
    print -u2 -r -- "zsh-opencode: opencode run exited with status $exit_code"
  fi

  if (( ! exit_code && snapshot_ok )); then
    if after_sessions="$(_zsh_opencode_list_session_ids)" && \
       discovered="$(_zsh_opencode_find_new_session "$before_sessions" "$after_sessions")"; then
      _zsh_opencode_set_session "$discovered"
    else
      print -u2 -r -- "zsh-opencode: could not identify one newly-created session; session was not pinned"
    fi
  fi

  return "$exit_code"
}

function _zsh_opencode_accept_line() {
  local msg

  if (( ! ZSH_OPENCODE_MODE )); then
    _zsh_opencode_clear_history_return
    zle .accept-line
    return
  fi

  msg="$BUFFER"
  if [[ -z "${msg//[[:space:]]/}" ]]; then
    return 0
  fi

  # Invalidate the current display before foreground output. Keeping the real
  # prose in BUFFER until this point leaves it intact in terminal scrollback.
  zle -I
  BUFFER=''
  CURSOR=0
  _zsh_opencode_run "$msg"
  zle .accept-line
}

function _zsh_opencode_chpwd() {
  if (( ZSH_OPENCODE_MODE )); then
    _zsh_opencode_exit_mode
  fi
}

function _zsh_opencode_precmd_rearm() {
  if (( ZSH_OPENCODE_MODE )); then
    _zsh_opencode_update_prompt
  fi
}

function _zsh_opencode_line_init() {
  if (( ZSH_OPENCODE_MODE )); then
    zle -K opencodemode
  fi
}

function _zsh_opencode_bind_widgets() {
  zle -N _zsh_opencode_enter_plan
  zle -N _zsh_opencode_enter_build
  zle -N _zsh_opencode_exit_mode
  zle -N _zsh_opencode_switch_agent
  zle -N _zsh_opencode_shell_tab
  zle -N _zsh_opencode_shell_down
  zle -N _zsh_opencode_agent_tab
  zle -N _zsh_opencode_agent_up
  zle -N _zsh_opencode_agent_down
  zle -N _zsh_opencode_newline
  zle -N _zsh_opencode_backspace
  zle -N _zsh_opencode_delete_or_exit
  zle -N _zsh_opencode_cancel_line
  zle -N _zsh_opencode_accept_line
}

function _zsh_opencode_save_shell_down_widget() {
  local km="$1"
  local seq="$2"
  local current key widget
  key="${km}:${seq}"

  current="$(bindkey -M "$km" "$seq" 2>/dev/null)"
  if [[ -n "$current" ]]; then
    widget="${current##* }"
    [[ "$widget" != _zsh_opencode_shell_down ]] && ZSH_OPENCODE_SHELL_DOWN_WIDGETS[$key]="$widget"
  else
    ZSH_OPENCODE_SHELL_DOWN_WIDGETS[$key]=down-line-or-history
  fi
}

function _zsh_opencode_bind_keys() {
  local -a kmaps
  kmaps=(${(z)ZSH_OPENCODE_BIND_KEYMAPS})
  local km current widget
  for km in "${kmaps[@]}"; do
    current="$(bindkey -M "$km" '^I' 2>/dev/null)"
    if [[ -n "$current" ]]; then
      widget="${current##* }"
      [[ "$widget" != _zsh_opencode_shell_tab ]] && ZSH_OPENCODE_SHELL_TAB_WIDGETS[$km]="$widget"
    else
      ZSH_OPENCODE_SHELL_TAB_WIDGETS[$km]=expand-or-complete
    fi
    bindkey -M "$km" '^I' _zsh_opencode_shell_tab 2>/dev/null
    _zsh_opencode_save_shell_down_widget "$km" $'\e[B'
    _zsh_opencode_save_shell_down_widget "$km" $'\eOB'
    bindkey -M "$km" $'\e[B' _zsh_opencode_shell_down 2>/dev/null
    bindkey -M "$km" $'\eOB' _zsh_opencode_shell_down 2>/dev/null
  done
}

autoload -Uz add-zsh-hook
autoload -Uz add-zle-hook-widget 2>/dev/null || true

bindkey -N opencodemode main 2>/dev/null || true
_zsh_opencode_configure_agent_keymap
_zsh_opencode_bind_widgets
_zsh_opencode_bind_keys

# Auto-exit OpenCode mode on directory change so the modal keymap and prompts
# don't bleed across workspaces.
add-zsh-hook chpwd _zsh_opencode_chpwd
add-zsh-hook precmd _zsh_opencode_precmd_rearm
add-zle-hook-widget line-init _zsh_opencode_line_init 2>/dev/null || true
