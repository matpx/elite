local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local json = require "plugins.lib.json"


command.add("core.docview", {
  ["jsonfmt:format"] = function()
    local doc = core.active_view.doc
    local text = doc:get_text(1, 1, math.huge, math.huge)
    local ok, val = pcall(json.decode, text)
    if not ok then
      core.error("jsonfmt: %s", val)
      return
    end
    local formatted = json.pretty(val)
    local sel = { doc:get_selection() }
    doc:remove(1, 1, math.huge, math.huge)
    doc:insert(1, 1, formatted)
    doc:set_selection(table.unpack(sel))
  end,
})

keymap.add {
  ["ctrl+shift+j"] = "jsonfmt:format",
}
