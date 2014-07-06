local lapis  = require 'lapis'
local db     = require 'lapis.db'
local helper = require 'lapis.application'

local mw    = require 'lib.mw'
local utils = require 'lib.utils'
local etlua = require 'etlua'

local Model = require('lapis.db.model').Model
local Users = Model:extend('users', { primary_key = 'domain' })
local Posts = Model:extend('posts', { primary_key = 'slug' })

local capture_errors = helper.capture_errors

local THIS_HOST  = ngx.var.host
THIS_HOST = 'f5n.de'


local app = lapis.Application()
app:enable("etlua")
app.layout = require 'views.my_layout'

app:get('index', "/", function(self)
  self.title = "moonwalk"
  local navi_fn = mw.tpl('_navi')
  preface = navi_fn({session = self.session})
  posts = mw.get_posts(self)
  for k, v in pairs(posts) do
    posts[k] = utils.prepare_post(v)
  end
  return { render = "_post" }
end)

app:get('by_tag', "/tag/:tag", function(self)
  self.title = "moonwalk"
  local navi_fn = mw.tpl('_navi')
  preface = navi_fn({session = self.session})
  posts = mw.get_posts_tag(self, self.params.tag)
  for k, v in pairs(posts) do
    posts[k] = utils.prepare_post(v)
  end
  return { render = "_post" }
end)

app:get("/:tmp", function(self)
  self.title = "moonwalk"
  local p = self.req.parsed_url.path
  if p == '/user.json' then
    user = mw.get_user(self, 'json')
    return { json = user }
  elseif p == '/user' then
    user = mw.get_user(self)
    return { render = "_user" }
  elseif p == '/posts.json' then
    posts = mw.get_posts(self, 'json')
    return { json = posts }
  elseif p == '/posts' then
    return { redirect_to = self:url_for("index") }
  else
    print('[' .. p .. ']')
    local slug, format = string.match(p, '%/(%w+)%.(%w+)$')
    if slug then
      if format ~= 'json' and format ~= 'md' then
        format = 'html'
      end
      slug = string.sub(slug, 1)
    else
      slug = string.sub(p, 2)
      format = 'html'
    end
    posts = mw.get_post(self, slug, format)
    if not posts then
      status_code = 404
      if format == 'json' then
        return { status = status_code, json = {} }
      else
        return { status = status_code, render = "_error" }
      end
    end
    if format == 'json' then
      return { json = posts[1] }
    elseif format == 'md' then
      return { content_type = 'text/x-markdown', render = '_md', layout = false }
    end
    local navi_fn = mw.tpl('_navi')
    preface = navi_fn({session = self.session})
    posts[1] = utils.prepare_post(posts[1])
    return { render = "_post" }
  end
end)

app:get('/new/post', capture_errors(function(self)
  return { render = "_newpost" }
end))

app:post('/new/post', function(self)
  if not self.session.current_user then
    return { redirect_to = self:url_for("index") }
  end
  user = Users:find({ domain = THIS_HOST })

  local pbody = self.params.post.body
  local slug = utils.randomslug(3, 3)
  local guid = string.format('%s/%s', user.domain, slug)
  local now = db.raw('NOW()')

  local post = Posts:create({
    sha = "aaaa",
    slug = slug,
    domain = user.domain,
    body = pbody,
    body_html = '',
    created_at = now,
    updated_at = now,
    tags = db.null,
    previous_shas = db.null,
    published_at = now,
    guid = guid,
    edited_at = db.null,
    url = string.format('http://%s', guid),
    referenced_guid = '',
  })

  return { redirect_to = self:url_for("index") }
end)

app:match('/logout', function(self)
  mw.logout(self)
  return { redirect_to = self:url_for("index") }
end)

app:match('/login', function(self)
  if 'GET' == ngx.var.request_method then
    return { render = "_login" }
  end
  user = Users:find({ domain = THIS_HOST })
  if user then
    mw.login(self, user, self.params.login.password)
  else
    mw.logout(self)
  end
  return { redirect_to = self:url_for("index") }
end)

app:post('/ping', function(self)
  post = mw.save_ping(self, self.params.url)
  if not post then
    return { status = 400, render = "_error" }
  end
end)

app:match('/x/dump', function(self)
  xxx = self
  return { render = "_dump" }
end)
app:get('/x/testlogin', capture_errors(function(self)
  return { render = "_testlogin" }
end))

lapis.serve(app)
