--- Debug formatter that generates readable output.
-- @usage local ahsm = require 'ahsm' 
-- local debug_plain = require 'tools.debug_plain'
-- ahsm.debug = debug_plain.out

local M = {}


local debug_names = {}

local function pick_debug_name(v, nv)
  if debug_names[v] then return debug_names[v] end
  if type(nv)=='string' then 
    debug_names[v] = nv
  else 
    debug_names[v] = tostring(v._name or v) 
  end
  if v.container and v.container._name ~= '.' then -- build path for states
    debug_names[v] = debug_names[v.container] ..'.' ..debug_names[v]
  end
  return debug_names[v]
end

--- Function to be used to write.
-- Defaults to `print`
M.print = print

-- -- Function to be passed assigned to `ahsm.debug`.
M.out = function( action, p1, p2, p3, p4 )
  if action == 'step' then
    M.print(action..'\t'..debug_names[p1.src]..'\t--'..debug_names[p1]..'['..pick_debug_name(p2)..']->\t'..debug_names[p1.tgt])
  elseif action == 'init' then
    M.print(action..'\t'..debug_names[p1])
  elseif action == 'sched' then
    --M.print(action, p1, p2, debug_names[p3],'--'..debug_names[p4]..'->', debug_names[p4.tgt])
    --called before init
    M.print(action..'\t'..(debug_names[p1] or tostring(p1))..'\t'..tostring(p2))
  elseif action == 'event' then
    M.print(action..tostring(p1)..'\t"'..pick_debug_name(p1, p2)..'"')
  elseif action == 'state' then
    debug_names[p1.EV_DONE] = 'EV_DONE'
    M.print(action..'\t'..tostring(p1)..'\t"'..pick_debug_name(p1, p2)..'"')
  elseif action == 'trans' then
    M.print(action..'\t'..tostring(p1)..'\t"'..pick_debug_name(p1, p2)..'"')
  elseif action == 'trsel' then
    M.print(action..'\t'..debug_names[p1]..'\t--'..debug_names[p2]..'['
      ..pick_debug_name(p3)..']->\t'..debug_names[p2.tgt])
  end
end


return M