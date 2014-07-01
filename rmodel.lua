local model = {}
local ngx   = ngx or require 'ngx'
local redis = require 'resty.redis'
local utils = require 'utils'

local THIS_HOST  = ngx.var.host
local REDIS_HOST = os.getenv('REDIS_HOST')
local REDIS_PORT = os.getenv('REDIS_PORT')


function model.save_ping(hash)
  local red = redis:new()
  red:set_timeout(1000)
  local ok, err = red:connect(REDIS_HOST, REDIS_PORT)
  if not ok then
    return false, {msg = 'error: ' .. err or ''}
  end

  local redis_key_ping = utils.randomslug(16)
  local exists = red:hexists(redis_key_ping)
  while exists do
    redis_key_ping = utils.randomslug(16)
    exists = red:hexists(redis_key_ping)
  end

  if not hash.time then
    hash.time = os.time()
  end

  local ok, err = red:hmset(redis_key_ping, hash)
  if not ok then
    return false, {msg = 'error: ' .. err or ''}
  end

  local redis_key_list = THIS_HOST .. '_pings'
  local ok, err = red:rpush(redis_key_list, redis_key_ping)
  if not ok then
    return false, {msg = 'error: ' .. err or ''}
  end

  return true, {msg = 'success: ' .. hash.url}

end

return model
