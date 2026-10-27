local T = dofile((debug.getinfo(1, "S").source:match("^@(.*)/[^/]+$") or ".") .. "/helper.lua")
local Changelog = require("shelfspace/changelog")

print("the changelog")

local function release(tag, body, extra)
    local r = { tag_name = tag, published_at = "2026-10-26T18:44:50Z", body = body, html_url = "https://example/" .. tag }
    for k, v in pairs(extra or {}) do r[k] = v end
    return r
end

T.test("releases come out newest first, as listed, without drafts, pre-releases or repeats", function()
    local list = Changelog.entries({
        release("v0.6.0", "a"), release("v0.6.0", "again"), release("v0.6.0-rc1", "b", { prerelease = true }),
        release("v0.5.0", "c"), release("v0.4.9", "d", { draft = true }), { not_a_release = true }, "junk",
    })
    T.eq(#list, 2)
    T.eq(list[1].version, "0.6.0")
    T.eq(list[2].version, "0.5.0")
    T.eq(list[1].date, "2026-10-26")
end)

T.test("an answer that is not a list gives no releases", function()
    T.eq(#Changelog.entries(nil), 0)
    T.eq(#Changelog.entries({ message = "rate limited" }), 0)
end)

T.test("a release's notes read as plain bullets under their kind", function()
    local text = Changelog.render(Changelog.entries({
        release("v0.4.0", "### Features\n\n* About: an info icon ([#53](https://x/53)) ([1ac0fd5](https://x/c))\n\n### Bug Fixes\n\n* keep **bold** and `code` plain"),
    })[1])
    T.eq(text, "v0.4.0  (2026-10-26)\n\n- New: About: an info icon (#53) (1ac0fd5)\n- Fix: keep bold and code plain")
end)

T.test("the version heading that release-please repeats is left out", function()
    local text = Changelog.render(Changelog.entries({ release("v0.1.0", "## [0.1.0](https://x) (2026-10-26)\n\n### Features\n\n* first") })[1])
    T.eq(text, "v0.1.0  (2026-10-26)\n\n- New: first")
end)

T.test("a release with no notes says so", function()
    T.eq(Changelog.render(Changelog.entries({ release("v0.1.0", "") })[1]), "v0.1.0  (2026-10-26)\n\nNo notes for this release.")
end)

T.done()
