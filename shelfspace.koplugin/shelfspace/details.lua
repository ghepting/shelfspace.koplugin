local ButtonDialog = require("ui/widget/buttondialog")
local DocSettings = require("docsettings")
local DocumentRegistry = require("document/documentregistry")
local Folderinfo = require("shelfspace/folderinfo")
local Stats = require("shelfspace/stats")
local UIManager = require("ui/uimanager")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template

-- A short card about one file, so a person can tell what it is before keeping or deleting it.
local Details = {}

-- "Manga/Vol 1" for a file in <root>/Manga/Vol 1; "Library" for the library itself.
local function whereIs(root, dir)
    local rel = dir:sub(#root + 2)
    return rel ~= "" and rel or _("Library")
end

-- What KOReader remembers about reading it, or nil for a file it has never opened.
local function readingLine(path)
    if not DocSettings:hasSidecarFile(path) then return nil end
    local settings = DocSettings:open(path)
    local summary = settings:readSetting("summary")
    if summary and summary.status == "complete" then return _("Finished") end
    local percent = settings:readSetting("percent_finished")
    if percent and percent > 0 then return T(_("Read %1%"), math.floor(percent * 100 + 0.5)) end
    return _("Opened, not started")
end

local function propsLines(path)
    if not DocSettings:hasSidecarFile(path) then return {} end
    local props = DocSettings:open(path):readSetting("doc_props") or {}
    local lines = {}
    if props.title and props.title ~= "" then table.insert(lines, T(_("Title: %1"), props.title)) end
    if props.authors and props.authors ~= "" then
        table.insert(lines, T(_("Author: %1"), (props.authors:gsub("\n", ", "))))
    end
    return lines
end

-- The facts shown for `entry`; `dir` is the folder it sits in, `reason` why it can't be deleted (or nil).
function Details.text(root, entry, dir, reason, book)
    local ext = entry.name:match("%.([^.]+)$")
    local lines = { entry.name, "" }
    table.insert(lines, ext and T(_("%1 · %2"), ext:upper(), util.getFriendlySize(entry.size))
        or util.getFriendlySize(entry.size))
    table.insert(lines, T(_("In: %1"), whereIs(root, dir)))
    if entry.modified then
        table.insert(lines, T(_("Changed: %1"), os.date("%Y-%m-%d %H:%M", entry.modified)))
    end
    if book then
        for _, line in ipairs(propsLines(entry.path)) do table.insert(lines, line) end
        table.insert(lines, readingLine(entry.path) or _("Never opened in KOReader"))
    else
        table.insert(lines, _("KOReader can't open this file type"))
    end
    if reason then table.insert(lines, T(_("Locked: %1"), reason:sub(1, 1):lower() .. reason:sub(2))) end
    return table.concat(lines, "\n")
end

function Details.show(plugin, entry, dir, reason)
    local book = DocumentRegistry:hasProvider(entry.path)
    local current = plugin.ui.document and plugin.ui.document.file == entry.path
    plugin:showDialog(function()
        local dialog
        local function act(fn)
            return function()
                UIManager:close(dialog)
                fn()
            end
        end
        local rows = {}
        if book then
            table.insert(rows, {
                {
                    text = current and _("Continue reading") or _("Open"),
                    callback = act(function() plugin:openBook(entry.path) end),
                },
                {
                    text = _("Book info"),
                    callback = function() plugin.ui.bookinfo:show(entry.path) end,
                },
            })
        end
        -- A book that was already open when ShelfSpace was can't be deleted; closing it here unlocks it.
        if current then
            table.insert(rows, { { text = _("Close book"), callback = act(function() plugin:closeBook() end) } })
        end
        local last = { { text = _("Close"), callback = act(function() end) } }
        if not reason then
            table.insert(last, 1, {
                text = _("Delete"),
                callback = act(function() plugin:confirmDelete(entry, dir) end),
            })
        end
        table.insert(rows, last)
        dialog = ButtonDialog:new{
            title = Details.text(plugin.root, entry, dir, reason, book),
            title_align = "center",
            buttons = rows,
        }
        return dialog
    end)
end

-- The card for a folder: what is in it, and what can be done with it. `reason` is why it can't be deleted.
function Details.showFolder(plugin, entry, dir, reason)
    local files = Stats.summarize(plugin.tree, entry.path).files -- the same count as the folder's own header
    local open_file = plugin.ui.document and plugin.ui.document.file
    local holds_open_book = open_file and open_file:sub(1, #entry.path + 1) == entry.path .. "/"
    plugin:showDialog(function()
        local dialog
        local function act(fn)
            return function()
                UIManager:close(dialog)
                fn()
            end
        end
        local rows = { { { text = _("Open"), callback = act(function() plugin.screen:setDir(entry.path) end) } } }
        if holds_open_book then
            table.insert(rows, { { text = _("Close book"), callback = act(function() plugin:closeBook() end) } })
        end
        local last = { { text = _("Close"), callback = act(function() end) } }
        if not reason then
            table.insert(last, 1, { text = _("Delete"), callback = act(function() plugin:confirmDelete(entry, dir) end) })
        end
        table.insert(rows, last)
        dialog = ButtonDialog:new{
            title = Folderinfo.text(entry, whereIs(plugin.root, dir), files, reason),
            title_align = "center",
            buttons = rows,
        }
        return dialog
    end)
end

return Details
