local ctrl = {}

local ngx                = ngx or require 'ngx'
local cjson              = require 'cjson'
local lunamark           = require 'lunamark'
local tirtemplate        = require 'tirtemplate'

local pmodel             = require 'pmodel'
local utils              = require 'utils'


-- stuff
TEMPLATEDIR = ngx.var.root .. 'public/templates/'
local THIS_HOST  = ngx.var.host
local user_whitelist_fields = { 'display_name', 'domain', 'locale', 'url' }

local md_opts = {}
local md_writer = lunamark.writer.html.new(md_opts)
local md_parse = lunamark.reader.markdown.new(md_writer, md_opts)


-- callback functions
local ctrl.show_ping = function()
  if 'POST' ~= ngx.var.request_method then
    return {ngx.HTTP_NOT_ALLOWED, {}, cjson.encode({msg = 'error'})}
  end
  ngx.req.read_body()
  local args, err = ngx.req.get_post_args()
  if not args then
    return cjson.encode({msg = 'error: ' .. err or ''})
  end
  if not args.url then
    return cjson.encode({msg = 'missing parameter: url'})
  end

  local hash = {
    url     = args.url,
    remote  = ngx.var.REMOTE_ADDR or '',
    forward = ngx.var.http_x_forwarded_for or ''
  }

  local ok, msg = pmodel.save_ping(hash)

  if not ok then
     return {500, {}, cjson.encode({msg = msg})}
  end

  return cjson.encode({status = ok, msg = ""})
end

local ctrl.show_posts = function(match)
  if '.json' == match[1] then
    local updated_since = tonumber(ngx.var.arg_updated_since) or 1388530800
    local data = pmodel.get_posts(updated_since)
    return cjson.encode(data)
  end
  return ngx.redirect('http://' .. THIS_HOST  .. '/', 301)
end

local ctrl.show_all_html = function()
  local data = pmodel.get_posts()
  ps = {}

  for k, p in pairs(data) do
    ps[k] = utils.prepare_post(p)
  end

  local page = tirtemplate.tload('post.html')
  local context = {
    title = "moonwalk",
    main = '',
    posts = ps
  }
  return page(context)
end

local ctrl.show_user = function(match)
  local format = ngx.var.arg_format or 'html'
  local data = pmodel.get_user_by_domain(THIS_HOST)
  local data2 = {}
  for _, w in pairs(user_whitelist_fields) do
    data2[w] = data[w]
  end

  if format == 'json' then
    return {200, {['Content-type'] = 'application/json'}, cjson.encode(data2)}
  else
    local us = {}
    us[0] = data2
    local page = tirtemplate.tload('_user.html')
    local context = { title = 'moonwalk', users = us }
    return page(context)
  end
end

local ctrl.show_post_json = function(match)
  local data = pmodel.get_post_by_slug(match[1])
  return {200, {['Content-type'] = 'application/json'}, cjson.encode(data)}
end

local ctrl.show_post_md = function(match)
  local data = pmodel.get_post_by_slug(match[1])
  return {200, {['Content-type'] = 'text/x-markdown; charset=UTF-8'}, data.body}
end

local ctrl.show_post_txt = function(match)
  local data = pmodel.get_post_by_slug(match[1])
  data = utils.prepare_post(data)
  local r = ''
  r = r .. data.slug .. '\n----------\n'
  r = r .. data.body ..'\n----------\n'
  r = r .. data.body_html
  return {200, {['Content-type'] = 'text/plain'}, r}
end

local ctrl.show_post_html = function(match)
  local data = pmodel.get_post_by_slug(match[1])

  ps = {}
  ps[0] = utils.prepare_post(data)

  local page = tirtemplate.tload('post.html')
  local context = {
    title = "moonwalk",
    main = r,
    posts = ps
  }

  return page(context)
end

local ctrl.show_tag_html = function(match)
  local data = pmodel.get_posts_by_tag(match[1])
  ps = {}

  for k, p in pairs(data) do
    ps[k] = utils.prepare_post(p)
  end

  local page = tirtemplate.tload('post.html')
  local context = {
    title = "moonwalk",
    main = '',
    posts = ps
  }
  return page(context)
end

return ctrl
