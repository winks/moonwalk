local ngx   = ngx or require 'ngx'
local ctrl  = require 'ctrl'
local utils = require 'utils'

-- ROUTING
-- these are checked from top to bottom.
local routes = {
  { pattern = 'posts(\\.json)?$', callback = ctrl.show_posts},
  { pattern = 'user(\\.json)?',   callback = ctrl.show_user},
  { pattern = 'ping$',            callback = ctrl.show_ping, before = {ctrl.post_only}},
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
    utils.pre_handler(route, match)
    utils.main_handler(route, match)
  end
end
