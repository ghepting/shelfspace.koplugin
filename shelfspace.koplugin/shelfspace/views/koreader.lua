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
return function(screen, th, width, layout)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = UI.hero(th, layout and layout.hero_w or width, {
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

    local hero = UI.hero(th, layout and layout.hero_w or width, {
        wrap = layout and layout.landscape,
        color = th.koreader_tile,
        icon = "koreader",
        title = _("KOReader"),
        subtitle = T(_("%1 · %2"), T(N_("%1 file", "%1 files", summary.files), summary.files), util.getFriendlySize(data_size)),
        chips = Stats.dataChips(parts, clearable_total, 3, #clearable, _("ALL CLEAR")),
    })

    local gap = sp(10)
    local size_w = sp(78)
    local tick = UI.CHECKBOX

    -- A row can be selected when it has something to clear and nothing stops it.
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

    -- The line that selects every row that can be cleared, over the boxes it selects (as in the Library). It covers all the rows, on
    -- every page. With nothing to clear there is nothing to select, so there is no such line either.
    local all_chosen = #selectable > 0 and #chosen == #selectable
    local function select_all()
        if #selectable == 0 then return nil end
        return VerticalGroup:new{
            align = "left",
            UI.selectAll(th, width, gap, {
                label = #chosen > 0 and T(_("Select all · %1 selected · %2"), #chosen, util.getFriendlySize(chosen_size)) or _("Select all"),
                checked = all_chosen, mixed = #chosen > 0 and not all_chosen,
                on_tap = function()
                    local keys = {}
                    for _, t in ipairs(selectable) do table.insert(keys, t.title) end
                    screen:selectKeys(keys, not all_chosen)
                end,
            }),
            VerticalSpan:new{ width = sp(8) },
        }
    end

    local function build(i, row_h)
        local t = targets[i]
        local h = (row_h or ROW_H) - Size.line.thin - (th.tinted and sp(5) or 0)
        local clearable = t.size > 0
        local pickable = clearable and not t.blocked
        -- Something empty has nothing to clear, so it has no box; only what is held back (blocked) gets the padlock.
        local box = CenterContainer:new{
            dimen = Geom:new{ w = tick, h = h },
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
                    dimen = Geom:new{ w = inner, h = h },
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
        -- A row has nothing to open, so a tap anywhere on it selects it (or says why it cannot be).
        local cell = VerticalGroup:new{ align = "left", UI.tappable(row, function()
            if pickable then
                screen:toggleKey(t.title)
            elseif t.blocked then
                plugin:notify(t.blocked)
            end
        end) }
        if th.tinted then table.insert(cell, VerticalSpan:new{ width = sp(5) }) end
        return cell
    end

    -- The bar in the middle of the pager row: what is selected with Cancel and Clear, and with nothing selected, Clear all.
    local bar
    if #chosen > 0 then
        bar = {
            count = #chosen, bytes = chosen_size,
            buttons = {
                { text = _("Cancel"), callback = function() screen:clearSelection() end },
                { text = _("Clear"), danger = true, callback = function() plugin:confirmClear(chosen) end },
            },
        }
    elseif can_free > 0 then
        bar = {
            labels = { T(_("%1 to clear"), util.getFriendlySize(can_free)), "" },
            buttons = { { text = _("Clear all"), danger = true, callback = function() plugin:confirmClear(clearable) end } },
        }
    end
    return {
        hero = hero, header = VerticalSpan:new{ width = sp(8) }, count = #targets, row_h = ROW_H + (th.tinted and sp(5) or 0),
        build = build, select_all = select_all, bar = bar,
    }
end
