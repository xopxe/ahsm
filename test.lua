local ahsm = require 'ahsm'


local socket = require 'socket'

ahsm.get_time = socket.gettime
ahsm.debug = require 'tools.debug_plain'.out

local composite_s = require 'examples.composite'
composite_s.entry = function() print "MACHINE STARTED" end

local hsm = ahsm.init( composite_s )  -- create hsm from root composite state

local function send(e)
  print('TEST sending event', e)
  hsm.send_event(e)
end
local function loop(e)
  print( '===', hsm.loop()  )
end

--package.path = package.path .. ";;;tools/?.lua;tools/?/init.lua"
--local to_dot = require 'to_dot'

send(composite_s.events.e_on)
hsm.loop()
send('e_restart')
hsm.loop()

--to_dot.to_function(composite_s, print)

send('e_off')
hsm.loop()
send(composite_s.events.e_on)
hsm.loop()
while hsm.loop() do end
