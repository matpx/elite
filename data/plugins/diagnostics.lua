-- Parses a log file for compiler diagnostics and displays them inline.
--
-- Config:
--   config.diagnostics_file = "runner.txt"  -- path to log file (relative to project)
--
-- Supports gcc/clang/tcc output formats:
--   file:line:col: kind: message
--   file:line: kind: message

local core = require("core")
local config = require("core.config")
local style = require("core.style")
local DocView = require("core.docview")

config.diagnostics_file = "runner.txt"

local diagnostics = {}
local last_modified = 0
local last_change_time = 0

local kind_colors = {
    error = { 255, 80, 80, 255 },
    warning = { 255, 200, 80, 255 },
    note = { 130, 180, 255, 255 },
}

local function parse_line(line)
    local file, ln, kind, msg

    -- file:line:col: (Ennn) message  /  (Wnnn) message (luacheck)
    file, ln, msg = line:match("^%s*(.+):(%d+):%d+: %(E%d+%) (.+)$")
    if file then
        return file, tonumber(ln), "error", msg
    end
    file, ln, msg = line:match("^%s*(.+):(%d+):%d+: %(W%d+%) (.+)$")
    if file then
        return file, tonumber(ln), "warning", msg
    end

    -- file:line:col: kind: message (gcc/clang)
    file, ln, kind, msg = line:match("^(.+):(%d+):%d+: (%w+): (.+)$")
    if file and kind_colors[kind] then
        return file, tonumber(ln), kind, msg
    end

    -- file:line:col: syntax error: message (go)
    file, ln, msg = line:match("^(.+):(%d+):%d+: syntax error: (.+)$")
    if file then
        return file, tonumber(ln), "error", "syntax error: " .. msg
    end

    -- file:line: kind: message (tcc)
    file, ln, kind, msg = line:match("^(.+):(%d+): (%w+): (.+)$")
    if file and kind_colors[kind] then
        return file, tonumber(ln), kind, msg
    end
end

local function reload()
    diagnostics = {}
    local path = config.diagnostics_file
    if not path then
        return false
    end
    local fp = io.open(path, "r")
    if not fp then
        return false
    end
    local has_errors = false
    for line in fp:lines() do
        local file, ln, kind, msg = parse_line(line)
        if file then
            local abs = system.absolute_path(file)
            if not diagnostics[abs] then
                diagnostics[abs] = {}
            end
            if not diagnostics[abs][ln] then
                diagnostics[abs][ln] = {}
            end
            table.insert(diagnostics[abs][ln], { kind = kind, message = msg })
            if kind == "error" then
                has_errors = true
            end
        end
    end
    fp:close()
    return has_errors
end

-- expose reload for other plugins (e.g. runner)
rawset(_G, "diagnostics_reload", reload)

-- poll on project scan interval
core.add_thread(function()
    while true do
        if core.project_change_time ~= last_change_time then
            last_change_time = core.project_change_time
            local path = config.diagnostics_file
            if path then
                local info = system.get_file_info(path)
                if info and info.modified ~= last_modified then
                    last_modified = info.modified
                    reload()
                end
            end
        end
        coroutine.yield(config.project_scan_rate)
    end
end)

local function get_line_diags(doc, idx)
    if not doc.filename then
        return nil
    end
    local file_diags = diagnostics[system.absolute_path(doc.filename)]
    return file_diags and file_diags[idx]
end

-- gutter markers
local draw_line_gutter = DocView.draw_line_gutter

function DocView:draw_line_gutter(idx, x, y)
    draw_line_gutter(self, idx, x, y)
    local diags = get_line_diags(self.doc, idx)
    if diags then
        local h = self:get_line_height()
        local color = kind_colors[diags[1].kind] or kind_colors.error
        renderer.draw_rect(x, y, style.padding.x * 0.3, h, color)
    end
end

-- inline diagnostics
local draw_line_text = DocView.draw_line_text

function DocView:draw_line_text(idx, x, y)
    draw_line_text(self, idx, x, y)
    local diags = get_line_diags(self.doc, idx)
    if diags then
        local font = self:get_font()
        local ty = y + self:get_line_text_y_offset()
        local tx = x + font:get_width(self.doc.lines[idx] or "")
        for _, d in ipairs(diags) do
            local msg = "  " .. d.kind .. ": " .. d.message
            local color = kind_colors[d.kind] or kind_colors.error
            tx = renderer.draw_text(font, msg, tx, ty, color)
        end
    end
end
