local config = require("core.config")

local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"
local logfile = config.diagnostics_file

-- runner

global { runner = {
  build = function()
    return os.execute(windows
      and "( build.bat 2>&1 && winlib\\luacheck\\luacheck.exe --formatter plain --codes . 2>&1 ) >" .. logfile
      or "{ ./build.sh 2>&1 && luacheck --formatter plain --codes . 2>&1; } >" .. logfile)
  end,

  run = function()
    return system.exec("." .. PATHSEP .. output)
  end,

  clean = function()
    os.remove(logfile)
    return os.remove(output)
  end,
} }

-- formatter

local window_stylua = EXEDIR .. "/winlib/stylua/stylua.exe - <"
local linux_stylua = EXEDIR .. "/winlib/stylua/stylua.exe - <"

config.formatter_commands[".lua"] = windows and window_stylua or linux_stylua
