local util = require "plugins.formatters.util"

local function format(doc)
  util.format_with_cmd(doc, "clang-format")
end

return { format = format }
