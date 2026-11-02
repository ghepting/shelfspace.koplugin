local Device = require("device")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local IconWidget = require("ui/widget/iconwidget")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local InputContainer = require("ui/widget/container/inputcontainer")
local ButtonDialog = require("ui/widget/buttondialog")
local InputDialog = require("ui/widget/inputdialog")
local LineWidget = require("ui/widget/linewidget")
local OverlapGroup = require("ui/widget/overlapgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local Size = require("ui/size")
local UIManager = require("ui/uimanager")
local logger = require("logger")
local time = require("ui/time")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template
local Screen = Device.screen

local About = require("shelfspace/about")
local Deleter = require("shelfspace/deleter")
local Stats = require("shelfspace/stats")
local Icons = require("shelfspace/icons")
local Theme = require("shelfspace/theme")
local Search = require("shelfspace/search")
local Selection = require("shelfspace/selection")
local UI = require("shelfspace/ui")
local Zones = require("shelfspace/zones")
local sp = UI.sp

-- The title, with the ShelfSpace mark on the left (it opens the menu) and a close button on the right; our own so
-- the icons can be transparent on the page colour. On a colour screen it is a band of the accent colour with the mark and
-- the title in white; on a gray one it is plain, with a rule under it.
local function header(th, width, on_menu, on_close)
    local h = sp(46)
    local close_icon = th.tinted and UI.text("✕", 26, { color = th.on_band })
        or IconWidget:new{ icon = "close", alpha = true, width = sp(26), height = sp(26) }
    local close = UI.tappable(CenterContainer:new{ dimen = Geom:new{ w = sp(56), h = h }, close_icon }, on_close)
    local mark = Icons.markWidget(sp(44), th.on_band, th.band)
    local menu = mark and UI.tappable(CenterContainer:new{
        dimen = Geom:new{ w = sp(76), h = h },
        mark,
    }, on_menu) or HorizontalSpan:new{ width = 0 }
    local bar = FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, background = th.band,
        OverlapGroup:new{
            dimen = Geom:new{ w = width, h = h },
            CenterContainer:new{
                dimen = Geom:new{ w = width, h = h },
                UI.text(_("ShelfSpace"), 22, { face = "tfont", color = th.on_band }),
            },
            LeftContainer:new{
                dimen = Geom:new{ w = width, h = h },
                HorizontalGroup:new{ HorizontalSpan:new{ width = sp(6) }, menu },
            },
            RightContainer:new{ dimen = Geom:new{ w = width, h = h }, close },
        },
    }
    return VerticalGroup:new{
        align = "left",
        bar,
        not th.tinted and LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.medium }, background = th.ink } or VerticalSpan:new{ width = 0 },
    }
end

local views = {
    library = require("shelfspace/views/library"),
    koreader = require("shelfspace/views/koreader"),
    duplicates = require("shelfspace/views/duplicates"),
}

-- One screen with a tab per view. A view returns { hero, body } for a plain page,
-- or { hero, count, row_h, build } for a paged list; `message` replaces the body.
local ShelfScreen = InputContainer:extend{
    plugin = nil, -- the ShelfSpace plugin: usage, tree, and the delete / clear actions
    tab = "library",
    dir = nil, -- folder shown on the Library tab
    only_books = false, -- the list is every book in the library, whichever folder it is in (the Books row of the chart)
    sort = "size", -- how the Library orders rows: a category id from Search.SORTS
    descending = true, -- ...and which way: biggest, newest or most recent first (names: Z to A)
    query = nil, -- name search in the Library, over the shown folder and everything under it
    status = nil, -- a reading status (Search.STATUSES) the Library is narrowed to, e.g. "complete" for finished books
    filter = nil, -- one file type (a Stats.extension) the Library is narrowed to, from the Filter button
    dup_set = nil, -- the set of duplicates being looked at, by id; nil shows the list of sets
    dup_ignored = false, -- the list shows the sets you chose to keep, not the ones still to deal with
    dup_keep = nil, -- set id -> the copy chosen to keep, when it is not the suggested one
}

function ShelfScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.covers_fullscreen = true
    self.theme = Theme.get()
    self.pages = {}
    self.left_at = {} -- pageKey -> the page of the Library a folder was on when you left it
    self.selected = {} -- path -> entry; survives paging, folders and searches
    self.dup_keep = {}
    if Device:hasKeys() then
        self.key_events.Close = { { Device.input.group.Back } }
        self.key_events.NextPage = { { Device.input.group.PgFwd } }
        self.key_events.PrevPage = { { Device.input.group.PgBack } }
    end
    if Device:isTouchDevice() then
        self.ges_events.SwipePage = { GestureRange:new{ ges = "swipe", range = self.dimen } }
    end
    self:rebuild()
end

function ShelfScreen:refresh()
    if self.closed then return end
    self:rebuild()
    self:buildActionBar()
    -- "partial", not the fast "ui": a new page drawn over the last one with "ui" leaves its remnants showing, most on colour e-ink.
    UIManager:setDirty(self, "partial")
end

-- What is ticked comes up as a bar (how many, how big, and what to do with them: Delete in the Library, Clear on the KOReader tab,
-- which hands in its own as `view.bar`), drawn in the middle of the pager row, so ticking moves nothing and covers no row. The screen draws it itself, last, and claims taps inside it:
-- a widget of its own on top would take every other tap on the page with it, since KOReader only
-- gives taps to the topmost widget.
function ShelfScreen:buildActionBar()
    self.action_bar, self.bar_hits, self.bar_zone = nil, nil, nil
    local count, bytes, buttons
    if self.tab == "library" then
        local chosen = self:chosen()
        if #chosen == 0 then return end
        count, bytes = #chosen, Selection.size(chosen)
        buttons = {
            { text = _("Cancel"), callback = function() self:clearSelection() end },
            { text = _("Delete"), danger = true, callback = function() self.plugin:confirmDeleteMany(chosen) end },
        }
    elseif self.tab == "koreader" and self.view_bar then
        count, bytes, buttons = self.view_bar.count, self.view_bar.bytes, self.view_bar.buttons
    else
        return
    end
    -- The fullest label that fits the slot: "4 selected · 660.3 MB", then "4 selected" (the size is on the Select all line above), and
    -- only then the bare number.
    local slot, text = self.bar_slot, util.getFriendlySize(bytes or 0)
    local bar, hits, size
    local labels = self.view_bar and self.view_bar.labels or { T(_("%1 selected · %2"), count, text), T(_("%1 selected"), count), tostring(count) }
    for _, label in ipairs(labels) do
        bar, hits = UI.floatingBar(self.theme, label, buttons, { compact = true })
        size = bar:getSize()
        if size.w <= slot.w then break end
    end
    local x = slot.x + math.floor((slot.w - size.w) / 2)
    local y = slot.y + math.floor((slot.h - size.h) / 2)
    self.action_bar, self.bar_hits = bar, hits
    self.bar_x, self.bar_y = x, y
    self.bar_zone = Geom:new{ x = x, y = y, w = size.w, h = size.h }
end

function ShelfScreen:paintTo(bb, x, y)
    InputContainer.paintTo(self, bb, x, y)
    if self.action_bar then self.action_bar:paintTo(bb, x + self.bar_x, y + self.bar_y) end
end

-- KOReader hands an event to a container's children before the container itself, so the table under the
-- bar would see a tap on the bar first. The screen looks at taps itself, ahead of its children: a tap
-- inside the bar is the bar's (a button's, or nobody's between the buttons) and never reaches the table.
function ShelfScreen:propagateEvent(event)
    local ges = event.handler == "onGesture" and event.args and event.args[1]
    if ges and ges.ges == "tap" and self.bar_zone and ges.pos and self.bar_zone:contains(ges.pos) then
        for _, hit in ipairs(self.bar_hits or {}) do
            if hit.widget.dimen and hit.widget.dimen:contains(ges.pos) then
                hit.callback()
                break
            end
        end
        return true
    end
    return InputContainer.propagateEvent(self, event)
end

-- Puts the Library back to everything: no search, no file type, no status.
-- What is selected is what a Delete acts on, so it must always be on screen: paging keeps it, but a change of folder, search, filter or
-- status shows other rows, and the selection goes.
function ShelfScreen:viewChanged()
    self.selected = {}
end

function ShelfScreen:clearFilters()
    self:viewChanged()
    self.query, self.filter, self.status, self.only_books = nil, nil, nil, false
    self.pages.library = 1
    self:refresh()
end

function ShelfScreen:clearSelection()
    self.selected = {}
    self:refresh()
end

-- The duplicates list opens from a row on Overview, so Overview stays lit while you are in it.
function ShelfScreen:openDuplicates()
    self.tab = "duplicates"
    self.dup_set = nil
    self.dup_ignored = false
    self.pages.duplicates = 1
    self:refresh()
end

function ShelfScreen:openSet(id)
    self.dup_set = id
    self.pages.duplicates = 1
    self:refresh()
end

-- Back to the list, whichever of the two it was opened from.
function ShelfScreen:closeSet()
    self.dup_set = nil
    self.pages.duplicates = 1
    self:refresh()
end

-- The sets you chose to keep as they are, and the way back to the ones still to deal with.
function ShelfScreen:showIgnoredDuplicates()
    self.dup_set = nil
    self.dup_ignored = true
    self.pages.duplicates = 1
    self:refresh()
end

function ShelfScreen:showActiveDuplicates()
    self.dup_set = nil
    self.dup_ignored = false
    self.pages.duplicates = 1
    self:refresh()
end

function ShelfScreen:currentSet()
    for _, list in ipairs({ self.plugin.duplicates or {}, self.plugin.ignored_duplicates or {} }) do
        for _, set in ipairs(list) do
            if set.id == self.dup_set then return set end
        end
    end
end

-- The copy that will be kept: the one the book you are reading, else the one you tapped, else the suggestion.
function ShelfScreen:keeper(set)
    for i, copy in ipairs(set.copies) do
        if self.plugin:copyInfo(copy).locked then return i end
    end
    local chosen = self.dup_keep[set.id]
    return chosen and chosen <= #set.copies and chosen or 1
end

function ShelfScreen:setKeeper(set, i)
    self.dup_keep[set.id] = i
    self:refresh()
end

-- The menu behind the ShelfSpace mark at the top left: what is not a page of its own.
function ShelfScreen:showMenu()
    local plugin = self.plugin
    local version = About.info(plugin.path).version
    plugin:showDialog(function()
        local dialog
        local function act(fn)
            return function()
                UIManager:close(dialog)
                fn()
            end
        end
        -- A grid, like the About card, two to a row. Four buttons make a 2 x 2 with Exit in the last cell;
        -- with sets set aside there is a fifth, and Exit takes the bottom row alone.
        local function button(text, fn) return { text = text, callback = act(fn) } end
        local cells = {
            button(_("About"), function() plugin:showAbout() end),
            button(_("Check for updates"), function() plugin:checkForUpdates(version) end),
            button(_("Changelog"), function() plugin:showChangelog() end),
        }
        local exit = button(_("Exit ShelfSpace"), function() self:onClose() end)
        local kept = #(plugin.ignored_duplicates or {})
        if kept > 0 then
            table.insert(cells, button(T(_("Kept on purpose · %1"), kept), function() self:openDuplicates() self:showIgnoredDuplicates() end))
        end
        local buttons = {}
        if kept > 0 then
            for i = 1, #cells, 2 do table.insert(buttons, { cells[i], cells[i + 1] }) end
            table.insert(buttons, { exit })
        else
            table.insert(cells, exit)
            for i = 1, #cells, 2 do table.insert(buttons, { cells[i], cells[i + 1] }) end
        end
        dialog = ButtonDialog:new { title = _("ShelfSpace"), title_align = "center", buttons = buttons }
        return dialog
    end)
end

function ShelfScreen:switchTab(id)
    -- A selection belongs to the tab it was made on.
    if id ~= self.tab then self.selected = {} end
    self.tab = id
    self:refresh()
end

-- Jump to the Library tab showing `dir`.
function ShelfScreen:openBrowse(dir)
    self.tab = "library"
    self.only_books = false
    self:setDir(dir)
end

-- The Library remembers the page each folder was on (for the sort and status it was shown with), so going Up
-- lands where you were instead of on page 1.
function ShelfScreen:pageKey(dir)
    return table.concat({ dir or self.plugin.root, tostring(self.status), self.sort, tostring(self.descending) }, "|")
end

function ShelfScreen:setDir(dir)
    self:viewChanged()
    -- A page of search results or of one file type says nothing about the folder's own pages.
    if not self.query and not self.filter then self.left_at[self:pageKey(self.dir)] = self.pages.library end
    self.dir = dir
    self.query = nil
    self.filter = nil
    self.pages.library = self.left_at[self:pageKey(dir)] or 1
    self:refresh()
end

-- Unlike the search and the type chip, the status stays when you change folder, like the sort order:
-- it is how the library is shown, not something you are looking for.
function ShelfScreen:setStatus(id)
    self:viewChanged()
    self.status = id
    self.pages.library = 1
    self:refresh()
end

-- The Books row of the chart: the list becomes every book in the library, wherever it is, or goes back to the folder it was on.
function ShelfScreen:toggleBooks()
    self:viewChanged()
    self.only_books = not self.only_books
    if self.only_books then self.dir = self.plugin.root end
    self.pages.library = 1
    self:refresh()
end

-- The file type and the reading status in one dialog: each is a choice, the current one ticked, and tapping it again clears it.
function ShelfScreen:askFilter()
    local tree = self.plugin.tree
    if not tree then return end
    self.plugin:showDialog(function()
        local dialog
        local function pick(fn) return function() UIManager:close(dialog) fn() end end
        local types = {}
        for _, x in ipairs(Stats.topExtensions(Stats.typeBytes(tree, self.plugin.root, Deleter.isSupported), 4)) do
            local ext = x.ext
            table.insert(types, {
                text = (self.filter == ext and "✓  " or "") .. ext:upper(),
                callback = pick(function() self:toggleFilter(ext) end),
            })
        end
        local buttons = { types }
        table.insert(buttons, { { text = _("Show"), enabled = false } })
        for _, option in ipairs(Search.STATUSES) do
            table.insert(buttons, { {
                text = (option.id == self.status and "✓  " or "     ") .. option.label,
                callback = pick(function() self:setStatus(option.id) end),
            } })
        end
        table.insert(buttons, { { text = _("Clear filters"), callback = pick(function() self:clearFilters() end) } })
        dialog = ButtonDialog:new{ title = _("Filter"), title_align = "center", buttons = buttons }
        return dialog
    end)
end

-- Every status filter at once, the current one ticked.
function ShelfScreen:askStatus()
    self.plugin:showDialog(function()
        local dialog
        local buttons = {}
        for _, option in ipairs(Search.STATUSES) do
            table.insert(buttons, { {
                text = (option.id == self.status and "✓  " or "     ") .. option.label,
                callback = function()
                    UIManager:close(dialog)
                    self:setStatus(option.id)
                end,
            } })
        end
        dialog = ButtonDialog:new{ title = _("Show"), title_align = "center", buttons = buttons }
        return dialog
    end)
end

-- Switches the file-type filter to `ext`, or off when it is already on.
function ShelfScreen:toggleFilter(ext)
    self:viewChanged()
    self.filter = self.filter ~= ext and ext or nil
    self.pages.library = 1
    self:refresh()
end

-- Ticks or unticks one row; `key` identifies it (a path in the Library, a title on the KOReader tab).
function ShelfScreen:toggleKey(key, value)
    self.selected[key] = (not self.selected[key]) and (value or true) or nil
    self:refresh()
end

function ShelfScreen:toggle(entry)
    self:toggleKey(entry.path, entry)
end

function ShelfScreen:selectKeys(keys, on)
    for _, key in ipairs(keys) do self.selected[key] = on and true or nil end
    self:refresh()
end

function ShelfScreen:select(entries, on)
    for _, e in ipairs(entries) do self.selected[e.path] = on and e or nil end
    self:refresh()
end

-- What a delete would act on: the selection, minus anything inside a selected folder.
function ShelfScreen:chosen()
    local list = {}
    for _, e in pairs(self.selected) do table.insert(list, e) end
    return Selection.collapse(list)
end

-- Picks a category, in the direction that suits it.
function ShelfScreen:setSort(id)
    self.sort = id
    self.descending = Search.sortBy(id).descending
    self.pages.library = 1
    self:refresh()
end

function ShelfScreen:flipSort()
    self.descending = not self.descending
    self.pages.library = 1
    self:refresh()
end

-- Every category at once, the current one ticked.
function ShelfScreen:askSort()
    self.plugin:showDialog(function()
        local dialog
        local buttons = {}
        for _, option in ipairs(Search.SORTS) do
            table.insert(buttons, { {
                text = (option.id == self.sort and "✓  " or "     ") .. option.label,
                callback = function()
                    UIManager:close(dialog)
                    self:setSort(option.id)
                end,
            } })
        end
        dialog = ButtonDialog:new{ title = _("Sort by"), title_align = "center", buttons = buttons }
        return dialog
    end)
end

function ShelfScreen:setQuery(query)
    self:viewChanged()
    query = query and query:match("^%s*(.-)%s*$")
    self.query = query ~= "" and query or nil
    self.pages.library = 1
    self:refresh()
end

function ShelfScreen:askQuery()
    self.plugin:showDialog(function()
        local dialog
        dialog = InputDialog:new{
            title = _("Search by name"),
            input = self.query or "",
            buttons = { {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(dialog) end },
                {
                    text = _("Search"),
                    is_enter_default = true,
                    callback = function()
                        local text = dialog:getInputText()
                        UIManager:close(dialog)
                        self:setQuery(text)
                    end,
                },
            } },
        }
        return dialog
    end)
    self.plugin.popup:onShowKeyboard()
end

function ShelfScreen:setPage(n)
    self.pages[self.tab] = n
    self:refresh()
end

function ShelfScreen:rebuild()
    local started = time.now()
    local th = self.theme
    local pad = sp(16)
    local width = self.dimen.w - 2 * pad
    local gap = sp(10)
    -- Sideways, the screen is wider than it is tall: the chart or summary takes a column of its own, and the controls, the list and
    -- the pager the rest, so the list gets the full height instead of what a tall hero leaves it.
    local landscape = self.dimen.w > self.dimen.h
    local hero_w = landscape and math.floor(width * 0.36) or width
    local main_w = landscape and (width - hero_w - 2 * gap) or width

    local titlebar = header(th, self.dimen.w, function() self:showMenu() end, function() self:onClose() end)
    -- Duplicates is a tab only while there is something to decide; the sets kept on purpose live in the menu.
    local tabs = { { id = "library", label = _("Library") }, { id = "koreader", label = _("KOReader") } }
    local sets = #(self.plugin.duplicates or {})
    if sets > 0 or self.tab == "duplicates" then
        table.insert(tabs, { id = "duplicates", label = sets > 0 and T(_("Duplicates · %1"), sets) or _("Duplicates") })
    end
    local top = VerticalGroup:new{
        align = "left",
        UI.tabbar(th, width, tabs, self.tab, function(id) self:switchTab(id) end),
        VerticalSpan:new{ width = gap },
    }
    local layout = {
        landscape = landscape, hero_w = hero_w,
        hero_h = self.dimen.h - titlebar:getSize().h - 2 * pad - top:getSize().h,
    }
    local view = views[self.tab](self, th, main_w, layout)
    self.view_bar = view.bar

    -- `body` is the whole page under the title; `col` is where the list goes: the page itself, or the right-hand column.
    local body, col
    if landscape then
        col = VerticalGroup:new{ align = "left" }
        body = VerticalGroup:new{
            align = "left", top,
            HorizontalGroup:new{
                align = "top",
                LeftContainer:new{ dimen = Geom:new{ w = hero_w, h = view.hero:getSize().h }, view.hero }, -- as tall as it is, so it sits at the top
                HorizontalSpan:new{ width = 2 * gap },
                col,
            },
        }
    else
        body = top
        table.insert(body, view.hero)
        table.insert(body, VerticalSpan:new{ width = gap })
        body:resetLayout() -- the tab bar was measured for the hero's room before the hero was added
        col = body
    end

    if view.build then
        if view.header then table.insert(col, view.header) end
        -- A view with a `table_head` draws its rows as a table: a rounded, outlined box holding the head and the rows.
        local frame_w = Size.border.default * 2
        -- A view with `select_all` has a line over its rows that ticks the page; it is built once the page is known, so its height is
        -- measured here on an empty one.
        local probe_all = view.select_all and view.select_all(1, 0)
        local above = landscape and (top:getSize().h + col:getSize().h) or col:getSize().h
        local used = titlebar:getSize().h + 2 * pad + above
            + (view.table_head and view.table_head:getSize().h + frame_w or 0)
            + (probe_all and probe_all:getSize().h or 0)
        local cell = landscape and sp(40) or nil -- narrower arrows, so the bar has room beside a list that is not full width
        local pager_h = UI.pager(th, main_w, 1, 1, function() end, { cell_w = cell }):getSize().h
        -- A little air between the last row and the pager row, which the floating bar fills when something is ticked.
        local pager_gap = sp(6)
        local avail = self.dimen.h - used - pager_h - pager_gap
        local per_page = math.max(1, math.floor(avail / view.row_h))
        -- Whatever is left over (less than one row) is shared out among the rows, so the list fills the screen
        -- at any height instead of ending short; but never by more than a quarter of a row each. (Cards, which must
        -- stay grouped, say `fixed_rows` and are not stretched.)
        local row_h = view.row_h + (view.fixed_rows and 0 or math.min(math.floor(view.row_h / 4), math.floor((avail - per_page * view.row_h) / per_page)))
        row_h = math.max(row_h, view.row_h)
        local pages = math.max(1, math.ceil(view.count / per_page))
        local page = math.min(self.pages[self.tab] or 1, pages)
        self.pages[self.tab] = page
        self.page_count = pages
        local first = (page - 1) * per_page + 1
        local last = math.min(view.count, first + per_page - 1)
        if probe_all then table.insert(col, view.select_all(first, last)) end
        local rows = col
        if view.table_head then rows = VerticalGroup:new{ align = "left", view.table_head } end
        if view.count == 0 and view.empty then
            table.insert(rows, view.empty(per_page * row_h))
        else
            for i = first, last do table.insert(rows, view.build(i, row_h)) end
        end
        if view.table_head then table.insert(col, UI.rounded(th, rows, sp(10), Size.border.default)) end
        local shown = (view.count == 0 and view.empty) and per_page or (last - first + 1) -- the empty state takes the whole page
        -- Cards are not stretched, so what is left over goes above the pager row, which stays at the bottom.
        local slack = view.fixed_rows and math.max(0, avail - per_page * row_h) or 0
        table.insert(col, VerticalSpan:new{ width = (per_page - shown) * row_h + pager_gap + slack })
        -- While rows are ticked the floating bar is drawn in the middle of this row, in place of "Page 1 of 3"; the arrows stay.
        table.insert(col, UI.pager(th, main_w, page, pages, function(n) self:setPage(n) end,
            { cell_w = cell, hide_label = (self.tab == "library" and next(self.selected) ~= nil) or (self.tab == "koreader" and self.view_bar ~= nil) }))
    else
        self.page_count = 1
        if view.message then
            table.insert(col, UI.text(view.message, 20, { color = th.muted }))
        else
            table.insert(col, view.body)
        end
        if view.bottom then
            table.insert(col, VerticalSpan:new{ width = sp(14) })
            table.insert(col, view.bottom)
        end
    end

    -- Where the floating bar goes: the middle of the pager row, between its arrows; a tab with no pager gives it the whole row.
    local geo = UI.pagerGeometry(main_w, landscape and sp(40) or nil)
    local left = pad + (landscape and (hero_w + 2 * gap) or 0)
    self.bar_slot = { x = left + 2 * geo.cell_w, y = self.dimen.h - pad - geo.h, w = geo.centre_w, h = geo.h }
    if not view.build then self.bar_slot.x, self.bar_slot.w = left, main_w end
    -- getSize() above cached the groups' heights before the rows were added
    col:resetLayout()
    body:resetLayout()
    self[1] = FrameContainer:new{
        bordersize = 0, padding = 0, margin = 0, background = th.bg,
        width = self.dimen.w, height = self.dimen.h,
        VerticalGroup:new{
            align = "left",
            titlebar,
            FrameContainer:new{ bordersize = 0, padding = pad, margin = 0, background = th.bg, body },
        },
    }
    logger.info(string.format("ShelfSpace: built %s tab in %d ms", self.tab, time.to_ms(time.since(started))))
end

-- Touches ShelfSpace does not use go on to KOReader underneath it (see zones.lua): the gesture that opens its top
-- menu, and the ones you have set. The edge swipes and corner holds you gave an action run ahead of ShelfSpace's own
-- use of them; a touch is not forwarded while the screensaver is waiting for its wake gesture.
function ShelfScreen:handleEvent(event)
    if event.handler == "onGesture" and not Device.screen_saver_lock then
        local ev, host = event.args and event.args[1], self.plugin.ui
        if Zones.forwardUserFirst(ev, host) then return true end
        if InputContainer.handleEvent(self, event) then return true end
        return Zones.forward(ev, host)
    end
    return InputContainer.handleEvent(self, event)
end

function ShelfScreen:onSwipePage(arg, ges)
    local page = self.pages[self.tab] or 1
    if ges.direction == "west" and page < self.page_count then
        self:setPage(page + 1)
        return true
    elseif ges.direction == "east" and page > 1 then
        self:setPage(page - 1)
        return true
    end
end

function ShelfScreen:onNextPage()
    local page = self.pages[self.tab] or 1
    if page < self.page_count then self:setPage(page + 1) end
    return true
end

function ShelfScreen:onPrevPage()
    local page = self.pages[self.tab] or 1
    if page > 1 then self:setPage(page - 1) end
    return true
end

function ShelfScreen:onShow()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function ShelfScreen:onCloseWidget()
    self.closed = true
    UIManager:setDirty(nil, "ui")
end

function ShelfScreen:onClose()
    UIManager:close(self)
    return true
end

return ShelfScreen
