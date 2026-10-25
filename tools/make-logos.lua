-- Writes the logo in assets/ from the code that draws the in-app icons, so they cannot drift apart
-- (tests/unit/icons_test.lua checks they match). Run from the repository root:  luajit tools/make-logos.lua
dofile("tests/unit/helper.lua") -- stand-ins for the few KOReader modules icons.lua loads
local Icons = require("shelfspace/icons")

local f = assert(io.open("assets/logo.svg", "w"))
f:write(Icons.plainLogo("e84a5f")) -- melonjolly
f:close()
print("wrote assets/logo.svg")
