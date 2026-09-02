# Neovim Keymap Reference

This file documents all custom keymaps in this Neovim configuration. All keymaps are centralized in `lua/config/keymaps.lua`.

## Leader Key
The leader key is `<Space>` (set by LazyVim default).

## Keymap Organization

**Centralized Location**: Most keymaps are in `lua/config/keymaps.lua`

**Plugin-Specific**: Some keymaps remain in plugin files for lazy-loading:
- Telescope keymaps: `lua/plugins/telescope.lua`
- LazyGit keymaps: `lua/plugins/lazygit.lua` 
- No Neck Pain keymaps: `lua/plugins/no-neckpain.lua`
- Basic SQL keymaps: `lua/plugins/dadbod.lua`
- Claude Code (AI) keymaps: `lua/plugins/claudecode.lua` (LazyVim `ai.claudecode` extra)

## Keymap Categories

### 🔍 **Search & Navigation**
| Key | Mode | Description | Location |
|-----|------|-------------|----------|
| `<leader>ff` | n | Find Files | telescope.lua |
| `<leader>ft` | n | Find text in files | telescope.lua |
| `<leader>fs` | n | Find Symbols | telescope.lua |
| `<C-d>` | n | Scroll down + center cursor | keymaps.lua |
| `<C-u>` | n | Scroll up + center cursor | keymaps.lua |
| `n` | n | Next search + center cursor | keymaps.lua |
| `N` | n | Previous search + center cursor | keymaps.lua |

### 📝 **Text Editing & Formatting**
| Key | Mode | Description | Plugin/Function |
|-----|------|-------------|-----------------|
| `<leader>wsq` | n | Surround word with quotes | Custom function |
| `<leader>rbs` | n | Replace backward slashes | Custom function |
| `<leader>rlt` | n | Convert line to title case | textcase.nvim |
| `<leader>f` | n | Format SQL (SQL files only) | conform.nvim |
| `<leader>fa` | n | Format and align SQL (SQL files only) | conform.nvim |


### 📝 **Note Taking (Zettelkasten)**
| Key | Mode | Description | Plugin/Function |
|-----|------|-------------|-----------------|
| `<leader>zn` | n | Create and open new note | scribe CLI |
| `<leader>zo` | n | Open existing note from link | Custom function |

### 🗃️ **Database Operations**

#### **Query Execution**
| Key | Mode | Description | Location |
|-----|------|-------------|----------|
| `<leader>de` | n | Execute entire SQL file | dadbod.lua |
| `<leader>dv` | v | Execute selected SQL | dadbod.lua |
| `<leader>dl` | n | Execute current SQL line | dadbod.lua |
| `<leader>dae` | n | Execute SQL file on Fabric DW | keymaps.lua |
| `<leader>dal` | n | Execute current line on Fabric DW | keymaps.lua |

#### **Database Introspection**
| Key | Mode | Description | Location |
|-----|------|-------------|----------|
| `<leader>dt` | n | Show all tables (all schemas) | dadbod.lua |
| `<leader>di` | n | Show all tables (all schemas) | dadbod.lua |
| `<leader>dc` | n | Describe table columns (supports schema.table) | dadbod.lua |
| `<leader>dp` | n | Show public schema tables only | dadbod.lua |
| `<leader>ds` | n | Show all schemas | dadbod.lua |
| `<leader>dS` | n | Show tables for specific schema (prompt) | dadbod.lua |

#### **SQL Formatting**
| Key | Mode | Description | Location |
|-----|------|-------------|----------|
| `<leader>fmt` | n | Format SQL (SQL files only) | sql-formatter.lua |
| `<leader>fma` | n | Format and align SQL (SQL files only) | sql-formatter.lua |

### 🛠️ **Development Tools**
| Key | Mode | Description | Location |
|-----|------|-------------|----------|
| `<leader>lg` | n | Open LazyGit | lazygit.lua |
| `<leader>gt` | n | Run Go tests | keymaps.lua |
| `<leader>S` | n | Stop LSP server | keymaps.lua |
| `<leader>nn` | n | Toggle No Neck Pain | no-neckpain.lua |

### 🤖 **AI (Claude Code) - `<leader>a` prefix**

claudecode.nvim connects the `claude` CLI to Neovim over the IDE protocol. Claude is started in
`--permission-mode manual`, so every edit it proposes shows up as a diff you accept or reject.

| Key | Mode | Action |
|-----|------|--------|
| `<leader>ae` | n, v | Headless edit: types `@file#L1-9 <instruction>` into Claude and submits it; the diff appears when ready |
| `<leader>aa` | n | Accept proposed diff (`:w` in the diff also accepts) |
| `<leader>ad` | n | Deny proposed diff |
| `<leader>ac` | n | Toggle the Claude terminal |
| `<leader>af` | n | Focus the Claude terminal |
| `<leader>as` | v | Send selection as context (shows the terminal) |
| `<leader>ab` | n | Add current buffer as context |
| `<leader>ar` | n | Resume last session |
| `<leader>aC` | n | Continue session |
| `<leader>am` | n | Select model |

The statusline (active window only) shows Claude's state while the terminal is hidden: `working m:ss`,
`asks a question`, `proposes a diff`, `needs permission` (non-edit tools), `replied` (cleared when you
open the terminal), `prompt not submitted` (no hook receipt within 4 s), `idle`. Fed by Claude Code hooks
(`scripts/claude-nvim-status`) into `lua/config/claude_status.lua`.

Completion is blink.cmp (`<leader>ce` / `<leader>cd` enable/disable per buffer).

### 🎬 **Content Creation**
| Key | Mode | Description | Plugin/Function |
|-----|------|-------------|-----------------|
| `<leader>hy` | n | Insert Hugo YouTube shortcode | Custom snippet |

## Environment Variables Required

For database operations to work properly, set these environment variables:
- `DB_URL` - Default database connection string
- `DB_POSTGRES_LOCAL` - Local PostgreSQL connection
- `FABRIC_SERVER` - Microsoft Fabric server URL

## Notes

- All SQL-related keymaps are only active in SQL file types
- Claude Code keymaps are available globally under `<leader>a`
- Date insertion uses the `gendate` command (must be in PATH)
- Note-taking functions require `scribe` CLI tool
- Some keymaps may conflict with LazyVim defaults - check `:map` for conflicts