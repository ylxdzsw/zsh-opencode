#!/usr/bin/env zsh

emulate -L zsh
setopt errexit nounset pipefail

local root=${0:A:h:h}
local dependency
for dependency in script timeout perl col cmp; do
  command -v "$dependency" >/dev/null || {
    print -u2 -r -- "missing test dependency: $dependency"
    return 1
  }
done

local tmp=$(mktemp -d)
TRAPEXIT() {
  local exit_code=$?
  if (( ZSH_SUBSHELL == 0 )); then
    if (( exit_code )); then
      print -u2 -r -- "test artifacts: $tmp"
    else
      rm -rf -- "$tmp"
    fi
  fi
  return $exit_code
}

local fake_bin=$tmp/bin
local capture_args=$tmp/args
local capture_stdin=$tmp/stdin
local capture_calls=$tmp/calls
local history_file=$tmp/history
local transcript=$tmp/transcript
mkdir -p -- "$fake_bin"

cat > "$fake_bin/opencode" <<'EOF'
#!/bin/sh
printf x >> "$TEST_CAPTURE_CALLS"
printf '%s\n' "$@" > "$TEST_CAPTURE_ARGS"
cat > "$TEST_CAPTURE_STDIN"
exit "${TEST_EXIT_CODE:-0}"
EOF
chmod +x "$fake_bin/opencode"

local first=$'quote \'" \\ $HOME $(touch '"$tmp"$'/injected); | & * !'
local second='ASCII line 2'
local prompt=$first$'\n'$second$'\n'
local setup="PS1='shell> '; PATH=${(q)fake_bin}:\$PATH; export TEST_CAPTURE_ARGS=${(q)capture_args} TEST_CAPTURE_STDIN=${(q)capture_stdin} TEST_CAPTURE_CALLS=${(q)capture_calls} TEST_EXIT_CODE=23; HISTFILE=${(q)history_file}; HISTSIZE=100; SAVEHIST=100; setopt INC_APPEND_HISTORY; ZSH_OPENCODE_TRACK_SESSIONS=0; source ${(q)root}/zsh-opencode.plugin.zsh"

local interactive_status=0
{
  print -r -- "$setup"
  sleep 0.2
  print -rn -- $'\t'"$first"$'\e[13;2u'"$second"$'\e[13;2u\r'
  sleep 0.2
  print -rn -- $'\x7f'
  sleep 0.2
  print -rn -- $'\e[A\r'
  sleep 0.2
  print -rn -- $'\x04'
} | timeout 5 script -qfec 'TERM=xterm-256color zsh -df' "$transcript" >/dev/null || interactive_status=$?
(( interactive_status == 23 ))

local normalized
normalized=$(perl -pe 's/\e\[[0-?]*[ -\/]*[@-~]//g' "$transcript" | col -b)
[[ $normalized == *"$first"* ]]
[[ $normalized == *"$second"* ]]
[[ $normalized == *'zsh-opencode: opencode run exited with status 23'* ]]
[[ $normalized != *'_zsh_opencode_send'* ]]
[[ ! -e $tmp/injected ]]
[[ $(<"$capture_calls") == xx ]]

local -a expected_args=(run --agent plan -c)
local -a actual_args=("${(@f)$(<"$capture_args")}")
[[ "${(j:\0:)actual_args}" == "${(j:\0:)expected_args}" ]]

local expected_stdin=$tmp/expected-stdin
print -rn -- "$prompt"$'\n' > "$expected_stdin"
cmp -- "$expected_stdin" "$capture_stdin"

local -a history_lines=("${(@f)$(<"$history_file")}")
local history_line=$history_lines[-1]
[[ $history_line == 'opencode run --agent plan -c <<< '* ]]
[[ $history_line != *$'\n'* ]]

local replay_status=0
PATH="$fake_bin:$PATH" TEST_CAPTURE_ARGS="$capture_args" \
  TEST_CAPTURE_STDIN="$capture_stdin" TEST_CAPTURE_CALLS="$capture_calls" \
  TEST_EXIT_CODE=23 \
  zsh -dfc "$history_line" || replay_status=$?
(( replay_status == 23 ))
cmp -- "$expected_stdin" "$capture_stdin"
[[ ! -e $tmp/injected ]]

source "$root/zsh-opencode.plugin.zsh"
local unicode_prompt=$'香港 café 🐚\tquote \' slash \\\n'
_zsh_opencode_record_history "$unicode_prompt" opencode run --agent plan
local unicode_history=$(fc -ln -1)
PATH="$fake_bin:$PATH" TEST_CAPTURE_ARGS="$capture_args" \
  TEST_CAPTURE_STDIN="$capture_stdin" TEST_CAPTURE_CALLS="$capture_calls" \
  TEST_EXIT_CODE=0 \
  zsh -dfc "$unicode_history"
print -rn -- "$unicode_prompt"$'\n' > "$expected_stdin"
cmp -- "$expected_stdin" "$capture_stdin"

local missing_bin=$tmp/missing-bin
mkdir -p -- "$missing_bin"
local saved_path=$PATH
PATH=$missing_bin
local -a recorded_lines

ZSH_OPENCODE_TRACK_SESSIONS=0
local missing_status=0
_zsh_opencode_run 'missing untracked' 2>/dev/null || missing_status=$?
(( missing_status == 127 ))
recorded_lines=("${(@f)$(fc -ln 1)}")
[[ $recorded_lines[-1] == 'opencode run --agent plan -c <<< '* ]]

ZSH_OPENCODE_TRACK_SESSIONS=1
_zsh_opencode_set_session pinned-session
missing_status=0
_zsh_opencode_run 'missing pinned' 2>/dev/null || missing_status=$?
(( missing_status == 127 ))
recorded_lines=("${(@f)$(fc -ln 1)}")
[[ $recorded_lines[-1] == 'opencode run --agent plan -s pinned-session <<< '* ]]

PATH=$saved_path
_zsh_opencode_clear_session

print 'ok'
