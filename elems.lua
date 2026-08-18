local BASE_URL = "https://raw.githubusercontent.com/selamlardostlarbenbao/UILib/refs/heads/main/"

local UIFactory = loadstring(game:HttpGet(BASE_URL .. "uifactory.lua"))()
local GUIFX = loadstring(game:HttpGet(BASE_URL .. "guifx.lua"))()
local CreateLibrary = loadstring(game:HttpGet(BASE_URL .. "library.lua"))()

local Library = CreateLibrary(UIFactory, GUIFX)

loadstring(game:HttpGet(BASE_URL .. "keybind.lua"))()(Library)
loadstring(game:HttpGet(BASE_URL .. "features.lua"))()(Library)
loadstring(game:HttpGet(BASE_URL .. "circularselection.lua"))()(Library)
loadstring(game:HttpGet(BASE_URL .. "popup.lua"))()(Library)
loadstring(game:HttpGet(BASE_URL .. "infooverlay.lua"))()(Library)

return Library
