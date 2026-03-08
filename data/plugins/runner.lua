-- Define a "runner" global in .lite_project.lua to enable build tasks:
--
--   global { runner = {
--     build = function() return os.execute("make") end,
--     run   = function() system.exec("./myapp") end,
--     clean = function() os.remove("myapp") end,
--   } }
--
-- Keys: F5 = build + run, F7 = build only

local core = require("core")
local command = require("core.command")
local keymap = require("core.keymap")
local style = require("core.style")
local StatusView = require("core.statusview")

local last_status = nil

local function save_all()
	for _, doc in ipairs(core.docs) do
		if doc.filename and doc:is_dirty() then
			doc:save()
		end
	end
end

local function run_task(name)
	if name == "build" then
		save_all()
	end
	local r = rawget(_G, "runner")
	if type(r) ~= "table" or not r[name] then
		core.error("runner: no '%s' function defined", name)
		return
	end
	local ok, success = pcall(r[name])
	if not ok then
		last_status = false
		core.error("runner %s error: %s", name, success)
	else
		local dr = name == "build" and rawget(_G, "diagnostics_reload")
		local has_errors = dr and dr()
		if success and not has_errors then
			last_status = true
			core.log("runner %s succeeded", name)
		else
			last_status = false
			core.error("runner %s failed", name)
		end
	end
end

-- status bar
local get_items = StatusView.get_items

function StatusView:get_items()
	if type(rawget(_G, "runner")) ~= "table" then
		return get_items(self)
	end
	local left, right = get_items(self)

	local label, color
	if last_status == nil then
		label = "ready"
		color = style.dim
	elseif last_status then
		label = "success"
		color = style.good or style.accent
	else
		label = "failed"
		color = style.accent
	end

	table.insert(right, style.dim)
	table.insert(right, self.separator)
	table.insert(right, color)
	table.insert(right, "runner: " .. label)
	return left, right
end

command.add(nil, {
	["runner:build"] = function()
		run_task("build")
	end,
	["runner:build-and-run"] = function()
		run_task("build")
		if last_status then
			run_task("run")
		end
	end,
	["runner:run"] = function()
		run_task("run")
	end,
	["runner:clean"] = function()
		run_task("clean")
	end,
	["runner:test"] = function()
		run_task("test")
	end,
})

keymap.add({
	["f5"] = "runner:build-and-run",
	["f7"] = "runner:build",
})
