local eq = MiniTest.expect.equality
local installer = require("copilot.lsp.installer")
local release = require("copilot.lsp.release")
local store = require("copilot.lsp.store")
local logger = require("copilot.logger")
local process_stub = require("tests.stubs.installer")

local original_resolve_target = installer.resolve_target
local original_store_reserve = store.reserve
local original_store_publish = store.publish
local original_os_uname = vim.loop.os_uname
local original_notify = logger.notify
local current_root
local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      process_stub.reset()
      store.reserve = original_store_reserve
      store.publish = original_store_publish
      vim.loop.os_uname = original_os_uname
      logger.notify = original_notify
      installer.reset()
      installer._operation_deadline = nil
      installer.cache_root_override = nil
      installer.resolve_target = original_resolve_target
      if current_root then
        vim.fn.delete(current_root, "rf")
        current_root = nil
      end
    end,
  },
})

local function canonical_path(path)
  return vim.uv.fs_realpath(path) or path
end

local function fixture_target()
  return vim.loop.os_uname().sysname == "Windows_NT" and "win32-x64" or "linux-x64"
end

local function successful_acl_responses(count)
  local responses = {}
  for _ = 1, count do
    responses[#responses + 1] = { code = 0, stdout = "", stderr = "" }
  end
  return responses
end

local function complete_pending(result, count)
  for _ = 1, count do
    vim.wait(1000, function()
      return result() ~= nil or #process_stub.pending > 0
    end)
    if result() then
      break
    end
    process_stub.complete_next()
  end
  vim.wait(1000, function()
    return result() ~= nil
  end)
end

local function extraction_error_fragment(target)
  return target == "win32-x64" and "entrypoint is not readable" or "entrypoint is not a regular file"
end

local function symlink(source, target)
  local ok, err = vim.uv.fs_symlink(source, target)
  eq(ok, true)
  eq(err, nil)
end

local function new_cache(target, absent)
  local root = vim.fn.tempname()
  if not absent then
    vim.fn.mkdir(vim.fs.joinpath(root, release.version, target), "p")
  end
  root = canonical_path(root)
  installer.cache_root_override = root
  installer.resolve_target = function(_, _, _)
    return target
  end
  current_root = root
  return root
end

local function options(root, target)
  local asset = release.assets[target]
  return {
    cache_root = root,
    version = release.version,
    target = target,
    sha256 = asset.sha256,
    entrypoint = asset.entrypoint,
  }
end

local function create_hit(root, target)
  local opts = options(root, target)
  local reservation = assert(store.reserve(opts))
  local entry = vim.fs.joinpath(reservation.path, opts.entrypoint)
  vim.fn.writefile({ "server" }, entry)
  vim.fn.setfperm(entry, target == "js" and "rw-------" or "rwx------")
  local receipt = assert(store.publish(reservation, opts, function() end))
  return receipt.path
end

local function successful_plan(target)
  return {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets[target].sha256 .. "  archive", stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  }
end

local function successful_completion(target)
  return function(command)
    if command[1] == "curl" then
      vim.fn.writefile({ "archive" }, command[9])
    elseif command[1] == "unzip" then
      vim.fn.mkdir(command[5], "p")
      local entry = vim.fs.joinpath(command[5], release.assets[target].entrypoint)
      vim.fn.writefile({ "server" }, entry)
      vim.fn.setfperm(entry, "rwxr-xr-x")
    end
  end
end

local function fallback_completion(target)
  return function(command)
    if command[1] == "unzip" then
      vim.fn.mkdir(command[5], "p")
      local entry = vim.fs.joinpath(command[5], release.assets[target].entrypoint)
      vim.fn.writefile({ "server" }, entry)
      vim.fn.setfperm(entry, "rwxr-xr-x")
    elseif (command[1] == "powershell" or command[1] == "pwsh") and (command[4] or ""):find("Expand%-Archive") then
      local destination = (command[4]):match("%-DestinationPath%s+'([^']+)'")
      vim.fn.mkdir(destination, "p")
      local entry = vim.fs.joinpath(destination, release.assets[target].entrypoint)
      vim.fn.writefile({ "server" }, entry)
      vim.fn.setfperm(entry, "rwxr-xr-x")
    end
  end
end

local function run_install(target, responses, completion, setup, sysname, absent)
  local root = new_cache(target, absent)
  if setup then
    setup(root)
  end
  local original_uname
  if sysname then
    original_uname = vim.loop.os_uname
    vim.loop.os_uname = function()
      return { sysname = sysname, machine = target == "win32-x64" and "AMD64" or "x86_64" }
    end
  end
  local restore = process_stub.start()
  process_stub.responses = responses or successful_plan(target)
  process_stub.on_complete = completion or successful_completion(target)
  local result
  local ok, run_error = xpcall(function()
    installer.ensure("binary", function(err, path)
      result = { err, path }
    end)
    for _ = 1, 16 do
      vim.wait(1000, function()
        return result ~= nil or #process_stub.pending > 0
      end)
      if result then
        break
      end
      process_stub.complete_next()
    end
    vim.wait(1000, function()
      return result ~= nil
    end)
  end, debug.traceback)
  restore()
  if original_uname then
    vim.loop.os_uname = original_uname
  end
  if not ok then
    error(run_error)
  end
  return canonical_path(root), result
end

local function with_system_probe(probes, callback)
  local original_system = vim.system
  vim.system = function(command)
    local probe = probes[command[1]] or {}
    if probe.fail then
      error(command[1] .. " failed to start")
    end
    return {
      wait = function()
        return { stdout = probe.stdout, stderr = probe.stderr, code = probe.code }
      end,
    }
  end
  local ok, err = pcall(callback)
  vim.system = original_system
  if not ok then
    error(err)
  end
end

T["cache hit avoids download"] = function()
  local target = fixture_target()
  local root = new_cache(target)
  local expected = create_hit(root, target)
  local restore = process_stub.start()
  if target == "win32-x64" then
    process_stub.responses = { powershell = successful_acl_responses(3) }
  end
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  if target == "win32-x64" then
    complete_pending(function()
      return result
    end, 3)
  else
    vim.wait(500, function()
      return result ~= nil
    end)
  end
  restore()
  eq(result, { nil, expected })
  if target == "win32-x64" then
    eq(#process_stub.calls, 3)
  else
    eq(process_stub.calls, {})
  end
end

T["downloads and publishes at the deterministic path"] = function()
  local target = fixture_target()
  local root, result = run_install(target)
  eq(result[1], nil)
  eq(
    result[2],
    vim.fs.joinpath(root, release.version, target, release.assets[target].sha256, release.assets[target].entrypoint)
  )
end

T["release metadata is internally consistent"] = function()
  eq(release.version:match("^[0-9]+%.[0-9]+%.[0-9]+$") ~= nil, true)
  local entrypoints = {
    ["darwin-arm64"] = "copilot-language-server",
    ["darwin-x64"] = "copilot-language-server",
    js = "language-server.js",
    ["linux-arm64"] = "copilot-language-server",
    ["linux-x64"] = "copilot-language-server",
    ["win32-arm64"] = "copilot-language-server.exe",
    ["win32-x64"] = "copilot-language-server.exe",
  }
  eq(vim.tbl_count(release.assets), vim.tbl_count(entrypoints))
  for target, expected_entrypoint in pairs(entrypoints) do
    local asset = release.assets[target]
    eq(asset.filename, string.format("copilot-language-server-%s-%s.zip", target, release.version))
    eq(asset.sha256:match("^[0-9a-f]+$") ~= nil and #asset.sha256 == 64, true)
    eq(asset.entrypoint, expected_entrypoint)
  end
end

T["resolve_target maps platforms and libc probes"] = function()
  local cases = {
    { "binary", { sysname = "Linux", machine = "x86_64" }, false, "linux-x64" },
    { "binary", { sysname = "Linux", machine = "aarch64" }, false, "linux-arm64" },
    { "binary", { sysname = "Darwin", machine = "arm64" }, nil, "darwin-arm64" },
    { "binary", { sysname = "Windows_NT", machine = "AMD64" }, nil, "win32-x64" },
    { "nodejs", { sysname = "Plan9", machine = "mips" }, nil, "js" },
  }
  for _, case in ipairs(cases) do
    local target, err = installer.resolve_target(case[1], case[2], case[3])
    eq(target, case[4])
    eq(err, nil)
  end
  with_system_probe({
    getconf = { stdout = "glibc 2.39", stderr = "", code = 0 },
  }, function()
    eq(installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" }), "linux-x64")
  end)

  with_system_probe({
    getconf = { stdout = "glibc 2.39", stderr = "", code = 1 },
    ldd = { stdout = "musl libc", stderr = "", code = 0 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    local error_message = assert(err)
    eq(error_message:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)

  with_system_probe({
    getconf = { stdout = "", stderr = "", code = 1 },
    ldd = { stdout = "musl libc", stderr = "", code = 0 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    local error_message = assert(err)
    eq(error_message:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)

  with_system_probe({
    getconf = { fail = true },
    ldd = { stdout = "", stderr = "", code = 1 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    local error_message = assert(err)
    eq(error_message:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
  with_system_probe({
    getconf = { stdout = "", stderr = "getconf: Unrecognized variable", code = 2 },
    ldd = { stdout = "ldd: error", stderr = "", code = 1 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    local error_message = assert(err)
    eq(error_message:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
  with_system_probe({
    getconf = { stdout = "", stderr = "getconf: Unrecognized variable", code = 2 },
    ldd = { stdout = "ldd version unavailable", stderr = "", code = 0 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    local error_message = assert(err)
    eq(error_message:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
end

T["resolve_target falls back to glibc ldd when getconf is missing"] = function()
  with_system_probe({
    getconf = { fail = true },
    ldd = { stdout = "ldd (GNU libc) 2.39", stderr = "", code = 0 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, "linux-x64")
    eq(err, nil)
  end)
end

T["resolve_target falls back to glibc ldd when getconf fails"] = function()
  with_system_probe({
    getconf = { stdout = "", stderr = "getconf: Unrecognized variable", code = 2 },
    ldd = { stdout = "ldd (GLIBC) 2.39", stderr = "", code = 0 },
  }, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "aarch64" })
    eq(target, "linux-arm64")
    eq(err, nil)
  end)
end

T["get_entrypoint resolves a deterministic cache hit"] = function()
  local target = fixture_target()
  local root = new_cache(target)
  local expected = create_hit(root, target)
  local entry, err = installer.get_entrypoint(target)
  eq(entry, expected)
  eq(err, nil)
end

T["cache hit avoids reserve and publication"] = function()
  local target = fixture_target()
  local root = new_cache(target)
  local expected = create_hit(root, target)
  local original_reserve = store.reserve
  local original_publish = store.publish
  store.reserve = function(_, _)
    error("reserve must not run for cache hit")
  end
  store.publish = function(_, _, _)
    error("publish must not run for cache hit")
  end
  local restore = process_stub.start()
  if target == "win32-x64" then
    process_stub.responses = { powershell = successful_acl_responses(3) }
  end
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  if target == "win32-x64" then
    complete_pending(function()
      return result
    end, 3)
  else
    vim.wait(500, function()
      return result ~= nil
    end)
  end
  restore()
  store.reserve = original_reserve
  store.publish = original_publish
  eq(result, { nil, expected })
end

T["installs from a completely absent cache root"] = function()
  local root, result = run_install(fixture_target(), nil, nil, nil, nil, true)
  eq(result[1], nil)
  eq(vim.fn.isdirectory(root), 1)
end

T["windows prepares cache version and target parents"] = function()
  local target = "win32-x64"
  local root = new_cache(target)
  local original_uname = vim.loop.os_uname
  vim.loop.os_uname = function()
    return { sysname = "Windows_NT", machine = "AMD64" }
  end
  local restore = process_stub.start()
  process_stub.responses = successful_plan(target)
  process_stub.on_complete = successful_completion(target)
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  complete_pending(function()
    return result
  end, 16)
  restore()
  vim.loop.os_uname = original_uname
  local parent = process_stub.calls[1][4]
  local version_path = vim.fs.joinpath(root, release.version)
  local target_path = vim.fs.joinpath(version_path, target)
  eq(parent:find("generations", 1, true), nil)
  eq(parent:find("'" .. root .. "'", 1, true) ~= nil, true)
  eq(parent:find("'" .. version_path .. "'", 1, true) ~= nil, true)
  eq(parent:find("'" .. target_path .. "'", 1, true) ~= nil, true)
  eq(process_stub.calls[1][1], "powershell")
  eq(process_stub.calls[2][1], "powershell")
  eq(process_stub.calls[2][4]:find("'" .. target_path .. "'", 1, true) ~= nil, true)
  eq(process_stub.calls[2][4]:find("generations", 1, true), nil)
  eq(process_stub.calls[3][1], "curl")
  eq(result[1], nil)
end

T["windows falls back to pwsh for ACL download hash and extraction"] = function()
  local target = "win32-x64"
  local responses = successful_acl_responses(8)
  responses[4].stdout = release.assets[target].sha256
  local root, result = run_install(target, {
    powershell = { false, false, false, false, false, false, false, false },
    pwsh = responses,
    curl = { false },
    wget = { false },
    sha256sum = { false },
    shasum = { false },
    openssl = { false },
    unzip = { false },
  }, fallback_completion(target), nil, "Windows_NT")
  eq(result[1], nil)
  eq(
    result[2],
    vim.fs.joinpath(root, release.version, target, release.assets[target].sha256, release.assets[target].entrypoint)
  )
  eq(vim.fn.readfile(result[2]), { "server" })
  local count = 0
  for i, command in ipairs(process_stub.calls) do
    if command[1] == "pwsh" then
      count = count + 1
      eq(process_stub.calls[i - 1][1], "powershell")
      eq(vim.list_slice(command, 2), vim.list_slice(process_stub.calls[i - 1], 2))
    end
  end
  eq(count, 8)
end

T["windows reuses a validated cache through pwsh"] = function()
  local expected
  local _, result = run_install(
    "win32-x64",
    {
      powershell = { false, false, false },
      pwsh = successful_acl_responses(3),
    },
    nil,
    function(root)
      expected = create_hit(root, "win32-x64")
    end,
    "Windows_NT"
  )
  eq(result, { nil, expected })
  eq(#process_stub.calls, 6)
  for i = 1, 6, 2 do
    eq(process_stub.calls[i][1], "powershell")
    eq(process_stub.calls[i + 1][1], "pwsh")
  end
end

T["windows reports both unavailable PowerShell executables"] = function()
  local _, result = run_install("win32-x64", {
    powershell = { false },
    pwsh = { false },
  }, nil, nil, "Windows_NT")
  eq(result[2], nil)
  eq(result[1]:find("powershell unavailable", 1, true) ~= nil, true)
  eq(result[1]:find("pwsh unavailable", 1, true) ~= nil, true)
  eq(#process_stub.calls, 2)
end

T["windows does not retry a failed ACL script through another runtime"] = function()
  local _, result = run_install("win32-x64", {
    powershell = { { code = 1, stdout = "", stderr = "DACL is not protected" } },
  }, nil, nil, "Windows_NT")
  eq(result[2], nil)
  eq(result[1]:find("DACL is not protected", 1, true) ~= nil, true)
  eq(#process_stub.calls, 1)
end

T["windows pwsh ACL failures stop before downloading"] = function()
  local _, result = run_install("win32-x64", {
    powershell = { false },
    pwsh = { { code = 1, stdout = "", stderr = "DACL is not protected" } },
  }, nil, nil, "Windows_NT")
  eq(result[2], nil)
  eq(result[1]:find("pwsh failed: DACL is not protected", 1, true) ~= nil, true)
  eq(#process_stub.calls, 2)
end

T["windows PowerShell module environments"] = MiniTest.new_set({ parametrize = { { false }, { true } } })
T["windows PowerShell module environments"]["do not inherit module paths"] = function(use_pwsh)
  local inherited = vim.env.PSModulePath
  local marker = vim.env.COPILOT_ENV_TEST
  vim.env.PSModulePath = "incompatible PowerShell 7 modules"
  vim.env.COPILOT_ENV_TEST = "preserve child environment"
  local plan = successful_plan("win32-x64")
  if use_pwsh then
    plan.powershell = { false, false, false, false, false }
  end
  local _, result = run_install("win32-x64", plan, nil, nil, "Windows_NT")
  local unchanged = vim.env.PSModulePath
  vim.env.PSModulePath = inherited
  vim.env.COPILOT_ENV_TEST = marker
  eq(result[1], nil)
  eq(unchanged, "incompatible PowerShell 7 modules")
  local child = vim
    .system({
      vim.v.progpath,
      "--headless",
      "--clean",
      "-u",
      "NONE",
      "-c",
      [[lua io.stdout:write(vim.json.encode({has_modules = vim.env.PSModulePath ~= nil, marker = vim.env.COPILOT_ENV_TEST}))]],
      "-c",
      "qa!",
    }, process_stub.options[use_pwsh and 2 or 1])
    :wait()
  eq(child.code, 0)
  eq(vim.json.decode(child.stdout), { has_modules = false, marker = "preserve child environment" })
  for i, command in ipairs(process_stub.calls) do
    if command[1] == "powershell" or command[1] == "pwsh" then
      eq(process_stub.options[i].clear_env, true)
    else
      eq(process_stub.options[i].env, nil)
      eq(process_stub.options[i].clear_env, nil)
    end
  end
end

T["Unix PowerShell fallbacks keep their module environment"] = function()
  if original_os_uname().sysname == "Windows_NT" then
    return
  end
  local _, result = run_install("linux-x64", {
    curl = { false },
    wget = { false },
    powershell = { { code = 1, stdout = "", stderr = "download failed" } },
  }, nil, nil, "Linux")
  eq(result[1]:find("download failed", 1, true) ~= nil, true)
  eq(process_stub.calls[3][1], "powershell")
  eq(process_stub.options[3].env, nil)
end

T["windows parent ACL writes do not request audit permissions"] = function()
  local _, result = run_install("win32-x64", nil, nil, nil, "Windows_NT")
  eq(result[1], nil)
  local script = process_stub.calls[1][4]
  eq(script:find("Set-Acl", 1, true), nil)
  eq(script:find("[System.IO.Directory]::SetAccessControl($p,$d)", 1, true) ~= nil, true)
  -- Each persist clears the descriptor's modification flags, so reusing it
  -- would leave the second and third existing directories unhardened.
  local loop = assert(script:find("foreach($p in $paths)", 1, true))
  local descriptor = assert(script:find("New-Object System.Security.AccessControl.DirectorySecurity", 1, true))
  eq(loop < descriptor, true)
  eq(script:find("[System.IO.Directory]::CreateDirectory($p,$d)", 1, true) ~= nil, true)
end

T["windows only normalizes ownership of newly created staging files"] = function()
  local _, result = run_install("win32-x64", nil, nil, nil, "Windows_NT")
  eq(result[1], nil)
  local staging = process_stub.calls[2][4]
  eq(staging:find("SetOwner($s)", 1, true) ~= nil, true)
  eq(staging:find("SetAccessRuleProtection", 1, true), nil)
  eq(staging:find("AddAccessRule", 1, true), nil)
  local files = process_stub.calls[6][4]
  eq(files:find("SetOwner($s)", 1, true) ~= nil, true)
  eq(files:find("[System.IO.File]::SetAccessControl", 1, true) ~= nil, true)
  eq(files:find("install.json", 1, true) ~= nil, true)
  for i = 7, 8 do
    eq(process_stub.calls[i][4]:find("SetOwner", 1, true), nil)
  end
end

T["windows file owner failure stops before publication"] = function()
  local responses = successful_acl_responses(2)
  responses[3] = { code = 1, stdout = "", stderr = "file owner normalization failed" }
  local plan = successful_plan("win32-x64")
  plan.powershell = responses
  local root, result = run_install("win32-x64", plan, nil, nil, "Windows_NT")
  eq(result[1]:find("file owner normalization failed", 1, true) ~= nil, true)
  eq(result[2], nil)
  eq(store.resolve(options(root, "win32-x64")), nil)
  eq(#process_stub.calls, 6)
end

T["windows rejects an untrusted racing winner without repairing it"] = function()
  local root, winner
  local completion = successful_completion("win32-x64")
  local responses = successful_acl_responses(3)
  responses[4] = { code = 1, stdout = "", stderr = "winner owner mismatch" }
  local plan = successful_plan("win32-x64")
  plan.powershell = responses
  local _, result = run_install("win32-x64", plan, function(command)
    completion(command)
    if command[1] == "unzip" then
      winner = create_hit(root, "win32-x64")
    end
  end, function(cache)
    root = cache
  end, "Windows_NT")
  eq(result[1]:find("winner owner mismatch", 1, true) ~= nil, true)
  eq(result[2], nil)
  eq(vim.fn.filereadable(winner), 1)
  eq(#process_stub.calls, 7)
  eq(process_stub.calls[7][4]:find("SetOwner", 1, true), nil)
end

T["windows ignores late file preparation after the deadline"] = function()
  local target = "win32-x64"
  local root = new_cache(target)
  vim.loop.os_uname = function()
    return { sysname = "Windows_NT", machine = "AMD64" }
  end
  installer._operation_deadline = 100
  process_stub.start()
  process_stub.responses = successful_plan(target)
  process_stub.on_complete = successful_completion(target)
  local result, callbacks = nil, 0
  installer.ensure("binary", function(err, path)
    result, callbacks = { err, path }, callbacks + 1
  end)
  for _ = 1, 5 do
    eq(
      vim.wait(1000, function()
        return #process_stub.pending > 0
      end),
      true
    )
    process_stub.complete_next()
  end
  eq(
    vim.wait(1000, function()
      return #process_stub.calls == 6
    end),
    true
  )
  eq(
    vim.wait(1000, function()
      return result ~= nil
    end),
    true
  )
  assert(result)
  eq(result[1]:find("timed out", 1, true) ~= nil, true)
  eq(result[2], nil)
  eq(process_stub.killed, 1)
  process_stub.complete_next()
  local drained = false
  vim.schedule(function()
    drained = true
  end)
  vim.wait(1000, function()
    return drained
  end)
  eq(callbacks, 1)
  eq(#process_stub.calls, 6)
  eq(store.resolve(options(root, target)), nil)
end

T["windows ACL verification commands report the failed contract"] = function()
  local _, result = run_install("win32-x64", nil, nil, nil, "Windows_NT")
  eq(result[1], nil)
  for _, command in ipairs(process_stub.calls) do
    if command[1] == "powershell" then
      local script = command[4]
      eq(script:find("exit 1", 1, true), nil)
      eq(script:find("owner mismatch", 1, true) ~= nil, true)
      eq(script:find("ACE count", 1, true) ~= nil, true)
      eq(script:find(".Sddl", 1, true) ~= nil, true)
    end
  end
end

T["windows validates cache ACLs before reusing an install"] = function()
  local target = "win32-x64"
  local root = new_cache(target)
  local expected = create_hit(root, target)
  local original_uname = vim.loop.os_uname
  vim.loop.os_uname = function()
    return { sysname = "Windows_NT", machine = "AMD64" }
  end
  local restore = process_stub.start()
  process_stub.responses = {
    powershell = {
      { code = 0, stdout = "", stderr = "" },
      { code = 0, stdout = "", stderr = "" },
      { code = 0, stdout = "", stderr = "" },
    },
  }
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  for _ = 1, 3 do
    vim.wait(1000, function()
      return result ~= nil or #process_stub.pending > 0
    end)
    if result then
      break
    end
    process_stub.complete_next()
  end
  vim.wait(1000, function()
    return result ~= nil
  end)
  restore()
  vim.loop.os_uname = original_uname
  eq(result, { nil, expected })
  eq(#process_stub.calls, 3)
  for _, command in ipairs(process_stub.calls) do
    eq(command[1], "powershell")
  end
  local file_check = process_stub.calls[3][4]
  local target_path = vim.fs.joinpath(root, release.version, target)
  eq(file_check:find("$parent=Get-Acl -LiteralPath '" .. target_path .. "';", 1, true) ~= nil, true)
end

T["windows rejects a cache hit when ACL validation fails"] = function()
  local target = "win32-x64"
  local root = new_cache(target)
  create_hit(root, target)
  local original_uname = vim.loop.os_uname
  vim.loop.os_uname = function()
    return { sysname = "Windows_NT", machine = "AMD64" }
  end
  local restore = process_stub.start()
  process_stub.responses = {
    powershell = {
      { code = 0, stdout = "", stderr = "" },
      { code = 1, stdout = "", stderr = "untrusted cache" },
    },
  }
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  for _ = 1, 2 do
    vim.wait(1000, function()
      return result ~= nil or #process_stub.pending > 0
    end)
    if result then
      break
    end
    process_stub.complete_next()
  end
  vim.wait(1000, function()
    return result ~= nil
  end)
  restore()
  vim.loop.os_uname = original_uname
  eq(result[1]:find("cache privacy verification failed", 1, true) ~= nil, true)
  eq(result[2], nil)
  eq(#process_stub.calls, 2)
end

T["windows parent and staging ACL failures stop in order"] = function()
  local _, parent_failure = run_install(
    "win32-x64",
    { powershell = { { code = 1, stdout = "", stderr = "parent ACL failed" } } },
    nil,
    nil,
    "Windows_NT"
  )
  eq(parent_failure[1] ~= nil, true)
  eq(#process_stub.calls, 1)

  local root, staging_failure = run_install("win32-x64", {
    powershell = {
      { code = 0, stdout = "", stderr = "" },
      { code = 1, stdout = "", stderr = "staging ACL failed" },
    },
  }, nil, nil, "Windows_NT")
  eq(staging_failure[1] ~= nil, true)
  eq(#process_stub.calls, 2)
  eq(process_stub.calls[1][1], "powershell")
  eq(process_stub.calls[2][1], "powershell")
  eq(vim.fn.isdirectory(vim.fs.joinpath(root, release.version, "win32-x64")), 1)
end

T["rejects download and publication phase failures"] = function()
  local target = fixture_target()
  local download_powershell = target == "win32-x64" and successful_acl_responses(2) or {}
  download_powershell[#download_powershell + 1] = false
  local _, result =
    run_install(target, { curl = { false }, wget = { false }, powershell = download_powershell, pwsh = { false } })
  eq(assert(result[1]):find("download failed at", 1, true) ~= nil, true)
  local download_command = process_stub.calls[#process_stub.calls]
  eq(download_command[1], target == "win32-x64" and "pwsh" or "powershell")
  eq((download_command[4] or ""):find("Invoke-WebRequest", 1, true) ~= nil, true)
  local extraction_powershell = { { code = 1, stdout = "", stderr = "extract failed" } }
  if target == "win32-x64" then
    extraction_powershell = {
      { code = 0, stdout = "", stderr = "" },
      { code = 0, stdout = "", stderr = "" },
      extraction_powershell[1],
    }
  end
  local extraction_root, extraction = run_install(target, {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets[target].sha256, stderr = "" } },
    unzip = { { code = 1, stdout = "", stderr = "extract failed" } },
    powershell = extraction_powershell,
  }, successful_completion(target))
  local extraction_error = assert(extraction[1])
  eq(extraction_error:find("extract failed at", 1, true) ~= nil, true)
  eq(extraction_error:find("powershell failed: extract failed", 1, true) ~= nil, true)
  local last_command = process_stub.calls[#process_stub.calls]
  eq(last_command[1], "powershell")
  eq((last_command[4] or ""):find("Expand%-Archive") ~= nil, true)
  eq(store.resolve(options(extraction_root, target)), nil)
end

T["rejects a wrong checksum before extraction"] = function()
  local target = fixture_target()
  local _, result = run_install(target, {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = string.rep("b", 64), stderr = "" } },
  })
  eq(result[1] ~= nil, true)
  local extracted = false
  for _, command in ipairs(process_stub.calls) do
    extracted = extracted
      or command[1] == "unzip"
      or (command[1] == "powershell" and (command[4] or ""):find("Expand%-Archive") ~= nil)
  end
  eq(extracted, false)
end

T["falls back across download checksum and extraction tools"] = function()
  local target = fixture_target()
  local _, wget_result = run_install(target, {
    curl = { false },
    wget = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets[target].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(wget_result[1], nil)

  local _, powershell_result = run_install(target, {
    curl = { false },
    wget = { false },
    powershell = { { code = 0, stdout = "", stderr = "" }, { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets[target].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  }, fallback_completion(target))
  eq(powershell_result[1], nil)

  local _, shasum_result = run_install(target, {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { false },
    shasum = { { code = 0, stdout = release.assets[target].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(shasum_result[1], nil)

  local _, openssl_result = run_install(target, {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { false },
    shasum = { false },
    openssl = { { code = 0, stdout = "SHA2-256 (archive)= " .. release.assets[target].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(openssl_result[1], nil)

  local powershell_hash_responses = { { code = 0, stdout = release.assets[target].sha256, stderr = "" } }
  if target == "win32-x64" then
    powershell_hash_responses = {
      { code = 0, stdout = "", stderr = "" },
      { code = 0, stdout = "", stderr = "" },
      powershell_hash_responses[1],
    }
  end
  local _, powershell_hash_result = run_install(target, {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { false },
    shasum = { false },
    openssl = { false },
    powershell = powershell_hash_responses,
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(powershell_hash_result[1], nil)

  local _, extraction_result = run_install(target, {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets[target].sha256, stderr = "" } },
    unzip = { false },
    powershell = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  }, fallback_completion(target))
  eq(extraction_result[1], nil)
end

T["rejects chmod failure"] = function()
  local root, result = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 1, stdout = "", stderr = "chmod failed" } },
  })
  eq(result[1] ~= nil, true)
  eq(store.resolve(options(root, "linux-x64")), nil)
end

T["wrong publication path is rejected"] = function()
  local original_publish = store.publish
  store.publish = function(_, _, callback)
    callback(nil, "/wrong/path", "published")
  end
  local _, result = run_install(fixture_target())
  store.publish = original_publish
  local error_message = assert(result[1])
  eq(error_message:find("unexpected entrypoint", 1, true) ~= nil, true)
end

T["publication timeout only recovers a POSIX current install"] = function()
  local original_publish = store.publish
  local late_callback
  store.publish = function(reservation, opts, callback)
    original_publish(reservation, opts, function(err, path, outcome)
      late_callback = function()
        callback(err, path, outcome)
      end
    end)
    return nil
  end
  installer._operation_deadline = 10
  local callback_count = 0
  local target = fixture_target()
  local root = new_cache(target)
  local restore = process_stub.start()
  process_stub.responses = successful_plan(target)
  process_stub.on_complete = successful_completion(target)
  local result
  installer.ensure("binary", function(err, path)
    callback_count = callback_count + 1
    result = { err, path }
  end)
  for _ = 1, 8 do
    vim.wait(1000, function()
      return result ~= nil or #process_stub.pending > 0
    end)
    if result then
      break
    end
    process_stub.complete_next()
  end
  vim.wait(1000, function()
    return result ~= nil
  end)
  restore()
  store.publish = original_publish
  if target == "win32-x64" then
    eq(result[1]:find("timed out", 1, true) ~= nil, true)
    eq(result[2], nil)
  else
    eq(result[1], nil)
    eq(result[2]:find(release.assets[target].sha256, 1, true) ~= nil, true)
  end
  eq(callback_count, 1)
  eq(late_callback ~= nil, true)
  late_callback()
  vim.wait(100)
  eq(callback_count, 1)
  eq(vim.fn.isdirectory(root), 1)
end

T["failed unpublished staging is discarded"] = function()
  local original_publish = store.publish
  store.publish = function(_, _, callback)
    callback("publication failed", nil, "unmarked")
  end
  local root, result = run_install(fixture_target())
  store.publish = original_publish
  eq(result[1] ~= nil, true)
  local target = vim.fs.joinpath(root, release.version, fixture_target())
  local staging = 0
  for name, kind in vim.fs.dir(target) do
    if kind == "directory" and name:match("^%.staging%-") then
      staging = staging + 1
    end
  end
  eq(staging, 0)
end

T["reuses a concurrent deterministic winner"] = function()
  local original_publish = store.publish
  store.publish = function(reservation, opts, _)
    local final = reservation.final_path
    vim.fn.mkdir(final, "p", "448")
    local entry = vim.fs.joinpath(final, opts.entrypoint)
    vim.fn.writefile({ "winner" }, entry)
    vim.fn.setfperm(entry, "rwx------")
    vim.fn.writefile(
      { vim.json.encode({ version = opts.version, target = opts.target, sha256 = opts.sha256 }) },
      vim.fs.joinpath(final, "install.json")
    )
    vim.fn.setfperm(vim.fs.joinpath(final, "install.json"), "rw-------")
    return { committed = true, outcome = "published", path = entry }
  end
  local target = fixture_target()
  local _, result = run_install(target)
  store.publish = original_publish
  eq(result[1], nil)
  eq(result[2]:find(release.assets[target].sha256, 1, true) ~= nil, true)
end

T["cleans stale staging and archives before retry"] = function()
  local old_staging = ".staging-old"
  local old_archive = ".copilot-lsp-archive-1-2.zip"
  local target = fixture_target()
  local root, result = run_install(target, nil, nil, function(cache)
    local target_path = vim.fs.joinpath(cache, release.version, target)
    vim.fn.mkdir(vim.fs.joinpath(target_path, old_staging), "p")
    vim.fn.writefile({ "old" }, vim.fs.joinpath(cache, old_archive))
    vim.uv.fs_utime(vim.fs.joinpath(target_path, old_staging), os.time() - 90000, os.time() - 90000)
    vim.uv.fs_utime(vim.fs.joinpath(cache, old_archive), os.time() - 90000, os.time() - 90000)
  end)
  eq(result[1], nil)
  eq(vim.fn.isdirectory(vim.fs.joinpath(root, release.version, target, old_staging)), 0)
  eq(vim.fn.filereadable(vim.fs.joinpath(root, old_archive)), 0)
end

T["preserves POSIX private staging and final permissions"] = function()
  local _, result = run_install(fixture_target())
  eq(result[1], nil)
  if vim.loop.os_uname().sysname ~= "Windows_NT" then
    eq(vim.fn.getfperm(vim.fs.dirname(result[2])), "rwx------")
    eq(vim.fn.getfperm(vim.fs.joinpath(vim.fs.dirname(result[2]), "install.json")), "rw-------")
  end
end

T["callbacks remain deduplicated"] = MiniTest.new_set({ parametrize = { { false }, { true } } })

T["callbacks remain deduplicated"]["notifies both callers"] = function(force_windows)
  if force_windows then
    vim.loop.os_uname = function()
      return { sysname = "Windows_NT", machine = "AMD64" }
    end
  end
  local target = fixture_target()
  new_cache(target)
  local restore = process_stub.start()
  process_stub.responses = successful_plan(target)
  process_stub.on_complete = successful_completion(target)
  local results = {}
  installer.ensure("binary", function(err, path)
    results[#results + 1] = { err, path }
  end)
  installer.ensure("binary", function(err, path)
    results[#results + 1] = { err, path }
  end)
  complete_pending(function()
    return #results == 2 and results or nil
  end, 16)
  restore()
  eq(#results, 2)
  eq(results[1][1], nil)
  eq(results[1][2], results[2][2])
end

T["publishes success callback exactly once"] = function()
  local target = fixture_target()
  local root = new_cache(target)
  local restore = process_stub.start()
  process_stub.responses = successful_plan(target)
  process_stub.on_complete = successful_completion(target)
  local count = 0
  local result
  installer.ensure("binary", function(err, path)
    count = count + 1
    result = { err, path }
  end)
  for _ = 1, 8 do
    vim.wait(1000, function()
      return result ~= nil or #process_stub.pending > 0
    end)
    if result then
      break
    end
    process_stub.complete_next()
  end
  vim.wait(500, function()
    return result ~= nil
  end)
  eq(count, 1)
  vim.wait(50)
  eq(count, 1)
  eq(store.resolve(options(root, target)), result[2])
  restore()
end

T["kills an active process at the operation deadline"] = function()
  new_cache(fixture_target())
  installer._operation_deadline = 10
  local restore = process_stub.start()
  process_stub.responses = successful_plan(fixture_target())
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  vim.wait(500, function()
    return result ~= nil
  end)
  local error_message = assert(result[1])
  eq(error_message:find("timed out", 1, true) ~= nil, true)
  eq(process_stub.killed, 1)
  restore()
end

T["notification failure does not fail installation"] = function()
  local saved_notify = logger.notify
  logger.notify = function()
    error("notification failed")
  end
  local _, result = run_install(fixture_target())
  logger.notify = saved_notify
  eq(result[1], nil)
end

T["rejects missing staged entrypoint and leaves no install"] = function()
  local target = fixture_target()
  local root, result = run_install(target, nil, function(command)
    successful_completion(target)(command)
    if command[1] == "unzip" then
      vim.fn.delete(vim.fs.joinpath(command[5], release.assets[target].entrypoint))
    end
  end)
  local error_message = assert(result[1])
  eq(error_message:find(extraction_error_fragment(target), 1, true) ~= nil, true)
  eq(store.resolve(options(root, target)), nil)
end

T["rejects symlinked staged entrypoint"] = function()
  local target = fixture_target()
  local outside
  local root, result = run_install(target, nil, function(command)
    successful_completion(target)(command)
    if command[1] == "unzip" then
      vim.fn.writefile({ "outside" }, outside)
      vim.fn.delete(vim.fs.joinpath(command[5], release.assets[target].entrypoint))
      symlink(outside, vim.fs.joinpath(command[5], release.assets[target].entrypoint))
    end
  end, function(cache)
    outside = vim.fs.joinpath(cache, "outside")
  end)
  local error_message = assert(result[1])
  eq(error_message:find(extraction_error_fragment(target), 1, true) ~= nil, true)
  eq(store.resolve(options(root, target)), nil)
end

T["rejects directory staged entrypoint"] = function()
  local target = fixture_target()
  local root, result = run_install(target, nil, function(command)
    successful_completion(target)(command)
    if command[1] == "unzip" then
      local entry = vim.fs.joinpath(command[5], release.assets[target].entrypoint)
      vim.fn.delete(entry)
      vim.fn.mkdir(entry, "p")
    end
  end)
  local error_message = assert(result[1])
  eq(error_message:find(extraction_error_fragment(target), 1, true) ~= nil, true)
  eq(store.resolve(options(root, target)), nil)
end

T["does not chmod JavaScript targets"] = function()
  local root, result = run_install("js", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets.js.sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(result[1], nil)
  local chmod_calls = 0
  for _, command in ipairs(process_stub.calls) do
    if command[1] == "chmod" then
      chmod_calls = chmod_calls + 1
    end
  end
  eq(chmod_calls, 0)
  eq(store.resolve(options(root, "js")), result[2])
end

T["ignores duplicate publication callbacks"] = function()
  local original_publish = store.publish
  store.publish = function(reservation, opts, callback)
    local receipt = assert(original_publish(reservation, opts, function() end))
    local path = assert(receipt.path)
    callback(nil, path, "published")
    callback("late publication", nil, "unmarked")
    return receipt
  end
  local _, result = run_install(fixture_target())
  store.publish = original_publish
  eq(result[1], nil)
  eq(result[2] ~= nil, true)
end

return T
