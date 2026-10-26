local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
local LineWidget = require("ui/widget/linewidget")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local BookList = require("ui/widget/booklist")
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Duplicates = require("shelfspace/duplicates")
local Progress = require("shelfspace/progress")
local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(60)

-- Why the copy marked to keep was chosen, in a sentence.
local function why(set)
    local reasons = {
        reading = _("You are reading this copy."),
        progress = _("You have read the most of this copy."),
        format = T(_("%1 reads best on an e-ink screen."), Duplicates.extension(set.copies[1].name):upper()),
        location = _("This copy is nearest the top of your library."),
        newest = _("This copy is the newest."),
    }
    return reasons[set.reason] or ""
end

local function kindText(set)
    return set.kind == "exact" and _("Same file") or _("Same book")
end

-- A copy's folder, relative to the library, for a line under its name.
local function whereIs(plugin, copy)
    local dir = copy.path:match("^(.*)/[^/]+$") or plugin.root
    local rel = dir:sub(#plugin.root + 2)
    return rel == "" and _("Library") or rel
end

-- The duplicates list, and, once a set is picked, that set's copies to choose between.
return function(screen, th, width)
    local plugin = screen.plugin
    local sets = plugin.duplicates or {}
    local up = function() screen:switchTab("overview") end
    local gap = sp(10)
    local line = Size.line.thin

    local function topRow(glyph, label, on_tap)
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, background = th.white,
            VerticalGroup:new{
                align = "left",
                HorizontalGroup:new{
                    align = "center",
                    CenterContainer:new{ dimen = Geom:new{ w = ROW_H, h = ROW_H - line }, UI.text(glyph, 20, { color = th.ink }) },
                    UI.text(label, 18, { bold = true, color = th.ink }),
                },
                LineWidget:new{ dimen = Geom:new{ w = width, h = line }, background = th.line },
            },
        }
        return UI.tappable(row, on_tap)
    end

    -- A set that was picked but is gone (cleared, or moved between the lists) sends you back to the list.
    local set = screen:currentSet()
    if screen.dup_set and not set then screen.dup_set = nil end
    local ignored_mode = screen.dup_ignored
    local sets = ignored_mode and (plugin.ignored_duplicates or {}) or sets
    local reclaim = Duplicates.reclaimable(sets)

    if not set then
        local hero = UI.hero(th, width, {
            color = th.brand, icon = "library", title = _("Duplicates"),
            subtitle = ignored_mode and T(N_("%1 book kept as it is", "%1 books kept as they are", #sets), #sets)
                or #sets == 0 and _("Nothing is on the shelf twice")
                or T(N_("%1 book · up to %2 to free", "%1 books · up to %2 to free", #sets), #sets, util.getFriendlySize(reclaim)),
        })
        local size_w = sp(110)
        local name_w = width - size_w - 3 * gap
        local function build(i, row_h)
            local item = sets[i]
            row_h = row_h or ROW_H
            local copies = T(N_("%1 copy", "%1 copies", #item.copies), #item.copies)
            local row = FrameContainer:new{
                bordersize = 0, padding = 0, margin = 0, background = th.white,
                VerticalGroup:new{
                    align = "left",
                    HorizontalGroup:new{
                        align = "center",
                        LeftContainer:new{
                            dimen = Geom:new{ w = name_w + 2 * gap, h = row_h - line },
                            HorizontalGroup:new{
                                HorizontalSpan:new{ width = gap },
                                VerticalGroup:new{
                                    align = "left",
                                    UI.text(item.title, 18, { bold = true, color = th.ink, max_width = name_w }),
                                    UI.text(T(_("%1 · %2"), kindText(item), copies), 13, { color = th.muted, max_width = name_w }),
                                },
                            },
                        },
                        RightContainer:new{
                            dimen = Geom:new{ w = size_w + gap, h = row_h - line },
                            HorizontalGroup:new{
                                UI.text(T(_("frees %1"), util.getFriendlySize(item.free)), 14, { bold = true, color = th.ink }),
                                HorizontalSpan:new{ width = gap },
                            },
                        },
                    },
                    LineWidget:new{ dimen = Geom:new{ w = width, h = line }, background = th.line },
                },
            }
            return UI.tappable(row, function() screen:openSet(item.id) end)
        end
        return {
            hero = hero, table_head = (function()
                local head = VerticalGroup:new{ align = "left", topRow("⬆", _("Up"), up) }
                local kept = #(plugin.ignored_duplicates or {})
                if ignored_mode then
                    table.insert(head, topRow("‹", _("Back to the duplicates"), function() screen:showActiveDuplicates() end))
                elseif kept > 0 then
                    table.insert(head, topRow("›", T(_("Kept on purpose · %1"), kept), function() screen:showIgnoredDuplicates() end))
                end
                return head
            end)(),
            count = #sets, row_h = ROW_H, build = build,
            empty = function(h)
                return FrameContainer:new{
                    bordersize = 0, padding = 0, margin = 0, background = th.white,
                    CenterContainer:new{
                        dimen = Geom:new{ w = width, h = h },
                        VerticalGroup:new{
                            align = "center",
                            UI.text(_("No duplicates left"), 22, { bold = true, color = th.ink }),
                            VerticalSpan:new{ width = sp(8) },
                            UI.text(_("Everything that looked like a copy has been dealt with."), 15, { color = th.muted, max_width = width - 4 * gap }),
                        },
                    },
                }
            end,
        }
    end

    -- One set, its copies stacked as cards, best first. The copy that will be kept is the first, unless you tapped
    -- another; the book you are reading is always kept.
    local keep = screen:keeper(set)
    local locked = plugin:copyInfo(set.copies[keep]).locked
    local hero = UI.hero(th, width, {
        color = th.books, icon = "library", title = set.title,
        subtitle = T(_("%1 · %2"), kindText(set), T(N_("%1 copy", "%1 copies", #set.copies), #set.copies))
            .. (set.ignored and _(" · kept on purpose") or ""),
    })
    local reason = keep == 1 and why(set) or _("You chose this copy.")
    local function pick(i)
        if not locked then screen:setKeeper(set, i) end
    end
    local function readText(copy) return Progress.cell(BookList.getBookInfo(copy.path)) end
    local function day(time) return time and os.date("%b %d", time) or "" end

    local tag_text = {
        suggested = _("SUGGESTED"), fixed_layout = _("PDF · FIXED LAYOUT"), older_format = _("OLDER FORMAT"),
        newest = _("NEWEST"), smallest = _("SMALLEST"),
    }
    local border, pad = Size.border.thick, sp(10)
    local lead_w = sp(84)
    local rest_w = width - 2 * (border + pad) - lead_w - gap
    local chip_h = UI.chip(th, "Ag"):getSize().h

    -- One field: a muted label and its value.
    local function field(label, value, w)
        local l = UI.text(label, 12, { color = th.muted })
        return HorizontalGroup:new{
            align = "center", l, HorizontalSpan:new{ width = sp(6) },
            UI.text(value, 14, { bold = true, color = th.ink, max_width = w - l:getSize().w - sp(6) }),
        }
    end

    local function card(i)
        local copy = set.copies[i]
        local kept = i == keep
        local third = math.floor((rest_w - 2 * gap) / 3)
        local where_w = math.min(sp(150), math.floor(rest_w / 3))
        local tags = HorizontalGroup:new{
            align = "center", VerticalSpan:new{ width = chip_h },
            UI.text(T(_("in %1"), whereIs(plugin, copy)), 12, { color = th.muted, max_width = where_w }),
            HorizontalSpan:new{ width = sp(8) },
        }
        local used = where_w + sp(8)
        for _n, tag in ipairs(Duplicates.tags(set, i, function(c) return plugin:copyInfo(c) end)) do
            local text = tag.id == "most_read" and T(_("MOST READ %1%"), tag.percent) or tag_text[tag.id]
            local chip = UI.chip(th, text, { active = tag.id == "suggested" or tag.id == "most_read" })
            local w = chip:getSize().w + sp(4)
            if used + w > rest_w then break end
            table.insert(tags, chip)
            table.insert(tags, HorizontalSpan:new{ width = sp(4) })
            used = used + w
        end
        local lead = VerticalGroup:new{
            align = "left",
            UI.chip(th, kept and _("KEEP") or _("CLEAR"), { active = kept }),
            VerticalSpan:new{ width = sp(6) },
            FrameContainer:new{
                bordersize = 0, padding = 0, margin = 0, radius = sp(6), background = Theme.kind(th, copy),
                CenterContainer:new{
                    dimen = Geom:new{ w = lead_w, h = sp(46) },
                    UI.text(Duplicates.extension(copy.name):upper(), 15, { bold = true, color = th.white, max_width = lead_w }),
                },
            },
        }
        local rest = VerticalGroup:new{
            align = "left",
            UI.text(copy.name, 16, { bold = true, color = th.ink, max_width = rest_w }),
            HorizontalGroup:new{
                field(_("Size"), util.getFriendlySize(copy.size), third), HorizontalSpan:new{ width = gap },
                field(_("Read"), readText(copy), third), HorizontalSpan:new{ width = gap },
                field(_("Added"), day(copy.modified), third),
            },
            tags,
        }
        return FrameContainer:new{
            bordersize = kept and border or Size.border.thin, color = kept and th.ink or th.danger,
            radius = sp(10), margin = 0, padding = kept and pad or pad + border - Size.border.thin,
            width = width, background = kept and th.white or th.clear,
            HorizontalGroup:new{ align = "top", lead, HorizontalSpan:new{ width = gap }, rest },
        }
    end

    local card_gap = sp(8)
    local row_h = card(1):getSize().h + card_gap
    local function build(i, h)
        local row = card(i)
        return VerticalGroup:new{
            align = "left",
            UI.tappable(row, function() pick(i) end),
            VerticalSpan:new{ width = (h or row_h) - row:getSize().h },
        }
    end
    local free = Duplicates.savings(set, keep)
    local actions = HorizontalGroup:new{
        align = "center",
        UI.button(th, { text = "⬆", size = 15, callback = function() screen:closeSet() end }),
        HorizontalSpan:new{ width = gap },
        set.ignored
            and UI.button(th, { text = _("Stop ignoring"), size = 15, callback = function() plugin:stopIgnoring(set) end })
            or UI.button(th, { text = _("Keep all"), size = 15, callback = function() plugin:keepAll(set) end }),
        HorizontalSpan:new{ width = gap },
        UI.button(th, {
            text = T(_("Clear %1 · frees %2"), #set.copies - 1, util.getFriendlySize(free)), size = 15,
            background = th.danger, color = th.white, callback = function() plugin:confirmClearCopies(set, keep) end,
        }),
    }
    return {
        hero = hero,
        header = VerticalGroup:new{
            align = "left",
            UI.text(T(_("%1 Tap a copy to keep that one instead."), reason), 14, { color = th.muted, max_width = width }),
            VerticalSpan:new{ width = sp(6) },
            actions,
            VerticalSpan:new{ width = sp(8) },
        },
        count = #set.copies, row_h = row_h, build = build, fixed_rows = true,
    }
end
