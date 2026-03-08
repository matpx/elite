local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"

global { runner = {
  lang = "cc",
  build = function()
    if not os.execute(windows and "build.bat >runner.txt 2>&1" or "./build.sh >runner.txt 2>&1") then
      -- core.open_file("runner.txt")
      return false
    end

    return true
  end,

  run = function()
    system.exec("." .. PATHSEP .. output)
  end,

  clean = function()
    os.remove(output)
  end,
} }
