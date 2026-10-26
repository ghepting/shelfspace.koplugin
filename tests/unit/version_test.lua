local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Version = require("shelfspace/version")

print("version")

T.test("a release number is read with or without a leading v", function()
    T.eq(table.concat(Version.parse("0.3.0"), "."), "0.3.0")
    T.eq(table.concat(Version.parse("v12.4.19"), "."), "12.4.19")
    T.eq(Version.parse("nonsense"), nil)
    T.eq(Version.parse(nil), nil)
end)

T.test("versions compare number by number, not as text", function()
    T.eq(Version.compare("0.3.0", "0.3.1"), -1)
    T.eq(Version.compare("0.3.1", "0.3.0"), 1)
    T.eq(Version.compare("v0.3.0", "0.3.0"), 0)
    T.eq(Version.compare("0.9.0", "0.10.0"), -1, "10 is more than 9")
    T.eq(Version.compare("1.0.0", "0.99.99"), 1)
    T.eq(Version.compare("0.3.0", "oops"), nil)
end)

T.test("the version is found in a _meta.lua", function()
    T.eq(Version.fromMeta('return {\n    fullname = "ShelfSpace",\n    version = "0.3.0", -- x-release-please-version\n}'), "0.3.0")
    T.eq(Version.fromMeta("return {}"), nil)
    T.eq(Version.fromMeta(nil), nil)
end)

T.done()
