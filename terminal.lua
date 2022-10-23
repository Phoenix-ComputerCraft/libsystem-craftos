--- The terminal module defines functions to allow interacting with the terminal
-- and screen, as well as handling user input.
--
-- @module system.terminal

local expect = require "expect"

local terminal = {}

local termtype = nil

--- Constants for colors. This includes both normal and British spelling.
terminal.colors = {
    white = 0,
    orange = 1,
    magenta = 2,
    lightBlue = 3,
    yellow = 4,
    lime = 5,
    pink = 6,
    gray = 7,
    grey = 7,
    lightGray = 8,
    lightGrey = 8,
    cyan = 9,
    purple = 10,
    blue = 11,
    brown = 12,
    green = 13,
    red = 14,
    black = 15
}
terminal.colours = terminal.colors

--- Converts a @{terminal.colors} constant to an ANSI escape code.
-- @tparam number color The color to convert
-- @tparam[opt=false] boolean background Whether the escape should set the background
-- @treturn string The escape code generated for the color
function terminal.toEscape(color, background)
    expect(1, color, "number")
    expect(2, background, "boolean", "nil")
    expect.range(color, 0, 15)
    local n = 37 - (color % 8)
    if color < 8 then n = n + 60 end
    if background then n = n + 10 end
    return "\x1b[" .. n .. "m"
end

--- Writes text to the standard output stream.
-- @param ... The entries to write. Each one will be separated by tabs (`\t`).
function terminal.write(...)
    for i, v in ipairs{...} do if i > 1 then write(" ") end write(v) end
end

--- Writes text to the standard error stream.
-- @param ... The entries to write. Each one will be separated by tabs (`\t`).
function terminal.writeerr(...)
    local oc = term.getTextColor()
    term.setTextColor(colors.red)
    for i, v in ipairs{...} do if i > 1 then write(" ") end write(v) end
    term.setTextColor(oc)
end

--- Reads a number of characters from the standard input stream.
-- @tparam number n The number of characters to read
-- @treturn string|nil The text read, or nil if EOF was reached.
function terminal.read(n)
    expect(1, n, "number")
    return read()
end

--- Reads a single line of text from the standard input stream.
-- @treturn string|nil The text read, or nil if EOF was reached.
function terminal.readline()
    return read()
end

--- Sets certain terminal control flags on the current TTY if available.
-- @tparam {cbreak?=boolean,delay?=boolean,echo?=boolean,keypad?=boolean,nlcr?=boolean,raw?=boolean} flags? The flags to set, or nil to just query.
-- @treturn {cbreak=boolean,delay=boolean,echo=boolean,keypad=boolean,nlcr=boolean,raw=boolean}|nil The flags that are currently set on the TTY, or nil if no TTY is available.
function terminal.termctl(flags)
    expect(1, flags, "table", "nil")
    if flags then
        expect.field(flags, "cbreak", "boolean", "nil")
        expect.field(flags, "delay", "boolean", "nil")
        expect.field(flags, "echo", "boolean", "nil")
        expect.field(flags, "keypad", "boolean", "nil")
        expect.field(flags, "nlcr", "boolean", "nil")
        expect.field(flags, "raw", "boolean", "nil")
    end
    return {
        cbreak = true,
        delay = true,
        echo = true,
        keypad = true,
        nlcr = true,
        raw = true
    }
end

--- Opens the current output TTY in exclusive text mode, allowing direct
-- manipulation of the screen buffer. Only one process may open the terminal at
-- a time. Once opened, the screen will be cleared, and stdout will be sent to
-- an off-screen buffer to be shown once the terminal is closed. The terminal
-- will automatically be closed on process exit.
-- @treturn[1] Terminal A terminal object for the current TTY.
-- @treturn[2] nil If the terminal could not be opened.
-- @treturn[2] string An error message describing why the terminal couldn't be opened.
function terminal.openterm()
    if termtype ~= nil then return nil, "Terminal is already open" end
    termtype = false
    local win = window.create(term.current(), 1, 1, term.getSize())
    local obj = setmetatable({}, {__name = "Terminal"})
    function obj.close()
        termtype = nil
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.white)
        term.clear()
        term.setCursorPos(1, 1)
        term.setCursorBlink(true)
    end
    obj.write = win.write
    obj.blit = win.blit
    obj.clear = win.clear
    obj.clearLine = win.clearLine
    obj.getCursorPos = win.getCursorPos
    obj.setCursorPos = win.setCursorPos
    obj.getCursorBlink = win.getCursorBlink
    obj.setCursorBlink = win.setCursorBlink
    obj.isColor = win.isColor
    obj.getSize = win.getSize
    obj.scroll = win.scroll
    function obj.getTextColor() return select(2, math.frexp(win.getTextColor()))-1 end
    function obj.setTextColor(color) return win.setTextColor(2^color) end
    function obj.getBackgroundColor() return select(2, math.frexp(win.getBackgroundColor()))-1 end
    function obj.setBackgroundColor(color) return win.setBackgroundColor(2^color) end
    function obj.getPaletteColor(color) return win.getPaletteColor(2^color) end
    function obj.setPaletteColor(color, r, g, b) return win.setPaletteColor(2^color, r, g, b) end
    obj.getTextColour = obj.getTextColor
    obj.setTextColour = obj.setTextColor
    obj.getBackgroundColour = obj.getBackgroundColor
    obj.setBackgroundColour = obj.setBackgroundColor
    obj.getPaletteColour = obj.getPaletteColor
    obj.setPaletteColour = obj.setPaletteColor
    obj.getLine = win.getLine
    return obj
end

--- Opens the current output TTY in exclusive graphics mode, allowing direct
-- manipulation of the pixels if available. Only one process may open the terminal
-- at a time. Once opened, the screen will be cleared, and stdout will be sent to
-- an off-screen buffer to be shown once the terminal is closed. The terminal
-- will automatically be closed on process exit. This only works on CraftOS-PC.
-- @treturn[1] GFXTerminal A graphical terminal object for the current TTY.
-- @treturn[2] nil If the terminal could not be opened.
-- @treturn[2] string An error message describing why the terminal couldn't be opened.
function terminal.opengfx()
    if termtype ~= nil then return nil, "Terminal is already open" end
    if not term.setGraphicsMode then return nil, "Graphics mode not supported" end
    termtype = true
    term.setGraphicsMode(2)
    local obj = setmetatable({}, {__name = "GFXTerminal"})
    function obj.close()
        termtype = nil
        term.clear()
        term.setGraphicsMode(false)
    end
    obj.getSize = term.getSize
    obj.clear = term.clear
    obj.getPaletteColor = term.getPaletteColor
    obj.setPaletteColor = term.setPaletteColor
    obj.getPixel = term.getPixel
    obj.setPixel = term.setPixel
    obj.getPixels = term.getPixels
    obj.drawPixels = term.drawPixels
    obj.getFrozen = term.getFrozen
    obj.setFrozen = term.setFrozen
end

--- Returns whether the current stdio are linked to a TTY.
-- @treturn boolean Whether the current stdin is linked to a TTY.
-- @treturn boolean Whether the current stdout is linked to a TTY.
function terminal.istty()
    return true, true
end

--- Returns the current size of the TTY if available.
-- @treturn[1] number The width of the screen.
-- @treturn[1] number The height of the screen.
-- @treturn[2] nil If the current stdout is not a screen.
function terminal.termsize()
    return term.getSize()
end
terminal.getSize = terminal.termsize

term.setCursorBlink(true)

return terminal