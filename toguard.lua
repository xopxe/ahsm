local ahsm = require 'ahsm'

local hello_s = ahsm.state { exit=function () print "> hello" end } --state with exit func
local world_s = ahsm.state { entry=function () print "> world" end } --state with entry func
local t11 = ahsm.transition { src=hello_s, tgt=world_s, events={hello_s.EV_DONE} } --transition on state completion

--local t12 = ahsm.transition { src=world_s, tgt=hello_s, events={'e_restart'}, timeout=1.0} --transition with timeout, event is a string
local t12 = ahsm.transition { src=world_s, tgt=hello_s, events={'e_restart'}}--event is a string
local t12to = ahsm.transition { src=world_s, tgt=hello_s, guard=ahsm.get_timeout_guard(1.0)} --transition with timeout

local a = 0
local helloworld_s = ahsm.state {
  states = { hello=hello_s, world=world_s }, --composite state
  transitions = { t11, t12, t12to },
  initial = hello_s, --initial state for machine
  doo = coroutine.wrap( function () -- a long running doo with yields
    while true do
      a = a + 1
      coroutine.yield(true)
      a = a + 1
    end
  end ),
  exit = function () print('!', a) end,  -- will show efect of doo on exit
}
--]]

local off_s = ahsm.state { 
  entry = function () print "> off" end,
  doo = function () --[[return true]] end, --single shot doo function, uncomment return for polling
}
local e_on = {}
local t21 = ahsm.transition { 
  src=off_s, 
  tgt=helloworld_s, --target is a composite state, will start it
  events={e_on},  --event is an object
  guard = function (e) return true end,  --guard function
  effect = function (e) end,  --function called on transition
}
--local t22 = ahsm.transition { src=helloworld_s, tgt=off_s, events={'e_off'}, timeout=3.0}
local t22 = ahsm.transition { src=helloworld_s, tgt=off_s, events={'e_off'}}
local t22to = ahsm.transition { src=helloworld_s, tgt=off_s, guard=ahsm.get_timeout_guard(3.0)}

local composite_s = ahsm.state {
  states = { off=off_s, helloworld=helloworld_s },
  transitions = { t21, t22, t22to },
  initial = off_s,
}


local fsm = ahsm.init( composite_s )  -- create fsm from root composite state

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
send(e_on)
loop()
send('e_restart')
loop()
send('e_off')
loop()
send(e_on)
loop()
while fsm.loop() do end
