--look for packages one folder up.
--package.path = package.path .. ";;;../../?.lua;../../?/init.lua"

local ahsm = require 'ahsm'

local fsm -- forward declaration

local s1 = ahsm.state { entry = function() print('S1', ahsm.get_time()) end }
local s2 = ahsm.state { entry = function() print('S2', ahsm.get_time()) end }
local s3 = ahsm.state { entry = function() print('END', ahsm.get_time()) end }

local t12 = ahsm.transition {
  src = s1,
  tgt = s2,
  timeout = 1.0,
}
local t13 = ahsm.transition {
  src = s1,
  tgt = s3,
  events = {'END_E'},
}

local t21 = ahsm.transition {
  src = s2,
  tgt = s1,
  events = {s2.EV_DONE},
  effect = function()
    if t12.timeout < 5 then 
      t12.timeout = t12.timeout+1 
    else
      --t12.timeout = nil
      fsm.send_event('END_E')
    end
  end, 
}

local root = ahsm.state {
  states = {s1, s2, s3},
  transitions = {t12, t21, t13},
  initial = s1
}

fsm = ahsm.init( root ) 
while fsm.loop() do end
