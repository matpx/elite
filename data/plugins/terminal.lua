local core = require("core")
local style = require("core.style")
local command = require("core.command")
local keymap = require("core.keymap")
local View = require("core.view")

local TerminalView = View:extend()

function TerminalView:new()
    TerminalView.super.new(self)
    self.scrollable = true
    self.lines = {}
    self.running = false
end

function TerminalView:try_close(do_close)
    self.running = false
    os.remove(self.output_file or "")
    os.remove(self.marker or "")
    do_close()
end

function TerminalView:get_name()
    return "Terminal"
end

function TerminalView:get_line_height()
    return style.code_font:get_height()
end

function TerminalView:get_scrollable_size()
    return #self.lines * self:get_line_height() + style.padding.y * 2
end

function TerminalView:run_command(cmd)
    if self.running then
        core.error("terminal: command already running")
        return
    end
    table.insert(self.lines, { text = "$ " .. cmd, color = style.accent })
    local output_start = #self.lines + 1
    self.running = true
    self.output_file = core.temp_filename(".term")
    self.marker = core.temp_filename(".done")
    local output_file = self.output_file
    local marker = self.marker
    local last_size = 0
    local shell_cmd =
        string.format("( %s ) > %s 2>&1 && echo ok > %s || echo fail > %s", cmd, output_file, marker, marker)
    system.exec(shell_cmd)
    core.add_thread(function()
        local function read_output()
            local info = system.get_file_info(output_file)
            if not info or info.size == last_size then
                return
            end
            last_size = info.size
            local fp = io.open(output_file, "r")
            if not fp then
                return
            end
            -- replace output lines from this command
            local i = output_start
            for line in fp:lines() do
                self.lines[i] = { text = line, color = style.text }
                i = i + 1
            end
            -- trim any excess from previous read
            for j = i, #self.lines do
                self.lines[j] = nil
            end
            fp:close()
            self.scroll.to.y = self:get_scrollable_size()
            core.redraw = true
        end

        while self.running do
            read_output()
            if system.get_file_info(marker) then
                read_output()
                os.remove(marker)
                os.remove(output_file)
                self.running = false
                table.insert(self.lines, { text = "", color = style.text })
                self.scroll.to.y = self:get_scrollable_size()
                core.redraw = true
            end
            coroutine.yield(0.25)
        end
    end)
end

function TerminalView:prompt()
    core.command_view:enter("Terminal", function(cmd)
        self:run_command(cmd)
    end)
end

function TerminalView:draw()
    self:draw_background(style.background)
    local ox, oy = self:get_content_offset()
    local lh = self:get_line_height()
    local y = oy + style.padding.y
    local x = ox + style.padding.x
    for _, line in ipairs(self.lines) do
        renderer.draw_text(style.code_font, line.text, x, y, line.color)
        y = y + lh
    end
    self:draw_scrollbar()
end

command.add(nil, {
    ["terminal:open"] = function()
        local node = core.root_view:get_active_node()
        node:add_view(TerminalView())
    end,
})

command.add(TerminalView, {
    ["terminal:run"] = function()
        local view = core.active_view
        view:prompt()
    end,
    ["terminal:stop"] = function()
        local view = core.active_view
        if view.running then
            view.running = false
            os.remove(view.output_file)
            os.remove(view.marker)
            table.insert(view.lines, { text = "^C (stopped)", color = style.accent })
            core.redraw = true
        end
    end,
    ["terminal:clear"] = function()
        local view = core.active_view
        if view.running then
            view.running = false
            os.remove(view.output_file)
            os.remove(view.marker)
        end
        view.lines = {}
        core.redraw = true
    end,
})

keymap.add({
    ["ctrl+´"] = "terminal:open",
    ["ctrl+c"] = "terminal:stop",
    ["return"] = "terminal:run",
})
