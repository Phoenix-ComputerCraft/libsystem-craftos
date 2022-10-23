--- The network module implements functions for making and hosting connections
-- with local and Internet-connected computers, as well as managing the network
-- stack configuration.
--
-- @module system.network

local expect = require "expect"

local network = {}
local nextHandleID = 0

local function makeHTTPHandle(handle)
    local closed = false
    local obj = setmetatable({id = nextHandleID}, {__name = "socket"})
    nextHandleID = nextHandleID + 1
    function obj:status()
        return closed and "closed" or "open"
    end
    function obj:read(mode, ...)
        if closed then error("attempt to read from a closed handle", 2) end
        mode = mode or "*l"
        if type(mode) ~= "string" and type(mode) ~= "number" then error("bad argument (expected string or number, got " .. type(mode) .. ")", 2) end
        mode = mode:gsub("^%*", "")
        if mode == "a" then
            if select("#", ...) > 0 then return handle.readAll(), self:read(...)
            else return handle.readAll() end
        elseif mode == "l" then
            if select("#", ...) > 0 then return handle.readLine(false), self:read(...)
            else return handle.readLine(false) end
        elseif mode == "L" then
            if select("#", ...) > 0 then return handle.readLine(true), self:read(...)
            else return handle.readLine(true) end
        elseif mode == "n" then
            local str
            repeat
                str = handle.read(1)
                if not str then return nil end
            until tonumber(str)
            while true do
                local c = handle.read(1)
                if not c or not c:match "%d" then break end
                str = str .. c
            end
            if select("#", ...) > 0 then return tonumber(str), self:read(...)
            else return tonumber(str) end
        elseif type(mode) == "number" then
            if select("#", ...) > 0 then return handle.read(mode), self:read(...)
            else return handle.read(mode) end
        else error("bad argument (invalid mode '" .. mode .. "')", 2) end
    end
    function obj:write()
        error("attempt to write to a " .. (closed and "closed" or "open") .. " handle", 2)
    end
    function obj:close()
        if closed then error("attempt to close a closed handle", 2) end
        handle.close()
        closed = true
    end
    function obj:responseHeaders()
        if closed then error("attempt to read from a closed handle", 2) end
        return handle.getResponseHeaders()
    end
    function obj:responseCode()
        if closed then error("attempt to read from a closed handle", 2) end
        return handle.getResponseCode()
    end
    return obj
end

--- Creates a new connection to a remote server.
-- @tparam string|table options The URI to connect with, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn Handle A handle to the connection
function network.connect(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then expect.field(options, "url", "string")
    else options = {url = options} end
    if options.url:match "^wss?://" then
        expect.field(options, "encoding", "string", "nil")
        expect.field(options, "headers", "table", "nil")
        local info = {process = process, id = nextHandleID, buffer = ""}
        local obj = setmetatable({id = nextHandleID}, {__name = "socket"})
        nextHandleID = nextHandleID + 1
        function obj:status()
            return info.status, info.error
        end
        function obj:read(mode, ...)
            if info.status ~= "open" then error("attempt to read from a " .. info.status .. " handle", 2) end
            mode = mode or "*l"
            if type(mode) ~= "string" and type(mode) ~= "number" then error("bad argument (expected string or number, got " .. type(mode) .. ")", 2) end
            if info.buffer == "" then
                info.buffer = info.handle.receive()
                if not info.buffer then
                    info.status = "closed"
                    return nil
                end
            end
            mode = mode:gsub("^%*", "")
            if mode == "a" then
                local str = info.buffer
                info.buffer = ""
                return str
            elseif mode == "l" then
                local str, pos = info.buffer:match "^([^\n]*)\n?()"
                if str then
                    info.buffer = info.buffer:sub(pos)
                    if select("#", ...) > 0 then return str, self:read(...)
                    else return str end
                else return nil end
            elseif mode == "L" then
                local str, pos = info.buffer:match "^([^\n]*\n?)()"
                if str then
                    info.buffer = info.buffer:sub(pos)
                    if select("#", ...) > 0 then return str, self:read(...)
                    else return str end
                else return nil end
            elseif mode == "n" then
                local str, pos = info.buffer:match "(%d+)()"
                if str then
                    info.buffer = info.buffer:sub(pos)
                    if select("#", ...) > 0 then return tonumber(str), self:read(...)
                    else return tonumber(str) end
                else return nil end
            elseif type(mode) == "number" then
                local str = info.buffer:sub(1, mode)
                info.buffer = info.buffer:sub(mode + 1)
                if select("#", ...) > 0 then return str, self:read(...)
                else return str end
            else error("bad argument (invalid mode '" .. mode .. "')", 2) end
        end
        function obj:write(data, ...)
            if info.status ~= "open" then error("attempt to write to a " .. info.status .. " handle", 2) end
            info.handle.send(tostring(data), options.encoding == "binary")
            if select("#", ...) > 0 then return self:write(...) end
        end
        function obj:close()
            if info.status ~= "open" then error("attempt to close a " .. info.status .. " handle", 2) end
            info.handle.close()
            info.status = "closed"
        end
        local url = options.url .. "#" .. info.id
        local ok, err = http.websocket(url, options.headers)
        if ok then info.status = "open"
        else return nil, err end
        return obj
    elseif options.url:match "^https?://" then
        expect.field(options, "encoding", "string", "nil")
        expect.field(options, "headers", "table", "nil")
        expect.field(options, "method", "string", "nil")
        expect.field(options, "redirect", "boolean", "nil")
        local info = {status = "ready", id = nextHandleID}
        local obj = setmetatable({id = nextHandleID}, {__name = "socket"})
        nextHandleID = nextHandleID + 1
        function obj:status()
            return info.status, info.error
        end
        function obj:read(mode, ...)
            if info.status ~= "open" then error("attempt to read from a " .. info.status .. " handle", 2) end
            mode = mode or "*l"
            if type(mode) ~= "string" and type(mode) ~= "number" then error("bad argument (expected string or number, got " .. type(mode) .. ")", 2) end
            mode = mode:gsub("^%*", "")
            if mode == "a" then
                if select("#", ...) > 0 then return info.handle.readAll(), self:read(...)
                else return info.handle.readAll() end
            elseif mode == "l" then
                if select("#", ...) > 0 then return info.handle.readLine(false), self:read(...)
                else return info.handle.readLine(false) end
            elseif mode == "L" then
                if select("#", ...) > 0 then return info.handle.readLine(true), self:read(...)
                else return info.handle.readLine(true) end
            elseif mode == "n" then
                local str
                repeat
                    str = info.handle.read(1)
                    if not str then return nil end
                until tonumber(str)
                while true do
                    local c = info.handle.read(1)
                    if not c or not c:match "%d" then break end
                    str = str .. c
                end
                if select("#", ...) > 0 then return tonumber(str), self:read(...)
                else return tonumber(str) end
            elseif type(mode) == "number" then
                if select("#", ...) > 0 then return info.handle.read(mode), self:read(...)
                else return info.handle.read(mode) end
            else error("bad argument (invalid mode '" .. mode .. "')", 2) end
        end
        function obj:write(...)
            if info.status ~= "ready" then error("attempt to write to a " .. info.status .. " handle", 2) end
            local data
            if select("#", ...) > 0 then
                data = ""
                for _, v in ipairs{...} do data = data .. tostring(v) end
            end
            local url = options.url .. "#" .. info.id
            local handle, err, errh = http.get{url = url, body = data, headers = options.headers, binary = options.encoding == "binary" or options.encoding == nil, method = options.method, redirect = options.redirect}
            if not handle then
                if errh then handle = errh
                else info.status, info.error = "error", err end
            end
            if handle then info.handle, info.status = handle, "open" end
        end
        function obj:close()
            if info.status ~= "open" then error("attempt to close a " .. info.status .. " handle", 2) end
            info.handle.close()
            info.status = "closed"
        end
        function obj:responseHeaders()
            if info.status ~= "open" then error("attempt to read from a " .. info.status .. " handle", 2) end
            return info.handle.getResponseHeaders()
        end
        function obj:responseCode()
            if info.status ~= "open" then error("attempt to read from a " .. info.status .. " handle", 2) end
            return info.handle.getResponseCode()
        end
        return obj
    else error("Unknown scheme", 2) end
end

--- Connects to an HTTP(S) server, sends a GET request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.get(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    elseif not options:match("^https?://") then error("Invalid scheme", 2) end
    local handle, err, errh
    if type(options) == "string" then handle, err, errh = http.get(options, nil, true)
    else handle, err, errh = http.get{
        url = options.url,
        binary = options.encoding == "binary" or options.encoding == nil,
        headers = options.headers,
        method = options.method,
        redirect = options.redirect
    } end
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    return makeHTTPHandle(handle)
end

--- Connects to an HTTP(S) server, sends a GET request, waits for a response,
-- and returns the data received after closing the connection.
-- @tparam string url The URL to connect to
-- @tparam[opt] table headers Any headers to send in the request
-- @treturn[1] string The response data sent from the server
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.getData(url, headers)
    expect(1, url, "string")
    expect(2, headers, "table", "nil")
    if not url:match("^https?://") then error("Invalid scheme", 2) end
    local handle, err, errh = http.get(url, headers, true)
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    local data = handle.readAll()
    handle.close()
    return data
end

--- Connects to an HTTP(S) server, sends a HEAD request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.head(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "HEAD"
    local handle, err, errh = http.get{
        url = options.url,
        binary = options.encoding == "binary" or options.encoding == nil,
        headers = options.headers,
        method = options.method,
        redirect = options.redirect
    }
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    return makeHTTPHandle(handle)
end

--- Connects to an HTTP(S) server, sends an OPTIONS request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.options(options)
    expect(1, options, "table", "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "OPTIONS"
    local handle, err, errh = http.get{
        url = options.url,
        binary = options.encoding == "binary" or options.encoding == nil,
        headers = options.headers,
        method = options.method,
        redirect = options.redirect
    }
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    return makeHTTPHandle(handle)
end

--- Connects to an HTTP(S) server, sends a POST request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @tparam string data The data to send to the server
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.post(options, data)
    expect(1, options, "table", "string")
    expect(2, data, "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "POST"
    local handle, err, errh = http.get{
        url = options.url,
        body = data,
        binary = options.encoding == "binary" or options.encoding == nil,
        headers = options.headers,
        method = options.method,
        redirect = options.redirect
    }
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    return makeHTTPHandle(handle)
end

--- Connects to an HTTP(S) server, sends a PUT request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @tparam string data The data to send to the server
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.put(options, data)
    expect(1, options, "table", "string")
    expect(2, data, "string")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "PUT"
    local handle, err, errh = http.get{
        url = options.url,
        body = data,
        binary = options.encoding == "binary" or options.encoding == nil,
        headers = options.headers,
        method = options.method,
        redirect = options.redirect
    }
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    return makeHTTPHandle(handle)
end

--- Connects to an HTTP(S) server, sends a DELETE request and waits for a response.
-- @tparam string|table options The URL to connect to, or a table of options
-- (see the connect syscall docs for more information)
-- @tparam[opt] string data The data to send to the server, if required
-- @treturn[1] Handle The handle to the response data
-- @treturn[2] nil If the connection failed
-- @treturn[2] string An error describing why the connection failed
function network.delete(options, data)
    expect(1, options, "table", "string")
    expect(2, data, "string", "nil")
    if type(options) == "table" then
        expect.field(options, "url", "string")
        if not options.url:match("^https?://") then error("Invalid scheme", 2) end
    else
        if not options:match("^https?://") then error("Invalid scheme", 2) end
        options = {url = options}
    end
    options.method = "DELETE"
    local handle, err, errh = http.get{
        url = options.url,
        body = data,
        binary = options.encoding == "binary" or options.encoding == nil,
        headers = options.headers,
        method = options.method,
        redirect = options.redirect
    }
    if not handle then
        if errh then errh = handle
        else return nil, err end
    end
    return makeHTTPHandle(handle)
end

network.checkURI = http.checkURL

return network