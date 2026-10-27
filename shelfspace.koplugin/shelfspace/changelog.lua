-- The release notes of every ShelfSpace release, from GitHub's list of releases, as pages for a viewer.
-- Pure: the caller fetches and stores the list.
local Changelog = {}

-- What a "###" heading in release-please's notes is called in a bullet.
local SECTIONS = { ["Features"] = "New", ["Bug Fixes"] = "Fix", ["Performance Improvements"] = "Faster" }

-- The releases worth showing, newest first: the decoded answer of GitHub's /releases, without drafts,
-- pre-releases, entries that are not releases, and a tag listed twice.
function Changelog.entries(releases)
    local out, seen = {}, {}
    if type(releases) ~= "table" then return out end
    for _, release in ipairs(releases) do
        if type(release) == "table" and type(release.tag_name) == "string" and not release.draft
            and not release.prerelease and not seen[release.tag_name] then
            seen[release.tag_name] = true
            table.insert(out, {
                version = release.tag_name:gsub("^v", ""),
                date = tostring(release.published_at or ""):sub(1, 10),
                body = tostring(release.body or ""),
                page = release.html_url,
            })
        end
    end
    return out
end

-- Markdown as plain text: a link is its text, and bold and code lose their marks.
local function plain(text)
    return (text:gsub("%[([^%]]*)%]%([^%)]*%)", "%1"):gsub("%*%*([^*]+)%*%*", "%1"):gsub("`", ""):gsub("%s+$", ""))
end

-- One release as the viewer's text: its version and date, then its notes as "- New: ..." and "- Fix: ..." lines.
function Changelog.render(entry)
    local lines = { string.format("v%s  (%s)", entry.version, entry.date), "" }
    local section
    for line in entry.body:gmatch("[^\r\n]+") do
        local heading = line:match("^###%s*(.-)%s*$")
        if heading then
            section = SECTIONS[heading] or heading
        elseif not line:match("^##%s") and not line:match("^%s*$") then
            local bullet = line:match("^%s*[%*%-]%s+(.*)$")
            if bullet then
                local prefix = section and section ~= "" and (section .. ": ") or ""
                table.insert(lines, "- " .. prefix .. plain(bullet))
            else
                table.insert(lines, plain(line))
            end
        end
    end
    if #lines == 2 then table.insert(lines, "No notes for this release.") end
    return table.concat(lines, "\n")
end

return Changelog
