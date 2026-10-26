-- Reading and comparing release numbers like "0.3.0" or "v0.3.0".
local Version = {}

-- { major, minor, patch } or nil when `text` is not a release number.
function Version.parse(text)
    local a, b, c = tostring(text or ""):match("^v?(%d+)%.(%d+)%.(%d+)")
    if not a then return nil end
    return { tonumber(a), tonumber(b), tonumber(c) }
end

-- -1 when `x` is older than `y`, 0 when the same, 1 when newer; nil when either can't be read.
function Version.compare(x, y)
    local px, py = Version.parse(x), Version.parse(y)
    if not (px and py) then return nil end
    for i = 1, 3 do
        if px[i] ~= py[i] then return px[i] < py[i] and -1 or 1 end
    end
    return 0
end

-- The version declared in the text of a plugin's _meta.lua (`version = "0.3.0"`), or nil.
function Version.fromMeta(text)
    return tostring(text or ""):match('version%s*=%s*"([^"]+)"')
end

return Version
