#!/bin/lua

package.path = package.path .. ";;;tools/?.lua;tools/?/init.lua"
local ahsm = require 'ahsm'

local filename = arg[1]

if not filename then
  io.stderr:write( 'syntax:\n  lua run_to_dot.lua <fsm.lua>\n' )
  io.stderr:write( 'Examples:\n' )
  io.stderr:write( '  ahsm$ lua5.3 tools/run_to_dot.lua examples/composite.lua > composite.dot\n')
  io.stderr:write( '  ahsm$ lua5.3 tools/run_to_dot.lua examples/composite.lua | dot -Tps -o composite.ps\n')
  io.stderr:write( '  ahsm$ lua5.3 tools/run_to_dot.lua examples/composite.lua | dot -Tpng | display -\n')
  os.exit()
end

local to_dot = require 'to_dot'

local root = assert(dofile(filename))

local s = to_dot(root)

print( s )