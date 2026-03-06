local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"

global { runner = {
  build = function()
    return io.popen(windows and "build.bat" or "./build.sh"):close()
  end,

  run = function()
    system.exec("." .. PATHSEP .. output)
  end,

  clean = function()
    os.remove(output)
  end,
} }
