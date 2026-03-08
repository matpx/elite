-- Unfortunately, no one can be told what the Matrix is. You have to see it for yourself.
local core = require("core")
local style = require("core.style")
local command = require("core.command")
local config = require("core.config")
local View = require("core.view")

config.matrix_speed = 1.0 -- multiplier for fall speed
config.matrix_density = 0.7 -- 0..1, column spawn probability
config.matrix_fade_steps = 16 -- number of brightness levels in a trail

local chars = "abcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*(){}[]<>~"

local MatrixView = View:extend()

function MatrixView:new()
	MatrixView.super.new(self)
	self.columns = {}
	self.last_time = os.clock()
	self.num_cols = 0
	self.num_rows = 0
end

function MatrixView.get_name(_self)
	return "Matrix"
end

local function random_char()
	local i = math.random(1, #chars)
	return chars:sub(i, i)
end

local function make_stream(num_rows, pos)
	local length = math.random(4, math.max(4, num_rows))
	local stream = {
		pos = pos or 0,
		speed = 0.5 + math.random() * 1.0,
		length = length,
		chars = {},
	}
	if pos then
		local head = math.floor(pos)
		for r = math.max(1, head - length + 1), math.max(1, head) do
			if r <= num_rows then
				stream.chars[r] = random_char()
			end
		end
	end
	return stream
end

function MatrixView:update_grid()
	local font = style.code_font
	local cw, ch = font:get_width("W"), font:get_height()
	local cols = math.max(1, math.floor(self.size.x / cw))
	local rows = math.max(1, math.floor(self.size.y / ch))
	if cols == self.num_cols and rows == self.num_rows then
		return
	end
	self.num_cols = cols
	self.num_rows = rows
	for i = cols + 1, #self.columns do
		self.columns[i] = nil
	end
	-- seed all columns spread across the screen
	for i = 1, cols do
		if math.random() < config.matrix_density then
			self.columns[i] = make_stream(rows, math.random() * (rows + 10))
		end
	end
end

function MatrixView:update()
	self:update_grid()

	local now = os.clock()
	local dt = now - self.last_time
	self.last_time = now
	local steps = dt * 15 * config.matrix_speed

	for i = 1, self.num_cols do
		local col = self.columns[i]
		if not col then
			if math.random() < config.matrix_density * 0.05 then
				self.columns[i] = make_stream(self.num_rows)
			end
		else
			col.pos = col.pos + steps * col.speed
			local head = math.floor(col.pos)
			-- fill in characters as the head advances
			for r = math.max(1, head - 2), math.min(self.num_rows, head) do
				if not col.chars[r] then
					col.chars[r] = random_char()
				end
			end
			-- occasionally mutate a random cell in the trail
			if math.random() < 0.1 then
				local r = math.random(math.max(1, head - col.length), math.max(1, head))
				if r <= self.num_rows then
					col.chars[r] = random_char()
				end
			end
			-- recycle column when fully off screen
			if head - col.length > self.num_rows then
				if math.random() < config.matrix_density then
					self.columns[i] = make_stream(self.num_rows)
				else
					self.columns[i] = nil
				end
			end
		end
	end

	core.redraw = true
	MatrixView.super.update(self)
end

function MatrixView:draw()
	self:draw_background(style.background)

	local font = style.code_font
	local x0, y0 = self.position.x, self.position.y
	local cw, ch = font:get_width("W"), font:get_height()
	local fade_steps = config.matrix_fade_steps
	local bg = style.background
	local trail = style.syntax["string"]

	for i = 1, self.num_cols do
		local col = self.columns[i]
		if col then
			local head = math.floor(col.pos)
			local cx = x0 + (i - 1) * cw
			for r = math.max(1, head - col.length + 1), math.min(self.num_rows, head) do
				local c = col.chars[r]
				if c then
					local age = head - r
					local cy = y0 + (r - 1) * ch
					local color
					if age == 0 then
						color = style.accent
					else
						local t = math.max(0, 1 - age / fade_steps)
						color = {
							bg[1] + (trail[1] - bg[1]) * t,
							bg[2] + (trail[2] - bg[2]) * t,
							bg[3] + (trail[3] - bg[3]) * t,
							255,
						}
					end
					renderer.draw_text(font, c, cx, cy, color)
				end
			end
		end
	end
end

command.add(nil, {
	["matrix:open"] = function()
		local node = core.root_view:get_active_node()
		node:add_view(MatrixView())
	end,
})

return MatrixView
