-- Writes the logo in assets/ from the code that draws the in-app icons, so they cannot drift apart
-- (tests/unit/icons_test.lua checks they match). Run from the repository root:  luajit tools/make-logos.lua
dofile("tests/unit/helper.lua") -- stand-ins for the few KOReader modules icons.lua loads
local Icons = require("shelfspace/icons")

for name, hex in pairs({ light = "2a363b", dark = "ffffff" }) do -- coup de grâce on light pages, white on dark
    local f = assert(io.open("assets/logo-" .. name .. ".svg", "w"))
    f:write(Icons.plainLogo(hex))
    f:close()
    print("wrote assets/logo-" .. name .. ".svg")
end
