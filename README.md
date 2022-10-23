# libsystem-craftos
libsystem is the default system library for Phoenix. It provides convenient library functions for interacting with the kernel and other useful routines. libsystem attempts to implement all of the functionality of CraftOS in a new API that's cleaner and more in-line with Phoenix's design.

libsystem-craftos is a small wrapper library for CraftOS that allows some basic Phoenix programs to run on CraftOS. It also functions as a unifying library for cross-platform programs to be able to use basic system functions.

This is not a complete wrapper over libsystem: many functions that are impossible on plain CraftOS are not available, including the entire `ipc` and `sync` modules. There also may be some weird behavior in functions that don't have a 1:1 conversion in CraftOS. Finally, events pulled through `coroutine.yield()` will still be in CraftOS form - please use `util.pullEvent()` to guarantee the event is in Phoenix form.

## Installation
Simply copy all Lua files into a folder named `system` adjacent to the original program.

## Usage
Load any module in this library with `local module = require "system.module"`. See the Phoenix documentation for more information on how to use each module.