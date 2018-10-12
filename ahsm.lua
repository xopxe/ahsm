--- ahsm Hierarchical State Machine.
-- ahsm is a very small implementation of Hierararchical State Machines,
-- also known as Statecharts. It's written in Lua, with no external 
-- dependencies, and in a single file. Can be run on platforms as small as 
-- a microcontroler.
-- @module ahsm
-- @usage local ahsm = require 'ahsm'
-- @alias M

local pairs, type, rawset = pairs, type, rawset
local math_huge = math.huge

local M = {}

local EV_ANY = {}
local EV_TIMEOUT = {}

local debug_names = {}

local function pick_debug_name(v, nv)
  if debug_names[v] then return debug_names[v] end
  if type(nv)=='string' then 
    debug_names[v] = nv
  else 
    debug_names[v] = tostring(v) 
  end
  return debug_names[v]
end


local function init ( composite )
  --initialize debug name for states and events
  if M.debug then 
    for ne, e in pairs(composite.events or {}) do
      M.debug('event', e, '"'..pick_debug_name(e, ne)..'"')
    end
    for ns, s in pairs(composite.states) do
      M.debug('state', s, '"'..pick_debug_name(s, ns)..'"')
    end
    for nt, t in pairs(composite.transitions) do
      M.debug('trans', t, '"'..pick_debug_name(t, nt)..'"')
    end
  end

  for _, s in pairs(composite.states) do
    s.container = composite
    for nt, t in pairs(composite.transitions or {}) do
      if t.src == s then 
        for _, e in pairs(t.events or {}) do
          if s.out_trans[e] then 
            print('WARN: multiple transitions from state on same event. Picking one.') 
          end
          if M.debug then
            M.debug('trsel', debug_names[s], '--'..pick_debug_name(t, nt)..'['..(debug_names[e] or e)..']->', debug_names[t.tgt])
          end
          s.out_trans[e] = t
        end
      end
    end
    if s.states then init( s ) end --recursion
  end
end

--- Function used to get current time.
-- Replace with whatever your app uses. Must return a number.
-- Defaults to os.time.
-- @function get_time
M.get_time = os.time

--- Initialize a state.
-- Converts a state specfification into a state. 
-- The state has a EV\_DONE field which is an event triggered on state
-- completion.
-- @param state_s state specificatios (see @{state_s}).
-- @return the initilized state
M.state = function (state_s)
  state_s = state_s or {}
  state_s.EV_DONE = {} --singleton, trigered on state completion
  if M.debug then debug_names[state_s.EV_DONE] = 'EV_DONE' end
  state_s.out_trans = {}
  return state_s
end

--- Debug print function.
-- If provided, this function will be called to print debug information.
-- It must be set before calling @{init}
-- @usage ahsm.debug = print
M.debug = nil

local to_key = {}
local mt_transition = {
  __index = function (t, k)
    if k=='timeout' then
      return rawget(t, to_key)
    else
      return rawget(t, k)
    end
  end,
  __newindex = function(t, k, v)
    if k=='timeout' then
      local src_out_trans = t.src.out_trans
      local src_timout_trans = src_out_trans[EV_TIMEOUT]
      if v ~= nil then
        if src_timout_trans and t~=src_timout_trans then 
          print('WARN: multiple transitions w/timeout from same state. Picking first.')
          if v<src_timout_trans.timeout then 
            src_out_trans[EV_TIMEOUT] = t
          end
        else
          src_out_trans[EV_TIMEOUT] = t
        end
      elseif src_timout_trans == t then 
        src_out_trans[EV_TIMEOUT] = nil
      end
      rawset(t, to_key, v)
    else
      rawset(t, k, v)
    end
  end
}

--- Initialize a transition.
-- Converts a transition specification into a transition table.
-- @param transition_s transition specificatios (see @{transition_s}).
-- @return the initilized transition
M.transition = function (transition_s)
  transition_s = transition_s or {}
  assert(transition_s.src, 'missing source state in transition')
  assert(transition_s.tgt, 'missing target state in transition')

  local timeout = transition_s.timeout
  transition_s.timeout = nil
  setmetatable(transition_s, mt_transition)
  transition_s.timeout = timeout
  return transition_s
end

--- When used in the @{transition_s}`.events` field will match any event.
M.EV_ANY = EV_ANY --singleton, event matches any event

--- Event reported to @{transition_s}`.effect` when a transition is made due 
-- to a timeout. 
M.EV_TIMEOUT = EV_TIMEOUT

--- Create a hsm.
-- Constructs and initializes an hsm from a root state.
-- @param root the root state, must be a composite.
-- @return inialized hsm
M.init = function ( root )
  local hsm = { 
    --- Callback for pulling events.
    -- If provided, this function will be called from inside the `step` call
    -- so new events can be added. 
    -- @param evqueue an array where new events can be added.
    -- @function hsm.get_events
    get_events = nil, --function (evqueue) end,
  }
  init( root )

  root.container = {} -- fake container for root state
  debug_names[EV_TIMEOUT] = 'EV_TIMEOUT'

  local evqueue = {} -- array, will hold events for step() to process
  local current_states = {}  -- states being active
  local active_trans = {} --must be balanced (enter and leave step() empty)

  local function enter_state (hsm, s, now)
    if s.entry then s.entry(s) end
    s.container.current_substate = s
    s.done = nil
    current_states[s] = true
    if s.out_trans[EV_TIMEOUT] then 
      s.expiration = now+s.out_trans[EV_TIMEOUT].timeout
    end
    if s.initial then
      if M.debug then M.debug('init', debug_names[s.initial]) end
      enter_state(hsm, s.initial, now) -- recurse into embedded hsm
    end
  end

  local function exit_state (hsm, s, dont_call)
    if (not dont_call) and s.exit then s.exit(s) end
    current_states[s] = nil
    if s.current_substate then 
      exit_state (hsm, s.current_substate, true) --FIXME call or not call?
    end
  end

  enter_state (hsm, root, M.get_time()) -- activate root state

  local function step ()
    local idle = true
    local next_expiration = math_huge
    local now = M.get_time()

    --queue new events
    if hsm.get_events then 
      hsm.get_events( evqueue )
    end

    --find active transitions
    for s, _ in pairs( current_states ) do
      local transited = false
      -- check for matching transitions for events
      for _, e in ipairs(evqueue) do
        local t = s.out_trans[e]
        if t and (t.guard==nil or t.guard(e)) then  --TODO pcall?
          transited = true
          active_trans[t] = e
          break
        end
      end
      --check if event is * and there is anything queued
      if not transited then -- priority down if already found listed event
        local t = s.out_trans[EV_ANY]
        local e = evqueue[1]
        if (t and e~=nil) and (t.guard==nil or t.guard(e)) then
          transited = true
          active_trans[t] = e
        end
      end
      --check timeouts
      if not transited then
        local t = s.out_trans[EV_TIMEOUT]
        if t then 
          local expiration = s.expiration
          if now>expiration then
            if (t.guard==nil or t.guard(EV_TIMEOUT)) then 
              transited = true
              active_trans[s.out_trans[EV_TIMEOUT]] = EV_TIMEOUT
            end
          else
            if expiration<next_expiration then
              next_expiration = expiration
            end
          end
        end
      end
    end

    -- purge current events
    for i=1, #evqueue do
      rawset(evqueue, i, nil)
    end

    --call leave_state, traverse transition, and enter_state
    for t, e in pairs(active_trans) do
      if current_states[t.src] then --src state could've been left
        if M.debug then 
          M.debug('step', debug_names[t.src], '--'..tostring(debug_names[t] or t)..'['..tostring(debug_names[e] or e)..']->', debug_names[t.tgt]) 
        end
        idle = false
        exit_state(hsm, t.src)
        if t.effect then t.effect(e) end --FIXME pcall
        enter_state(hsm, t.tgt, now)
      end
      active_trans[t] = nil
    end

    --call doo on active_states
    for s, _ in pairs(current_states) do
      if not s.done then
        if type(s.doo)=='nil' then 
          evqueue[#evqueue+1] = s.EV_DONE
          s.done = true
          idle = false -- let step again for new event
        elseif type(s.doo)=='function' then 
          local poll_flag = s.doo(s) --TODO pcall
          if not poll_flag then 
            evqueue[#evqueue+1] = s.EV_DONE
            s.done = true
            idle = false -- let step again for new EV_DONE event
          end
        end
      end
    end

    if next_expiration==math_huge then
      next_expiration = nil
    end

    return idle, next_expiration
  end

  --- Push new event to the hsm.
  -- All events added before running the hsm using @{step} or @{loop} are 
  -- considered simultaneous, and the order in which they are processed 
  -- is undetermined.
  -- @param ev an event. Can be of any type except nil.
  hsm.send_event = function (ev)
    evqueue[#evqueue+1] = ev
  end

  --- Step trough the hsm.
  -- A single step will consume all pending events, and do a round evaluating
  -- available doo() functions on all active states. This call finishes as soon 
  -- as the cycle count is reached or the hsm becomes idle.
  -- @param count maximum number of cycles to perform. Defaults to 1
  -- @return the idle status, and the next impending expiration time if 
  -- available. Being idle means that all events have been consumed and no 
  -- doo() function is pending to be run. The expiration time indicates there 
  -- is a transition with timeout waiting.
  hsm.step = function ( count )
    count = count or 1
    for i=1, count do
      local idle, expiration = step()
      if idle then return true, expiration end
    end
    return false
  end

  --- Loop trough the hsm.
  -- Will step the machine until it becomes idle. When this call returns means
  -- there's no actions to be taken immediatelly.
  -- @return If available, the time of the closests pending timeout
  -- on a transition
  hsm.loop = function ()
    local idle, expiration 
    repeat
      idle, expiration = step()
    until idle
    return expiration
  end

  return hsm
end


--- Data structures.
-- Main structures used to describe a hsm.
-- @section structures

------
-- State specification.
-- A state can be either leaf or composite. A composite state has a hsm 
-- embedded, defined by the `states`, `transitions` and `initial` fields. When a
-- compodite state is activated the embedded hsm is started from the `initial`
-- state. The activity of a state must be provided in the `entry`, `exit` and `doo` 
-- fields.
-- @field entry an optional function to be called on entering the state.
-- @field exit an optional function to be called on leaving the state.
-- @field doo an optional function that will be called when the state is 
-- active. If this function returns true, it will be polled again. If
-- returns false, it is considered as completed.
-- @field EV_DONE This field is created when calling @{state}, and is an
-- event emitted when the `doo()` function is completed, or immediatelly if 
-- no `doo()` function is provided.
-- @field states When the state is a composite this table's values are the 
-- states of the embedded hsm. Keys can be used to provide a name.
-- @field transitions When the state is a composite this table's values are
-- the transitions of the embedded hsm. Keys can be used to provide a name.
-- @field initial This is the initial state of the embedded.
-- @table state_s

------
-- Transition specification.
-- @field src source state.
-- @field dst destination state.
-- @field events table where the values are the events that trigger the 
-- transition. Can be supressed by the guard function
-- @field guard if provided, when the transition is triggered this function 
-- will be evaluated with the event as parameter. If returns a true value
-- the transition is made.
-- @field effect this funcion of transition traversal, with the triggering 
-- event as parameter.
-- @field timeout If provided, this number is used as timeout for time 
-- traversal. After timeout time units spent in the souce state the transition 
-- will be triggered with the @{EV_TIMEOUT} event as parameter. Uses the 
-- @{get_time} to read the system's time.
-- @table transition_s



return M