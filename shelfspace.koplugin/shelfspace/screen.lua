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
local Icons = require("shelfspace/icons")
local Theme = require("shelfspace/theme")
local Search = require("shelfspace/search")
local Selection = require("shelfspace/selection")
local UI = require("shelfspace/ui")
local sp = UI.sp

-- The title with the ShelfSpace mark on the left and the menu on the right; our own so the icons can be
-- transparent on the page colour. Everything else (updates, the changelog, About, closing) is in the menu.
local function header(th, width, on_menu)
    local h = sp(46)
    local menu = UI.tappable(CenterContainer:new{
        dimen = Geom:new{ w = sp(56), h = h },
        IconWidget:new{ icon = "appbar.menu", alpha = true, width = sp(26), height = sp(26) },
    }, on_menu)
    local mark = Icons.markWidget(sp(44), th.ink, th.bg)
    return VerticalGroup:new{
        align = "left",
        OverlapGroup:new{
            dimen = Geom:new{ w = width, h = h },
            CenterContainer:new{
                dimen = Geom:new{ w = width, h = h },
                UI.text(_("ShelfSpace"), 22, { face = "tfont", color = th.ink }),
            },
            LeftContainer:new{
                dimen = Geom:new{ w = width, h = h },
                HorizontalGroup:new{ HorizontalSpan:new{ width = sp(16) }, mark or HorizontalSpan:new{ width = 0 } },
            },
            RightContainer:new{ dimen = Geom:new{ w = width, h = h }, menu },
        },
        LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.medium }, background = th.ink },
    }
end

local views = {
    overview = require("shelfspace/views/overview"),
    browse = require("shelfspace/views/browse"),
    koreader = require("shelfspace/views/koreader"),
    duplicates = require("shelfspace/views/duplicates"),
}

-- One screen with a tab per view. A view returns { hero, body } for a plain page,
-- or { hero, count, row_h, build } for a paged list; `message` replaces the body.
local ShelfScreen = InputContainer:extend{
    plugin = nil, -- the ShelfSpace plugin: usage, tree, and the delete / clear actions
    tab = "overview",
    dir = nil, -- folder shown on the Browse tab
    sort = "size", -- how Browse orders rows: a category id from Search.SORTS
    descending = true, -- ...and which way: biggest, newest or most recent first (names: Z to A)
    query = nil, -- name search on Browse, over the shown folder and everything under it
    status = nil, -- a reading status (Search.STATUSES) Browse is narrowed to, e.g. "complete" for finished books
    filter = nil, -- one file type (a Stats.extension) Browse is narrowed to, from the chips in the header
    selecting = false, -- Browse is in select mode: rows get checkboxes
    dup_set = nil, -- the set of duplicates being looked at, by id; nil shows the list of sets
    dup_ignored = false, -- the list shows the sets you chose to keep, not the ones still to deal with
    dup_keep = nil, -- set id -> the copy chosen to keep, when it is not the suggested one
}

function ShelfScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.covers_fullscreen = true
    self.theme = Theme.get()
    self.pages = {}
    self.left_at = {} -- pageKey -> the page of Browse a folder was on when you left it
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
    UIManager:setDirty(self, "ui")
end

-- What is ticked on Browse floats over the page as a bar (how many, how big, and Delete), so ticking
-- never moves the table under your finger. The screen draws it itself, last, and claims taps inside it:
-- a widget of its own on top would take every other tap on the page with it, since KOReader only
-- gives taps to the topmost widget.
function ShelfScreen:buildActionBar()
    self.action_bar, self.bar_hits, self.bar_zone = nil, nil, nil
    local chosen = self.tab == "browse" and self:chosen() or {}
    if #chosen == 0 then return end
    local bar, hits = UI.floatingBar(self.theme, T(_("%1 selected · %2"), #chosen, util.getFriendlySize(Selection.size(chosen))), {
        { text = "✕", callback = function() self:clearSelection() end },
        { text = _("Delete"), danger = true, callback = function() self.plugin:confirmDeleteMany(chosen) end },
    })
    local size = bar:getSize()
    local x = math.floor((self.dimen.w - size.w) / 2)
    local y = self.dimen.h - size.h - sp(76) -- over the bottom rows, clear of the pager
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

-- Puts Browse back to everything: no search, no file type, no status.
function ShelfScreen:clearFilters()
    self.query, self.filter, self.status = nil, nil, nil
    self.pages.browse = 1
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

-- The menu behind the icon at the top right: what is not a page of its own.
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
        local buttons = {
            { { text = T(_("Check for updates (v%1)"), version), callback = act(function() plugin:checkForUpdates(version) end) } },
            { { text = _("View changelog"), callback = act(function() plugin:showChangelog() end) } },
            { { text = _("About ShelfSpace"), callback = act(function() plugin:showAbout() end) } },
        }
        local kept = #(plugin.ignored_duplicates or {})
        if kept > 0 then
            table.insert(buttons, { {
                text = T(_("Kept on purpose · %1"), kept),
                callback = act(function() self:openDuplicates() self:showIgnoredDuplicates() end),
            } })
        end
        table.insert(buttons, { { text = _("Close ShelfSpace"), callback = act(function() self:onClose() end) } })
        dialog = ButtonDialog:new { title = _("ShelfSpace"), title_align = "center", buttons = buttons }
        return dialog
    end)
end

function ShelfScreen:switchTab(id)
    -- A selection belongs to the tab it was made on.
    if id ~= self.tab then self.selecting, self.selected = false, {} end
    self.tab = id
    self:refresh()
end

-- Jump to the Browse tab showing `dir`.
function ShelfScreen:openBrowse(dir)
    self.tab = "browse"
    self:setDir(dir)
end

-- Browse remembers the page each folder was on (for the sort and status it was shown with), so going Up
-- lands where you were instead of on page 1.
function ShelfScreen:pageKey(dir)
    return table.concat({ dir or self.plugin.root, tostring(self.status), self.sort, tostring(self.descending) }, "|")
end

function ShelfScreen:setDir(dir)
    -- A page of search results or of one file type says nothing about the folder's own pages.
    if not self.query and not self.filter then self.left_at[self:pageKey(self.dir)] = self.pages.browse end
    self.dir = dir
    self.query = nil
    self.filter = nil
    self.pages.browse = self.left_at[self:pageKey(dir)] or 1
    self:refresh()
end

-- Unlike the search and the type chip, the status stays when you change folder, like the sort order:
-- it is how the library is shown, not something you are looking for.
function ShelfScreen:setStatus(id)
    self.status = id
    self.pages.browse = 1
    self:refresh()
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
    self.filter = self.filter ~= ext and ext or nil
    self.pages.browse = 1
    self:refresh()
end

function ShelfScreen:setSelecting(on)
    self.selecting = on
    if not on then self.selected = {} end
    self:refresh()
end

-- Ticks or unticks one row; `key` identifies it (a path on Browse, a title on the KOReader tab).
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
    self.pages.browse = 1
    self:refresh()
end

function ShelfScreen:flipSort()
    self.descending = not self.descending
    self.pages.browse = 1
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
    query = query and query:match("^%s*(.-)%s*$")
    self.query = query ~= "" and query or nil
    self.pages.browse = 1
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
    local view = views[self.tab](self, th, width)

    local titlebar = header(th, self.dimen.w, function() self:showMenu() end)
    local tabs = {
        { id = "overview", label = _("OVERVIEW") },
        { id = "browse", label = _("BROWSE") },
        { id = "koreader", label = _("KOREADER") },
    }
    local gap = sp(10)
    local body = VerticalGroup:new{
        align = "left",
        view.hero,
        VerticalSpan:new{ width = gap },
        UI.tabbar(th, width, tabs, self.tab == "duplicates" and "overview" or self.tab, function(id) self:switchTab(id) end),
        VerticalSpan:new{ width = gap },
    }

    if view.build then
        if view.header then table.insert(body, view.header) end
        -- A view with a `table_head` draws its rows as a table: a rounded, outlined box holding the head and the rows.
        local frame_w = Size.border.default * 2
        local used = titlebar:getSize().h + 2 * pad + body:getSize().h
            + (view.table_head and view.table_head:getSize().h + frame_w or 0)
        local pager_h = UI.pager(th, width, 1, 1, function() end):getSize().h
        local avail = self.dimen.h - used - pager_h
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
        local rows = body
        if view.table_head then rows = VerticalGroup:new{ align = "left", view.table_head } end
        if view.count == 0 and view.empty then
            table.insert(rows, view.empty(per_page * row_h))
        else
            for i = first, last do table.insert(rows, view.build(i, row_h)) end
        end
        if view.table_head then table.insert(body, UI.rounded(th, rows, sp(10), Size.border.default)) end
        local shown = (view.count == 0 and view.empty) and per_page or (last - first + 1) -- the empty state takes the whole page
        table.insert(body, VerticalSpan:new{ width = (per_page - shown) * row_h })
        table.insert(body, UI.pager(th, width, page, pages, function(n) self:setPage(n) end))
    else
        self.page_count = 1
        if view.message then
            table.insert(body, UI.text(view.message, 20, { color = th.muted }))
        else
            table.insert(body, view.body)
        end
        if view.bottom then
            table.insert(body, VerticalSpan:new{ width = sp(14) })
            table.insert(body, view.bottom)
        end
    end

    body:resetLayout() -- getSize() above cached the group's height before the rows were added
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
