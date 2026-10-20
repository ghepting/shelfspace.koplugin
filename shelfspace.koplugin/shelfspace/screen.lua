local Device = require("device")
local FrameContainer = require("ui/widget/container/framecontainer")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TitleBar = require("ui/widget/titlebar")
local UIManager = require("ui/uimanager")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local _ = require("gettext")
local Screen = Device.screen

local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp

local views = {
    overview = require("shelfspace/views/overview"),
    browse = require("shelfspace/views/browse"),
    koreader = require("shelfspace/views/koreader"),
}

-- One screen with a tab per view. A view returns { hero, body } for a plain page,
-- or { hero, count, row_h, build } for a paged list; `message` replaces the body.
local ShelfScreen = InputContainer:extend{
    plugin = nil, -- the ShelfSpace plugin: usage, tree, and the delete / clear actions
    tab = "overview",
    dir = nil, -- folder shown on the Browse tab
}

function ShelfScreen:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.covers_fullscreen = true
    self.theme = Theme.get()
    self.pages = {}
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
    UIManager:setDirty(self, "ui")
end

function ShelfScreen:switchTab(id)
    self.tab = id
    self:refresh()
end

function ShelfScreen:setDir(dir)
    self.dir = dir
    self.pages.browse = 1
    self:refresh()
end

function ShelfScreen:setPage(n)
    self.pages[self.tab] = n
    self:refresh()
end

function ShelfScreen:rebuild()
    local th = self.theme
    local pad = sp(16)
    local width = self.dimen.w - 2 * pad
    local view = views[self.tab](self, th, width)

    local titlebar = TitleBar:new{
        width = self.dimen.w,
        fullscreen = true,
        title = _("Shelf Space"),
        with_bottom_line = true,
        close_callback = function() self:onClose() end,
        show_parent = self,
    }
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
        UI.tabbar(th, width, tabs, self.tab, function(id) self:switchTab(id) end),
        VerticalSpan:new{ width = gap },
    }

    if view.build then
        if view.header then table.insert(body, view.header) end
        local used = titlebar:getSize().h + 2 * pad + body:getSize().h
        local pager_h = sp(44)
        local per_page = math.max(1, math.floor((self.dimen.h - used - pager_h) / view.row_h))
        local pages = math.max(1, math.ceil(view.count / per_page))
        local page = math.min(self.pages[self.tab] or 1, pages)
        self.pages[self.tab] = page
        self.page_count = pages
        local first = (page - 1) * per_page + 1
        local last = math.min(view.count, first + per_page - 1)
        for i = first, last do table.insert(body, view.build(i)) end
        table.insert(body, VerticalSpan:new{ width = (per_page - (last - first + 1)) * view.row_h })
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
