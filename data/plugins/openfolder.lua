local core = require "core"
local command = require "core.command"

command.add(nil, {
  ["open-folder:open-in-new-instance"] = function()
    local proj_dir = system.absolute_path(".")
    core.command_view:set_text(proj_dir)
    core.command_view:enter("Open Folder in New Instance", function(text)
      if text and text ~= "" then
        system.exec(string.format("%q %q", EXEFILE, text))
      end
    end)
  end,
})
