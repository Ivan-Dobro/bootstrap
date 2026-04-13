-- Clipboard: allow copying over SSH in terminals that support OSC52.
vim.g.clipboard = "osc52"

-- Clipboard: use the system clipboard by default for yank/delete/paste.
vim.opt.clipboard = "unnamedplus"

-- Line numbers: show the current absolute line number.
vim.opt.number = true

-- Line numbers: show relative numbers to make motions with counts easier.
vim.opt.relativenumber = true

-- Insert mode: hide relative numbers while typing so the screen is calmer.
vim.api.nvim_create_autocmd("InsertEnter", {
  callback = function()
    vim.opt.relativenumber = false
  end,
})

-- Normal mode: restore relative numbers after leaving insert mode.
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.opt.relativenumber = true
  end,
})

-- UI: highlight the current line.
vim.opt.cursorline = true

-- UI: show invisible characters like tabs, trailing spaces and non-breaking spaces.
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- UI: keep long lines on one row without wrapping.
vim.opt.wrap = false

-- Navigation: keep a few lines visible above and below the cursor while scrolling.
vim.opt.scrolloff = 5

-- Search: ignore case by default, but become case-sensitive when uppercase is used.
vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Search: highlight matches and update results while typing.
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Syntax: enable syntax highlighting.
vim.cmd("syntax on")

-- Files: automatically reload a file if it was changed outside Neovim.
vim.opt.autoread = true

-- Indentation: shift selected lines right or left and keep the selection active.
vim.keymap.set("v", "<Tab>", ">gv")
vim.keymap.set("v", "<S-Tab>", "<gv")

-- Windows: move between splits with Ctrl+h/j/k/l.
vim.keymap.set("n", "<C-h>", "<C-w>h")
vim.keymap.set("n", "<C-l>", "<C-w>l")
vim.keymap.set("n", "<C-j>", "<C-w>j")
vim.keymap.set("n", "<C-k>", "<C-w>k")
