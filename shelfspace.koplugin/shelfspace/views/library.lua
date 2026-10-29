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
local Empty = require("shelfspace/empty")
local Icons = require("shelfspace/icons")
local Progress = require("shelfspace/progress")
local Search = require("shelfspace/search")
local Selection = require("shelfspace/selection")
local Storage = require("shelfspace/views/storage")
local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(46)

-- At most `max` characters, cut on a character boundary.
local function shorten(text, max)
    local count, cut = 0, #text
    for pos in text:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max then cut = pos - 1 break end
    end
    return count > max and (text:sub(1, cut) .. "…") or text
end

-- The Library: where the storage went (the chart, which also narrows the list), then the current folder's contents as a
-- table, largest first, with the controls to search, filter and sort it.
return function(screen, th, width)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = Storage(screen, th, width), message = _("Scanning your library…") }
    end

    local root = plugin.root
    local dir = screen.only_books and root or screen.dir
    if not dir or not tree[dir] then dir = root end
    screen.dir = dir
    local parent = dir ~= root and dir:match("^(.*)/[^/]+$") or nil
    if parent and not tree[parent] then parent = root end

    local entries, where = {}, nil
    local status = screen.status
    local include
    if status or screen.only_books then
        include = function(e) return Deleter.isBook(e) and (not status or BookList.getBookStatus(e.path) == status) end
    end
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
    local hero = Storage(screen, th, width)

    local gap = sp(10)
    local vgap = sp(5) -- between rows: each row's height includes it
    local tile = sp(34)
    local tick_size = sp(26)
    local read_w, size_w = sp(70), sp(92)
    local name_w = width - tile - read_w - size_w - 4 * gap
    local ctx = plugin:deleteContext()
    local selecting = screen.selecting

    -- The tile in front of a name: three or four letters of its type on its kind's colour ("DIR" for a folder).
    local function type_tile(item)
        local label = item.is_dir and "DIR" or (item.name:match("%.([^.]+)$") or "?"):upper():sub(1, 4)
        return FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = sp(7), background = Theme.kind(th, item),
            CenterContainer:new{ dimen = Geom:new{ w = tile, h = tile }, UI.text(label, 11, { bold = true, color = Theme.on(th, item) }) },
        }
    end

    -- A row: a tile (a checkbox while selecting), the name, how much of the book is read, and the size, on a tint of
    -- its kind's colour. Under the name goes only what the row needs to say: why it is locked, or where a search result
    -- is. Tapping opens a folder or says what a file is (while selecting, it ticks the row); pressing and holding opens
    -- the card of a file or folder.
    local function build(i, row_h)
        row_h = row_h or ROW_H -- the screen may stretch rows a little to fill the page
        local h = row_h - vgap
        local item = entries[i]
        local reason = Deleter.blockedReason(item, ctx)
        local under
        if reason then
            under = UI.text(reason, 12, { color = th.muted, max_width = name_w })
        elseif where then
            local rel = where[item]
            under = UI.text(rel == "" and _("here") or T(_("in %1"), rel), 12, { color = th.muted, max_width = name_w })
        end
        local read = Deleter.isBook(item) and Progress.cell(BookList.getBookInfo(item.path)) or ""
        local lead
        if selecting then
            lead = UI.checkbox(th, screen.selected[item.path] ~= nil, { size = tick_size, disabled = reason ~= nil })
        else
            lead = type_tile(item)
        end
        local name = VerticalGroup:new{
            align = "left",
            UI.text(item.is_dir and (item.name .. "/") or item.name, 18,
                { bold = true, color = reason and th.muted or th.ink, max_width = name_w }),
        }
        if under then table.insert(name, under) end
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = sp(8), background = Theme.tint(th, item),
            HorizontalGroup:new{
                align = "center",
                HorizontalSpan:new{ width = gap },
                CenterContainer:new{ dimen = Geom:new{ w = tile, h = h }, lead },
                HorizontalSpan:new{ width = gap },
                LeftContainer:new{ dimen = Geom:new{ w = name_w, h = h }, name },
                RightContainer:new{ dimen = Geom:new{ w = read_w, h = h }, UI.text(read, 15, { bold = true, color = th.ink }) },
                RightContainer:new{ dimen = Geom:new{ w = size_w, h = h }, UI.text(util.getFriendlySize(item.size), 15, { bold = true, color = th.ink }) },
                HorizontalSpan:new{ width = gap },
            },
        }
        -- On a gray screen there is no tint to separate the rows, so a thin rule does.
        local cell = VerticalGroup:new{ align = "left", row }
        if th.tinted then
            table.insert(cell, VerticalSpan:new{ width = vgap })
        else
            table.insert(cell, LineWidget:new{ dimen = Geom:new{ w = width, h = vgap }, background = th.bg })
            table.insert(cell, LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line })
        end
        local parent_dir = item.path:match("^(.*)/[^/]+$") or dir
        local function card()
            if item.is_dir then plugin:showFolder(item, parent_dir) else plugin:showDetails(item, parent_dir) end
        end
        if selecting and not reason then
            return UI.tappable(cell, function() screen:toggle(item) end, card)
        elseif item.is_dir then
            return UI.tappable(cell, function() screen:setDir(item.path) end, card)
        end
        -- A file's card opens on a tap or a long press, so a long press is the card's gesture on every row.
        return UI.tappable(cell, card, card)
    end

    -- One row of controls: search, the filters (file type, reading status), how it is sorted and which way, and Select.
    -- The labels are never squeezed: each button gets room for its own text.
    -- An arrow down is biggest, newest or most recent first (Z to A for names), an arrow up the other way round.
    local direction_button = UI.button(th, {
        icon = Icons.sortWidget(screen.sort, screen.descending, sp(24), th.ink, th.white), text = screen.descending and "↓" or "↑",
        callback = function() screen:flipSort() end,
    })
    -- Search is a magnifier until you search, then a chip with what you searched for; tapping that clears it.
    local search_button
    if screen.query then
        search_button = UI.button(th, {
            text = T(_("“%1” ✕"), shorten(screen.query, 10)), size = 15, background = th.accent, color = th.white,
            callback = function() screen:setQuery(nil) end,
        })
    else
        search_button = UI.button(th, {
            icon = Icons.searchWidget(sp(24), th.ink, th.white), text = "🔍",
            callback = function() screen:askQuery() end,
        })
    end
    local select_button = UI.button(th, {
        text = selecting and _("Done") or _("Select"), size = 15,
        background = selecting and th.accent or nil, color = selecting and th.white or nil,
        callback = function() screen:setSelecting(not selecting) end,
    })
    local active = (screen.filter and 1 or 0) + (status and 1 or 0)
    local rest_w = width - search_button:getSize().w - direction_button:getSize().w - select_button:getSize().w - 4 * gap
    local filter_w = math.floor(rest_w / 2)
    local controls = HorizontalGroup:new{
        align = "center",
        search_button,
        HorizontalSpan:new{ width = gap },
        UI.button(th, {
            text = active > 0 and T(_("Filter · %1 ▾"), active) or _("Filter ▾"), size = 15, width = filter_w,
            background = active > 0 and th.accent or nil, color = active > 0 and th.white or nil,
            callback = function() screen:askFilter() end,
        }),
        HorizontalSpan:new{ width = gap },
        UI.button(th, {
            text = T(_("Sort: %1 ▾"), Search.sortBy(screen.sort).short), size = 15, width = rest_w - filter_w,
            callback = function() screen:askSort() end,
        }),
        HorizontalSpan:new{ width = gap },
        direction_button,
        HorizontalSpan:new{ width = gap },
        select_button,
    }

    local header = VerticalGroup:new{ align = "left", VerticalSpan:new{ width = sp(4) }, controls, VerticalSpan:new{ width = sp(8) } }

    -- What can be ticked, and what is.
    local deletable, ticked = {}, 0
    for _, e in ipairs(entries) do
        if not Deleter.blockedReason(e, ctx) then
            table.insert(deletable, e)
            if screen.selected[e.path] then ticked = ticked + 1 end
        end
    end

    -- What is narrowing the list, each with a ✕ that undoes just that.
    local flat = screen.query or screen.filter or include
    local chips = HorizontalGroup:new{}
    local function add_chip(text, on_tap)
        if #chips > 0 then table.insert(chips, HorizontalSpan:new{ width = sp(6) }) end
        table.insert(chips, UI.chip(th, text .. " ✕", { active = true, on_tap = on_tap }))
    end
    if screen.only_books then add_chip(_("Books"), function() screen:toggleBooks() end) end
    if screen.filter then add_chip(screen.filter:upper(), function() screen:toggleFilter(screen.filter) end) end
    if status then add_chip(Search.status(status).short, function() screen:setStatus(nil) end) end
    if #chips > 0 then
        table.insert(header, chips)
        table.insert(header, VerticalSpan:new{ width = sp(6) })
    end
    -- The line under the controls: what to tick, or where you are and the way back up.
    if selecting then
        local all_ticked = #deletable > 0 and ticked == #deletable
        local box = UI.checkbox(th, all_ticked, { mixed = ticked > 0 and not all_ticked, disabled = #deletable == 0, size = tick_size })
        local label = UI.text(T(_("Select all · %1 ticked"), ticked), 15, { bold = true, color = th.ink })
        local line = HorizontalGroup:new{ align = "center", box, HorizontalSpan:new{ width = sp(10) }, label }
        table.insert(header, #deletable > 0 and UI.tappable(line, function() screen:select(deletable, not all_ticked) end) or line)
    elseif parent and not screen.only_books then
        table.insert(header, HorizontalGroup:new{
            align = "center",
            UI.button(th, { text = _("‹ Up"), size = 15, callback = function() screen:setDir(parent) end }),
            HorizontalSpan:new{ width = sp(10) },
            UI.text(T(_("Library / %1"), dir:sub(#root + 2)), 15, { color = th.muted, max_width = width - sp(120) }),
        })
    else
        local count = #entries
        local noun = flat and (screen.filter and (screen.filter:upper() .. " " .. N_("file", "files", count)) or N_("book", "books", count))
            or N_("item", "items", count)
        table.insert(header, UI.text(T(_("%1 · %2 %3"), name, count, noun), 15, { color = th.muted, max_width = width }))
    end
    table.insert(header, VerticalSpan:new{ width = sp(8) })

    -- Nothing to list: say why, and offer the one thing that undoes it. Drawn under the controls, over the `h` pixels the
    -- rows would have taken.
    local function empty_state(h)
        local d = Empty.describe({
            query = screen.query and shorten(screen.query, 20), ext = screen.filter, status = status,
            place = name, has_parent = parent ~= nil,
        })
        local actions = {
            search = function() screen:setQuery(nil) end,
            filter = function() screen:toggleFilter(screen.filter) end,
            status = function() screen:setStatus(nil) end,
            all = function() screen:clearFilters() end,
            up = function() screen:setDir(parent) end,
        }
        local room = width - 4 * gap
        local group = VerticalGroup:new{
            align = "center",
            UI.text(d.headline, 22, { bold = true, color = th.ink, max_width = room }),
            VerticalSpan:new{ width = sp(8) },
            UI.text(d.line, 15, { color = th.muted, max_width = room }),
        }
        if d.action then
            table.insert(group, VerticalSpan:new{ width = sp(18) })
            table.insert(group, UI.button(th, { text = d.label, size = 15, callback = actions[d.action] }))
        end
        return FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, background = th.white,
            CenterContainer:new{ dimen = Geom:new{ w = width, h = h }, group },
        }
    end

    return { hero = hero, header = header, count = #entries, row_h = ROW_H, build = build, empty = empty_state }
end
