# zsh-opencode

A zsh plugin that adds an **OpenCode mode**: press a key combo to get a `plan>` or `build>` prompt, type a message, and have it run as `opencode run` with the matching agent. Tab switches between plan and build while staying in the same session.

## Install

### Oh My Zsh

```bash
git clone https://github.com/YOUR_USER/zsh-opencode.git \
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

Requires `opencode` in your `PATH`.

## Usage

| Key | Action |
|-----|--------|
| `Ctrl+Shift+P` | Enter OpenCode mode as **plan** |
| `Ctrl+Shift+B` | Enter OpenCode mode as **build** |
| `Tab` | Switch plan ↔ build (only in OpenCode mode) |
| `Enter` | Send buffer to `opencode run` |
| `Escape` | Exit OpenCode mode |

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
ZSH_OPENCODE_PLAN_KEY='^[^P'        # default: Ctrl+Shift+P
ZSH_OPENCODE_BUILD_KEY='^[^B'       # default: Ctrl+Shift+B
ZSH_OPENCODE_EXIT_KEY='^['         # default: Escape
ZSH_OPENCODE_SWITCH_KEY='^I'       # default: Tab
ZSH_OPENCODE_TRACK_SESSIONS=1      # 1 = track session in memory (default); 0 = always use -c
```

## Session behavior

- One session per directory (`$PWD:A`), shared between plan and build agents.
- First message in a directory starts a new opencode session.
- Later messages use `opencode run -s <id> --agent <plan|build>`.
- Nothing is written to disk by this plugin; restart zsh to forget sessions.
