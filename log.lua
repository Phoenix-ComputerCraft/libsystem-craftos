--- The log module exposes functions for interacting with the logging subsystem.
-- The default system log is available under the root `log` table. Other logs
-- created through @{log.create} can be accessed by indexing the `log` table with
-- the name of the log, e.g. `log.mylog.info("hello")`. Both the main and
-- subtables may also be called directly, e.g. `log("test")` or `log.mylog("hello")`.
--
-- @module system.log

local expect = require "expect"

local function selflog(self, ...) return self.log(...) end

local function makeLogs(name)
    local log = {}
    --- Writes a message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.log(options, ...)
        -- nop
    end

    --- Writes a debug message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.debug(options, ...)
        -- nop
    end

    --- Writes an info message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.info(options, ...)
        -- nop
    end

    --- Writes a notice message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.notice(options, ...)
        -- nop
    end

    --- Writes a warning message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.warning(options, ...)
        -- nop
    end
    log.warn = log.warning

    --- Writes an error message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.error(options, ...)
        -- nop
    end

    --- Writes a critical error message to the log.
    -- @tparam[opt] table options A table of options to supply. See the documentation
    -- for the syslog syscall for more information.
    -- @tparam any ... The values to print to the log, which will be concatenated as
    -- strings with \t.
    function log.critical(options, ...)
        -- nop
    end

    --- Writes a traceback error message to the log.
    -- @tparam[opt] string message A message to attach to the traceback
    function log.traceback(message)
        -- nop
    end

    return setmetatable(log, {__call = selflog})
end

local log = makeLogs()

--- Constants for log levels.
log.levels = {
    debug = 0,
    info = 1,
    notice = 2,
    warning = 3,
    error = 4,
    critical = 5
}

--- Creates a new log.
-- @tparam string name The name of the log to create
-- @tparam[opt] boolean streamed Whether to make the log available for streaming
-- @tparam[opt] string file The path to the file to write the log to
-- @treturn table A logger object from `log.*`
function log.create(name, streamed, file)
    expect(1, name, "string")
    expect(2, streamed, "boolean", "nil")
    expect(3, file, "string", "nil")
    -- nop
    return makeLogs(name)
end

--- Removes a previously created log.
-- @tparam string name The log to remove
function log.remove(name)
    expect(1, name, "string")
    -- nop
end

--- Opens a log for listening to messages.
-- @tparam string name The name of the log to listen to
-- @tparam[opt] string filter A filter command to filter messages with (see the
-- openlog syscall docs for more info)
-- @treturn number An ID to identify the logged messages with
function log.open(name, filter)
    expect(1, name, "string")
    expect(2, filter, "string", "nil")
    error("Not implemented")
end

--- Closes a log or stream for listening.
-- @tparam string|number name The log name to close (closes all streams), or an
-- ID returned by @{log.open}.
function log.close(name)
    expect(1, name, "string", "number")
    -- nop
end

--- Sets the TTY to output a log to. (Requires root)
-- @tparam string name The log to set the TTY of
-- @tparam TTY|nil tty The TTY to use, or `nil` to disable
-- @tparam[opt] number level The minimum log level to show messages
function log.setTTY(name, tty, level)
    expect(1, name, "string")
    expect(2, tty, "table", "nil")
    expect(3, level, "number", "nil")
    -- nop
end

return setmetatable(log, {
    __call = selflog,
    __index = function(_, idx) if type(idx) == "string" then return makeLogs(idx) end end
})