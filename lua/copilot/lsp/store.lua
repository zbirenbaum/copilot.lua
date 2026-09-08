local uv = vim.uv
local LOCK_STALE_SECONDS = 60
local STAGING_STALE_SECONDS = 24 * 60 * 60

local M = {}
local digest_pattern = "^" .. string.rep("[0-9a-f]", 64) .. "$"
local lock_sequence = 0

local function component(value, pattern)
  return type(value) == "string"
    and value ~= ""
    and value ~= "."
    and value ~= ".."
    and not value:find("[/\\\\]", 1)
    and not value:find(":", 1, true)
    and value:match(pattern) ~= nil
end

local function validate_options(options)
  if type(options) ~= "table" or type(options.cache_root) ~= "string" then
    return nil, "invalid store options"
  end
  if not component(options.version, "^[0-9]+%.[0-9]+%.[0-9]+$") then
    return nil, "invalid version"
  end
  if not component(options.target, "^[A-Za-z0-9][A-Za-z0-9%-]*$") then
    return nil, "invalid target"
  end
  if type(options.sha256) ~= "string" or not options.sha256:match(digest_pattern) then
    return nil, "invalid SHA-256 digest"
  end
  if not component(options.entrypoint, "^[^%.][^/\\\\]*$") then
    return nil, "invalid entrypoint"
  end
  return true
end

local function paths(options, fs)
  local cache_root = (fs and fs.realpath or uv.fs_realpath)(options.cache_root)
  if not cache_root then
    return nil
  end
  local version_path = vim.fs.joinpath(cache_root, options.version)
  local target_path = vim.fs.joinpath(version_path, options.target)
  return {
    cache_root = cache_root,
    version_path = version_path,
    target_path = target_path,
    final_path = vim.fs.joinpath(target_path, options.sha256),
  }
end

local function staging_name(path)
  return vim.fs.basename(path):match("^%.staging%-.+$") ~= nil
end

local function remove_path(path)
  local stat = uv.fs_lstat(path)
  if not stat then
    return true
  end
  if stat.type == "link" then
    return uv.fs_unlink(path) == true
  end
  return pcall(vim.fs.rm, path, { recursive = stat.type == "directory", force = true })
end

local function default_read(path)
  local fd = uv.fs_open(path, "r", 384)
  if not fd then
    return nil
  end
  local stat = uv.fs_fstat(fd)
  local data = stat and uv.fs_read(fd, stat.size, 0) or nil
  uv.fs_close(fd)
  return data
end

local function default_write_exclusive(path, data, mode)
  local fd = uv.fs_open(path, "wx", mode)
  if not fd then
    return false
  end
  local written = uv.fs_write(fd, data, -1)
  uv.fs_close(fd)
  return written == #data
end

local function filesystem(options)
  local override = options._fs or {}
  return {
    lstat = override.lstat or uv.fs_lstat,
    realpath = override.realpath or uv.fs_realpath,
    read = override.read or default_read,
    write_exclusive = override.write_exclusive or default_write_exclusive,
    rename = override.rename or function(source, target)
      return uv.fs_rename(source, target)
    end,
    mkdtemp = override.mkdtemp or uv.fs_mkdtemp,
    scandir = override.scandir or uv.fs_scandir,
  }
end

local function read_json(fs, path)
  local data = fs.read(path)
  if not data then
    return nil
  end
  local ok, value = pcall(vim.json.decode, data)
  return ok and type(value) == "table" and value or nil
end

local function ensure_directory(path, allow_link)
  local stat = uv.fs_lstat(path)
  if stat then
    if stat.type == "link" and allow_link then
      path = uv.fs_realpath(path)
      stat = path and uv.fs_lstat(path) or nil
    end
    if not stat or stat.type ~= "directory" then
      return false
    end
  else
    vim.fn.mkdir(path, "p", "448")
    stat = uv.fs_lstat(path)
    if not stat or stat.type ~= "directory" then
      return false
    end
  end

  if uv.os_uname().sysname == "Windows_NT" then
    return true
  end
  if not uv.getuid or stat.uid ~= uv.getuid() then
    return false
  end
  if stat.mode % 64 ~= 0 then
    if uv.fs_chmod(path, 448) ~= true then
      return false
    end
    stat = uv.fs_lstat(path)
  end
  return stat and stat.uid == uv.getuid() and stat.mode % 64 == 0
end

local static_paths_valid

local function prepared_paths(options, fs)
  if not ensure_directory(options.cache_root, true) then
    return nil, "could not establish cache root"
  end
  local cache_root = (fs and fs.realpath or uv.fs_realpath)(options.cache_root)
  if not cache_root then
    return nil, "could not establish physical cache root"
  end
  local store_paths = {
    cache_root = cache_root,
    version_path = vim.fs.joinpath(cache_root, options.version),
    target_path = vim.fs.joinpath(cache_root, options.version, options.target),
    final_path = vim.fs.joinpath(cache_root, options.version, options.target, options.sha256),
  }
  if not static_paths_valid(fs, store_paths) then
    return nil, "prepared store paths are not directories"
  end
  return store_paths
end

local function resolve_final(fs, options, store_paths)
  if not static_paths_valid(fs, store_paths) then
    return nil
  end
  if uv.os_uname().sysname ~= "Windows_NT" then
    local uid = uv.getuid and uv.getuid()
    if not uid then
      return nil
    end
    for _, path in ipairs({
      store_paths.cache_root,
      store_paths.version_path,
      store_paths.target_path,
      store_paths.final_path,
    }) do
      local stat = fs.lstat(path)
      if not stat or stat.type ~= "directory" or stat.uid ~= uid or stat.mode % 64 ~= 0 then
        return nil
      end
    end
  end
  local marker_path = vim.fs.joinpath(store_paths.final_path, "install.json")
  local marker_stat = fs.lstat(marker_path)
  local marker = marker_stat and marker_stat.type == "file" and read_json(fs, marker_path) or nil
  if
    not marker
    or marker.version ~= options.version
    or marker.target ~= options.target
    or marker.sha256 ~= options.sha256
  then
    return nil
  end
  local entry = vim.fs.joinpath(store_paths.final_path, options.entrypoint)
  local stat = fs.lstat(entry)
  if not stat or stat.type ~= "file" then
    return nil
  end
  if uv.os_uname().sysname ~= "Windows_NT" then
    local uid = uv.getuid and uv.getuid()
    if
      not uid
      or marker_stat.uid ~= uid
      or stat.uid ~= uid
      or math.floor(marker_stat.mode / 16) % 2 ~= 0
      or math.floor(marker_stat.mode / 2) % 2 ~= 0
      or math.floor(stat.mode / 16) % 2 ~= 0
      or math.floor(stat.mode / 2) % 2 ~= 0
    then
      return nil
    end
  end
  if options.target == "js" then
    return vim.fn.filereadable(entry) == 1 and entry or nil
  end
  return vim.fn.executable(entry) == 1 and entry or nil
end

local function valid_reservation(store_paths, reservation)
  return type(reservation) == "table"
    and type(reservation.path) == "string"
    and reservation.target_path == store_paths.target_path
    and reservation.final_path == store_paths.final_path
    and vim.fs.dirname(reservation.path) == store_paths.target_path
    and staging_name(reservation.path)
end

local function semver(value)
  local major, minor, patch = value:match("^([0-9]+)%.([0-9]+)%.([0-9]+)$")
  return major and tonumber(major), minor and tonumber(minor), patch and tonumber(patch)
end

local function older_version(candidate, current)
  local ca, cb, cc = semver(candidate)
  local a, b, c = semver(current)
  return ca and a and (ca < a or (ca == a and cb < b) or (ca == a and cb == b and cc < c)) or false
end

local function beneath(root, path)
  root = vim.fs.normalize(root)
  path = vim.fs.normalize(path)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

static_paths_valid = function(fs, store_paths)
  for _, path in ipairs({ store_paths.version_path, store_paths.target_path, store_paths.final_path }) do
    local stat = fs.lstat(path)
    if stat and stat.type ~= "directory" then
      return false
    end
    if stat then
      local real = fs.realpath(path)
      if not real or not beneath(store_paths.cache_root, real) then
        return false
      end
    end
  end
  return true
end

local function lock_path(store_paths)
  return store_paths.final_path .. ".lock"
end

local function lock_owner_path(store_paths)
  return vim.fs.joinpath(lock_path(store_paths), "owner")
end

local function new_lock_token()
  lock_sequence = lock_sequence + 1
  return string.format("%x-%x", uv.hrtime(), lock_sequence)
end

local function acquire_lock(fs, store_paths)
  local path = lock_path(store_paths)
  if uv.fs_lstat(path) then
    return nil
  end
  if uv.fs_mkdir(path, 448) ~= true then
    return nil
  end
  local token = new_lock_token()
  if not fs.write_exclusive(lock_owner_path(store_paths), token, 384) then
    remove_path(path)
    return nil, "could not write publication lock token"
  end
  return token
end

local function owns_lock(fs, path, token)
  return token ~= nil and fs.read(vim.fs.joinpath(path, "owner")) == token
end

local function acquire_lock_wait(fs, options, store_paths)
  local deadline = uv.hrtime() + 1000000000
  local path = lock_path(store_paths)
  while true do
    local winner = resolve_final(fs, options, store_paths)
    if winner then
      return false, winner
    end
    local token, acquire_error = acquire_lock(fs, store_paths)
    if token then
      return token, nil, nil
    end
    if acquire_error then
      return nil, nil, acquire_error
    end
    local stat = uv.fs_lstat(path)
    if stat and stat.type == "directory" and stat.mtime and os.time() - stat.mtime.sec > LOCK_STALE_SECONDS then
      remove_path(path)
    end
    if uv.hrtime() >= deadline then
      return nil, nil, nil
    end
    vim.wait(50)
  end
end

local function release_lock(fs, store_paths, token)
  local path = lock_path(store_paths)
  if owns_lock(fs, path, token) then
    remove_path(path)
  end
end

local function inspect_directory(fs, path, callback)
  local scanned, handle, scan_error = pcall(fs.scandir, path)
  if not scanned or not handle then
    return false, scan_error or handle
  end
  return pcall(function()
    for name, kind in vim.fs.dir(path) do
      callback(name, kind)
    end
  end)
end

function M.resolve(user_options)
  local ok, err = validate_options(user_options)
  if not ok then
    return nil, err
  end
  local fs = filesystem(user_options)
  local store_paths = paths(user_options, fs)
  if not store_paths then
    return nil, "store path is unavailable"
  end
  return resolve_final(fs, user_options, store_paths)
end

function M.current(user_options)
  return M.resolve(user_options)
end

function M.prepare_path(user_options)
  local ok, err = validate_options(user_options)
  if not ok then
    return nil, err
  end
  return prepared_paths(user_options, filesystem(user_options))
end

function M.reserve(user_options, prepared)
  local ok, err = validate_options(user_options)
  if not ok then
    return nil, err
  end
  local fs = filesystem(user_options)
  if not ensure_directory(user_options.cache_root, true) then
    return nil, "could not establish cache root"
  end
  local store_paths = paths(user_options, fs)
  if not store_paths then
    return nil, "store path is unavailable"
  end
  if prepared then
    for _, key in ipairs({ "cache_root", "version_path", "target_path", "final_path" }) do
      if prepared[key] ~= store_paths[key] then
        return nil, "prepared store path changed"
      end
    end
  end
  if not ensure_directory(store_paths.version_path) or not ensure_directory(store_paths.target_path) then
    return nil, "could not establish store parents"
  end
  if not static_paths_valid(fs, store_paths) then
    return nil, "store path contains a symlink or non-directory ancestor"
  end
  local staging, staging_error = fs.mkdtemp(vim.fs.joinpath(store_paths.target_path, ".staging-XXXXXX"))
  if not staging then
    return nil, "could not reserve staging directory: " .. tostring(staging_error)
  end
  return {
    path = staging,
    target_path = store_paths.target_path,
    final_path = store_paths.final_path,
  },
    nil
end

function M.discard(reservation, user_options)
  local ok = validate_options(user_options)
  if not ok then
    return false, "invalid store options"
  end
  local store_paths = paths(user_options, filesystem(user_options))
  if not store_paths or not valid_reservation(store_paths, reservation) then
    return false, "invalid reservation"
  end
  if not remove_path(reservation.path) then
    return false, "could not discard staging reservation"
  end
  return true, nil
end

function M.cleanup_incomplete(user_options, now)
  local ok, err = validate_options(user_options)
  if not ok then
    return 0, err
  end
  local fs = filesystem(user_options)
  local root_stat = fs.lstat(user_options.cache_root)
  if not root_stat then
    return 0, nil
  end
  local physical_root = fs.realpath(user_options.cache_root)
  root_stat = physical_root and fs.lstat(physical_root) or nil
  if not root_stat or root_stat.type ~= "directory" then
    return 0, "cache root is not a directory"
  end
  local store_paths = paths(user_options, fs)
  if not store_paths then
    return 0, "cache root is unavailable"
  end
  local stat = uv.fs_lstat(store_paths.target_path)
  if not stat or stat.type ~= "directory" then
    return 0, stat and "target root is not a directory" or nil
  end
  now = now or os.time()
  local removed = 0
  local inspected, scan_error = inspect_directory(fs, store_paths.target_path, function(name, kind)
    if
      kind == "directory"
      and (name:match("^%.staging%-.+$") or name:match("^" .. string.rep("[0-9a-f]", 64) .. "%.lock$"))
    then
      local path = vim.fs.joinpath(store_paths.target_path, name)
      local item = uv.fs_lstat(path)
      if
        item
        and item.type == "directory"
        and item.mtime
        and now - item.mtime.sec > (name:match("%.lock$") and LOCK_STALE_SECONDS or STAGING_STALE_SECONDS)
        and remove_path(path)
      then
        removed = removed + 1
      end
    end
  end)
  if not inspected then
    return removed, tostring(scan_error)
  end
  return removed, nil
end

function M.cleanup_archives(user_options, now)
  local ok, err = validate_options(user_options)
  if not ok then
    return 0, err
  end
  local fs = filesystem(user_options)
  local root_stat = fs.lstat(user_options.cache_root)
  if not root_stat then
    return 0, nil
  end
  local cache_root = fs.realpath(user_options.cache_root)
  if not cache_root then
    return 0, "cache root is unavailable"
  end
  local stat = fs.lstat(cache_root)
  if not stat or stat.type ~= "directory" then
    return 0, "cache root is not a directory"
  end
  now = now or os.time()
  local removed = 0
  local inspected, scan_error = inspect_directory(fs, cache_root, function(name, kind)
    if kind == "file" and name:match("^%.copilot%-lsp%-archive%-%d+%-%d+%.zip$") then
      local path = vim.fs.joinpath(cache_root, name)
      local item = uv.fs_lstat(path)
      if
        item
        and item.type == "file"
        and item.mtime
        and now - item.mtime.sec > STAGING_STALE_SECONDS
        and remove_path(path)
      then
        removed = removed + 1
      end
    end
  end)
  if not inspected then
    return removed, tostring(scan_error)
  end
  return removed, nil
end

function M.cleanup_old_versions(user_options)
  local ok, err = validate_options(user_options)
  if not ok then
    return 0, err
  end
  local fs = filesystem(user_options)
  local root_stat = fs.lstat(user_options.cache_root)
  if not root_stat then
    return 0, nil
  end
  local physical_root = fs.realpath(user_options.cache_root)
  root_stat = physical_root and fs.lstat(physical_root) or nil
  if not root_stat or root_stat.type ~= "directory" then
    return 0, "cache root is not a directory"
  end
  local store_paths = paths(user_options, fs)
  if not store_paths then
    return 0, "cache root is unavailable"
  end
  local removed = 0
  local inspected, scan_error = inspect_directory(fs, store_paths.cache_root, function(name, kind)
    if kind == "directory" and older_version(name, user_options.version) then
      if remove_path(vim.fs.joinpath(store_paths.cache_root, name)) then
        removed = removed + 1
      end
    end
  end)
  if not inspected then
    return removed, tostring(scan_error)
  end
  for _, path in ipairs({
    vim.fs.joinpath(store_paths.target_path, "current.json"),
    vim.fs.joinpath(store_paths.target_path, "generations"),
  }) do
    if uv.fs_lstat(path) and remove_path(path) then
      removed = removed + 1
    end
  end
  return removed, nil
end

-- prepare_files may asynchronously secure the freshly created payload/marker
-- before they become visible at the deterministic destination.
function M.publish(reservation, user_options, callback, prepare_files)
  local receipt = { outcome = "unmarked", path = nil, error = nil, committed = false }
  local done = false
  local function finish(err, path, outcome)
    if done then
      return receipt
    end
    done = true
    receipt.outcome = outcome or "unmarked"
    receipt.path = path
    receipt.error = err
    receipt.committed = receipt.outcome == "published"
    vim.schedule(function()
      callback(err, path, receipt.outcome)
    end)
    return receipt
  end
  local ok, err = validate_options(user_options)
  if not ok then
    return finish(err)
  end
  local fs = filesystem(user_options)
  local store_paths = paths(user_options, fs)
  if not store_paths or not valid_reservation(store_paths, reservation) then
    return finish("invalid staging reservation")
  end
  local staged_entry = vim.fs.joinpath(reservation.path, user_options.entrypoint)
  local stat = fs.lstat(staged_entry)
  if not stat or stat.type ~= "file" then
    return finish("reserved staging entrypoint is invalid")
  end
  if user_options.target == "js" and vim.fn.filereadable(staged_entry) ~= 1 then
    return finish("reserved staging entrypoint is not readable")
  elseif user_options.target ~= "js" and vim.fn.executable(staged_entry) ~= 1 then
    return finish("reserved staging entrypoint is not executable")
  end
  local marker =
    vim.json.encode({ version = user_options.version, target = user_options.target, sha256 = user_options.sha256 })
  local staged_marker = vim.fs.joinpath(reservation.path, "install.json")
  if not fs.write_exclusive(staged_marker, marker, 384) then
    return finish("could not publish install marker")
  end
  local function publish_prepared()
    local staging_stat = fs.lstat(reservation.path)
    if not staging_stat or staging_stat.type ~= "directory" then
      return finish("staging reservation disappeared before publication")
    end
    local function rename()
      local renamed_ok, renamed_value, rename_error, rename_code =
        pcall(fs.rename, reservation.path, store_paths.final_path)
      if not renamed_ok then
        return false, renamed_value
      end
      return renamed_value, rename_error, rename_code
    end
    local winner = resolve_final(fs, user_options, store_paths)
    if winner then
      M.discard(reservation, user_options)
      receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
      return finish(nil, winner, "published")
    end
    local renamed = rename()
    if not renamed then
      winner = resolve_final(fs, user_options, store_paths)
      if winner then
        M.discard(reservation, user_options)
        receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
        return finish(nil, winner, "published")
      end
      local lock_token, waited_winner, acquire_error = acquire_lock_wait(fs, user_options, store_paths)
      staging_stat = fs.lstat(reservation.path)
      if not staging_stat or staging_stat.type ~= "directory" then
        release_lock(fs, store_paths, lock_token)
        return finish("staging reservation disappeared before publication")
      end
      if waited_winner then
        M.discard(reservation, user_options)
        receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
        return finish(nil, waited_winner, "published")
      end
      if acquire_error then
        return finish(acquire_error)
      end
      if not lock_token then
        return finish("publication conflict at " .. store_paths.final_path)
      end
      local function lock_finish(error_message)
        release_lock(fs, store_paths, lock_token)
        return finish(error_message)
      end
      local function lock_lost()
        winner = resolve_final(fs, user_options, store_paths)
        if winner then
          M.discard(reservation, user_options)
          release_lock(fs, store_paths, lock_token)
          receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
          return finish(nil, winner, "published")
        end
        return lock_finish("publication conflict: lock ownership lost")
      end
      winner = resolve_final(fs, user_options, store_paths)
      if winner then
        M.discard(reservation, user_options)
        release_lock(fs, store_paths, lock_token)
        receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
        return finish(nil, winner, "published")
      end
      if not owns_lock(fs, lock_path(store_paths), lock_token) then
        return lock_lost()
      end
      if uv.fs_lstat(store_paths.final_path) then
        winner = resolve_final(fs, user_options, store_paths)
        if winner then
          M.discard(reservation, user_options)
          release_lock(fs, store_paths, lock_token)
          receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
          return finish(nil, winner, "published")
        end
        if not owns_lock(fs, lock_path(store_paths), lock_token) then
          return lock_lost()
        end
        if not remove_path(store_paths.final_path) then
          return lock_finish("could not remove invalid deterministic destination")
        end
      end
      winner = resolve_final(fs, user_options, store_paths)
      if winner then
        M.discard(reservation, user_options)
        release_lock(fs, store_paths, lock_token)
        receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
        return finish(nil, winner, "published")
      end
      if not owns_lock(fs, lock_path(store_paths), lock_token) then
        return lock_lost()
      end
      local rename_error, rename_code
      renamed, rename_error, rename_code = rename()
      if not renamed then
        winner = resolve_final(fs, user_options, store_paths)
        if winner then
          M.discard(reservation, user_options)
          release_lock(fs, store_paths, lock_token)
          receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
          return finish(nil, winner, "published")
        end
        return lock_finish(
          "could not publish deterministic destination at "
            .. store_paths.final_path
            .. (rename_error ~= nil and ": " .. tostring(rename_error) or "")
            .. (rename_code ~= nil and " (" .. tostring(rename_code) .. ")" or "")
        )
      end
      release_lock(fs, store_paths, lock_token)
    end
    local final_entry = resolve_final(fs, user_options, store_paths)
    if not final_entry then
      return finish("published deterministic destination is invalid")
    end
    receipt.cleanup_removed, receipt.cleanup_error = M.cleanup_old_versions(user_options)
    return finish(nil, final_entry, "published")
  end
  if not prepare_files then
    return publish_prepared()
  end
  local resumed = false
  local prepared_receipt
  local prepared_ok, prepare_error = pcall(prepare_files, { staged_entry, staged_marker }, function(error_message)
    if resumed then
      return
    end
    resumed = true
    if error_message then
      prepared_receipt = finish(error_message)
    else
      prepared_receipt = publish_prepared()
    end
  end)
  if not prepared_ok and not resumed then
    resumed = true
    return finish(tostring(prepare_error))
  end
  return prepared_receipt
end

return M
