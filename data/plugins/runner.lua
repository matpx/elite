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
local config = require("core.config")
local keymap = require("core.keymap")

config.runner_save_on_build = true

local function save_all()
    for _, doc in ipairs(core.docs) do
        if doc.filename and doc:is_dirty() then
            doc:save()
        end
    end
end

local function run_task(name)
    if config.runner_save_on_build and name == "build" then
        save_all()
    end
    local r = rawget(_G, "runner")
    if type(r) ~= "table" or not r[name] then
        core.error("runner: no '%s' function defined", name)
        return false
    end
    local ok, success = pcall(r[name])
    if not ok then
        core.error("runner %s error: %s", name, success)
        return false
    end
    if name == "build" then
        local dr = rawget(_G, "diagnostics_reload")
        if dr then dr() end
    end
    if success then
        core.log("runner %s succeeded", name)
    else
        core.error("runner %s failed", name)
    end
    return success
end

command.add(nil, {
    ["runner:build"] = function()
        run_task("build")
    end,
    ["runner:build-and-run"] = function()
        if run_task("build") then
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
