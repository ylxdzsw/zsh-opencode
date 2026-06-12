#!/usr/bin/env zsh
# zsh-opencode plugin entry point.

[[ -n ${ZSH_OPENCODE_LOADED:-} ]] && return 0
ZSH_OPENCODE_LOADED=1

0=${(%):-%N}
ZSH_OPENCODE_ROOT=${0:A:h}

source "$ZSH_OPENCODE_ROOT/zsh-opencode-session.zsh"
source "$ZSH_OPENCODE_ROOT/zsh-opencode.zsh"
