local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"

local formatters = {
  [".go"]   = "plugins.formatters.gofmt",
  [".c"]    = "plugins.formatters.clangfmt",
  [".h"]    = "plugins.formatters.clangfmt",
  [".cc"]   = "plugins.formatters.clangfmt",
  [".cpp"]  = "plugins.formatters.clangfmt",
  [".hpp"]  = "plugins.formatters.clangfmt",
  [".json"] = "plugins.formatters.jsonfmt",
  [".rs"]   = "plugins.formatters.rustfmt",
  [".py"]   = "plugins.formatters.black",
  [".zig"]  = "plugins.formatters.zigfmt",
  [".lua"]  = "plugins.formatters.stylua",
  [".sh"]   = "plugins.formatters.shfmt",
  [".bash"] = "plugins.formatters.shfmt",
}

local function get_ext(filename)
  return filename and filename:match("(%.[^.]+)$")
end

command.add("core.docview", {
  ["formatter:format"] = function()
    local doc = core.active_view.doc
    local ext = get_ext(doc.filename)
    local mod_name = ext and formatters[ext]
    if not mod_name then
      core.error("No formatter configured for '%s' files", ext or "unknown")
      return
    end
    local fmt = require(mod_name)
    fmt.format(doc)
  end,
})

keymap.add {
  ["ctrl+shift+f"] = "formatter:format",
}
