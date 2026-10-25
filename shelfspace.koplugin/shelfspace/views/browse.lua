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

local Deleter = require("shelfspace/deleter")
local Search = require("shelfspace/search")
local Selection = require("shelfspace/selection")
local Stats = require("shelfspace/stats")
local Theme = require("shelfspace/theme")
local UI = require("shelfspace/ui")
local sp = UI.sp

local ROW_H = sp(60)

-- At most `max` characters, cut on a character boundary.
local function shorten(text, max)
    local count, cut = 0, #text
    for pos in text:gmatch("()[%z\1-\127\194-\244][\128-\191]*") do
        count = count + 1
        if count > max then cut = pos - 1 break end
    end
    return count > max and (text:sub(1, cut) .. "…") or text
end

-- The current folder as a hero card, then its contents largest-first with a share bar.
return function(screen, th, width)
    local plugin = screen.plugin
    local tree = plugin.tree
    if not tree then
        return { hero = UI.hero(th, width, {
            color = th.books, icon = "library", title = _("Library"), subtitle = _("Scanning…"),
        }), message = _("Scanning your library…") }
    end

    local root = plugin.root
    local dir = screen.dir
    if not dir or not tree[dir] then dir = root end
    screen.dir = dir
    local parent = dir ~= root and dir:match("^(.*)/[^/]+$") or nil
    if parent and not tree[parent] then parent = root end

    local entries, where = {}, nil
    if screen.query or screen.filter then
        entries, where = Search.find(tree, dir, screen.query, screen.filter)
    else
        for i, e in ipairs(tree[dir].entries) do
            if not e.hidden then table.insert(entries, e) end
        end
    end
    Search.sort(entries, Search.OPTIONS[screen.sort])

    local name = dir == root and _("Library") or dir:match("[^/]+$")
    local summary = Stats.summarize(tree, dir)
    local chips = {}
    for i, x in ipairs(Stats.topExtensions(summary.exts, 3)) do
        local ext = x.ext
        table.insert(chips, {
            text = T(_("%1 %2%"), ext:upper(), x.percent),
            active = screen.filter == ext,
            on_tap = function() screen:toggleFilter(ext) end,
        })
    end
    local dir_size = tree[dir].size

    local hero = UI.hero(th, width, {
        color = th.books,
        icon = "library",
        title = name,
        subtitle = T(_("%1 · %2"), T(N_("%1 file", "%1 files", summary.files), summary.files), util.getFriendlySize(dir_size)),
        chips = chips,
    })

    local largest = 1
    for i, e in ipairs(entries) do largest = math.max(largest, e.size) end

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
        elseif where then
            local rel = where[item]
            under = UI.text(rel == "" and _("here") or T(_("in %1"), rel), 14, { color = th.muted, max_width = mid_w })
        else
            under = UI.bar(th, mid_w, sp(8), item.size / largest, th.accent)
        end
        local action = HorizontalSpan:new{ width = delete_w }
        if not reason and screen.selecting then
            action = UI.tappable(CenterContainer:new{
                dimen = Geom:new{ w = delete_w, h = thumb_h },
                UI.checkbox(th, screen.selected[item.path] ~= nil),
            }, function() screen:toggle(item) end)
        elseif not reason then
            action = UI.button(th, {
                text = _("Delete"),
                size = 14,
                callback = function() plugin:confirmDelete(item, item.path:match("^(.*)/[^/]+$") or dir) end,
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
        -- Tapping a file says what it is, or ticks it in select mode; the Delete button is still
        -- the only thing on a row that deletes.
        return UI.tappable(row, function()
            if screen.selecting and not reason then
                screen:toggle(item)
            else
                plugin:showDetails(item, item.path:match("^(.*)/[^/]+$") or dir)
            end
        end)
    end

    -- Search and sort, then "Up": pinned above the list on every page.
    local sort_button = UI.button(th, {
        text = T(_("Sort: %1 ▾"), Search.OPTIONS[screen.sort].short), size = 15,
        callback = function() screen:askSort() end,
    })
    local clear_button = screen.query and UI.button(th, {
        text = "✕", size = 15, callback = function() screen:setQuery(nil) end,
    })
    local select_button = UI.button(th, {
        text = screen.selecting and _("Done") or _("Select"), size = 15,
        callback = function() screen:setSelecting(not screen.selecting) end,
    })
    local search_w = width - sort_button:getSize().w - select_button:getSize().w - 2 * gap
        - (clear_button and (clear_button:getSize().w + gap) or 0)
    local controls = HorizontalGroup:new{
        align = "center",
        UI.button(th, {
            text = screen.query and shorten(screen.query, 20) or _("Search by name"), size = 15,
            width = search_w, callback = function() screen:askQuery() end,
        }),
        HorizontalSpan:new{ width = gap },
    }
    if clear_button then
        table.insert(controls, clear_button)
        table.insert(controls, HorizontalSpan:new{ width = gap })
    end
    table.insert(controls, sort_button)
    table.insert(controls, HorizontalSpan:new{ width = gap })
    table.insert(controls, select_button)

    local header = VerticalGroup:new{ align = "left", VerticalSpan:new{ width = sp(4) }, controls, VerticalSpan:new{ width = sp(6) } }
    if screen.selecting then
        local deletable, all_chosen = {}, true
        for i, e in ipairs(entries) do
            if not Deleter.blockedReason(e, ctx) then
                table.insert(deletable, e)
                if not screen.selected[e.path] then all_chosen = false end
            end
        end
        local chosen = screen:chosen()
        local all_button = UI.button(th, {
            text = (#deletable > 0 and all_chosen) and _("None") or _("All"), size = 15, enabled = #deletable > 0,
            callback = function() screen:select(deletable, not all_chosen) end,
        })
        local delete_button = UI.button(th, {
            text = _("Delete"), size = 15, enabled = #chosen > 0, background = th.accent, color = th.white,
            callback = function() plugin:confirmDeleteMany(chosen) end,
        })
        local label_w = width - all_button:getSize().w - delete_button:getSize().w - 3 * gap
        table.insert(header, HorizontalGroup:new{
            align = "center",
            LeftContainer:new{
                dimen = Geom:new{ w = label_w, h = all_button:getSize().h },
                UI.text(T(_("%1 selected · %2"), #chosen, util.getFriendlySize(Selection.size(chosen))), 16,
                    { bold = true, color = th.ink, max_width = label_w }),
            },
            HorizontalSpan:new{ width = gap }, all_button, HorizontalSpan:new{ width = gap }, delete_button,
        })
        table.insert(header, VerticalSpan:new{ width = sp(6) })
    end
    if screen.query or screen.filter then
        local count = #entries
        local kind = screen.filter and T(N_(" %1 file", " %1 files", count), screen.filter:upper()) or ""
        local text
        if screen.query then
            text = count == 0 and T(_("No matches for “%1”%2 in %3"), shorten(screen.query, 20), kind, name)
                or T(N_("%1 match%2 in %3", "%1 matches%2 in %3", count), count, kind, name)
        else
            text = count == 0 and T(_("No%1 in %2"), kind, name)
                or T(N_("%1%2 in %3", "%1%2 in %3", count), count, kind, name)
        end
        table.insert(header, UI.text(text, 15, { color = th.muted, max_width = width }))
        table.insert(header, VerticalSpan:new{ width = sp(6) })
    end
    if parent then
        table.insert(header, UI.tappable(frame(HorizontalGroup:new{
            align = "center",
            UI.text("⬆", 22, { color = th.ink }), HorizontalSpan:new{ width = gap },
            UI.text(_("Up"), 20, { bold = true, color = th.ink }),
        }), function() screen:setDir(parent) end))
    end

    return { hero = hero, header = header, count = #entries, row_h = ROW_H, build = build }
end
