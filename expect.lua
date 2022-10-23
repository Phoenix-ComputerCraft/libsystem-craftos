--- The expect module provides error checking functions for other libraries.
--
-- @module system.expect

local expect = {}

local native_types = {["nil"] = true, boolean = true, number = true, string = true, table = true, ["function"] = true, userdata = true, thread = true}

local function check_type(msg, value, ...)
    local vt = type(value)
    local vmt
    if vt == "table" then
        local mt = getmetatable(value)
        if mt then vmt = mt.__name end
    end
    local args = table.pack(...)
    for _, typ in ipairs(args) do
        if native_types[typ] then if vt == typ then return value end
        elseif vmt == typ then return value end
    end
    local info = debug.getinfo(2, "n")
    if info and info.name and info.name ~= "" then msg = msg .. " to '" .. info.name .. "'" end
    local types
    if args.n == 1 then types = args[1]
    elseif args.n == 2 then types = args[1] .. " or " .. args[2]
    else types = table.concat(args, ", ", 1, args.n - 1) .. ", or " .. args[args.n] end
    error(msg .. " (expected " .. types .. ", got " .. vt .. ")", 3)
end

--- Check that a numbered argument matches the expected type(s). If the type
-- doesn't match, throw an error.
-- This function supports custom types by checking the __name metaproperty.
-- @tparam number index The index of the argument to check
-- @tparam any value The value to check
-- @tparam string ... The types to check for
-- @treturn any `value`
function expect.expect(index, value, ...)
    return check_type("bad argument #" .. index, value, ...)
end

--- Check that a key in a table matches the expected type(s). If the type
-- doesn't match, throw an error.
-- This function supports custom types by checking the __name metaproperty.
-- @tparam any tbl The table (or other indexable value) to search through
-- @tparam any key The key of the table to check
-- @tparam string ... The types to check for
-- @treturn any The indexed value in the table
function expect.field(tbl, key, ...)
    local ok, str = pcall(string.format, "%q", key)
    if not ok then str = tostring(key) end
    return check_type("bad field " .. str, tbl[key], ...)
end

--- Check that a number is between the specified minimum and maximum values. If
-- the number is out of bounds, throw an error.
-- @tparam number num The number to check
-- @tparam[opt=-math.huge] number min The minimum value of the number (inclusive)
-- @tparam[opt=math.huge] number max The maximum value of the number (inclusive)
-- @treturn number `num`
function expect.range(num, min, max)
    expect.expect(1, num, "number")
    expect.expect(2, min, "number", "nil")
    expect.expect(3, max, "number", "nil")
    if max and min and max < min then error("bad argument #3 (min must be less than or equal to max)", 2) end
    if num ~= num or num < (min or -math.huge) or num > (max or math.huge) then error(("number outside of range (expected %s to be within %s and %s)"):format(num, min or -math.huge, max or math.huge), 3) end
    return num
end

return setmetatable(expect, {__call = function(_, ...) return expect.expect(...) end})