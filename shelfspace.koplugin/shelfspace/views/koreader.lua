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
local util = require("util")
local _ = require("gettext")
local N_ = _.ngettext
local T = require("ffi/util").template

local Cleanup = require("shelfspace/cleanup")
local Stats = require("shelfspace/stats")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(62)

-- KOReader's own data: what can be cleared, each with its size and a Clear button.
return function(screen, th, width)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = UI.hero(th, width, {
            color = th.koreader_tile, icon = "koreader", title = _("KOReader"), subtitle = _("Scanning…"),
        }), message = _("Scanning your library…") }
    end

    local targets = Cleanup.targets(tree, plugin.koreader_dir, plugin.ui.document ~= nil, plugin.root)
    -- Everything a row can clear right now: the header total and the bottom button both use it.
    local can_free, clearable = 0, {}
    for i, t in ipairs(targets) do
        if t.size > 0 and not t.blocked then
            can_free = can_free + t.size
            table.insert(clearable, t)
        end
    end

    -- What KOReader's data folder is made of: the kinds of thing that can be cleared, and what is kept.
    local data_size = tree[plugin.koreader_dir].size
    local summary = Stats.summarize(tree, plugin.koreader_dir)
    local parts, listed = {}, 0
    for i, t in ipairs(targets) do
        table.insert(parts, { name = t.short, bytes = t.size })
        listed = listed + t.size
    end
    table.insert(parts, { name = _("KEPT"), bytes = math.max(data_size - listed, 0) })

    local hero = UI.hero(th, width, {
        color = th.koreader_tile,
        icon = "koreader",
        title = _("KOReader"),
        subtitle = T(_("%1 · %2"), T(N_("%1 file", "%1 files", summary.files), summary.files), util.getFriendlySize(data_size)),
        chips = Stats.dataChips(parts, data_size, 3, #clearable, _("ALL CLEAR")),
    })

    local gap = sp(10)
    local size_w = sp(78)
    local body = VerticalGroup:new{ align = "left" }

    -- Select several: a row can be ticked when it has something to clear and nothing stops it.
    local selecting = screen.selecting
    local selectable, chosen, chosen_size = {}, {}, 0
    for i, t in ipairs(targets) do
        if t.size > 0 and not t.blocked then
            table.insert(selectable, t)
            if screen.selected[t.title] then
                table.insert(chosen, t)
                chosen_size = chosen_size + t.size
            end
        end
    end
    local select_button = UI.button(th, {
        text = selecting and _("Done") or _("Select"), size = 15,
        enabled = #selectable > 0 or selecting,
        callback = function() screen:setSelecting(not selecting) end,
    })
    table.insert(body, VerticalSpan:new{ width = sp(4) })
    if selecting then
        local all_chosen = #selectable > 0 and #chosen == #selectable
        local all_button = UI.button(th, {
            text = all_chosen and _("None") or _("All"), size = 15, enabled = #selectable > 0,
            callback = function()
                local keys = {}
                for _, t in ipairs(selectable) do table.insert(keys, t.title) end
                screen:selectKeys(keys, not all_chosen)
            end,
        })
        local clear_button = UI.button(th, {
            text = _("Clear"), size = 15, enabled = #chosen > 0, background = th.danger, color = th.white,
            disabled_background = th.free,
            callback = function() plugin:confirmClear(chosen) end,
        })
        local label_w = width - select_button:getSize().w - all_button:getSize().w - clear_button:getSize().w - 4 * gap
        table.insert(body, HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = label_w, h = select_button:getSize().h },
                UI.text(T(_("%1 selected · %2"), #chosen, util.getFriendlySize(chosen_size)), 16,
                    { bold = true, color = th.ink, max_width = label_w }),
            },
            HorizontalSpan:new{ width = gap }, all_button, HorizontalSpan:new{ width = gap }, clear_button,
            HorizontalSpan:new{ width = gap }, select_button,
        })
    else
        table.insert(body, RightContainer:new{ dimen = Geom:new{ w = width, h = select_button:getSize().h }, select_button })
    end
    table.insert(body, VerticalSpan:new{ width = sp(4) })

    for i, t in ipairs(targets) do
        local clearable = t.size > 0
        local ticked = screen.selected[t.title] ~= nil
        local button
        if selecting and clearable and not t.blocked then
            button = UI.tappable(CenterContainer:new{
                dimen = Geom:new{ w = sp(70), h = sp(40) },
                UI.checkbox(th, ticked),
            }, function() screen:toggleKey(t.title) end)
        else
            button = UI.button(th, {
                text = _("Clear"),
                size = 15,
                enabled = clearable and not selecting,
                callback = function()
                    if t.blocked then
                        plugin:notify(t.blocked)
                    else
                        plugin:confirmClear({ t }, t.title:lower())
                    end
                end,
            })
        end
        local label = t.count and T(_("%1 (%2)"), t.title, t.count) or t.title
        local text_w = width - size_w - button:getSize().w - 2 * gap
        local title = UI.text(label, 19, { bold = true, color = clearable and th.ink or th.muted, max_width = text_w })
        local note = UI.text(t.blocked or t.note, 14, { color = th.muted, max_width = text_w })
        local used = math.max(title:getSize().w, note:getSize().w)
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0,
            VerticalGroup:new{
                align = "left",
                CenterContainer:new{
                    dimen = Geom:new{ w = width, h = ROW_H - Size.line.thin },
                    HorizontalGroup:new{
                        align = "center",
                        VerticalGroup:new{ align = "left", title, note },
                        HorizontalSpan:new{ width = text_w - used },
                        RightContainer:new{
                            dimen = Geom:new{ w = size_w, h = sp(30) },
                            UI.text(util.getFriendlySize(t.size), 17, { bold = true, color = th.ink }),
                        },
                        HorizontalSpan:new{ width = gap },
                        button,
                    },
                },
                LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line },
            },
        }
        -- In select mode the whole row ticks it, not just the box.
        if selecting and clearable and not t.blocked then
            row = UI.tappable(row, function() screen:toggleKey(t.title) end)
        end
        table.insert(body, row)
    end
    local bottom = UI.button(th, {
        text = T(_("Clear all · %1"), util.getFriendlySize(can_free)),
        width = width,
        enabled = can_free > 0,
        background = th.danger,
        color = th.white,
        disabled_background = th.free,
        callback = function()
            plugin:confirmClear(clearable)
        end,
    })
    return { hero = hero, body = body, bottom = not selecting and bottom or nil }
end
