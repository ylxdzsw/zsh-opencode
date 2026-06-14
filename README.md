# zsh-opencode

A zsh plugin that adds an **OpenCode mode**: press a key combo to get a `plan>` or `build>` prompt, type a message, and have it run as `opencode run` with the matching agent. Tab switches between plan and build while staying in the same session.

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

Requires `opencode` and `python3` in your `PATH`. `python3` is only used to
parse `opencode session list --format json` when discovering a session for
the current directory; if it is missing, a regex fallback is used.

## Usage

| Key | Action |
|-----|--------|
| `Ctrl+P` | Enter OpenCode mode as **plan** |
| `Ctrl+B` | Enter OpenCode mode as **build** |
| `Tab` | Switch plan ↔ build (only in OpenCode mode) |
| `Enter` | Send buffer to `opencode run` |
| `Escape` | Exit OpenCode mode (buffer is left on the line) |

### Typical workflow

```
plan> design a refactor for the auth module     # Enter → opencode run --agent plan
[Tab]
build> implement step 1 from the plan           # Enter → same session, --agent build
```

Session IDs are kept **in memory only** (per directory, shared between agents). They are cleared when the shell exits. Use `oc-reset` to start a fresh session in the current directory.

## Commands

| Command | Description |
|---------|-------------|
| `oc-status` | Show mode, agent, session id, and pwd |
| `oc-reset` | Clear in-memory session for current directory |
| `oc-continue <id>` | Pin a session id for current directory |

## Configuration

Set these before sourcing the plugin (or in `~/.zshrc` before plugins load):

```zsh
ZSH_OPENCODE_PLAN_KEY='^P'                # default: Ctrl+P (overrides up-line-or-history)
ZSH_OPENCODE_BUILD_KEY='^B'               # default: Ctrl+B (overrides backward-char)
ZSH_OPENCODE_EXIT_KEY='^['                # default: Escape
ZSH_OPENCODE_SWITCH_KEY='^I'              # default: Tab
ZSH_OPENCODE_TRACK_SESSIONS=1             # 1 = track session in memory (default);
                                          #     first message in a dir starts a new
                                          #     opencode session, later messages
                                          #     continue it with -s <id>.
                                          # 0 = always pass -c (continue most recent).
ZSH_OPENCODE_BIND_KEYMAPS='main viins vicmd'
                                          # Keymaps to bind the entry chords in.
                                          # main  : emacs mode (and vi insert in vi mode)
                                          # viins : vi insert mode (redundant with main
                                          #         when main is linked to viins, but
                                          #         listed for clarity)
                                          # vicmd : vi command mode — independent of
                                          #         main, so it must be listed for the
                                          #         chord to work after pressing Esc.
                                          # Override to drop vicmd if you use vi mode
                                          # but want the chord to be insert-only.
```

## Session behavior

- One session per directory (`$PWD:A`), shared between plan and build agents.
- First message in a directory starts a new opencode session. The session id
  is discovered by `opencode session list --format json` and matched on the
  current directory.
- Later messages use `opencode run -s <id> --agent <plan|build>`.
- Nothing is written to disk by this plugin; restart zsh to forget sessions.
- Changing directory (`cd`) automatically exits OpenCode mode, so the modal
  keymap and prompt do not bleed across directories.

## Editor mode

- **Emacs mode** (default): the entry chords work out of the box.
- **Vi mode** (`bindkey -v`): the chords are bound in `main` (which aliases
  `viins` in vi mode) and in `vicmd`. Pressing the chord from insert mode or
  command mode both enter OpenCode mode. Exiting restores whatever keymap
  was active on entry.

## Prompt handling

- The plugin saves and restores `PROMPT`, `RPROMPT`, and `RPROMPT2` on
  mode entry and exit. `PROMPT2` is intentionally left untouched so the
  default continuation prompt still works for unclosed quotes, brackets,
  and heredocs inside the modal.

## Buffer handling

- Sending a message clears the buffer (as expected).
- Pressing `Escape` exits the mode but **leaves the typed text on the
  line** in the main keymap, so re-entering the mode brings it back. This
  avoids accidental data loss if Escape is hit by mistake.
