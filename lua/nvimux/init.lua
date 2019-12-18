--[[
Nvimux: Neovim as a terminal multiplexer.

This is the lua reimplementation of VimL.
--]]
-- luacheck: globals unpack

local state = {}
local nvimux = {}
local bindings = require('nvimux.bindings')
local vars = require('nvimux.vars')
local fns = require('nvimux.fns')
local ui = require('nvimux.ui')
nvimux.debug = {}
nvimux.bindings = bindings
nvimux.config = {}
nvimux.term = {}
nvimux.term.prompt = {}

nvimux.commands = {}

-- [ Private variables and tables
local nvim = vim.api -- luacheck: ignore
local nvim_proxy = {
  __index = function(_, key)
    local key_ = 'nvimux_' .. key
    local val = nil
    if fns.exists(key_) then
      val = nvim.nvim_get_var(key_)
    end
    return val
  end
}

-- [[ Table of default bindings
bindings.mappings = {
  ['<C-r>']  = { nvi  = {':so $MYVIMRC'}},
  ['!']      = { nvit = {':wincmd T'}},
  ['%']      = { nvit = {function() return vars.vertical_split end}},
  ['\"']     = { nvit = {function() return vars.horizontal_split end}},
  ['-']      = { nvit = {':NvimuxPreviousTab'}},
  ['q']      = { nvit = {':NvimuxToggleTerm'}},
  ['w']      = { nvit = {':tabs'}},
  ['o']      = { nvit = {'<C-w>w'}},
  ['n']      = { nvit = {'gt'}},
  ['p']      = { nvit = {'gT'}},
  ['x']      = { nvi  = {':bd %'},
                 t    = {function() return vars.close_term end}},
  ['X']      = { nvi  = {':enew \\| bd #'}},
  ['h']      = { nvit = {'<C-w><C-h>'}},
  ['j']      = { nvit = {'<C-w><C-j>'}},
  ['k']      = { nvit = {'<C-w><C-k>'}},
  ['l']      = { nvit = {'<C-w><C-l>'}},
  [':']      = { t    = {':', suffix = ''}},
  ['[']      = { t    = {''}},
  [']']      = { t    = {':NvimuxTermPaste'}},
  [',']      = { t    = {'', nvimux.term.prompt.rename}},
  ['c']      = { nvit = {':NvimuxNewTab'}},
}

bindings.map_table = {}

local win_cmd = function(create_window)
      local select_buffer
    if type(vars.new_window) == "function" then
      select_buffer = vars.new_window
    else
      select_buffer = function()
        vim.api.nvim_command(vars.new_window)
      end
    end

    ui.on_new(create_window, select_buffer)
end

local tab_cmd = function(create_window)
      local select_buffer
      local selector = vars.new_tab or vars.new_window
    if type(selector) == "function" then
      select_buffer = selector
    else
      select_buffer = function()
        vim.api.nvim_command(selector)
      end
    end

    ui.on_new(create_window, select_buffer)
end

nvimux.commands.horizontal_split = function() return win_cmd[[spl|wincmd j]] end
nvimux.commands.vertical_split = function() return win_cmd[[vspl|wincmd l]] end
nvimux.commands.new_tab = function() return tab_cmd[[tabe]] end


local nvimux_commands = {
  {name = 'NvimuxPreviousTab', cmd = [[lua require('nvimux').go_to_last_tab()]]},
  {name = 'NvimuxSet', cmd = [[lua require('nvimux').config.set_fargs(<f-args>)]], nargs='+'},
}

local autocmds = {
  {event = "TabLeave", target="*", cmd = [[lua require('nvimux').set_last_tab()]]},
}

-- ]]

setmetatable(vars, nvim_proxy)

-- ]

-- [[ Set var
fns.variables = {}
fns.variables.scoped = {
  arg = {
    b = function() return nvim.nvim_get_current_buf() end,
    t = function() return nvim.nvim_get_current_tabpage() end,
    l = function() return nvim.nvim_get_current_win() end,
    g = function() return nil end,
  },
  set = {
    b = function(options) return nvim.nvim_buf_set_var(options.nr, options.name, options.value) end,
    t = function(options) return nvim.nvim_tabpage_set_var(options.nr, options.name, options.value) end,
    l = function(options) return nvim.nvim_win_set_var(options.nr, options.name, options.value) end,
    g = function(options) return nvim.nvim_set_var(options.name, options.value) end,
  },
  get = {
    b = function(options)
      return fns.exists('b:' .. options.name) and nvim.nvim_buf_get_var(options.nr, options.name) or nil
    end,
    t = function(options)
      return fns.exists('t:' .. options.name) and nvim.nvim_tabpage_get_var(options.nr, options.name) or nil
    end,
    l = function(options)
      return fns.exists('l:' .. options.name) and nvim.nvim_win_get_var(options.nr, options.name) or nil
    end,
    g = function(options)
      return fns.exists('g:' .. options.name) and nvim.nvim_get_var(options.name) or nil
    end,
  },
}

fns.variables.set = function(options)
  local mode = options.mode or 'g'
  options.nr = options.nr or fns.variables.scoped.arg[mode]()
  fns.variables.scoped.set[mode](options)
end

fns.variables.get = function(options)
  local mode = options.mode or 'g'
  options.nr = options.nr or fns.variables.scoped.arg[mode]()
  return fns.variables.scoped.get[mode](options)
end

-- ]]
-- ]

nvimux.do_autocmd = function()
  local au = {"augroup nvimux"}
  for _, v in ipairs(autocmds) do
    table.insert(au, "au! " .. v.event .. " " .. v.target .. " " .. v.cmd)
  end
  table.insert(au, "augroup END")
  nvim.nvim_call_function("execute", {au})
end

-- [ Public API
-- [[ Config-handling commands
nvimux.config.set = function(options)
  vars[options.key] = options.value
end

nvimux.config.set_fargs = function(key, value)
  nvimux.config.set{key=key, value=value}
end

nvimux.config.set_all = function(options)
  for key, value in pairs(options) do
    nvimux.config.set{['key'] = key, ['value'] = value}
  end
end
-- ]]

-- [[ Quickterm
nvimux.term.new_toggle = function()
  local split_type = vars:split_type()
  nvim.nvim_command(split_type .. ' | enew | ' .. vars.quickterm_command)
  local buf_nr = nvim.nvim_call_function('bufnr', {'%'})
  nvim.nvim_set_option('wfw', true)
  fns.variables.set{mode='b', nr=buf_nr, name='nvimux_buf_orientation', value=split_type}
  fns.variables.set{mode=vars.quickterm_scope, name='nvimux_last_buffer_id', value=buf_nr}
end

nvimux.term.toggle = function()
  -- TODO Allow external commands
  local buf_nr = fns.variables.get{mode=vars.quickterm_scope, name='nvimux_last_buffer_id'}

  if not buf_nr then
    nvimux.term.new_toggle()
  else
    local id = math.floor(buf_nr)
    local window = nvim.nvim_call_function('bufwinnr', {id})

    if window == -1 then
      if nvim.nvim_call_function('bufname', {id}) == '' then
        nvimux.term.new_toggle()
      else
        local split_type = nvim.nvim_buf_get_var(id, 'nvimux_buf_orientation')
        nvim.nvim_command(split_type .. ' | b' .. id)
      end
    else
      nvim.nvim_command(window .. ' wincmd w | q | stopinsert')
    end
  end
end

nvimux.term.prompt.rename = function()
  nvimux.term_only{
    cmd = fns.prompt('nvimux > New term name: '),
    action = function(k) nvim.nvim_command('file term://' .. k) end
  }
end
-- ]]

-- [[ Bindings
-- ]]

-- [[ Top-level commands
nvimux.debug.vars = function()
  for k, v in pairs(vars) do
    print(k, v)
  end
end

nvimux.debug.bindings = function()
  local has, inspect = pcall(require, "inspect")
  for k, v in pairs(bindings.mappings) do
    if has then
      print(k, inspect(v))
    else
      -- TODO better fallback debug
      print(k, v)
    end
  end
end


nvimux.debug.map_table = function()
  for k, v in pairs(bindings.map_table) do
    print(k, v)
  end
end

nvimux.debug.state = function()
  print(require("inspect")(state))
end

nvimux.term_only = function(options)
  local action = options.action or nvim.nvim_command
  if nvim.nvim_buf_get_option('%', 'buftype') == 'terminal' then
    action(options.cmd)
  else
    print("Not on terminal")
  end
end

nvimux.mapped = function(options)
  local mapping = bindings.map_table[options.key]
  local ret = mapping.arg()
  if ret ~= '' then
    nvim.nvim_command(ret)
  end
end

nvimux.set_last_tab = function(tabn)
  if tabn == nil then
    tabn = nvim.nvim_call_function('tabpagenr', {})
  end

  state.last_tab = tabn
end

nvimux.go_to_last_tab = function()
  nvim.nvim_command((state.last_tab or 1)  .. 'tabn')
end

 -- ]]
-- ]


nvimux.bootstrap = function(force)
  if force or nvimux.loaded == nil then
    for i=1, 9 do
      bindings.mappings[i] = bindings.create_binding({"n", "v", "i", "t"} , i .. 'gt')
    end

    for _, cmd in ipairs(nvimux_commands) do
      fns.build_cmd(cmd)
    end

    for key, cmd in pairs(bindings.mappings) do
      for modes, binds in pairs(cmd) do
        modes = fns.split(modes)
        local arg = table.remove(binds, 1)
        binds.key = key
        binds.modes = modes
        if type(arg) == 'function' then
          bindings.map_table[key] = {['arg'] = arg, ['action'] = nil}
          binds.mapping = ":lua require('nvimux').mapped{key = '" .. key .. "'}"
        else
          binds.mapping = arg
        end
        bindings.bind(binds)
      end
    end
    fns.build_cmd{name = 'NvimuxReload', cmd = 'lua require("nvimux").bootstrap(true)'}
    nvimux.do_autocmd()
    nvimux.loaded = true
  end
end
-- ]


return nvimux
