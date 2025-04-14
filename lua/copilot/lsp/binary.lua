local util = require("copilot.util")
local logger = require("copilot.logger")

local M = {
  ---@class copilot_server_info
  ---@field path string
  ---@field filename string
  ---@field absolute_path string
  ---@field absolute_filepath string
  ---@field extracted_filename string
  copilot_server_info = nil,
  initialized = false,
  initialization_failed = false,
}

local function ensure_directory_exists(path)
  if path and vim.fn.isdirectory(path) == 0 then
    if vim.fn.mkdir(path) == 0 then
      logger.error("failed to create directory: " .. path)
      return false
    end
  end

  return true
end

---@param folder string
---@param except_file string
local function delete_all_except(folder, except_file)
  for file in vim.fs.dir(folder) do
    if file ~= except_file then
      local file_path = folder .. "/" .. file
      if vim.fn.isdirectory(file_path) == 1 then
        vim.fn.delete(file_path, "rf")
      else
        vim.fn.delete(file_path)
      end
    end
  end
end

---@param url string
---@param local_server_zip_filepath string
---@return boolean
local function download_file_with_wget(url, local_server_zip_filepath)
  if vim.fn.executable("wget") == 0 then
    return false
  end

  local wget_cmd = string.format('wget -O "%s" "%s"', local_server_zip_filepath:gsub("\\", "\\\\"), url)
  logger.trace("Downloading copilot-language-server with command: " .. wget_cmd)
  local result = vim.fn.system(wget_cmd)

  if vim.v.shell_error ~= 0 then
    logger.error("error downloading file with wget: " .. result)
    return false
  end

  return true
end

---@param url string
---@param local_server_zip_filepath string
---@return boolean
local function download_file_with_curl(url, local_server_zip_filepath)
  if vim.fn.executable("curl") == 0 then
    return false
  end

  local cmd = string.format('curl -s -L -o "%s" "%s"', local_server_zip_filepath:gsub("\\", "\\\\"), url)
  logger.trace("downloading copilot-language-server with command: " .. cmd)
  local result = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    logger.error("error downloading file: " .. result)
    return false
  end

  return true
end

---@param url string
---@param local_server_zip_filepath string
---@param local_server_zip_path string
---@return boolean
local function download_file(url, local_server_zip_filepath, local_server_zip_path)
  logger.notify("current version of copilot-language-server is not downloaded, downloading")

  if (vim.fn.executable("curl") ~= 1) and (vim.fn.executable("wget") == 1) then
    logger.error("neither curl nor wget is available, please make sure one of them is installed")
    M.initialization_failed = true
    return false
  end

  if vim.fn.filereadable(local_server_zip_filepath) == 1 then
    vim.fn.delete(local_server_zip_filepath)
  else
    logger.trace("copilot-language-server zip file not found, ensuring directory exists")

    if not ensure_directory_exists(local_server_zip_path) then
      return false
    end
  end

  if not download_file_with_curl(url, local_server_zip_filepath) then
    if not download_file_with_wget(url, local_server_zip_filepath) then
      logger.error("could not download the copilot sever")
      M.initialization_failed = true
      return false
    end
  end

  logger.debug("copilot-language-server downloaded to " .. local_server_zip_filepath)
  return true
end

---@param copilot_server_info copilot_server_info
---@param local_server_zip_filepath string
---@return boolean
local function extract_file(copilot_server_info, local_server_zip_filepath)
  if vim.fn.filereadable(local_server_zip_filepath) == 0 then
    logger.error("Error: file not found after download")
    return false
  end

  if vim.fn.filereadable(copilot_server_info.extracted_filename) == 1 then
    vim.fn.delete(copilot_server_info.extracted_filename)
  end

  local unzip_cmd
  if vim.fn.has("win32") > 0 then
    unzip_cmd = string.format(
      'powershell -Command "Expand-Archive -Path %s -DestinationPath %s"',
      local_server_zip_filepath,
      copilot_server_info.absolute_path
    )
  else
    unzip_cmd = string.format(
      "unzip -o %s -d %s",
      local_server_zip_filepath:gsub("\\", "\\\\"),
      copilot_server_info.absolute_path:gsub("\\", "\\\\")
    )
  end

  logger.trace("Extracting copilot-language-server with command: " .. unzip_cmd)
  vim.fn.system(unzip_cmd)

  if vim.v.shell_error ~= 0 then
    M.initialization_failed = true
    return false
  end

  vim.fn.delete(local_server_zip_filepath)
  if copilot_server_info.path ~= "js" then
    vim.fn.rename(
      vim.fs.joinpath(copilot_server_info.absolute_path, copilot_server_info.extracted_filename),
      copilot_server_info.absolute_filepath
    )
  end

  return true
end

---@param filename string
---@return boolean
local function set_permissions(filename)
  if vim.fn.has("win32") > 0 then
    return true
  end

  local chmod_cmd = string.format("chmod +x %s", filename)
  logger.trace("Setting permissions with command: " .. chmod_cmd)
  local result = vim.fn.system(chmod_cmd)

  if vim.v.shell_error ~= 0 then
    logger.error("Error setting permissions: " .. result)
    return false
  end

  return true
end

-- let's hope the naming convention does not change!!!
---@return boolean
function M.init()
  if M.initialized then
    return true
  elseif M.initialization_failed then
    logger.error("copilot-language-server previously failed to initialize, please check the logs")
    return false
  end

  M.initialization_failed = true

  local copilot_version = util.get_editor_info().editorPluginInfo.version
  local plugin_path = vim.fs.normalize(util.get_plugin_path())
  local copilot_server_info = M.get_copilot_server_info()
  local download_filename =
    string.format("copilot-language-server-%s-%s.zip", copilot_server_info.path, copilot_version)
  local url = string.format(
    "https://github.com/github/copilot-language-server-release/releases/download/%s/%s",
    copilot_version,
    download_filename
  )
  local local_server_zip_path = vim.fs.joinpath(plugin_path, "copilot/", copilot_server_info.path)
  local local_server_zip_filepath =
    vim.fs.joinpath(plugin_path, "copilot/", copilot_server_info.path, download_filename)

  logger.trace("copilot_server_info: ", copilot_server_info)

  if vim.fn.filereadable(copilot_server_info.absolute_filepath) == 1 then
    logger.debug("copilot-language-server is already downloaded")
    M.initialization_failed = false
    return true
  end

  if not download_file(url, local_server_zip_filepath, local_server_zip_path) then
    return false
  end

  if not extract_file(copilot_server_info, local_server_zip_filepath) then
    return false
  end

  if copilot_server_info.path ~= "js" then
    if not set_permissions(copilot_server_info.absolute_filepath) then
      logger.error("could not set permissions for copilot-language-server")
      return false
    end
    delete_all_except(copilot_server_info.absolute_path, copilot_server_info.filename)
  end

  logger.notify("copilot-language-server downloaded")
  return true
end

---@return boolean
local function is_arm()
  local fh, err = assert(io.popen("uname -m 2>/dev/null", "r"))
  if err then
    logger.error("could not determine if cpu is arm, assuming it is not: " .. err)
    return false -- we assume not arm
  end

  local os_name
  if fh then
    os_name = fh:read()
    fh:close()
  end

  return os_name == "aarch64" or string.sub(os_name, 1, 3) == "arm"
end

---@return boolean
local function is_musl()
  local fh, err = assert(io.popen("ldd --version 2>&1", "r"))
  if err then
    return false -- we assume glibc
  end

  local ldd_output
  if fh then
    ldd_output = fh:read()
    fh:close()
  end

  return string.sub(ldd_output, 1, 4) == "musl"
end

---@param client vim.lsp.Client|nil
---@return string
function M.get_server_info(client)
  local copilot_server_info = M.get_copilot_server_info()

  if client then
    return copilot_server_info.path .. "/" .. copilot_server_info().filename
  else
    return copilot_server_info.path .. "/" .. copilot_server_info().filename .. " " .. "not running"
  end
end

---@return table
function M.get_execute_command()
  return {
    M.server_path or M.get_server_path(),
    "--stdio",
  }
end

---@return copilot_server_info
function M.get_copilot_server_info()
  if M.copilot_server_info then
    return M.copilot_server_info
  end

  local copilot_version = util.get_editor_info().editorPluginInfo.version
  local plugin_path = vim.fs.normalize(util.get_plugin_path())
  local path = ""
  local extracted_filename = "copilot-language-server"
  local filename = "copilot-language-server-" .. copilot_version
  local os = vim.loop.os_uname().sysname
  if os == "Linux" then
    if is_arm() then
      path = "linux-arm64"
    elseif not is_musl() then
      path = "linux-x64"
    else
      -- Fallback to plain nodejs project
      path = "js"
    end
  elseif os == "Darwin" then
    if is_arm() then
      path = "darwin-arm64"
    else
      path = "darwin-x64"
    end
  elseif os == "Windows_NT" then
    path = "win32-x64"
    filename = filename .. ".exe"
    extracted_filename = extracted_filename .. ".exe"
  end

  if path == "" then
    logger.error("could not determine OS, please report this issue with the output of `uname -a`")
  end

  if path == "js" then
    filename = "language-server.js"
    extracted_filename = ""
  end

  M.copilot_server_info = {
    path = path,
    filename = filename,
    absolute_path = vim.fs.joinpath(plugin_path, "copilot/", path),
    absolute_filepath = vim.fs.joinpath(plugin_path, "copilot/", path, filename),
    extracted_filename = extracted_filename,
  }

  return M.copilot_server_info
end

---@return string
function M.get_server_path()
  return M.get_copilot_server_info().absolute_filepath
end

---@param custom_server_path? string
function M.setup(custom_server_path)
  if custom_server_path then
    if vim.fn.filereadable(custom_server_path) == 0 and vim.fn.executable(custom_server_path) == 0 then
      logger.error("copilot-language-server not found at " .. custom_server_path)
      return M
    end

    logger.debug("using custom copilot-language-server binary:", custom_server_path)
    M.copilot_server_info = {
      path = "",
      filename = "",
      absolute_path = "",
      absolute_filepath = custom_server_path or "",
      extracted_filename = "",
    }

    M.initialized = true
  end

  M.init()
end

return M
