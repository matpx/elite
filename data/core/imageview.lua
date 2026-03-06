local core = require "core"
local style = require "core.style"
local View = require "core.view"


local ImageView = View:extend()

local image_extensions = {
  [".png"] = true, [".jpg"] = true, [".jpeg"] = true,
  [".bmp"] = true, [".gif"] = true, [".tga"] = true,
  [".psd"] = true, [".hdr"] = true, [".qoi"] = true,
}


function ImageView.is_image(filename)
  local ext = filename:lower():match("(%.[^%.]+)$")
  return ext and image_extensions[ext] or false
end


function ImageView:new(filename)
  ImageView.super.new(self)
  self.filename = filename
  self:reload()
end


function ImageView:reload()
  local ok, img = pcall(renderer.image.load, self.filename)
  if not ok then return end
  self.image = img
  self.scaled = nil
  self.scaled_w = 0
  self.scaled_h = 0
end


function ImageView:get_name()
  return self.filename:match("[^/\\]+$") or self.filename
end


function ImageView:get_scaled_image()
  local iw = self.image:get_width()
  local ih = self.image:get_height()
  local pad = style.padding.y * 2
  local vw = self.size.x - pad
  local vh = self.size.y - pad

  -- fit to view, preserving aspect ratio
  local scale = math.min(vw / iw, vh / ih)
  local sw = math.max(1, math.floor(iw * scale))
  local sh = math.max(1, math.floor(ih * scale))

  if sw ~= self.scaled_w or sh ~= self.scaled_h then
    self.scaled = self.image:resize(sw, sh)
    self.scaled_w = sw
    self.scaled_h = sh
  end

  return self.scaled, sw, sh
end


function ImageView:draw()
  self:draw_background(style.background)

  local ox, oy = self:get_content_offset()
  local img, sw, sh = self:get_scaled_image()

  -- center in view
  local x = ox + (self.size.x - sw) / 2
  local y = oy + (self.size.y - sh) / 2

  renderer.draw_image(img, x, y)

  -- draw info
  local iw = self.image:get_width()
  local ih = self.image:get_height()
  local text = string.format("%dx%d", iw, ih)
  renderer.draw_text(style.font, text, ox + style.padding.x, oy + style.padding.y, style.dim)
end


return ImageView
