-- How far through a book you are, from KOReader's book info (BookList.getBookInfo): a fraction for the
-- bar and the words for the label.
local _ = require("gettext")
local T = require("ffi/util").template

local Progress = {}

-- Every label this can return, widest last, so a row can reserve room for the longest.
function Progress.samples()
    return { _("Finished"), _("Not started"), T(_("%1% read"), 100), T(_("<%1% read"), 1) }
end

function Progress.describe(info)
    if not info or not info.been_opened then return { fraction = 0, label = _("Not started") } end
    if info.status == "complete" then return { fraction = 1, label = _("Finished") } end
    local fraction = tonumber(info.percent_finished)
    if not fraction or fraction <= 0 then return { fraction = 0, label = _("Not started") } end
    fraction = math.min(fraction, 1)
    local percent = math.floor(fraction * 100 + 0.5)
    return { fraction = fraction, label = percent < 1 and T(_("<%1% read"), 1) or T(_("%1% read"), percent) }
end

return Progress
