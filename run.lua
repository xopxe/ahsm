--- Simple run script.
-- This script will execute a state machine from a library. This script must be 
-- placed in the same directory with hsm.lua. It is a good example on how a 
-- minimal program that uses an hsm looks.
-- @usage $ lua run.lua <fsm.lua>
-- @script run.lua

local ahsm = require 'ahsm'

local filename = arg[1]

if not filename then
  io.stderr:write( 'syntax:\n  lua run.lua <fsm.lua>\n' )
  os.exit()
end

local root = assert(dofile(filename))

local fsm = ahsm.init( root )  -- create fsm from root composite state

while fsm.loop() do end
