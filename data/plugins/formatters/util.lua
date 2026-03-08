local core = require("core")

local util = {}

function util.exec(cmd)
	local fp = io.popen(cmd, "r")
	local res = fp:read("*a")
	local success = fp:close()
	return res:gsub("%\n$", ""), success
end

function util.format_with_cmd(doc, cmd)
	local active_filename = doc and system.absolute_path(doc.filename or "")
	local text, success = util.exec(string.format("%s %s", cmd, active_filename))
	if success == nil then
		core.error("Command '%s' not found in the system", cmd)
		return
	end
	local sel = { doc:get_selection() }
	doc:remove(1, 1, math.huge, math.huge)
	doc:insert(1, 1, text)
	doc:set_selection(table.unpack(sel))
end

return util
