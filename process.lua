--- The process module allows querying various properties about the current
-- process, as well as creating, modifying, and searching other processes.
--
-- @module system.process

local expect = require "expect"

local process = {}

--- Returns the name of the current process.
-- @treturn string The name of the current process
function process.getname()
    return shell.getRunningProgram()
end

--- Returns the working directory of the current process.
-- @treturn string The working directory of the current process
function process.getcwd()
    return shell.dir()
end

--- Sets the working directory of the current process.
-- @tparam string dir The new working directory, which must be absolute and existent.
function process.chdir(dir)
    expect(1, dir, "string")
    return shell.setDir(dir)
end

--- Runs a program from the specified path in a new process, waiting until it completes.
-- @tparam string path The path to the file to execute
-- @tparam any ... Any arguments to pass to the file
-- @treturn[1] true When the process succeeded
-- @treturn[1] any The return value from the process
-- @treturn[2] false When the process errored
-- @treturn[2] string The error message from the process
function process.run(path, ...)
    expect(1, path, "string")
    return shell.run(path, ...)
end

return process