local utils = {}
local ngx = ngx or require 'ngx'

--- Split a string using a pattern.
-- @param str The string to search in
-- @param pat The pattern to search with
-- @see http://lua-users.org/wiki/SplitJoin
function utils.split(str, pat)
  local t = {}  -- NOTE: use {n = 0} in Lua-5.0
  local fpat = '(.-)' .. pat
  local last_end = 1
  local s, e, cap = str:find(fpat, 1)
  while s do
    if s ~= 1 or cap ~= '' then
      t[#t+1] = cap
    end
    last_end = e+1
    s, e, cap = str:find(fpat, last_end)
  end
  if last_end <= #str then
    cap = str:sub(last_end)
    t[#t+1] = cap
  end
  return t
end


--- Create ISO 8601 timestamp from UNIX timestamp.
-- @param timestamp A UNIX timestamp
-- @see http://docs.coronalabs.com/api/library/os/date.html
function utils.iso_date(timestamp)
  return os.date('!%Y-%m-%dT%H:%M:%SZ', timestamp)
end

function utils.strtotime(str)
  local pat1 = '(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)([\\+-])(%d+)'
  local pat2 = pat1 .. ':(%d+)'

  _,_,y,m,d,h,i,s,z,o1,o2=string.find(str, pat2)

  if not y then
    _,_,y,m,d,h,i,s,z,o1=string.find(str, pat1)
  end

  local t = os.time{year=y,month=m,day=d,hour=h,min=i,sec=s}
  return t
end



function utils.pretty_date(date, format)
  if not format then
    format = '%Y-%m-%d'
  end

  return os.date(format, date)
end

return utils
