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
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Deleter = require("shelfspace/deleter")
local Stats = require("shelfspace/stats")
local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(60)

local function percent(fraction)
    return math.floor(100 * fraction + 0.5) .. "%"
end

-- The current folder as a hero card, then its contents largest-first with a share bar.
return function(screen, th, width)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = UI.hero(th, width, {
            color = th.books, label = _("LIBRARY"), title = _("Library"), subtitle = _("Scanning…"),
        }), message = _("Scanning your library…") }
    end

    local root = plugin.root
    local dir = screen.dir
    if not dir or not tree[dir] then dir = root end
    screen.dir = dir
    local parent = dir ~= root and dir:match("^(.*)/[^/]+$") or nil
    if parent and not tree[parent] then parent = root end

    local entries = {}
    for i, e in ipairs(tree[dir].entries) do
        if not e.hidden then table.insert(entries, e) end
    end
    table.sort(entries, function(a, b) return a.size > b.size end)

    local name = dir == root and _("Library") or dir:match("[^/]+$")
    local summary = Stats.summarize(tree, dir)
    local chips = {}
    for i, x in ipairs(Stats.topExtensions(summary.exts, 3)) do
        table.insert(chips, T(_("%1 %2%"), x.ext:upper(), x.percent))
    end
    local dir_size = tree[dir].size
    local whole = parent and tree[parent].size or plugin.usage.total
    local share = whole > 0 and dir_size / whole or 0

    local hero = UI.hero(th, width, {
        color = th.books,
        label = name:upper(),
        title = name,
        subtitle = T(N_("%1 file", "%1 files", summary.files), summary.files),
        chips = chips,
        progress = { fraction = share, left = percent(share), right = util.getFriendlySize(dir_size) },
    })

    local items = entries
    local largest = entries[1] and math.max(entries[1].size, 1) or 1

    local size_w = sp(84)
    local gap = sp(12)
    local thumb_w, thumb_h = sp(34), sp(44)

    local function frame(content)
        return FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0,
            VerticalGroup:new{
                align = "left",
                LeftContainer:new{ dimen = Geom:new{ w = width, h = ROW_H - Size.line.thin }, content },
                LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line },
            },
        }
    end

    local function build(i)
        local item = items[i]
        local ask = function() plugin:confirmDelete(item, dir) end
        local locked = Deleter.protectedReason(item.path, root, plugin.koreader_dir) ~= nil
        local mid_w = width - thumb_w - size_w - 3 * gap
        local row = frame(HorizontalGroup:new{
            align = "center",
            UI.block(thumb_w, thumb_h, Theme.kind(th, item), sp(5)),
            HorizontalSpan:new{ width = gap },
            VerticalGroup:new{
                align = "left",
                UI.text(item.is_dir and (item.name .. "/") or item.name, 19,
                    { bold = true, color = locked and th.muted or th.ink, max_width = mid_w }),
                VerticalSpan:new{ width = sp(5) },
                UI.bar(th, mid_w, sp(8), item.size / largest, th.accent),
            },
            HorizontalSpan:new{ width = gap },
            RightContainer:new{
                dimen = Geom:new{ w = size_w, h = thumb_h },
                UI.text(util.getFriendlySize(item.size), 17, { bold = true, color = th.ink }),
            },
        })
        return UI.tappable(row, item.is_dir and function() screen:setDir(item.path) end or ask, ask)
    end

    -- "Up" stays above the list on every page.
    local header
    if parent then
        header = UI.tappable(frame(HorizontalGroup:new{
            align = "center",
            UI.text("⬆", 22, { color = th.ink }), HorizontalSpan:new{ width = gap },
            UI.text(_("Up"), 20, { bold = true, color = th.ink }),
        }), function() screen:setDir(parent) end)
    end

    return { hero = hero, header = header, count = #items, row_h = ROW_H, build = build }
end
