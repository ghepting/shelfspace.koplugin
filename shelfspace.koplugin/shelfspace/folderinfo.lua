-- The lines of text on a folder's dialog (the dialog itself is in details.lua), kept apart so the wording can be tested.
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Folderinfo = {}

-- `entry` is the folder, `place` where it sits ("Library" or a folder's name), `files` how many files are
-- Whether a lock is only that ShelfSpace does not recognise the file (or what is in the folder). KOReader's own file manager can
-- delete such a file, once its "Show unsupported files" setting is on, so the card says so.
function Folderinfo.unrecognised(reason)
    return reason == _("Not a book KOReader manages") or reason == _("Has files KOReader doesn't manage")
end

-- The "Locked" line of a card.
-- `shown` is whether the file manager is already showing files it cannot open, which decides what there is left to do.
function Folderinfo.lockedLine(reason, shown)
    local line = T(_("Locked: %1"), reason:sub(1, 1):lower() .. reason:sub(2))
    if Folderinfo.unrecognised(reason) then
        line = line .. "\n" .. (shown and _("KOReader's file manager can delete it: press and hold it there.")
            or _("KOReader's file manager can delete it: turn on Show unsupported files in its settings first."))
    end
    return line
end

-- under it, `reason` why it can't be deleted (nil when it can).
function Folderinfo.text(entry, place, files, reason, shown)
    local lines = { entry.name .. "/", "" }
    table.insert(lines, T(_("%1 · %2"), T(N_("%1 file", "%1 files", files), files), util.getFriendlySize(entry.size)))
    table.insert(lines, T(_("In: %1"), place))
    if entry.modified then
        table.insert(lines, T(_("Changed: %1"), os.date("%Y-%m-%d %H:%M", entry.modified)))
    end
    if reason then table.insert(lines, Folderinfo.lockedLine(reason, shown)) end
    return table.concat(lines, "\n")
end

return Folderinfo
