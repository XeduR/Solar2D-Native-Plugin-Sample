-- plugin_hello.lua
-- Lua stub for platforms where the native hello plugin is not available.
--
-- Copyright (c) 2026 Eetu Rantanen
-- MIT License

local Library = require( "CoronaLibrary" )
local lib = Library:new{ name = "plugin.hello", publisherId = "com.xedur" }


lib.getGreeting = function()
    return "Hello from Lua! The native plugin is not available on this platform."
end


return lib
