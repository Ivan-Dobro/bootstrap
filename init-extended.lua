```lua
-----------------------------------------------------------
-- Часть 1. Базовые настройки
-----------------------------------------------------------

-- Системный буфер
vim.opt.clipboard = "unnamedplus"

-- Нумерация строк
vim.opt.number = true
vim.opt.relativenumber = true

-- Автопереключение относительных номеров
vim.api.nvim_create_autocmd(
  {"BufEnter", "FocusGained", "InsertLeave"},
  { command = "set relativenumber" }
)
vim.api.nvim_create_autocmd(
  {"BufLeave", "FocusLost", "InsertEnter"},
  { command = "set norelativenumber" }
)

-- Отступы
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Поиск
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.hlsearch = true
vim.opt.incsearch = true

-- Мышь
vim.opt.mouse = "a"

-- Цвета
vim.opt.termguicolors = true

-- Автоматически менять рабочую директорию на папку файла
vim.cmd("autocmd BufEnter * silent! lcd %:p:h")


-----------------------------------------------------------
-- Часть 2. Менеджер плагинов lazy.nvim
-----------------------------------------------------------

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  print("Устанавливаю lazy.nvim...")
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({

  -- 🔹 Telescope (поиск файлов, текста и т.п.)
  {
    "nvim-telescope/telescope.nvim", tag = "0.1.6",
    dependencies = { "nvim-lua/plenary.nvim" }
  },

  -- 🔹 Подсветка синтаксиса и парсер кода
  { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },

  -- 🔹 Файловый менеджер
  { "nvim-tree/nvim-tree.lua", dependencies = { "nvim-tree/nvim-web-devicons" } },

  -- 🔹 Красивый статус-бар
  { "nvim-lualine/lualine.nvim", dependencies = { "nvim-tree/nvim-web-devicons" } },

  -- 🔹 Темы
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  { "sainnhe/sonokai" },

})


-----------------------------------------------------------
-- Часть 3. Настройки плагинов
-----------------------------------------------------------

-- NvimTree (файловый менеджер)
require("nvim-tree").setup()

-- Lualine (статус-бар)
require("lualine").setup()

-- Sonokai тема
vim.g.sonokai_style = "andromeda"
vim.g.sonokai_enable_italic = 1
vim.g.sonokai_disable_italic_comment = 1
vim.cmd.colorscheme("sonokai")


-----------------------------------------------------------
-- Часть 4. Горячие клавиши
-----------------------------------------------------------

-- Лидер — пробел
vim.g.mapleader = " "
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- 📂 Файловый менеджер
map("n", "<C-n>", ":NvimTreeToggle<CR>", opts)

-- 🔍 Telescope: поиск файлов
map("n", "<C-p>", ":Telescope find_files<CR>", opts)

-- 🔎 Поиск текста в проекте
map("n", "<leader>fg", ":Telescope live_grep<CR>", opts)

-- 📜 Открытые файлы (буферы)
map("n", "<leader>fb", ":Telescope buffers<CR>", opts)

-- 🕑 Недавние файлы
map("n", "<leader>fr", ":Telescope oldfiles<CR>", opts)

-- ❓ Помощь
map("n", "<leader>fh", ":Telescope help_tags<CR>", opts)

-- 💾 Сохранение
map("n", "<C-s>", ":w<CR>", opts)

-- 🚪 Выход
map("n", "<C-q>", ":q<CR>", opts)