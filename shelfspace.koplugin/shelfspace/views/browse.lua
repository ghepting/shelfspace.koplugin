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

    local largest = entries[1] and math.max(entries[1].size, 1) or 1

    local size_w = sp(80)
    local gap = sp(10)
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

    local ctx = plugin:deleteContext()
    local delete_w = UI.button(th, { text = _("Delete"), size = 14 }):getSize().w

    -- Tapping a folder opens it; deleting is always the explicit Delete button.
    -- Rows that can't be deleted have no button and say why instead of showing a share bar.
    local function build(i)
        local item = entries[i]
        local reason = Deleter.blockedReason(item, ctx)
        local mid_w = width - thumb_w - size_w - delete_w - 4 * gap
        local under
        if reason then
            under = UI.text(reason, 13, { color = th.muted, max_width = mid_w })
        else
            under = UI.bar(th, mid_w, sp(8), item.size / largest, th.accent)
        end
        local action = HorizontalSpan:new{ width = delete_w }
        if not reason then
            action = UI.button(th, {
                text = _("Delete"),
                size = 14,
                callback = function() plugin:confirmDelete(item, dir) end,
            })
        end
        local row = frame(HorizontalGroup:new{
            align = "center",
            UI.block(thumb_w, thumb_h, Theme.kind(th, item), sp(5)),
            HorizontalSpan:new{ width = gap },
            LeftContainer:new{
                dimen = Geom:new{ w = mid_w, h = thumb_h },
                VerticalGroup:new{
                    align = "left",
                    UI.text(item.is_dir and (item.name .. "/") or item.name, 19,
                        { bold = true, color = reason and th.muted or th.ink, max_width = mid_w }),
                    VerticalSpan:new{ width = sp(5) },
                    under,
                },
            },
            HorizontalSpan:new{ width = gap },
            RightContainer:new{
                dimen = Geom:new{ w = size_w, h = thumb_h },
                UI.text(util.getFriendlySize(item.size), 16, { bold = true, color = th.ink }),
            },
            HorizontalSpan:new{ width = gap },
            action,
        })
        if item.is_dir then
            return UI.tappable(row, function() screen:setDir(item.path) end)
        end
        return row
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

    return { hero = hero, header = header, count = #entries, row_h = ROW_H, build = build }
end
