-- How far through a book you are, from KOReader's book info (BookList.getBookInfo), as the text of the
-- "% Read" column: 0% to 99%, or "Read" for a finished book.
local _ = require("gettext")
local T = require("ffi/util").template

local Progress = {}

function Progress.cell(info)
    if not info or not info.been_opened then return T(_("%1%"), 0) end
    local fraction = tonumber(info.percent_finished) or 0
    if info.status == "complete" or fraction >= 1 then return _("Read") end
    -- Rounded down, so only a finished book ever says 100%.
    return T(_("%1%"), math.max(0, math.floor(fraction * 100)))
end

-- The same, as a share of the book from 0 to 1 (a finished book is 1), for a meter.
function Progress.fraction(info)
    if not info or not info.been_opened then return 0 end
    local fraction = tonumber(info.percent_finished) or 0
    if info.status == "complete" or fraction >= 1 then return 1 end
    return math.max(0, math.min(1, fraction))
end

return Progress
