#!/bin/lua

package.path = package.path .. ";;;tools/?.lua;tools/?/init.lua"
local ahsm = require 'ahsm'

local filename = arg[1]

if not filename then
   io.stderr( 'syntax: lua run_to_dot.lua <fsm.lua>' )
end

local to_dot = require 'to_dot'

local root = assert(dofile(filename))

local s = to_dot(root)

print( s )