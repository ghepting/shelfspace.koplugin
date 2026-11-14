-- Writes the logo in assets/ from the code that draws the in-app icons, so they cannot drift apart
-- (tests/unit/icons_test.lua checks they match). Run from the repository root:  luajit tools/make-logos.lua
dofile("tests/unit/helper.lua") -- stand-ins for the few KOReader modules icons.lua loads
local Icons = require("shelfspace/icons")

-- coup de grâce on light pages and white on dark, with the empty slot in green (SideShelf's green, lightened for dark pages)
for name, c in pairs({ light = { "2a363b", "2f6f5e" }, dark = { "ffffff", "6fc2a8" } }) do
    local f = assert(io.open("assets/logo-" .. name .. ".svg", "w"))
    f:write(Icons.plainLogo(c[1], c[2]))
    f:close()
    print("wrote assets/logo-" .. name .. ".svg")
end
