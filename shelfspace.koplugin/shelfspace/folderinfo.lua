-- The lines of text on a folder's dialog (the dialog itself is in details.lua), kept apart so the wording can be tested.
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Folderinfo = {}

-- `entry` is the folder, `place` where it sits ("Library" or a folder's name), `files` how many files are
-- under it, `reason` why it can't be deleted (nil when it can).
function Folderinfo.text(entry, place, files, reason)
    local lines = { entry.name .. "/", "" }
    table.insert(lines, T(_("%1 · %2"), T(N_("%1 file", "%1 files", files), files), util.getFriendlySize(entry.size)))
    table.insert(lines, T(_("In: %1"), place))
    if entry.modified then
        table.insert(lines, T(_("Changed: %1"), os.date("%Y-%m-%d %H:%M", entry.modified)))
    end
    if reason then table.insert(lines, T(_("Locked: %1"), reason:sub(1, 1):lower() .. reason:sub(2))) end
    return table.concat(lines, "\n")
end

return Folderinfo
