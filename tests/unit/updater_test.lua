local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Updater = require("shelfspace/updater")

print("updater")

local function release(tag, assets)
    return { tag_name = tag, published_at = "2026-10-26T14:03:11Z", body = "Notes here", html_url = "https://example/r",
             assets = assets or { { name = "shelfspace.koplugin.zip", browser_download_url = "https://example/z.zip", size = 49109, digest = "sha256:abc" } } }
end

T.test("a newer release is available, with its date, notes, page and the zip to download", function()
    local r = Updater.interpret(release("v0.4.0"), "0.3.0")
    T.eq(r.state, "available"); T.eq(r.latest, "0.4.0"); T.eq(r.date, "2026-10-26"); T.eq(r.notes, "Notes here")
    T.eq(r.page, "https://example/r"); T.eq(r.asset.url, "https://example/z.zip"); T.eq(r.asset.digest, "sha256:abc"); T.eq(r.asset.size, 49109)
end)

T.test("the same release is up to date, an older one means this build is ahead", function()
    T.eq(Updater.interpret(release("v0.3.0"), "0.3.0").state, "current")
    T.eq(Updater.interpret(release("v0.2.9"), "0.3.0").state, "ahead")
end)

T.test("a version that can't be compared is unknown, not a false 'up to date'", function()
    T.eq(Updater.interpret(release("v0.3.0"), "?").state, "unknown")
end)

T.test("a release without the zip still reports, with no asset to download", function()
    local r = Updater.interpret(release("v0.4.0", { { name = "something-else.txt" } }), "0.3.0")
    T.eq(r.state, "available"); T.eq(r.asset, nil)
end)

T.test("an answer that is not a release is an error", function()
    T.eq(Updater.interpret(nil, "0.3.0").state, "error")
    T.eq(Updater.interpret({ message = "Not Found" }, "0.3.0").state, "error")
end)

T.test("it asks GitHub's latest-release address for this repository", function()
    T.eq(Updater.API, "https://api.github.com/repos/ghepting/shelfspace.koplugin/releases/latest")
end)

T.test("the card says what is available, since when, and the notes, cut to twelve lines", function()
    local notes = {}
    for n = 1, 20 do notes[#notes + 1] = "* change " .. n end
    local r = Updater.interpret({ tag_name = "v0.4.0", published_at = "2026-11-02T10:00:00Z", body = table.concat(notes, "\r\n\r\n"), assets = {} }, "0.3.0")
    local text = Updater.message(r, "0.3.0")
    assert(text:find("ShelfSpace 0.4.0 is available", 1, true), text)
    assert(text:find("Released 2026-11-02 · you have 0.3.0", 1, true), text)
    assert(text:find("* change 12", 1, true) and not text:find("* change 13", 1, true), text)
    assert(text:find("…", 1, true), text)
end)

T.test("the card for no update says you are up to date, or why it could not tell", function()
    assert(Updater.message({ state = "current", latest = "0.3.0" }, "0.3.0"):find("You are up to date", 1, true))
    assert(Updater.message({ state = "ahead", latest = "0.2.0" }, "0.3.0"):find("newer than the latest release (0.2.0)", 1, true))
    assert(Updater.message({ state = "unknown", latest = "0.4.0" }, "?"):find("could not be compared", 1, true))
    local err = Updater.message({ state = "error", message = "no connection" }, "0.3.0")
    assert(err:find("Could not check for updates", 1, true) and err:find("no connection", 1, true), err)
end)

T.test("release notes lose their Markdown: no repeated title, plain section labels, links as their text", function()
    local body = "## [0.4.0](https://github.com/x/compare/v0.3.0...v0.4.0) (2026-11-02)\r\n\r\n### Features\r\n\r\n* See the [release page](https://example/r) now\r\n\r\n### Bug Fixes\r\n\r\n* A fix"
    local text = Updater.message(Updater.interpret({ tag_name = "v0.4.0", published_at = "2026-11-02T10:00:00Z", body = body }, "0.3.0"), "0.3.0")
    assert(not text:find("##", 1, true) and not text:find("](", 1, true) and not text:find("compare", 1, true), text)
    assert(text:find("\nFeatures\n* See the release page now\nBug Fixes\n* A fix", 1, true), text)
end)

T.done()
