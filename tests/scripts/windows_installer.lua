-- Windows-only regression harness for the installer ACL preparation phase.
-- It executes production PowerShell ACL commands and replaces only transport
-- commands, so it never downloads a server release.
local function fail(message)
  error(message, 0)
end

if vim.uv.os_uname().sysname ~= "Windows_NT" then
  print("windows installer harness skipped: Windows is required")
  return
end

local result_path = vim.env.COPILOT_WINDOWS_RESULT

local function main()
  local root = assert(vim.env.COPILOT_WINDOWS_CACHE_ROOT, "COPILOT_WINDOWS_CACHE_ROOT is required")
  result_path = assert(result_path, "COPILOT_WINDOWS_RESULT is required")
  local separator = assert(vim.env.COPILOT_WINDOWS_SEPARATOR, "COPILOT_WINDOWS_SEPARATOR is required")
  if separator == "forward" then
    root = root:gsub("\\", "/")
  elseif separator ~= "backslash" then
    fail("COPILOT_WINDOWS_SEPARATOR must be forward or backslash")
  end

  vim.opt.runtimepath:prepend(assert(vim.env.COPILOT_WINDOWS_WORKSPACE, "COPILOT_WINDOWS_WORKSPACE is required"))

  local installer = require("copilot.lsp.installer")
  local release = require("copilot.lsp.release")
  local original_system = vim.system
  local verification_env = vim.fn.environ()
  for name in pairs(verification_env) do
    if name:lower() == "psmodulepath" then
      verification_env[name] = nil
    end
  end
  if vim.fn.has("nvim-0.11.3") == 0 then
    local env = {}
    for name, value in pairs(verification_env) do
      env[#env + 1] = name .. "=" .. value
    end
    verification_env = env
  end
  local power_shell_calls = 0
  local staging_acl_verified = false
  local observed_staging
  local harness_error

  local function ps_quote(value)
    return "'" .. value:gsub("'", "''") .. "'"
  end

  local function verify_staging_acl(path)
    local script = "$ErrorActionPreference='Stop';$p="
      .. ps_quote(path)
      .. ";$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User;$a=Get-Acl -LiteralPath $p;"
      .. "if($a.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
      .. "throw 'staging owner mismatch'};"
      .. "if(@($a.Access).Count -ne 1){throw 'staging ACE count mismatch'};$r=$a.Access[0];"
      .. "if($r.AccessControlType -ne 'Allow' -or $r.IdentityReference.Translate("
      .. "[System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){throw 'staging identity mismatch'};"
      .. "if($r.FileSystemRights.ToString() -ne 'FullControl'){throw 'staging rights mismatch'};"
      .. "if($r.InheritanceFlags.ToString() -ne 'ContainerInherit, ObjectInherit' "
      .. "-or $r.PropagationFlags.ToString() -ne 'None'){throw 'staging inheritance mismatch'};"
      .. "if(-not $r.IsInherited){throw 'staging ACE is not inherited'}"
    local result = original_system({ "powershell", "-NoProfile", "-Command", script }, {
      text = true,
      env = verification_env,
      clear_env = true,
    }):wait()
    return result.code == 0, result.stderr or result.stdout or "unknown error"
  end

  local function acl_persistence_diagnostic()
    local forward = root:gsub("\\", "/") .. "/acl-diagnostic-forward"
    local backward = root:gsub("/", "\\") .. "\\acl-diagnostic-backslash"
    local script = "$ErrorActionPreference='Stop';"
      .. "function New-D{$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User;"
      .. "$d=New-Object System.Security.AccessControl.DirectorySecurity;$d.SetOwner($s);"
      .. "$d.SetAccessRuleProtection($true,$false);"
      .. "$r=New-Object System.Security.AccessControl.FileSystemAccessRule($s,'FullControl',"
      .. "'ContainerInherit,ObjectInherit','None','Allow');"
      .. "$d.AddAccessRule($r);return $d};$out=@();$paths=@("
      .. ps_quote(forward)
      .. ","
      .. ps_quote(backward)
      .. ");foreach($p in $paths){[System.IO.Directory]::CreateDirectory($p)|Out-Null;"
      .. "[System.IO.Directory]::SetAccessControl($p,(New-D));$row=[ordered]@{path=$p};"
      .. "try{Set-Acl -LiteralPath $p -AclObject (New-D);$row.set_acl='succeeded'}"
      .. "catch{$row.set_acl=$_.Exception.Message};"
      .. "try{[System.IO.Directory]::SetAccessControl($p,(New-D));"
      .. "$row.directory_set_access_control='succeeded'}catch{$row.directory_set_access_control=$_.Exception.Message};"
      .. "$out+=[pscustomobject]$row};$out|ConvertTo-Json -Compress"
    local result = original_system({ "powershell", "-NoProfile", "-Command", script }, {
      text = true,
      env = verification_env,
      clear_env = true,
    }):wait()
    if result.code ~= 0 then
      fail("ACL persistence diagnostic failed: " .. (result.stderr or result.stdout or "unknown error"))
    end
    return result.stdout
  end

  vim.system = function(command, options, callback)
    local program = command[1]
    local script = program == "powershell" and command[4] or ""
    local is_transport = program == "curl"
      or program == "wget"
      or program == "unzip"
      or program == "sha256sum"
      or program == "shasum"
      or program == "openssl"
      or (
        program == "powershell"
        and (script:find("Invoke%-WebRequest") or script:find("Get%-FileHash") or script:find("Expand%-Archive"))
      )

    if not is_transport then
      if program == "powershell" then
        power_shell_calls = power_shell_calls + 1
      end
      return original_system(command, options, callback)
    end

    if program == "curl" then
      local target = vim.fs.joinpath(root, release.version, "win32-x64")
      for name, kind in vim.fs.dir(target) do
        if kind == "directory" and name:match("^%.staging%-") then
          observed_staging = vim.fs.joinpath(target, name)
          local verified, verify_error = verify_staging_acl(observed_staging)
          staging_acl_verified = verified
          if not verified then
            harness_error = "live staging ACL verification failed: " .. verify_error
          end
          break
        end
      end
      if not staging_acl_verified and not harness_error then
        harness_error = "download began before a private staging reservation existed"
      end
    end

    vim.schedule(function()
      callback({ code = 91, stdout = "", stderr = "transport disabled by Windows ACL harness" })
    end)
    return { kill = function() end }
  end

  installer.cache_root_override = root
  local done, install_error
  installer.ensure("binary", function(err)
    install_error = err
    done = true
  end)
  if not vim.wait(30000, function()
    return done
  end, 25) then
    fail("installer did not finish")
  end
  vim.system = original_system

  if harness_error then
    fail(harness_error .. "; installer returned: " .. tostring(install_error))
  end
  if not staging_acl_verified then
    fail("installer never reached its download transport; installer returned: " .. tostring(install_error))
  end
  if not install_error or not install_error:find("download failed", 1, true) then
    fail("transport failure was not surfaced: " .. tostring(install_error))
  end

  -- Seed a local cache fixture without downloading or executing a server.
  local store = require("copilot.lsp.store")
  local asset = release.assets["win32-x64"]
  local cache_options = {
    cache_root = root,
    version = release.version,
    target = "win32-x64",
    sha256 = asset.sha256,
    entrypoint = asset.entrypoint,
  }
  local reservation = assert(store.reserve(cache_options))
  assert(vim.fn.writefile({ "server fixture" }, vim.fs.joinpath(reservation.path, asset.entrypoint)) == 0)
  local receipt = assert(store.publish(reservation, cache_options, function() end))
  assert(not receipt.error, receipt.error)
  assert(receipt.path, "fixture was not published")
  local unexpected_transport
  vim.system = function(command, options, callback)
    if command[1] ~= "powershell" or not command[4]:find("Get-Acl", 1, true) then
      unexpected_transport = command[1]
      error("unexpected cache transport: " .. command[1])
    end
    return original_system(command, options, callback)
  end
  done = false
  local cached_path
  installer.ensure("binary", function(err, path)
    install_error, cached_path, done = err, path, true
  end)
  assert(
    vim.wait(30000, function()
      return done
    end, 25),
    "cache verification did not finish"
  )
  vim.system = original_system
  assert(not unexpected_transport, "cache invoked transport: " .. tostring(unexpected_transport))
  assert(not install_error, install_error)
  assert(cached_path == receipt.path, "cache returned an unexpected path")
  assert(vim.fn.delete(vim.fs.dirname(receipt.path), "rf") == 0, "could not remove cache fixture")
  local diagnostic = acl_persistence_diagnostic()

  vim.fn.writefile({
    vim.json.encode({
      error = install_error,
      powershell_calls = power_shell_calls,
      separator = separator,
      staging = observed_staging,
      staging_acl_verified = staging_acl_verified,
      cache_verified = true,
      diagnostic = diagnostic,
    }),
  }, result_path)
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  if result_path and result_path ~= "" then
    vim.fn.writefile({ vim.json.encode({ failure = err }) }, result_path)
  end
  io.stderr:write(tostring(err), "\n")
  vim.cmd("cquit 1")
end
