local config = require("core.config")

local windows = PLATFORM == "Windows"
local output = windows and "elite.exe" or "elite"
local logfile = config.diagnostics_file

-- runner

global({
    runner = {
        build = function()
            local make = windows and "mingw32-make" or "make"
            local flags = "EXTRA_CFLAGS=-fdiagnostics-plain-output"
            return os.execute(
                "{ "
                    .. make
                    .. " "
                    .. flags
                    .. " -j 2>&1"
                    .. " && luacheck --formatter plain --codes . 2>&1; } >"
                    .. logfile
            )
        end,

        run = function()
            return system.exec("." .. PATHSEP .. output)
        end,

        clean = function()
            os.remove(logfile)
            return os.remove(output)
        end,
    },
})

-- formatter
