-- What the About card says: which ShelfSpace this is, where it was built, and what it runs on. The facts
-- are gathered in About.info and turned into text in About.lines, so the wording can be tested.
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template
local Version = require("shelfspace/version")

local About = {
    REPO = "ghepting/shelfspace.koplugin",
    LICENSE = "MIT",
}

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- Everything About.lines needs. `plugin_path` is the plugin's folder. The release workflow adds build.lua
-- (tag, commit, date) to the zip; a source checkout has none, and is called a development build.
function About.info(plugin_path)
    local info = { version = Version.fromMeta(readFile(plugin_path .. "/_meta.lua")) or "?" }
    local chunk = loadfile(plugin_path .. "/build.lua")
    if chunk then
        local ok, build = pcall(chunk)
        if ok and type(build) == "table" then info.build = build end
    end
    local Device = require("device")
    info.device = Device.model
    -- "v2026.07.1", without the nightly build suffix some builds carry after an underscore.
    info.koreader = tostring(require("version"):getCurrentRevision()):match("^[^_]+")
    return info
end

-- The card's text. `info` is About.info's table, plus `library` (a path) and `usage` ({ total, available }) when known.
function About.lines(info)
    local lines = { T(_("ShelfSpace %1"), info.version), "" }
    if info.build then
        table.insert(lines, T(_("Released %1 · commit %2"), info.build.date or "?", info.build.commit or "?"))
    else
        table.insert(lines, _("A development build, not a release"))
    end
    if info.koreader or info.device then
        table.insert(lines, T(_("KOReader %1 on %2"), info.koreader or "?", info.device or "?"))
    end
    if info.library then
        local free = info.usage and info.usage.total and info.usage.total > 0
            and T(_(" (%1 free of %2)"), util.getFriendlySize(info.usage.available), util.getFriendlySize(info.usage.total)) or ""
        table.insert(lines, T(_("Library: %1%2"), info.library, free))
    end
    table.insert(lines, T(_("%1 license · github.com/%2"), About.LICENSE, About.REPO))
    return table.concat(lines, "\n")
end

-- A URL-safe version of `text`.
local function escape(text)
    return (tostring(text):gsub("[^%w%-%._~]", function(c) return string.format("%%%02X", c:byte()) end))
end

-- The "report a problem" form with what we know already filled in: the device, KOReader and ShelfSpace versions.
function About.issueUrl(info)
    return string.format("https://github.com/%s/issues/new?template=bug_report.yml&device=%s&koreader=%s&version=%s",
        About.REPO, escape(info.device or ""), escape(info.koreader or ""), escape(info.version or ""))
end

function About.repoUrl() return "https://github.com/" .. About.REPO end

function About.releasesUrl() return "https://github.com/" .. About.REPO .. "/releases" end

return About
