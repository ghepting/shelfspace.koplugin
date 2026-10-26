-- Asking GitHub whether a newer ShelfSpace has been released. Nothing here runs unless the person taps
-- "Check for updates": no background checks, and nothing is sent but the request itself.
local Version = require("shelfspace/version")
local _ = require("shelfspace/i18n")
local T = require("ffi/util").template

local Updater = {
    REPO = "ghepting/shelfspace.koplugin",
    ASSET = "shelfspace.koplugin.zip", -- the zip every release carries
}
Updater.API = "https://api.github.com/repos/" .. Updater.REPO .. "/releases/latest"

-- What a release (GitHub's JSON, decoded) means for someone running `current`:
-- { state = "available" | "current" | "ahead" | "unknown" | "error", latest, date, notes, page, asset, message }.
-- "ahead" is a build newer than the latest release (a checkout of the source); "unknown" is a version
-- that can't be compared.
function Updater.interpret(release, current)
    if type(release) ~= "table" or type(release.tag_name) ~= "string" then
        return { state = "error", message = "GitHub's answer was not a release" }
    end
    local latest = release.tag_name:gsub("^v", "")
    local asset
    for _, a in ipairs(release.assets or {}) do
        if a.name == Updater.ASSET then
            asset = { url = a.browser_download_url, size = a.size, digest = a.digest }
        end
    end
    local result = {
        latest = latest, date = tostring(release.published_at or ""):sub(1, 10), notes = release.body or "",
        page = release.html_url, asset = asset,
    }
    local order = Version.compare(current, latest)
    result.state = order == nil and "unknown" or order < 0 and "available" or order == 0 and "current" or "ahead"
    return result
end

-- At most `max` lines of release notes, with a mark when more were left out.
local function trimNotes(notes, max)
    local lines, count = {}, 0
    for line in tostring(notes):gmatch("[^\r\n]+") do
        -- Release notes are Markdown: the version heading repeats the title, other headings become plain
        -- labels, and a link is just its text.
        line = line:gsub("%[([^%]]*)%]%([^%)]*%)", "%1"):gsub("^###%s*", ""):gsub("%s+$", "")
        if line:match("^##%s") then line = "" end
        if not line:match("^%s*$") then
            count = count + 1
            if count <= max then table.insert(lines, line) end
        end
    end
    if count > max then table.insert(lines, "…") end
    return table.concat(lines, "\n")
end

-- The card's text for a result of Updater.interpret / Updater.check, for someone running `current`.
function Updater.message(result, current)
    if result.state == "available" then
        local lines = { T(_("ShelfSpace %1 is available"), result.latest), T(_("Released %1 · you have %2"), result.date, current) }
        local notes = trimNotes(result.notes, 12)
        if notes ~= "" then table.insert(lines, ""); table.insert(lines, notes) end
        return table.concat(lines, "\n")
    elseif result.state == "current" then
        return T(_("You are up to date\n\nShelfSpace %1 is the latest release."), current)
    elseif result.state == "ahead" then
        return T(_("This build (%1) is newer than the latest release (%2)."), current, result.latest)
    elseif result.state == "unknown" then
        return T(_("The latest release is %1, but this build's version could not be compared with it."), result.latest)
    end
    return T(_("Could not check for updates\n\n%1"), result.message or "")
end

-- GET `url` and return its body, or nil and why not. Blocks for up to the timeouts.
function Updater.get(url)
    local http = require("socket.http")
    local ltn12 = require("ltn12")
    local socket = require("socket")
    local socketutil = require("socketutil")
    local chunks = {}
    socketutil:set_timeout(10, 30)
    local code, _, status = socket.skip(1, http.request {
        url = url, method = "GET", sink = ltn12.sink.table(chunks),
        headers = { ["User-Agent"] = "ShelfSpace", Accept = "application/vnd.github+json" },
    })
    socketutil:reset_timeout()
    if code ~= 200 then
        if code == 403 or code == 429 then return nil, "GitHub is limiting requests right now; try again later" end
        return nil, status or tostring(code or "no connection")
    end
    return table.concat(chunks)
end

-- The latest release as Updater.interpret describes it, fetched now.
function Updater.check(current)
    local body, err = Updater.get(Updater.API)
    if not body then return { state = "error", message = err } end
    local JSON = require("json")
    local ok, release = pcall(JSON.decode, body)
    if not ok then return { state = "error", message = "GitHub's answer could not be read" } end
    return Updater.interpret(release, current)
end

return Updater
