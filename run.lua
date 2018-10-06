#!/bin/lua

local ahsm = require 'ahsm'

local filename = arg[1]

if not filename then
  io.stderr:write( 'syntax:\n  lua run.lua <fsm.lua>\n' )
  os.exit()
end

local root = assert(dofile(filename))

local fsm = ahsm.init( root )  -- create fsm from root composite state

while fsm.loop() do end
