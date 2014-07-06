local html = require('lapis.html')
local Default
do
  local _parent_0 = html.Widget
  local _base_0 = {
    content = function(self)
      return html_5(function()
        head(function()
          meta({
            ["content"] = "text/html; charset=utf-8",
            ["http-equiv"] ="content-type",
          })
          link({
            ["type"] = "text/css",
            ["rel"] = "stylesheet",
            ["href"] = "/static/main.css",
            ["media"] = "screen",
          })
          return title(self.title or "moonwalk")
        end)
        return body(function()
          return self:content_for("inner")
        end)
      end)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  local _class_0 = setmetatable({
    __init = function(self, ...)
      return _parent_0.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Default",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        return _parent_0[name]
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Default = _class_0
  return _class_0
end
