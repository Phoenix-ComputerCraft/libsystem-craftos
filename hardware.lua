--- The hardware module implements functions for operating on peripherals and
-- other hardware devices.
--
-- @module system.hardware

local expect = require "expect"

local hardware = {}

--- Wraps a device into an indexable object, allowing accessing properties and
-- methods of the device by indexing the table.
-- If an object is passed, this simply re-wraps the device in a new object.
-- @tparam string device The device specifier or object to wrap
-- @treturn device The wrapped device
-- @usage Wrap a device, use a property, and call a method:
--     
--     local computer = hardware.wrap("/")
--     print(computer.isOn)
--     computer.label = "My Computer"
--     computer:reboot()
function hardware.wrap(device)
    expect(1, device, "string", "device", "devicetree")
    if type(device) ~= "string" then device = getmetatable(device).uuid end
    local methods = peripheral.getMethods(device)
    if not methods then return nil end
    local retval = {}
    for _, v in ipairs(methods) do retval[v] = function(self, ...) return peripheral.call(device, v, ...) end end
    return setmetatable(retval, {
        __name = "device",
        uuid = device,
        __tostring = function(self)
            return "wrapped device: " .. device
        end
    })
end

--- Returns a list of wrapped devices that implement the specified type.
-- @tparam string type The type to search for
-- @treturn device... The devices found, or `nil` if none were found
-- @see wrap For wrapping a single device by path
function hardware.find(type)
    expect(1, type, "string")
    local retval = {}
    for i, v in ipairs{peripheral.find(type)} do retval[i] = hardware.wrap(peripheral.getName(v)) end
    return table.unpack(retval)
end

--- Returns a list of device paths that match the device specifier or object.
-- If an absolute path is specified, this returns the same path back.
-- If a device object is specified, this returns the path to the device.
-- @tparam string|device device The device specifier or object to read
-- @treturn string... The paths that match the specifier or device object.
function hardware.path(device)
    expect(1, device, "string", "device", "devicetree")
    if type(device) ~= "string" then device = getmetatable(device).uuid end
    return peripheral.isPresent(device) and device or nil
end

--- Returns whether the device implements the specified type.
-- @tparam string|device device The device specifier or object to query
-- @tparam string type The type to check for
-- @treturn boolean Whether the device implements the type
function hardware.hasType(device, type)
    expect(1, device, "string", "device", "devicetree")
    if type(device) ~= "string" then device = getmetatable(device).uuid end
    if not peripheral.isPresent(device) then error("No such device", 2) end
    return peripheral.hasType(device, type)
end

--- Returns a table of information about the specified device.
-- @tparam string|device device The device specifier or object to query
-- @treturn HWInfo|nil The hardware info table, or `nil` if no device was found
function hardware.info(device)
    expect(1, device, "string", "device", "devicetree")
    if type(device) ~= "string" then device = getmetatable(device).uuid end
    if not peripheral.isPresent(device) then return nil end
    local retval = {
        id = device,
        uuid = device,
        types = {},
        metadata = {}
    }
    for _, v in ipairs{peripheral.getType(device)} do retval.types[v] = v end
    return retval
end

--- Returns a list of methods implemented by this device.
-- @tparam string|device device The device specifier or object to query
-- @treturn {string...} The methods available to call on this device
function hardware.methods(device)
    expect(1, device, "string", "device", "devicetree")
    if type(device) == "string" then return peripheral.getMethods(device)
    else return peripheral.getMethods(getmetatable(device).uuid) end
end

--- Returns a list of properties implemented by this device.
-- @tparam string|device device The device specifier or object to query
-- @treturn {string...} The properties available on this device
function hardware.properties(device)
    expect(1, device, "string", "device", "devicetree")
    return {}
end

--- Returns a list of children of this device.
-- @tparam string|device device The device specifier or object to query
-- @treturn {string...} The names of children of the device
function hardware.children(device)
    expect(1, device, "string", "device", "devicetree")
    if device == "/" or device == "" then return peripheral.getNames() end
    return {}
end

--- Calls a method on a device.
-- @tparam string|device device The device specifier or object to call on
-- @tparam string method The method to call
-- @tparam any ... Any arguments to pass to the method
-- @treturn any... The return values from the method
function hardware.call(device, method, ...)
    expect(1, device, "string", "device", "devicetree")
    expect(2, method, "string")
    if type(device) == "string" then return peripheral.call(device, method, ...)
    else return peripheral.call(getmetatable(device).uuid, method, ...) end
end

--- Toggles whether this process should receive events from the device.
-- @tparam string|device device The device specifier or object to modify
-- @tparam[opt=true] boolean state Whether to allow events
function hardware.listen(device, state)
    expect(1, device, "string", "device", "devicetree")
    expect(2, state, "boolean", "nil")
    -- nop
end

--- Locks the device from being called on or listened to by other processes.
-- @tparam string|device device The device specifier or object to modify
-- @tparam[opt=true] boolean wait Whether to wait for the device to unlock if
-- it's currently locked by another process
-- @treturn boolean Whether the current process now owns the lock
-- @see unlock To unlock the device afterward
function hardware.lock(device, wait)
    expect(1, device, "string", "device", "devicetree")
    expect(2, wait, "boolean", "nil")
    -- nop
end

--- Unlocks the device after previously locking it.
-- @tparam string|device device The device specifier or object to modify
-- @see lock To lock the device
function hardware.unlock(device)
    expect(1, device, "string", "device", "devicetree")
    -- nop
end

--- A table that allows accessing device object pointers in a tree. This is
-- simply syntax sugar for real paths.
-- @usage To access the left redstone signal
--     
--     local device = hardware.wrap(hardware.tree.redstone.left)
--     print(device.input)
hardware.tree = setmetatable({}, {__index = function(_, idx) return setmetatable({}, {__name = "devicetree", uuid = idx, __newindex = function() end}) end, __newindex = function() end})

return hardware