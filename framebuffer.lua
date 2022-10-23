--- The framebuffer library provides functions to make "window" and "framebuffer"
-- objects. These objects imitate a Terminal object (as returned by
-- @{system.terminal.openterm}) or GFXTerminal object (as returned by
-- @{system.terminal.opengfx}) that may or may not draw to a parent object.
-- Windows and framebuffers may be used as parents to other windows and
-- framebuffers, in addition to the root terminal object.
--
-- A framebuffer object holds its own state, can be redrawn onto the parent
-- terminal even if the parent is changed, can be removed from the parent and
-- used independently, and its contents can be accessed from code. A window
-- object simply changes the coordinates of writing methods, and is entirely
-- dependent on the parent.
--
-- The type of object returned by each function is dependent on the parent
-- passed in. If a Terminal object is passed, a Terminal object is created; if a
-- GFXTerminal object is passed, a GFXTerminal object is created. When creating
-- a framebuffer with no parent, the @{empty} fields are used to specify the type.
--
-- @module system.framebuffer

local expect = require "expect"
local util = require "util"

local framebuffer = {}

--- Empty objects for use when creating framebuffers with no parents.
-- @field text Used to create a text mode Terminal framebuffer
-- @field graphics Used to create a graphics mode GFXTerminal framebuffer
framebuffer.empty = {
    text = {}, -- Used to create a text mode Terminal framebuffer
    graphics = {}, -- Used to create a graphics mode GFXTerminal framebuffer
}

--- Creates a new window object.
-- @tparam Terminal|GFXTerminal parent The parent object to render to
-- @tparam number x The X coordinate in the parent to start at
-- @tparam number y The Y coordinate in the parent to start at
-- @tparam number width The width of the window
-- @tparam number height The height of the window
-- @treturn Terminal|GFXTerminal The new window object
function framebuffer.window(parent, x, y, width, height)
    expect(1, parent, "Terminal", "GFXTerminal")
    expect(2, x, "number")
    expect(3, y, "number")
    expect(4, width, "number")
    expect(5, height, "number")
    local typ = util.type(parent)

    local win = {}

    function win.close() end
    function win.getSize() return width, height end
    function win.getPosition() return x, y end
    function win.getPaletteColor(color) return parent.getPaletteColor(color) end
    function win.setPaletteColor(color, r, g, b) return parent.setPaletteColor(color, r, g, b) end
    win.getPaletteColour = win.getPaletteColor
    win.setPaletteColour = win.setPaletteColor

    function win.reposition(_x, _y, w, h, p)
        expect(1, _x, "number", "nil")
        expect(2, _y, "number", "nil")
        expect(3, w, "number", "nil")
        expect(4, h, "number", "nil")
        expect(5, p, "nil", typ)
        x = _x or x
        y = _y or y
        width = w or width
        height = h or height
        parent = p or parent
    end

    function win.resize(w, h)
        expect(1, w, "number", "nil")
        expect(2, h, "number", "nil")
        width = w or width
        height = h or height
    end

    function win.reparent(p)
        expect(1, p, "nil", typ)
        parent = p or parent
    end

    if typ == "Terminal" then
        setmetatable(win, {__name = "Terminal"})
        local cx, cy, cblink = 1, 1, parent.getCursorBlink()
        local fg, bg = parent.getTextColor(), parent.getBackgroundColor()
        function win.write(text)
            expect(1, text, "string")
            if cy < 1 or cy > height or cx > width or #text == 0 then return end
            if cx < 1 then
                local d = math.min(1 - cx, #text)
                cx = cx + d
                if d == #text then return end
                text = text:sub(d)
            end
            local d = math.min(width - cx + 1, #text)
            parent.setCursorPos(x+cx-1, y+cy-1)
            parent.setTextColor(fg)
            parent.setBackgroundColor(bg)
            parent.write(text:sub(1, d))
            cx = cx + d
        end

        function win.blit(text, fgs, bgs)
            expect(1, text, "string")
            expect(2, fgs, "string")
            expect(3, bgs, "string")
            if cy < 1 or cy > height or cx > width or #text == 0 then return end
            if cx < 1 then
                local d = math.min(1 - cx, #text)
                cx = cx + d
                if d == #text then return end
                text = text:sub(d)
            end
            local d = math.min(width - cx + 1, #text)
            parent.setCursorPos(x+cx-1, y+cy-1)
            parent.blit(text:sub(1, d), fgs:sub(1, d), bgs:sub(1, d))
            fg, bg = parent.getTextColor(), parent.getBackgroundColor()
            cx = cx + d
        end

        function win.clear()
            parent.setTextColor(fg)
            parent.setBackgroundColor(bg)
            for yy = 1, height do
                parent.setCursorPos(x, y+yy-1)
                parent.write((" "):rep(width))
            end
        end

        function win.clearLine()
            parent.setTextColor(fg)
            parent.setBackgroundColor(bg)
            parent.setCursorPos(x, y+cy-1)
            parent.write((" "):rep(width))
        end

        function win.getCursorPos()
            return cx, cy
        end

        function win.setCursorPos(_x, _y)
            expect(1, _x, "number")
            expect(2, _y, "number")
            cx, cy = _x, _y
            parent.setCursorPos(x+cx-1, y+cy-1)
        end

        function win.getCursorBlink()
            return cblink
        end

        function win.setCursorBlink(blink)
            expect(1, blink, "boolean")
            cblink = blink
            parent.setCursorBlink(blink)
        end

        function win.isColor()
            return parent.isColor()
        end

        function win.scroll(lines)
            expect(1, lines, "number")
            if math.abs(lines) >= width then
                return win.clear()
            elseif lines > 0 then
                for i = lines + 1, height do
                    local l = win.getLine(i)
                    parent.setCursorPos(x, y+i-lines-1)
                    parent.blit(table.unpack(l, 1, 3))
                end
                for i = height - lines + 1, height do
                    parent.setCursorPos(x, y+i-1)
                    parent.setTextColor(fg)
                    parent.setBackgroundColor(bg)
                    parent.write((' '):rep(width))
                end
            elseif lines < 0 then
                for i = 1, height + lines do
                    local l = win.getLine(i)
                    parent.setCursorPos(x, y+i-lines-1)
                    parent.blit(table.unpack(l, 1, 3))
                end
                for i = 1, -lines do
                    parent.setCursorPos(x, y+i-1)
                    parent.setTextColor(fg)
                    parent.setBackgroundColor(bg)
                    parent.write((' '):rep(width))
                end
            else return end
        end

        function win.getTextColor()
            return fg
        end

        function win.setTextColor(color)
            expect(1, color, "number")
            fg = color
            parent.setTextColor(color)
        end

        function win.getBackgroundColor()
            return bg
        end

        function win.setBackgroundColor(color)
            expect(1, color, "number")
            bg = color
            parent.setBackgroundColor(color)
        end

        function win.getLine(_y)
            expect(1, _y, "number")
            local l = parent.getLine(y+_y-1)
            if not l then return nil end
            return {l[1]:sub(x, x+width-1), l[2]:sub(x, x+width-1), l[3]:sub(x, x+width-1)}
        end

        function win.restoreCursor()
            parent.setCursorPos(x+cx-1, y+cy-1)
            parent.setCursorBlink(cblink)
        end
        win.isColour = win.isColor
        win.getTextColour = win.getTextColor
        win.setTextColour = win.setTextColor
        win.getBackgroundColour = win.getBackgroundColor
        win.setBackgroundColour = win.setBackgroundColor
    else
        setmetatable(win, {__name = "GFXTerminal"})
        function win.clear()
            parent.drawPixels(x, y, 15, width, height)
        end

        function win.getPixel(_x, _y)
            return parent.getPixel(x+_x, y+_y)
        end

        function win.setPixel(_x, _y, color)
            return parent.setPixel(x+_x, y+_y, color)
        end

        function win.getPixels(_x, _y, _width, _height, asStr)
            return parent.getPixels(x+_x, y+_y, _width, _height, asStr)
        end

        function win.drawPixels(_x, _y, data, _width, _height)
            return parent.drawPixels(x+_x, y+_y, data, _width, _height)
        end

        function win.getFrozen()
            return parent.getFrozen()
        end

        function win.setFrozen(frozen)
            return parent.setFrozen(frozen)
        end
    end

    return win
end

--- Creates a new framebuffer object.
-- @tparam Terminal|GFXTerminal parent The parent object to render to, or a member of @{empty} to not use a parent
-- @tparam number|nil wx The X coordinate in the parent to start at (`nil` if there's no parent)
-- @tparam number|nil wy The Y coordinate in the parent to start at (`nil` if there's no parent)
-- @tparam number w The width of the framebuffer
-- @tparam number h The height of the framebuffer
-- @tparam[opt] boolean visible Whether the window should be visible upon creation
-- @treturn Terminal|GFXTerminal The new framebuffer object
function framebuffer.framebuffer(parent, wx, wy, w, h, visible)
    local isGFX
    if parent == framebuffer.empty.text or parent == framebuffer.empty.graphics then
        wx = expect(2, wx, "number", "nil") or 1
        wy = expect(3, wy, "number", "nil") or 1
        isGFX = parent == framebuffer.empty.graphics
        parent = nil
    else
        expect(1, parent, "Terminal", "GFXTerminal")
        expect(2, wx, "number")
        expect(3, wy, "number")
        isGFX = util.type(parent) == "GFXTerminal"
    end
    expect(4, w, "number")
    expect(5, h, "number")
    expect(6, visible, "boolean", "nil")
    if visible == nil then visible = true end
    local size = {width = w, height = h}

    if isGFX then
        local buffer = {
            palette = {},
            dirtyRects = {},
            dirtyPalette = {},
            frozen = false,
        }
        for y = 1, size.height * 9 do buffer[y] = ('\15'):rep(size.width * 6) end
        if parent then
            for i = 0, 15 do
                buffer.palette[i] = {parent.getPaletteColor(i)}
                buffer.dirtyPalette[i] = true
            end
        else
            buffer.palette = {
                [0] = {0.94117647058824, 0.94117647058824, 0.94117647058824},
                {0.94901960784314, 0.69803921568627, 0.2},
                {0.89803921568627, 0.49803921568627, 0.84705882352941},
                {0.6, 0.69803921568627, 0.94901960784314},
                {0.87058823529412, 0.87058823529412, 0.42352941176471},
                {0.49803921568627, 0.8, 0.098039215686275},
                {0.94901960784314, 0.69803921568627, 0.8},
                {0.29803921568627, 0.29803921568627, 0.29803921568627},
                {0.6, 0.6, 0.6},
                {0.29803921568627, 0.6, 0.69803921568627},
                {0.69803921568627, 0.4, 0.89803921568627},
                {0.2, 0.4, 0.8},
                {0.49803921568627, 0.4, 0.29803921568627},
                {0.34117647058824, 0.65098039215686, 0.30588235294118},
                {0.8, 0.29803921568627, 0.29803921568627},
                {0.066666666666667, 0.066666666666667, 0.066666666666667}
            }
            for i = 0, 15 do buffer.dirtyPalette[i] = true end
        end
        for i = 16, 255 do
            buffer.palette[i] = {0, 0, 0}
            buffer.dirtyPalette[i] = true
        end

        local win = setmetatable({}, {__name = "GFXTerminal"})

        function win.close() end

        function win.getSize()
            return size.width * 6, size.height * 9
        end

        function win.clear()
            for y = 1, size.height * 9 do buffer[y] = ('\15'):rep(size.width * 6) end
            win.redraw(true)
        end

        function win.getPixel(x, y)
            expect(1, x, "number")
            expect(2, y, "number")
            expect.range(x, 0, size.width * 6 - 1)
            expect.range(y, 0, size.height * 9 - 1)
            x, y = math.floor(x), math.floor(y)
            return buffer[y+1]:byte(x+1)
        end

        function win.setPixel(x, y, color)
            expect(1, x, "number")
            expect(2, y, "number")
            expect(3, color, "number")
            expect.range(x, 0, size.width * 6 - 1)
            expect.range(y, 0, size.height * 9 - 1)
            expect.range(color, 0, 255)
            x, y = math.floor(x), math.floor(y)
            buffer[y+1] = buffer[y+1]:sub(1, x) .. string.char(color) .. buffer[y+1]:sub(x + 2)
            buffer.dirtyRects[#buffer.dirtyRects+1] = {x = x, y = y, color = color}
            win.redraw()
        end

        function win.getPixels(x, y, width, height, asStr)
            expect(1, x, "number")
            expect(2, y, "number")
            expect(3, width, "number")
            expect(4, height, "number")
            expect(5, asStr, "boolean", "nil")
            expect.range(width, 0)
            expect.range(height, 0)
            x, y = math.floor(x), math.floor(y)
            local t = {}
            for py = 1, height do
                if asStr then t[py] = buffer[y+py]:sub(x + 1, x + width)
                else t[py] = {buffer[y+py]:sub(x + 1, x + width):byte(1, -1)} end
            end
            return t
        end

        function win.drawPixels(x, y, data, width, height)
            expect(1, x, "number")
            expect(2, y, "number")
            expect(3, data, "table", "number")
            local isn = type(data) == "number"
            expect(4, width, "number", not isn and "nil" or nil)
            expect(5, height, "number", not isn and "nil" or nil)
            expect.range(x, 0, size.width * 6 - 1)
            expect.range(y, 0, size.height * 9 - 1)
            if width then expect.range(width, 0) end
            if height then expect.range(height, 0) end
            if isn then expect.range(data, 0, 255) end
            if width == 0 or height == 0 then return end
            x, y = math.floor(x), math.floor(y)
            if width and x + width >= size.width * 6 then width = size.width * 6 - x end
            height = height or #data
            local rect = {x = x, y = y, width = width, height = height}
            for py = 1, height do
                if y + py > size.height * 9 then break end
                if isn then
                    local s = string.char(data):rep(width)
                    buffer[y+py] = buffer[y+py]:sub(1, x) .. s .. buffer[y+py]:sub(x + width + 1)
                    rect[py] = s
                elseif data[py] ~= nil then
                    if type(data[py]) ~= "table" and type(data[py]) ~= "string" then
                        error("bad argument #3 to 'drawPixels' (invalid row " .. py .. ")", 2)
                    end
                    local width = width or #data[py]
                    if x + width >= size.width * 6 then width = size.width * 6 - x end
                    local s
                    if type(data[py]) == "string" then
                        s = data[py]
                        if #s < width then s = s .. ('\15'):rep(width - #s)
                        elseif #s > width then s = s:sub(1, width) end
                    else
                        s = ""
                        for px = 1, width do s = s .. string.char(data[py][px] or buffer[y+py]:byte(x+px)) end
                    end
                    buffer[y+py] = buffer[y+py]:sub(1, x) .. s .. buffer[y+py]:sub(x + width + 1)
                    rect[py] = s
                end
            end
            buffer.dirtyRects[#buffer.dirtyRects+1] = rect
            win.redraw()
        end

        function win.getFrozen()
            return buffer.frozen
        end

        function win.setFrozen(f)
            expect(1, f, "boolean")
            buffer.frozen = f
            win.redraw()
        end

        function win.getPaletteColor(color)
            expect(1, color, "number")
            expect.range(color, 0, 255)
            return table.unpack(buffer.palette[color])
        end

        function win.setPaletteColor(color, r, g, b)
            expect(1, color, "number")
            expect(2, r, "number")
            if g == nil and b == nil then r, g, b = bit32.band(bit32.rshift(r, 16), 0xFF) / 255, bit32.band(bit32.rshift(r, 8), 0xFF) / 255, bit32.band(r, 0xFF) / 255 end
            expect(3, g, "number")
            expect(4, b, "number")
            expect.range(r, 0, 1)
            expect.range(g, 0, 1)
            expect.range(b, 0, 1)
            expect.range(color, 0, 255)
            buffer.palette[color] = {r, g, b}
            buffer.dirtyPalette[color] = true
            win.redraw()
        end

        function win.getPosition()
            return wx, wy
        end

        function win.reposition(x, y, w, h, p)
            expect(1, x, "number", "nil")
            expect(2, y, "number", "nil")
            wx = x or wx
            wy = y or wy
            if p then win.reparent(p) end
            if w or h then return win.resize(w, h) end
        end

        function win.resize(width, height)
            expect(1, width, "number", "nil")
            expect(2, height, "number", "nil")
            if width > size.width then
                for y = 1, size.height * 9 do
                    buffer[y] = buffer[y] .. ('\15'):rep((width - size.width) * 6)
                end
                buffer.dirtyRects[#buffer.dirtyRects+1] = {
                    x = size.width * 6 + 1, y = 1,
                    width = (width - size.width) * 6, height = size.height * 9
                }
            elseif width < size.width then
                for y = 1, size.height * 9 do
                    buffer[y] = buffer[y]:sub(1, width * 6)
                end
            end
            size.width = width

            if height > size.height then
                for y = size.height * 9 + 1, height * 9 do
                    buffer[y] = ('\15'):rep(width * 6)
                end
                buffer.dirtyRects[#buffer.dirtyRects+1] = {
                    x = 1, y = size.height * 9 + 1,
                    width = size.width * 6, height = (height - size.height) * 9
                }
            elseif height < size.height then
                for y = height * 9 + 1, size.height * 9 do
                    buffer[y] = nil
                end
            end
            size.height = height
        end

        function win.reparent(p)
            expect(1, p, "GFXTerminal", "nil")
            parent = p
            win.redraw()
        end

        function win.redraw(full)
            if not parent or not visible then return end
            if parent.setFrozen then parent.setFrozen(true) end
            if full then
                parent.clear()
                parent.drawPixels(0, 0, buffer)
                for i = 0, 255 do parent.setPaletteColor(i, buffer.palette[i][1], buffer.palette[i][2], buffer.palette[i][3]) end
            else
                if buffer.frozen then
                    if parent.setFrozen then parent.setFrozen(false) end
                    return
                end
                for _, v in ipairs(buffer.dirtyRects) do
                    if v.color then parent.setPixel(v.x, v.y, v.color, v.width, v.height)
                    else parent.drawPixels(v.x, v.y, v) end
                end
                for i in pairs(buffer.dirtyPalette) do parent.setPaletteColor(i, buffer.palette[i][1], buffer.palette[i][2],buffer.palette[i][3]) end
            end
            if parent.setFrozen then parent.setFrozen(false) end
            buffer.dirtyRects, buffer.dirtyPalette = {}, {}
        end

        function win.isVisible()
            return visible
        end

        function win.setVisible(v)
            expect(1, v, "boolean")
            visible = v
            win.redraw()
        end

        win.getPaletteColour = win.getPaletteColor
        win.setPaletteColour = win.setPaletteColor
        win.redraw()
        return win
    else
        local buffer = {
            cursor = {x = 1, y = 1},
            cursorBlink = false,
            colors = {fg = '0', bg = 'f'},
            palette = {},
            dirtyLines = {},
            dirtyPalette = {},
        }
        for y = 1, size.height do
            buffer[y] = {(' '):rep(size.width), ('0'):rep(size.width), ('f'):rep(size.width)}
            buffer.dirtyLines[y] = true
        end
        if parent then
            for i = 0, 15 do
                buffer.palette[i] = {parent.getPaletteColor(i)}
                buffer.dirtyPalette[i] = true
            end
        else
            buffer.palette = {
                [0] = {0.94117647058824, 0.94117647058824, 0.94117647058824},
                {0.94901960784314, 0.69803921568627, 0.2},
                {0.89803921568627, 0.49803921568627, 0.84705882352941},
                {0.6, 0.69803921568627, 0.94901960784314},
                {0.87058823529412, 0.87058823529412, 0.42352941176471},
                {0.49803921568627, 0.8, 0.098039215686275},
                {0.94901960784314, 0.69803921568627, 0.8},
                {0.29803921568627, 0.29803921568627, 0.29803921568627},
                {0.6, 0.6, 0.6},
                {0.29803921568627, 0.6, 0.69803921568627},
                {0.69803921568627, 0.4, 0.89803921568627},
                {0.2, 0.4, 0.8},
                {0.49803921568627, 0.4, 0.29803921568627},
                {0.34117647058824, 0.65098039215686, 0.30588235294118},
                {0.8, 0.29803921568627, 0.29803921568627},
                {0.066666666666667, 0.066666666666667, 0.066666666666667}
            }
            for i = 0, 15 do buffer.dirtyPalette[i] = true end
        end

        local win = setmetatable({}, {__name = "Terminal"})

        function win.close() end

        function win.write(text)
            text = tostring(text)
            expect(1, text, "string")
            if buffer.cursor.y < 1 or buffer.cursor.y > size.height then return
            elseif buffer.cursor.x > size.width or buffer.cursor.x + #text < 1 then
                buffer.cursor.x = buffer.cursor.x + #text
                return
            elseif buffer.cursor.x < 1 then
                text = text:sub(-buffer.cursor.x + 2)
                buffer.cursor.x = 1
            end
            local ntext = #text
            if buffer.cursor.x + #text > size.width then text = text:sub(1, size.width - buffer.cursor.x + 1) end
            buffer[buffer.cursor.y][1] = buffer[buffer.cursor.y][1]:sub(1, buffer.cursor.x - 1) .. text .. buffer[buffer.cursor.y][1]:sub(buffer.cursor.x + #text)
            buffer[buffer.cursor.y][2] = buffer[buffer.cursor.y][2]:sub(1, buffer.cursor.x - 1) .. buffer.colors.fg:rep(#text) .. buffer[buffer.cursor.y][2]:sub(buffer.cursor.x + #text)
            buffer[buffer.cursor.y][3] = buffer[buffer.cursor.y][3]:sub(1, buffer.cursor.x - 1) .. buffer.colors.bg:rep(#text) .. buffer[buffer.cursor.y][3]:sub(buffer.cursor.x + #text)
            buffer.cursor.x = buffer.cursor.x + ntext
            buffer.dirtyLines[buffer.cursor.y] = true
            win.redraw()
        end

        function win.blit(text, fg, bg)
            text = tostring(text)
            expect(1, text, "string")
            expect(2, fg, "string")
            expect(3, bg, "string")
            if #text ~= #fg or #fg ~= #bg then error("Arguments must be the same length", 2) end
            if buffer.cursor.y < 1 or buffer.cursor.y > size.height then return
            elseif buffer.cursor.x > size.width or buffer.cursor.x < 1 - #text then
                buffer.cursor.x = buffer.cursor.x + #text
                win.redraw()
                return
            elseif buffer.cursor.x < 1 then
                text, fg, bg = text:sub(-buffer.cursor.x + 2), fg:sub(-buffer.cursor.x + 2), bg:sub(-buffer.cursor.x + 2)
                buffer.cursor.x = 1
            end
            local ntext = #text
            if buffer.cursor.x + #text > size.width then text, fg, bg = text:sub(1, size.width - buffer.cursor.x + 1), fg:sub(1, size.width - buffer.cursor.x + 1), bg:sub(1, size.width - buffer.cursor.x + 1) end
            buffer[buffer.cursor.y][1] = buffer[buffer.cursor.y][1]:sub(1, buffer.cursor.x - 1) .. text .. buffer[buffer.cursor.y][1]:sub(buffer.cursor.x + #text)
            buffer[buffer.cursor.y][2] = buffer[buffer.cursor.y][2]:sub(1, buffer.cursor.x - 1) .. fg .. buffer[buffer.cursor.y][2]:sub(buffer.cursor.x + #fg)
            buffer[buffer.cursor.y][3] = buffer[buffer.cursor.y][3]:sub(1, buffer.cursor.x - 1) .. bg .. buffer[buffer.cursor.y][3]:sub(buffer.cursor.x + #bg)
            buffer.cursor.x = buffer.cursor.x + ntext
            buffer.dirtyLines[buffer.cursor.y] = true
            win.redraw()
        end

        function win.clear()
            for y = 1, size.height do
                buffer[y] = {(' '):rep(size.width), buffer.colors.fg:rep(size.width), buffer.colors.bg:rep(size.width)}
                buffer.dirtyLines[y] = true
            end
            win.redraw()
        end

        function win.clearLine()
            if buffer.cursor.y >= 1 and buffer.cursor.y <= size.height then
                buffer[buffer.cursor.y] = {(' '):rep(size.width), buffer.colors.fg:rep(size.width), buffer.colors.bg:rep(size.width)}
                buffer.dirtyLines[buffer.cursor.y] = true
                win.redraw()
            end
        end

        function win.getCursorPos()
            return buffer.cursor.x, buffer.cursor.y
        end

        function win.setCursorPos(cx, cy)
            expect(1, cx, "number")
            expect(2, cy, "number")
            if cx == buffer.cursor.x and cy == buffer.cursor.y then return end
            buffer.cursor.x, buffer.cursor.y = math.floor(cx), math.floor(cy)
            win.redraw()
        end

        function win.getCursorBlink()
            return buffer.cursorBlink
        end

        function win.setCursorBlink(b)
            expect(1, b, "boolean")
            buffer.cursorBlink = b
            win.redraw()
        end

        function win.isColor()
            return true
        end

        function win.getSize()
            return size.width, size.height
        end

        function win.scroll(lines)
            expect(1, lines, "number")
            if math.abs(lines) >= size.width then
                for y = 1, size.height do buffer[y] = {(' '):rep(size.width), buffer.colors.fg:rep(size.width), buffer.colors.bg:rep(size.width)} end
            elseif lines > 0 then
                for i = lines + 1, size.height do buffer[i - lines] = buffer[i] end
                for i = size.height - lines + 1, size.height do buffer[i] = {(' '):rep(size.width), buffer.colors.fg:rep(size.width), buffer.colors.bg:rep(size.width)} end
            elseif lines < 0 then
                for i = 1, size.height + lines do buffer[i - lines] = buffer[i] end
                for i = 1, -lines do buffer[i] = {(' '):rep(size.width), buffer.colors.fg:rep(size.width), buffer.colors.bg:rep(size.width)} end
            else return end
            for i = 1, size.height do buffer.dirtyLines[i] = true end
            win.redraw()
        end

        function win.getTextColor()
            return tonumber(buffer.colors.fg)
        end

        function win.setTextColor(color)
            expect(1, color, "number")
            expect.range(color, 0, 15)
            buffer.colors.fg = ("%x"):format(color)
        end

        function win.getBackgroundColor()
            return tonumber(buffer.colors.bg)
        end

        function win.setBackgroundColor(color)
            expect(1, color, "number")
            expect.range(color, 0, 15)
            buffer.colors.bg = ("%x"):format(color)
        end

        function win.getPaletteColor(color)
            expect(1, color, "number")
            expect.range(color, 0, 15)
            return table.unpack(buffer.palette[math.floor(color)])
        end

        function win.setPaletteColor(color, r, g, b)
            expect(1, color, "number")
            expect(2, r, "number")
            if g == nil and b == nil then r, g, b = bit32.band(bit32.rshift(r, 16), 0xFF) / 255, bit32.band(bit32.rshift(r, 8), 0xFF) / 255, bit32.band(r, 0xFF) / 255 end
            expect(3, g, "number")
            expect(4, b, "number")
            expect.range(color, 0, 15)
            if r < 0 or r > 1 then error("bad argument #2 (value out of range)", 2) end
            if g < 0 or g > 1 then error("bad argument #3 (value out of range)", 2) end
            if b < 0 or b > 1 then error("bad argument #4 (value out of range)", 2) end
            buffer.palette[math.floor(color)] = {r, g, b}
            buffer.dirtyPalette[math.floor(color)] = true
            win.redraw()
        end

        function win.getLine(y)
            expect(1, y, "number")
            local l = buffer[y]
            return l and table.unpack(l, 1, 3)
        end

        function win.getPosition()
            return wx, wy
        end

        function win.reposition(x, y, w, h, p)
            expect(1, x, "number", "nil")
            expect(2, y, "number", "nil")
            wx = x or wx
            wy = y or wy
            if p then win.reparent(p) end
            if x or y then win.redraw(true) end
            if w or h then return win.resize(w, h) end
        end

        function win.resize(width, height)
            expect(1, width, "number", "nil")
            expect(2, height, "number", "nil")
            if width > size.width then
                for y = 1, size.height do
                    buffer[y][1] = buffer[y][1] .. (' '):rep(width - size.width)
                    buffer[y][2] = buffer[y][2] .. buffer.colors.fg:rep(width - size.width)
                    buffer[y][3] = buffer[y][3] .. buffer.colors.bg:rep(width - size.width)
                    buffer.dirtyLines[y] = true
                end
            elseif width < size.width then
                for y = 1, size.height do
                    buffer[y][1] = buffer[y][1]:sub(1, width)
                    buffer[y][2] = buffer[y][2]:sub(1, width)
                    buffer[y][3] = buffer[y][3]:sub(1, width)
                end
            end
            size.width = width

            if height > size.height then
                for y = size.height + 1, height do
                    buffer[y] = {(' '):rep(width), buffer.colors.fg:rep(width), buffer.colors.bg:rep(width)}
                    buffer.dirtyLines[y] = true
                end
            elseif height < size.height then
                for y = height + 1, size.height do
                    buffer[y] = nil
                end
            end
            size.height = height
        end

        function win.reparent(p)
            expect(1, p, "Terminal", "nil")
            parent = p
            win.redraw()
        end

        function win.redraw(full)
            if not parent or not visible then return end
            parent.setCursorBlink(false)
            if full then
                parent.clear()
                for y = 1, size.height do
                    parent.setCursorPos(wx, wy+y-1)
                    parent.blit(buffer[y][1], buffer[y][2], buffer[y][3])
                end
                for i = 0, 15 do parent.setPaletteColor(i, buffer.palette[i][1], buffer.palette[i][2], buffer.palette[i][3]) end
            else
                for y in pairs(buffer.dirtyLines) do
                    parent.setCursorPos(wx, wy+y-1)
                    if #buffer[y][1] ~= #buffer[y][2] or #buffer[y][2] ~= #buffer[y][3] then error("Internal error: Invalid lengths") end
                    parent.blit(buffer[y][1], buffer[y][2], buffer[y][3])
                end
                for i in pairs(buffer.dirtyPalette) do parent.setPaletteColor(i, buffer.palette[i][1], buffer.palette[i][2], buffer.palette[i][3]) end
            end
            parent.setCursorPos(wx+buffer.cursor.x-1, wy+buffer.cursor.y-1)
            parent.setCursorBlink(buffer.cursorBlink)
            buffer.dirtyLines, buffer.dirtyPalette = {}, {}
        end

        function win.restoreCursor()
            if not parent or not visible then return end
            parent.setCursorPos(wx+buffer.cursor.x-1, wy+buffer.cursor.y-1)
            parent.setCursorBlink(buffer.cursorBlink)
        end

        function win.isVisible()
            return visible
        end

        function win.setVisible(v)
            expect(1, v, "boolean")
            visible = v
            win.redraw()
        end

        win.isColour = win.isColor
        win.getTextColour = win.getTextColor
        win.setTextColour = win.setTextColor
        win.getBackgroundColour = win.getBackgroundColor
        win.setBackgroundColour = win.setBackgroundColor
        win.getPaletteColour = win.getPaletteColor
        win.setPaletteColour = win.setPaletteColor
        win.redraw()
        return win
    end
end

return framebuffer
