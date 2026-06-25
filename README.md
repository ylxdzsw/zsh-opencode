# zsh-opencode

A zsh plugin that adds lightweight **OpenCode agent modes** to your normal
shell. Press Tab on an empty shell line to enter `plan>`, switch between
`plan>` and `build>` with Tab at the beginning of the prompt, and submit the
buffer to `opencode run` with the matching agent.

## Install

### Oh My Zsh

```bash
git clone https://github.com/ylxdzsw/zsh-opencode.git \
  ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-opencode
```

Add to `~/.zshrc`:

```zsh
plugins=(... zsh-opencode)
```

### Manual

```zsh
source /path/to/zsh-opencode/zsh-opencode.plugin.zsh
```

Requires `opencode` in your `PATH`. Tracked local sessions also require `jq`
(preferred) or `python3` to parse `opencode session list --format json`.

## Usage

| Key | Action |
|-----|--------|
| `Tab` on an empty shell line | Enter **plan** mode |
| `Tab` at cursor position 0 in plan/build | Switch plan ↔ build |
| `Tab` elsewhere in plan/build | Insert a literal tab |
| `Shift+Enter` in plan/build | Insert a literal newline (CSI-u terminals) |
| `Enter` in plan/build | Send buffer to `opencode run` |
| `Backspace` at cursor position 0 in plan/build | Exit to shell mode |
| `Ctrl+D` with an empty plan/build buffer | Exit to shell mode |
| `Ctrl+C` in plan/build | Clear the buffer and print a fresh agent prompt |

### Typical workflow

```
plan> design a refactor for the auth module     # Enter → opencode run --agent plan
<Tab at beginning>
build> implement step 1 from the plan           # Enter → same session, --agent build
```

Session IDs are kept **in memory only** (per directory, shared between agents).
They are cleared when the shell exits. Use `oc-reset` to clear the pinned
session for the current directory.

## Commands

| Command | Description |
|---------|-------------|
| `oc-status` | Show mode, agent, session id, and pwd |
| `oc-reset` | Clear in-memory session for current directory |
| `oc-continue <id>` | Pin a session id for current directory |

## Configuration

Set these before sourcing the plugin (or in `~/.zshrc` before plugins load):

```zsh
ZSH_OPENCODE_TRACK_SESSIONS=1             # 1 = track session in memory (default);
                                          #     first local-mode message in a dir
                                          #     starts a new opencode session,
                                          #     later messages continue it with
                                          #     -s <id>.
                                          # 0 = always pass -c in local mode.
ZSH_OPENCODE_BIND_KEYMAPS='main viins vicmd'
                                          # Keymaps whose Tab binding is wrapped.
                                          # main  : emacs mode (and vi insert in vi mode)
                                          # viins : vi insert mode (redundant with main
                                          #         when main is linked to viins, but
                                          #         listed for clarity)
                                          # vicmd : vi command mode — independent of
                                          #         main, so it must be listed for the
                                          #         empty-line Tab entry to work there.
                                          # Override to drop vicmd if you use vi mode
                                          # but want Tab entry to be insert-only.
ZSH_OPENCODE_ENTER_HOOKS=()               # functions called on mode entry
ZSH_OPENCODE_EXIT_HOOKS=()                # functions called on mode exit
```

### Custom key bindings

The plugin only installs the Tab entry wrapper by default. If you want extra
entry or exit keys, bind the exported widgets with normal zsh config after the
plugin is sourced:

```zsh
bindkey -M main '^P' _zsh_opencode_enter_plan
bindkey -M main '^B' _zsh_opencode_enter_build
bindkey -M opencodemode '^[' _zsh_opencode_exit_mode
```

## Session behavior

- One session per directory (`$PWD:A`), shared between plan and build agents.
- In local mode, the first tracked message in a directory starts a new
  opencode session. The plugin snapshots the directory's session ids before
  the run and pins the single new id afterward. Failed or ambiguous runs are
  not pinned, avoiding accidental continuation of an unrelated session.
- Later local-mode messages use `opencode run -s <id> --agent <plan|build>`.
- Nothing is written to disk by this plugin; restart zsh to forget sessions.
- Changing directory (`cd`) automatically exits OpenCode mode, so the modal
  keymap and prompt do not bleed across directories.

## Editor mode

- **Emacs mode** (default): empty-line Tab enters plan mode.
- **Vi mode** (`bindkey -v`): Tab is wrapped in `main`, `viins`, and `vicmd`
  by default. Override `ZSH_OPENCODE_BIND_KEYMAPS` if you only want this in
  insert mode.
- The dedicated `opencodemode` keymap inherits normal editing keys but
  overrides Enter, Shift+Enter, Tab, Backspace, Ctrl+D, and Ctrl+C. Esc and
  Ctrl+J are not bound by default.

## Prompt handling

- The plugin saves and restores `PROMPT`, `RPROMPT`, and `RPROMPT2` on mode
  entry and exit. `PROMPT2` is intentionally left untouched; agent input is
  prose and does not enter zsh's shell-continuation parser.
- Shell syntax highlighting and autosuggestions are disabled while in
  plan/build mode and restored on exit when those plugins are present.

### Plugin compatibility hooks

`ZSH_OPENCODE_ENTER_HOOKS` and `ZSH_OPENCODE_EXIT_HOOKS` contain names of zsh
functions to call inside ZLE when entering and leaving agent mode. Use them for
editor plugins that need their own suspend/resume calls:

```zsh
function my_opencode_enter() { zle my-plugin-disable }
function my_opencode_exit()  { zle my-plugin-enable }
ZSH_OPENCODE_ENTER_HOOKS+=(my_opencode_enter)
ZSH_OPENCODE_EXIT_HOOKS+=(my_opencode_exit)
```

zsh-autosuggestions is handled automatically through its `autosuggest-disable`
and `autosuggest-enable` ZLE widgets. If it was already disabled before agent
mode, the plugin leaves it disabled afterward.

## Buffer handling

- Sending a message leaves the submitted `plan>` or `build>` line visible in
  terminal scrollback, then clears the editable buffer for the next prompt.
- Each submission adds a replayable command to zsh history. The prompt is
  represented as a safely quoted here-string, for example:

  ```zsh
  opencode run --agent plan -c <<< $'explain the auth flow'
  ```

  Writing that entry to `HISTFILE` follows the shell's normal history options,
  such as `INC_APPEND_HISTORY` or `SHARE_HISTORY`.
- Up in agent mode loads shell history as shell input and exits agent mode, so
  replayable `opencode run ...` entries can be executed directly. Pressing Down
  back to the original line re-enters the agent prompt.
- Backspace at the beginning of the buffer exits agent mode and leaves the
  typed text on the shell line.
- Ctrl+D exits only when the agent buffer is empty.
- Ctrl+C clears the current agent buffer, leaves the discarded text visible in
  terminal scrollback, and stays in the same agent mode.
- Shift+Enter inserts a newline when the terminal emits the CSI-u sequence
  `^[[13;2u`, as WebTerm does. Traditional terminals commonly send the same
  carriage return for Enter and Shift+Enter, so zsh cannot distinguish them.

## Development

Run the syntax and interactive regression checks with:

```zsh
zsh -n zsh-opencode.zsh zsh-opencode-session.zsh zsh-opencode.plugin.zsh
zsh tests/test.zsh
```
