local vars = require("nvimux.vars").proto
local ui = {}

ui.new_buf = function()
  return vim.api.nvim_create_buf(false, true)
end

ui.singleton_buf = function()
  if ui._buf == nil or not vim.api.nvim_buf_is_loaded(ui._buf) then
    ui._buf = ui.new_buf()
    vim.api.nvim_buf_set_lines(ui._buf, 0, -1, false, vars.scratch_buf_content())
  end

  return ui._buf
end

ui.global_size = function()
  local width = 0
  local height = 0

  for ui in vim.api.nvim_list_uis() do
    if width < ui.width then
      width = ui.width
    end
    if height < ui.height then
      height = ui.height
    end
  end

  return width, height
end

ui.current_size = function()
  local win = vim.api.nvim_get_current_win()
  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)

  return width, height
end

ui.on_new = function(new_cmd, fn)
  vim.api.nvim_command(new_cmd)
  fn()
end

_G.ui = ui

return ui
