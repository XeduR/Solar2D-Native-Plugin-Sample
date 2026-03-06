---------------------------------------------------------------------------------
-- Solar2D Hello Plugin - Sample Project
--
-- Demonstrates the hello plugin:
-- Tap the button to call hello.getGreeting() and display the result.
---------------------------------------------------------------------------------

display.setStatusBar( display.HiddenStatusBar )
display.setDefault( "background", 20/255, 21/255, 24/255 )

-- This plugin sample is local only and not available in Solar2D's plugin directory or marketplaces.
-- You must build it and place the output files in the correct locations before use (see BUILDING.md).
local loaded, hello = pcall( require, "plugin.hello" )
if not loaded then
    local warning = display.newText({
        text = "Failed to load plugin.\n\nPlease refer to BUILDING.md and README.md\nfor build and setup instructions.",
        x = display.contentCenterX,
        y = display.contentCenterY,
        font = native.systemFontBold,
        fontSize = 20,
        align = "center",
        width = display.contentWidth - 40,
    })
    warning:setFillColor( 1, 0.3, 0.3 )
    return
end

-- Layout constants
local centerX = display.contentCenterX
local buttonWidth = 280
local buttonHeight = 50

---------------------------------------------------------------------------------
-- Title
---------------------------------------------------------------------------------

local title = display.newText({
    text = "Solar2D Hello Plugin",
    x = centerX,
    y = 80,
    font = native.systemFontBold,
    fontSize = 34,
})
title:setFillColor( 252/255, 186/255, 4/255 )

local subtitle = display.newText({
    text = "Tap the button to test the plugin.",
    x = centerX,
    y = 130,
    font = native.systemFont,
    fontSize = 20,
})
subtitle:setFillColor( 1 )

---------------------------------------------------------------------------------
-- Greeting Display Area
---------------------------------------------------------------------------------

local greetingText = display.newText({
    text = "",
    x = centerX,
    y = 340,
    width = 560,
    font = native.systemFont,
    fontSize = 22,
    align = "center",
})
greetingText:setFillColor( 1, 1, 0 )

---------------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------------

local buttonGroup = display.newGroup()

local bg = display.newRoundedRect( buttonGroup, centerX, 230, buttonWidth, buttonHeight, 12 )
bg:setFillColor( 50/255, 51/255, 54/255 )

local buttonLabel = display.newText({
    parent = buttonGroup,
    text = "Get Greeting",
    x = centerX,
    y = 230,
    font = native.systemFontBold,
    fontSize = 18,
})
buttonLabel:setFillColor( 252/255, 186/255, 4/255 )

bg:addEventListener( "touch", function( event )
    if event.phase == "began" then
        local greeting = hello.getGreeting()
        greetingText.text = greeting
        print( greeting )
    end
    return true
end )

---------------------------------------------------------------------------------

print( "Solar2D Hello Plugin sample loaded." )
