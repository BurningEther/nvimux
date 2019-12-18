local vars = {
  prefix = '<C-b>',
  vertical_split = ':NvimuxVerticalSplit',
  horizontal_split = ':NvimuxHorizontalSplit',
  quickterm_scope = 'g',
  quickterm_direction = 'botright',
  quickterm_orientation = 'vertical',
  quickterm_size = '',
  quickterm_command = 'term',
  close_term = ':x',
}

vars.scratch_buf_content = {
  ""
}

vars.new_window = function()
    vim.api.nvim_set_current_buf(require("nvimux.ui").singleton_buf())
end

vars.new_tab = function()
    vim.api.nvim_set_current_buf(require("nvimux.ui").singleton_buf())
end

vars.split_type = function(t)
  return t.quickterm_direction .. ' ' .. t.quickterm_orientation .. ' ' .. t.quickterm_size .. 'split'
end

local proto_vars = {}
setmetatable(proto_vars, {
    __index = function(_, k)
      local v = rawget(vars, k)
      if type(v) == "function" then
        return v
      else
        return function()
          return v
        end
      end
    end,
    __newindex = function(_, k, v)
      rawset(vars, k ,v)
    end
  })

vars.proto = proto_vars

return vars
