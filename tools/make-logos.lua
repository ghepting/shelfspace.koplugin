-- Writes the logo files in assets/ from the code that draws the in-app icons, so they cannot drift apart
-- (tests/unit/icons_test.lua checks they match). Run from the repository root:  luajit tools/make-logos.lua
dofile("tests/unit/helper.lua") -- stand-ins for the few KOReader modules icons.lua loads
local Icons = require("shelfspace/icons")

local function write(path, text)
    local f = assert(io.open(path, "w"))
    f:write(text)
    f:close()
    print("wrote " .. path)
end

write("assets/logo.svg", Icons.logo("2a363b"))              -- the tile, for places that want an app icon
write("assets/logo-light.svg", Icons.plainLogo("2a363b"))   -- slate, for light pages
write("assets/logo-dark.svg", Icons.plainLogo("fecea8"))    -- peach, for dark pages
