local ngx                = ngx or require 'ngx'
local tirtemplate        = require 'tirtemplate'
local redis              = require 'resty.redis'
local cjson              = require 'cjson'
local utils              = require 'utils'
local rocks              = require 'luarocks.loader'
local lunamark           = require 'lunamark'


-- defaults
ngx.header.content_type = 'text/plain'
local DB_PREFIX = '/db/'
local DB_POSTS_ALL = DB_PREFIX .. 'posts'
local DB_POSTS_ONE = DB_POSTS_ALL .. '/'
local DB_TAGS_ONE = DB_PREFIX .. 'tags/'
TEMPLATEDIR = ngx.var.root .. 'public/templates/'

-- stuff
local strip_fields = { 'created_at', 'updated_at' }
local array_fields = { 'tags', 'previous_shas' }
local md_opts = {}
local md_writer = lunamark.writer.html.new(md_opts)
local md_parse = lunamark.reader.markdown.new(md_writer, md_opts)

-- functions
local get_json = function(mode, crit, strip, multiple)
  local url = ''
  if mode == 'tag' then
    url = DB_TAGS_ONE .. crit
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
      a = a:gsub('[\\{\\}]', '')
      v[kv] = a and #a > 0 and utils.split(a, ',') or {}
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
    ngx.print(route['callback'](match))
    ngx.exit(ngx.OK)
  end
end
