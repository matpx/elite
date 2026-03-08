-- Define a "runner" global in .lite_project.lua to enable build tasks:
--
--   global { runner = {
--     lang  = "cc",  -- diagnostics parser: "cc" (gcc/clang/tcc)
--     build = function() return os.execute("make >runner.txt 2>&1") end,
--     run   = function() system.exec("./myapp") end,
--     clean = function() os.remove("myapp") end,
--   } }
--
-- Keys: F5 = build + run, F7 = build only

local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local style = require "core.style"
local StatusView = require "core.statusview"
local DocView = require "core.docview"

local last_status = nil
local diagnostics = {}

local kind_colors = {
  error   = { 255, 80, 80, 255 },
  warning = { 255, 200, 80, 255 },
  note    = { 130, 180, 255, 255 },
}

-- built-in parsers for runner.txt diagnostics
local parsers = {}

function parsers.cc(line)
  -- file:line:col: kind: message (gcc/clang)
  local file, ln, kind, msg = line:match("^(.+):(%d+):%d+: (%w+): (.+)$")
  if not file then
    -- file:line: kind: message (tcc)
    file, ln, kind, msg = line:match("^(.+):(%d+): (%w+): (.+)$")
  end
  if file and kind_colors[kind] then
    return file, tonumber(ln), kind, msg
  end
end


local function parse_runner_txt()
  diagnostics = {}
  local r = rawget(_G, "runner")
  if type(r) ~= "table" or not r.lang then return end
  local parse = parsers[r.lang]
  if not parse then return end
  local fp = io.open("runner.txt", "r")
  if not fp then return end
  for line in fp:lines() do
    local file, ln, kind, msg = parse(line)
    if file then
      local abs = system.absolute_path(file)
      if not diagnostics[abs] then diagnostics[abs] = {} end
      if not diagnostics[abs][ln] then diagnostics[abs][ln] = {} end
      table.insert(diagnostics[abs][ln], { message = msg, kind = kind })
    end
  end
  fp:close()
end


local function get_doc_diags(doc)
  if not doc.filename then return nil end
  return diagnostics[system.absolute_path(doc.filename)]
end


local function save_all()
  for _, doc in ipairs(core.docs) do
    if doc.filename and doc:is_dirty() then
      doc:save()
    end
  end
end


local function run_task(name)
  if name == "build" then save_all() end
  local r = rawget(_G, "runner")
  if type(r) ~= "table" or not r[name] then
    core.error("runner: no '%s' function defined", name)
    return
  end
  local ok, success = pcall(r[name])
  if not ok then
    last_status = false
    core.error("runner %s error: %s", name, success)
  elseif success then
    last_status = true
    diagnostics = {}
    core.log("runner %s succeeded", name)
  else
    last_status = false
    core.error("runner %s failed", name)
    parse_runner_txt()
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


-- gutter markers
local draw_line_gutter = DocView.draw_line_gutter

function DocView:draw_line_gutter(idx, x, y)
  draw_line_gutter(self, idx, x, y)
  local diags = get_doc_diags(self.doc)
  if diags and diags[idx] then
    local h = self:get_line_height()
    local color = kind_colors[diags[idx][1].kind] or kind_colors.error
    renderer.draw_rect(x, y, style.padding.x * 0.3, h, color)
  end
end


-- inline diagnostics
local draw_line_text = DocView.draw_line_text

function DocView:draw_line_text(idx, x, y)
  draw_line_text(self, idx, x, y)
  local diags = get_doc_diags(self.doc)
  if diags and diags[idx] then
    local font = self:get_font()
    local ty = y + self:get_line_text_y_offset()
    local tx = x + font:get_width(self.doc.lines[idx] or "")
    for _, d in ipairs(diags[idx]) do
      local msg = "  " .. d.kind .. ": " .. d.message
      local color = kind_colors[d.kind] or kind_colors.error
      tx = renderer.draw_text(font, msg, tx, ty, color)
    end
  end
end


command.add(nil, {
  ["runner:build"]         = function() run_task("build") end,
  ["runner:build-and-run"] = function() run_task("build") if last_status then run_task("run") end end,
  ["runner:run"]           = function() run_task("run") end,
  ["runner:clean"]         = function() run_task("clean") end,
  ["runner:test"]          = function() run_task("test") end,
})

command.add("core.docview", {
  ["runner:next-issue"] = function()
    local doc = core.active_view.doc
    local diags = get_doc_diags(doc)
    if not diags then return end
    local line = doc:get_selection()
    local first, next_line = math.huge, math.huge
    for l in pairs(diags) do
      if l > line and l < next_line then next_line = l end
      if l < first then first = l end
    end
    if next_line == math.huge then next_line = first end
    if next_line ~= math.huge then
      doc:set_selection(next_line, 1)
      core.active_view:scroll_to_line(next_line, true)
    end
  end,
})

keymap.add {
  ["f5"]        = "runner:build-and-run",
  ["f7"]        = "runner:build",
  ["ctrl+shift+n"] = "runner:next-issue",
}
