local core = require "core"
local config = require "core.config"
local Doc = require "core.doc"
local ImageView = require "core.imageview"


local times = setmetatable({}, { __mode = "k" })
local last_changed = 0


core.add_thread(function()
  while true do
    if core.project_change_count ~= last_changed then
      last_changed = core.project_change_count
      -- check all doc modified times
      for _, doc in ipairs(core.docs) do
        local info = system.get_file_info(doc.filename or "")
        if info and times[doc] ~= info.modified then
          doc:reload()
          times[doc] = info.modified
          core.log_quiet("Auto-reloaded doc \"%s\"", doc.filename)
        end
        coroutine.yield()
      end

      -- check open image views
      for _, view in ipairs(core.root_view.root_node:get_children()) do
        if view:is(ImageView) then
          local info = system.get_file_info(view.filename or "")
          if info and times[view] ~= info.modified then
            view:reload()
            times[view] = info.modified
            core.log_quiet("Auto-reloaded image \"%s\"", view.filename)
          end
        end
        coroutine.yield()
      end
    end

    coroutine.yield(config.project_scan_rate)
  end
end)


-- patch `Doc.save|load` to store modified time
local load = Doc.load
local save = Doc.save

Doc.load = function(self, ...)
  local res = load(self, ...)
  local info = system.get_file_info(self.filename)
  if info then times[self] = info.modified end
  return res
end

Doc.save = function(self, ...)
  local res = save(self, ...)
  local info = system.get_file_info(self.filename)
  if info then times[self] = info.modified end
  return res
end

-- patch ImageView to store modified time on creation
local imageview_new = ImageView.new
ImageView.new = function(self, ...)
  imageview_new(self, ...)
  local info = system.get_file_info(self.filename)
  if info then times[self] = info.modified end
end
