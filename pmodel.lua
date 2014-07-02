local model = {}
local ngx    = ngx or require 'ngx'
local utils  = require 'utils'
local parser = require 'rds.parser'

local DB_PREFIX = '/db/'
local post_table_fields = { 'tags', 'previous_shas' }

function model.plain_to_table(data, fields)
  fields = fields or post_table_fields
  for k, _ in pairs(data) do
    for _, field in pairs(fields) do
      local a = data[k][field]
      if a then
        a = a:gsub('[\\{\\}]', '')
        data[k][field] = a and #a > 0 and utils.split(a, ',') or {}
      end
    end
  end
  return data
end

function model.query(query)
  local url = DB_PREFIX .. 'query'
  local res, m = ngx.location.capture(url, { body = query })
  local out, err = parser.parse(res.body)
  if not (out) then
    return false, tostring(err) .. ": " .. tostring(str)
  end
  do
    local resultset = out.resultset
    if resultset then
      return resultset
    end
  end
  return out
end

function model.save_ping(hash)
  local url = DB_PREFIX .. 'query'
  local query = "INSERT INTO pings VALUES("
  query = query .. "nextval('pings_id_seq'), NOW(), "
  query = query .. "'" .. hash.url .. "', '" .. hash.remote
  query = query .. "', '" .. hash.forward .. "');"

  ngx.log(ngx.CRIT, query)

  local res, m = ngx.location.capture(url, { body = query })
  local out, err = parser.parse(res.body)
  if not (out) then
    return false, tostring(err) .. ": " .. tostring(str)
  end
  return out
end

function model.get_posts(updated_since)
  if updated_since then
    update_string = ' WHERE extract(epoch from updated_at) >= ' .. updated_since
  else
    update_string = ''
  end
  local query = string.format(
    "SELECT * FROM posts%s ORDER BY updated_at DESC;",
    update_string
  )
  utils.log(query)
  local data = model.query(query)
  data = model.plain_to_table(data)
  return data
end

function model.get_posts_by_tag(arg)
  local query = "SELECT * FROM posts WHERE '" .. arg
  query = query .. "' = ANY (tags) ORDER BY updated_at DESC;"
  local data = model.query(query)
  data = model.plain_to_table(data)
  return data
end

function model.get_post_by_slug(arg)
  local query = "SELECT * FROM posts WHERE slug='" .. arg
  query = query .. "' ORDER BY updated_at DESC;"
  local data = model.query(query)
  data = model.plain_to_table(data)
  return type(data[1]) == 'table' and data[1] or data
end

function model.get_user_by_domain(arg)
  local query = "SELECT * FROM users WHERE domain='" .. arg
  query = query .. "' ORDER BY id ASC;"
  local data = model.query(query)
  return type(data[1]) == 'table' and data[1] or data

end

return model
