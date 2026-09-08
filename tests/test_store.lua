local eq = MiniTest.expect.equality
local store = require("copilot.lsp.store")

local base_filereadable = vim.fn.filereadable
local base_executable = vim.fn.executable
local base_rm = vim.fs.rm
local base_rename = vim.uv.fs_rename
local T = MiniTest.new_set({
  hooks = {
    post_case = function()
      vim.fn.filereadable = base_filereadable
      vim.fn.executable = base_executable
      vim.fs.rm = base_rm
      vim.uv.fs_rename = base_rename
    end,
  },
})
local digest = string.rep("a", 64)

local function mkdir_private(path)
  vim.fn.mkdir(path, "p", "448")
end

local function root()
  local path = vim.fn.tempname()
  mkdir_private(path)
  return vim.uv.fs_realpath(path) or path
end

local function symlink(source, target)
  local ok, err = vim.uv.fs_symlink(source, target)
  eq(ok, true)
  eq(err, nil)
end

local function directory_symlink(source, target)
  local ok, err = vim.uv.fs_symlink(source, target, { dir = true })
  eq(ok, true)
  eq(err, nil)
end

local function mark_non_executable(path)
  if vim.loop.os_uname().sysname == "Windows_NT" then
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.fn.executable = function(value)
      if value == path then
        return 0
      end
      return base_executable(value)
    end
  else
    vim.fn.setfperm(path, "rw-------")
  end
end

local function fixture_target()
  return vim.loop.os_uname().sysname == "Windows_NT" and "win32-x64" or "linux-x64"
end

local function options(path, target, sha256)
  target = target or fixture_target()
  return {
    cache_root = path,
    version = "1.527.5",
    target = target,
    sha256 = sha256 or digest,
    entrypoint = target == "js" and "server.js"
      or target:match("^win32%-") and "copilot-language-server.exe"
      or "copilot-language-server",
  }
end

local function target_root(path, opts)
  return vim.fs.joinpath(path, opts.version, opts.target)
end

local function final_path(path, opts)
  return vim.fs.joinpath(target_root(path, opts), opts.sha256)
end

local function write_json(path, value)
  mkdir_private(vim.fs.dirname(path))
  vim.fn.writefile({ vim.json.encode(value) }, path)
end

local function complete_install(path, opts)
  local final = final_path(path, opts)
  mkdir_private(final)
  local entry = vim.fs.joinpath(final, opts.entrypoint)
  vim.fn.writefile({ opts.target == "js" and "module.exports = 1" or "server" }, entry)
  vim.fn.setfperm(entry, opts.target == "js" and "rw-------" or "rwx------")
  write_json(vim.fs.joinpath(final, "install.json"), {
    version = opts.version,
    target = opts.target,
    sha256 = opts.sha256,
  })
  return final, entry
end

local function reserve_with_entry(_, opts)
  local reservation = assert(store.reserve(opts))
  local entry = vim.fs.joinpath(reservation.path, opts.entrypoint)
  vim.fn.writefile({ opts.target == "js" and "module.exports = 1" or "server" }, entry)
  vim.fn.setfperm(entry, opts.target == "js" and "rw-------" or "rwx------")
  return reservation
end

local function publish(reservation, opts)
  local callback_result
  local receipt = store.publish(reservation, opts, function(err, path, outcome)
    callback_result = { err, path, outcome }
  end)
  vim.wait(500, function()
    return callback_result ~= nil
  end)
  return callback_result, receipt
end

local function marker(path, opts, overrides)
  local value = { version = opts.version, target = opts.target, sha256 = opts.sha256 }
  for key, replacement in pairs(overrides or {}) do
    value[key] = replacement
  end
  write_json(vim.fs.joinpath(path, "install.json"), value)
end

T["resolves an exact deterministic install"] = function()
  local path = root()
  local opts = options(path)
  local _, entry = complete_install(path, opts)
  eq(store.resolve(opts), entry)
  vim.fn.delete(path, "rf")
end

T["prepares newly created files before publishing and resumes only once"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local resume, prepared_files, callback_result
  local callbacks = 0
  local receipt = store.publish(reservation, opts, function(err, entry, outcome)
    callbacks = callbacks + 1
    callback_result = { err, entry, outcome }
  end, function(files, done)
    prepared_files, resume = files, done
  end)
  eq(receipt, nil)
  eq(prepared_files, {
    vim.fs.joinpath(reservation.path, opts.entrypoint),
    vim.fs.joinpath(reservation.path, "install.json"),
  })
  eq(vim.fn.filereadable(prepared_files[2]), 1)
  eq(store.resolve(opts), nil)
  eq(callback_result, nil)
  resume(nil)
  resume("duplicate completion")
  eq(
    vim.wait(500, function()
      return callback_result ~= nil
    end),
    true
  )
  eq(callback_result, { nil, vim.fs.joinpath(final_path(path, opts), opts.entrypoint), "published" })
  eq(callbacks, 1)
  vim.fn.delete(path, "rf")
end

T["file preparation failure leaves the install unpublished"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local receipt = store.publish(reservation, opts, function() end, function(_, done)
    done("owner normalization failed")
  end)
  eq(receipt.error, "owner normalization failed")
  eq(receipt.outcome, "unmarked")
  eq(store.resolve(opts), nil)
  eq(vim.fn.isdirectory(reservation.path), 1)
  vim.fn.delete(path, "rf")
end

T["file preparation exceptions fail without publication"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local receipt = store.publish(reservation, opts, function() end, function()
    error("preparation failed")
  end)
  eq(receipt.error:find("preparation failed", 1, true) ~= nil, true)
  eq(receipt.outcome, "unmarked")
  eq(store.resolve(opts), nil)
  vim.fn.delete(path, "rf")
end

T["discarded preparation cannot resume and adopt a winner"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local resume, result
  store.publish(reservation, opts, function(err, entry, outcome)
    result = { err, entry, outcome }
  end, function(_, done)
    resume = done
  end)
  eq(store.discard(reservation, opts), true)
  local _, winner = complete_install(path, opts)
  resume(nil)
  vim.wait(500, function()
    return result ~= nil
  end)
  eq(result[1], "staging reservation disappeared before publication")
  eq(result[2], nil)
  eq(result[3], "unmarked")
  eq(store.resolve(opts), winner)
  vim.fn.delete(path, "rf")
end

T["discarded reservation cannot publish after waiting for a lock"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local winner
  opts._fs = {
    rename = function()
      mkdir_private(final_path(path, opts) .. ".lock")
      vim.defer_fn(function()
        store.discard(reservation, opts)
        winner = select(2, complete_install(path, opts))
      end, 10)
      return false
    end,
  }
  local result = publish(reservation, opts)
  eq(result[1], "staging reservation disappeared before publication")
  eq(result[2], nil)
  eq(result[3], "unmarked")
  eq(store.resolve(opts), winner)
  vim.fn.delete(path, "rf")
end

T["does not prepare files when the install marker already exists"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  vim.fn.writefile({ "pre-existing marker" }, vim.fs.joinpath(reservation.path, "install.json"))
  local prepared = false
  local receipt = store.publish(reservation, opts, function() end, function()
    prepared = true
  end)
  eq(receipt.error, "could not publish install marker")
  eq(prepared, false)
  eq(store.resolve(opts), nil)
  vim.fn.delete(path, "rf")
end

T["rejects cache hits through permissive directories"] = function()
  if vim.loop.os_uname().sysname == "Windows_NT" then
    return
  end
  local path = root()
  local opts = options(path)
  complete_install(path, opts)
  vim.fn.setfperm(opts.cache_root, "rwxrwxrwx")
  eq(store.resolve(opts), nil)
  vim.fn.delete(path, "rf")
end

T["repairs user-owned cache directory permissions before reserving"] = function()
  if vim.loop.os_uname().sysname == "Windows_NT" then
    return
  end
  local path = root()
  local opts = options(path)
  mkdir_private(target_root(path, opts))
  vim.fn.setfperm(path, "rwxrwxrwx")
  vim.fn.setfperm(vim.fs.joinpath(path, opts.version), "rwxrwxrwx")
  vim.fn.setfperm(target_root(path, opts), "rwxrwxrwx")
  local reservation = assert(store.reserve(opts))
  eq(vim.fn.getfperm(path), "rwx------")
  eq(vim.fn.getfperm(vim.fs.joinpath(path, opts.version)), "rwx------")
  eq(vim.fn.getfperm(target_root(path, opts)), "rwx------")
  vim.fn.delete(reservation.path, "rf")
  vim.fn.delete(path, "rf")
end

T["supports a symlink to a private cache root"] = function()
  if vim.loop.os_uname().sysname == "Windows_NT" then
    return
  end
  local physical = root()
  local path = vim.fn.tempname()
  directory_symlink(physical, path)
  local opts = options(path)
  local reservation = assert(store.reserve(opts))
  local entry = vim.fs.joinpath(reservation.path, opts.entrypoint)
  vim.fn.writefile({ "server" }, entry)
  vim.fn.setfperm(entry, "rwx------")
  local receipt = store.publish(reservation, opts, function() end)
  eq(store.resolve(opts), receipt.path)
  local _, incomplete_error = store.cleanup_incomplete(opts)
  local _, archive_error = store.cleanup_archives(opts)
  local _, versions_error = store.cleanup_old_versions(opts)
  eq({ incomplete_error, archive_error, versions_error }, { nil, nil, nil })
  vim.fn.delete(path)
  vim.fn.delete(physical, "rf")
end

T["rejects invalid options and marker mismatches"] = function()
  local path = root()
  for key, value in pairs({
    version = "../escape",
    target = "nested/name",
    sha256 = "bad",
    entrypoint = "nested/server",
  }) do
    local opts = options(path)
    opts[key] = value
    eq(store.resolve(opts) ~= nil, false)
    eq(store.reserve(opts) == nil, true)
  end
  local opts = options(path)
  local final = complete_install(path, opts)
  for key, value in pairs({ version = "wrong", target = "wrong", sha256 = string.rep("b", 64) }) do
    marker(final, opts, { [key] = value })
    eq(store.resolve(opts), nil)
  end
  vim.fn.delete(path, "rf")
end

T["rejects malformed marker JSON"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "{" }, vim.fs.joinpath(final, "install.json"))
  local entry = vim.fs.joinpath(final, opts.entrypoint)
  vim.fn.writefile({ "server" }, entry)
  vim.fn.setfperm(entry, "rwx------")
  eq(store.resolve(opts), nil)
  vim.fn.delete(path, "rf")
end

T["rejects missing symlinked unreadable and non-executable entrypoints"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  marker(final, opts)
  eq(store.resolve(opts), nil)
  local outside = vim.fs.joinpath(path, "outside")
  vim.fn.writefile({ "server" }, outside)
  symlink(outside, vim.fs.joinpath(final, opts.entrypoint))
  eq(store.resolve(opts), nil)
  local entry = vim.fs.joinpath(final, opts.entrypoint)
  vim.fn.delete(entry)
  vim.fn.writefile({ "server" }, entry)
  mark_non_executable(entry)
  eq(store.resolve(opts), nil)
  vim.fn.delete(path, "rf")
end

T["rejects an unreadable JavaScript entrypoint"] = function()
  local path = root()
  local opts = options(path, "js")
  local _, entry = complete_install(path, opts)
  local saved_filereadable = vim.fn.filereadable
  vim.fn.filereadable = function(value)
    if value == entry then
      return 0
    end
    return saved_filereadable(value)
  end
  eq(store.resolve(opts), nil)
  vim.fn.filereadable = saved_filereadable
  vim.fn.delete(path, "rf")
end

T["reserves unique private staging directories"] = function()
  local path = root()
  local opts = options(path)
  local first = assert(store.reserve(opts))
  local second = assert(store.reserve(opts))
  eq(first.path ~= second.path, true)
  eq(first.final_path, final_path(path, opts))
  eq(vim.fs.basename(first.path):match("^%.staging%-.+$") ~= nil, true)
  if vim.loop.os_uname().sysname ~= "Windows_NT" then
    eq(vim.fn.getfperm(first.path), "rwx------")
  end
  vim.fn.delete(path, "rf")
end

T["rejects symlinked final and ancestor directories"] = function()
  local path = root()
  local outside = root()
  local opts = options(path)
  local outside_final, outside_entry = complete_install(outside, options(outside))
  local final = final_path(path, opts)
  mkdir_private(target_root(path, opts))
  directory_symlink(outside_final, final)
  eq(store.resolve(opts), nil)
  vim.fn.delete(final)
  local version = vim.fs.joinpath(path, opts.version)
  vim.fn.delete(version, "rf")
  directory_symlink(vim.fs.joinpath(outside, opts.version), version)
  eq(store.resolve(opts), nil)
  eq(store.reserve(opts) == nil, true)
  eq(vim.fn.filereadable(outside_entry), 1)
  vim.fn.delete(path, "rf")
  vim.fn.delete(outside, "rf")
end

T["rejects a symlinked target ancestor during reservation"] = function()
  local path = root()
  local outside = root()
  local opts = options(path)
  local version = vim.fs.joinpath(path, opts.version)
  mkdir_private(version)
  local external_target = vim.fs.joinpath(outside, opts.target)
  mkdir_private(external_target)
  directory_symlink(external_target, vim.fs.joinpath(version, opts.target))
  eq(store.reserve(opts) == nil, true)
  vim.fn.delete(path, "rf")
  vim.fn.delete(outside, "rf")
end

T["reserves beneath an absent cache root"] = function()
  local path = vim.fn.tempname()
  local opts = options(path)
  local reservation, err = store.reserve(opts)
  eq(err, nil)
  eq(vim.fn.isdirectory(path), 1)
  eq(vim.fn.isdirectory(reservation.target_path), 1)
  vim.fn.delete(path, "rf")
end

T["publishes marker and entrypoint at the deterministic final path"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local result, receipt = publish(reservation, opts)
  local expected = vim.fs.joinpath(final_path(path, opts), opts.entrypoint)
  eq(result, { nil, expected, "published" })
  eq(receipt.committed, true)
  eq(receipt.cleanup_removed, 0)
  eq(receipt.cleanup_error, nil)
  eq(vim.fn.isdirectory(reservation.path), 0)
  eq(vim.fn.filereadable(vim.fs.joinpath(final_path(path, opts), "install.json")), 1)
  vim.fn.delete(path, "rf")
end

T["returns a synchronous committed receipt before callback"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local called = false
  local receipt = store.publish(reservation, opts, function()
    called = true
  end)
  eq(receipt.committed, true)
  eq(called, false)
  vim.wait(500, function()
    return called
  end)
  vim.fn.delete(path, "rf")
end

T["publish returns only its committed receipt"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local receipt = store.publish(reservation, opts, function() end)
  eq(receipt.committed, true)
  eq(receipt.path, vim.fs.joinpath(final_path(path, opts), opts.entrypoint))
  vim.fn.delete(path, "rf")
end

T["delivers successful publication callback asynchronously exactly once"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local count = 0
  local synchronous = true
  store.publish(reservation, opts, function()
    eq(synchronous, false)
    count = count + 1
  end)
  synchronous = false
  vim.wait(500, function()
    return count == 1
  end)
  vim.wait(30)
  eq(count, 1)
  vim.fn.delete(path, "rf")
end

T["delivers one asynchronous callback on failure"] = function()
  local path = root()
  local opts = options(path)
  local reservation = assert(store.reserve(opts))
  local count = 0
  local synchronous = true
  store.publish(reservation, opts, function(err)
    count = count + 1
    eq(err ~= nil, true)
    eq(synchronous, false)
  end)
  synchronous = false
  vim.wait(500, function()
    return count == 1
  end)
  eq(count, 1)
  vim.fn.delete(path, "rf")
end

T["delivers exactly one callback for every publication failure"] = function()
  local cases = {
    {
      setup = function(_, _)
        return nil, nil
      end,
    },
    {
      setup = function(_, opts)
        return nil, opts
      end,
    },
    {
      setup = function(_, opts)
        return assert(store.reserve(opts)), opts
      end,
    },
    {
      setup = function(path, opts)
        local reservation = reserve_with_entry(path, opts)
        opts._fs = {
          write_exclusive = function()
            return false
          end,
        }
        return reservation, opts
      end,
    },
    {
      setup = function(path)
        local opts = options(path, "js")
        local reservation = reserve_with_entry(path, opts)
        local entry = vim.fs.joinpath(reservation.path, opts.entrypoint)
        local saved_filereadable = vim.fn.filereadable
        vim.fn.filereadable = function(value)
          if value == entry then
            return 0
          end
          return saved_filereadable(value)
        end
        opts._restore = function()
          vim.fn.filereadable = saved_filereadable
        end
        return reservation, opts
      end,
    },
    {
      setup = function(path)
        local opts = options(path)
        local reservation = assert(store.reserve(opts))
        local entry = vim.fs.joinpath(reservation.path, opts.entrypoint)
        vim.fn.writefile({ "server" }, entry)
        mark_non_executable(entry)
        return reservation, opts
      end,
    },
    {
      setup = function(path, opts)
        local final = final_path(path, opts)
        mkdir_private(final)
        vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
        local reservation = reserve_with_entry(path, opts)
        local saved_rm = vim.fs.rm
        vim.fs.rm = function(value)
          if value == final then
            error("remove failed")
          end
          return saved_rm(value)
        end
        opts._restore = function()
          vim.fs.rm = saved_rm
        end
        return reservation, opts
      end,
    },
    {
      setup = function(path, opts)
        local final = final_path(path, opts)
        mkdir_private(final)
        vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
        local reservation = reserve_with_entry(path, opts)
        opts._fs = {
          rename = function()
            return false
          end,
        }
        return reservation, opts
      end,
    },
    {
      setup = function(path, opts)
        local reservation = reserve_with_entry(path, opts)
        local final_entry = vim.fs.joinpath(final_path(path, opts), opts.entrypoint)
        opts._fs = {
          lstat = function(value)
            if value == final_entry then
              return nil
            end
            return vim.uv.fs_lstat(value)
          end,
        }
        return reservation, opts
      end,
    },
  }
  for _, case in ipairs(cases) do
    local path = root()
    local reservation, opts = case.setup(path, options(path))
    local count = 0
    local synchronous = true
    store.publish(reservation, opts, function()
      eq(synchronous, false)
      count = count + 1
    end)
    synchronous = false
    vim.wait(500, function()
      return count == 1
    end)
    vim.wait(20)
    eq(count, 1)
    if opts and opts._restore then
      opts._restore()
    end
    vim.fn.delete(path, "rf")
  end
end

T["reuses a concurrent valid winner after rename failure"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  local original_rename = vim.uv.fs_rename
  opts._fs = {
    rename = function(_, _)
      complete_install(path, opts)
      return false
    end,
  }
  local result = publish(reservation, opts)
  eq(result[1], nil)
  eq(result[2], vim.fs.joinpath(final_path(path, opts), opts.entrypoint))
  vim.uv.fs_rename = original_rename
  vim.fn.delete(path, "rf")
end

T["replaces an invalid destination"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "bad" }, vim.fs.joinpath(final, "wrong"))
  local result = publish(reserve_with_entry(path, opts), opts)
  eq(result[1], nil)
  eq(result[2], vim.fs.joinpath(final, opts.entrypoint))
  vim.fn.delete(path, "rf")
end

T["renames before removing an invalid destination and retries once"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  local calls = 0
  opts._fs = {
    rename = function(source, target)
      calls = calls + 1
      return vim.uv.fs_rename(source, target) == true
    end,
  }
  local result = publish(reserve_with_entry(path, opts), opts)
  eq(result[1], nil)
  eq(calls, 2)
  vim.fn.delete(path, "rf")
end

for _, case in ipairs({
  { name = "returned OS error", detail = "second rename denied", code = "EACCES" },
  { name = "thrown error", detail = "second rename threw", throws = true },
  { name = "default filesystem adapter", detail = "second adapter rename denied", code = "EPERM", default = true },
}) do
  T["reports final rename diagnostics for " .. case.name] = function()
    local path = root()
    local opts = options(path)
    local reservation = reserve_with_entry(path, opts)
    local attempts, callbacks = 0, 0
    local result
    local function rename(source, target)
      if source ~= reservation.path or target ~= reservation.final_path then
        return base_rename(source, target)
      end
      attempts = attempts + 1
      if attempts == 1 then
        return nil, "first rename conflict", "EEXIST"
      end
      if case.throws then
        error(case.detail, 0)
      end
      return nil, case.detail, case.code
    end
    if case.default then
      vim.uv.fs_rename = rename
    else
      opts._fs = { rename = rename }
    end
    local receipt = store.publish(reservation, opts, function(err, entry, outcome)
      callbacks = callbacks + 1
      result = { err, entry, outcome }
    end)
    vim.uv.fs_rename = base_rename
    eq(callbacks, 0)
    eq(
      vim.wait(500, function()
        return result ~= nil
      end),
      true
    )
    vim.wait(20)
    eq(callbacks, 1)
    eq(attempts, 2)
    eq(result, { receipt.error, nil, "unmarked" })
    eq(receipt.outcome, "unmarked")
    eq(receipt.path, nil)
    eq(receipt.committed, false)
    eq(store.resolve(opts), nil)
    eq(vim.fn.isdirectory(reservation.path), 1)
    eq(vim.fn.filereadable(vim.fs.joinpath(reservation.path, "install.json")), 1)
    eq(vim.uv.fs_lstat(reservation.final_path), nil)
    eq(vim.uv.fs_lstat(reservation.final_path .. ".lock"), nil)
    eq(receipt.error:find("could not publish deterministic destination", 1, true), 1)
    eq(receipt.error:find(case.detail, 1, true) ~= nil, true)
    eq(receipt.error:find(reservation.final_path, 1, true) ~= nil, true)
    if case.code then
      eq(receipt.error:find(case.code, 1, true) ~= nil, true)
    end
    eq(receipt.error:find("first rename conflict", 1, true), nil)
    eq(receipt.error:find("EEXIST", 1, true), nil)
    vim.fn.delete(path, "rf")
  end
end

T["preserves a valid deterministic destination"] = function()
  local path = root()
  local opts = options(path)
  local _, winner = complete_install(path, opts)
  local reservation = reserve_with_entry(path, opts)
  local result = publish(reservation, opts)
  eq(result[1], nil)
  eq(result[2], winner)
  eq(table.concat(vim.fn.readfile(winner), "\n"), "server")
  eq(vim.fn.isdirectory(reservation.path), 0)
  vim.fn.delete(path, "rf")
end

T["discards only staging beneath the expected target"] = function()
  local path = root()
  local opts = options(path)
  local reservation = assert(store.reserve(opts))
  local discarded, discard_error = store.discard(reservation, opts)
  eq({ discarded, discard_error }, { true, nil })
  local outside = root()
  local forged = {
    path = vim.fs.joinpath(outside, ".staging-forged"),
    target_path = reservation.target_path,
    final_path = reservation.final_path,
  }
  mkdir_private(forged.path)
  discarded, discard_error = store.discard(forged, opts)
  eq({ discarded, discard_error }, { false, "invalid reservation" })
  vim.fn.delete(path, "rf")
  vim.fn.delete(outside, "rf")
end

T["cleans stale staging and archives while preserving fresh items"] = function()
  local path = root()
  local opts = options(path)
  local target = target_root(path, opts)
  mkdir_private(target)
  local stale = vim.fs.joinpath(target, ".staging-old")
  local fresh = vim.fs.joinpath(target, ".staging-new")
  mkdir_private(stale)
  mkdir_private(fresh)
  vim.uv.fs_utime(stale, os.time() - 90000, os.time() - 90000)
  local removed, cleanup_error = store.cleanup_incomplete(opts, os.time())
  eq({ removed, cleanup_error }, { 1, nil })
  eq(vim.fn.isdirectory(fresh), 1)
  local archive = vim.fs.joinpath(path, ".copilot-lsp-archive-1-2.zip")
  local current = vim.fs.joinpath(path, ".copilot-lsp-archive-3-4.zip")
  vim.fn.writefile({ "old" }, archive)
  vim.fn.writefile({ "new" }, current)
  vim.uv.fs_utime(archive, os.time() - 90000, os.time() - 90000)
  removed, cleanup_error = store.cleanup_archives(opts, os.time())
  eq({ removed, cleanup_error }, { 1, nil })
  eq(vim.fn.filereadable(current), 1)
  vim.fn.delete(path, "rf")
end

T["reports an uninspectable cleanup root"] = function()
  local path = root()
  local opts = options(path)
  vim.fn.delete(path, "rf")
  vim.fn.writefile({ "not a directory" }, path)
  local removed, err = store.cleanup_incomplete(opts)
  eq(removed, 0)
  eq(err ~= nil, true)
  vim.fn.delete(path)
end

T["reports a non-directory target root and scan failure"] = function()
  local path = root()
  local opts = options(path)
  local target = target_root(path, opts)
  mkdir_private(vim.fs.dirname(target))
  vim.fn.writefile({ "not a directory" }, target)
  local removed, err = store.cleanup_incomplete(opts)
  eq(removed, 0)
  eq(err ~= nil, true)
  vim.fn.delete(target)
  mkdir_private(target)
  opts._fs = {
    scandir = function()
      return nil, "scan failed"
    end,
  }
  removed, err = store.cleanup_incomplete(opts)
  eq(removed, 0)
  eq(err ~= nil, true)
  vim.fn.delete(path, "rf")
end

T["cleans old versions and legacy layout after publication"] = function()
  local path = root()
  local opts = options(path)
  mkdir_private(vim.fs.joinpath(path, "1.526.9"))
  mkdir_private(vim.fs.joinpath(path, "1.528.0"))
  mkdir_private(vim.fs.joinpath(path, "custom-cache"))
  mkdir_private(vim.fs.joinpath(target_root(path, opts), "generations", "old"))
  write_json(vim.fs.joinpath(target_root(path, opts), "current.json"), {})
  local result = publish(reserve_with_entry(path, opts), opts)
  eq(result[1], nil)
  eq(vim.fn.isdirectory(vim.fs.joinpath(path, "1.526.9")), 0)
  eq(vim.fn.isdirectory(vim.fs.joinpath(path, "1.528.0")), 1)
  eq(vim.fn.isdirectory(vim.fs.joinpath(path, "custom-cache")), 1)
  eq(vim.fn.filereadable(vim.fs.joinpath(target_root(path, opts), "current.json")), 0)
  eq(vim.fn.isdirectory(vim.fs.joinpath(target_root(path, opts), "generations")), 0)
  vim.fn.delete(path, "rf")
end

T["reports marker removal and rename failures without resolving staging"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  opts._fs = {
    write_exclusive = function()
      return false
    end,
  }
  local result = publish(reservation, opts)
  eq(result[1] ~= nil, true)
  eq(store.resolve(opts), nil)
  vim.fn.delete(path, "rf")
end

T["reports rename and deterministic removal failures"] = function()
  local path = root()
  local opts = options(path)
  local reservation = reserve_with_entry(path, opts)
  opts._fs = {
    rename = function()
      return false
    end,
  }
  local result = publish(reservation, opts)
  eq(result[1] ~= nil, true)
  vim.fn.delete(path, "rf")

  path = root()
  opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  local saved_rm = vim.fs.rm
  vim.fs.rm = function(value)
    if value == final then
      error("remove failed")
    end
    return saved_rm(value)
  end
  local removal_result = publish(reserve_with_entry(path, opts), opts)
  vim.fs.rm = saved_rm
  eq(removal_result[1] ~= nil, true)
  vim.fn.delete(path, "rf")
end

T["preserves SHA directories and archive symlinks during cleanup"] = function()
  local path = root()
  local opts = options(path)
  local sha = vim.fs.joinpath(target_root(path, opts), string.rep("b", 64))
  mkdir_private(sha)
  local external = root()
  local archive = vim.fs.joinpath(path, ".copilot-lsp-archive-1-2.zip")
  local external_archive = vim.fs.joinpath(external, "archive.zip")
  vim.fn.writefile({ "archive" }, external_archive)
  symlink(external_archive, archive)
  local removed = store.cleanup_incomplete(opts, os.time())
  eq(removed, 0)
  local archive_removed = store.cleanup_archives(opts, os.time())
  eq(archive_removed, 0)
  eq(vim.fn.isdirectory(sha), 1)
  eq(vim.fn.filereadable(external_archive), 1)
  vim.fn.delete(path, "rf")
  vim.fn.delete(external, "rf")
end

T["reclaims just-stale publication locks and preserves younger locks"] = function()
  local path = root()
  local opts = options(path)
  local target = target_root(path, opts)
  mkdir_private(target)
  local stale_lock = vim.fs.joinpath(target, opts.sha256 .. ".lock")
  local younger_opts = options(path, nil, string.rep("b", 64))
  local younger_lock = vim.fs.joinpath(target, younger_opts.sha256 .. ".lock")
  mkdir_private(stale_lock)
  mkdir_private(younger_lock)
  vim.uv.fs_utime(stale_lock, os.time() - 61, os.time() - 61)
  vim.uv.fs_utime(younger_lock, os.time() - 30, os.time() - 30)
  local removed, err = store.cleanup_incomplete(opts, os.time())
  eq({ removed, err }, { 1, nil })
  eq(vim.fn.isdirectory(stale_lock), 0)
  eq(vim.fn.isdirectory(younger_lock), 1)
  vim.fn.delete(path, "rf")
end

T["reuses a winner that appears before invalid removal"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  local saved_rm = vim.fs.rm
  local injected = false
  opts._fs = {
    rename = function()
      return false
    end,
  }
  vim.fs.rm = function(value, rm_options)
    if value == final and not injected then
      injected = true
      complete_install(path, opts)
      return true
    end
    return saved_rm(value, rm_options)
  end
  local result = publish(reserve_with_entry(path, opts), opts)
  vim.fs.rm = saved_rm
  eq(result[1], nil)
  eq(result[2], vim.fs.joinpath(final, opts.entrypoint))
  eq(table.concat(vim.fn.readfile(result[2]), "\n"), "server")
  eq(vim.fn.isdirectory(vim.fs.joinpath(target_root(path, opts), opts.sha256 .. ".lock")), 0)
  vim.fn.delete(path, "rf")
end

T["waits for an owner to complete before reusing its winner"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  local lock = final .. ".lock"
  local reservation = reserve_with_entry(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  mkdir_private(lock)
  opts._fs = {
    rename = function()
      return false
    end,
  }
  vim.defer_fn(function()
    complete_install(path, opts)
    vim.fn.delete(lock, "rf")
  end, 100)
  local result = publish(reservation, opts)
  eq(result[1], nil)
  eq(result[2], vim.fs.joinpath(final, opts.entrypoint))
  eq(vim.fn.isdirectory(lock), 0)
  vim.fn.delete(path, "rf")
end

T["fences a late owner after lock reclamation"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  local lock = final .. ".lock"
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  local reservation = reserve_with_entry(path, opts)
  local original_read = vim.uv.fs_open
  local replaced = false
  opts._fs = {
    read = function(value)
      if value == vim.fs.joinpath(lock, "owner") and not replaced then
        replaced = true
        vim.fn.delete(lock, "rf")
        mkdir_private(lock)
        vim.fn.writefile({ "owner-b" }, vim.fs.joinpath(lock, "owner"))
        vim.fn.delete(vim.fs.joinpath(final, "invalid"))
        vim.fn.writefile({ "winner-b" }, vim.fs.joinpath(final, opts.entrypoint))
        vim.fn.setfperm(vim.fs.joinpath(final, opts.entrypoint), "rwx------")
        marker(final, opts)
      end
      local fd = original_read(value, "r", 384)
      if not fd then
        return nil
      end
      local stat = vim.uv.fs_fstat(fd)
      local data = stat and vim.uv.fs_read(fd, stat.size, 0) or nil
      vim.uv.fs_close(fd)
      return data
    end,
  }
  local result = publish(reservation, opts)
  eq(result[1], nil)
  eq(result[2], vim.fs.joinpath(final, opts.entrypoint))
  eq(table.concat(vim.fn.readfile(vim.fs.joinpath(final, opts.entrypoint)), "\n"), "winner-b")
  eq(table.concat(vim.fn.readfile(vim.fs.joinpath(lock, "owner")), "\n"), "owner-b")
  vim.fn.delete(path, "rf")
end

T["reports publication lock token write failure"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  local original_write = vim.uv.fs_open
  opts._fs = {
    write_exclusive = function(value)
      if value:match("%.lock/owner$") then
        return false
      end
      local fd = original_write(value, "wx", 384)
      if not fd then
        return false
      end
      vim.uv.fs_write(fd, vim.json.encode({ version = opts.version, target = opts.target, sha256 = opts.sha256 }), -1)
      vim.uv.fs_close(fd)
      return true
    end,
  }
  local result = publish(reserve_with_entry(path, opts), opts)
  eq(result[1]:find("publication lock", 1, true) ~= nil, true)
  vim.fn.delete(path, "rf")
end

T["fences publication when the owner token cannot be read"] = function()
  local path = root()
  local opts = options(path)
  local final = final_path(path, opts)
  mkdir_private(final)
  vim.fn.writefile({ "invalid" }, vim.fs.joinpath(final, "invalid"))
  local lock
  opts._fs = {
    read = function(value)
      if lock and value == vim.fs.joinpath(lock, "owner") then
        return nil
      end
      local fd = vim.uv.fs_open(value, "r", 384)
      if not fd then
        return nil
      end
      local stat = vim.uv.fs_fstat(fd)
      local data = stat and vim.uv.fs_read(fd, stat.size, 0) or nil
      vim.uv.fs_close(fd)
      return data
    end,
  }
  lock = final .. ".lock"
  local result = publish(reserve_with_entry(path, opts), opts)
  eq(result[1]:find("lock ownership lost", 1, true) ~= nil, true)
  eq(vim.fn.isdirectory(lock), 1)
  vim.fn.delete(path, "rf")
end

return T
