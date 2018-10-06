
local lines = {}
local a = function(s)
  lines[#lines+1] = s
end

local names = {}

local function draw_state (root)

  for name, s in pairs(root.states) do
    names[s] = name
    if s.states then
      a( 'subgraph cluster_'..name..' {' )
      a( 'label = "'..name..'";' )
      a( 'DUMMY_'..name..' [shape=point style=invis];' )
      if s == root.initial then 
        a 'style="filled";'
        a 'color="lightgrey";'      
      end
      draw_state(s)
      a '}'
    else
      local style = ''
      if s == root.initial then
        style = 'style="filled",color="lightgrey";'
      end
      a( 'node [label="'..name..'"'..style..'] ' ..name..';' )
      end
    end

    for name, t in pairs(root.transitions) do
      local ltail, lhead
      local source, target
      if t.src.states then
        source = 'DUMMY_'..names[t.src]
        ltail = 'ltail=cluster_'..names[t.src]
      else
        source = names[t.src]
      end
      if t.tgt.states then
        target = 'DUMMY_'..names[t.tgt]
        ltail = 'lhead=cluster_'..names[t.tgt]
      else
        target = names[t.tgt]
      end
      local link = source .. ' -> '..target..' [label="'..name ..'"'
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