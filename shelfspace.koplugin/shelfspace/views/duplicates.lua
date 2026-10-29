local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local LeftContainer = require("ui/widget/container/leftcontainer")
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
    local gap = sp(10)

    -- A set that was picked but is gone (cleared, or moved between the lists) sends you back to the list.
    local set = screen:currentSet()
    if screen.dup_set and not set then screen.dup_set = nil end
    local ignored_mode = screen.dup_ignored
    local sets = ignored_mode and (plugin.ignored_duplicates or {}) or (plugin.duplicates or {})
    local reclaim = Duplicates.reclaimable(sets)
    local function info(copy) return plugin:copyInfo(copy) end
    local function readText(copy) return Progress.cell(BookList.getBookInfo(copy.path)) end
    local function relative(copy) return copy.path:sub(#plugin.root + 2) end

    if not set then
        -- What the whole tab could free, as the first thing on it.
        local summary
        if ignored_mode then
            summary = UI.text(T(N_("%1 book kept as it is", "%1 books kept as they are", #sets), #sets), 18, { bold = true, color = th.ink, max_width = width - 2 * gap })
        elseif #sets == 0 then
            summary = UI.text(_("Nothing is on the shelf twice"), 18, { bold = true, color = th.ink, max_width = width - 2 * gap })
        else
            local big = UI.text(util.getFriendlySize(reclaim), 34, { face = "tfont", color = th.ink })
            summary = HorizontalGroup:new{
                align = "center", big, HorizontalSpan:new{ width = gap },
                UI.text(T(N_("could be freed from %1 book on the shelf twice", "could be freed from %1 books on the shelf twice", #sets), #sets), 15,
                    { color = th.ink, max_width = width - 2 * gap - big:getSize().w - gap }),
            }
        end
        local hero = FrameContainer:new{
            bordersize = th.tinted and 0 or Size.border.thick, color = th.ink, radius = sp(12), margin = 0, padding = gap,
            background = th.tint_duplicates, width = width, summary,
        }

        -- A set as a card: its book, what clearing it frees, and its copies, the one that stays marked ✓ and the others ✕.
        local border, pad = Size.border.thick, sp(10)
        local inner = width - 2 * (border + pad)
        local function copy_line(copy, kept)
            local meta = UI.text(T(_("%1 · %2"), util.getFriendlySize(copy.size), readText(copy)), 13, { color = th.muted })
            local glyph = UI.text(kept and "✓" or "✕", 16, { bold = true, color = kept and th.accent or th.danger })
            local path_w = inner - glyph:getSize().w - sp(8) - meta:getSize().w - sp(8)
            return HorizontalGroup:new{
                align = "center", glyph, HorizontalSpan:new{ width = sp(8) },
                LeftContainer:new{ dimen = Geom:new{ w = path_w, h = glyph:getSize().h + sp(4) },
                    UI.text(relative(copy), 14, { bold = kept, color = kept and th.ink or th.muted, max_width = path_w }) },
                HorizontalSpan:new{ width = sp(8) }, meta,
            }
        end
        local function set_card(item)
            local keep = screen:keeper(item)
            local free = UI.text(T(_("frees %1"), util.getFriendlySize(Duplicates.savings(item, keep))), 14, { bold = true, color = th.white })
            local pill = FrameContainer:new{
                bordersize = 0, margin = 0, radius = sp(14), background = th.duplicates,
                padding = sp(3), padding_left = sp(10), padding_right = sp(10), free,
            }
            local title_w = inner - pill:getSize().w - gap
            local card = VerticalGroup:new{
                align = "left",
                HorizontalGroup:new{
                    align = "center",
                    LeftContainer:new{ dimen = Geom:new{ w = title_w, h = pill:getSize().h }, UI.text(item.title, 19, { bold = true, color = th.ink, max_width = title_w }) },
                    HorizontalSpan:new{ width = gap }, pill,
                },
                VerticalSpan:new{ width = sp(4) },
                HorizontalGroup:new{
                    align = "center", UI.chip(th, kindText(item):upper()), HorizontalSpan:new{ width = sp(8) },
                    UI.text(T(N_("%1 copy", "%1 copies", #item.copies), #item.copies), 13, { color = th.muted }),
                },
                VerticalSpan:new{ width = sp(6) },
                copy_line(item.copies[keep], true),
            }
            -- The first of the others, and a word for the rest.
            local shown = 0
            for i, copy in ipairs(item.copies) do
                if i ~= keep and shown < 1 then table.insert(card, copy_line(copy, false)) shown = shown + 1 end
            end
            if #item.copies - 1 > shown then
                table.insert(card, UI.text(T(_("and %1 more"), #item.copies - 1 - shown), 13, { color = th.muted }))
            end
            table.insert(card, RightContainer:new{ dimen = Geom:new{ w = inner, h = sp(22) }, UI.text(_("Compare ›"), 13, { color = th.muted }) })
            return FrameContainer:new{
                bordersize = border, color = th.ink, radius = sp(12), margin = 0, padding = pad, width = width, background = th.white,
                card,
            }
        end
        local card_gap, row_h = sp(9), 0
        for _n, item in ipairs(sets) do row_h = math.max(row_h, set_card(item):getSize().h) end
        row_h = row_h + card_gap
        local function build(i, h)
            local card = set_card(sets[i])
            return VerticalGroup:new{
                align = "left",
                UI.tappable(card, function() screen:openSet(sets[i].id) end),
                VerticalSpan:new{ width = (h or row_h) - card:getSize().h },
            }
        end
        -- The way to the sets you chose to keep (there when there are some), and back.
        local header = VerticalGroup:new{ align = "left", VerticalSpan:new{ width = sp(6) } }
        local kept = #(plugin.ignored_duplicates or {})
        if ignored_mode then
            table.insert(header, UI.button(th, { text = _("‹ Back to the duplicates"), size = 15, callback = function() screen:showActiveDuplicates() end }))
            table.insert(header, VerticalSpan:new{ width = sp(8) })
        elseif kept > 0 then
            table.insert(header, UI.button(th, { text = T(_("Kept on purpose · %1 ›"), kept), size = 15, callback = function() screen:showIgnoredDuplicates() end }))
            table.insert(header, VerticalSpan:new{ width = sp(8) })
        end
        return {
            hero = hero, header = header, count = #sets, row_h = row_h, build = build, fixed_rows = true,
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
    local locked = info(set.copies[keep]).locked
    local hero = VerticalGroup:new{
        align = "left",
        UI.text(set.title, 26, { face = "tfont", color = th.ink, max_width = width }),
        VerticalSpan:new{ width = sp(4) },
        HorizontalGroup:new{
            align = "center", UI.chip(th, kindText(set):upper()), HorizontalSpan:new{ width = sp(8) },
            UI.text(T(N_("%1 copy", "%1 copies", #set.copies), #set.copies) .. (set.ignored and _(" · kept on purpose") or ""), 14, { color = th.muted }),
        },
    }
    local reason = keep == 1 and why(set) or _("You chose this copy.")
    local function pick(i)
        if not locked then screen:setKeeper(set, i) end
    end
    local function day(time) return time and os.date("%b %d", time) or "" end

    local tag_text = {
        suggested = _("SUGGESTED"), fixed_layout = _("FIXED LAYOUT"), older_format = _("OLDER FORMAT"),
        newest = _("NEWEST"), smallest = _("SMALLEST"),
    }
    -- The copy to keep has a heavy outline in the accent colour and a filled radio; the others a thin red one and an
    -- empty radio, so they differ by shape on a screen with no colour.
    local keep_border, clear_border, pad = sp(3), Size.border.button, sp(10)
    local radio = sp(30)
    local rest_w = width - 2 * (keep_border + pad) - radio - gap
    local chip_h = UI.chip(th, "Ag"):getSize().h

    local function field(label, widget, w)
        local l = UI.text(label, 12, { color = th.muted })
        return HorizontalGroup:new{ align = "center", l, HorizontalSpan:new{ width = sp(6) }, widget }
    end

    local function card(i)
        local copy = set.copies[i]
        local kept = i == keep
        local mark = FrameContainer:new{
            bordersize = Size.border.thick, radius = math.floor(radio / 2), margin = 0, padding = 0,
            color = kept and th.accent or th.ink, background = kept and th.accent or th.white,
            CenterContainer:new{ dimen = Geom:new{ w = radio - 2 * Size.border.thick, h = radio - 2 * Size.border.thick },
                kept and UI.text("✓", 16, { bold = true, color = th.white }) or HorizontalSpan:new{ width = 0 } },
        }
        local badge = UI.chip(th, kept and _("KEEP") or _("CLEAR"), { active = kept })
        local name_w = rest_w - badge:getSize().w - sp(8)
        local fraction = Progress.fraction(BookList.getBookInfo(copy.path))
        local facts = HorizontalGroup:new{
            align = "center",
            field(_("Size"), UI.text(util.getFriendlySize(copy.size), 14, { bold = true, color = th.ink })), HorizontalSpan:new{ width = gap },
            field(_("Read"), HorizontalGroup:new{
                align = "center", FrameContainer:new{ bordersize = Size.border.default, color = th.ink, radius = sp(5), margin = 0, padding = 0, UI.bar(th, sp(54), sp(8), fraction, th.ink) }, HorizontalSpan:new{ width = sp(6) },
                UI.text(readText(copy), 14, { bold = true, color = th.ink }) }), HorizontalSpan:new{ width = gap },
            field(_("Added"), UI.text(day(copy.modified), 14, { bold = true, color = th.ink })),
        }
        local tags = HorizontalGroup:new{ align = "center", VerticalSpan:new{ width = chip_h } }
        local used = 0
        for _n, tag in ipairs(Duplicates.tags(set, i, function(c) return plugin:copyInfo(c) end)) do
            local text = tag.id == "most_read" and T(_("MOST READ %1%"), tag.percent) or tag_text[tag.id]
            local chip = UI.chip(th, text, { active = tag.id == "suggested" or tag.id == "most_read" })
            local w = chip:getSize().w + sp(4)
            if used + w > rest_w then break end
            table.insert(tags, chip)
            table.insert(tags, HorizontalSpan:new{ width = sp(4) })
            used = used + w
        end
        local rest = VerticalGroup:new{
            align = "left",
            HorizontalGroup:new{ align = "center", UI.text(copy.name, 17, { bold = true, color = th.ink, max_width = name_w }),
                HorizontalSpan:new{ width = sp(8) }, badge },
            UI.text(T(_("in %1"), whereIs(plugin, copy)), 12, { color = th.muted, max_width = rest_w }),
            VerticalSpan:new{ width = sp(3) },
            facts,
            VerticalSpan:new{ width = sp(4) },
            kept and UI.text(reason, 12, { bold = true, color = th.ink, max_width = rest_w }) or VerticalSpan:new{ width = 0 },
            kept and VerticalSpan:new{ width = sp(3) } or VerticalSpan:new{ width = 0 },
            tags,
        }
        local border = kept and keep_border or clear_border
        return FrameContainer:new{
            bordersize = border, color = kept and th.accent or th.danger, radius = sp(12), margin = 0,
            padding = pad + (keep_border - border), width = width, background = kept and th.tint_books or th.clear,
            HorizontalGroup:new{ align = "top", mark, HorizontalSpan:new{ width = gap }, rest },
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
    -- What the button will do, in a sentence above it, so it never surprises you.
    local free = Duplicates.savings(set, keep)
    local clears = #set.copies - 1
    local box_pad = sp(10)
    local inner = width - 2 * (box_pad + Size.border.thick)
    local keep_w = math.floor(inner * 0.32)
    local actions = HorizontalGroup:new{
        align = "center",
        set.ignored
            and UI.button(th, { text = _("Stop ignoring"), size = 15, width = keep_w, callback = function() plugin:stopIgnoring(set) end })
            or UI.button(th, { text = _("Keep all"), size = 15, width = keep_w, callback = function() plugin:keepAll(set) end }),
        HorizontalSpan:new{ width = gap },
        UI.button(th, {
            text = T(N_("Clear %1 copy", "Clear %1 copies", clears), clears), size = 15, width = inner - keep_w - gap,
            background = th.danger, color = th.white, callback = function() plugin:confirmClearCopies(set, keep) end,
        }),
    }
    local sentence = T(N_("Keeps %1 · clears %2 copy · frees %3", "Keeps %1 · clears %2 copies · frees %3", clears),
        set.copies[keep].name, clears, util.getFriendlySize(free))
    local summary = FrameContainer:new{
        bordersize = Size.border.thick, color = th.ink, radius = sp(12), margin = 0, padding = box_pad, width = width, background = th.white,
        VerticalGroup:new{ align = "left", UI.text(sentence, 14, { color = th.ink, max_width = inner }), VerticalSpan:new{ width = sp(8) }, actions },
    }
    return {
        hero = hero,
        header = VerticalGroup:new{
            align = "left",
            VerticalSpan:new{ width = sp(4) },
            HorizontalGroup:new{
                align = "center",
                UI.button(th, { text = _("‹ Back"), size = 15, callback = function() screen:closeSet() end }),
                HorizontalSpan:new{ width = gap },
                UI.text(_("Tap the copy you want to keep."), 14, { color = th.muted, max_width = width - sp(120) }),
            },
            VerticalSpan:new{ width = sp(8) },
            summary,
            VerticalSpan:new{ width = sp(8) },
        },
        count = #set.copies, row_h = row_h, build = build, fixed_rows = true,
    }
end
