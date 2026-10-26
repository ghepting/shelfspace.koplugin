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
local CARDS_AT_MOST = 3 -- more copies than this are listed as rows: three cards is what a 3:4 screen has room for

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

    local function upRow(label, on_tap)
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, background = th.white,
            VerticalGroup:new{
                align = "left",
                HorizontalGroup:new{
                    align = "center",
                    CenterContainer:new{ dimen = Geom:new{ w = ROW_H, h = ROW_H - line }, UI.text("⬆", 20, { color = th.ink }) },
                    UI.text(label, 18, { bold = true, color = th.ink }),
                },
                LineWidget:new{ dimen = Geom:new{ w = width, h = line }, background = th.line },
            },
        }
        return UI.tappable(row, on_tap)
    end

    -- A set that was picked but is gone (cleared, or kept from now on) sends you back to the list.
    local set
    for _, s in ipairs(sets) do
        if s.id == screen.dup_set then set = s break end
    end
    if screen.dup_set and not set then screen.dup_set = nil end

    local reclaim = Duplicates.reclaimable(sets)

    if not set then
        local hero = UI.hero(th, width, {
            color = th.brand, icon = "library", title = _("Duplicates"),
            subtitle = #sets == 0 and _("Nothing is on the shelf twice")
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
            hero = hero, table_head = VerticalGroup:new{ align = "left", upRow(_("Up"), up) },
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

    -- One set: which copy is kept is the first, unless you tapped another. The book you are reading is always kept.
    local keep = screen:keeper(set)
    local locked = plugin:copyInfo(set.copies[keep]).locked
    local hero = UI.hero(th, width, {
        color = th.books, icon = "library", title = set.title,
        subtitle = T(_("%1 · %2"), kindText(set), T(N_("%1 copy", "%1 copies", #set.copies), #set.copies)),
    })
    local reason = keep == 1 and why(set) or _("You chose this copy.")
    local function pick(i)
        if not locked then screen:setKeeper(set, i) end
    end
    local function readText(copy) return Progress.cell(BookList.getBookInfo(copy.path)) end

    if #set.copies <= CARDS_AT_MOST then
        local n = #set.copies
        local card_w = math.floor((width - gap * (n - 1)) / n)
        local inner = card_w - 2 * sp(10)
        local cards = HorizontalGroup:new{ align = "top" }
        for i, copy in ipairs(set.copies) do
            local kept = i == keep
            local ext = Duplicates.extension(copy.name)
            local card = FrameContainer:new{
                bordersize = kept and Size.border.thick or Size.border.thin, color = kept and th.ink or th.muted,
                radius = sp(10), margin = 0, padding = sp(10), width = card_w,
                background = kept and th.white or th.chip,
                VerticalGroup:new{
                    align = "left",
                    UI.chip(th, kept and _("KEEP") or _("CLEAR"), { active = kept }),
                    VerticalSpan:new{ width = sp(8) },
                    UI.block(inner, sp(46), Theme.kind(th, copy), sp(6)),
                    VerticalSpan:new{ width = sp(2) },
                    UI.text(ext:upper(), 16, { bold = true, color = th.ink, max_width = inner }),
                    VerticalSpan:new{ width = sp(6) },
                    UI.text(_("Size"), 12, { color = th.muted, max_width = inner }),
                    UI.text(util.getFriendlySize(copy.size), 15, { bold = true, color = th.ink, max_width = inner }),
                    VerticalSpan:new{ width = sp(4) },
                    UI.text(_("Read"), 12, { color = th.muted, max_width = inner }),
                    UI.text(readText(copy), 15, { bold = true, color = th.ink, max_width = inner }),
                    VerticalSpan:new{ width = sp(4) },
                    UI.text(_("In"), 12, { color = th.muted, max_width = inner }),
                    UI.text(whereIs(plugin, copy), 14, { bold = true, color = th.ink, max_width = inner }),
                },
            }
            if i > 1 then table.insert(cards, HorizontalSpan:new{ width = gap }) end
            table.insert(cards, UI.tappable(card, function() pick(i) end))
        end
        local body = VerticalGroup:new{
            align = "left",
            upRow(_("Back to the list"), function() screen:closeSet() end),
            VerticalSpan:new{ width = sp(12) },
            cards,
            VerticalSpan:new{ width = sp(10) },
            UI.text(T(_("%1 Tap a copy to keep that one instead."), reason), 14, { color = th.muted, max_width = width }),
        }
        return { hero = hero, body = body }
    end

    -- Four or more copies: a row each, the one to keep ticked.
    local tick = sp(20)
    local size_w = sp(90)
    local name_w = width - ROW_H - size_w - 2 * line - gap
    local function build(i, row_h)
        local copy = set.copies[i]
        row_h = row_h or ROW_H
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, background = th.white,
            VerticalGroup:new{
                align = "left",
                HorizontalGroup:new{
                    align = "center",
                    CenterContainer:new{
                        dimen = Geom:new{ w = ROW_H, h = row_h - line },
                        UI.checkbox(th, i == keep, { size = tick }),
                    },
                    LineWidget:new{ dimen = Geom:new{ w = line, h = row_h - line }, background = th.line },
                    LeftContainer:new{
                        dimen = Geom:new{ w = name_w, h = row_h - line },
                        HorizontalGroup:new{
                            HorizontalSpan:new{ width = gap },
                            VerticalGroup:new{
                                align = "left",
                                UI.text(T(_("%1 · %2"), Duplicates.extension(copy.name):upper(), readText(copy)), 17,
                                    { bold = true, color = th.ink, max_width = name_w - gap }),
                                UI.text(whereIs(plugin, copy), 12, { color = th.muted, max_width = name_w - gap }),
                            },
                        },
                    },
                    LineWidget:new{ dimen = Geom:new{ w = line, h = row_h - line }, background = th.line },
                    RightContainer:new{
                        dimen = Geom:new{ w = size_w, h = row_h - line },
                        HorizontalGroup:new{ UI.text(util.getFriendlySize(copy.size), 15, { bold = true, color = th.ink }), HorizontalSpan:new{ width = gap } },
                    },
                },
                LineWidget:new{ dimen = Geom:new{ w = width, h = line }, background = th.line },
            },
        }
        return UI.tappable(row, function() pick(i) end)
    end
    return {
        hero = hero,
        header = VerticalGroup:new{
            align = "left",
            VerticalSpan:new{ width = sp(2) },
            UI.text(T(_("%1 Tap a copy to keep that one instead."), reason), 14, { color = th.muted, max_width = width }),
            VerticalSpan:new{ width = sp(6) },
        },
        table_head = VerticalGroup:new{ align = "left", upRow(_("Back to the list"), function() screen:closeSet() end) },
        count = #set.copies, row_h = ROW_H, build = build,
    }
end
