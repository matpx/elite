local util = require "plugins.formatters.util"

local function format(doc)
  util.format_with_cmd(doc, "black -q - <")
end

return { format = format }
