
local lines = {}
local a = function(s)
  lines[#lines+1] = s
end

local function get_counter(start)
  local count = (start or 1)-1
  return function()
    count = count+1
    return count
  end
end

local inital_s_counter = get_counter()

local function draw_state (root)
  local names = {}

  for name, s in pairs(root.states) do
    names[s] = name
    if s.states then
      a( 'subgraph cluster_'..name..' {' )
      a( 'label = "'..name..'";' )
      a( 'style = rounded;' )
      a( 'fontsize = 12;' )
      a( '__DUMMY_'..name..' [shape=point style=invis];' )
      draw_state(s)
      a '}'
    else
      a( 'node [label="'..name..'",shape=circle,fontsize=12] ' ..name..';' )
    end
  end

  if root.initial then
    local initial_s_name = '__initial'..tostring(inital_s_counter())
    a( 'node [shape = point style=invis] '..initial_s_name..';' )
    a( initial_s_name..' -> '..names[root.initial] ..' [weight=1000];' )
  end

  for name, e in pairs(root.events or {}) do
    if type(name)~='string' and type(e)=='string' then 
      names[e] = e
    else 
      names[e] = name
    end
  end

  for name, t in pairs(root.transitions) do
    local elist, comma = '[', ''
    for _, e in pairs (t.events) do
      if names[e] then 
        elist, comma = elist..comma..names[e], ','
      elseif e==t.src.EV_DONE then
        elist, comma = elist..comma..'DONE', ','
      end
    end
    if t.timeout then
      elist, comma = elist..comma..'T='..t.timeout, ','
    end
    elist = elist..']'


    local ltail, lhead
    local source, target
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
    local lname=''
    if type(name)=='string' then
      lname=name
    end
    --local link = source .. ' -> '..target..' [label="'..name..elist..'"'
    local link = source .. ' -> '..target..' [fontsize=10,label="'..lname..elist..'"'
    if ltail or lhead then
      local comma = ''
      if ltail and lhead then comma = ',' end
      link = link .. ','..(ltail or '')..comma..(lhead or '')
    end
    a( link..'];' )
  end
end


local F=function(root)
  a 'digraph G {'
  a 'compound=true;'
  draw_state (root)
  a '}'
  return table.concat( lines, '\n' )
end



return F