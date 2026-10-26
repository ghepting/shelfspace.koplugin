local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Installer = require("shelfspace/installer")

print("installer")

T.test("the checksum is read from GitHub's digest, and only when it is a full SHA-256", function()
    local hex = ("ab"):rep(32)
    T.eq(Installer.expectedDigest({ digest = "sha256:" .. hex }), hex)
    T.eq(Installer.expectedDigest({ digest = "sha256:" .. hex:upper() }), hex, "upper case is read as lower")
    T.eq(Installer.expectedDigest({ digest = "sha256:abc" }), nil, "too short")
    T.eq(Installer.expectedDigest({ digest = "md5:" .. hex }), nil)
    T.eq(Installer.expectedDigest({}), nil)
    T.eq(Installer.expectedDigest(nil), nil)
end)

T.test("a path in the zip lands inside the plugin folder, or is refused", function()
    local n = "shelfspace.koplugin"
    T.eq(Installer.relative(n .. "/", n), "")
    T.eq(Installer.relative(n .. "/main.lua", n), "main.lua")
    T.eq(Installer.relative(n .. "/shelfspace/views/browse.lua", n), "shelfspace/views/browse.lua")
    T.eq(Installer.relative(n .. "/shelfspace/", n), "shelfspace")
    T.eq(Installer.relative("other.koplugin/main.lua", n), nil, "another folder")
    T.eq(Installer.relative("/etc/passwd", n), nil, "an absolute path")
    T.eq(Installer.relative(n .. "/../evil.lua", n), nil, "climbing out")
    T.eq(Installer.relative(n .. "/a/../../evil.lua", n), nil, "climbing out, further in")
    T.eq(Installer.relative(n .. "//x.lua", n), nil, "an empty part")
    T.eq(Installer.relative(n .. "/a\\b.lua", n), nil, "a backslash")
    T.eq(Installer.relative(n .. "xx/main.lua", n), nil, "a folder that only starts like it")
    T.eq(Installer.relative(n .. "/a..b.lua", n), "a..b.lua", "dots inside a name are fine")
end)

T.test("the staging and old folders sit beside the plugin, where KOReader will not load them", function()
    local p = Installer.plan("/mnt/onboard/.adds/koreader/plugins/shelfspace.koplugin")
    T.eq(p.dir, "/mnt/onboard/.adds/koreader/plugins")
    T.eq(p.name, "shelfspace.koplugin")
    T.eq(p.staging, "/mnt/onboard/.adds/koreader/plugins/.shelfspace-update")
    T.eq(p.incoming, "/mnt/onboard/.adds/koreader/plugins/.shelfspace-update/shelfspace.koplugin")
    T.eq(p.old, "/mnt/onboard/.adds/koreader/plugins/shelfspace.koplugin.old")
    assert(not p.staging:match("%.koplugin$") and not p.old:match("%.koplugin$"))
end)

-- A folder tree in a table, with the three operations swap needs.
local function fakeFs(tree, fail_on)
    local log, failed = {}, false
    return {
        log = log, tree = tree,
        exists = function(p) return tree[p] ~= nil end,
        rename = function(a, b)
            log[#log + 1] = "rename " .. a:match("[^/]+$") .. " -> " .. b:match("[^/]+$")
            if fail_on == b and not failed then failed = true return false end -- the first try fails, as one real step would
            tree[b], tree[a] = tree[a], nil
            return true
        end,
        purge = function(p) log[#log + 1] = "purge " .. p:match("[^/]+$"); tree[p] = nil end,
    }
end

T.test("swapping moves the old one aside, the new one in, and clears the staging folder", function()
    local plan = Installer.plan("/p/shelfspace.koplugin")
    local fs = fakeFs({ [plan.current] = "v1", [plan.incoming] = "v2", [plan.staging] = "dir" })
    T.eq(Installer.swap(plan, fs), true)
    T.eq(fs.tree[plan.current], "v2"); T.eq(fs.tree[plan.old], "v1"); T.eq(fs.tree[plan.staging], nil)
end)

T.test("an earlier .old copy is replaced, not piled up", function()
    local plan = Installer.plan("/p/shelfspace.koplugin")
    local fs = fakeFs({ [plan.current] = "v2", [plan.incoming] = "v3", [plan.old] = "v1" })
    T.eq(Installer.swap(plan, fs), true)
    T.eq(fs.tree[plan.old], "v2")
    T.eq(fs.log[1], "purge shelfspace.koplugin.old")
end)

T.test("if the new one cannot be moved in, the old one is put back and nothing is lost", function()
    local plan = Installer.plan("/p/shelfspace.koplugin")
    local fs = fakeFs({ [plan.current] = "v1", [plan.incoming] = "v2" }, plan.current)
    local ok, err = Installer.swap(plan, fs)
    T.eq(ok, nil)
    assert(err:find("current one was kept", 1, true), err)
    T.eq(fs.tree[plan.current], "v1", "the installed version is back")
    T.eq(fs.tree[plan.incoming], "v2", "the download is still staged")
end)

T.test("if the current one cannot be moved aside, nothing changes", function()
    local plan = Installer.plan("/p/shelfspace.koplugin")
    local fs = fakeFs({ [plan.current] = "v1", [plan.incoming] = "v2" }, plan.old)
    local ok, err = Installer.swap(plan, fs)
    T.eq(ok, nil)
    T.eq(fs.tree[plan.current], "v1")
end)

T.test("a release with no checksum is refused before anything is downloaded", function()
    local ok, err = Installer.install({ url = "http://example/z.zip" }, "0.4.0", "/p/shelfspace.koplugin", "/tmp/never.zip", fakeFs({}))
    T.eq(ok, nil)
    assert(err:find("no checksum", 1, true), err)
end)

T.done()
