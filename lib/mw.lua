local mw = {}

local utils = require 'lib.utils'
local etlua = require 'etlua'

local db = require 'lapis.db'
local util = require 'lapis.util'
local Model = require('lapis.db.model').Model
local Users = Model:extend('users', { primary_key = 'domain' })
local Posts = Model:extend('posts', { primary_key = 'slug' })
local Pings = Model:extend('pings', {})

local THIS_HOST = ngx.var.host
THIS_HOST = 'f5n.de'

local user_whitelist_fields = { 'display_name', 'domain', 'locale', 'url' }
local post_blacklist_fields = { 'created_at', 'updated_at' }
local post_table_fields     = { 'tags', 'previous_shas' }

function mw.save_ping(self, url)
  if not url then
    return nil
  end

  local now = db.raw('NOW()')
  local post = Pings:create({
    created_at = now,
    url     = url,
    remote  = ngx.var.REMOTE_ADDR or '',
    forward = ngx.var.http_x_forwarded_for or '',
  })

  return post
end

function mw.get_user(self, format)
  user = Users:find({ domain = THIS_HOST })
  if format == 'json' then
    local usr = {}
    for _, w in pairs(user_whitelist_fields) do
      usr[w] = user[w]
    end
    return usr
  end
  return user
end

function mw.get_posts_tag(self, tag)
  tag = utils.sanitize(tag)
  local s = string.format(
    "WHERE '%s' = ANY(tags) ORDER BY created_at DESC",
    tag
  )
  local posts = Posts:paginated(s)
  return mw.plain_to_table(posts:get_all())
end

function mw.get_posts(self, format)
  posts = Posts:paginated('ORDER BY created_at DESC')
  clean = (format == 'json')
  return mw.plain_to_table(posts:get_all(), clean)
end

function mw.get_post(self, slug, format)
  slug = utils.sanitize(slug)
  post = Posts:find({ slug = slug })
  clean = (format == 'json')
  return post and mw.plain_to_table({post}, clean) or nil
end

function mw.auth(user, pass)
  return pass == user.password_digest
end

function mw.login(self, user, pass)
  if mw.auth(user, pass) then
    self.session.current_user = user.domain
  else
    mw.logout(self)
  end
end

function mw.logout(self)
  self.session.current_user = nil
end

function mw.clean_post(orig)
  local post = orig
  for _, w in pairs(post_blacklist_fields) do
      post[w] = nil
  end
  return post
end

function mw.plain_to_table(data, clean, fields)
  fields = fields or post_table_fields
  for k, _ in pairs(data) do
    data[k] = clean and mw.clean_post(data[k]) or data[k]
    for _, field in pairs(fields) do
      local a = data[k][field]
      if a then
        if type(a) == 'string' then
          a = a:gsub('[\\{\\}]', '')
          data[k][field] = a and #a > 0 and utils.split(a, ',') or {}
        elseif type(a) == 'userdata' then
          data[k][field] = {}
        end
      else
        data[k][field] = {}
      end
    end
  end
  return data
end

function mw.tpl(tpl)
   local len = #ngx.var.document_root
   f = string.sub(ngx.var.document_root, 1, len-5) .. '/views/' .. tpl .. '.etlua'
   local filefp = assert(io.open(f, 'r'))
   local content = filefp:read('*a')

   local template = etlua.compile(content)
   filefp:close()

  return template
end

return mw
