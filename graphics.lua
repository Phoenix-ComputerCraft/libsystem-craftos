--- The graphics module provides functions to draw primitive geometry on a locked
-- terminal object. It supports both text and graphics mode terminals.
-- The state of text terminals is preserved, so using these functions doesn't
-- change the cursor position or colors.
--
-- @module system.graphics

local expect = require "expect"
local util = require "util"

local graphics = {}

--- Draws a single pixel on screen.
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x The X coordinate to draw at
-- @tparam number y The Y coordinate to draw at
-- @tparam number color The color to draw with
function graphics.drawPixel(term, x, y, color)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, color, "number")
    if util.type(term) == "Terminal" then
        local ox, oy = term.getCursorPos()
        local c = term.getBackgroundColor()
        term.setCursorPos(x, y)
        term.setBackgroundColor(color)
        term.write(" ")
        term.setCursorPos(ox, oy)
        term.setBackgroundColor(c)
    else
        term.setPixel(x-1, y-1, color)
    end
end

local function drawLineInternal(sp, x1, y1, x2, y2)
    if math.abs(y2 - y1) < math.abs(x2 - x1) then
        if x1 > x2 then x1, y1, x2, y2 = x2, y2, x1, y1 end
        local dx, dy, yi = x2 - x1, y2 - y1, 1
        if dy < 0 then yi, dy = -1, -dy end
        local D, y = 2*dy - dx, y1
        if yi < 0 then
            y = y2
            for x = x2, x1, -1 do
                sp(x, y)
                if D > 0 then
                    y = y + 1
                    D = D + 2*(dy - dx)
                else
                    D = D + 2*dy
                end
            end
        else
            for x = x1, x2 do
                sp(x, y)
                if D > 0 then
                    y = y + 1
                    D = D + 2*(dy - dx)
                else
                    D = D + 2*dy
                end
            end
        end
    else
        if y1 > y2 then x1, y1, x2, y2 = x2, y2, x1, y1 end
        local dx, dy, xi = x2 - x1, y2 - y1, 1
        if dx < 0 then xi, dx = -1, -dx end
        local D, x = 2*dx - dy, x1
        for y = y1, y2 do
            sp(x, y)
            if D > 0 then
                x = x + xi
                D = D + 2*(dx - dy)
            else
                D = D + 2*dx
            end
        end
    end
end

--- Draws a line between two points.
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x1 The start X coordinate to draw at
-- @tparam number y1 The start Y coordinate to draw at
-- @tparam number x2 The end X coordinate to draw at
-- @tparam number y2 The end Y coordinate to draw at
-- @tparam number color The color to draw with
function graphics.drawLine(term, x1, y1, x2, y2, color)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x1, "number")
    expect(3, y1, "number")
    expect(4, x2, "number")
    expect(5, y2, "number")
    expect(6, color, "number")
    if y1 == y2 then
        local width = math.abs(x2 - x1) + 1
        if util.type(term) == "Terminal" then
            local b, f = term.getBackgroundColor(), term.getTextColor()
            local ox, oy = term.getCursorPos()
            local fg, bg = ("%x"):format(f), ("%x"):format(color)
            term.setCursorPos(x1, y1)
            term.blit((" "):rep(width), fg:rep(width), bg:rep(width))
            term.setCursorPos(ox, oy)
            term.setBackgroundColor(b)
        else
            term.drawPixels(x1-1, y1-1, color, width, 1)
        end
        return
    elseif x1 == x2 and util.type(term) == "GFXTerminal" then
        term.drawPixels(x1-1, y1-1, color, 1, math.abs(y2 - y1) + 1)
    end
    local sp, rst
    if util.type(term) == "Terminal" then
        local c = term.getBackgroundColor()
        local ox, oy = term.getCursorPos()
        term.setBackgroundColor(color)
        sp, rst = function(x, y)
            term.setCursorPos(x, y)
            term.write(" ")
        end, function()
            term.setBackgroundColor(c)
            term.setCursorPos(ox, oy)
        end
    else sp, rst = function(x, y) term.setPixel(x-1, y-1, color) end, function() end end
    drawLineInternal(sp, x1, y1, x2, y2)
    rst()
end

--- Draws an outlined rectangle on screen.
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x The upper-left X coordinate to draw at
-- @tparam number y The upper-left Y coordinate to draw at
-- @tparam number width The width of the rectangle
-- @tparam number height The height of the rectangle
-- @tparam number color The color to draw with
function graphics.drawBox(term, x, y, width, height, color)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, color, "number")
    if util.type(term) == "Terminal" then
        local b, f = term.getBackgroundColor(), term.getTextColor()
        local ox, oy = term.getCursorPos()
        local fg, bg = ("%x"):format(f), ("%x"):format(color)
        term.setCursorPos(x, y)
        term.blit((" "):rep(width), fg:rep(width), bg:rep(width))
        term.setCursorPos(x, y+height-1)
        term.blit((" "):rep(width), fg:rep(width), bg:rep(width))
        for py = y + 1, y + height - 2 do
            term.setCursorPos(x, py)
            term.blit(" ", fg, bg)
            term.setCursorPos(x+width-1, py)
            term.blit(" ", fg, bg)
        end
        term.setBackgroundColor(b)
        term.setCursorPos(ox, oy)
    else
        term.drawPixels(x-1, y-1, color, width, 1)
        term.drawPixels(x-1, y-1, color, 1, height)
        term.drawPixels(x-1, y+height-1, color, width, 1)
        term.drawPixels(x+width-1, y-1, color, 1, height)
    end
end

--- Draws a filled rectangle on screen.
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x The upper-left X coordinate to draw at
-- @tparam number y The upper-left Y coordinate to draw at
-- @tparam number width The width of the rectangle
-- @tparam number height The height of the rectangle
-- @tparam number color The color to draw with
function graphics.drawFilledBox(term, x, y, width, height, color)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, color, "number")
    if util.type(term) == "Terminal" then
        local b, f = term.getBackgroundColor(), term.getTextColor()
        local ox, oy = term.getCursorPos()
        local text, fg, bg = (" "):rep(width), ("%x"):format(f):rep(width), ("%x"):format(color):rep(width)
        for py = y, y + height - 1 do
            term.setCursorPos(x, py)
            term.blit(text, fg, bg)
        end
        term.setBackgroundColor(b)
        term.setCursorPos(ox, oy)
    else
        term.drawPixels(x-1, y-1, color, width, height)
    end
end

--- Draws an outlined circle (or arc) on screen.
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x The upper-left X coordinate to draw at
-- @tparam number y The upper-left Y coordinate to draw at
-- @tparam number width The width of the circle
-- @tparam number height The height of the circle
-- @tparam number color The color to draw with
-- @tparam[opt=0] number startAngle The angle to start from in radians (starting at the right side)
-- @tparam[opt=2*math.pi] number arcCircumference The amount of the arc to draw in radians
function graphics.drawCircle(term, x, y, width, height, color, startAngle, arcCircumference)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    expect(6, color, "number")
    startAngle = (expect(7, startAngle, "number", "nil") or 0) % (2 * math.pi)
    arcCircumference = (expect(8, arcCircumference, "number", "nil") or 0) % (2 * math.pi)
    if arcCircumference == 0 then arcCircumference = 2*math.pi end
    local sp, rst
    if util.type(term) == "Terminal" then
        local c = term.getBackgroundColor()
        local ox, oy = term.getCursorPos()
        term.setBackgroundColor(color)
        sp, rst = function(px, py)
            term.setCursorPos(px, py)
            term.write(" ")
        end, function()
            term.setBackgroundColor(c)
            term.setCursorPos(ox, oy)
        end
    else sp, rst = function(px, py) term.setPixel(px-1, py-1, color) end, function() end end
    local step = math.pi / (width + height) -- TODO: calibrate this
    width, height = width / 2, height / 2
    for theta = startAngle, startAngle + arcCircumference, step do
        local px, py = width * math.cos(theta) + width, height * math.sin(theta) + height
        sp(x + px, y + py)
    end
    rst()
end

--- Draws a filled triangle on screen.
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x1 The first X coordinate to draw at
-- @tparam number y1 The first Y coordinate to draw at
-- @tparam number x2 The second X coordinate to draw at
-- @tparam number y2 The second Y coordinate to draw at
-- @tparam number x3 The third X coordinate to draw at
-- @tparam number y3 The third Y coordinate to draw at
-- @tparam number color The color to draw with
function graphics.drawFilledTriangle(term, x1, y1, x2, y2, x3, y3, color)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x1, "number")
    expect(3, y1, "number")
    expect(4, x2, "number")
    expect(5, y2, "number")
    expect(6, x3, "number")
    expect(7, y3, "number")
    expect(8, color, "number")
    local row, rst
    if util.type(term) == "Terminal" then
        local b, f = term.getBackgroundColor(), term.getTextColor()
        local ox, oy = term.getCursorPos()
        local bg, fg = ("%x"):format(color), ("%x"):format(f)
        row, rst = function(px, py, len)
            term.setCursorPos(px, py)
            term.blit((" "):rep(len), fg:rep(len), bg:rep(len))
        end, function()
            term.setBackgroundColor(b)
            term.setTextColor(f)
            term.setCursorPos(ox, oy)
        end
    else row, rst = function(px, py, len) term.drawPixels(px-1, py-1, color, len, 1) end, function() end end
    local points = {{x = x1, y = y1}, {x = x2, y = y2}, {x = x3, y = y3}}
    table.sort(points, function(a, b) return a.y < b.y end)
    if points[1].y == points[2].y then
        -- Triangle with horizontal line facing down
        -- This has two lines that start and end at the same Ys, so we can draw
        -- them in parallel, and the third line on top will automatically be
        -- drawn as part of this process (during the first row blit).
        if points[2].y == points[3].y then
            local dx = math.min(points[1].x, points[2].x, points[3].x)
            row(dx, points[1].y, math.max(points[1].x, points[2].x, points[3].x) - dx)
            rst()
            return
        end
        if points[1].x > points[2].x then points[1], points[2] = points[2], points[1] end
        local l1, l2 = coroutine.create(drawLineInternal), coroutine.create(drawLineInternal)
        local _, l1x, ry = coroutine.resume(l1, coroutine.yield, points[1].x, points[1].y, points[3].x, points[3].y)
        local _, l2x, currentY = coroutine.resume(l2, coroutine.yield, points[2].x, points[2].y, points[3].x, points[3].y)
        local minX, maxX = l1x, l2x
        while currentY do
            repeat
                minX = math.min(minX, l1x)
                _, l1x, ry = coroutine.resume(l1)
            until ry ~= currentY
            repeat
                maxX = math.max(maxX, l2x)
                _, l2x, ry = coroutine.resume(l2)
            until ry ~= currentY
            row(minX, currentY, maxX - minX + 1)
            minX, maxX, currentY = l1x, l2x, ry
        end
    elseif points[2].y == points[3].y then
        -- Triangle with horizontal line facing up
        -- This follows the same procedure as facing down, but with the points
        -- swapped around.
        if points[2].x > points[3].x then points[2], points[3] = points[3], points[2] end
        local l1, l2 = coroutine.create(drawLineInternal), coroutine.create(drawLineInternal)
        local _, l1x, ry = coroutine.resume(l1, coroutine.yield, points[1].x, points[1].y, points[2].x, points[2].y)
        local _, l2x, currentY = coroutine.resume(l2, coroutine.yield, points[1].x, points[1].y, points[3].x, points[3].y)
        local minX, maxX = l1x, l2x
        while currentY do
            repeat
                minX = math.min(minX, l1x)
                _, l1x, ry = coroutine.resume(l1)
            until ry ~= currentY
            repeat
                maxX = math.max(maxX, l2x)
                _, l2x, ry = coroutine.resume(l2)
            until ry ~= currentY
            row(minX, currentY, maxX - minX + 1)
            minX, maxX, currentY = l1x, l2x, ry
        end
    else
        -- Any other free-form triangle
        -- The triangle is defined by a dividing line between points 1 and 3
        -- (highest and lowest points), with two lines going to the side meeting
        -- at point 2.
        -- We can do a similar procedure as above by drawing the dividing line
        -- the whole way through, but once the other line meets point 2 we need
        -- to swap to line 2->3.
        local l1, l2 = coroutine.create(drawLineInternal), coroutine.create(drawLineInternal)
        local _, l1x, ry = coroutine.resume(l1, coroutine.yield, points[1].x, points[1].y, points[3].x, points[3].y)
        local _, l2x, currentY = coroutine.resume(l2, coroutine.yield, points[1].x, points[1].y, points[2].x, points[2].y)
        local minX, maxX = l1x, l2x
        while l1x and l2x and currentY do
            repeat
                minX = math.min(minX, l1x)
                maxX = math.max(maxX, l1x)
                _, l1x, ry = coroutine.resume(l1)
            until ry ~= currentY
            if currentY == points[2].y then
                l2 = coroutine.create(drawLineInternal)
                _, l2x, ry = coroutine.resume(l2, coroutine.yield, points[2].x, points[2].y, points[3].x, points[3].y)
            end
            repeat
                minX = math.min(minX, l2x)
                maxX = math.max(maxX, l2x)
                _, l2x, ry = coroutine.resume(l2)
            until ry ~= currentY
            row(minX, currentY, maxX - minX + 1)
            minX, maxX, currentY = math.min(l1x or 0, l2x or 0), math.max(l1x or 0, l2x or 0), ry
        end
    end
    rst()
end

--- Draws an image on screen. The image may be either a valid graphics mode
-- pixel region (using either string or table rows), or a blit table with
-- {text, text color, background color} table rows (text mode only).
-- @tparam Terminal|GFXTerminal term The terminal to draw on
-- @tparam number x The X coordinate to draw at
-- @tparam number y The Y coordinate to draw at
-- @tparam table image The image to draw
function graphics.drawImage(term, x, y, image)
    expect(1, term, "Terminal", "GFXTerminal")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, image, "table")
    if util.type(term) == "Terminal" then
        local b, f = term.getBackgroundColor(), term.getTextColor()
        local ox, oy = term.getCursorPos()
        local fg = ("%x"):format(f)
        for py = 1, #image do
            expect.field(image, py, "string", "table")
            term.setCursorPos(x, y + py - 1)
            local row = image[py]
            if type(row) == "string" then
                -- Graphics string-row table
                local bg = row:gsub("[\16-\255]", " "):gsub("[%z-\15]", function(c) return ("%x"):format(c:byte()) end)
                term.blit((" "):rep(#bg), fg:rep(#bg), bg)
            elseif #row == 3 and type(row[1] == "string") then
                -- Blit table
                term.blit(row[1], row[2], row[3])
            else
                -- Graphics table-row table
                local bg = ""
                for i = 1, #row do
                    expect(row, i, "number")
                    bg = bg .. ("%x"):format(row[i])
                end
                term.blit((" "):rep(#bg), fg:rep(#bg), bg)
            end
        end
        term.setBackgroundColor(b)
        term.setTextColor(f)
        term.setCursorPos(ox, oy)
    else
        if type(image[1]) == "table" and type(image[1][1]) == "string" then error("bad argument #4 to 'drawImage' (image type not supported on this terminal)", 2) end
        return term.drawPixels(x-1, y-1, image)
    end
end

return graphics
