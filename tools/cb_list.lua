--- A callback proxy for multiple for multiple callbacks.

local M = {}

local cbs_append = function (cbs, cb)
  cbs[#cbs+1] = cb
end
local cbs_remove = function (cbs, cb)
  for i = 1, #cbs do 
    if cbs[i] == cb then table.remove(cbs, i) end
  end
end
local cbs_call = function (cbs, ...)
  for i = 1, #cbs do 
    cbs[i](...)
  end
end

local cbs_mt = {
  __call = cbs_call
}

--- Get a new list.
-- @return an object to be registered as callback. Offers `append` and `remove` 
-- calls for regitering callbacks.
M.get_list = function ()
  local cbs = {
    append = cbs_append,
    remove = cbs_remove,
    call = cbs_call,
  }
  setmetatable (cbs, cbs_mt)

  return cbs
end

return M