# ahsm: a Hierarchical State Machine

ahsm is a very small and simple implementation of Hierarchical State Machines, also known as Statecharts. It's written in Lua, without external dependencies, and in a single file. It can be run on platforms as small as a microcontroller. The API is inspired by the [rFSM](https://github.com/kmarkus/rFSM) library but is heavily trimmed down to only the basic functionality.

## Features

- Lua only, with no external dependencies. Supports Lua 5.1, 5.2, 5.3.
- States, transitions, and events. States support `entry`, `exit` and `do` functions. Transitions support `effect` and `guard` functions. Events can be of any type. A state can have a state machine embedded, which is active while the state is active.
- A simple timeout scheme for transitions that solves many use cases without having to use timers.
- Easily embeddable in a system:
  - Events can be pushed or pulled
  - When using the timeout functionality, compute the idle times to allow saving on CPU
  - Easily browsable data representation for recovering sub-states, events, etc.
- Events can be of any type.
- Support for long-running actions in states using coroutines.
- Additional tools, like debugging output and a dot graph exporter for visualization.

See test.lua for an example of utilization.

## How to run?

To run examples, do:

```bash
lua run.lua examples/helloworld.lua
lua run.lua test.lua
```

To create a graphical representation of machines, do:

```bash
lua tools/run_to_dot.lua examples/composite.lua > composite.dot
dot -Tps composite.dot -o composite.ps
```

## How to use?

First, you load the ahsm library:

```lua
local ahsm=require'ahsm'
```

To create an HSM, you do:

- Define states.
- Define transitions.
- compose states.
- Integrate with your application.

### Defining states

States can be leaf or composite. We will deal with composite states later. A state is a table you initialized with the `ahsm.state` call. You can add code to the state to be executed at different moments through its lifetime:

```lua
local s1 = ahsm.state {}              -- an empty state
local s2 = ahsm.state {               -- another state, with behavior
  entry = function() print 'IN' end,  -- to be called on state activation
  exit = function() print 'OUT' end,  -- to be called on state deactivation
  doo = function()                    -- to be called while the state is active
    print 'DURING'
    return true                       -- doo() will be polled as long as it returns true
  end
}
```

### Defining transitions

A transition specifies a change between states as a response to an event. As with states, a transition is a table you pass to ahsm to initialize:

```lua
local t1 = ahsm.transition {
  src=s1,
  tgt=s2,
  events={'an_event', 'another_event'},
  effect = print,
}
```

In this case, `t1` will trigger a change from state `s1` to state `s2` whenever events `'an_event'` or `'another_event'` are emitted. This transition also has an effect function, called on transition traversal, with the event that triggered it as a parameter.

Events can be of any type. For example, you can use a table to create a singleton-like object to avoid clashes between events. For example:

```lua
local ev1 = {}
local t2 = ahsm.transition {
  src=s2,
  tgt=s1,
  events = {ev1},
  timeout = 5.0
}
```

Besides triggering on `ev1`, this transition will also trigger on timeout. This means that after 5 seconds, it will activate as if a special `ahsm.EV_TIMEOUT` event triggered it. Times are measured by calling `ahsm.get_time()`, which defaults to `os.time()`, but you can change it to whatever your system uses to get the current time. There's another special event, `ahsm.EV_ANY`, that will be matched by any event.

You can also have a `guard` function, which can decide if an event should trigger the transition or not. For example, you could have this:

```lua
local t3 = ahsm.transition {
  src=s2,
  tgt=s1,
  events={ev1, s2.EV_DONE},
  guard = function(e)
    if e==ev1 and math.random()<0.5 then return false end
    return true
  end
}
```

This example would refuse about half of the `ev1` events. In this example, the `EV_DONE` event is also used. It is a special event emitted by states when they are considered finalized. This is done after the `doo` function returns a false value or immediately if there was no `doo` function.

### Compose state machines

A whole state machine can be collected into a single composite state. Then, this state can be used as part of another state machine. You create a composite state just as a plain state, adding the embedded states and transitions:

```lua
local cs = ahsm.state {
  states = {s1, s2},
  transitions = {t1, t2, t3},
  initial = s1  -- the initial state of the embedded machine
}
```

In this example, states and transitions are arrays so that the elements can be browsed by index, but you could give them descriptive names to ease browsing, reuse, and debug output. As a convention, you can also add an event table to publish the events the machine uses:

```lua
local cs = ahsm.state {
  events = {
    evstr1 ='an_event',
    evstr2 ='another_event',
    evtbl1 = ev1,
  },
  states = {empty=s1, behavior=s2},
  transitions = {
    onstring = t1,
    withtimeout = t2,
    withguard = t3,
  },
  initial = s1,  -- the initial state of the embedded machine
}
```

Of course, you can add behavior with `entry`, `exit`, and `doo` functions if you want to use it as part of your state machine. Such a composite state is the standard way a state machine is reused. Typically, a library will return a composite state, and the user will require it and then use it in their state machine. The events to feed the embedded machine will be found in the events table.

### Integrate with your application

A machine is created by passing a composite state to the `ahsm.init` call. This call will return a table representing the machine. The composite state has a machine embedded and will be started at the `initial` state.

```lua
local hsm = ahsm.init( cs )
```

To use a state machine in an application, you must feed it events and let it step through them.

Events can be pushed by calling `hsm.queue_event`. For example, you can do:

```lua
hsm.queue_event( 'an_event' )
hsm.queue_event( cs.events.evtbl1 )
```

You can send events anywhere in your program, including from state functions or transition effects. Events are queued and then consumed by the machine when stepping.

Also, the state machine will pull events calling `hsm.get_events(evqueue)`, where evqueue is an array table where events can be added. You can provide this function to add events as needed. For example

```lua
local ev_much_memory = {}               -- an event
hsm.get_events = function (evqueue)
  if collectagarbage('count') > 10 then
    evqueue[#evqueue+1] = ev_much_memory      -- is sent under some conditions
  end
end
```

To advance the state machine, you have to step it. This can be done in two ways. One option is to call `hsm.step( count)`, where count is the number of steps you want to perform (defaults to 1). During a step, the HSM consumes all queued events since the last step and processes the affected transitions. New events can be emitted during a step, which will be processed in the next step. The `hsm.step` call returns an idle status. If there are pending events, or there's an active state with a `doo` function that requested to be polled, the idle status will be false. When the machine is idle, there is no reason to step the HSM until new events are produced. If transitions are waiting for timeout, the next impending timeout is returned as a second parameter.

If you want to consume all events and only get the control back when the machine is idle, you can use `hsm.loop()`. Internally, this call is:

```lua
hsm.loop = function ()
  local idle, expiration 
  repeat
    idle, expiration = step()
  until idle
  return expiration
end
```

Also, it is possible to use the state machine in a fully event-driven architecture.
A simple way to do this is to use `send_event()`, which is equivalent to queueing an event and then calling `loop()`.
For example, you could have callbacks drive a state machine:

```lua
-- Let's suppose we have a timer module
timer.register_callback(
  1,                      -- each second
  hsm.send_event('tick')  -- process an event
)
```

## License

Same as Lua, see LICENSE.

## Who?

Copyright (C) 2018 Jorge Visca <jvisca@fing.edu.uy>

Grupo MINA - Facultad de Ingeniería - Universidad de la República
