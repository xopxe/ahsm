local ahsm = require 'ahsm'

local composite_s = require 'examples.composite'

local fsm = ahsm.init( composite_s )  -- create fsm from root composite state

local function send(e)
  print('TEST sending event', e)
  fsm.send_event(e)
end
local function loop(e)
  print( '===', fsm.loop()  )
end

send(composite_s.events.e_on)
fsm.loop()
send('e_restart')
fsm.loop()
send('e_off')
fsm.loop()
send(composite_s.events.e_on)
fsm.loop()
while fsm.loop() do end
