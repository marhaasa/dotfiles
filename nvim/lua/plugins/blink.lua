return {
  "saghen/blink.cmp",
  -- optional: provides snippets for the snippet source
  dependencies = "rafamadriz/friendly-snippets",

  -- use a release tag to download pre-built binaries
  version = "*",
  -- AND/OR build from source, requires nightly: https://rust-lang.github.io/rustup/concepts/channels.html#working-with-nightly-rust
  -- build = 'cargo build --release',
  -- If you use nix, you can build from source using latest nightly rust with:
  -- build = 'nix run .#build-plugin',

  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = function(_, opts)
    opts = opts or {}
    
    -- Base configuration
    opts.keymap = { preset = "super-tab" }
    
    opts.appearance = {
      -- Sets the fallback highlight groups to nvim-cmp's highlight groups
      -- Useful for when your theme doesn't support blink.cmp
      -- Will be removed in a future release
      use_nvim_cmp_as_default = true,
      -- Set to 'mono' for 'Nerd Font Mono' or 'normal' for 'Nerd Font'
      -- Adjusts spacing to ensure icons are aligned
      nerd_font_variant = "normal",
    }

    -- Default list of enabled providers defined so that you can extend it
    -- elsewhere in your config, without redefining it, due to `opts_extend`
    opts.sources = {
      default = { "lsp", "path", "snippets", "buffer" },
      providers = {
        markdown = {
          name = "RenderMarkdown",
          module = "render-markdown.integ.blink",
          fallbacks = { "lsp" },
        },
      },
    }

    opts.completion = {
      list = {
        max_items = 50,
      },
      menu = {
        draw = {
          columns = {
            { "kind_icon", "label", gap = 1 },
            { "source_name" },
          },
        },
      },
      ghost_text = {
        enabled = true,
      },
    }

    -- Enhanced keymaps
    opts.keymap = vim.tbl_extend("force", opts.keymap or {}, {
      preset = "super-tab",
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<C-f>"] = { "scroll_documentation_down" },
      ["<C-b>"] = { "scroll_documentation_up" },
    })

    -- Disable completion based on buffer variable
    opts.enabled = function()
      return not vim.b.blink_disable
    end

    -- Keep default global completion settings intact
    -- Markdown-specific config is handled in the autocmd below

    return opts
  end,

  -- Markdown specific autocmds
  init = function()
    -- Markdown-specific less intrusive completion
    vim.api.nvim_create_autocmd("FileType", {
      pattern = { "markdown", "md" },
      callback = function()
        -- Disable blink.cmp for current buffer
        vim.b.blink_disable = true
        
        -- Use native vim completion for markdown
        vim.opt_local.completeopt = "menu,menuone,noinsert,noselect"
        vim.opt_local.complete = ".,w,b,t" -- Current buffer, windows, other buffers, tags
      end,
    })
  end,
  
  opts_extend = { "sources.default" },
}
