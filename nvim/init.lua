-- Route all yank/delete/paste through the system clipboard, so text
-- copied in nvim is immediately available to paste in tmux (or anywhere
-- else), and vice versa. Uses pbcopy/pbpaste automatically on macOS.
vim.opt.clipboard = "unnamedplus"

-- Match tmux's low escape-time (see ~/.tmux.conf) so leaving insert mode
-- with <Esc> feels instant while running inside tmux.
vim.opt.ttimeoutlen = 10

-- Shared C-h/j/k/l pane/split navigation with tmux (see ~/.tmux.conf).
-- Inside nvim these move nvim splits; outside nvim, tmux catches the
-- same keys and moves panes instead.
vim.keymap.set("n", "<C-h>", "<C-w>h", { silent = true })
vim.keymap.set("n", "<C-j>", "<C-w>j", { silent = true })
vim.keymap.set("n", "<C-k>", "<C-w>k", { silent = true })
vim.keymap.set("n", "<C-l>", "<C-w>l", { silent = true })

-- Pick up external file changes when tmux reports the pane regained focus.
vim.opt.autoread = true
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter" }, {
  command = "checktime",
})

-- Full 24-bit color instead of the reduced 256-color palette, so syntax
-- highlighting (already on by default in nvim) actually looks right.
vim.opt.termguicolors = true

-- Explicitly enable syntax highlighting and pick a real colorscheme.
-- Without a colorscheme set, highlighting can render as nearly flat even
-- though the engine itself is on. "desert" ships built into nvim, no
-- plugin needed.
vim.cmd("syntax enable")
vim.cmd.colorscheme("desert")

-- Use treesitter highlighting for C instead of the older regex-based
-- syntax engine. This build already bundles a compiled C parser and its
-- highlight queries in the runtime, so no plugin is needed -- this just
-- turns it on. Treesitter is what actually distinguishes function calls
-- from plain identifiers, which the regex engine above doesn't do.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "c",
  callback = function()
    pcall(vim.treesitter.start)
  end,
})

-- Absolute number on the current line, relative distance on every other
-- line (the standard "hybrid" line number setup).
vim.opt.number = true
vim.opt.relativenumber = true

-- 4 real space characters per indent level, not a literal tab byte.
-- Nvim's built-in C indent file (active by default via filetype plugin
-- indent) handles brace/switch-case-aware auto-indenting on top of this.
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
