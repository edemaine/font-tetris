margin = 0.5
charKern = 1
charSpace = 3
lineKern = 2

svg = null

drawLetter = (char, svg, state) ->
  group = svg.group()
  glyph = window.font[char]
  for pieceName in glyph.order
    piece = window.pieces[pieceName]
    #group.polygon piece.polygon
    #.addClass pieceName
    #.transform
    #  translateX: glyph[pieceName].tx
    #  translateY: glyph[pieceName].ty
    polygon = group.polygon piece.polygon
    .addClass pieceName
    .transform
      rotate: glyph[pieceName].r
      origin: piece.center
      translateX: glyph[pieceName].tx
      translateY: glyph[pieceName].ty
    # Rotation center:
    #group.circle 1
    #.center piece.center[0] + glyph[pieceName].tx,
    #        piece.center[1] + glyph[pieceName].ty

  group: group
  x: 0
  y: 0
  width: glyph.width
  height: glyph.height

updateText = (changed) ->
  state = @getState()
  svg.clear()
  y = 0
  xmax = 0
  for line in state.text.split '\n'
    x = 0
    dy = 0
    row = []
    for char, c in line
      char = char.toUpperCase()
      if char of window.font
        x += charKern unless c == 0
        letter = drawLetter char, svg, state
        letter.group.move x - letter.x, y - letter.y
        row.push letter
        x += letter.width
        xmax = Math.max xmax, x
        dy = Math.max dy, letter.height
      else if char == ' '
        x += charSpace
    ## Bottom alignment
    #for letter in row
    #  letter.group.dy dy - letter.height
    y += dy + lineKern
  svg.viewbox
    x: -margin
    y: -margin
    width: xmax + 2*margin
    height: y + 2*margin

## Based on meouw's answer on http://stackoverflow.com/questions/442404/retrieve-the-position-x-y-of-an-html-element
getOffset = (el) ->
  x = y = 0
  while el and not isNaN(el.offsetLeft) and not isNaN(el.offsetTop)
    x += el.offsetLeft - el.scrollLeft
    y += el.offsetTop - el.scrollTop
    el = el.offsetParent
  x: x
  y: y

resize = ->
  offset = getOffset document.getElementById('output')
  height = Math.max 100, window.innerHeight - offset.y
  document.getElementById('output').style.height = "#{height}px"

checkAlone = ['unfolded', 'folded']

furls = null
window?.onload = ->
  svg = SVG().addTo '#output'
  .width '100%'
  .height '100%'
  furls = new Furls()
  .addInputs()
  .on 'stateChange', updateText
  .syncState()

  window.addEventListener 'resize', resize
  resize()
