local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"
local logfile = "runner.txt"

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
