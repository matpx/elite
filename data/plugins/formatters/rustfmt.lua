local util = require "plugins.formatters.util"

local function format(doc)
  util.format_with_cmd(doc, "rustfmt --emit stdout <")
end

return { format = format }
