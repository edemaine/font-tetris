margin = 1.1 # for I + stroke to not fall outside
charKern = 1
charSpace = 3
lineKern = (state) ->
  #if state.anim
  #  0
  #else
    2
headRoom = 3

rotateDelay = 0.3
horizDelay = 0.2
vertDelay = 0.3
pieceDelay = 1
loopDelay = 1 # in addition to pieceDelay

svg = null
round = 0
anims = 0
waiting = []

sleep = (delay) -> new Promise (done) -> setTimeout done, delay * 1000
sync = -> new Promise (done) ->
  waiting.push done
  if anims == waiting.length  # everyone has reached sync
    waiters = waiting
    waiting = []
    for waiter in waiters
      waiter()

animate = (group, glyph, state) ->
  myRound = round
  anims++
  loop
    for pieceName in glyph.order
      angle = glyph[pieceName].r
      angle = -90 if angle == 270
      piece = window.pieces[pieceName]
      polygon = group.polygon piece.polygon
      .addClass pieceName
      .transform transform =
        rotate: startAngle = (1 - state.rotate) * angle
        origin: piece.center
        translateX: startX = Math.floor glyph.width / 2 - 1
        translateY: startY = -headRoom
      if startAngle == 0 and angle == 180
        angles = [0, 90, 180]
      else if startAngle != angle
        angles = [startAngle, angle]
      else
        angles = [startAngle]
      if angles.length > 1
        for a in angles
          await sleep rotateDelay unless a == 0
          return unless round == myRound
          transform.rotate = a
          polygon.transform transform
      for x in [startX..glyph[pieceName].tx]
        await sleep horizDelay unless x == 0
        return unless round == myRound
        transform.translateX = x
        polygon.transform transform
      for y in [startY..glyph[pieceName].ty]
        await sleep vertDelay unless y == 0
        return unless round == myRound
        transform.translateY = y
        polygon.transform transform
      await sleep pieceDelay
      return unless round == myRound
    await sync()
    await sleep loopDelay
    return unless round == myRound
    group.clear()

drawLetter = (char, svg, state) ->
  group = svg.group()
  glyph = window.font[char]

  if state.anim
    animate group, glyph, state
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
  return unless changed.text or changed.anim or changed.rotate
  round++
  anims = 0
  waiter() for waiter in waiting  # clear waiters
  waiting = []

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
