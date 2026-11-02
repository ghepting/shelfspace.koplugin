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
local Icons = require("shelfspace/icons")
local Progress = require("shelfspace/progress")
local Formats = require("shelfspace/formats")
local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp


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
return function(screen, th, width, layout)
    local plugin = screen.plugin
    local gap = sp(10)
    local hero_w = layout and layout.hero_w or width

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
            summary = UI.text(T(N_("%1 book kept as it is", "%1 books kept as they are", #sets), #sets), 18, { bold = true, color = th.ink, max_width = hero_w - 2 * gap })
        elseif #sets == 0 then
            -- Done: a green band with a check, the colour of what stays rather than of what goes.
            local disc = Icons.doneWidget(sp(36), th.keep)
            local text = UI.text(_("You're all caught up"), 18, { bold = true, color = th.ink, max_width = hero_w - 2 * gap - sp(36) - gap })
            summary = disc and HorizontalGroup:new{ align = "center", disc, HorizontalSpan:new{ width = gap }, text } or text
        else
            local big = UI.text(util.getFriendlySize(reclaim), 34, { face = "tfont", color = th.ink })
            local text = T(N_("could be freed from %1 book on the shelf twice", "could be freed from %1 books on the shelf twice", #sets), #sets)
            if layout and layout.landscape then
                -- In its own column the words go under the number.
                summary = VerticalGroup:new{ align = "left", big, VerticalSpan:new{ width = sp(4) },
                    UI.text(_("could be freed"), 15, { color = th.ink, max_width = hero_w - 2 * gap }),
                    UI.text(T(N_("from %1 book on the shelf twice", "from %1 books on the shelf twice", #sets), #sets), 15, { color = th.ink, max_width = hero_w - 2 * gap }) }
            else
                summary = HorizontalGroup:new{
                    align = "center", big, HorizontalSpan:new{ width = gap },
                    UI.text(text, 15, { color = th.ink, max_width = hero_w - 2 * gap - big:getSize().w - gap }),
                }
            end
        end
        local hero = FrameContainer:new{
            bordersize = th.tinted and 0 or Size.border.thick, color = th.ink, radius = sp(12), margin = 0, padding = gap,
            background = (not ignored_mode and #sets == 0) and th.tint_keep or th.tint_duplicates, width = hero_w, summary,
        }

        -- A set as a card: its book, what deleting the extras frees, and its copies, the one that stays marked ✓ and the others ✕.
        local border, pad = Size.border.thick, sp(10)
        local inner = width - 2 * (border + pad)
        local function copy_line(copy, kept)
            local meta = UI.text(T(_("%1 · %2"), util.getFriendlySize(copy.size), readText(copy)), 13, { color = th.muted })
            local glyph = Icons.tickWidget(kept and "tick" or "cross", sp(20), kept and th.keep or th.danger)
                or UI.text(kept and "✓" or "✕", 16, { bold = true, color = kept and th.keep or th.danger })
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
            -- The kind and what it frees share the top right; the name's room is what they leave.
            local kind = UI.chip(th, kindText(item))
            local right = HorizontalGroup:new{ align = "center", kind, HorizontalSpan:new{ width = sp(6) }, pill }
            local title_w = inner - right:getSize().w - gap
            local card = VerticalGroup:new{
                align = "left",
                HorizontalGroup:new{
                    align = "center",
                    LeftContainer:new{ dimen = Geom:new{ w = title_w, h = right:getSize().h }, UI.text(item.title, 19, { bold = true, color = th.ink, max_width = title_w }) },
                    HorizontalSpan:new{ width = gap }, right,
                },
                UI.text(T(N_("%1 copy", "%1 copies", #item.copies), #item.copies), 13, { color = th.muted }),
                VerticalSpan:new{ width = sp(4) },
                copy_line(item.copies[keep], true),
            }
            -- The first of the others; a word for the rest at the left of the last line, and the way in at the right.
            local shown = 0
            for i, copy in ipairs(item.copies) do
                if i ~= keep and shown < 1 then table.insert(card, copy_line(copy, false)) shown = shown + 1 end
            end
            local more = #item.copies - 1 - shown
            local compare = UI.text(_("Compare ›"), 13, { color = th.muted })
            local more_text = more > 0 and UI.text(T(_("and %1 more"), more), 13, { color = th.muted }) or HorizontalSpan:new{ width = 0 }
            table.insert(card, HorizontalGroup:new{
                align = "center", more_text,
                HorizontalSpan:new{ width = inner - more_text:getSize().w - compare:getSize().w }, compare,
            })
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
        elseif kept > 0 and #sets > 0 then -- with none left, that way in is on the finished screen
            table.insert(header, UI.button(th, { text = T(_("Kept on purpose · %1 ›"), kept), size = 15, callback = function() screen:showIgnoredDuplicates() end }))
            table.insert(header, VerticalSpan:new{ width = sp(8) })
        end
        return {
            hero = hero, header = header, count = #sets, row_h = row_h, build = build, fixed_rows = true,
            empty = function(h)
                local lines = VerticalGroup:new{ align = "center" }
                local disc = Icons.doneWidget(sp(96), th.keep)
                if disc then
                    table.insert(lines, disc)
                    table.insert(lines, VerticalSpan:new{ width = sp(14) })
                end
                table.insert(lines, UI.text(_("No duplicates left"), 22, { bold = true, color = th.ink }))
                table.insert(lines, VerticalSpan:new{ width = sp(8) })
                table.insert(lines, UI.text(_("Everything that looked like a copy has been dealt with."), 15, { color = th.muted, max_width = width - 4 * gap }))
                if kept > 0 and not ignored_mode then
                    table.insert(lines, VerticalSpan:new{ width = sp(16) })
                    table.insert(lines, UI.button(th, { text = T(_("Kept on purpose · %1 ›"), kept), size = 15, callback = function() screen:showIgnoredDuplicates() end }))
                end
                return FrameContainer:new{
                    bordersize = 0, padding = 0, margin = 0, background = th.white,
                    CenterContainer:new{ dimen = Geom:new{ w = width, h = h }, lines },
                }
            end,
        }
    end

    -- One set, its copies stacked as cards, best first. The copy that will be kept is the first, unless you tapped
    -- another; the book you are reading is always kept.
    local keep = screen:keeper(set)
    local locked = info(set.copies[keep]).locked
    local kind_chip = UI.chip(th, kindText(set))
    local count_text = UI.text(T(N_("%1 copy", "%1 copies", #set.copies), #set.copies) .. (set.ignored and _(" · kept on purpose") or ""), 14, { color = th.muted })
    local hero
    if layout and layout.landscape then
        -- In a column of its own the title has the whole width and the facts sit under it.
        hero = VerticalGroup:new{
            align = "left",
            UI.text(set.title, 26, { face = "tfont", color = th.ink, max_width = hero_w }),
            VerticalSpan:new{ width = sp(4) },
            HorizontalGroup:new{ align = "center", kind_chip, HorizontalSpan:new{ width = sp(8) }, count_text },
        }
    else
        -- Upright, the title and what it is take one line, so there is room for more copies below.
        -- Back goes at the left of the title, so it costs no row of its own.
        local back_btn = UI.button(th, { text = _("‹ Back"), size = 15, callback = function() screen:closeSet() end })
        -- The title over a muted line of facts, as the other tabs' headings are.
        local text_w = hero_w - back_btn:getSize().w - sp(12)
        local sub = T(N_("%1 copy", "%1 copies", #set.copies), #set.copies) .. " · " .. kindText(set):lower() .. (set.ignored and _(" · kept on purpose") or "")
        hero = HorizontalGroup:new{
            align = "center",
            back_btn, HorizontalSpan:new{ width = sp(12) },
            UI.stack(UI.text(set.title, 24, { face = "tfont", color = th.ink, max_width = text_w }),
                UI.text(sub, 15, { color = th.muted, max_width = text_w })),
        }
    end
    local function pick(i)
        if not locked then screen:setKeeper(set, i) end
    end
    local function day(time) return time and os.date("%b %d", time) or "" end

    local tag_text = {
        suggested = _("Suggested"), fixed_layout = _("Fixed layout"), older_format = _("Older format"),
        newest = _("Newest"), smallest = _("Smallest"),
    }
    -- A copy is a row like the KOReader tab's: its name over its facts at the left, its size and its radio button at the right, all centred
    -- in the row, with the file's type tile in front. The copy that stays is tinted green and the ones that go the magenta-red.
    local ROW_PAD = sp(6) -- the room above and below a copy's lines
    local size_w = sp(78)

    local function card(i)
        local copy = set.copies[i]
        local kept = i == keep
        local inner = th.tinted and (width - 2 * gap) or (width - gap)
        -- The file's type, as on the Library tab: its letters on its kind's colour.
        local tile_w = sp(34)
        local label = Formats.label(copy.name)
        local tile = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = sp(7), background = Theme.kind(th, copy),
            CenterContainer:new{ dimen = Geom:new{ w = tile_w, h = tile_w }, UI.text(label, #label >= 4 and 10 or 11, { bold = true, color = Theme.on(th, copy) }) },
        }
        local text_w = inner - tile_w - size_w - UI.CHECKBOX - 3 * gap
        -- What sets a copy apart (suggested, newest, an older format...) sits on the name's line, as many as leave the name room.
        local tag_chips = {}
        for _n, tag in ipairs(Duplicates.tags(set, i, function(c) return plugin:copyInfo(c) end)) do
            local text = tag.id == "most_read" and T(_("Most read %1%"), tag.percent) or tag_text[tag.id]
            table.insert(tag_chips, UI.chip(th, text, { fill = tag.id == "suggested" and th.suggest or th.accent, size = 12, pad_v = sp(1) }))
        end
        local function tags_w(n)
            local w = 0
            for k = 1, n do w = w + tag_chips[k]:getSize().w + sp(6) end
            return w
        end
        -- The tags sit at the right, beside the size and the box; drop them from the end until the text keeps half the line.
        local n = #tag_chips
        while n > 0 and text_w - tags_w(n) < math.floor(text_w * 0.5) do n = n - 1 end
        local tags = HorizontalGroup:new{ align = "center" }
        for k = 1, n do
            table.insert(tags, tag_chips[k])
            table.insert(tags, HorizontalSpan:new{ width = sp(6) })
        end
        local col_w = text_w - tags_w(n)
        local title = UI.text(copy.name, 18, { bold = true, color = th.ink, max_width = col_w })
        -- The folder and the date, and how far it was read when it was.
        local read = readText(copy)
        -- Progress leads, so a long folder name can only cut the end of the line, never it.
        local facts = T(_("%1 · %2"), whereIs(plugin, copy), day(copy.modified))
        if read == "Read" then facts = _("Finished") .. " · " .. facts
        elseif read == "" or read == "0%" then facts = _("Unread") .. " · " .. facts
        else facts = T(_("%1 read"), read) .. " · " .. facts end
        local note = UI.text(facts, 14, { color = th.muted, max_width = col_w })
        local used = math.max(title:getSize().w, note:getSize().w)
        -- The same pairing as the KOReader tab's rows, so the name and its line sit as close.
        local lines = UI.stack(title, note)
        -- No outline: the tint and the box say which copy stays, as the tint of a row does on the KOReader tab.
        return FrameContainer:new{
            bordersize = 0, radius = sp(8), margin = 0, padding = 0, width = width,
            padding_left = th.tinted and gap or 0, padding_right = th.tinted and gap or 0,
            background = th.tinted and (kept and th.tint_keep or th.clear) or nil,
            CenterContainer:new{
                dimen = Geom:new{ w = inner, h = math.max(lines:getSize().h, UI.CHECKBOX) + 2 * ROW_PAD },
                HorizontalGroup:new{
                    align = "center",
                    tile, HorizontalSpan:new{ width = gap },
                    lines,
                    HorizontalSpan:new{ width = col_w - used + gap },
                    tags,
                    RightContainer:new{ dimen = Geom:new{ w = size_w, h = sp(30) }, UI.text(util.getFriendlySize(copy.size), 17, { bold = true, color = th.ink }) },
                    HorizontalSpan:new{ width = gap },
                    UI.radio(th, kept, { fill = th.keep }),
                },
            },
        }
    end

    local card_gap = sp(5)
    local row_h = card(1):getSize().h + card_gap
    local function build(i, h)
        local row = card(i)
        return VerticalGroup:new{
            align = "left",
            UI.tappable(row, function() pick(i) end),
            VerticalSpan:new{ width = (h or row_h) - row:getSize().h },
        }
    end
    -- The line over the copies: which one stays, at the left (what the bar's buttons will delete and free is in the bar), and, when the
    -- set has more copies than a page holds, which ones are showing, at the right.
    local function page_line(first, last)
        local n = #set.copies
        local range = not (first <= 1 and last >= n) and UI.text(T(_("Copies %1–%2 of %3"), first, math.max(first, last), n), 14, { color = th.muted })
        local label = UI.text(_("Keeps"), 16, { color = th.ink })
        -- KOReader's text keeps only a colour's brightness, so the name is drawn with UI's colour-keeping text to come out green.
        local side = label:getSize().w + sp(8) + (range and (range:getSize().w + gap) or 0)
        local name = UI.text(set.copies[keep].name, 16, { bold = true, color = th.keep, color_text = true, max_width = width - side })
        local used = label:getSize().w + sp(8) + name:getSize().w + (range and (range:getSize().w + gap) or 0)
        return VerticalGroup:new{
            align = "left",
            HorizontalGroup:new{
                align = "center", label, HorizontalSpan:new{ width = sp(8) }, name,
                HorizontalSpan:new{ width = math.max(0, width - used + (range and gap or 0)) }, range or HorizontalSpan:new{ width = 0 },
            },
            VerticalSpan:new{ width = sp(6) },
        }
    end
    -- What the buttons will do (what is freed, and how many copies go) is in the bar over the pager row, as on the other tabs.
    local free = Duplicates.savings(set, keep)
    local clears = #set.copies - 1
    local bar = {
        labels = { T(_("frees %1"), util.getFriendlySize(free)), "" },
        buttons = {
            set.ignored and { text = _("Stop ignoring"), callback = function() plugin:stopIgnoring(set) end }
                or { text = _("Keep all"), callback = function() plugin:keepAll(set) end },
            { text = T(N_("Delete %1 copy", "Delete %1 copies", clears), clears), danger = true, callback = function() plugin:confirmClearCopies(set, keep) end },
        },
    }
    local landscape = layout and layout.landscape
    return {
        hero = hero,
        header = VerticalGroup:new{
            align = "left",
            VerticalSpan:new{ width = landscape and sp(4) or 0 },
            landscape and HorizontalGroup:new{
                align = "center",
                UI.button(th, { text = _("‹ Back"), size = 15, callback = function() screen:closeSet() end }),
                HorizontalSpan:new{ width = gap },
                UI.text(_("Tap the copy you want to keep."), 14, { color = th.muted, max_width = width - sp(120) }),
            } or VerticalSpan:new{ width = 0 },
        },
        count = #set.copies, row_h = row_h, build = build, select_all = page_line, fixed_rows = true, bar = bar,
    }
end
