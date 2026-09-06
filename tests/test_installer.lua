local eq = MiniTest.expect.equality
local installer = require("copilot.lsp.installer")
local release = require("copilot.lsp.release")
local store = require("copilot.lsp.store")
local logger = require("copilot.logger")
local process_stub = require("tests.stubs.installer")

local original_resolve_target = installer.resolve_target
local current_root
local T = MiniTest.new_set({
  hooks = {
    post_case = function()
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

local function new_cache(target, absent)
  local root = vim.fn.tempname()
  if not absent then
    vim.fn.mkdir(vim.fs.joinpath(root, release.version, target), "p")
  end
  installer.cache_root_override = root
  installer.resolve_target = function()
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
      local fixture = vim.fs.joinpath(vim.fs.dirname(command[9]), release.assets[target].entrypoint)
      vim.fn.writefile({ "archive" }, fixture)
      vim.fn.delete(command[9])
      vim.fn.system({ "zip", "-q", "-j", command[9], fixture })
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
    elseif command[1] == "powershell" and (command[4] or ""):find("Expand%-Archive") then
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
  installer.ensure("binary", function(err, path)
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
  if original_uname then
    vim.loop.os_uname = original_uname
  end
  return root, result
end

local function with_ldd_probe(stdout, stderr, code, fail, callback)
  local original_system = vim.system
  vim.system = function()
    if fail then
      error("ldd failed to start")
    end
    return {
      wait = function()
        return { stdout = stdout, stderr = stderr, code = code }
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
  local target = "linux-x64"
  local root = new_cache(target)
  local expected = create_hit(root, target)
  local restore = process_stub.start()
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  vim.wait(500, function()
    return result ~= nil
  end)
  restore()
  eq(result, { nil, expected })
  eq(process_stub.calls, {})
end

T["downloads and publishes at the deterministic path"] = function()
  local root, result = run_install("linux-x64")
  eq(result[1], nil)
  eq(
    result[2],
    vim.fs.joinpath(
      root,
      release.version,
      "linux-x64",
      release.assets["linux-x64"].sha256,
      release.assets["linux-x64"].entrypoint
    )
  )
end

T["release metadata remains pinned"] = function()
  eq(release.version, "1.534.0")
  eq(release.assets["linux-x64"].filename, "copilot-language-server-linux-x64-1.534.0.zip")
  eq(release.assets["linux-x64"].entrypoint, "copilot-language-server")
  eq(release.assets.js.entrypoint, "language-server.js")
  eq(vim.tbl_count(release.assets), 7)
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
  with_ldd_probe("ldd (GNU libc) 2.39", "", 0, false, function()
    eq(installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" }), "linux-x64")
  end)
  with_ldd_probe("musl libc", "", 0, false, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    eq(err:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
  with_ldd_probe(nil, nil, nil, true, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    eq(err:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
  with_ldd_probe("ldd: error", "", 1, false, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    eq(err:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
  with_ldd_probe("ldd version unavailable", "", 0, false, function()
    local target, err = installer.resolve_target("binary", { sysname = "Linux", machine = "x86_64" })
    eq(target, nil)
    eq(err:find('server.type = "nodejs"', 1, true) ~= nil, true)
  end)
end

T["get_entrypoint resolves a deterministic cache hit"] = function()
  local root = new_cache("linux-x64")
  local expected = create_hit(root, "linux-x64")
  local entry, err = installer.get_entrypoint("linux-x64")
  eq(entry, expected)
  eq(err, nil)
end

T["cache hit avoids reserve and publication"] = function()
  local root = new_cache("linux-x64")
  local expected = create_hit(root, "linux-x64")
  local original_reserve = store.reserve
  local original_publish = store.publish
  store.reserve = function()
    error("reserve must not run for cache hit")
  end
  store.publish = function()
    error("publish must not run for cache hit")
  end
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  vim.wait(500, function()
    return result ~= nil
  end)
  store.reserve = original_reserve
  store.publish = original_publish
  eq(result, { nil, expected })
end

T["installs from a completely absent cache root"] = function()
  local root, result = run_install("linux-x64", nil, nil, nil, nil, true)
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
  for _ = 1, 8 do
    vim.wait(1000, function()
      return result ~= nil or #process_stub.pending > 0
    end)
    if result then
      break
    end
    process_stub.complete_next()
  end
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
  local _, result = run_install("linux-x64", { curl = { false }, wget = { false }, powershell = { false } })
  eq(result[1] ~= nil, true)
  local extraction_root, extraction = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 1, stdout = "", stderr = "extract failed" } },
    powershell = { { code = 1, stdout = "", stderr = "extract failed" } },
  }, successful_completion("linux-x64"))
  eq(extraction[1] ~= nil, true)
  eq(store.resolve(options(extraction_root, "linux-x64")), nil)
end

T["rejects a wrong checksum before extraction"] = function()
  local _, result = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = string.rep("b", 64), stderr = "" } },
  })
  eq(result[1] ~= nil, true)
  eq(vim.tbl_get(process_stub.calls, 3, 1), nil)
end

T["falls back across download checksum and extraction tools"] = function()
  local _, wget_result = run_install("linux-x64", {
    curl = { false },
    wget = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(wget_result[1], nil)

  local _, powershell_result = run_install("linux-x64", {
    curl = { false },
    wget = { false },
    powershell = { { code = 0, stdout = "", stderr = "" }, { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  }, fallback_completion("linux-x64"))
  eq(powershell_result[1], nil)

  local _, shasum_result = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { false },
    shasum = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(shasum_result[1], nil)

  local _, openssl_result = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { false },
    shasum = { false },
    openssl = { { code = 0, stdout = "SHA2-256 (archive)= " .. release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(openssl_result[1], nil)

  local _, powershell_hash_result = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { false },
    shasum = { false },
    openssl = { false },
    powershell = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  })
  eq(powershell_hash_result[1], nil)

  local _, extraction_result = run_install("linux-x64", {
    curl = { { code = 0, stdout = "", stderr = "" } },
    sha256sum = { { code = 0, stdout = release.assets["linux-x64"].sha256, stderr = "" } },
    unzip = { false },
    powershell = { { code = 0, stdout = "", stderr = "" } },
    chmod = { { code = 0, stdout = "", stderr = "" } },
  }, fallback_completion("linux-x64"))
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
  local _, result = run_install("linux-x64")
  store.publish = original_publish
  eq(result[1]:find("unexpected entrypoint", 1, true) ~= nil, true)
end

T["publication timeout recovers the deterministic current install"] = function()
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
  local root = new_cache("linux-x64")
  local restore = process_stub.start()
  process_stub.responses = successful_plan("linux-x64")
  process_stub.on_complete = successful_completion("linux-x64")
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
  eq(result[1], nil)
  eq(callback_count, 1)
  eq(late_callback ~= nil, true)
  late_callback()
  vim.wait(100)
  eq(callback_count, 1)
  eq(result[2]:find(release.assets["linux-x64"].sha256, 1, true) ~= nil, true)
  eq(vim.fn.isdirectory(root), 1)
end

T["failed unpublished staging is discarded"] = function()
  local original_publish = store.publish
  store.publish = function(_, _, callback)
    callback("publication failed", nil, "unmarked")
  end
  local root, result = run_install("linux-x64")
  store.publish = original_publish
  eq(result[1] ~= nil, true)
  local target = vim.fs.joinpath(root, release.version, "linux-x64")
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
  store.publish = function(reservation, opts)
    local final = reservation.final_path
    vim.fn.mkdir(final, "p", 448)
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
  local _, result = run_install("linux-x64")
  store.publish = original_publish
  eq(result[1], nil)
  eq(result[2]:find(release.assets["linux-x64"].sha256, 1, true) ~= nil, true)
end

T["cleans stale staging and archives before retry"] = function()
  local old_staging = ".staging-old"
  local old_archive = ".copilot-lsp-archive-1-2.zip"
  local root, result = run_install("linux-x64", nil, nil, function(cache)
    local target = vim.fs.joinpath(cache, release.version, "linux-x64")
    vim.fn.mkdir(vim.fs.joinpath(target, old_staging), "p")
    vim.fn.writefile({ "old" }, vim.fs.joinpath(cache, old_archive))
    vim.uv.fs_utime(vim.fs.joinpath(target, old_staging), os.time() - 90000, os.time() - 90000)
    vim.uv.fs_utime(vim.fs.joinpath(cache, old_archive), os.time() - 90000, os.time() - 90000)
  end)
  eq(result[1], nil)
  eq(vim.fn.isdirectory(vim.fs.joinpath(root, release.version, "linux-x64", old_staging)), 0)
  eq(vim.fn.filereadable(vim.fs.joinpath(root, old_archive)), 0)
end

T["preserves POSIX private staging and final permissions"] = function()
  local root, result = run_install("linux-x64")
  eq(result[1], nil)
  if vim.loop.os_uname().sysname ~= "Windows_NT" then
    eq(vim.fn.getfperm(vim.fs.dirname(result[2])), "rwx------")
    eq(vim.fn.getfperm(vim.fs.joinpath(vim.fs.dirname(result[2]), "install.json")), "rw-------")
  end
end

T["callbacks remain deduplicated"] = function()
  local root = new_cache("linux-x64")
  local restore = process_stub.start()
  process_stub.responses = successful_plan("linux-x64")
  process_stub.on_complete = successful_completion("linux-x64")
  local results = {}
  installer.ensure("binary", function(err, path)
    results[#results + 1] = { err, path }
  end)
  installer.ensure("binary", function(err, path)
    results[#results + 1] = { err, path }
  end)
  for _ = 1, 8 do
    vim.wait(1000, function()
      return #results == 2 or #process_stub.pending > 0
    end)
    if #results == 2 then
      break
    end
    process_stub.complete_next()
  end
  restore()
  eq(#results, 2)
  eq(results[1][1], nil)
  eq(results[1][2], results[2][2])
end

T["publishes success callback exactly once"] = function()
  local root = new_cache("linux-x64")
  local restore = process_stub.start()
  process_stub.responses = successful_plan("linux-x64")
  process_stub.on_complete = successful_completion("linux-x64")
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
  eq(store.resolve(options(root, "linux-x64")), result[2])
  restore()
end

T["kills an active process at the operation deadline"] = function()
  new_cache("linux-x64")
  installer._operation_deadline = 10
  local restore = process_stub.start()
  process_stub.responses = successful_plan("linux-x64")
  local result
  installer.ensure("binary", function(err, path)
    result = { err, path }
  end)
  vim.wait(500, function()
    return result ~= nil
  end)
  eq(result[1]:find("timed out", 1, true) ~= nil, true)
  eq(process_stub.killed, 1)
  restore()
end

T["notification failure does not fail installation"] = function()
  local original_notify = logger.notify
  logger.notify = function()
    error("notification failed")
  end
  local _, result = run_install("linux-x64")
  logger.notify = original_notify
  eq(result[1], nil)
end

T["rejects missing staged entrypoint and leaves no install"] = function()
  local root, result = run_install("linux-x64", nil, function(command)
    successful_completion("linux-x64")(command)
    if command[1] == "unzip" then
      vim.fn.delete(vim.fs.joinpath(command[5], release.assets["linux-x64"].entrypoint))
    end
  end)
  eq(result[1]:find("regular file", 1, true) ~= nil, true)
  eq(store.resolve(options(root, "linux-x64")), nil)
end

T["rejects symlinked staged entrypoint"] = function()
  local outside
  local root, result = run_install("linux-x64", nil, function(command)
    successful_completion("linux-x64")(command)
    if command[1] == "unzip" then
      vim.fn.writefile({ "outside" }, outside)
      vim.fn.delete(vim.fs.joinpath(command[5], release.assets["linux-x64"].entrypoint))
      vim.uv.fs_symlink(outside, vim.fs.joinpath(command[5], release.assets["linux-x64"].entrypoint))
    end
  end, function(cache)
    outside = vim.fs.joinpath(cache, "outside")
  end)
  eq(result[1]:find("regular file", 1, true) ~= nil, true)
  eq(store.resolve(options(root, "linux-x64")), nil)
end

T["rejects directory staged entrypoint"] = function()
  local root, result = run_install("linux-x64", nil, function(command)
    successful_completion("linux-x64")(command)
    if command[1] == "unzip" then
      local entry = vim.fs.joinpath(command[5], release.assets["linux-x64"].entrypoint)
      vim.fn.delete(entry)
      vim.fn.mkdir(entry, "p")
    end
  end)
  eq(result[1]:find("regular file", 1, true) ~= nil, true)
  eq(store.resolve(options(root, "linux-x64")), nil)
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
    local receipt = original_publish(reservation, opts, function() end)
    callback(nil, receipt.path, "published")
    callback("late publication", nil, "unmarked")
    return receipt
  end
  local _, result = run_install("linux-x64")
  store.publish = original_publish
  eq(result[1], nil)
  eq(result[2] ~= nil, true)
end

return T
