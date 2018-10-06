#!/bin/lua

local ahsm = require 'ahsm'

local filename = arg[1]

if not filename then
  io.stderr( 'syntax: lua run.lua <fsm.lua>' )
end

local root = assert(dofile(filename))

local fsm = ahsm.init( root )  -- create fsm from root composite state

while fsm.loop() do end
