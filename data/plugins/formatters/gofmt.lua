local util = require "plugins.formatters.util"

local function format(doc)
  util.format_with_cmd(doc, "gofmt")
end

return { format = format }
