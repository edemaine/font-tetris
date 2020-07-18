margin = 1.1 # for I + stroke to not fall outside
baseOutset = 0.9 # smaller than 1 to avoid overlapping stroke-linecap
baseOutsetPuzzle = 1.1 # larger than to guarantee overlap
charKern = (state) ->
  if state.puzzle
    2
  else
    1
charSpace = (state) ->
  if state.puzzle
    4
  else
    3
lineKern = (state) ->
  #if state.anim
  #  0
  #else
  if state.puzzle
    4
  else
    2
headRoom = 3

rotateDelay = 0.3
horizDelay = 0.3
vertDelay = 0.2
pieceDelay = 1
loopDelay = 2 # in addition to pieceDelay

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
    waiter() for waiter in waiters

animate = (group, glyph, state) ->
  rotate = state.rotate
  rotate = false if state.puzzle
  myRound = round
  anims++
  loop
    puzzleY = glyph.height - 3
    jobs = []
    for pieceName in glyph.order
      angle = glyph[pieceName].r
      angle = -90 if angle == 270
      startAngle = (1 - rotate) * angle
      if state.puzzle
        startX = glyph[pieceName].tx
        startY = puzzleY
      else
        startX = Math.floor glyph.width / 2 - 1
        startY = -headRoom
      piece = window.pieces[pieceName]
      polygon = group.polygon piece.polygon
      .addClass pieceName
      .transform transform =
        rotate: startAngle
        origin: piece.center
        translateX: startX
        translateY: startY
      if state.puzzle
        jobs.push do (startY, polygon, transform) ->
          for y in [startY..glyph[pieceName].ty]
            await sleep vertDelay unless y == startY
            return unless round == myRound
            transform.translateY = y
            polygon.transform transform
          await sleep pieceDelay
          return unless round == myRound
        puzzleY -= 4 # mimic drawLetter in puzzle mode
      else
        if startAngle == 0 and angle == 180
          angles = [0, 90, 180]
        else if startAngle != angle
          angles = [startAngle, angle]
        else
          angles = [startAngle]
        if angles.length > 1
          for a in angles
            await sleep rotateDelay unless a == angles[0]
            return unless round == myRound
            transform.rotate = a
            polygon.transform transform
        for x in [startX..glyph[pieceName].tx]
          await sleep horizDelay unless x == startX
          return unless round == myRound
          transform.translateX = x
          polygon.transform transform
        for y in [startY..glyph[pieceName].ty]
          await sleep vertDelay unless y == startY
          return unless round == myRound
          transform.translateY = y
          polygon.transform transform
        await sleep pieceDelay
        return unless round == myRound
    await job for job in jobs
    return unless round == myRound
    await sync()
    return unless round == myRound
    await sleep loopDelay
    return unless round == myRound
    group.clear()
    drawBase group, glyph

drawBase = (group, glyph, dy = 0, outset = baseOutset) ->
  group.rect glyph.width + 2*outset, 0.5
  .x -outset
  .y glyph.height + dy
  .addClass 'base'

drawLetter = (char, svg, state) ->
  group = svg.group()
  glyph = window.font[char]
  y = 0

  drawBase group, glyph, (if state.puzzle and not state.anim then -5),
    if state.puzzle then baseOutsetPuzzle else baseOutset
  if state.anim
    animate group, glyph, state
    if state.puzzle
      y = -4 * glyph.order.length + glyph.height
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
        translateY:
          if state.puzzle
            y
          else
            glyph[pieceName].ty
      # Rotation center:
      #group.circle 0.5
      #.center piece.center[0] + glyph[pieceName].tx,
      #        piece.center[1] + glyph[pieceName].ty
      y -= 4 if state.puzzle

  group: group
  x: 0
  y: y
  width: glyph.width
  height:
    if state.puzzle
      if state.anim
        -y + glyph.height - 3
      else
        -y
    else
      glyph.height

updateLink = (state) ->
  if (link = document.getElementById 'link') and
     (href = link.getAttribute 'data-href')
    href = href.replace /TEXT/, state.text
    link.setAttribute 'href', href

updateText = (changed) ->
  state = @getState()
  updateLink state
  document.getElementById 'output'
  .className = (
    for setting in ['black', 'floor']
      if state[setting]
        setting
      else
        ''
  ).join ' '
  return unless changed.text or changed.anim or changed.rotate or changed.puzzle
  round++
  waiters = waiting
  waiter() for waiter in waiters  # clear waiters
  #await sleep 0
  waiting = []
  anims = 0

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
        x += charKern state unless c == 0
        letter = drawLetter char, svg, state
        letter.group.translate x - letter.x, y - letter.y
        row.push letter
        x += letter.width
        xmax = Math.max xmax, x
        dy = Math.max dy, letter.height
      else if char == ' '
        x += charSpace state
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

svgPrefixId = (svg, prefix = 'N') ->
  svg.replace /\b(id\s*=\s*")([^"]*")/gi, "$1#{prefix}$2"
  .replace /\b(xlink:href\s*=\s*"#)([^"]*")/gi, "$1#{prefix}$2"

svgExplicit = (svg) ->
  explicit = SVG().addTo '#output'
  try
    explicit.svg svgPrefixId svg.svg()
    ## Expand CSS for <rect>, <line>, <polygon>
    explicit.find 'rect, line, polygon'
    .each ->
      style = window.getComputedStyle @node
      @css 'fill', style.fill
      @css 'stroke', style.stroke
      @css 'stroke-width', style.strokeWidth
      @css 'stroke-linecap', style.strokeLinecap
      @remove() if style.visibility == 'hidden'
    explicit.svg()
    ## Remove surrounding <svg>...</svg> from explicit SVG container
    .replace /^<svg[^<>]*>/, ''
    .replace /<\/svg>$/, ''
  finally
    explicit.remove()

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

  document.getElementById 'downloadSVG'
  ?.addEventListener 'click', ->
    explicit = svgExplicit svg
    document.getElementById('download').href = URL.createObjectURL \
      new Blob [explicit], type: "image/svg+xml"
    document.getElementById('download').download = 'tetris.svg'
    document.getElementById('download').click()

  for pieceName, piece of window.pieces
    return unless document.getElementById "piece#{pieceName}"
    width = Math.max ...(x for [x,y] in piece.polygon)
    height = Math.max ...(y for [x,y] in piece.polygon)
    x = SVG().addTo "#piece#{pieceName}"
    .viewbox -0.1, -0.1, width+0.2, height+0.2
    .width width*8
    .height height*8
    .polygon piece.polygon
    .addClass pieceName
