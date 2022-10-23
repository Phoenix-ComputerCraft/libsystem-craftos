--- The serialization module provides functions for serializing and deserializing
-- objects in multiple formats, as well as some miscellaneous encoding types.
--
-- @module system.serialization

local expect = require "expect"

local serialization = {base64 = {}, json = {}, lua = {}}

--- serialization.base64
-- @section serialization.base64

local b64str = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

--- Encodes a binary string into Base64.
-- @tparam string str The string to encode
-- @treturn string The string's representation in Base64
function serialization.base64.encode(str)
    expect(1, str, "string")
    local retval = ""
    for s in str:gmatch "..." do
        local n = s:byte(1) * 65536 + s:byte(2) * 256 + s:byte(3)
        local a, b, c, d = bit32.extract(n, 18, 6), bit32.extract(n, 12, 6), bit32.extract(n, 6, 6), bit32.extract(n, 0, 6)
        retval = retval .. b64str:sub(a+1, a+1) .. b64str:sub(b+1, b+1) .. b64str:sub(c+1, c+1) .. b64str:sub(d+1, d+1)
    end
    if #str % 3 == 1 then
        local n = str:byte(-1)
        local a, b = bit32.rshift(n, 2), bit32.lshift(bit32.band(n, 3), 4)
        retval = retval .. b64str:sub(a+1, a+1) .. b64str:sub(b+1, b+1) .. "=="
    elseif #str % 3 == 2 then
        local n = str:byte(-2) * 256 + str:byte(-1)
        local a, b, c, d = bit32.extract(n, 10, 6), bit32.extract(n, 4, 6), bit32.lshift(bit32.extract(n, 0, 4), 2)
        retval = retval .. b64str:sub(a+1, a+1) .. b64str:sub(b+1, b+1) .. b64str:sub(c+1, c+1) .. "="
    end
    return retval
end

--- Decodes a Base64 string to binary.
-- @tparam string str The Base64 to decode
-- @treturn string The decoded data
function serialization.base64.decode(str)
    expect(1, str, "string")
    local retval = ""
    for s in str:gmatch "...." do
        if s:sub(3, 4) == '==' then
            retval = retval .. string.char(bit32.bor(bit32.lshift(b64str:find(s:sub(1, 1)) - 1, 2), bit32.rshift(b64str:find(s:sub(2, 2)) - 1, 4)))
        elseif s:sub(4, 4) == '=' then
            local n = (b64str:find(s:sub(1, 1))-1) * 4096 + (b64str:find(s:sub(2, 2))-1) * 64 + (b64str:find(s:sub(3, 3))-1)
            retval = retval .. string.char(bit32.extract(n, 10, 8)) .. string.char(bit32.extract(n, 2, 8))
        else
            local n = (b64str:find(s:sub(1, 1))-1) * 262144 + (b64str:find(s:sub(2, 2))-1) * 4096 + (b64str:find(s:sub(3, 3))-1) * 64 + (b64str:find(s:sub(4, 4))-1)
            retval = retval .. string.char(bit32.extract(n, 16, 8)) .. string.char(bit32.extract(n, 8, 8)) .. string.char(bit32.extract(n, 0, 8))
        end
    end
    return retval
end

--- serialization.json
-- @section serialization.json

--
-- json.lua
--
-- Copyright (c) 2020 rxi
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of
-- this software and associated documentation files (the "Software"), to deal in
-- the Software without restriction, including without limitation the rights to
-- use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
-- of the Software, and to permit persons to whom the Software is furnished to do
-- so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.
--

local function rotable(str)
    return setmetatable({}, {__newindex = function() error("attempt to modify read-only table") end, __tostring = function() return str end})
end

serialization.json.null = rotable "null"
serialization.json.emptyArray = rotable "[]"

-------------------------------------------------------------------------------
-- Encode
-------------------------------------------------------------------------------

local encode

local escape_char_map = {
    [ "\\" ] = "\\",
    [ "\"" ] = "\"",
    [ "\b" ] = "b",
    [ "\f" ] = "f",
    [ "\n" ] = "n",
    [ "\r" ] = "r",
    [ "\t" ] = "t",
}

local escape_char_map_inv = { [ "/" ] = "/" }
for k, v in pairs(escape_char_map) do
    escape_char_map_inv[v] = k
end


local function escape_char(c)
    return "\\" .. (escape_char_map[c] or string.format("u%04x", c:byte()))
end


local function encode_nil(val)
    return "null"
end


local function encode_table(val, stack)
    local res = {}
    stack = stack or {}

    if val == serialization.json.null then return "null"
    elseif val == serialization.json.emptyArray then return "[]" end

    -- Circular reference?
    if stack[val] then error("circular reference") end

    stack[val] = true

    if rawget(val, 1) ~= nil or next(val) == nil then
        -- Treat as array -- check keys are valid and it is not sparse
        local n = 0
        for k in pairs(val) do
            if type(k) ~= "number" then
                error("invalid table: mixed or invalid key types")
            end
            n = n + 1
        end
        if n ~= #val then
            error("invalid table: sparse array")
        end
        -- Encode
        for i, v in ipairs(val) do
            table.insert(res, encode(v, stack))
        end
        stack[val] = nil
        return "[" .. table.concat(res, ",") .. "]"

    else
        -- Treat as an object
        for k, v in pairs(val) do
            if type(k) ~= "string" then
                error("invalid table: mixed or invalid key types")
            end
            table.insert(res, encode(k, stack) .. ":" .. encode(v, stack))
        end
        stack[val] = nil
        return "{" .. table.concat(res, ",") .. "}"
    end
end


local function encode_string(val)
    return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
end


local function encode_number(val)
    -- Check for NaN, -inf and inf
    if val ~= val or val <= -math.huge or val >= math.huge then
        error("unexpected number value '" .. tostring(val) .. "'")
    end
    return string.format("%.14g", val)
end


local type_func_map = {
    [ "nil"     ] = encode_nil,
    [ "table"   ] = encode_table,
    [ "string"  ] = encode_string,
    [ "number"  ] = encode_number,
    [ "boolean" ] = tostring,
}


encode = function(val, stack)
    local t = type(val)
    local f = type_func_map[t]
    if f then
        return f(val, stack)
    end
    error("unexpected type '" .. t .. "'")
end


--- Serializes an arbitrary Lua object into a JSON string.
-- @tparam any val The value to encode
-- @treturn string The JSON representation of the object
function serialization.json.encode(val)
    return ( encode(val) )
end


-------------------------------------------------------------------------------
-- Decode
-------------------------------------------------------------------------------

local parse

local function create_set(...)
    local res = {}
    for i = 1, select("#", ...) do
        res[ select(i, ...) ] = true
    end
    return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
    [ "true"  ] = true,
    [ "false" ] = false,
    [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
    for i = idx, #str do
        if set[str:sub(i, i)] ~= negate then
            return i
        end
    end
    return #str + 1
end


local function decode_error(str, idx, msg)
    local line_count = 1
    local col_count = 1
    for i = 1, idx - 1 do
        col_count = col_count + 1
        if str:sub(i, i) == "\n" then
            line_count = line_count + 1
            col_count = 1
        end
    end
    error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
    -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
    local f = math.floor
    if n <= 0x7f then
        return string.char(n)
    elseif n <= 0x7ff then
        return string.char(f(n / 64) + 192, n % 64 + 128)
    elseif n <= 0xffff then
        return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
    elseif n <= 0x10ffff then
        return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                                             f(n % 4096 / 64) + 128, n % 64 + 128)
    end
    error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
    local n1 = tonumber( s:sub(1, 4),  16 )
    local n2 = tonumber( s:sub(7, 10), 16 )
     -- Surrogate pair?
    if n2 then
        return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
    else
        return codepoint_to_utf8(n1)
    end
end


local function parse_string(str, i)
    local res = ""
    local j = i + 1
    local k = j

    while j <= #str do
        local x = str:byte(j)

        if x < 32 then
            decode_error(str, j, "control character in string")

        elseif x == 92 then -- `\`: Escape
            res = res .. str:sub(k, j - 1)
            j = j + 1
            local c = str:sub(j, j)
            if c == "u" then
                local hex = str:match("^[dD][89aAbB]%x%x\\u%x%x%x%x", j + 1)
                                 or str:match("^%x%x%x%x", j + 1)
                                 or decode_error(str, j - 1, "invalid unicode escape in string")
                res = res .. parse_unicode_escape(hex)
                j = j + #hex
            else
                if not escape_chars[c] then
                    decode_error(str, j - 1, "invalid escape char '" .. c .. "' in string")
                end
                res = res .. escape_char_map_inv[c]
            end
            k = j + 1

        elseif x == 34 then -- `"`: End of string
            res = res .. str:sub(k, j - 1)
            return res, j + 1
        end

        j = j + 1
    end

    decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
    local x = next_char(str, i, delim_chars)
    local s = str:sub(i, x - 1)
    local n = tonumber(s)
    if not n then
        decode_error(str, i, "invalid number '" .. s .. "'")
    end
    return n, x
end


local function parse_literal(str, i)
    local x = next_char(str, i, delim_chars)
    local word = str:sub(i, x - 1)
    if not literals[word] then
        decode_error(str, i, "invalid literal '" .. word .. "'")
    end
    return literal_map[word], x
end


local function parse_array(str, i)
    local res = {}
    local n = 1
    i = i + 1
    while 1 do
        local x
        i = next_char(str, i, space_chars, true)
        -- Empty / end of array?
        if str:sub(i, i) == "]" then
            i = i + 1
            break
        end
        -- Read token
        x, i = parse(str, i)
        res[n] = x
        n = n + 1
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "]" then break end
        if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
    end
    return res, i
end


local function parse_object(str, i)
    local res = {}
    i = i + 1
    while 1 do
        local key, val
        i = next_char(str, i, space_chars, true)
        -- Empty / end of object?
        if str:sub(i, i) == "}" then
            i = i + 1
            break
        end
        -- Read key
        if str:sub(i, i) ~= '"' then
            decode_error(str, i, "expected string for key")
        end
        key, i = parse(str, i)
        -- Read ':' delimiter
        i = next_char(str, i, space_chars, true)
        if str:sub(i, i) ~= ":" then
            decode_error(str, i, "expected ':' after key")
        end
        i = next_char(str, i + 1, space_chars, true)
        -- Read value
        val, i = parse(str, i)
        -- Set
        res[key] = val
        -- Next token
        i = next_char(str, i, space_chars, true)
        local chr = str:sub(i, i)
        i = i + 1
        if chr == "}" then break end
        if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
    end
    return res, i
end


local char_func_map = {
    [ '"' ] = parse_string,
    [ "0" ] = parse_number,
    [ "1" ] = parse_number,
    [ "2" ] = parse_number,
    [ "3" ] = parse_number,
    [ "4" ] = parse_number,
    [ "5" ] = parse_number,
    [ "6" ] = parse_number,
    [ "7" ] = parse_number,
    [ "8" ] = parse_number,
    [ "9" ] = parse_number,
    [ "-" ] = parse_number,
    [ "t" ] = parse_literal,
    [ "f" ] = parse_literal,
    [ "n" ] = parse_literal,
    [ "[" ] = parse_array,
    [ "{" ] = parse_object,
}


parse = function(str, idx)
    local chr = str:sub(idx, idx)
    local f = char_func_map[chr]
    if f then
        return f(str, idx)
    end
    decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


--- Parses a JSON string and returns a Lua value represented by the string.
-- @tparam string str The JSON string to decode
-- @treturn any The Lua value from the JSON
function serialization.json.decode(str)
    expect(1, str, "string")
    local res, idx = parse(str, next_char(str, 1, space_chars, true))
    idx = next_char(str, idx, space_chars, true)
    if idx <= #str then
        decode_error(str, idx, "trailing garbage")
    end
    return res
end

--- Saves a Lua value to a JSON file.
-- @tparam any val The value to save
-- @tparam string path The path to the file to save
function serialization.json.save(val, path)
    expect(2, path, "string")
    local file = assert(io.open(path, "w"))
    file:write(serialization.json.encode(val))
    file:close()
end

--- Loads a JSON file into a Lua value.
-- @tparam string path The path to the file to load
-- @treturn any The loaded value
function serialization.json.load(path)
    expect(1, path, "string")
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    return serialization.json.decode(data)
end

--- serialization.lua
-- @section serialization.lua

local keywords = {
    ["and"] = true,
    ["break"] = true,
    ["do"] = true,
    ["else"] = true,
    ["elseif"] = true,
    ["end"] = true,
    ["false"] = true,
    ["for"] = true,
    ["function"] = true,
    ["goto"] = true,
    ["if"] = true,
    ["in"] = true,
    ["local"] = true,
    ["nil"] = true,
    ["not"] = true,
    ["or"] = true,
    ["repeat"] = true,
    ["return"] = true,
    ["then"] = true,
    ["true"] = true,
    ["until"] = true,
    ["while"] = true,
}

local function lua_serialize(val, stack, opts, level)
    if stack[val] then error("Cannot serialize recursive value", 0) end
    local tt = type(val)
    if tt == "table" then
        if not next(val) then return "{}" end
        stack[val] = true
        local res = opts.minified and "{" or "{\n"
        local num = {}
        for i, v in ipairs(val) do
            if not opts.minified then res = res .. ("    "):rep(level) end
            num[i] = true
            res = res .. lua_serialize(v, stack, opts, level + 1) .. (opts.minified and "," or ",\n")
        end
        for k, v in pairs(val) do if not num[k] then
            if not opts.minified then res = res .. ("    "):rep(level) end
            if type(k) == "string" and not keywords[k] then res = res .. k
            else res = res .. "[" .. lua_serialize(k, stack, opts, level + 1) .. "]" end
            res = res .. (opts.minified and "=" or " = ") .. lua_serialize(v, stack, opts, level + 1) .. (opts.minified and "," or ",\n")
        end end
        if opts.minified then res = res:gsub(",$", "")
        else res = res .. ("    "):rep(level - 1) end
        stack[val] = nil
        return res .. "}"
    elseif tt == "function" and opts.allow_functions then
        local ok, dump = pcall(string.dump, val)
        if not ok then error("Cannot serialize C function", 0) end
        dump = ("%q"):format(dump):gsub("[%z\1-\31\127-\255]", function(c) return '\\' .. ("%03d"):format(string.byte(c)) end)
        local ups = {n = 0}
        stack[val] = true
        for i = 1, math.huge do
            local ok, name, value = pcall(debug.getupvalue, val, i)
            if not ok or not name then break end
            ups[i] = value
            ups.n = i
        end
        local name = "=(serialized function)"
        local ok, info = pcall(debug.getinfo, val, "S")
        if ok then name = info.source or name end
        local v = ("__function(%s,%q,%s)"):format(dump, name, lua_serialize(ups, stack, opts, level + 1))
        stack[val] = nil
        return v
    elseif tt == "nil" or tt == "number" or tt == "boolean" or tt == "string" then
        return ("%q"):format(val):gsub("[%z\1-\31\127-\255]", function(c) return '\\' .. ("%03d"):format(string.byte(c)) end)
    else
        error("Cannot serialize type " .. tt, 0)
    end
end

--- Serializes an arbitrary Lua object into a serialized Lua string.
-- @tparam any val The value to encode
-- @tparam[opt] {minified=boolean,allow_functions=boolean} opts Any options to specify while encoding
-- @treturn string The serialized Lua representation of the object
function serialization.lua.encode(val, opts)
    expect(2, opts, "table", "nil")
    return lua_serialize(val, {}, opts or {}, 1)
end

--- Parses a serialized Lua string and returns a Lua value represented by the string.
-- @tparam string str The serialized Lua string to decode
-- @tparam[opt] {allow_functions=boolean} opts Any options to specify while decoding
-- @treturn any The Lua value from the serialized Lua
function serialization.lua.decode(str, opts)
    opts = expect(2, opts, "table", "nil") or {}
    local env = {}
    local fns = {}
    if opts.allow_functions then function env.__function(code, name, ups)
        expect(1, code, "string")
        expect(3, ups, "table")
        expect.field(ups, "n", "number")
        local fn = assert(load(code, name, "b", {}))
        for i = 1, ups.n do debug.setupvalue(fn, i, ups[i]) end
        fns[#fns+1] = fn
        return fn
    end end
    local res = assert(load("return " .. str, "=unserialize", "t", env))()
    for _, v in ipairs(fns) do setfenv(v, _G) end
    return res
end

--- Saves a Lua value to a serialized Lua file.
-- @tparam any val The value to save
-- @tparam string path The path to the file to save
-- @tparam[opt] {minified=boolean,allow_functions=boolean} opts Any options to specify while encoding
function serialization.lua.save(val, path, opts)
    expect(2, path, "string")
    local file = assert(io.open(path, "w"))
    file:write(serialization.lua.encode(val, opts))
    file:close()
end

--- Loads a serialized Lua file into a Lua value.
-- @tparam string path The path to the file to load
-- @tparam[opt] {allow_functions=boolean} opts Any options to specify while decoding
-- @treturn any The loaded value
function serialization.lua.load(path, opts)
    expect(1, path, "string")
    local file = assert(io.open(path, "r"))
    local data = file:read("*a")
    file:close()
    return serialization.lua.decode(data, opts)
end

return serialization