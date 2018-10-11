--- dot graph exporter.
-- Creates a dot drawing of the hsm.
--@alias M

local ahsm = require 'ahsm'

local a 

local function get_counter(start)
  local count = (start or 1)-1
  return function()
    count = count+1
    return count
  end
end

local inital_s_counter = get_counter()

local names = {}

local function draw_transition(name, t)
  --events
  local elist = '['
  do
    local comma = ''
    for _, e in pairs (t.events) do
      if names[e] then 
        elist, comma = elist..comma..names[e], ','
      elseif e==t.src.EV_DONE then
        elist, comma = elist..comma..'EV_DONE', ','
      end
    end
    if t.timeout then
      elist, comma = elist..comma..'T='..t.timeout, ','
    end
    elist = elist..']'
  end
  --for composits
  local ltail, lhead, source, target
  do
    if t.src.states then
      source = '__DUMMY_'..names[t.src]
      ltail = 'ltail=cluster_'..names[t.src]
    else
      source = names[t.src]
    end
    if t.tgt.states then
      target = '__DUMMY_'..names[t.tgt]
      ltail = 'lhead=cluster_'..names[t.tgt]
    else
      target = names[t.tgt]
    end
  end
  --name
  local lname=''
  do
    if type(name)=='string' then
      lname=name
    end
  end
  --effect label
  local leffectguard = ''
  do
    local comma = '\n'
    for _, fname in ipairs {'guard', 'effect'} do
      if t[fname] then 
        leffectguard = leffectguard .. comma .. fname
        comma = ','
      end
    end
  end
  --build link
  local link = source .. ' -> '..target..' [fontsize=10,label="'..lname..elist..leffectguard..'"'
  if ltail or lhead then
    local comma = ''
    if ltail and lhead then comma = ',' end
    link = link .. ','..(ltail or '')..comma..(lhead or '')
  end
  a( link..'];' )
end


local function draw_state (root)
  for name, s in pairs(root.states) do
    names[s] = name    

    local is_final = true
    for _, t in pairs(root.transitions) do
      if t.src==s then 
        is_final=false
        break
      end
    end

    local namelabel = '{'..name..'}'
    local comma = '\n'
    for _, fname in ipairs {'entry', 'exit', 'doo'} do
      if s[fname] then 
        namelabel = namelabel .. comma .. fname
        comma = ','
      end
    end   

    if s.states then
      a( 'subgraph cluster_'..name..' {' )
      a( 'label = "'..namelabel..'";' )
      if is_final then 
        a 'style="rounded,bold,filled";'
      else
        a( 'style="rounded,filled";' )
      end
      if root.current_substate==s then
        a 'fillcolor=yellow;'
      else
        a 'fillcolor=white;'
      end
      a( 'fontsize = 12;' )
      a( '__DUMMY_'..name..' [shape=point style=invis];' )
      draw_state(s)
      a '}'
    else
      local shape='circle'
      if is_final then shape='doublecircle' end
      local activestyle = ''
      if root.current_substate==s then 
        activestyle = ',fillcolor=yellow,style=filled'
      else
        activestyle = ',fillcolor=white,style=filled'
      end
      a( 'node [label="'..namelabel..'",shape='..shape
        ..activestyle..',fontsize=12] ' ..name..';' )
    end
  end

  if root.initial then
    local initial_s_name = '__initial'..tostring(inital_s_counter())
    a( 'node [shape = point,fillcolor=black] '..initial_s_name..';' )
    a( initial_s_name..' -> '..names[root.initial] ..' [weight=1000, len=0.2];' )
  end

  for name, e in pairs(root.events or {}) do
    if type(name)~='string' and type(e)=='string' then 
      names[e] = e
    else 
      names[e] = name
    end
  end

  for name, t in pairs(root.transitions) do
    --event list
    draw_transition(name, t)
  end
end

local process=function(root)
  a 'digraph G {'
  a 'compound=true;'
  draw_state (root)
  a '}'
end

local to_function = function(root, f)
  a = f
  process(root)
end

local to_string = function(root)
  local lines = {}
  to_function( root, function(s) lines[#lines+1] = s end )
  return table.concat( lines, '\n' )
end

local to_file = function(root, filename)
  local f, err = io.open(filename, 'w')
  if not f then return nil, err end
  to_function( root, function(s) f:write(s, '\n') end )
  f:close()
  return true
end

local M = {
--- Generate dot string.
-- @param root The root state of the hsm.
-- @param root The root state of the hsm.
-- @return A string with the dot description.
  to_string = to_string,

--- Write dot to file.
-- @param root The root state of the hsm.
-- @param filename the name of the file to write to.
-- @return true on success.
-- @return nil, message on failure
  to_file = to_file,

--- Write dot using function.
-- @param root The root state of the hsm.
-- @param f the name of the file to write to.
  to_function = to_function,
}

return M