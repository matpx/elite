local util = require("plugins.formatters.util")

local function format(doc)
	util.format_with_cmd(doc, "zig fmt --stdin <")
end

return { format = format }
