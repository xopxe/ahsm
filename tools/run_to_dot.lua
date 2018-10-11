--- Simple dot export script.
-- This script will export a hsm library to a dot file representation. 
-- If filename is provided the output will be written to a file. Otherwise
-- the dot output will be writted to stdout.
-- @usage $ lua run_to_dot.lua <fsm.lua> [filename]
-- @usage $ lua tools/run_to_dot.lua examples/composite.lua composite.dot
-- $ lua tools/run_to_dot.lua examples/composite.lua | dot -Tps -o composite.ps
-- $ lua tools/run_to_dot.lua examples/composite.lua | dot -Tpng | display -
-- @script run_to_dot.lua

package.path = package.path .. ";;;tools/?.lua;tools/?/init.lua"

local filehsm = arg[1]
local filetarget = arg[2]

if not filehsm then
  io.stderr:write( 'syntax:\n  lua run_to_dot.lua <fsm.lua> [filename]\n' )
  os.exit()
end

local root = assert(dofile(filehsm))
local to_dot = require 'to_dot'

if filetarget then
  assert(to_dot.to_file(root, filetarget))
else
  local s = to_dot.to_function(root, print)
end
