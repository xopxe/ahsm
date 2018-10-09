local ahsm = require 'ahsm'

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

send(composite_s.events.e_on)
hsm.loop()
send('e_restart')
hsm.loop()
send('e_off')
hsm.loop()
send(composite_s.events.e_on)
hsm.loop()
while hsm.loop() do end
