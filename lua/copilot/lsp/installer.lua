local release = require("copilot.lsp.release")
local logger = require("copilot.logger")
local store = require("copilot.lsp.store")

local M = { cache_root_override = nil }

local status = { state = "idle", target = nil, path = nil, error = nil }
local operations = {}
local process_timeout = 10 * 60 * 1000
local operation_timeout = 12 * 60 * 1000

local function set_status(state, target, path, error)
  status = { state = state, target = target, path = path, error = error }
end

local function schedule(callback)
  vim.schedule(callback)
end

local function notify(message)
  schedule(function()
    pcall(logger.notify, message)
  end)
end

local function cache_root()
  return M.cache_root_override or M.get_cache_root()
end

local function target_dir(target)
  return vim.fs.joinpath(cache_root(), release.version, target)
end

local function entrypoint(target, root)
  return vim.fs.joinpath(root or target_dir(target), release.assets[target].entrypoint)
end

local function unique_path(prefix, suffix)
  return vim.fs.joinpath(
    cache_root(),
    string.format(".copilot-lsp-%s-%d-%d%s", prefix, vim.uv.os_getpid(), vim.uv.hrtime(), suffix)
  )
end

local function regular_file(path)
  local stat = vim.uv.fs_lstat(path)
  return stat and stat.type == "file"
end

local function executable_file(target, path)
  if not regular_file(path) then
    return false
  end
  return target == "js" and vim.fn.filereadable(path) == 1 or vim.fn.executable(path) == 1
end

local function remove_archive(path)
  local stat = path and vim.uv.fs_lstat(path)
  if stat and stat.type == "file" then
    vim.uv.fs_unlink(path)
  end
end

local function command_error(result, command)
  local output = result and (result.stderr or "") or ""
  if output == "" then
    output = result and (result.stdout or "") or ""
  end
  return string.format("%s failed%s", command[1], output ~= "" and (": " .. output:gsub("%s+$", "")) or "")
end

local function phase_active(operation, phase, token)
  return operations[operation.key] == operation
    and not operation.terminal
    and operation.phase == phase
    and operation.phase_token == token
end

local function begin_phase(operation, phase)
  operation.phase = phase
  operation.phase_token = operation.phase_token + 1
  operation.active_process = nil
  return operation.phase_token
end

local finish

local function windows_platform()
  return vim.loop.os_uname().sysname == "Windows_NT"
end

local function run_commands(operation, phase, commands, callback, stage, owned_path)
  local token = begin_phase(operation, phase)
  local index = 0
  local errors = {}
  local function next_command(last_error, fallback_command)
    if not phase_active(operation, phase, token) then
      return
    end
    if last_error then
      errors[#errors + 1] = last_error
    end
    if not fallback_command then
      index = index + 1
    end
    local command = fallback_command or commands[index]
    if not command then
      callback(nil, string.format("%s failed at %s (%s): %s", stage, owned_path, stage, table.concat(errors, "; ")))
      return
    end
    local completed = false
    local process
    local ok
    local options = { text = true, timeout = process_timeout }
    if windows_platform() and (command[1] == "powershell" or command[1] == "pwsh") then
      -- Let each runtime discover its own modules instead of inheriting another edition's.
      options.env = vim.fn.environ()
      for name in pairs(options.env) do
        if name:lower() == "psmodulepath" then
          options.env[name] = nil
        end
      end
      options.clear_env = true
      -- Before 0.11.3, clear_env bypasses vim.system's dictionary conversion.
      if vim.fn.has("nvim-0.11.3") == 0 then
        local env = {}
        for name, value in pairs(options.env) do
          env[#env + 1] = name .. "=" .. value
        end
        options.env = env
      end
    end
    ok, process = pcall(vim.system, command, options, function(result)
      if completed then
        return
      end
      completed = true
      if operation.active_process == process then
        operation.active_process = nil
      end
      schedule(function()
        if not phase_active(operation, phase, token) then
          return
        end
        if result.code == 0 then
          callback(result, nil)
        else
          next_command(command_error(result, command))
        end
      end)
    end)
    if not ok or not process then
      completed = true
      local fallback
      if windows_platform() and command[1] == "powershell" then
        fallback = vim.list_extend({ "pwsh" }, vim.list_slice(command, 2))
      end
      next_command(string.format("%s unavailable", command[1]), fallback)
    else
      operation.active_process = process
    end
  end
  next_command(nil)
end

local function hash_from_result(result)
  for token in (result.stdout or ""):gmatch("%S+") do
    local digest = token:gsub("^.*=", ""):gsub("^[^0-9a-fA-F]+", ""):gsub("[^0-9a-fA-F]+$", "")
    if #digest == 64 and digest:match("^[0-9a-fA-F]+$") then
      return digest:lower()
    end
  end
end

local function ps_quote(value)
  return "'" .. value:gsub("'", "''") .. "'"
end

local function needs_chmod(target)
  return target ~= "js" and not target:match("^win32%-")
end

finish = function(operation, err, path, outcome)
  if operations[operation.key] ~= operation or operation.terminal then
    return
  end
  operation.terminal = true
  operation.phase = "terminal"
  operation.phase_token = operation.phase_token + 1
  operations[operation.key] = nil
  if operation.active_process then
    pcall(operation.active_process.kill, operation.active_process, 15)
    operation.active_process = nil
  end
  if operation.timer then
    pcall(operation.timer.stop, operation.timer)
    pcall(operation.timer.close, operation.timer)
    operation.timer = nil
  end
  remove_archive(operation.archive)
  if (not outcome or outcome == "unmarked") and operation.reservation then
    local discarded, discard_error = store.discard(operation.reservation, operation.options)
    if not discarded then
      logger.warn("Could not discard Copilot server reservation: " .. tostring(discard_error))
    end
  end
  if err then
    set_status("failed", operation.target, nil, err)
  else
    set_status("ready", operation.target, path, nil)
    logger.info("Copilot server " .. release.version .. " ready at " .. path)
    if outcome ~= "cached" then
      notify("Copilot server " .. release.version .. " ready")
    end
  end
  local callbacks = operation.callbacks
  operation.callbacks = {}
  for _, callback in ipairs(callbacks) do
    schedule(function()
      callback(err, path)
    end)
  end
end

local function arm_deadline(operation)
  operation.timer = vim.defer_fn(function()
    if operations[operation.key] ~= operation or operation.terminal then
      return
    end
    if not windows_platform() and operation.phase == "publish" and operation.reservation then
      local committed = store.current(operation.options)
      if type(committed) == "string" then
        finish(operation, nil, committed, "published")
        return
      end
    end
    finish(operation, "install timed out after 12 minutes", nil, "unmarked")
  end, M._operation_deadline or operation_timeout)
end

local function ps_set_acl(kind)
  -- A Core executable may be exposed as powershell.exe; inspect the runtime,
  -- not its name. Both APIs persist only the descriptor's modified sections.
  return "if($PSVersionTable.PSEdition -eq 'Core'){"
    .. "[System.IO.FileSystemAclExtensions]::SetAccessControl([System.IO."
    .. kind
    .. "Info]::new($p),$d)}else{[System.IO."
    .. kind
    .. "]::SetAccessControl($p,$d)};"
end

local function private_acl_command(path, normalize_owner, parent)
  local quoted = ps_quote(path)
  local script = "$ErrorActionPreference='Stop';$p=" .. quoted .. ";"
  script = script .. "$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User;"
  if parent then
    script = script .. "$parent=Get-Acl -LiteralPath " .. ps_quote(parent) .. ";"
  end
  if normalize_owner then
    -- Elevated tokens default new objects to Administrators ownership. Change
    -- only the owner of our fresh reservation, preserving its inherited DACL.
    script = script
      .. "if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){"
      .. "throw ('reservation is a reparse point: '+$p)};"
      .. "$d=New-Object System.Security.AccessControl.DirectorySecurity;$d.SetOwner($s);"
      .. ps_set_acl("Directory")
  end
  script = script
    .. "$c=Get-Acl -LiteralPath $p;$detail=$p+'; ACL='+$c.Sddl;"
    .. "if($parent){$detail+='; parent ACL='+$parent.Sddl};"
    .. "if($c.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('owner mismatch (expected '+$s.Value+'): '+$detail)};"
    .. "if(@($c.Access).Count -ne 1){throw ('unexpected ACE count: '+$detail)};"
    .. "if(@($c.Access|Where-Object{$_.AccessControlType -ne 'Allow'}).Count -ne 0){"
    .. "throw ('unexpected ACE type: '+$detail)};"
    .. "if(@($c.Access|Where-Object{"
    .. "$_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value "
    .. "-ne $s.Value}).Count -ne 0){throw ('unexpected ACE identity: '+$detail)};"
    .. "if($c.Access[0].FileSystemRights.ToString() -ne 'FullControl'){throw ('unexpected ACE rights: '+$detail)};"
    .. "if($c.Access[0].InheritanceFlags.ToString() -ne 'ContainerInherit, ObjectInherit'){"
    .. "throw ('unexpected ACE inheritance flags: '+$detail)};"
    .. "if($c.Access[0].PropagationFlags.ToString() -ne 'None'){throw ('unexpected ACE propagation: '+$detail)};"
    .. "if($parent -and (-not $parent.AreAccessRulesProtected)){throw ('parent DACL is not protected: '+$detail)};"
    .. "if($parent -and @($parent.Access).Count -ne 1){throw ('unexpected parent ACE count: '+$detail)};"
    .. "if($parent -and $parent.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('parent owner mismatch: '+$detail)};"
    .. "if($parent -and $parent.Access[0].AccessControlType -ne 'Allow'){"
    .. "throw ('unexpected parent ACE type: '+$detail)};"
    .. "if($parent -and $parent.Access[0].IdentityReference.Translate("
    .. "[System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('unexpected parent ACE identity: '+$detail)};"
    .. "if($parent -and $parent.Access[0].FileSystemRights.ToString() -ne 'FullControl'){"
    .. "throw ('unexpected parent ACE rights: '+$detail)};"
    .. "if($parent -and $parent.Access[0].InheritanceFlags.ToString() -ne 'ContainerInherit, ObjectInherit'){"
    .. "throw ('unexpected parent ACE inheritance flags: '+$detail)};"
    .. "if($parent -and $parent.Access[0].PropagationFlags.ToString() -ne 'None'){"
    .. "throw ('unexpected parent ACE propagation: '+$detail)};"
    .. "if($parent -and ($parent.Access[0].IsInherited -ne $false)){throw ('parent ACE is inherited: '+$detail)};"
    .. "if($parent -and ($c.Access[0].IsInherited -ne $true)){throw ('ACE is not inherited: '+$detail)};"
    .. "if((-not $parent) -and ($c.Access[0].IsInherited -ne $false)){throw ('ACE is inherited: '+$detail)}"
  return {
    "powershell",
    "-NoProfile",
    "-Command",
    script,
  }
end

local function private_parent_command(path_token)
  local cache = ps_quote(path_token.cache_root)
  local version = ps_quote(path_token.version_path)
  local target = ps_quote(path_token.target_path)
  -- Set-Acl copies audit information too, which can require SeSecurityPrivilege.
  -- Direct persistence writes only modified sections; use a fresh descriptor
  -- for each path because persistence clears its modification flags.
  local script = "$ErrorActionPreference='Stop';"
    .. "$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User;"
    .. "$r=New-Object System.Security.AccessControl.FileSystemAccessRule($s,'FullControl',"
    .. "'ContainerInherit,ObjectInherit','None','Allow');"
    .. "$paths=@("
    .. cache
    .. ","
    .. version
    .. ","
    .. target
    .. ");"
    .. "foreach($p in $paths){$d=New-Object System.Security.AccessControl.DirectorySecurity;"
    .. "$d.SetOwner($s);$d.SetAccessRuleProtection($true,$false);$d.AddAccessRule($r);"
    .. "if(Test-Path -LiteralPath $p){"
    .. ps_set_acl("Directory")
    .. "}elseif($PSVersionTable.PSEdition -eq 'Core'){"
    .. "[System.IO.FileSystemAclExtensions]::Create([System.IO.DirectoryInfo]::new($p),$d)}"
    .. "else{[System.IO.Directory]::CreateDirectory($p,$d)|Out-Null}};"
    .. "foreach($p in $paths){$a=Get-Acl -LiteralPath $p;$detail=$p+'; ACL='+$a.Sddl;"
    .. "if($a.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('owner mismatch (expected '+$s.Value+'): '+$detail)};"
    .. "if(-not $a.AreAccessRulesProtected){throw ('DACL is not protected: '+$detail)};"
    .. "if(@($a.Access).Count -ne 1){throw ('unexpected ACE count: '+$detail)};"
    .. "if($a.Access[0].AccessControlType -ne 'Allow'){throw ('unexpected ACE type: '+$detail)};"
    .. "if($a.Access[0].IdentityReference.Translate("
    .. "[System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('unexpected ACE identity: '+$detail)};"
    .. "if($a.Access[0].FileSystemRights.ToString() -ne 'FullControl'){throw ('unexpected ACE rights: '+$detail)};"
    .. "if($a.Access[0].InheritanceFlags.ToString() -ne 'ContainerInherit, ObjectInherit'){"
    .. "throw ('unexpected ACE inheritance flags: '+$detail)};"
    .. "if($a.Access[0].PropagationFlags.ToString() -ne 'None'){throw ('unexpected ACE propagation: '+$detail)};"
    .. "if($a.Access[0].IsInherited){throw ('ACE is inherited: '+$detail)}}"
  return { "powershell", "-NoProfile", "-Command", script }
end

local function private_file_acl_command(paths, parent, normalize_owner)
  local quoted_paths = {}
  for _, path in ipairs(paths) do
    quoted_paths[#quoted_paths + 1] = ps_quote(path)
  end
  local script = "$ErrorActionPreference='Stop';"
    .. "$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User;"
    .. "$parent=Get-Acl -LiteralPath "
    .. ps_quote(parent)
    .. ";"
    .. "$paths=@("
    .. table.concat(quoted_paths, ",")
    .. ");"
    .. "foreach($p in $paths){if(-not (Test-Path -LiteralPath $p -PathType Leaf)){throw ('file missing: '+$p)};"
  if normalize_owner then
    script = script
      .. "if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){"
      .. "throw ('staged file is a reparse point: '+$p)};"
      .. "$d=New-Object System.Security.AccessControl.FileSecurity;$d.SetOwner($s);"
      .. ps_set_acl("File")
  end
  script = script
    .. "$a=Get-Acl -LiteralPath $p;$detail=$p+'; ACL='+$a.Sddl;"
    .. "if($a.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('owner mismatch (expected '+$s.Value+'): '+$detail)};"
    .. "if(@($a.Access).Count -ne 1){throw ('unexpected ACE count: '+$detail)};"
    .. "if($a.Access[0].AccessControlType -ne 'Allow'){throw ('unexpected ACE type: '+$detail)};"
    .. "if($a.Access[0].IdentityReference.Translate("
    .. "[System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('unexpected ACE identity: '+$detail)};"
    .. "if($a.Access[0].FileSystemRights.ToString() -ne 'FullControl'){throw ('unexpected ACE rights: '+$detail)};"
    .. "if($a.Access[0].InheritanceFlags.ToString() -ne 'None'){throw ('unexpected ACE inheritance flags: '+$detail)};"
    .. "if($a.Access[0].PropagationFlags.ToString() -ne 'None'){throw ('unexpected ACE propagation: '+$detail)};"
    .. "if($a.Access[0].IsInherited -ne $true){throw ('ACE is not inherited: '+$detail)}};"
    .. "$detail+='; parent ACL='+$parent.Sddl;"
    .. "if(-not $parent.AreAccessRulesProtected){throw ('parent DACL is not protected: '+$detail)};"
    .. "if(@($parent.Access).Count -ne 1){throw ('unexpected parent ACE count: '+$detail)};"
    .. "if($parent.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
    .. "throw ('parent owner mismatch: '+$detail)}"
  return { "powershell", "-NoProfile", "-Command", script }
end

local function publish(operation)
  local token = begin_phase(operation, "publish")
  local function handle_result(err, path, outcome)
    if not phase_active(operation, "publish", token) then
      return
    end
    if err then
      finish(operation, "activate failed at " .. operation.staging .. ": " .. err, nil, outcome)
      return
    end
    local current = store.current(operation.options)
    if outcome ~= "published" or type(path) ~= "string" or path ~= current then
      finish(
        operation,
        "activate failed at " .. operation.staging .. ": publication returned an unexpected entrypoint",
        nil,
        outcome
      )
    elseif not windows_platform() then
      finish(operation, nil, path, outcome)
    else
      -- Publication may adopt another installer's winner. Never repair that
      -- destination: validate its actual directory and files before using it.
      run_commands(operation, "published-directory-acl", {
        private_acl_command(vim.fs.dirname(path), false, operation.reservation.target_path),
      }, function(_, directory_error)
        if directory_error then
          finish(operation, directory_error, nil, "published")
          return
        end
        run_commands(operation, "published-file-acl", {
          private_file_acl_command(
            { path, vim.fs.joinpath(vim.fs.dirname(path), "install.json") },
            operation.reservation.target_path
          ),
        }, function(_, file_error)
          if file_error then
            finish(operation, file_error, nil, "published")
          else
            finish(operation, nil, path, "published")
          end
        end, "published file ACL", path)
      end, "published directory ACL", path)
    end
  end
  local prepare_files
  if windows_platform() then
    prepare_files = function(paths, done)
      run_commands(operation, "staged-file-acl", {
        private_file_acl_command(paths, operation.reservation.target_path, true),
      }, function(_, file_error)
        token = begin_phase(operation, "publish")
        done(file_error)
      end, "staged file ACL", operation.staging)
    end
  end
  local receipt = store.publish(operation.reservation, operation.options, function(err, path, outcome)
    schedule(function()
      handle_result(err, path, outcome)
    end)
  end, prepare_files)
  if receipt then
    handle_result(receipt.error, receipt.path, receipt.outcome)
  end
end

local function activate(operation)
  if vim.fn.isdirectory(operation.staging) ~= 1 then
    finish(operation, "activate failed at " .. operation.staging .. ": staging directory is missing", nil, "unmarked")
    return
  end
  local staged_entrypoint = entrypoint(operation.target, operation.staging)
  if needs_chmod(operation.target) then
    if not regular_file(staged_entrypoint) then
      finish(
        operation,
        "extract failed at " .. staged_entrypoint .. ": entrypoint is not a regular file",
        nil,
        "unmarked"
      )
      return
    end
    run_commands(operation, "chmod", { { "chmod", "u+x,go-rwx", staged_entrypoint } }, function(_, err)
      if err then
        finish(operation, err, nil, "unmarked")
      elseif not executable_file(operation.target, staged_entrypoint) then
        finish(operation, "chmod failed at " .. staged_entrypoint .. ": entrypoint is not executable", nil, "unmarked")
      else
        publish(operation)
      end
    end, "chmod", staged_entrypoint)
  elseif not executable_file(operation.target, staged_entrypoint) then
    finish(operation, "extract failed at " .. staged_entrypoint .. ": entrypoint is not readable", nil, "unmarked")
  else
    publish(operation)
  end
end

local function extract(operation, extract_script)
  set_status("extracting", operation.target, nil, nil)
  vim.fn.mkdir(operation.staging, "p", "448")
  run_commands(operation, "extract", {
    { "unzip", "-o", operation.archive, "-d", operation.staging },
    { "powershell", "-NoProfile", "-Command", extract_script },
  }, function(_, extract_error)
    if extract_error then
      finish(operation, extract_error, nil, "unmarked")
    else
      activate(operation)
    end
  end, "extract", operation.staging)
end

local function install(operation)
  local asset = release.assets[operation.target]
  local url = string.format(
    "https://github.com/github/copilot-language-server-release/releases/download/%s/%s",
    release.version,
    asset.filename
  )
  local download_script = "$ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri "
    .. ps_quote(url)
    .. " -OutFile "
    .. ps_quote(operation.archive)
  local hash_script = "(Get-FileHash -LiteralPath " .. ps_quote(operation.archive) .. " -Algorithm SHA256).Hash"
  local extract_script = "Expand-Archive -LiteralPath "
    .. ps_quote(operation.archive)
    .. " -DestinationPath "
    .. ps_quote(operation.staging)
    .. " -Force"

  set_status("downloading", operation.target, nil, nil)
  logger.info("Downloading Copilot server " .. release.version .. " (" .. operation.target .. ")")
  notify("Downloading Copilot server " .. release.version .. " (" .. operation.target .. ")")
  run_commands(operation, "download", {
    {
      "curl",
      "--fail",
      "--location",
      "--connect-timeout",
      "30",
      "--max-time",
      "600",
      "--output",
      operation.archive,
      url,
    },
    { "wget", "--timeout=30", "--tries=1", "--output-document", operation.archive, url },
    { "powershell", "-NoProfile", "-Command", download_script },
  }, function(_, download_error)
    if download_error then
      finish(operation, download_error, nil, "unmarked")
      return
    end
    set_status("verifying", operation.target, nil, nil)
    run_commands(operation, "hash", {
      { "sha256sum", operation.archive },
      { "shasum", "-a", "256", operation.archive },
      { "openssl", "dgst", "-sha256", operation.archive },
      { "powershell", "-NoProfile", "-Command", hash_script },
    }, function(result, hash_error)
      if hash_error then
        finish(operation, hash_error, nil, "unmarked")
        return
      end
      if hash_from_result(result) ~= asset.sha256 then
        finish(
          operation,
          "hash failed at " .. operation.archive .. ": checksum does not match release metadata",
          nil,
          "unmarked"
        )
        return
      end
      extract(operation, extract_script)
    end, "hash", operation.archive)
  end, "download", operation.archive)
end

local function begin_install(operation)
  operation.archive = unique_path("archive", ".zip")
  vim.fn.mkdir(cache_root(), "p", "448")
  local fd = vim.uv.fs_open(operation.archive, "w", 384)
  if fd then
    vim.uv.fs_close(fd)
  end
  install(operation)
end

local function reserve_operation(operation, prepared)
  local reservation, reserve_error = store.reserve(operation.options, prepared)
  if not reservation then
    finish(operation, reserve_error, nil, "unmarked")
    return
  end
  operation.reservation = reservation
  operation.staging = reservation.path
  if not windows_platform() then
    begin_install(operation)
    return
  end
  run_commands(
    operation,
    "reservation-acl",
    { private_acl_command(operation.staging, true, operation.reservation.target_path) },
    function(_, acl_error)
      if acl_error then
        finish(operation, "reservation privacy verification failed: " .. acl_error, nil, "unmarked")
        return
      end
      operation.private_staging = true
      begin_install(operation)
    end,
    "reservation ACL",
    operation.staging
  )
end

local function resolve_windows_cache(operation, prepared_path)
  if not vim.uv.fs_lstat(prepared_path.final_path) then
    reserve_operation(operation, prepared_path)
    return
  end
  run_commands(
    operation,
    "cache-directory-acl",
    { private_acl_command(prepared_path.final_path, false, prepared_path.target_path) },
    function(_, acl_error)
      if acl_error then
        finish(operation, "cache privacy verification failed: " .. acl_error, nil, "unmarked")
        return
      end
      local resolved = store.resolve(operation.options)
      if not resolved then
        reserve_operation(operation, prepared_path)
        return
      end
      run_commands(operation, "cache-file-acl", {
        private_file_acl_command(
          { vim.fs.joinpath(prepared_path.final_path, "install.json"), resolved },
          prepared_path.target_path
        ),
      }, function(_, file_acl_error)
        if file_acl_error then
          finish(operation, "cache file privacy verification failed: " .. file_acl_error, nil, "unmarked")
        else
          finish(operation, nil, resolved, "cached")
        end
      end, "cache file ACL", prepared_path.final_path)
    end,
    "cache directory ACL",
    prepared_path.final_path
  )
end

local function prepare_operation(operation)
  if not windows_platform() then
    reserve_operation(operation)
    return
  end
  local prepared_path, prepare_error = store.prepare_path(operation.options)
  if not prepared_path then
    finish(operation, prepare_error, nil, "unmarked")
    return
  end
  run_commands(operation, "parent-acl", { private_parent_command(prepared_path) }, function(_, acl_error)
    if acl_error then
      finish(operation, "staging parent privacy setup failed: " .. acl_error, nil, "unmarked")
      return
    end
    resolve_windows_cache(operation, prepared_path)
  end, "staging parent ACL", prepared_path.target_path)
end

---@param server_type string
---@param callback fun(err: string|nil, entrypoint: string|nil)
function M.ensure(server_type, callback)
  local target, target_error = M.resolve_target(server_type)
  if not target then
    set_status("failed", nil, nil, target_error)
    return schedule(function()
      callback(target_error, nil)
    end)
  end

  local options = {
    cache_root = cache_root(),
    version = release.version,
    target = target,
    sha256 = release.assets[target].sha256,
    entrypoint = release.assets[target].entrypoint,
  }
  if not windows_platform() then
    local resolved = store.resolve(options)
    if resolved then
      set_status("ready", target, resolved, nil)
      return schedule(function()
        callback(nil, resolved)
      end)
    end
  end

  local key = release.version .. ":" .. target
  local operation = operations[key]
  if operation then
    operation.callbacks[#operation.callbacks + 1] = callback
    return
  end

  local _, cleanup_error = store.cleanup_incomplete(options)
  if cleanup_error then
    logger.warn("Could not clean incomplete Copilot staging directories: " .. tostring(cleanup_error))
  end
  local _, archive_error = store.cleanup_archives(options)
  if archive_error then
    logger.warn("Could not clean stale Copilot archives: " .. tostring(archive_error))
  end
  operation = {
    key = key,
    target = target,
    options = options,
    reservation = nil,
    archive = nil,
    staging = nil,
    callbacks = { callback },
    phase = "reserved",
    phase_token = 0,
    terminal = false,
    deadline = vim.loop.hrtime() / 1000000 + (M._operation_deadline or operation_timeout),
  }
  operations[key] = operation
  arm_deadline(operation)
  prepare_operation(operation)
end

---@return { state: string, target: string|nil, path: string|nil, error: string|nil }
function M.get_status()
  return vim.deepcopy(status)
end

function M.reset()
  operations = {}
  set_status("idle", nil, nil, nil)
end

local function detect_libc()
  local ok, process = pcall(vim.system, { "getconf", "GNU_LIBC_VERSION" }, { text = true })
  if ok and process then
    local result = process:wait()
    if result.code == 0 then
      local output = ((result.stdout or "") .. (result.stderr or "")):lower()

      if output:find("glibc", 1, true) then
        return "glibc"
      end
    end
  end

  ok, process = pcall(vim.system, { "ldd", "--version" }, { text = true })
  if ok and process then
    local result = process:wait()
    if result.code == 0 then
      local output = ((result.stdout or "") .. (result.stderr or "")):lower()

      if output:find("musl", 1, true) then
        return "musl"
      end
      if output:find("glibc", 1, true) or output:find("gnu libc", 1, true) then
        return "glibc"
      end
    end
  end

  return nil
end

---@param server_type string
---@param uname? { sysname: string, machine: string }
---@param musl? string|boolean
---@return string? target
---@return string? error_message
function M.resolve_target(server_type, uname, musl)
  if server_type == "nodejs" then
    return "js"
  end
  uname = uname or vim.loop.os_uname()
  if uname.sysname == "Linux" and musl == nil then
    musl = detect_libc()
  end
  if musl == "musl" or musl == true then
    return nil, 'musl Linux is unsupported; use server.type = "nodejs"'
  end
  if uname.sysname == "Linux" and musl ~= false and musl ~= "glibc" then
    return nil, 'could not identify Linux libc; use server.type = "nodejs"'
  end
  local platform = ({ Linux = "linux", Darwin = "darwin", Windows_NT = "win32" })[uname.sysname]
  local architecture = ({
    x86_64 = "x64",
    amd64 = "x64",
    AMD64 = "x64",
    aarch64 = "arm64",
    arm64 = "arm64",
    ARM64 = "arm64",
  })[uname.machine]
  if platform and architecture then
    return platform .. "-" .. architecture
  end
  return nil, 'unsupported native target; use server.type = "nodejs"'
end

---@return string
function M.get_cache_root()
  return M.cache_root_override or vim.fs.joinpath(vim.fn.stdpath("data"), "copilot.lua", "lsp")
end

---@param target string
---@return string
function M.get_target_dir(target)
  return target_dir(target)
end

---@param target string
---@return string|nil entrypoint
---@return string|nil error
function M.get_entrypoint(target)
  local asset = release.assets[target]
  if not asset then
    return nil, "unsupported target: " .. tostring(target)
  end
  return store.resolve({
    cache_root = cache_root(),
    version = release.version,
    target = target,
    sha256 = asset.sha256,
    entrypoint = asset.entrypoint,
  })
end

return M
