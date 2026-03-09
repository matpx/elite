local core = require("core")
local command = require("core.command")
local keymap = require("core.keymap")
local config = require("core.config")
local json = require("plugins.lib.json")

-- Override these in your user module, e.g.:
--   config.formatter_commands[".lua"] = "stylua --indent-type Spaces - <"
--   config.formatter_commands[".ts"] = "prettier --stdin-filepath file.ts"
config.formatter_commands = {
    [".go"] = "gofmt",
    [".c"] = "clang-format",
    [".h"] = "clang-format",
    [".cc"] = "clang-format",
    [".cpp"] = "clang-format",
    [".hpp"] = "clang-format",
    [".rs"] = "rustfmt --emit stdout <",
    [".py"] = "black -q - <",
    [".zig"] = "zig fmt --stdin <",
    [".lua"] = "stylua - <",
    [".sh"] = "shfmt",
    [".bash"] = "shfmt",
}

local function get_ext(filename)
    return filename and filename:match("(%.[^.]+)$")
end

local function exec(cmd)
    local fp = io.popen(cmd, "r")
    local res = fp:read("*a")
    local success = fp:close()
    return res:gsub("%\n$", ""), success
end

local function format_with_cmd(doc, cmd)
    local active_filename = doc and system.absolute_path(doc.filename or "")
    local text, success = exec(string.format("%s %s", cmd, active_filename))
    if success == nil then
        core.error("Command '%s' not found in the system", cmd)
        return
    end
    local sel = { doc:get_selection() }
    doc:remove(1, 1, math.huge, math.huge)
    doc:insert(1, 1, text)
    doc:set_selection(table.unpack(sel))
end

local function format_json(doc)
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
end

command.add("core.docview", {
    ["formatter:format"] = function()
        local doc = core.active_view.doc
        local ext = get_ext(doc.filename)
        if not ext then
            core.error("No formatter configured for unknown files")
            return
        end
        if ext == ".json" then
            format_json(doc)
            return
        end
        local cmd = config.formatter_commands[ext]
        if not cmd then
            core.error("No formatter configured for '%s' files", ext)
            return
        end
        format_with_cmd(doc, cmd)
    end,
})

keymap.add({
    ["ctrl+shift+i"] = "formatter:format",
})
