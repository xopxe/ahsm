--- ahsm Hierarchical State Machine.
-- ahsm is a very small implementation of Hierararchical State Machines,
-- also known as Statecharts. It's written in Lua, with no external 
-- dependencies, and in a single file. Can be run on platforms as small as 
-- a microcontroler.
-- @module ahsm
-- @usage local ahsm = require 'ahsm'
-- @alias M

local M = {}

local EV_ANY = {}
local EV_TIMEOUT = {}

local function init ( composite )
  for _, s in pairs(composite.states) do
    s.out_trans = {}
    for _, t in pairs(composite.transitions) do
      if t.src == s then 
        for _, e in pairs(t.events) do
          if s.out_trans[e] then 
            print('WARN: multiple transitions from state on same event. Picking one.') 
          end
          s.out_trans[e] = t
        end
        --setup timeout
        if t.timeout then 
          if s.out_trans[EV_TIMEOUT] then 
            print('WARN: multiple transitions w/timeout from same state. Picking first.')
            if t.timeout<s.out_trans[EV_TIMEOUT].timeout then 
              s.out_trans[EV_TIMEOUT] = t
            end
          else
            s.out_trans[EV_TIMEOUT] = t
          end
        end
      end
    end
    if s.states then init( s ) end --recursion
  end
end

--- Function used by the fsm to get current time.
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
  return state_s
end

--- Initialize a transition.
-- Converts a transition specification into a transition table.
-- @param transition_s transition specificatios (see @{transition_s}).
-- @return the initilized transition
M.transition = function (transition_s)
  transition_s = transition_s or {}
  return transition_s
end

--- When used in the `events` field of a @{transition_s} will match any event.
M.EV_ANY = EV_ANY --singleton, event matches any event

--- Event reported to `effect()` when a transition is made due to a timeout. 
M.EV_TIMEOUT = EV_TIMEOUT


--- Create a fsm.
-- Constructs and initializes an fsm from a root state.
-- @param root_s the root state, must be a composite.
-- @return inialized fsm
M.init = function ( root_s )
  local fsm = { 
    --- Callback for pulling events.
    -- If provided, this function will be called from inside the `step` call
    -- so new events can be queued. All events in the queue are considered 
    -- simultaneous, and the order in which they are processed is undetermined.
    -- @param evqueue a set were new events can be placed.
    -- @function fsm.get_events
    get_events = nil, --function (evqueue) end,
  }
  init( root_s )

  local evqueue = {}
  local current_states = { [root_s.initial] = true }
  local active_trans = {} --must be balanced (enter and leave step() empty)

  local function enter_state (fsm, s, now)
    if s.entry then s.entry(s) end
    s.done = nil
    current_states[s] = true
    if s.out_trans[EV_TIMEOUT] then 
      s.expiration = now+s.out_trans[EV_TIMEOUT].timeout
    end
    if s.initial then
      enter_state(fsm, s.initial, now)
    end
  end

  local function exit_state (fsm, s, dont_call)
    if (not dont_call) and s.exit then s.exit(s) end
    current_states[s] = nil
    if s.states then --substates, is composite
      for _, sub_s in pairs(s.states) do
        if (current_states[sub_s]) then
          exit_state (fsm, sub_s, true) --FIXME call or not call?
        end
      end
    end
  end

  enter_state (fsm, root_s.initial, M.get_time())

  local function step ()
    local idle = true
    local next_expiration = math.huge
    local now = M.get_time()

    --queue new events
    if fsm.get_events then 
      fsm.get_events( evqueue )
    end

    --find active transitions
    for s, _ in pairs( current_states ) do
      local transited = false
      -- check for matching transitions for events
      for e, _ in pairs(evqueue) do
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
        local e = next(evqueue)
        if (t and e~=nil) and (t.guard==nil or t.guard(e)) then
          transited = true
          active_trans[t] = e
        end
      end
      --check timeouts
      if not transited then
        if s.out_trans[EV_TIMEOUT] then 
          local expiration = s.expiration
          if now>expiration then 
            transited = true
            active_trans[s.out_trans[EV_TIMEOUT]] = EV_TIMEOUT
          else
            if expiration<next_expiration then
              next_expiration = expiration
            end
          end
        end
      end
    end

    -- purge current events
    -- they are simultaneous, so concurrent transitions are not determnistic
    for e, _ in pairs(evqueue) do
      evqueue[e] = nil
    end

    --call leave_state, traverse transition, and enter_state
    for t, e in pairs(active_trans) do
      if current_states[t.src] then --src state could've been left
        idle = false
        exit_state(fsm, t.src)
        if t.effect then t.effect(e) end --FIXME pcall
        enter_state(fsm, t.tgt, now)
      end
      active_trans[t] = nil
    end

    --call doo on active_states
    for s, _ in pairs(current_states) do
      if not s.done then
        if type(s.doo)=='nil' then 
          evqueue[s.EV_DONE] = true
          s.done = true
          idle = false -- let step again for new event
        elseif type(s.doo)=='function' then 
          local poll_flag = s.doo(s) --TODO pcall
          if not poll_flag then 
            evqueue[s.EV_DONE] = true
            s.done = true
            idle = false -- let step again for new EV_DONE event
          end
        end
      end
    end

    if next_expiration==math.huge then
      next_expiration = nil
    end

    return idle, next_expiration
  end

  --- Push new event to the queue.
  -- All events added before running the fsm using step() or loop() are 
  -- considered simultaneous, and the order in which they are processed 
  -- is undetermined.
  -- @param ev an event. Can be of any type except nil.
  fsm.send_event = function (ev)
    evqueue[ev] = true
  end

  --- Step trough the fsm.
  -- A single step will consume all pending events, and do a round evaluating
  -- available doo() functions on all active states. This call finishes as soon 
  -- as the cycle count is reached or the fsm becomes idle.
  -- @param count maximum number of cycles to perform. Defaults to 1
  -- @return the idle status, and the next impending expiration time if 
  -- available. Being idle means that all events have been consumed and no 
  -- doo() function is pending to be run. The expiration time indicates there 
  -- is a transition with timeout waiting.
  fsm.step = function ( count )
    count = count or 1
    for i=1, count do
      local idle, expiration = step()
      if idle then return true, expiration end
    end
    return false
  end

  --- Loop trough the fsm.
  -- Will step the machine until it becomes idle. When this call returns means
  -- there's no actions to be taken immediatelly.
  -- @return expiration time if available, or the time the closests timeout
  -- on a transition to trigger
  fsm.loop = function ()
    local idle, expiration 
    repeat
      idle, expiration = step()
    until idle
    return expiration
  end

  return fsm
end


--- Data structures.
-- Main structures used to describe a fsm.
-- @section structures

------
-- State specification.
-- A state can be either leaf or composite. A composite state has a fsm 
-- embedded, defined by the `states`, `transitions` and `initial` fields. When a
-- compodite state is activated the embedded fsm is started from the `initial`
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
-- states of the embedded fsm. Keys can be used to provide a name.
-- @field transitions When the state is a composite this table's values are
-- the transitions of the embedded fsm. Keys can be used to provide a name.
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