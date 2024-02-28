local api = require("copilot.api")
local c = require("copilot.client")
local config = require("copilot.config")
local hl_group = require("copilot.highlight").group
local util = require("copilot.util")

local mod = {}

local marker_prefix = "[copilot] "

local panel_uri_prefix = "copilot://"

local panel = {
  client = nil,
  setup_done = false,

  augroup = "copilot.panel",
  ns_id = vim.api.nvim_create_namespace("copilot.panel"),

  req_number = 0,
  panel_uri = nil,
  -- `req_number:panel_uri`
  panelId = nil,
  bufnr = nil,
  winid = nil,
  filetype = nil,

  state = {
    req_id = nil,
    line = nil,
    status = nil,
    error = nil,
    expected_count = nil,
    received_count = nil,
    entries = {},
    was_insert = nil,
    auto_refreshing = nil,
  },
  layout = {
    position = "bottom",
    ratio = 0.4,
  },

  auto_refresh = false,
  keymap = {},
}

---@param text string
---@return string[]
local function get_display_lines(text)
  local lines = vim.split(text, "\n", { plain = true, trimempty = true })

  local extra_indent = math.min(unpack(vim.tbl_map(function(line)
    return #(string.match(line, "^%s*") or "")
  end, lines)))

  if extra_indent > 0 then
    for i, line in ipairs(lines) do
      lines[i] = line:sub(extra_indent + 1)
    end
  end

  return lines
end

---@return string panelUri
local function panel_uri_from_doc_uri(doc_uri)
  return doc_uri:gsub("^file://", panel_uri_prefix)
end

---@return string doc_uri
local function panel_uri_to_doc_uri(panel_uri)
  return panel_uri:gsub("^" .. panel_uri_prefix, "file://")
end

---@param bufname string
local function is_panel_uri(bufname)
  return bufname:sub(1, #panel_uri_prefix) == panel_uri_prefix
end

function panel:lock()
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", false)
  vim.api.nvim_buf_set_option(self.bufnr, "readonly", true)
  return self
end

function panel:unlock()
  vim.api.nvim_buf_set_option(self.bufnr, "modifiable", true)
  vim.api.nvim_buf_set_option(self.bufnr, "readonly", false)
  return self
end

function panel:clear()
  self.state = { entries = {} }

  if self.bufnr and vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_clear_namespace(self.bufnr, self.ns_id, 0, -1)
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, { "", "" })
  end

  return self
end

function panel:refresh_header()
  local state = self.state

  vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, 0, 0, {
    id = 1,
    virt_text = {
      {
        string.format(
          " %s %s/%s solutions (Duplicates hidden) [%s]",
          state.status == "done" and "Synthesized" or "Synthesizing",
          state.received_count or "?",
          state.expected_count or "?",
          state.status or "..."
        ),
        hl_group.CopilotAnnotation,
      },
    },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })

  return self
end

---@param item copilot_panel_solution_data
function panel:add_entry(item)
  if panel.state.entries[item.solutionId] then
    return self
  end

  panel.state.entries[item.solutionId] = item

  -- 0-indexed
  local marker_linenr = vim.api.nvim_buf_line_count(self.bufnr)

  local lines = {
    "", -- marker line
  }

  lines[#lines + 1] = ""
  for _, line in ipairs(get_display_lines(item.displayText)) do
    lines[#lines + 1] = line
  end
  lines[#lines + 1] = ""

  vim.api.nvim_buf_set_lines(self.bufnr, -1, -1, false, lines)

  vim.api.nvim_buf_set_extmark(self.bufnr, self.ns_id, marker_linenr, 0, {
    id = marker_linenr + 1,
    virt_text = {
      {
        string.format("%s:id:%s: :score:%s:", marker_prefix, item.solutionId, item.score),
        hl_group.CopilotAnnotation,
      },
    },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })

  return self
end

---@param dir string|-1|0|1
---@return copilot_panel_solution_data|nil entry
---@return integer|nil linenr
function panel:get_entry(dir)
  local linenr = vim.api.nvim_win_get_cursor(self.winid)[1]

  if type(dir) == "string" then
    return self.state.entries[dir]
  end

  if type(dir) ~= "number" then
    return nil
  end

  local extmarks = vim.api.nvim_buf_get_extmarks(
    self.bufnr,
    self.ns_id,
    { math.max(0, linenr - 1 + dir), 0 },
    dir > 0 and -1 or 0,
    { details = true, limit = 1 }
  )

  if not extmarks[1] then
    return nil
  end

  local id = string.match(extmarks[1][4].virt_text[1][1], ":id:(.-):")

  if not id then
    return nil
  end

  return self:get_entry(id), extmarks[1][2] + 1
end

---@param dir -1|0|1
function panel:jump(dir)
  local _, linenr = self:get_entry(dir)
  if linenr then
    vim.api.nvim_win_set_cursor(self.winid, { linenr, 0 })
  end
end

function panel:accept()
  local entry = self:get_entry(0)
  if not entry then
    return
  end

  local bufnr = vim.uri_to_bufnr(panel_uri_to_doc_uri(self.panel_uri))
  local winid = vim.fn.bufwinid(bufnr)

  if not vim.api.nvim_buf_is_loaded(bufnr) or winid == -1 then
    vim.cmd("echoerr 'Buffer was closed'")
    return
  end

  if vim.fn.getbufline(bufnr, entry.range.start.line + 1)[1] ~= self.state.line then
    vim.cmd('echoerr "Buffer has changed since synthesizing solution"')
    return
  end

  vim.api.nvim_set_current_win(winid)

  if self.state.was_insert then
    vim.cmd("startinsert!")
  else
    vim.cmd("normal! $")
  end

  api.notify_accepted(self.client, { uuid = entry.solutionId }, function() end)

  vim.lsp.util.apply_text_edits({
    { range = entry.range, newText = entry.completionText },
  }, vim.api.nvim_get_current_buf(), "utf-16")
  -- Put cursor at the end of current line.
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<End>", true, false, true), "n", false)

  self:close()
end

function panel:close()
  if self.bufnr and vim.api.nvim_win_is_valid(self.bufnr) then
    self:unlock():clear():lock()
  end

  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    vim.api.nvim_win_close(self.winid, true)
  end
end

local function set_keymap(bufnr)
  if panel.keymap.accept then
    vim.keymap.set("n", panel.keymap.accept, mod.accept, {
      buffer = bufnr,
      desc = "[copilot] (panel) accept",
      silent = true,
    })
  end

  if panel.keymap.jump_prev then
    vim.keymap.set("n", panel.keymap.jump_prev, mod.jump_prev, {
      buffer = bufnr,
      desc = "[copilot] (panel) jump prev",
      silent = true,
    })
  end

  if panel.keymap.jump_next then
    vim.keymap.set("n", panel.keymap.jump_next, mod.jump_next, {
      buffer = bufnr,
      desc = "[copilot] (panel) jump next",
      silent = true,
    })
  end

  if panel.keymap.refresh then
    vim.keymap.set("n", panel.keymap.refresh, mod.refresh, {
      buffer = bufnr,
      desc = "[copilot] (panel) refresh",
      silent = true,
    })
  end
end

function panel:ensure_bufnr()
  if not self.bufnr or not vim.api.nvim_buf_is_valid(self.bufnr) then
    self.bufnr = vim.api.nvim_create_buf(false, true)

    for name, value in pairs({
      bufhidden = "hide",
      buflisted = false,
      buftype = "nofile",
      modifiable = false,
      readonly = true,
      swapfile = false,
      undolevels = 0,
    }) do
      vim.api.nvim_buf_set_option(self.bufnr, name, value)
    end

    set_keymap(self.bufnr)
  end

  vim.api.nvim_buf_set_name(self.bufnr, self.panel_uri)
  vim.api.nvim_buf_set_option(self.bufnr, "filetype", self.filetype)
end

function panel:ensure_winid()
  if self.winid and vim.api.nvim_win_is_valid(self.winid) then
    return
  end

  if not self.bufnr then
    return
  end

  local position = self.layout.position
  local ratio = self.layout.ratio

  local get_width = vim.api.nvim_win_get_width
  local get_height = vim.api.nvim_win_get_height

  local split_map = {
    top = { cmd_prefix = "topleft ", winsize_fn = get_height },
    right = { cmd_prefix = "vertical botright ", winsize_fn = get_width },
    bottom = { cmd_prefix = "botright ", winsize_fn = get_height },
    left = { cmd_prefix = "vertical topleft ", winsize_fn = get_width },
  }

  local split_info = split_map[position]
  if not split_info then
    print("Error: " .. position .. " is not a valid position")
    return
  end

  local function resolve_splitcmd()
    local size = math.floor(split_info.winsize_fn(0) * ratio)
    local cmd_prefix = split_info.cmd_prefix
    return "silent noswapfile " .. cmd_prefix .. tostring(size) .. " split"
  end

  self.winid = vim.api.nvim_win_call(0, function()
    vim.cmd(resolve_splitcmd())
    return vim.api.nvim_get_current_win()
  end)

  vim.api.nvim_win_set_buf(self.winid, self.bufnr)

  for name, value in pairs({
    fcs = "eob: ",
    list = false,
    number = false,
    numberwidth = 1,
    relativenumber = false,
    signcolumn = "no",
  }) do
    vim.api.nvim_win_set_option(self.winid, name, value)
  end

  vim.api.nvim_create_augroup(self.augroup, { clear = true })

  if self.auto_refresh then
    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP" }, {
      group = self.augroup,
      buffer = vim.uri_to_bufnr(panel_uri_to_doc_uri(self.panel_uri)),
      callback = function()
        self.state.auto_refreshing = true
        self:refresh()
      end,
      desc = "[copilot] (panel) auto refresh",
    })
  end

  vim.api.nvim_create_autocmd("WinClosed", {
    group = self.augroup,
    pattern = tostring(self.winid),
    callback = function()
      local should_jump_to_prev_win = self.winid == vim.api.nvim_get_current_win()

      self.panelId = nil
      self.state = { entries = {} }
      vim.api.nvim_clear_autocmds({ group = self.augroup })
      self.winid = nil

      if should_jump_to_prev_win then
        vim.cmd("wincmd p")
      end
    end,
    desc = "[copilot] (panel) win closed cleanup",
    once = true,
  })
end

function panel:refresh()
  if not self.winid or not vim.api.nvim_win_is_valid(self.winid) then
    return
  end

  if not c.buf_is_attached(0) then
    return
  end

  if self.panelId then
    api.unregister_panel_handlers(self.panelId)
  end

  if self.state.req_id then
    self.client.cancel_request(self.state.req_id)
    self.state.req_id = nil
  end

  self.req_number = self.req_number + 1
  self.panelId = self.req_number .. ":" .. self.panel_uri

  api.register_panel_handlers(self.panelId, {
    ---@param result copilot_panel_solution_data
    on_solution = function(result)
      if result.panelId ~= self.panelId then
        api.unregister_panel_handlers(result.panelId)
        return
      end

      self.state.received_count = type(self.state.received_count) == "number" and self.state.received_count + 1 or 1

      self:unlock():refresh_header():add_entry(result):lock()
    end,
    ---@param result copilot_panel_solutions_done_data
    on_solutions_done = function(result)
      self.state.req_id = nil

      if result.panelId ~= self.panelId then
        api.unregister_panel_handlers(result.panelId)
        return
      end

      if result.status == "OK" then
        self.state.status = "done"
      elseif result.status == "Error" then
        self.state.status = "error"
        self.state.error = result.message
        print(self.state.error)
      end

      self:unlock():refresh_header():lock()
    end,
  })

  local auto_refreshing = self.state.auto_refreshing

  self:unlock():clear():lock()

  local params = util.get_doc_params({ panelId = self.panelId })

  self.state.line = vim.fn.getline(".")
  self.state.was_insert = vim.fn.mode():match("^[iR]")

  if not auto_refreshing and self.state.was_insert then
    vim.cmd("stopinsert")
  else
    -- assume cursor at end of line
    local _, utf16_index = vim.str_utfindex(self.state.line)
    params.doc.position.character = utf16_index
    params.position.character = params.doc.position.character
  end

  local _, id = api.get_panel_completions(
    self.client,
    params,
    ---@param result copilot_get_panel_completions_data
    function(err, result)
      if err then
        self.state.status = "error"
        self.state.error = err
        print(self.state.error)
        return
      end

      self.state.status = "loading"
      self.state.expected_count = result.solutionCountTarget
      panel:unlock():refresh_header():lock()
    end
  )

  self.state.req_id = id
end

function panel:init()
  local doc = util.get_doc()

  if is_panel_uri(doc.uri) then
    -- currently inside the panel itself
    mod.refresh()
    return
  end

  if not c.buf_is_attached(0) then
    local should_attach, no_attach_reason = util.should_attach()
    vim.notify(
      string.format("[Copilot] %s", should_attach and ("Disabled manually for " .. vim.bo.filetype) or no_attach_reason),
      vim.log.levels.ERROR
    )
    return
  end

  self.panel_uri = panel_uri_from_doc_uri(doc.uri)
  self.filetype = vim.bo.filetype

  self:ensure_bufnr()

  self:ensure_winid()

  self:refresh()

  vim.api.nvim_set_current_win(self.winid)
end

function mod.accept()
  panel:accept()
end

function mod.jump_prev()
  panel:jump(-1)
end

function mod.jump_next()
  panel:jump(1)
end

function mod.refresh()
  vim.api.nvim_buf_call(vim.uri_to_bufnr(panel_uri_to_doc_uri(panel.panel_uri)), function()
    panel:refresh()
  end)
end

---@param layout {position: string, ratio: number}
---position: (optional) 'bottom' | 'top' | 'left' | 'right'
---ratio: (optional) between 0 and 1
function mod.open(layout)
  local client = c.get()
  if not client then
    print("Error, copilot not running")
    return
  end

  panel.client = client
  panel.layout = vim.tbl_deep_extend("force", panel.layout, layout or {})

  panel:init()
end

function mod.setup()
  local opts = config.get("panel") --[[@as copilot_config_panel]]
  if not opts.enabled then
    return
  end

  if panel.setup_done then
    return
  end

  panel.auto_refresh = opts.auto_refresh or false

  panel.keymap = opts.keymap or {}
  panel.layout = vim.tbl_deep_extend("force", panel.layout, opts.layout or {})

  if panel.keymap.open then
    vim.keymap.set("i", panel.keymap.open, mod.open, {
      desc = "[copilot] (panel) open",
      silent = true,
    })
  end

  panel.setup_done = true
end

function mod.teardown()
  local opts = config.get("panel") --[[@as copilot_config_panel]]
  if not opts.enabled then
    return
  end

  if not panel.setup_done then
    return
  end

  if panel.keymap.open then
    vim.keymap.del("i", panel.keymap.open)
  end

  panel:close()

  panel.setup_done = false
end

return mod
