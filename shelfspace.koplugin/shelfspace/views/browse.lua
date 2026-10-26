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
local ReadHistory = require("readhistory")
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Deleter = require("shelfspace/deleter")
local Icons = require("shelfspace/icons")
local Progress = require("shelfspace/progress")
local Search = require("shelfspace/search")
local Selection = require("shelfspace/selection")
local Stats = require("shelfspace/stats")
local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(52)

-- At most `max` characters, cut on a character boundary.
local function shorten(text, max)
    local count, cut = 0, #text
    for pos in text:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max then cut = pos - 1 break end
    end
    return count > max and (text:sub(1, cut) .. "…") or text
end

-- The current folder as a hero card, then its contents largest-first with a share bar.
return function(screen, th, width)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = UI.hero(th, width, {
            color = th.books, icon = "library", title = _("Library"), subtitle = _("Scanning…"),
        }), message = _("Scanning your library…") }
    end

    local root = plugin.root
    local dir = screen.dir
    if not dir or not tree[dir] then dir = root end
    screen.dir = dir
    local parent = dir ~= root and dir:match("^(.*)/[^/]+$") or nil
    if parent and not tree[parent] then parent = root end

    local entries, where = {}, nil
    local status = screen.status
    local include = status and function(e) return Deleter.isBook(e) and BookList.getBookStatus(e.path) == status end
    if screen.query or screen.filter or include then
        entries, where = Search.find(tree, dir, screen.query, screen.filter, include)
    else
        for i, e in ipairs(tree[dir].entries) do
            if not e.hidden then table.insert(entries, e) end
        end
    end
    local opened
    if screen.sort == "opened" then
        local last = {}
        for _, item in ipairs(ReadHistory.hist) do last[item.file] = item.time end
        opened = function(e) return last[e.path] end
    end
    Search.sort(entries, screen.sort, screen.descending, opened)

    local name = dir == root and _("Library") or dir:match("[^/]+$")
    local summary = Stats.summarize(tree, dir)
    local chips = {}
    -- The chips are the types of book in the library, not everything on the device.
    for i, x in ipairs(Stats.topExtensions(Stats.typeBytes(tree, dir, Deleter.isBook), 3)) do
        local ext = x.ext
        table.insert(chips, {
            text = T(_("%1 %2%"), ext:upper(), x.percent == 0 and "<1" or x.percent),
            active = screen.filter == ext,
            on_tap = function() screen:toggleFilter(ext) end,
        })
    end
    local dir_size = tree[dir].size

    local hero = UI.hero(th, width, {
        color = th.books,
        icon = "library",
        title = name,
        subtitle = T(_("%1 · %2"), T(N_("%1 file", "%1 files", summary.files), summary.files), util.getFriendlySize(dir_size)),
        chips = chips,
    })

    local largest = 1
    for i, e in ipairs(entries) do largest = math.max(largest, e.size) end

    -- The table: a checkbox column, the name, how much of the book is read and the size, with thin lines
    -- between the columns.
    local gap = sp(10)
    local line = Size.line.thin
    local cb_w = sp(44) -- the checkbox column, wide enough to tap
    local tick_size = sp(26)
    local read_cell_w = sp(70)
    local size_cell_w = sp(88)
    local name_cell_w = width - cb_w - read_cell_w - size_cell_w - 3 * line
    local dot_w, dot_gap = sp(10), sp(8)
    local text_w = name_cell_w - 2 * gap - dot_w - dot_gap -- the name, and what is under it
    local head_h = sp(40)

    local function vline(h) return LineWidget:new{ dimen = Geom:new{ w = line, h = h }, background = th.line } end

    -- One row of the table: what goes in each of the four columns, and how tall the row is.
    local function frame(checkbox, name_cell, read_cell, size_cell, h, fill)
        return FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, background = fill or th.white,
            VerticalGroup:new{
                align = "left",
                HorizontalGroup:new{
                    align = "center",
                    CenterContainer:new{ dimen = Geom:new{ w = cb_w, h = h - line }, checkbox },
                    vline(h - line),
                    LeftContainer:new{
                        dimen = Geom:new{ w = name_cell_w, h = h - line },
                        HorizontalGroup:new{ HorizontalSpan:new{ width = gap }, name_cell },
                    },
                    vline(h - line),
                    RightContainer:new{
                        dimen = Geom:new{ w = read_cell_w, h = h - line },
                        HorizontalGroup:new{ read_cell, HorizontalSpan:new{ width = gap } },
                    },
                    vline(h - line),
                    RightContainer:new{
                        dimen = Geom:new{ w = size_cell_w, h = h - line },
                        HorizontalGroup:new{ size_cell, HorizontalSpan:new{ width = gap } },
                    },
                },
                LineWidget:new{ dimen = Geom:new{ w = width, h = line }, background = th.line },
            },
        }
    end

    local ctx = plugin:deleteContext()

    -- A row: checkbox, then the name with a dot for its type, then how much of the book is read, then the size.
    -- Under the name goes only what the row needs to say: why it is locked, or where a search result is.
    -- Tapping the row opens a folder or says what a file is; ticking is the checkbox. Rows that can't be
    -- deleted have a greyed checkbox.
    local function build(i, row_h)
        row_h = row_h or ROW_H -- the screen may stretch rows a little to fill the page
        local item = entries[i]
        local reason = Deleter.blockedReason(item, ctx)
        local under
        if reason then
            under = UI.text(reason, 12, { color = th.muted, max_width = text_w })
        elseif where then
            local rel = where[item]
            under = UI.text(rel == "" and _("here") or T(_("in %1"), rel), 12, { color = th.muted, max_width = text_w })
        end
        local read = Deleter.isBook(item) and Progress.cell(BookList.getBookInfo(item.path)) or ""
        local tick
        if reason then
            tick = UI.checkbox(th, false, { disabled = true, size = tick_size })
        else
            tick = UI.tappable(CenterContainer:new{
                dimen = Geom:new{ w = cb_w, h = row_h - line },
                UI.checkbox(th, screen.selected[item.path] ~= nil, { size = tick_size }),
            }, function() screen:toggle(item) end)
        end
        local name = VerticalGroup:new{
            align = "left",
            HorizontalGroup:new{
                align = "center",
                VerticalGroup:new{ align = "left", VerticalSpan:new{ width = sp(4) }, UI.block(dot_w, dot_w, Theme.kind(th, item), sp(3)) },
                HorizontalSpan:new{ width = dot_gap },
                UI.text(item.is_dir and (item.name .. "/") or item.name, 18,
                    { bold = true, color = reason and th.muted or th.ink, max_width = text_w }),
            },
        }
        if under then
            table.insert(name, HorizontalGroup:new{ HorizontalSpan:new{ width = dot_w + dot_gap }, under })
        end
        local row = frame(tick, name, UI.text(read, 15, { bold = true, color = th.ink }),
            UI.text(util.getFriendlySize(item.size), 15, { bold = true, color = th.ink }), row_h)
        if item.is_dir then
            return UI.tappable(row, function() screen:setDir(item.path) end)
        end
        return UI.tappable(row, function()
            plugin:showDetails(item, item.path:match("^(.*)/[^/]+$") or dir)
        end)
    end

    -- Two rows of controls: search with Show, then Sort with its direction. The labels are never squeezed:
    -- each button gets room for its own text.
    local clear_button = screen.query and UI.button(th, {
        text = "✕", size = 15, callback = function() screen:setQuery(nil) end,
    })
    local show_button = UI.button(th, {
        text = T(_("Show: %1 ▾"), Search.status(status).short), size = 15,
        callback = function() screen:askStatus() end,
    })
    local search_w = width - show_button:getSize().w - gap - (clear_button and (clear_button:getSize().w + gap) or 0)
    local search_row = HorizontalGroup:new{
        align = "center",
        UI.button(th, {
            text = screen.query and shorten(screen.query, 24) or _("Search by name"), size = 15,
            width = search_w, callback = function() screen:askQuery() end,
        }),
        HorizontalSpan:new{ width = gap },
    }
    if clear_button then
        table.insert(search_row, clear_button)
        table.insert(search_row, HorizontalSpan:new{ width = gap })
    end
    table.insert(search_row, show_button)

    -- An arrow down is biggest, newest or most recent first (Z to A for names), an arrow up the other way round.
    local direction_button = UI.button(th, {
        icon = Icons.sortWidget(screen.sort, screen.descending, sp(24), th.ink, th.white), text = screen.descending and "↓" or "↑",
        callback = function() screen:flipSort() end,
    })
    local sort_row = HorizontalGroup:new{
        align = "center",
        UI.button(th, {
            text = T(_("Sort: %1 ▾"), Search.sortBy(screen.sort).short), size = 15,
            width = width - direction_button:getSize().w - gap,
            callback = function() screen:askSort() end,
        }),
        HorizontalSpan:new{ width = gap },
        direction_button,
    }

    local header = VerticalGroup:new{
        align = "left", VerticalSpan:new{ width = sp(4) }, search_row, VerticalSpan:new{ width = sp(6) },
        sort_row, VerticalSpan:new{ width = sp(6) },
    }

    -- What can be ticked, and what is.
    local deletable, ticked = {}, 0
    for _, e in ipairs(entries) do
        if not Deleter.blockedReason(e, ctx) then
            table.insert(deletable, e)
            if screen.selected[e.path] then ticked = ticked + 1 end
        end
    end
    local chosen = screen:chosen()
    if screen.query or screen.filter or include then
        local count = #entries
        -- "3 finished PDF files", "1 finished book", "No EPUB files": what the filters leave, in words.
        local noun = screen.filter and (screen.filter:upper() .. " " .. N_("file", "files", count)) or N_("book", "books", count)
        if include then noun = Search.status(status).noun .. " " .. noun end
        local text
        if screen.query then
            text = count == 0 and T(_("No %1 match “%2” in %3"), noun, shorten(screen.query, 20), name)
                or T(_("%1 %2 match “%3” in %4"), count, noun, shorten(screen.query, 20), name)
        else
            text = count == 0 and T(_("No %1 in %2"), noun, name) or T(_("%1 %2 in %3"), count, noun, name)
        end
        table.insert(header, UI.text(text, 15, { color = th.muted, max_width = width }))
        table.insert(header, VerticalSpan:new{ width = sp(6) })
    end
    -- The ticked items' action: how many and how big, and the one Delete.
    if #chosen > 0 then
        local delete_button = UI.button(th, {
            text = _("Delete"), size = 15, background = th.danger, color = th.white,
            callback = function() plugin:confirmDeleteMany(chosen) end,
        })
        local label_w = width - delete_button:getSize().w - gap
        table.insert(header, HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = label_w, h = delete_button:getSize().h },
                UI.text(T(_("%1 selected · %2"), #chosen, util.getFriendlySize(Selection.size(chosen))), 16,
                    { bold = true, color = th.ink, max_width = label_w }),
            },
            HorizontalSpan:new{ width = gap }, delete_button,
        })
        table.insert(header, VerticalSpan:new{ width = sp(6) })
    end
    -- The column labels, and a checkbox that ticks everything that can be deleted (a dash when only some are).
    local all_ticked = #deletable > 0 and ticked == #deletable
    local head_tick = UI.checkbox(th, all_ticked, { mixed = ticked > 0 and not all_ticked, disabled = #deletable == 0, size = tick_size })
    local head = frame(
        #deletable > 0 and UI.tappable(CenterContainer:new{ dimen = Geom:new{ w = cb_w, h = head_h - line }, head_tick },
            function() screen:select(deletable, not all_ticked) end) or head_tick,
        HorizontalGroup:new{ HorizontalSpan:new{ width = dot_w + dot_gap }, UI.text(_("Name"), 14, { bold = true, color = th.muted }) },
        UI.text(_("% Read"), 14, { bold = true, color = th.muted }),
        UI.text(_("Size"), 14, { bold = true, color = th.muted }), head_h, th.chip)
    local table_head = VerticalGroup:new{ align = "left", head }
    if parent then
        table.insert(table_head, UI.tappable(frame(
            UI.text("⬆", 20, { color = th.ink }),
            UI.text(_("Up"), 18, { bold = true, color = th.ink }),
            HorizontalSpan:new{ width = 0 }, HorizontalSpan:new{ width = 0 }, ROW_H), function() screen:setDir(parent) end))
    end

    return { hero = hero, header = header, table_head = table_head, count = #entries, row_h = ROW_H, build = build }
end
