-- The summary ShelfSpace saved after its last scan, with the free space read live: what the Bookshelf pieces draw from. Needs KOReader
-- (its settings and util.diskUsage), so unlike summary.lua it does not run under the plain tests.
local Summary = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/summary.lua")

local Live = {}

-- Returns the summary and whether it came from a scan (false: only the free space is known), or nil when not even that is.
function Live.read()
    local saved = Summary.valid(G_reader_settings:readSetting(Summary.KEY))
    -- Free space is cheap to read, so it is live. What is on the device comes from the last scan.
    local ok, usage = pcall(function()
        local util = require("util")
        local root = G_reader_settings:readSetting("home_dir") or require("datastorage"):getDataDir()
        return util.diskUsage(root)
    end)
    if ok and usage and usage.total and usage.total > 0 then
        local s = saved or { v = 1, time = 0, books = 0, koreader = 0, other = 0, duplicates = 0, duplicate_sets = 0, koreader_clearable = 0 }
        s.total, s.free = usage.total, math.min(usage.available or usage.free or 0, usage.total)
        return s, saved ~= nil
    end
    return saved, saved ~= nil
end

return Live
