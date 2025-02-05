--- Changes timeouts at runtime.

local ahsm = require 'ahsm'

local fsm -- forward declaration

local s1 = ahsm.state { _name="s1", entry = function() print('S1', ahsm.get_time()) end }
local s2 = ahsm.state { _name="s2", entry = function() print('S2', ahsm.get_time()) end }

local t12 = ahsm.transition {
  src = s1,
  tgt = s2,
  timeout = 2.0,
  _name="s1->s2",
}

local t21 = ahsm.transition {
  src = s2,
  tgt = s1,
  events = {s2.EV_DONE},
  effect = function()
    if t12.timeout < 5.0 then
      t12.timeout = t12.timeout+1.0
    else
      --t12.timeout = nil
      os.exit()
    end
  end, 
  _name="s2->s1",
}

local root = ahsm.state {
  states = {s1, s2},
  transitions = {t12, t21},
  initial = s1
}

return root
