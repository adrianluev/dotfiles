-- ============================================================================
-- Options
-- ============================================================================

-- Leader must be set BEFORE any <leader> mapping (and before plugins load)
-- since mappings capture the leader's value at definition time.
vim.g.mapleader = " "

-- nvim-tree replaces netrw as the file explorer; netrw must be disabled
-- before nvim-tree loads.
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- Hybrid line numbers: absolute on the cursor line, relative elsewhere.
vim.opt.number = true
vim.opt.relativenumber = true

-- Route yank/delete/paste through the macOS clipboard (pbcopy/pbpaste),
-- so text moves freely between nvim, tmux, and other apps.
vim.opt.clipboard = "unnamedplus"

-- Full 24-bit color (tmux passes it through, see tmux.conf).
vim.opt.termguicolors = true

-- Indentation: 4 spaces, no hard tabs
vim.opt.tabstop = 4          -- how many columns a <Tab> displays as
vim.opt.shiftwidth = 4       -- spaces per indent step (>>, <<, autoindent)
vim.opt.softtabstop = 4      -- spaces inserted when you press <Tab>
vim.opt.expandtab = true     -- insert spaces instead of a real tab character

-- Reload files changed on disk (e.g. by git or an AI agent in another pane)
-- when nvim regains focus. tmux's `focus-events on` delivers FocusGained.
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "checktime",
})

-- ============================================================================
-- Keymaps (plugin-specific ones live with their plugin below)
-- ============================================================================

local map = vim.keymap.set

-- Clear search highlight
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "Clear search highlight" })

-- Show the full diagnostic message under the cursor in a floating window
map("n", "<leader>e", vim.diagnostic.open_float, { desc = "Show diagnostic at cursor" })

-- Seamless split/pane navigation with Ctrl-hjkl (no plugin needed):
--   * a nvim split exists in that direction -> move to it
--   * already at the edge and inside tmux   -> move to the tmux pane instead
-- tmux.conf forwards Ctrl-hjkl to nvim when the pane runs nvim; outside
-- nvim tmux moves panes itself. Together one set of keys works everywhere.
local function navigate(dir, tmux_dir)
  local before = vim.api.nvim_get_current_win()
  vim.cmd.wincmd(dir)
  if vim.api.nvim_get_current_win() == before and vim.env.TMUX then
    vim.fn.system({ "tmux", "select-pane", "-" .. tmux_dir })
  end
end
map("n", "<C-h>", function() navigate("h", "L") end, { desc = "Go to split/pane left" })
map("n", "<C-j>", function() navigate("j", "D") end, { desc = "Go to split/pane below" })
map("n", "<C-k>", function() navigate("k", "U") end, { desc = "Go to split/pane above" })
map("n", "<C-l>", function() navigate("l", "R") end, { desc = "Go to split/pane right" })

-- Copy "file:line" to clipboard — handy for pointing an AI/coworker at a spot.
-- Keep <leader>c free of longer <leader>c... maps, or it waits timeoutlen.
map("n", "<leader>c", function()
  local loc = vim.fn.expand("%:p") .. ":" .. vim.fn.line(".")
  vim.fn.setreg("+", loc)
  vim.notify("Copied: " .. loc)
end, { desc = "Copy file:line to clipboard" })

-- Visual mode: copy "file:startline-endline" for a selected range
map("x", "<leader>c", function()  -- "x" = visual only; "v" would also hit select mode (snippets)
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  if a > b then a, b = b, a end -- selection made upwards
  local loc = vim.fn.expand("%:p") .. ":" .. a .. "-" .. b
  vim.fn.setreg("+", loc)
  vim.notify("Copied: " .. loc)
end, { desc = "Copy file:start-end lines to clipboard" })

-- JSON: format with jq via gq or <leader>f
vim.api.nvim_create_autocmd("FileType", {
  pattern = "json",
  callback = function()
    vim.bo.formatprg = "jq ."
    map("n", "<leader>f", ":%!jq .<CR>", { buffer = true, desc = "Format JSON with jq" })
  end,
})

-- ---------------------------------------------------------------------------
-- Git (vim-fugitive + fzf-lua pickers)
-- ---------------------------------------------------------------------------

-- Run git from the current file's directory, so these work even when nvim's
-- cwd is outside the file's repo.
local function git_in_file_dir(args)
  return vim.fn.system(vim.list_extend({ "git", "-C", vim.fn.expand("%:p:h") }, args))
end

map("n", "<leader>gs", "<cmd>Git<CR>", { desc = "Fugitive status" })
map("n", "<leader>gb", "<cmd>Git blame<CR>", { desc = "Fugitive blame" })

-- Side-by-side diff of the current file. Blank = vs index (working tree
-- changes); type a branch/commit to diff this file against that ref.
map("n", "<leader>gd", function()
  vim.ui.input({ prompt = "Diff current file against (blank = index): " }, function(ref)
    if ref == nil then return end
    vim.cmd("Gvdiffsplit " .. ref)
  end)
end, { desc = "Fugitive diff split" })

-- Toggle stage/unstage for the current file: if it has no staged changes
-- (`git diff --cached --quiet` exits 0) stage it, otherwise unstage it.
map("n", "<leader>gt", function()
  local file = vim.fn.expand("%:p")
  git_in_file_dir({ "diff", "--cached", "--quiet", "--", file })
  local staging = vim.v.shell_error == 0
  git_in_file_dir(staging and { "add", "--", file } or { "reset", "-q", "--", file })
  if vim.v.shell_error ~= 0 then
    vim.notify("git stage toggle failed for " .. file, vim.log.levels.ERROR)
    return
  end
  vim.notify((staging and "Staged: " or "Unstaged: ") .. vim.fn.expand("%:t"))
  pcall(function() require("gitsigns").refresh() end)
end, { desc = "Toggle stage/unstage current file" })

-- Review workflow (fzf-lua git pickers): file list on the left, diff
-- preview on the right. <Enter> opens the file; <C-v>/<C-s> open a split.
--   gu : uncommitted changes (working tree + staged)  -- "did my/agent's edits look right"
--   gl : pick a commit, see its diff                  -- point-in-time review
--   gc : everything this branch added since it diverged -- whole-branch/PR review
map("n", "<leader>gu", "<cmd>FzfLua git_status<CR>", { desc = "Review: uncommitted changes" })
map("n", "<leader>gl", "<cmd>FzfLua git_commits<CR>", { desc = "Review: pick a commit to view its diff" })
map("n", "<leader>gc", function()
  -- "..." (triple-dot) diffs against the merge-base, so it only shows what
  -- *this* branch changed, not commits landed on main after you branched.
  vim.ui.input({ prompt = "Diff branch against (merge-base with): ", default = "main" }, function(ref)
    if ref and ref ~= "" then
      vim.cmd("FzfLua git_diff ref=" .. ref .. "...HEAD")
    end
  end)
end, { desc = "Review: diff whole branch/PR against a ref" })

-- ============================================================================
-- Plugins (lazy.nvim)
--
-- Plugin set is deliberately small. Versions are pinned in lazy-lock.json,
-- which lives next to this file in the dotfiles repo; copy both to another
-- machine and run :Lazy restore to get the exact same commits.
-- ============================================================================

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Keep the lockfile beside the real init.lua (resolving the symlink into
-- the dotfiles repo) so it gets committed with the config.
local config_dir = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.stdpath("config") .. "/init.lua"), ":h")

require("lazy").setup({
  -- Tokyonight: colorscheme with rich treesitter highlighting
  {
    "folke/tokyonight.nvim",
    lazy = false,    -- load during startup
    priority = 1000, -- load before other plugins so highlights apply
    config = function()
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- Vim Fugitive: :Git, blame, diff splits
  { "tpope/vim-fugitive" },

  -- Paginate: review an agent's changes as a book (local plugin).
  --   Skipped on machines without the checkout, so the config still loads there.
  {
    dir = "~/Desktop/personal_projects/paginate",
    cond = (vim.uv or vim.loop).fs_stat(vim.fn.expand("~/Desktop/personal_projects/paginate")) ~= nil,
    cmd = "Paginate",
    keys = {
      { "<leader>pr", "<cmd>Paginate<CR>", desc = "Paginate: review changes" },
    },
    opts = {},
  },

  -- Treesitter: accurate syntax highlighting.
  --   Neovim 0.12+ needs the `main` branch. Installing parsers requires the
  --   `tree-sitter` CLI (brew: tree-sitter-cli) and a C compiler.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").install({
        "lua", "vim", "vimdoc", "bash", "python", "javascript", "json",
      })

      -- Start treesitter highlighting per buffer. pcall so filetypes
      -- without an installed parser silently keep regex highlighting.
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(args)
          pcall(vim.treesitter.start, args.buf)
        end,
      })
    end,
  },

  -- Fzf-lua: fuzzy finder (needs fzf, fd, ripgrep on PATH)
  {
    "ibhagwan/fzf-lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local fzf = require("fzf-lua")
      local actions = require("fzf-lua.actions")

      -- Paths excluded from all searches (Node + Python build/cache/venv junk)
      local excludes = {
        ".git", "node_modules", "dist", "build",             -- Node / general
        ".venv", "venv", "__pycache__", "site-packages",     -- Python
        ".mypy_cache", ".pytest_cache", ".ruff_cache",       -- Python caches
        ".tox", ".eggs",
      }

      -- Build fd flags (file search) and rg glob flags (text search)
      local fd_exclude, rg_exclude = "", ""
      for _, path in ipairs(excludes) do
        fd_exclude = fd_exclude .. " --exclude " .. path
        rg_exclude = rg_exclude .. " -g '!" .. path .. "'"
      end

      fzf.setup({
        files = {
          fd_opts = "--color=never --type f --hidden --follow" .. fd_exclude,
        },
        grep = {
          rg_opts = "--column --line-number --no-heading --color=always "
            .. "--smart-case --max-columns=4096" .. rg_exclude,
        },
        -- git_status (<leader>gu): stage/unstage with ctrl-h/ctrl-l instead
        -- of the default left/right arrows.
        git = {
          status = {
            actions = {
              ["ctrl-h"] = { fn = actions.git_stage, reload = true },
              ["ctrl-l"] = { fn = actions.git_unstage, reload = true },
            },
          },
        },
      })

      map("n", "<leader>pf", fzf.files, { desc = "Find files" })
      map("n", "<leader>pb", fzf.buffers, { desc = "Find open buffers" })
      map("n", "<leader>ps", fzf.live_grep, { desc = "Search text across project" })
    end,
  },

  -- Gitsigns: git change markers in the gutter, hunk navigation
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        on_attach = function(bufnr)
          local gs = require("gitsigns")
          local function bmap(lhs, rhs, desc)
            map("n", lhs, rhs, { buffer = bufnr, desc = "Gitsigns: " .. desc })
          end
          -- In diff mode (e.g. <leader>gd) keep Vim's native ]c/[c, which
          -- jump between diff blocks; elsewhere jump between git hunks.
          local function hunk(native, dir)
            return function()
              if vim.wo.diff then
                vim.cmd.normal({ native, bang = true })
              else
                gs.nav_hunk(dir)
              end
            end
          end
          bmap("]c", hunk("]c", "next"), "Next hunk")
          bmap("[c", hunk("[c", "prev"), "Previous hunk")
          bmap("<leader>gp", gs.preview_hunk, "Preview hunk")
        end,
      })
    end,
  },

  -- Lualine: statusline with branch, diff, diagnostics, LSP name, and a
  -- staged/unstaged indicator for the current file.
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      -- The statusline redraws constantly, so the indicator is cached per
      -- buffer and only recomputed on events that can change it (including
      -- gitsigns updates, which fire after staging from anywhere).
      local function compute_stage_status(buf)
        local file = vim.api.nvim_buf_get_name(buf)
        if file == "" or vim.bo[buf].buftype ~= "" then return "" end
        local out = vim.fn.systemlist({
          "git", "-C", vim.fn.fnamemodify(file, ":h"), "status", "--porcelain=v1", "--", file,
        })
        if vim.v.shell_error ~= 0 or #out == 0 then return "" end
        -- Two-char porcelain code: index (staged), then working tree.
        local code = out[1]:sub(1, 2)
        if code == "??" then return "[untracked]" end
        local staged, unstaged = code:sub(1, 1) ~= " ", code:sub(2, 2) ~= " "
        if staged and unstaged then return "[staged+unstaged]" end
        if staged then return "[staged]" end
        if unstaged then return "[unstaged]" end
        return ""
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "FocusGained" }, {
        callback = function(args)
          vim.b[args.buf].stage_status = compute_stage_status(args.buf)
        end,
      })
      vim.api.nvim_create_autocmd("User", {
        pattern = "GitSignsUpdate",
        callback = function(args)
          local buf = (args.data and args.data.buffer) or vim.api.nvim_get_current_buf()
          if vim.api.nvim_buf_is_valid(buf) then
            vim.b[buf].stage_status = compute_stage_status(buf)
          end
        end,
      })

      require("lualine").setup({
        options = { theme = "tokyonight" },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff" },
          lualine_c = { "filename", function() return vim.b.stage_status or "" end },
          lualine_x = { "diagnostics", "lsp_status", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      })
    end,
  },

  -- LSP: Mason installs language servers; nvim-lspconfig ships their configs.
  --   pyright (Python) gives `gd`/`K` into imported modules. pyright is
  --   Node-based, so Node.js must be on PATH. `:Mason` shows install status,
  --   `:checkhealth vim.lsp` shows what's attached.
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      { "mason-org/mason.nvim", opts = {} },
      -- mason-lspconfig also auto-enables every installed server.
      { "mason-org/mason-lspconfig.nvim", opts = { ensure_installed = { "pyright" } } },
    },
    config = function()
      -- Explicit too, so a pyright installed outside Mason still starts.
      vim.lsp.enable("pyright")

      -- Buffer-local LSP keymaps, set only once a server attaches.
      -- Neovim 0.11+ already provides these by default, so they are NOT
      -- remapped here (custom gr/gi would shadow them and add a delay):
      --   grr references   gri implementation   grn rename
      --   gra code action  grt type definition  K   hover
      --   gO  document symbols   <C-s> (insert) signature help
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local function bmap(lhs, rhs, desc)
            map("n", lhs, rhs, { buffer = args.buf, desc = "LSP: " .. desc })
          end
          bmap("gd", vim.lsp.buf.definition, "Go to definition")
          bmap("gD", vim.lsp.buf.declaration, "Go to declaration")
        end,
      })
    end,
  },

  -- Nvim-tree: file explorer with git status markers
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("nvim-tree").setup({
        on_attach = function(bufnr)
          require("nvim-tree.api").config.mappings.default_on_attach(bufnr)
          -- nvim-tree binds <C-k> to "Info"; drop it so Ctrl-k moves to the
          -- split/pane above like everywhere else.
          vim.keymap.del("n", "<C-k>", { buffer = bufnr })
        end,
      })
      map("n", "<leader>pv", "<cmd>NvimTreeToggle<CR>", { desc = "Toggle file explorer" })
    end,
  },
}, {
  lockfile = config_dir .. "/lazy-lock.json",
})
