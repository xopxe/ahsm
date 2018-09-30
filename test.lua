local ahsm = require 'ahsm'

local helloworld_s = require 'helloworld' -- load a fsm from a library

local off_s = ahsm.state { 
  entry = function () print "TEST STATE off" end,
  doo = function () --[[return true]] end, --single shot doo function, uncomment return for polling
}
local e_on = {}
local t21 = ahsm.transition { 
  src=off_s, 
  tgt=helloworld_s, --target is a composite state, will start it
  events={e_on},  --event is an object
  guard = function (e) return true end,  --guard function
  effect = function (e) --function called on transition
    print ('TEST switching on', os.time()) 
  end,  
}
local t22 = ahsm.transition { 
  src=helloworld_s, 
  tgt=off_s, 
  events={'e_off'}, 
  timeout=7.0,
  effect = function (e) --function called on transition
    print ('TEST switching off', os.time(), 'timeout:'..tostring(e==ahsm.EV_TIMEOUT)) 
  end,  
}

local composite_s = ahsm.state {
  states = { off=off_s, helloworld=helloworld_s },
  transitions = { t21, t22 },
  initial = off_s,
}


local fsm = ahsm.init( composite_s )  -- create fsm from root composite state

local function send(e)
  print('TEST sending event', e)
  fsm.send_event(e)
end
local function loop(e)
  print( '===', fsm.loop()  )
end

send(e_on)
fsm.loop()
send('e_restart')
fsm.loop()
send('e_off')
fsm.loop()
send(e_on)
fsm.loop()
while fsm.loop() do end
