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

    -- The tags show how big each kind of clearable thing is, as a share of everything that can be cleared; the rest of
    -- the folder (KOReader itself, its settings and plugins) is not something to clear, so it gets no tag.
    local data_size = tree[plugin.koreader_dir].size
    local summary = Stats.summarize(tree, plugin.koreader_dir)
    local parts, clearable_total = {}, 0
    for i, t in ipairs(targets) do
        table.insert(parts, { name = t.short, bytes = t.size })
        clearable_total = clearable_total + t.size
    end

    local hero = UI.hero(th, width, {
        color = th.koreader_tile,
        icon = "koreader",
        title = _("KOReader"),
        subtitle = T(_("%1 · %2"), T(N_("%1 file", "%1 files", summary.files), summary.files), util.getFriendlySize(data_size)),
        chips = Stats.dataChips(parts, clearable_total, 3, #clearable, _("ALL CLEAR")),
    })

    local gap = sp(10)
    local size_w = sp(78)
    local tick = UI.CHECKBOX
    local body = VerticalGroup:new{ align = "left" }

    -- A row can be ticked when it has something to clear and nothing stops it.
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

    -- The line that ticks every row that can be cleared, over the boxes it ticks (as in the Library). With nothing to clear there is
    -- nothing to tick, so there is no such line either.
    local all_chosen = #selectable > 0 and #chosen == #selectable
    if #selectable > 0 then
        table.insert(body, VerticalSpan:new{ width = sp(8) })
        table.insert(body, UI.selectAll(th, width, gap, {
            label = #chosen > 0 and T(_("Select all · %1 selected · %2"), #chosen, util.getFriendlySize(chosen_size)) or _("Select all"),
            checked = all_chosen, mixed = #chosen > 0 and not all_chosen,
            on_tap = function()
                local keys = {}
                for _, t in ipairs(selectable) do table.insert(keys, t.title) end
                screen:selectKeys(keys, not all_chosen)
            end,
        }))
        table.insert(body, VerticalSpan:new{ width = sp(8) })
    else
        table.insert(body, VerticalSpan:new{ width = sp(10) })
    end

    for i, t in ipairs(targets) do
        local clearable = t.size > 0
        local pickable = clearable and not t.blocked
        -- Something empty has nothing to clear, so it has no box; only what is held back (blocked) gets the padlock.
        local box = CenterContainer:new{
            dimen = Geom:new{ w = tick, h = ROW_H - Size.line.thin },
            clearable and UI.checkbox(th, screen.selected[t.title] ~= nil, { disabled = not pickable })
                or HorizontalSpan:new{ width = tick },
        }
        local label = t.count and T(_("%1 (%2)"), t.title, t.count) or t.title
        -- On a colour screen a row is a teal-tinted card; on a gray one it keeps the rule under it. Either way its box ends a gap
        -- short of the edge, where the Library's boxes end.
        local inner = th.tinted and (width - 2 * gap) or (width - gap)
        -- The row's content is a gap before the size, a gap before the box and then the box: exactly `inner`, so the box ends at its edge.
        local text_w = inner - size_w - tick - 2 * gap
        local title = UI.text(label, 19, { bold = true, color = clearable and th.ink or th.muted, max_width = text_w })
        local note = UI.text(t.blocked or t.note, 14, { color = th.muted, max_width = text_w })
        local used = math.max(title:getSize().w, note:getSize().w)
        local row = FrameContainer:new{
            bordersize = 0, padding = 0, margin = 0, radius = th.tinted and sp(8) or nil,
            padding_left = th.tinted and gap or 0, padding_right = th.tinted and gap or 0,
            background = th.tinted and th.tint_koreader or nil,
            VerticalGroup:new{
                align = "left",
                CenterContainer:new{
                    dimen = Geom:new{ w = inner, h = ROW_H - Size.line.thin },
                    HorizontalGroup:new{
                        align = "center",
                        UI.stack(title, note),
                        HorizontalSpan:new{ width = text_w - used + gap },
                        RightContainer:new{
                            dimen = Geom:new{ w = size_w, h = sp(30) },
                            UI.text(util.getFriendlySize(t.size), 17, { bold = true, color = th.ink }),
                        },
                        HorizontalSpan:new{ width = gap },
                        box,
                    },
                },
                th.tinted and VerticalSpan:new{ width = Size.line.thin }
                    or LineWidget:new{ dimen = Geom:new{ w = width, h = Size.line.thin }, background = th.line },
            },
        }
        -- A row has nothing to open, so a tap anywhere on it ticks it (or says why it cannot be).
        table.insert(body, UI.tappable(row, function()
            if pickable then
                screen:toggleKey(t.title)
            elseif t.blocked then
                plugin:notify(t.blocked)
            end
        end))
        if th.tinted then table.insert(body, VerticalSpan:new{ width = sp(5) }) end
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
    -- What is ticked floats over the page as a bar, as in the Library; the screen draws it. Clear all gives way to it.
    local bar
    if #chosen > 0 then
        bar = {
            count = #chosen, bytes = chosen_size,
            buttons = {
                { text = _("Cancel"), callback = function() screen:clearSelection() end },
                { text = _("Clear"), danger = true, callback = function() plugin:confirmClear(chosen) end },
            },
        }
    end
    return { hero = hero, body = body, bottom = #chosen == 0 and bottom or nil, bar = bar }
end
