-- What Browse says when a folder, a search or a filter leaves nothing to show: a headline, a line saying
-- why, and the one action that undoes it (if there is one). `state` is what is in force:
--   query (the search text), ext (a file type like "pdf"), status ("complete" or "new"), place (where
--   we are: "Library" or a folder's name), has_parent (we can go up).
local _ = require("shelfspace/i18n")
local T = require("ffi/util").template

local Empty = {}

-- Returns { headline, line, action, label }; `action` is "search", "filter", "status", "all" or "up", or nil.
function Empty.describe(state)
    local place = state.place or _("Library")
    local count = (state.query and 1 or 0) + (state.ext and 1 or 0) + (state.status and 1 or 0)
    if count == 0 then
        return {
            headline = _("This folder is empty"), line = T(_("There is nothing in %1."), place),
            action = state.has_parent and "up" or nil, label = state.has_parent and _("Up") or nil,
        }
    end
    if count > 1 then
        return {
            headline = _("Nothing matches"), line = T(_("Nothing in %1 matches these filters."), place),
            action = "all", label = _("Clear all filters"),
        }
    end
    if state.query then
        return {
            headline = _("No matches"), line = T(_("Nothing in %1 matches “%2”."), place, state.query),
            action = "search", label = _("Clear search"),
        }
    elseif state.status == "new" then
        return {
            headline = _("No unread books"), line = _("Every book here has been opened."),
            action = "status", label = _("Show all files"),
        }
    elseif state.status == "complete" then
        return {
            headline = _("No finished books"), line = _("None of the books here are marked as finished."),
            action = "status", label = _("Show all files"),
        }
    end
    local kind = state.ext:upper()
    return {
        headline = T(_("No %1 files"), kind), line = T(_("There are no %1 files in %2."), kind, place),
        action = "filter", label = _("Clear filter"),
    }
end

return Empty
