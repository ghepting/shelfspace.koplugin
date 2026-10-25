local T = require("helper")
local lfs = require("libs/libkoreader-lfs")

-- A fake disk: dirs[path] = { mtime, files = { name = size }, subs = { names } }.
local dirs, listed
lfs.attributes = function(path, what) return dirs[path] and dirs[path].mtime end
lfs.dir = function(path)
    listed[#listed + 1] = path
    local d = dirs[path]
    local names = { ".", ".." }
    for n in pairs(d.files) do names[#names + 1] = n end
    for _, n in ipairs(d.subs) do names[#names + 1] = n end
    local i = 0
    return function() i = i + 1 return names[i] end, {}
end
lfs.symlinkattributes = function(path)
    if dirs[path] then return { mode = "directory", modification = dirs[path].mtime } end
    local dir, name = path:match("(.*)/([^/]+)$")
    local size = dirs[dir] and dirs[dir].files[name]
    return size and { mode = "file", size = size, modification = 1 } or nil
end
package.loaded["ui/uimanager"] = { scheduleIn = function(_, _, fn) fn() end }
package.loaded["shelfspace/scanner"] = nil
local Scanner = require("shelfspace/scanner")
local ScanCache = require("shelfspace/scancache")

local function disk()
    listed = {}
    dirs = {
        ["/lib"] = { mtime = 10, files = { ["a.epub"] = 100 }, subs = { "Manga" } },
        ["/lib/Manga"] = { mtime = 20, files = { ["b.cbz"] = 400 }, subs = {} },
    }
end

local function scan(previous)
    local out
    Scanner.scan("/lib", function(t) out = t end, previous)
    return out
end

T.test("a scan totals every folder", function()
    disk()
    local tree = scan()
    T.eq(tree["/lib"].size, 500)
    T.eq(tree["/lib/Manga"].modified, 20)
end)

T.test("folders that have not changed are not read again, changed ones are", function()
    disk()
    local first = scan()
    listed = {}
    local second = scan(first)
    T.eq(#listed, 0, "folders read")
    T.eq(second["/lib"].size, 500)
    dirs["/lib/Manga"].mtime = 21
    dirs["/lib/Manga"].files["c.cbz"] = 50
    listed = {}
    local third = scan(second)
    T.eq(table.concat(listed, ","), "/lib/Manga")
    T.eq(third["/lib"].size, 550)
end)

T.test("a change deep down is found even when the folders above it look the same", function()
    disk()
    local first = scan()
    dirs["/lib/Manga"].mtime = 30
    dirs["/lib/Manga"].files["b.cbz"] = nil
    local second = scan(first)
    T.eq(second["/lib"].size, 100)
end)

T.test("the saved scan comes back for the same library, and only that one", function()
    disk()
    local tree = scan()
    local path = os.tmpname()
    assert(ScanCache.save(path, "/lib", tree, "/lib/none"))
    local back = ScanCache.load(path, "/lib")
    T.eq(back["/lib"].size, 500)
    T.eq(back["/lib/Manga"].entries[1].name, "b.cbz")
    T.eq(ScanCache.load(path, "/other"), nil, "another library")
    os.remove(path)
    T.eq(ScanCache.load(path, "/lib"), nil, "missing file")
end)

T.test("the KOReader data folder is not saved", function()
    disk()
    local tree = scan()
    local path = os.tmpname()
    ScanCache.save(path, "/lib", tree, "/lib/Manga")
    local back = ScanCache.load(path, "/lib")
    T.eq(back["/lib/Manga"], nil)
    assert(back["/lib"])
    os.remove(path)
end)

T.done()
