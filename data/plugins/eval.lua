local core = require("core")
local command = require("core.command")

local function eval(str)
    local fn, err = load("return " .. str)
    if not fn then
        fn, err = load(str)
    end
    assert(fn, err)
    return tostring(fn())
end

command.add(nil, {
    ["eval:run"] = function()
        core.command_view:enter("Evaluate", function(cmd)
            local fn, err = load(cmd)
            assert(fn, err)
            fn()
        end)
    end,
})

command.add("core.docview", {
    ["eval:insert"] = function()
        core.command_view:enter("Evaluate And Insert Result", function(cmd)
            core.active_view.doc:text_input(eval(cmd))
        end)
    end,

    ["eval:replace"] = function()
        core.active_view.doc:replace(eval)
    end,
})
