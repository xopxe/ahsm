--- Simple run script.
-- This script will execute a state machine from a library. This script must be 
-- placed in the same directory with hsm.lua. 
-- @usage lua run.lua  [debug] [forever] [sleep=none|os|socket] [time=ahsm|os|socket] <fsm.lua>
-- @usage [debug] enables the ahsm logging using print.
-- @usage [forever] do not not stop even if the machine becomes idle.
-- @usage [sleep=none|os|socket] selects a sleeping mode. 
-- "none" is polling, "os" uses a call to the sleep pogram, 
-- and "socket" uses luasockets sleep().
-- @usage [time=ahsm|os|socket] sets the ahsm.gettime function. 
-- "ahsm" keeps it unchanged, "os" sets to call to os.time(), 
-- and "socket" set to luasockets gettime()
-- @script run.lua

local forever = false

local config = {
  sleep = 'none', -- 'os', 'socket'
  time = 'ahsm', -- 'socket'
}

local function exit_on_error(err)
  io.stderr:write( (err or '')..'\n' )
  io.stderr:write( 'syntax:\n  lua run.lua [debug] [forever] [sleep=none|os|socket] [time=ahsm|os|socket] <fsm.lua>\n' )
  os.exit(1)
end

local ahsm = require 'ahsm'

-- get parameters
if #arg==0 then exit_on_error('Missing parameter') end
local filename = arg[#arg]

for i = 1, #arg-1 do
  local param = arg[i]
  if param == 'debug' then 
    ahsm.debug = require 'tools/debug_plain'.out
  elseif param == 'forever' then 
    forever = true
  else
    local k, v = string.match(param, '^([^=]*)=(.*)$')
    if k and v then
      if not config[k] then
        exit_on_error ('Unknown parameter '..tostring(k))
      end
      config[k] = v 
    else
      exit_on_error ('Error parsing: '..tostring(param))
    end
  end
end

-- initialize libs
local socket
if config.time=='socket' or config.sleep=='socket' then
  socket = require 'socket'
end
if config.time == 'socket' then 
  ahsm.get_time = socket.gettime
elseif config.time == 'os' then 
  ahsm.get_time = os.time
end


-- load hsm
local root = assert(dofile(filename))
local hsm = ahsm.init( root )  -- create fsm from root composite state

-- run hsm
repeat
  local next_t = hsm.loop()
  if config.sleep ~= 'none' then 
    if next_t then
      local dt = next_t-ahsm.get_time()
      if config.sleep == 'os' then 
        if dt>0 and os.execute("sleep "..dt) ~= 0 then break end
      elseif config.sleep == 'socket' then
        socket.sleep(dt)
      end
    end
  end
until (not forever and not next_t)
