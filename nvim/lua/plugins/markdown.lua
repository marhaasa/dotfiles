return {
  "MeanderingProgrammer/render-markdown.nvim",
  lazy = true, -- Don't load until needed
  ft = { "markdown", "md" }, -- Load when opening markdown files
  dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-mini/mini.nvim" },
  ---@module 'render-markdown'
  ---@type render.md.UserConfig
  opts = {
    heading = {
      enabled = true,
      sign = false,
      position = "inline",
      icons = { "", "", "", "", "", "" },
      width = "block",
      left_pad = 0,
      right_pad = 0,
      min_width = 0,
      border = false,
      backgrounds = {},
      above = "",
      below = "",
      foregrounds = {
        "RenderMarkdownH1",
        "RenderMarkdownH2",
        "RenderMarkdownH3",
        "RenderMarkdownH4",
        "RenderMarkdownH5",
        "RenderMarkdownH6",
      },
    },
    paragraph = {
      enabled = true,
      left_margin = 0,
      min_width = 0,
    },
    code = {
      enabled = true,
      sign = true,
      style = "full",
      position = "left",
      language_pad = 2,
      language_name = true,
      disable_background = { "diff" },
      width = "full",
      left_pad = 1,
      right_pad = 1,
      min_width = 0,
      border = "none",
      above = "",
      below = "",
      highlight = "RenderMarkdownCode",
      highlight_inline = "RenderMarkdownCodeInline",
      highlight_language = "RenderMarkdownCodeLanguage",
    },
    dash = {
      enabled = false,
    },
    bullet = {
      enabled = true,
      icons = { "●", "○", "◆", "◇" },
      left_pad = 0,
      right_pad = 0,
      highlight = "RenderMarkdownBullet",
    },
    checkbox = {
      enabled = true,
      position = "inline",
      unchecked = {
        icon = "󰄱 ",
        highlight = "RenderMarkdownUnchecked",
      },
      checked = {
        icon = "󰱒 ",
        highlight = "RenderMarkdownChecked",
      },
      custom = {
        todo = { raw = "[-]", rendered = "󰥔 ", highlight = "RenderMarkdownTodo" },
      },
    },
    quote = {
      enabled = true,
      icon = "▋",
      repeat_linebreak = false,
      highlight = "RenderMarkdownQuote",
    },
    pipe_table = {
      enabled = true,
      preset = "none",
      style = "full",
      cell = "padded",
      min_width = 0,
      border = {
        "┌",
        "┬",
        "┐",
        "├",
        "┼",
        "┤",
        "└",
        "┴",
        "┘",
        "│",
        "─",
      },
      alignment_indicator = "━",
      head = "RenderMarkdownTableHead",
      row = "RenderMarkdownTableRow",
      filler = "RenderMarkdownTableFill",
    },
    callout = {
      note = { raw = "[!NOTE]", rendered = "󰋽 Note", highlight = "RenderMarkdownInfo" },
      tip = { raw = "[!TIP]", rendered = "󰌶 Tip", highlight = "RenderMarkdownSuccess" },
      important = { raw = "[!IMPORTANT]", rendered = "󰅾 Important", highlight = "RenderMarkdownHint" },
      warning = { raw = "[!WARNING]", rendered = "󰀪 Warning", highlight = "RenderMarkdownWarn" },
      caution = { raw = "[!CAUTION]", rendered = "󰳦 Caution", highlight = "RenderMarkdownError" },
    },
    link = {
      enabled = false,
    },
    sign = {
      enabled = true,
      highlight = "RenderMarkdownSign",
    },
    indent = {
      enabled = false,
      per_level = 0,
      skip_level = 1,
      skip_heading = true,
    },
    win_options = {
      conceallevel = {
        default = vim.api.nvim_get_option_value("conceallevel", {}),
        rendered = 2,
      },
    },
  },
  config = function(_, opts)
    require("render-markdown").setup(opts)

    -- Set custom heading colors with VimEnter to ensure they stick
    local function apply_colors()
      -- Try using @markup.heading instead since that's what treesitter uses
      vim.api.nvim_set_hl(0, "@markup.heading.1.markdown", { fg = "#cc241d", bold = true })
      vim.api.nvim_set_hl(0, "@markup.heading.2.markdown", { fg = "#98971a", bold = true })
      vim.api.nvim_set_hl(0, "@markup.heading.3.markdown", { fg = "#d79921", bold = true })
      vim.api.nvim_set_hl(0, "@markup.heading.4.markdown", { fg = "#458588", bold = false })
      vim.api.nvim_set_hl(0, "@markup.heading.5.markdown", { fg = "#b16286", bold = false })
      vim.api.nvim_set_hl(0, "@markup.heading.6.markdown", { fg = "#689d6a", bold = false })

      -- Also try the render-markdown specific ones
      vim.api.nvim_set_hl(0, "RenderMarkdownH1", { fg = "#cc241d", bold = true })
      vim.api.nvim_set_hl(0, "RenderMarkdownH2", { fg = "#98971a", bold = true })
      vim.api.nvim_set_hl(0, "RenderMarkdownH3", { fg = "#d79921", bold = true })
      vim.api.nvim_set_hl(0, "RenderMarkdownH4", { fg = "#458588", bold = false })
      vim.api.nvim_set_hl(0, "RenderMarkdownH5", { fg = "#b16286", bold = false })
      vim.api.nvim_set_hl(0, "RenderMarkdownH6", { fg = "#689d6a", bold = false })

      -- And try markdown* ones too
      vim.api.nvim_set_hl(0, "markdownH1", { fg = "#cc241d", bold = true })
      vim.api.nvim_set_hl(0, "markdownH2", { fg = "#98971a", bold = true })
      vim.api.nvim_set_hl(0, "markdownH3", { fg = "#d79921", bold = true })
      vim.api.nvim_set_hl(0, "markdownH4", { fg = "#458588", bold = false })
      vim.api.nvim_set_hl(0, "markdownH5", { fg = "#b16286", bold = false })
      vim.api.nvim_set_hl(0, "markdownH6", { fg = "#689d6a", bold = false })

      -- Very subtle backgrounds for code blocks and inline code
      vim.api.nvim_set_hl(0, "RenderMarkdownCode", { bg = "#2a2a2a" })
      vim.api.nvim_set_hl(0, "RenderMarkdownCodeInline", { bg = "#2f2f2f" })
      vim.api.nvim_set_hl(0, "RenderMarkdownCodeLanguage", { bg = "#2a2a2a" })

      -- Disable any line-related highlights
      vim.api.nvim_set_hl(0, "RenderMarkdownDash", { fg = "NONE", bg = "NONE" })
      vim.api.nvim_set_hl(0, "RenderMarkdownRule", { fg = "NONE", bg = "NONE" })
    end

    -- Force colors to apply using multiple strategies
    apply_colors()

    -- Apply on buffer enter for markdown files
    vim.api.nvim_create_autocmd("BufEnter", {
      pattern = "*.md",
      callback = apply_colors,
    })

    -- Apply on filetype detection
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = apply_colors,
    })

    -- Apply on colorscheme change
    vim.api.nvim_create_autocmd("ColorScheme", {
      callback = apply_colors,
    })

    -- Force apply after a delay on VimEnter
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        vim.defer_fn(apply_colors, 500)
      end,
    })
  end,
}
