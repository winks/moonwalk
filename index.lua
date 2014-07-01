local ngx                = ngx or require 'ngx'
local cjson              = require 'cjson'
local rocks              = require 'luarocks.loader'
local lunamark           = require 'lunamark'
local tirtemplate        = require 'tirtemplate'

local pmodel             = require 'pmodel'
local utils              = require 'utils'


-- defaults
ngx.header.content_type = 'text/plain'
local DB_PREFIX = '/db/'
local DB_POSTS_ALL = DB_PREFIX .. 'posts'
local DB_POSTS_ONE = DB_POSTS_ALL .. '/'
local DB_TAGS_ONE = DB_PREFIX .. 'tags/'
local DB_USERS_ONE = DB_PREFIX .. 'users/'
TEMPLATEDIR = ngx.var.root .. 'public/templates/'

local THIS_HOST  = ngx.var.host

-- stuff
local strip_fields = { 'created_at', 'updated_at' }
local array_fields = { 'tags', 'previous_shas' }

local user_whitelist = { 'display_name', 'domain', 'locale', 'url' }

local md_opts = {}
local md_writer = lunamark.writer.html.new(md_opts)
local md_parse = lunamark.reader.markdown.new(md_writer, md_opts)

-- functions
local get_json = function(mode, crit, strip, multiple)
  local url = ''
  if mode == 'tag' then
    url = DB_TAGS_ONE .. crit
  elseif mode == 'user' then
    url = DB_USERS_ONE .. crit
  else
    url = crit and DB_POSTS_ONE .. crit or DB_POSTS_ALL
  end
  local res, m = ngx.location.capture(url)
  local data = cjson.decode(res.body)
  for k, v in pairs(data) do
    if strip then
      for _, kv in pairs(strip_fields) do
        v[kv] = nil
      end
    end
    for _, kv in pairs(array_fields) do
      local a = v[kv]
      if a then
        a = a:gsub('[\\{\\}]', '')
        v[kv] = a and #a > 0 and utils.split(a, ',') or {}
      end
    end
    if not multiple then
      return v
      -- return cjson.encode(v)
    end
    data[k] = v
  end
  --return cjson.encode(data)
  return data
end

local get_posts_by_slug = function(crit, strip, multiple)
  return get_json('slug', crit, strip, multiple)
end

local get_posts_by_tag = function(crit, strip, multiple)
  return get_json('tag', crit, strip, multiple)
end

local get_users_by_domain = function(crit, strip, multiple)
  return get_json('user', crit, strip, multiple)
end

local prepare_post = function(p)
    p.body = p.body:gsub('\\n','\n')
    p.body = p.body:gsub('\\r','\r')
    p.body_html = md_parse(p.body)
    local dt = utils.strtotime(p.updated_at)
    p.pretty_date = utils.pretty_date(dt, '%Y-%m-%d %H:%M')
    p.backlink = p.slug
    return p
end

-- callback functions
local show_ping = function()

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

  if ok then
     return cjson.encode({status = ok, msg = msg})
  else
     return {500, {}, cjson.encode({msg = msg})}
  end
end
local show_index = function()
  ngx.header.content_type = 'text/html'
  data = get_posts_by_slug("", false, true)
  ps = {}

  for k, p in pairs(data) do
    ps[k] = prepare_post(p)
  end

  local page = tirtemplate.tload('post.html')
  local context = {
    title = "moonwalk",
    main = '',
    posts = ps
  }
  return page(context)
end
local show_post_json = function(match)
  ngx.header.content_type = 'application/json'
  data = get_posts_by_slug(match[1], true)
  return cjson.encode(data)
end
local show_user = function(match)
  local format = ngx.var.arg_format or 'html'
  data = get_users_by_domain(THIS_HOST)
  local data2 = {}
  for _, w in pairs(user_whitelist) do
    data2[w] = data[w]
  end

  if format == 'json' then
    ngx.header.content_type = 'application/json'
    return cjson.encode(data2)
  else
    local us = {}
    us[0] = data2
    local page = tirtemplate.tload('_user.html')
    local context = { title = 'moonwalk', users = us }
    ngx.header.content_type = 'text/html'
    return page(context)
  end
end
local show_post_md = function(match)
  ngx.header.content_type = 'text/x-markdown; charset=UTF-8'
  data = get_posts_by_slug(match[1], true)
  return data.body
end
local show_post_txt = function(match)
  ngx.header.content_type = 'text/plain'
  data = get_posts_by_slug(match[1])

  data = prepare_post(data)
  local r = ''
  r = r .. data.slug .. '\n----------\n'
  r = r .. data.body ..'\n----------\n'
  r = r .. data.body_html
  return r
end
local show_post_html = function(match)
  ngx.header.content_type = 'text/html'
  data = get_posts_by_slug(match[1])

  ps = {}
  ps[0] = prepare_post(data)

  local page = tirtemplate.tload('post.html')
  local context = {
    title = "moonwalk",
    main = r,
    posts = ps
  }

  return page(context)
end
local show_tag_html = function(match)
  ngx.header.content_type = 'text/html'
  data = get_posts_by_tag(match[1], false, true)
  ps = {}

  for k, p in pairs(data) do
    ps[k] = prepare_post(p)
  end

  local page = tirtemplate.tload('post.html')
  local context = {
    title = "moonwalk",
    main = '',
    posts = ps
  }
  return page(context)
end

-- ROUTING
-- these are checked from top to bottom.
local routes = {
  { pattern = 'user',          callback = show_user},
  { pattern = 'ping',          callback = show_ping},
  { pattern = 'tag/(.+)$',     callback = show_tag_html},
  { pattern = '(.+)\\.md$',    callback = show_post_md},
  { pattern = '(.+)\\.json$',  callback = show_post_json},
  { pattern = '(.+)\\.txt$',   callback = show_post_txt},
  { pattern = '(.+)$',         callback = show_post_html},
  { pattern = '$',             callback = show_index},
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
      ngx.print(ret)
      ngx.exit(ngx.OK)
    end
  end
end
