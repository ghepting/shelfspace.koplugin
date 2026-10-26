-- Installing a ShelfSpace release from inside KOReader. Every step before the last only touches a staging
-- folder, so a failure at any point leaves the installed plugin exactly as it was:
--   download the release zip -> check its SHA-256 against the digest GitHub published with it -> unpack it into
--   a staging folder (refusing anything outside the plugin's own folder) -> check that what came out is the
--   release we meant and that every Lua file at least compiles -> swap it in, keeping the old one beside it as
--   shelfspace.koplugin.old. KOReader must be restarted afterwards to load it.
local Version = require("shelfspace/version")
local _ = require("gettext")
local T = require("ffi/util").template

local Installer = {}

-- The hex SHA-256 GitHub published for a release asset ("sha256:<64 hex digits>"), or nil when it did not.
function Installer.expectedDigest(asset)
    local hex = asset and type(asset.digest) == "string" and asset.digest:match("^sha256:(%x+)$")
    if hex and #hex == 64 then return hex:lower() end
end

-- Where `entry_path` (a path in the zip) lands inside the plugin folder called `name`: "" for the folder
-- itself, "lib/x.lua" for a file in it, nil for anything that is not inside it or could climb out of it.
function Installer.relative(entry_path, name)
    local prefix = name .. "/"
    if entry_path:sub(1, #prefix) ~= prefix then return nil end
    local rel = entry_path:sub(#prefix + 1):gsub("/$", "")
    if rel == "" then return "" end
    if rel:find("\0", 1, true) or rel:find("\\", 1, true) then return nil end
    for part in (rel .. "/"):gmatch("([^/]*)/") do
        if part == "" or part == "." or part == ".." then return nil end
    end
    return rel
end

-- The folders involved for the plugin at `plugin_path`. The staging folder sits beside it, on the same disk,
-- so the final move is a rename and not a copy. KOReader only loads folders ending in .koplugin, so neither
-- the staging folder nor the .old copy is ever loaded.
function Installer.plan(plugin_path)
    local dir, name = plugin_path:match("^(.*)/([^/]+)$")
    local staging = dir .. "/.shelfspace-update"
    return { dir = dir, name = name, current = plugin_path, staging = staging, incoming = staging .. "/" .. name, old = plugin_path .. ".old" }
end

-- Puts the unpacked plugin in place, the old one kept as .old. If the second move fails the first is undone.
-- `fs` is { exists, rename, purge }; Installer.fs() is the real one.
function Installer.swap(plan, fs)
    if fs.exists(plan.old) then fs.purge(plan.old) end
    if not fs.rename(plan.current, plan.old) then
        return nil, _("could not move the current version aside")
    end
    if not fs.rename(plan.incoming, plan.current) then
        fs.rename(plan.old, plan.current)
        return nil, _("could not put the new version in place; the current one was kept")
    end
    fs.purge(plan.staging)
    return true
end

function Installer.fs()
    local lfs = require("libs/libkoreader-lfs")
    return {
        exists = function(path) return lfs.attributes(path, "mode") ~= nil end,
        rename = os.rename,
        purge = require("ffi/util").purgeDir,
    }
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- Fetches `url` into the file `dest`.
function Installer.download(url, dest)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local socket = require("socket")
    local socketutil = require("socketutil")
    local file = io.open(dest, "wb")
    if not file then return nil, T(_("could not write %1"), dest) end
    socketutil:set_timeout(15, 120)
    local code, _, status = socket.skip(1, http.request { url = url, sink = ltn12.sink.file(file), headers = { ["User-Agent"] = "ShelfSpace" } })
    socketutil:reset_timeout()
    if code ~= 200 then return nil, status or tostring(code or "no connection") end
    return true
end

local function mkdirs(path, from)
    local lfs = require("libs/libkoreader-lfs")
    local built = from
    for part in path:sub(#from + 2):gmatch("[^/]+") do
        built = built .. "/" .. part
        if lfs.attributes(built, "mode") == nil then
            if not lfs.mkdir(built) then return nil, T(_("could not create %1"), built) end
        end
    end
    return true
end

-- Unpacks the zip into plan.incoming. Anything not inside the plugin's own folder in the zip is refused.
function Installer.extract(zip_path, plan)
    local lfs = require("libs/libkoreader-lfs")
    local reader = require("ffi/archiver").Reader:new()
    if not reader:open(zip_path) then return nil, _("could not open the download") end
    if lfs.attributes(plan.staging, "mode") then require("ffi/util").purgeDir(plan.staging) end
    local ok, err = mkdirs(plan.staging, plan.dir)
    for entry in reader:iterate() do
        if not ok then break end
        local rel = Installer.relative(entry.path, plan.name)
        if rel == nil then
            ok, err = nil, T(_("the download holds a file it should not: %1"), entry.path)
        elseif entry.mode == "directory" then
            ok, err = mkdirs(plan.incoming .. (rel ~= "" and "/" .. rel or ""), plan.dir)
        elseif entry.mode == "file" then
            local target = plan.incoming .. "/" .. rel
            ok, err = mkdirs(target:match("^(.*)/[^/]+$"), plan.dir)
            if ok then
                local content = reader:extractToMemory(entry.path)
                local f = content and io.open(target, "wb")
                if f then f:write(content) f:close() else ok, err = nil, T(_("could not unpack %1"), rel) end
            end
        else
            ok, err = nil, T(_("the download holds something other than files: %1"), entry.path)
        end
    end
    reader:close()
    return ok, err
end

-- That what was unpacked is release `version`, complete enough to load, and every Lua file compiles.
function Installer.validate(plan, version)
    local lfs = require("libs/libkoreader-lfs")
    for _, name in ipairs({ "main.lua", "_meta.lua" }) do
        if lfs.attributes(plan.incoming .. "/" .. name, "mode") ~= "file" then return nil, T(_("%1 is missing"), name) end
    end
    local found = Version.fromMeta(readFile(plan.incoming .. "/_meta.lua"))
    if found ~= version then return nil, T(_("the download is version %1, not %2"), tostring(found), version) end
    local function walk(dir)
        for name in lfs.dir(dir) do
            if name ~= "." and name ~= ".." then
                local path = dir .. "/" .. name
                local mode = lfs.attributes(path, "mode")
                if mode == "directory" then
                    local ok, err = walk(path)
                    if not ok then return nil, err end
                elseif name:match("%.lua$") then
                    local chunk, err = loadfile(path)
                    if not chunk then return nil, T(_("%1 does not compile: %2"), name, tostring(err)) end
                end
            end
        end
        return true
    end
    return walk(plan.incoming)
end

-- Downloads, checks and installs release `version` described by `asset` ({ url, size, digest }) over the plugin at
-- `plugin_path`, using `zip_path` for the download. Returns true, or nil and what went wrong; on failure the
-- installed plugin is untouched.
function Installer.install(asset, version, plugin_path, zip_path, fs)
    local expected = Installer.expectedDigest(asset)
    if not expected then return nil, _("this release has no checksum to verify it against") end
    local plan = Installer.plan(plugin_path)
    fs = fs or Installer.fs()
    local function fail(err)
        if fs.exists(plan.staging) then fs.purge(plan.staging) end
        os.remove(zip_path)
        return nil, err
    end
    local ok, err = Installer.download(asset.url, zip_path)
    if not ok then return fail(T(_("the download failed: %1"), tostring(err))) end
    local content = readFile(zip_path)
    if not content or (asset.size and #content ~= asset.size) then return fail(_("the download is not the size GitHub reported")) end
    if require("ffi/sha2").sha256(content) ~= expected then return fail(_("the download does not match its checksum")) end
    ok, err = Installer.extract(zip_path, plan)
    if not ok then return fail(err) end
    ok, err = Installer.validate(plan, version)
    if not ok then return fail(err) end
    ok, err = Installer.swap(plan, fs)
    if not ok then return fail(err) end
    os.remove(zip_path)
    return true
end

return Installer
