margin = 0.5
charKern = 1
charSpace = 3
lineKern = (state) ->
  #if state.anim
  #  0
  #else
    2
headRoom = 3

horizDelay = 0.2
vertDelay = 0.3
pieceDelay = 1

svg = null

sleep = (delay) -> new Promise (done) -> setTimeout done, delay * 1000

animate = (group, glyph) ->
  for pieceName in glyph.order
    piece = window.pieces[pieceName]
    polygon = group.polygon piece.polygon
    .addClass pieceName
    .transform transform =
      rotate: glyph[pieceName].r
      origin: piece.center
      translateX: startX = Math.floor glyph.width / 2
      translateY: startY = -headRoom
    for x in [startX..glyph[pieceName].tx]
      await sleep horizDelay unless x == 0
      transform.translateX = x
      polygon.transform transform
    for y in [startY..glyph[pieceName].ty]
      await sleep vertDelay unless y == 0
      transform.translateY = y
      polygon.transform transform
    await sleep pieceDelay

drawLetter = (char, svg, state) ->
  group = svg.group()
  glyph = window.font[char]

  if state.anim
    animate group, glyph
  else
    for pieceName in glyph.order
      piece = window.pieces[pieceName]
      #group.polygon piece.polygon
      #.addClass pieceName
      #.transform
      #  translateX: glyph[pieceName].tx
      #  translateY: glyph[pieceName].ty
      group.polygon piece.polygon
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
  document.getElementById 'output'
  .className = (
    for setting in ['black']
      if state[setting]
        setting
      else
        ''
  ).join ' '
  return unless changed.text or changed.anim

  svg.clear()
  y = 0
  xmax = 0
  for line in state.text.split '\n'
    y += headRoom if state.anim
    x = 0
    dy = 0
    row = []
    for char, c in line
      char = char.toUpperCase()
      if char of window.font
        x += charKern unless c == 0
        letter = drawLetter char, svg, state
        letter.group.translate x - letter.x, y - letter.y
        row.push letter
        x += letter.width
        xmax = Math.max xmax, x
        dy = Math.max dy, letter.height
      else if char == ' '
        x += charSpace
    ## Bottom alignment
    #for letter in row
    #  letter.group.dy dy - letter.height
    y += dy + lineKern state
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
