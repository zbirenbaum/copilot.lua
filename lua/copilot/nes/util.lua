local M = {}

local logger = require("copilot.logger")

---@param edit copilotlsp.InlineEdit
function M.apply_inline_edit(edit)
  local bufnr = vim.uri_to_bufnr(edit.textDocument.uri)

  ---@diagnostic disable-next-line: assign-type-mismatch
  vim.lsp.util.apply_text_edits({ edit }, bufnr, "utf-16")
end

---Debounces calls to a function, and ensures it only runs once per delay
---even if called repeatedly.
---@param fn fun(...: any)
---@param delay integer
function M.debounce(fn, delay)
  local timer = vim.uv.new_timer()
  if not timer then
    logger.error("unable to create timer")
    return
  end

  return function(...)
    local argv = vim.F.pack_len(...)
    timer:start(delay, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(vim.F.unpack_len(argv))
    end)
  end
end

---@private
---@class Capture
---@field hl string|string[]
---range(0-based)
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer

---@param text string
---@param lang string
---@return Capture[]?
local function parse_text(text, lang)
  local ok, trees = pcall(vim.treesitter.get_string_parser, text, lang)
  if not ok then
    return
  end
  trees:parse(true)

  local captures = {}

  trees:for_each_tree(function(tree, _)
    local hl_query = vim.treesitter.query.get(lang, "highlights")
    if not hl_query then
      return
    end

    local iter = hl_query:iter_captures(tree:root(), text)
    vim.iter(iter):each(function(id, node)
      local name = hl_query.captures[id]
      local hl = "Normal"
      if not vim.startswith(name, "_") then
        hl = "@" .. name .. "." .. lang
      end
      local start_row, start_col, end_row, end_col = node:range()

      -- Ignore zero-width captures if they cause issues (sometimes happen at EOF)
      if start_row == end_row and start_col == end_col then
        return
      end

      table.insert(captures, {
        hl = hl,
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
      })
    end)
  end)
  return captures
end

local function merge_captures(captures)
  table.sort(captures, function(a, b)
    if a.start_row == b.start_row then
      return a.start_col < b.start_col
    end
    return a.start_row < b.start_row
  end)
  local merged_captures = {}
  for i = 2, #captures do
    local prev = captures[i - 1]
    local curr = captures[i]
    if
      prev.start_row == curr.start_row
      and prev.start_col == curr.start_col
      and prev.end_row == curr.end_row
      and prev.end_col == curr.end_col
    then
      local prev_hl = type(prev.hl) == "table" and prev.hl or { prev.hl }
      local curr_hl = type(curr.hl) == "table" and curr.hl or { curr.hl }
      ---@diagnostic disable-next-line: param-type-mismatch
      vim.list_extend(prev_hl, curr_hl)
      curr.hl = prev_hl
    else
      table.insert(merged_captures, prev)
    end
  end
  table.insert(merged_captures, captures[#captures])

  return merged_captures
end

function M.hl_text_to_virt_lines(text, lang)
  local lines = vim.split(text, "\n")
  local normal_hl = "Normal"
  local bg_hl = "NesAdd"

  local function hl_chunk(chunk, hl)
    if not hl then
      return { chunk, { normal_hl, bg_hl } }
    end
    if type(hl) == "string" then
      return { chunk, { hl, bg_hl } }
    end
    hl = vim.deepcopy(hl)
    table.insert(hl, bg_hl)
    return { chunk, hl }
  end

  local captures = parse_text(text, lang)
  if not captures or #captures == 0 then
    return vim
      .iter(lines)
      :map(function(line)
        return { hl_chunk(line) }
      end)
      :totable()
  end

  captures = merge_captures(captures)

  local virt_lines = {}

  local curr_row = 0
  local curr_col = 0
  local curr_virt_line = {}

  vim.iter(captures):each(function(cap)
    -- skip if the capture is before the current position
    if cap.end_row < curr_row or (cap.end_row == curr_row and cap.end_col < curr_col) then
      return
    end

    if cap.start_row > curr_row then
      -- add the rest of the line
      local chunk_text = string.sub(lines[curr_row + 1], curr_col + 1)
      table.insert(curr_virt_line, hl_chunk(chunk_text))
      table.insert(virt_lines, curr_virt_line)

      for i = curr_row + 1, cap.start_row - 1 do
        local line_text = lines[i + 1]
        table.insert(virt_lines, { hl_chunk(line_text) })
      end

      curr_row = cap.start_row
      curr_col = 0
      curr_virt_line = {}
    end

    assert(curr_row == cap.start_row, "Unexpected start row")

    if cap.start_col > curr_col then
      local chunk_text = string.sub(lines[curr_row + 1], curr_col + 1, cap.start_col)
      table.insert(curr_virt_line, hl_chunk(chunk_text))
      curr_col = cap.start_col
    end

    assert(curr_col == cap.start_col, "Unexpected start column")

    if cap.end_row > curr_row then
      local chunk_text = string.sub(lines[curr_row + 1], curr_col + 1)
      table.insert(curr_virt_line, hl_chunk(chunk_text, cap.hl))
      table.insert(virt_lines, curr_virt_line)

      for i in curr_row + 1, cap.end_row - 1 do
        local line_text = lines[i + 1]
        table.insert(virt_lines, { hl_chunk(line_text, cap.hl) })
      end

      curr_row = cap.end_row
      curr_col = 0
      curr_virt_line = {}
    end

    assert(curr_row == cap.end_row, "Unexpected end row")

    if cap.end_col > curr_col then
      local chunk_text = string.sub(lines[curr_row + 1], curr_col + 1, cap.end_col)
      table.insert(curr_virt_line, hl_chunk(chunk_text, cap.hl))
      curr_col = cap.end_col
    end
  end)

  if #curr_virt_line > 0 then
    table.insert(virt_lines, curr_virt_line)
  end

  return virt_lines
end

return M
