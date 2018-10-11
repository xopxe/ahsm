--- Two state flip-flop.

local ahsm = require 'ahsm'

local hello_s = ahsm.state { exit=function () --[[print "HW STATE hello"]] end } --state with exit func
local world_s = ahsm.state { entry=function () --[[print "HW STATE world"]] end } --state with entry func
local t11 = ahsm.transition { src=hello_s, tgt=world_s, events={hello_s.EV_DONE} } --transition on state completion
local t12 = ahsm.transition { src=world_s, tgt=hello_s, events={'e_restart'}, timeout=2.0} --transition with timeout, event is a string

local a = 0
local helloworld_s = ahsm.state {
  states = { hello=hello_s, world=world_s }, --composite state
  transitions = { t11, t12 },
  initial = hello_s, --initial state for machine
  doo = coroutine.wrap( function () -- a long running doo with yields
    while true do
      a = a + 1
      coroutine.yield(true)
    end
  end ),
  entry = function() --[[print 'HW doo running']] end,
  exit = function () print('HW doo iteration count', a) end,  -- will show efect of doo on exit
}

return helloworld_s

--[[
Sample use:

local helloworld_s = require 'helloworld'
local fsm = ahsm.init( helloworld_s )
fsm.send_event('e_restart')
while fsm.loop() do end
--]]