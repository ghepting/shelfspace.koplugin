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

-- A library three folders deep: /lib/A/B, with a book and its sidecar in each.
local function deep()
    listed = {}
    dirs = {
        ["/lib"] = { mtime = 1, files = { ["top.epub"] = 1000 }, subs = { "A" } },
        ["/lib/A"] = { mtime = 1, files = { ["a.epub"] = 200 }, subs = { "B", "a.sdr" } },
        ["/lib/A/a.sdr"] = { mtime = 1, files = { ["metadata.epub.lua"] = 7 }, subs = {} },
        ["/lib/A/B"] = { mtime = 1, files = { ["b.pdf"] = 3000, ["c.epub"] = 40 }, subs = { "C" } },
        ["/lib/A/B/C"] = { mtime = 1, files = { ["d.cbz"] = 500 }, subs = {} },
    }
end

local function find(tree, dir, name)
    for _, e in ipairs(tree[dir].entries) do if e.name == name then return e end end
end

-- What every folder and folder row adds up to, read off the tree.
local function sizes(tree)
    local out = {}
    for path, node in pairs(tree) do
        out[path] = node.size
        for _, e in ipairs(node.entries) do if e.is_dir then out[e.path .. " (row)"] = e.size end end
    end
    return out
end

T.test("removing a book takes it and its sidecar off every folder above it, and nothing else", function()
    deep()
    local tree = scan()
    Scanner.remove(tree, "/lib", "/lib/A", find(tree, "/lib/A", "a.epub"))
    local got = sizes(tree)
    T.eq(got["/lib/A"], 3540)
    T.eq(got["/lib/A (row)"], 3540)
    T.eq(got["/lib"], 4540)
    T.eq(got["/lib/A/B"], 3540, "a folder beside it")
    T.eq(tree["/lib/A/a.sdr"], nil, "the sidecar is gone from the tree")
    T.eq(find(tree, "/lib/A", "a.sdr"), nil, "and from its folder's listing")
end)

T.test("removing a folder forgets everything under it", function()
    deep()
    local tree = scan()
    Scanner.remove(tree, "/lib", "/lib/A", find(tree, "/lib/A", "B"))
    T.eq(tree["/lib/A/B"], nil)
    T.eq(tree["/lib/A/B/C"], nil)
    T.eq(tree["/lib/A"].size, 207)
    T.eq(tree["/lib"].size, 1207)
end)

T.test("removing many, one at a time, ends where adding the whole tree up again would", function()
    deep()
    local tree = scan()
    Scanner.remove(tree, "/lib", "/lib/A/B/C", find(tree, "/lib/A/B/C", "d.cbz"))
    Scanner.remove(tree, "/lib", "/lib/A/B", find(tree, "/lib/A/B", "c.epub"))
    Scanner.remove(tree, "/lib", "/lib", find(tree, "/lib", "top.epub"))
    local step = sizes(tree)
    Scanner.total(tree, "/lib")
    for path, size in pairs(sizes(tree)) do T.eq(step[path], size, path) end
    T.eq(tree["/lib"].size, 3207)
end)

T.test("the saved scan keeps what each entry is: a file, a folder or a sidecar, its size and when it changed", function()
    deep()
    local tree = scan()
    local path = os.tmpname()
    assert(ScanCache.save(path, "/lib", tree))
    local back = ScanCache.load(path, "/lib")
    local a = find(back, "/lib/A", "a.epub")
    T.eq(a.path, "/lib/A/a.epub")
    T.eq(a.size, 200)
    T.eq(a.modified, 1)
    T.eq(a.is_dir, nil)
    local sdr = find(back, "/lib/A", "a.sdr")
    T.eq(sdr.is_dir, true)
    T.eq(sdr.hidden, true)
    local b = find(back, "/lib/A", "B")
    T.eq(b.is_dir, true)
    T.eq(b.hidden, nil)
    T.eq(back["/lib/A/B"].modified, 1)
    -- Used as the previous scan, it gives the same totals as reading the disk.
    listed = {}
    local again = scan(back)
    T.eq(#listed, 0, "folders read")
    T.eq(again["/lib"].size, tree["/lib"].size)
    os.remove(path)
end)

T.test("a folder with a name the lines cannot hold is left out, so it is read again", function()
    deep()
    local tree = scan()
    table.insert(tree["/lib/A/B"].entries, { name = "odd\tname.epub", path = "/lib/A/B/odd\tname.epub", size = 1, modified = 1 })
    local path = os.tmpname()
    ScanCache.save(path, "/lib", tree)
    local back = ScanCache.load(path, "/lib")
    T.eq(back["/lib/A/B"], nil)
    assert(back["/lib/A"])
    os.remove(path)
end)

T.test("a scan saved by an older ShelfSpace, or anything else, is not used", function()
    local path = os.tmpname()
    local f = io.open(path, "w")
    f:write('return { root = "/lib", tree = {} }')
    f:close()
    T.eq(ScanCache.load(path, "/lib"), nil, "the old Lua file")
    f = io.open(path, "w")
    f:write("shelfspace-scan 2\t/lib\nD\t\t1\t/lib\ngarbage\n")
    f:close()
    T.eq(ScanCache.load(path, "/lib"), nil, "a line that is not ours")
    os.remove(path)
end)

T.done()
