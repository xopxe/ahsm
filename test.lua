local ahsm = require 'ahsm'

local hello_s = ahsm.state { exit=function () print "> hello" end }
local world_s = ahsm.state { entry=function () print "> world" end }
local t11 = ahsm.transition { src=hello_s, tgt=world_s, events={hello_s.EV_DONE} }
local t12 = ahsm.transition { src=world_s, tgt=hello_s, events={'e_restart'}, timeout=2.0}

local helloworld_s = ahsm.state {
  states = { hello=hello_s, world=world_s },
  transitions = { t11, t12 },
  initial = hello_s,
  exit = function () end,
}
--]]

local off_s = ahsm.state { 
  entry = function () print "> off" end,
  doo = function () end,
}
local t21 = ahsm.transition { 
  src=off_s, 
  tgt=helloworld_s, 
  events={'e_on'} ,
  guard = function () return true end,
  effect = function () end,
}
local t22 = ahsm.transition { src=helloworld_s, tgt=off_s, events={'e_off'}, timeout=7.0}

local composite_s = ahsm.state {
  states = { off=off_s, helloworld=helloworld_s },
  transitions = { t21, t22 },
  initial = off_s,
}


local fsm = ahsm.init( composite_s )

local function send(e)
  print('<', e)
  fsm.send_event(e)
end
local function loop(e)
  print( '===', fsm.loop()  )
end

loop()
send('e_restart')
loop()
send('e_on')
loop()
send('e_restart')
loop()
send('e_off')
loop()
send('e_on')
loop()
while fsm.loop() do end
