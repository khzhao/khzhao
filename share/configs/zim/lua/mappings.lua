require "nvchad.mappings"

local map = vim.keymap.set

map({ "n", "v" }, "<C-j>", "5j", { desc = "move down 5 lines" })
map({ "n", "v" }, "<C-k>", "5k", { desc = "move up 5 lines" })
map({ "n", "v" }, "<C-h>", "5h", { desc = "move left 5 chars" })
map({ "n", "v" }, "<C-l>", "5l", { desc = "move right 5 chars" })

local tree_movement_group = vim.api.nvim_create_augroup("ZimNvimTreeMovement", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = tree_movement_group,
  pattern = "NvimTree",
  callback = function(args)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(args.buf) then
        map("n", "<C-k>", "5k", { buffer = args.buf, desc = "move up 5 lines" })
      end
    end)
  end,
})

map("i", "FF", "<Esc>", { desc = "escape insert mode" })
map("n", "<C-p>", "<cmd>set paste!<CR>", { desc = "toggle paste mode" })

map("n", "<M-h>", "<C-w>h", { desc = "window move left" })
map("n", "<M-j>", "<C-w>j", { desc = "window move down" })
map("n", "<M-k>", "<C-w>k", { desc = "window move up" })
map("n", "<M-l>", "<C-w>l", { desc = "window move right" })

map("n", "<C-t>", "<cmd>tabnew<CR>", { desc = "tab new" })
map("n", "H", function()
  require("nvchad.tabufline").prev()
end, { desc = "buffer previous" })
map("n", "L", function()
  require("nvchad.tabufline").next()
end, { desc = "buffer next" })
map("n", "<Tab>", "gt", { desc = "tab next" })
map("n", "<S-Tab>", "gT", { desc = "tab previous" })
