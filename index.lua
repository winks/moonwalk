local ngx  = ngx or require 'ngx'
local ctrl = require 'ctrl'

-- ROUTING
-- these are checked from top to bottom.
local routes = {
  { pattern = 'posts(\\.json)?$', callback = ctrl.show_posts},
  { pattern = 'user',             callback = ctrl.show_user},
  { pattern = 'ping$',            callback = ctrl.show_ping},
  { pattern = 'tag/(.+)$',        callback = ctrl.show_tag_html},
  { pattern = '(.+)\\.md$',       callback = ctrl.show_post_md},
  { pattern = '(.+)\\.json$',     callback = ctrl.show_post_json},
  { pattern = '(.+)\\.txt$',      callback = ctrl.show_post_txt},
  { pattern = '(.+)$',            callback = ctrl.show_post_html},
  { pattern = '$',                callback = ctrl.show_all_html},
}

local BASE = '/'
for _, route in pairs(routes) do
  local uri = '^' .. BASE .. route['pattern']
  local match = ngx.re.match(ngx.var.uri, uri, '')
  if match then
    local ret = route['callback'](match)
    if type(ret) == 'table' then
      ngx.status = ret[1]
      for k, v in pairs(ret[2]) do
        ngx.header[k] = v
      end
      ngx.print(ret[3])
      ngx.exit(ngx.HTTP_OK)
    else
      ngx.header.content_type = 'text/html'
      ngx.print(ret)
      ngx.exit(ngx.OK)
    end
  end
end
