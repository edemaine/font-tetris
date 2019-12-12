# svgtiler tile set for simple visualization
pixel = (fill) -> ->
  #g = ["""<rect width="10" height="10" fill="#{fill}" stroke="#{fill}" stroke-width="0.5" />"""]
  g = ["""<rect width="10" height="10" fill="#{fill}" stroke="#{fill}" strok-width="0.1"/>"""]
  if @neighbor(-1, 0).key != @key
    g.push '<line y2="10" stroke="black" stroke-width="2" stroke-linecap="round"/>'
  if @neighbor(0, -1).key != @key
    g.push '<line x2="10" stroke="black" stroke-width="2" stroke-linecap="round"/>'
  if @neighbor(+1, 0).key in [null, undefined, ' ']
    g.push '<line x1="10" x2="10" y2="10" stroke="black" stroke-width="2" stroke-linecap="round"/>'
  if @neighbor(0, +1).key in [null, undefined, ' ']
    g.push '<line y1="10" y2="10" x2="10" stroke="black" stroke-width="2" stroke-linecap="round"/>'
  """
    <symbol viewBox="0 0 10 10">
      <g>
        #{g.join '\n'}
      </g>
    </symbol>
  """
# colors based on Tetris 99 colors, but with different saturation and lightness
I: pixel 'hsl(180,75%,50%)' # cyan
O: pixel 'hsl(60 ,75%,50%)' # yellow
S: pixel 'hsl(120,75%,50%)' # green
Z: pixel 'hsl(0  ,75%,50%)' # red
T: pixel 'hsl(300,75%,50%)' # purple/magenta
L: pixel 'hsl(30 ,75%,50%)' # orange
J: pixel 'hsl(240,75%,50%)' # blue
' ': '<svg viewBox="0 0 10 10"></svg>'
