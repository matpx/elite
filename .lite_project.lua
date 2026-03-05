local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"

global { runner = {
  build = function()
    local out, code = system.exec(windows and "build.bat" or "./build.sh", true)
    return code == 0, out
  end,

  run = function()
    system.exec("." .. PATHSEP .. output)
  end,

  clean = function()
    os.remove(output)
  end,
} }
