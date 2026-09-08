-- Windows-only regression harness for the installer ACL preparation phase.
-- It executes production PowerShell ACL/hash/extraction commands against a local
-- ZIP fixture. Runtime selection is forced only at the vim.system boundary.
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
  local runtime = assert(vim.env.COPILOT_WINDOWS_RUNTIME, "COPILOT_WINDOWS_RUNTIME is required")
  assert(runtime == "powershell" or runtime == "pwsh" or runtime == "renamed-pwsh", "invalid runtime")
  local shell = assert(vim.env.COPILOT_WINDOWS_SHELL, "COPILOT_WINDOWS_SHELL is required")
  local edition = runtime == "powershell" and "Desktop" or "Core"
  local edition_check = "if($PSVersionTable.PSEdition -ne '"
    .. edition
    .. "'){throw 'unexpected child PSEdition'};"
    .. (
      runtime == "powershell" and "if($PSVersionTable.PSVersion.ToString() -notlike '5.1.*'){throw 'expected 5.1'};"
      or "if($PSVersionTable.PSVersion.Major -ne 7){throw 'expected PowerShell 7'};"
    )
  if separator == "forward" then
    root = root:gsub("\\", "/")
  elseif separator ~= "backslash" then
    fail("COPILOT_WINDOWS_SEPARATOR must be forward or backslash")
  end

  vim.opt.runtimepath:prepend(assert(vim.env.COPILOT_WINDOWS_WORKSPACE, "COPILOT_WINDOWS_WORKSPACE is required"))

  local installer = require("copilot.lsp.installer")
  local release = require("copilot.lsp.release")
  release.assets["win32-x64"].sha256 = assert(vim.env.COPILOT_WINDOWS_FIXTURE_SHA256)
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
  local hash_verified, extraction_verified = false, false
  local pending_fallback
  local staging_acl_verified = false
  local observed_staging
  local harness_error

  local function ps_quote(value)
    return "'" .. value:gsub("'", "''") .. "'"
  end

  local function run_shell(command, options, callback)
    -- Simulate only executable absence, not a failed script. This leaves the
    -- production fallback responsible for constructing and launching pwsh.
    if runtime == "pwsh" and command[1] == "powershell" then
      pending_fallback = command[4]
      error("powershell unavailable in pwsh runtime harness (ENOENT)")
    end
    assert(command[1] == (runtime == "pwsh" and "pwsh" or "powershell"), "unexpected shell selection")
    if runtime == "pwsh" then
      assert(pending_fallback == command[4], "pwsh must retry the failed powershell spawn's script")
      pending_fallback = nil
    end
    assert(options.clear_env and options.env, "child environment must be sanitized")
    for name, value in pairs(options.env) do
      assert(
        (
          type(name) == "number" and not value:lower():match("^psmodulepath=")
          or type(name) == "string" and name:lower() ~= "psmodulepath"
        ),
        "child inherited PSModulePath"
      )
    end
    command = vim.deepcopy(command)
    -- Absolute resolution also models a Core executable installed as powershell;
    -- the production command and script remain otherwise unchanged.
    command[1] = shell
    command[4] = edition_check .. command[4]
    return original_system(command, options, callback)
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
    local result = original_system({ shell, "-NoProfile", "-Command", edition_check .. script }, {
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
      .. "$row=[ordered]@{path=$p;edition=$PSVersionTable.PSEdition};"
      .. "try{Set-Acl -LiteralPath $p -AclObject (New-D);$row.set_acl='succeeded'}"
      .. "catch{$row.set_acl=$_.Exception.Message};"
      .. "try{[System.IO.Directory]::SetAccessControl($p,(New-D));"
      .. "$row.directory_set_access_control='succeeded'}catch{$row.directory_set_access_control=$_.Exception.Message};"
      .. "$out+=[pscustomobject]$row};$out|ConvertTo-Json -Compress"
    local result = original_system({ shell, "-NoProfile", "-Command", edition_check .. script }, {
      text = true,
      env = verification_env,
      clear_env = true,
    }):wait()
    if result.code ~= 0 then
      fail("ACL persistence diagnostic failed: " .. (result.stderr or result.stdout or "unknown error"))
    end
    return result.stdout
  end

  local function verify_published_acl(path)
    local install = vim.fs.dirname(path)
    local target = vim.fs.dirname(install)
    local version = vim.fs.dirname(target)
    local script = "$ErrorActionPreference='Stop';$s=[System.Security.Principal.WindowsIdentity]::GetCurrent().User;"
      .. "$parents=@("
      .. ps_quote(root)
      .. ","
      .. ps_quote(version)
      .. ","
      .. ps_quote(target)
      .. ");"
      .. "function Assert-P($p){$a=Get-Acl -LiteralPath $p;"
      .. "if($a.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
      .. "throw 'parent owner mismatch'};"
      .. "if(-not $a.AreAccessRulesProtected){throw 'parent DACL mismatch'};"
      .. "if(@($a.Access).Count -ne 1){throw 'parent ACE count mismatch'};$r=$a.Access[0];"
      .. "if($r.AccessControlType -ne 'Allow' -or $r.IdentityReference.Translate("
      .. "[System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value "
      .. "-or $r.FileSystemRights.ToString() -ne 'FullControl' "
      .. "-or $r.InheritanceFlags.ToString() -ne 'ContainerInherit, ObjectInherit' "
      .. "-or $r.PropagationFlags.ToString() -ne 'None' -or $r.IsInherited){throw 'parent ACE mismatch'}};"
      .. "function Assert-I($p,$leaf,$flags){$a=Get-Acl -LiteralPath $p;"
      .. "if($a.GetOwner([System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value){"
      .. "throw ($leaf+' owner mismatch')};if(@($a.Access).Count -ne 1){throw ($leaf+' ACE count mismatch')};"
      .. "$r=$a.Access[0];if($r.AccessControlType -ne 'Allow' -or $r.IdentityReference.Translate("
      .. "[System.Security.Principal.SecurityIdentifier]).Value -ne $s.Value "
      .. "-or $r.FileSystemRights.ToString() -ne 'FullControl' -or $r.InheritanceFlags.ToString() -ne $flags "
      .. "-or $r.PropagationFlags.ToString() -ne 'None' -or -not $r.IsInherited){throw ($leaf+' ACE mismatch')}};"
      .. "foreach($p in $parents){Assert-P $p};Assert-I "
      .. ps_quote(install)
      .. " 'install' 'ContainerInherit, ObjectInherit';Assert-I "
      .. ps_quote(path)
      .. " 'entrypoint' 'None';Assert-I "
      .. ps_quote(vim.fs.joinpath(install, "install.json"))
      .. " 'marker' 'None'"
    local result = original_system({ shell, "-NoProfile", "-Command", edition_check .. script }, {
      text = true,
      env = verification_env,
      clear_env = true,
    }):wait()
    return result.code == 0, result.stderr or result.stdout or "unknown error"
  end

  vim.system = function(command, options, callback)
    local program = command[1]
    local script = (program == "powershell" or program == "pwsh") and command[4] or ""
    local function respond(result)
      vim.schedule(function()
        callback(result)
      end)
      return { kill = function() end }
    end

    if script:find("Get%-Acl") then
      power_shell_calls = power_shell_calls + 1
      return run_shell(command, options, callback)
    end
    if script:find("Get-FileHash", 1, true) or script:find("Expand-Archive", 1, true) then
      return run_shell(command, options, function(result)
        if result.code == 0 then
          if script:find("Get-FileHash", 1, true) then
            hash_verified = true
          else
            extraction_verified = true
          end
        end
        callback(result)
      end)
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
      if not vim.uv.fs_copyfile(assert(vim.env.COPILOT_WINDOWS_FIXTURE), command[9]) then
        harness_error = "could not copy ZIP fixture"
      end
      return respond({ code = 0, stdout = "", stderr = "" })
    end
    if program == "sha256sum" or program == "shasum" or program == "openssl" or program == "unzip" then
      error(program .. " unavailable in PowerShell fallback harness (ENOENT)")
    end
    harness_error = "unexpected installer command: " .. table.concat(command, " ")
    return respond({ code = 91, stdout = "", stderr = "unexpected command in Windows ACL harness" })
  end

  installer.cache_root_override = root
  local done, install_error
  local published_path
  installer.ensure("binary", function(err, path)
    install_error, published_path = err, path
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
  if install_error then
    fail("fake transport install failed: " .. tostring(install_error))
  end
  if not published_path or vim.fn.filereadable(published_path) ~= 1 then
    fail("fake transport install did not publish an entrypoint")
  end
  assert(hash_verified and extraction_verified, "real PowerShell hash/extraction did not complete")
  assert(vim.fn.readfile(published_path)[1] == "server", "ZIP entrypoint contents mismatch")
  local published_acl_verified, published_acl_error = verify_published_acl(published_path)
  if not published_acl_verified then
    fail("published ACL verification failed: " .. published_acl_error)
  end
  local unexpected_transport
  vim.system = function(command, options, callback)
    if (command[1] ~= "powershell" and command[1] ~= "pwsh") or not command[4]:find("Get-Acl", 1, true) then
      unexpected_transport = command[1]
      error("unexpected cache transport: " .. command[1])
    end
    return run_shell(command, options, callback)
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
  assert(cached_path == published_path, "cache returned an unexpected path")
  assert(vim.fn.delete(vim.fs.dirname(published_path), "rf") == 0, "could not remove published test fixture")
  local diagnostic = acl_persistence_diagnostic()

  vim.fn.writefile({
    vim.json.encode({
      error = install_error,
      powershell_calls = power_shell_calls,
      runtime = runtime,
      edition = edition,
      hash_verified = hash_verified,
      extraction_verified = extraction_verified,
      separator = separator,
      staging = observed_staging,
      staging_acl_verified = staging_acl_verified,
      published_acl_verified = published_acl_verified,
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
