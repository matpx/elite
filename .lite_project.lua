local windows = PLATFORM == "Windows"
local output = windows and "lite.exe" or "lite"

local core = require "core"

global { runner = {
  build = function()
    local out, code = system.exec(windows and "build.bat" or "./build.sh")
    if code == 0 then
      core.log("Build succeeded\n%s", out or "")
      return true
    else
      core.error("Build failed (exit %d)\n%s", code, out or "")
      return false
    end
  end,

  run = function()
    system.exec("." .. PATHSEP .. output)
  end,

  clean = function()
    os.remove(output)
  end,
} }
