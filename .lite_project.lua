local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"

global { runner = {
  build = function()
    return os.execute(windows and "build.bat >runner.txt 2>&1" or "./build.sh >runner.txt 2>&1")
  end,

  run = function()
    return system.exec("." .. PATHSEP .. output)
  end,

  clean = function()
    return os.remove(output)
  end,
} }
