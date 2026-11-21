-- Loads the built plugin through Lua 5.1's own require and checks its API.
-- The library must be staged on the C loader's path for the require name,
-- e.g. <stage dir>/plugin/hello.so for plugin.hello.
--
--   lua5.1 test/test_plugin.lua <stage dir> <plugin name>

local stageDir = arg[1]
local pluginName = arg[2]

if not stageDir or not pluginName then
    print( "usage: lua5.1 test_plugin.lua <stage dir> <plugin name>" )
    os.exit( 1 )
end

local checksRun = 0
local checksFailed = 0

local function check( condition, message )
    checksRun = checksRun + 1

    if not condition then
        checksFailed = checksFailed + 1
        print( "FAIL: " .. message )
    end
end

package.cpath = stageDir .. "/?.so;" .. package.cpath
local hello = require( pluginName )

check( type( hello ) == "table", "require did not return a table" )
check( type( hello.getGreeting ) == "function", "missing function: getGreeting" )

local greeting = hello.getGreeting()

check( type( greeting ) == "string", "getGreeting did not return a string" )
check(
    string.match( greeting, "^Hello from %a+! The time is currently %d%d:%d%d:%d%d%.$" ) ~= nil,
    "unexpected greeting: " .. tostring( greeting )
)

print( checksRun - checksFailed .. " of " .. checksRun .. " checks passed" )

if checksFailed > 0 then
    os.exit( 1 )
end
