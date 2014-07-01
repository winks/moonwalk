local model = {}
local ngx    = ngx or require 'ngx'
local utils  = require 'utils'
local parser = require 'rds.parser'

local DB_PREFIX = '/db/'

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
  local query = "INSERT INTO pings VALUES(nextval('pings_id_seq'), NOW(), "
  query = query .. "'" .. hash.url .. "', '" .. hash.remote .. "', '" .. hash.forward .. "');"

  ngx.log(ngx.CRIT, query)

  local res, m = ngx.location.capture(url, { body = query })
  local out, err = parser.parse(res.body)
  if not (out) then
    return false, tostring(err) .. ": " .. tostring(str)
  end
  return true, out
end

return model
