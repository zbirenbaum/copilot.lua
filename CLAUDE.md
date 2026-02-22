# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

copilot.lua is a pure Lua Neovim plugin for GitHub Copilot integration, replacing github/copilot.vim. It communicates with the Copilot Language Server via Neovim's built-in LSP client to provide inline suggestions, a completion panel, and next-edit suggestions (NES).

**Requirements**: Neovim 0.11+, Node.js 22+ (for the default nodejs server mode).

## Development Commands

```bash
make deps                          # Clone mini.nvim and osv into deps/
make test                          # Run all tests (auto-fetches deps)
make test_file FILE=tests/test_client.lua  # Run a single test file
```

**Code quality** (checked in CI):
- **Format**: Stylua (config in `.stylua.toml`)
- **Lint**: Luacheck (config in `.luacheckrc`, vim globals allowed)
- **Typecheck**: Lua type annotations

## Architecture

### Initialization Flow

`plugin/copilot.lua` registers the `:Copilot` user command. When `require("copilot").setup(opts)` is called:

1. Validates Neovim version, sets up highlights, merges config
2. On `:Copilot` or lazy trigger → `client.setup()` starts the LSP server
3. `BufEnter` autocmd attaches buffers based on filetype rules and `should_attach`
4. `suggestion.setup()` and `panel.setup()` wire up their keymaps and handlers

The LSP client is lazily initialized — it starts on first buffer attach or explicit command.

### Key Modules (`lua/copilot/`)

| Module | Role |
|--------|------|
| `client/` | LSP client lifecycle, buffer attach/detach, state tracking |
| `api/` | Wraps all LSP requests/notifications (coroutine-based async) |
| `lsp/` | Server startup — `nodejs.lua` (default) or `binary.lua` (experimental) |
| `config/` | Modular config with per-feature defaults, deep merge, validation |
| `auth/` | Device code sign-in flow, token caching from `~/.config/github-copilot/` |
| `suggestion/` | Inline virtual text completions with accept/dismiss/cycle |
| `panel/` | Split window showing multiple completions with navigation |
| `nes/` | Next Edit Suggestion (experimental, requires copilot-lsp plugin) |
| `keymaps/` | Buffer-local keymap registration with passthrough support |
| `model.lua` | Model listing, selection, get/set |
| `logger/` | Dual file + console logging with configurable levels |
| `status/` | LSP status notifications and callback system |

### Design Patterns

- **Coroutine-based async**: LSP requests are wrapped in coroutines via `api/init.lua`
- **Passthrough keymaps**: Keymaps fall through to original bindings if the action returns `false`
- **Buffer-local state**: Suggestion context and keymaps are per-buffer
- **Config cascading**: User opts deep-merged over module defaults with type validation

## Testing

Tests use **mini.test** (from mini.nvim). Test stubs in `tests/stubs/` mock the LSP server and Node.js to enable testing without a real Copilot server.

- `tests/child_helper.lua` manages child Neovim processes for integration tests
- `tests/scripts/minimal_init.lua` is the minimal Neovim config used by the test harness
- CI runs tests on Ubuntu (ARM), macOS, and Windows against both stable and nightly Neovim
