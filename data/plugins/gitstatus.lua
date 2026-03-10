local core = require("core")
local config = require("core.config")
local style = require("core.style")
local StatusView = require("core.statusview")

local git = {
    branch = nil,
    ahead = 0,
    behind = 0,
    dirty = 0,
    staged = 0,
}

local function exec(cmd, wait)
    local tempfile = core.temp_filename()
    system.exec(string.format("%s > %q", cmd, tempfile))
    coroutine.yield(wait)
    local fp = io.open(tempfile)
    local res = fp:read("*a")
    fp:close()
    os.remove(tempfile)
    return res
end

local last_change_time = 0

core.add_thread(function()
    while true do
        if core.project_change_time ~= last_change_time then
            last_change_time = core.project_change_time
            if system.get_file_info(".git") then
                -- get branch, ahead/behind, and dirty file count
                local status = exec("git status --porcelain -b", 1)
                local header = status:match("[^\n]*")
                git.branch = header:match("^## ([^%.%s]+)") or header:match("^## (.+)") or "unknown"
                git.ahead = tonumber(header:match("%[ahead (%d+)")) or 0
                git.behind = tonumber(header:match("behind (%d+)")) or 0
                local dirty = 0
                local staged = 0
                for line in status:gmatch("\n([^\n]+)") do
                    if line:match("^[MADRCU]") then
                        staged = staged + 1
                    end
                    if line:match("^.[MADRCU%?]") then
                        dirty = dirty + 1
                    end
                end
                git.dirty = dirty
                git.staged = staged

                core.redraw = true
            else
                git.branch = nil
            end
        end

        coroutine.yield(config.project_scan_rate)
    end
end)

local get_items = StatusView.get_items

function StatusView:get_items()
    if not git.branch then
        return get_items(self)
    end
    local left, right = get_items(self)

    local branch_label = git.branch
    if git.dirty > 0 then
        branch_label = branch_label .. "*"
    end
    if git.staged > 0 then
        branch_label = branch_label .. "+"
    end

    local t = {
        style.dim,
        self.separator,
        git.dirty > 0 and style.accent or style.text,
        branch_label,
    }

    if git.ahead > 0 or git.behind > 0 then
        table.insert(t, style.dim)
        table.insert(t, " | ")
        local parts = {}
        if git.ahead > 0 then
            table.insert(parts, git.ahead .. " ahead")
        end
        if git.behind > 0 then
            table.insert(parts, git.behind .. " behind")
        end
        table.insert(t, style.text)
        table.insert(t, table.concat(parts, ", "))
    end

    for _, item in ipairs(t) do
        table.insert(right, item)
    end

    return left, right
end
