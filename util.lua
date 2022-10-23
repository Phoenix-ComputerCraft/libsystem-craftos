--- The util module contains various functions that don't have any specific
-- system function, or help improve the usability of the general system.
--
-- @module system.util

local expect = require "expect"

local util = {}

--- Takes a list of valid arguments + the arguments to a program, and returns a
-- table with the extracted arguments (and values if requested).
-- If an argument with all `-`s is passed, processing of arguments stops, and
-- all subsequent arguments are added to the list.
-- @tparam {[string]=string|boolean|nil} arguments A list of arguments that
-- the program accepts. Single-character arguments are handled through `-a`, and
-- longer arguments are handled through `--argument`. The value of the entry
-- specifies how the argument is handled:
-- * If the value is a truthy value, this argument requires a parameter.
-- * If the value is `"number"`, the argument requires a number parameter.
-- * If the value is `"multiple"`, the argument can be specified multiple times,
--   and will require a parameter. The values returned will be in a table.
-- * If the value is `"multiple number"`, the argument can be specified multiple
--   times, and will require a number parameter. These are also in a table.
-- * If the value is `false`, the argument does not take a parameter.
-- * If the value is `nil`, the argument does not exist and will throw an error
--   if passed.
-- * If the value starts with `@`, the parameter is an alias and will be stored
--   in that argument instead, following the same rules as that argument as well.
-- Special parameters to the parser can be added in a `[""]` table. The following
-- parameters are specified:
-- * `stopProcessingOnPositionalArgument` [boolean]: Whether to stop processing
--   arguments when a positional argument is passed, e.g. `myprog -s arg -i` will
--   return `args.s = true`, but `args.i = nil`.
-- @tparam string ... The arguments as passed to the program.
-- @treturn[1] {[string]=string|number|boolean|nil,string...} The arguments
-- as parsed from the arguments table as key-value entries, plus positional
-- arguments as list entries.
-- @treturn[2] nil If the arguments passed are invalid.
-- @treturn[2] string An error string describing what was invalid, which can be
-- printed for the user.
function util.argparse(arguments, ...)
    expect(1, arguments, "table")
    expect.field(arguments, "", "table", "nil")
    local retval = {}
    local nextArg
    local params = arguments[""] or {}
    for i, arg in ipairs{...} do
        if nextArg then
            if arguments[nextArg] == "number" then
                retval[nextArg] = tonumber(arg)
                if not retval[nextArg] then return nil, "parameter passed to argument '" .. nextArg .. "' is not a number" end
            elseif arguments[nextArg] == "multiple" then
                retval[nextArg] = retval[nextArg] or {}
                retval[nextArg][#retval[nextArg]+1] = arg
            elseif arguments[nextArg] == "multiple number" then
                arg = tonumber(arg)
                if not arg then return nil, "parameter passed to argument '" .. nextArg .. "' is not a number" end
                retval[nextArg] = retval[nextArg] or {}
                retval[nextArg][#retval[nextArg]+1] = arg
            else retval[nextArg] = arg end
            nextArg = nil
        elseif arg:match "^%-+$" then
            local args = table.pack(...)
            local s = arg == "-" and #retval+1 or #retval
            for j = arg == "-" and 0 or 1, args.n-i do retval[s+j] = args[i+j] end
            break
        elseif arg:sub(1, 2) == "--" then
            local n = arg:sub(3)
            while type(arguments[n]) == "string" and arguments[n]:match "^@" do n = arguments[n]:sub(2) end
            if arguments[n] then nextArg = n
            elseif arguments[n] == false then retval[n] = true
            else return nil, "unrecognized argument '--" .. n .. "'" end
        elseif arg:sub(1, 1) == "-" then
            for n in arg:sub(2):gmatch "." do
                while type(arguments[n]) == "string" and arguments[n]:match "^@" do n = arguments[n]:sub(2) end
                if arguments[n] then
                    if nextArg then return nil, "no parameter passed to argument '" .. nextArg .. "'" end
                    nextArg = n
                elseif arguments[n] == false then retval[n] = true
                else return nil, "unrecognized argument '-" .. n .. "'" end
            end
        else
            if params.stopProcessingOnPositionalArgument then
                local args = table.pack(...)
                local s = #retval+1
                for j = 0, args.n-i do retval[s+j] = args[i+j] end
                break
            else retval[#retval+1] = arg end
        end
    end
    if nextArg then return nil, "no parameter passed to argument '" .. nextArg .. "'" end
    return retval
end

--- Starts a timer that will run for the specified number of seconds.
-- A timer event will be queued on completion.
-- @tparam number time The number of seconds to wait until sending the event
-- @treturn number The ID of the newly created timer
function util.timer(time)
    expect(1, time, "number")
    return os.startTimer(time)
end

--- Starts an alarm that will run until the specified time.
-- A timer event will be queued on completion.
-- @tparam number time The time to send the event at
-- @treturn number The ID of the newly created alarm
function util.alarm(time)
    expect(1, time, "number")
    return os.setAlarm(time)
end

--- Cancels a timer or alarm. This prevents the event from triggering.
-- @tparam number id The ID of the timer or alarm to cancel
function util.cancel(id)
    expect(1, id, "number")
    return os.cancelTimer(id) -- TODO: make alarms cancelable
end

--- Pauses the process for a certain amount of time.
-- @tparam number time The amount of time to wait for, in seconds
function util.sleep(time)
    expect(1, time, "number")
    local tm = os.startTimer(time)
    repeat local ev, param = os.pullEvent("timer")
    until ev == "timer" and param == tm
end

local eventParameterMap = {
    alarm = {"id"},
    char = {"character"},
    key = {"keycode", "isRepeat"},
    key_up = {"keycode"},
    mouse_click = {"button", "x", "y"},
    mouse_drag = {"button", "x", "y"},
    mouse_up = {"button", "x", "y"},
    mouse_scroll = {"direction", "x", "y"},
    paste = {"text"},
    redstone = {},
    term_resize = {},
    timer = {"id"},
    turtle_inventory = {}
}

--- Returns the next event from the event queue. This is intended to make it more
-- clear when events are being pulled, and also has the benefit of supporting
-- libsystem-craftos better.
-- @treturn string The event pulled
-- @treturn table The parameters for the event
function util.pullEvent()
    local ev = table.pack(coroutine.yield())
    local name = table.remove(ev, 1)
    local params = {}
    if eventParameterMap[name] then
        for i = 1, #eventParameterMap[name] do
            params[eventParameterMap[name][i]] = ev[i]
        end
        if name == "key" or name == "key_up" then
            params.keycode = keymap[params.keycode]
            params.ctrlHeld = keysHeld.ctrl
            params.altHeld = keysHeld.alt
            params.shiftHeld = keysHeld.shift
        end
    elseif #ev == 1 and type(ev) == "table" then params = ev[1]
    else params = ev end
    return name, params
end

--- Waits until an event of the specified type(s) occurs.
-- @tparam string ... The event names to filter for
-- @treturn string The event type that was matched
-- @treturn table The parameters for the event
function util.filterEvent(...)
    local types = {...}
    for i, v in ipairs(types) do expect(i, v, "string") end
    while true do
        local event, param = util.pullEvent()
        for _, v in ipairs(types) do if event == v then return event, param end end
    end
end

--- Queues an event to loop back to the process.
-- @tparam string event The event name to send
-- @tparam table param The parameter table to send with the event
util.queueEvent = os.queueEvent

--- Splits a string into components.
-- @tparam string str The string to split
-- @tparam[opt="%s"] string sep The delimiter match class to split by
-- @tparam[opt=false] boolean includeEmpty Whether to include empty matches
-- @treturn {string...} The components of the string
function util.split(str, sep, includeEmpty)
    expect(1, str, "string")
    expect(2, sep, "string", "nil")
    local t = {}
    if includeEmpty then
        local s, n = 1, str:find("[" .. sep .. "]")
        while s do
            t[#t+1] = str:sub(s, n and n - 1)
            s = n and n + 1
            n = str:find("[" .. sep .. "]", s)
        end
    else
        for match in str:gmatch("[^" .. (sep or "%s") .. "]+") do t[#t+1] = match end
    end
    return t
end

--- Copies a value recursively, including all its keys and values.
-- @tparam any value The value to copy
-- @treturn any A copy of the value, with all keys, values, and metatables duplicated.
function util.copy(value)
    if type(value) == "table" then
        local retval = setmetatable({}, deepcopy(getmetatable(value)))
        for k,v in pairs(value) do retval[deepcopy(k)] = deepcopy(v) end
        return retval
    else return value end
end

local eventListeners = {}

--- Adds an event listener to the listening module.
-- @tparam string event The event to listen for
-- @tparam function(string,table):boolean callback The function to call when
-- the event is queued. If the function returns a truthy value, processing for
-- the current event will stop. If the function throws an error, the loop will
-- stop.
function util.addEventListener(event, callback)
    expect(1, event, "string")
    expect(2, callback, "function")
    eventListeners[event] = eventListeners[event] or {}
    eventListeners[event][#eventListeners[event]+1] = callback
end

--- Removes an event listener from the listening module.
-- @tparam string event The event to listen for
-- @tparam function(string,table) callback The function to remove
function util.removeEventListener(event, callback)
    expect(1, event, "string")
    expect(2, callback, "function")
    if eventListeners[event] then
        for k, v in ipairs(eventListeners[event]) do
            if v == callback then
                table.remove(eventListeners[event], k)
                return
            end
        end
    end
end

--- Runs the event listening loop on the current thread, blocking forever.
-- @treturn string The error that caused the function to stop
function util.runEvents()
    while true do
        local event, param = coroutine.yield()
        if eventListeners[event] then
            for _, v in ipairs(eventListeners[event]) do
                local ok, res = pcall(v, event, param)
                if not ok then return res end
                if res then break end
            end
        end
    end
end

--- Returns the type of the parameter, with the ability to check the __name
-- metamethod for custom types.
-- @tparam any value The value to check
-- @treturn string The type of the value
function util.type(value)
    local t = type(value)
    if t == "table" then
        local mt = getmetatable(value)
        if mt and mt.__name then return mt.__name end
    end
    return t
end

local CRC32 = {[0xEDB88320] = {
    [0] = 0x00000000, 0x77073096, 0xee0e612c, 0x990951ba,
    0x076dc419, 0x706af48f, 0xe963a535, 0x9e6495a3,
    0x0edb8832, 0x79dcb8a4, 0xe0d5e91e, 0x97d2d988,
    0x09b64c2b, 0x7eb17cbd, 0xe7b82d07, 0x90bf1d91,
    0x1db71064, 0x6ab020f2, 0xf3b97148, 0x84be41de,
    0x1adad47d, 0x6ddde4eb, 0xf4d4b551, 0x83d385c7,
    0x136c9856, 0x646ba8c0, 0xfd62f97a, 0x8a65c9ec,
    0x14015c4f, 0x63066cd9, 0xfa0f3d63, 0x8d080df5,
    0x3b6e20c8, 0x4c69105e, 0xd56041e4, 0xa2677172,
    0x3c03e4d1, 0x4b04d447, 0xd20d85fd, 0xa50ab56b,
    0x35b5a8fa, 0x42b2986c, 0xdbbbc9d6, 0xacbcf940,
    0x32d86ce3, 0x45df5c75, 0xdcd60dcf, 0xabd13d59,
    0x26d930ac, 0x51de003a, 0xc8d75180, 0xbfd06116,
    0x21b4f4b5, 0x56b3c423, 0xcfba9599, 0xb8bda50f,
    0x2802b89e, 0x5f058808, 0xc60cd9b2, 0xb10be924,
    0x2f6f7c87, 0x58684c11, 0xc1611dab, 0xb6662d3d,
    0x76dc4190, 0x01db7106, 0x98d220bc, 0xefd5102a,
    0x71b18589, 0x06b6b51f, 0x9fbfe4a5, 0xe8b8d433,
    0x7807c9a2, 0x0f00f934, 0x9609a88e, 0xe10e9818,
    0x7f6a0dbb, 0x086d3d2d, 0x91646c97, 0xe6635c01,
    0x6b6b51f4, 0x1c6c6162, 0x856530d8, 0xf262004e,
    0x6c0695ed, 0x1b01a57b, 0x8208f4c1, 0xf50fc457,
    0x65b0d9c6, 0x12b7e950, 0x8bbeb8ea, 0xfcb9887c,
    0x62dd1ddf, 0x15da2d49, 0x8cd37cf3, 0xfbd44c65,
    0x4db26158, 0x3ab551ce, 0xa3bc0074, 0xd4bb30e2,
    0x4adfa541, 0x3dd895d7, 0xa4d1c46d, 0xd3d6f4fb,
    0x4369e96a, 0x346ed9fc, 0xad678846, 0xda60b8d0,
    0x44042d73, 0x33031de5, 0xaa0a4c5f, 0xdd0d7cc9,
    0x5005713c, 0x270241aa, 0xbe0b1010, 0xc90c2086,
    0x5768b525, 0x206f85b3, 0xb966d409, 0xce61e49f,
    0x5edef90e, 0x29d9c998, 0xb0d09822, 0xc7d7a8b4,
    0x59b33d17, 0x2eb40d81, 0xb7bd5c3b, 0xc0ba6cad,
    0xedb88320, 0x9abfb3b6, 0x03b6e20c, 0x74b1d29a,
    0xead54739, 0x9dd277af, 0x04db2615, 0x73dc1683,
    0xe3630b12, 0x94643b84, 0x0d6d6a3e, 0x7a6a5aa8,
    0xe40ecf0b, 0x9309ff9d, 0x0a00ae27, 0x7d079eb1,
    0xf00f9344, 0x8708a3d2, 0x1e01f268, 0x6906c2fe,
    0xf762575d, 0x806567cb, 0x196c3671, 0x6e6b06e7,
    0xfed41b76, 0x89d32be0, 0x10da7a5a, 0x67dd4acc,
    0xf9b9df6f, 0x8ebeeff9, 0x17b7be43, 0x60b08ed5,
    0xd6d6a3e8, 0xa1d1937e, 0x38d8c2c4, 0x4fdff252,
    0xd1bb67f1, 0xa6bc5767, 0x3fb506dd, 0x48b2364b,
    0xd80d2bda, 0xaf0a1b4c, 0x36034af6, 0x41047a60,
    0xdf60efc3, 0xa867df55, 0x316e8eef, 0x4669be79,
    0xcb61b38c, 0xbc66831a, 0x256fd2a0, 0x5268e236,
    0xcc0c7795, 0xbb0b4703, 0x220216b9, 0x5505262f,
    0xc5ba3bbe, 0xb2bd0b28, 0x2bb45a92, 0x5cb36a04,
    0xc2d7ffa7, 0xb5d0cf31, 0x2cd99e8b, 0x5bdeae1d,
    0x9b64c2b0, 0xec63f226, 0x756aa39c, 0x026d930a,
    0x9c0906a9, 0xeb0e363f, 0x72076785, 0x05005713,
    0x95bf4a82, 0xe2b87a14, 0x7bb12bae, 0x0cb61b38,
    0x92d28e9b, 0xe5d5be0d, 0x7cdcefb7, 0x0bdbdf21,
    0x86d3d2d4, 0xf1d4e242, 0x68ddb3f8, 0x1fda836e,
    0x81be16cd, 0xf6b9265b, 0x6fb077e1, 0x18b74777,
    0x88085ae6, 0xff0f6a70, 0x66063bca, 0x11010b5c,
    0x8f659eff, 0xf862ae69, 0x616bffd3, 0x166ccf45,
    0xa00ae278, 0xd70dd2ee, 0x4e048354, 0x3903b3c2,
    0xa7672661, 0xd06016f7, 0x4969474d, 0x3e6e77db,
    0xaed16a4a, 0xd9d65adc, 0x40df0b66, 0x37d83bf0,
    0xa9bcae53, 0xdebb9ec5, 0x47b2cf7f, 0x30b5ffe9,
    0xbdbdf21c, 0xcabac28a, 0x53b39330, 0x24b4a3a6,
    0xbad03605, 0xcdd70693, 0x54de5729, 0x23d967bf,
    0xb3667a2e, 0xc4614ab8, 0x5d681b02, 0x2a6f2b94,
    0xb40bbe37, 0xc30c8ea1, 0x5a05df1b, 0x2d02ef8d
}}

--- Calculates the CRC-32 checksum of the specified data.
-- @tparam string str The data to checksum
-- @tparam[opt=0xEDB88320] table|number polynomial The polynomial for the CRC, or the lookup table to use
-- @tparam[opt=0xFFFFFFFF] number crc The initial CRC value
-- @treturn number The calculated CRC checksum
function util.crc32(str, polynomial, crc)
    expect(1, str, "string")
    polynomial = expect(2, polynomial, "table", "number", "nil") or 0xEDB88320
    crc = expect(3, crc, "number", "nil") or 0xFFFFFFFF
    local crctab = type(polynomial) == "table" and polynomial or CRC32[polynomial]
    if not crctab then
        crctab = {}
        for i = 0, 255 do
            local r = i
            for _ = 1, 8 do
                if bit32.btest(r, 1) then r = bit32.bxor(bit32.rshift(r, 1), polynomial)
                else r = bit32.rshift(r, 1) end
            end
            crctab[i] = r
        end
        CRC32[polynomial] = crctab
    end
    for i = 1, #str do
        crc = bit32.bxor(crctab[bit32.band(bit32.bxor(str:byte(i), bit32.band(crc, 0xFF)))], bit32.rshift(crc, 8))
    end
    return bit32.bnot(crc)
end

return util