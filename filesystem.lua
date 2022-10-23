--- The filesystem module implements common operations for working with the
-- filesystem, including wrappers for syscalls.
--
-- @module system.filesystem

local expect = require "expect"

local filesystem = {}

--- Opens a file for reading or writing.
-- @tparam string path The path to the file to open
-- @tparam string mode The mode to open the file in: [rwa]b?
-- @treturn[1] FileHandle The file handle, which has the same functions as CraftOS file handles
-- @treturn[2] nil If the file could not be opened
-- @treturn[2] string An error message describing why the file couldn't be opened
filesystem.open = fs.open

--- Returns a list of files in a directory.
-- @tparam string path The path to query
-- @treturn table A list of files and folders in the directory
filesystem.list = fs.list

--- Returns a table with various information about a file or directory.
-- @tparam string path The path to query
-- @treturn FileStat A table with information about the path
function filesystem.stat(path)
    expect(1, path, "string")
    local stat = fs.attributes(path)
    if not stat then return nil end
    return {
        size = stat.size,
        type = stat.isDir and "directory" or "file",
        created = stat.created,
        modified = stat.modified,
        owner = "root",
        mountpoint = "/",
        capacity = fs.getCapacity(path),
        freeSpace = fs.getFreeSpace(path),
        permissions = {},
        worldPermissions = {read = true, write = not stat.isReadOnly, execute = true},
        setuser = false
    }
end

--- Deletes a file or directory at a path, removing any subentries if present.
-- @tparam string path The path to remove
filesystem.remove = fs.delete

--- Moves a file or directory on the same filesystem.
-- @tparam string from The original file to move
-- @tparam string to The new path for the file
filesystem.rename = fs.move

--- Creates a directory, making any parent paths that don't exist.
-- @tparam string path The directory to create
filesystem.mkdir = fs.makeDir

--- Changes the permissions (mode) of the file at a path.
-- @tparam string path The path to modify
-- @tparam string|nil user The user to modify, or nil to modify world permissions
-- @tparam number|string|{read?=boolean,write?=boolean,execute?=boolean} mode The new permissions, as either an octal bitmask, a string in the format "[+-=][rwx]+" or "[r-][w-][x-]", or a table with the permissions to set (any `nil` arguments are left unset).
function filesystem.chmod(path, user, mode)
    expect(1, path, "string")
    expect(2, user, "string", "nil")
    expect(3, mode, "number", "string", "table")
    if type(mode) == "string" and not mode:match "^[%+%-=][rwxs]+$" and not mode:match "^[r%-][w%-][xs%-]$" then
        error("bad argument #3 (invalid mode)", 2)
    elseif type(mode) == "table" then
        expect.field(mode, "read", "boolean", "nil")
        expect.field(mode, "write", "boolean", "nil")
        expect.field(mode, "execute", "boolean", "nil")
    end
    -- not implemented
end

--- Changes the owner of a file or directory.
-- @tparam string path The path to modify
-- @tparam string user The new owner of the file
function filesystem.chown(path, user)
    expect(1, path, "string")
    expect(2, user, "string")
    -- not implemented
end

--- Mounts a filesystem of the specified type to a directory. This can only be run by root.
-- @tparam string type The type of filesystem to mount
-- @tparam string src The source of the mount (depends on the FS type)
-- @tparam string dest The destination directory to mount to
-- @tparam[opt] table options A table of options to pass to the filesystem
function filesystem.mount(type, src, dest, options)
    expect(1, type, "string")
    expect(2, src, "string")
    expect(3, dest, "string")
    expect(4, options, "table", "nil")
    -- not implemented
end

--- Unmounts a mounted filesystem. This can only be run by root.
-- @tparam string path The filesystem to unmount
function filesystem.unmount(path)
    expect(1, path, "string")
    -- not implemented
end

--- Returns a list of mounts currently available.
-- @treturn [{path:string,type:string,source:string,options:table}] A list of mounts and their properties.
function filesystem.mountlist()
    return {{path = "/", type = "craftos", source = "/", options = {}}}
end

--- Combines the specified path components into a single path, canonicalizing any links and ./.. paths.
-- @tparam string ... The path components to combine
-- @treturn string The combined and canonicalized path
filesystem.combine = fs.combine

--- Copies a file or directory.
-- @tparam string from The path to copy from
-- @tparam string to The path to copy to
-- @tparam[opt] boolean preserve Whether to preserve permissions when copying
filesystem.copy = fs.copy

--- Moves a file or directory, allowing cross-filesystem operations.
-- @tparam string from The path to move from
-- @tparam string to The path to move to
filesystem.move = fs.move

--- Returns the file name for a path.
-- @tparam string path The path to use
-- @treturn string The file name of the path
function filesystem.basename(path)
    expect(1, path, "string")
    return filesystem.combine(path):match "[^/]+$"
end

--- Returns the parent directory for a path.
-- @tparam string path The path to use
-- @treturn string The parent directory of the path
function filesystem.dirname(path)
    expect(1, path, "string")
    local p = filesystem.combine(path):match "^(.*)/[^/]*$"
    if p == "" or p == nil then
        if path:sub(1, 1) == "/" then return "/"
        else return "." end
    else return p end
end

--- Searches the filesystem for paths matching a glob-style wildcard.
-- @tparam string wildcard The pathspec to match
-- @treturn table A list of matching file paths
filesystem.find = fs.find

--- Convenience function for determining whether a file exists.
-- This simply checks that @{stat} does not return `nil`.
-- @tparam string path The path to check
-- @treturn boolean Whether the path exists
filesystem.exists = fs.exists

--- Returns whether the path exists and is a file.
-- @tparam string path The path to check
-- @treturn boolean Whether the path is a file
function filesystem.isFile(path)
    expect(1, path, "string")
    return fs.exists(path) and not fs.isDir(path)
end

--- Returns whether the path exists and is a directory.
-- @tparam string path The path to check
-- @treturn boolean Whether the path is a directory
filesystem.isDir = fs.isDir

--- Returns whether the path exists and is a link.
-- @tparam string path The path to check
-- @treturn boolean Whether the path is a link
function filesystem.isLink(path)
    expect(1, path, "string")
    return false
end

--- Returns the effective permissions on a file or stat entry for the selected user.
-- @tparam string|FileStat file The file path or stat to check
-- @tparam[opt] string user The user to check for (defaults to the current user)
-- @treturn {read:boolean,write:boolean,execute:boolean}|nil The permissions for the user, or `nil` if the file doesn't exist
function filesystem.effectivePermissions(file, user)
    expect(1, file, "string", "table")
    user = expect(2, user, "number", "nil") or 0
    if type(file) == "string" then
        file = {permissions = {}, worldPermissions = {read = true, write = not fs.isReadOnly(file), execute = true}}
        if not file then return nil end
    end
    expect.field(file, "permissions", "table")
    expect.field(file, "worldPermissions", "table")
    return file.permissions[user] or file.worldPermissions
end

return filesystem