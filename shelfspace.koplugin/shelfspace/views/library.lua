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
local Formats = require("shelfspace/formats")
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
        include = function(e)
            if status then return Deleter.isBook(e) and BookList.getBookStatus(e.path) == status end
            return Deleter.isSupported(e)
        end
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
    local tick = UI.CHECKBOX
    local read_w, size_w = sp(70), sp(92)
    -- A row is a gap, the tile, a gap, the name, the read share, the size, a gap, the checkbox and a gap: it runs the full width of
    -- the page, like the controls above, and the box ends a gap short of the edge.
    local name_w = width - tile - read_w - size_w - tick - 4 * gap
    local ctx = plugin:deleteContext()

    -- The tile in front of a name: three or four letters of its type on its kind's colour ("DIR" for a folder).
    local function type_tile(item, locked)
        local label = item.is_dir and "DIR" or Formats.label(item.name)
        return FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = sp(7), background = locked and th.line or Theme.kind(th, item),
            CenterContainer:new{ dimen = Geom:new{ w = tile, h = tile }, UI.text(label, #label >= 4 and 10 or 11, { bold = true, color = locked and th.white or Theme.on(th, item) }) },
        }
    end

    -- A row: a tile, the name, how much of the book is read, the size and a checkbox, on a tint of its kind's colour. Under
    -- the name goes only what the row needs to say: why it is locked, or where a search result is. Tapping opens a folder or
    -- says what a file is (the box at the right ticks it); pressing and holding opens the card of a file or folder.
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
        -- The box ticks the row (a row that cannot be deleted has a disabled one); the rest of the row opens it.
        local box = CenterContainer:new{
            dimen = Geom:new{ w = tick + 2 * gap, h = h }, -- a gap each side of the box: it ends a gap short of the row's edge
            UI.checkbox(th, screen.selected[item.path] ~= nil, { disabled = reason ~= nil }),
        }
        -- A tap on a locked row's box says why it cannot be ticked; it never falls through to the row and opens the folder.
        box = UI.tappable(box, function()
            if reason then plugin:notify(reason) else screen:toggle(item) end
        end)
        local name = UI.stack(UI.text(item.is_dir and (item.name .. "/") or item.name, 18,
            { bold = true, color = reason and th.muted or th.ink, max_width = name_w }), under)
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = sp(8), background = reason and th.bg or Theme.tint(th, item),
            HorizontalGroup:new{
                align = "center",
                HorizontalSpan:new{ width = gap },
                CenterContainer:new{ dimen = Geom:new{ w = tile, h = h }, type_tile(item, reason ~= nil) },
                HorizontalSpan:new{ width = gap },
                LeftContainer:new{ dimen = Geom:new{ w = name_w, h = h }, name },
                RightContainer:new{ dimen = Geom:new{ w = read_w, h = h }, UI.text(read, 15, { bold = true, color = th.ink }) },
                RightContainer:new{ dimen = Geom:new{ w = size_w, h = h }, UI.text(util.getFriendlySize(item.size), 15, { bold = true, color = reason and th.muted or th.ink }) },
                box,
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
        if item.is_dir then
            return UI.tappable(cell, function() screen:setDir(item.path) end, card)
        end
        -- A file's card opens on a tap or a long press, so a long press is the card's gesture on every row.
        return UI.tappable(cell, card, card)
    end

    -- One row of controls: search, the filters (file type, reading status), how it is sorted and which way.
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
    local active = (screen.filter and 1 or 0) + (status and 1 or 0)
    local rest_w = width - search_button:getSize().w - direction_button:getSize().w - 3 * gap
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
    }

    local header = VerticalGroup:new{ align = "left", VerticalSpan:new{ width = sp(4) }, controls, VerticalSpan:new{ width = sp(8) } }

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
    -- The line under the controls: where you are and the way back up, or how many there are.
    local up_row = parent and not screen.only_books
    local count_text
    local count = #entries
    local noun = flat and (screen.filter and (screen.filter:upper() .. " " .. N_("file", "files", count)) or N_("book", "books", count))
        or N_("item", "items", count)
    if not up_row and #entries > 0 then
        count_text = UI.text(T(_("%1 · %2 %3"), name, count, noun), 15, { color = th.muted, max_width = width })
    end
    if #chips > 0 then
        -- The count goes on the chips' own line, at the right (ending where the boxes below do), when there is room for both.
        local chips_size = chips:getSize()
        if count_text and chips_size.w + gap + count_text:getSize().w <= width - gap then
            table.insert(header, HorizontalGroup:new{
                align = "center",
                chips,
                RightContainer:new{ dimen = Geom:new{ w = width - chips_size.w - gap, h = chips_size.h }, count_text },
                HorizontalSpan:new{ width = gap },
            })
            count_text = nil
        else
            table.insert(header, chips)
            table.insert(header, VerticalSpan:new{ width = sp(6) })
        end
    end
    if up_row then
        -- Where you are, with how many; the way back up is the first row of the list.
        table.insert(header, UI.text(T(_("Library / %1 · %2 %3"), dir:sub(#root + 2), count, noun), 15, { color = th.muted, max_width = width }))
    elseif count_text then
        table.insert(header, count_text)
    end
    table.insert(header, VerticalSpan:new{ width = sp(8) })

    -- The line over the boxes it ticks. Its box ticks the rows on the page you are looking at, and only those (`first` to `last`, which
    -- the screen knows once it has paged the list), so a delete is never of rows you have not seen. An empty list says why in the
    -- space below and needs no such line, so it gets none.
    local function select_all(first, last)
        if #entries == 0 then return nil end
        local page, ticked = {}, 0
        for i = first, last do
            local e = entries[i]
            if e and not Deleter.blockedReason(e, ctx) then
                table.insert(page, e)
                if screen.selected[e.path] then ticked = ticked + 1 end
            end
        end
        local all_ticked = #page > 0 and ticked == #page
        -- The label always says what a Delete would act on in total, whichever pages it was ticked on (the box is for this page).
        local chosen = screen:chosen()
        local lines = VerticalGroup:new{
            align = "left",
            UI.selectAll(th, width, gap, {
                label = #chosen > 0 and T(_("Select all · %1 selected · %2"), #chosen, util.getFriendlySize(Selection.size(chosen)))
                    or _("Select all"),
                checked = all_ticked, mixed = ticked > 0 and not all_ticked, disabled = #page == 0,
                on_tap = function() screen:select(page, not all_ticked) end,
            }),
            VerticalSpan:new{ width = sp(8) },
        }
        -- Inside a folder the first row of every page is "../", the way back up.
        if up_row then
            local h = ROW_H - vgap
            local row = FrameContainer:new{
                bordersize = 0, padding = 0, margin = 0, radius = sp(8), background = th.tinted and th.chip or nil,
                HorizontalGroup:new{
                    align = "center",
                    HorizontalSpan:new{ width = gap },
                    CenterContainer:new{ dimen = Geom:new{ w = tile, h = h }, Icons.upWidget(sp(26), th.ink) },
                    HorizontalSpan:new{ width = gap },
                    LeftContainer:new{ dimen = Geom:new{ w = width - tile - 2 * gap, h = h }, UI.text("../", 18, { bold = true, color = th.ink }) },
                },
            }
            local cell = VerticalGroup:new{ align = "left", row }
            if th.tinted then
                table.insert(cell, VerticalSpan:new{ width = vgap })
            else
                table.insert(cell, LineWidget:new{ dimen = Geom:new{ w = width, h = vgap }, background = th.bg })
                table.insert(cell, LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line })
            end
            table.insert(lines, UI.tappable(cell, function() screen:setDir(parent) end))
        end
        return lines
    end

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

    return { hero = hero, header = header, count = #entries, row_h = ROW_H, build = build, empty = empty_state, select_all = select_all }
end
