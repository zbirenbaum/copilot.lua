local M = {}

local panel_uri_prefix = "copilot:///"

---@return string panelUri
function M.panel_uri_from_doc_uri(doc_uri)
  return panel_uri_prefix .. vim.fs.normalize(vim.uri_to_fname(doc_uri))
end

---@return string doc_uri
function M.panel_uri_to_doc_uri(panel_uri)
  return panel_uri:gsub("^" .. panel_uri_prefix, "file:///")
end

---@param bufname string
function M.is_panel_uri(bufname)
  return bufname:sub(1, #panel_uri_prefix) == panel_uri_prefix
end

return M
