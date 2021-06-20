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

## All of these delays are divided by 1.2 ** speed,
## except for loopDelay which stays long.
rotateDelay = 0.3
horizDelay = 0.3
vertDelay = 0.2
pieceDelay = 1
loopDelay = 2 # in addition to pieceDelay

furls = null
svg = null
round = 0
now = 0
anims = []
waiting = []
recording = null

speed = 0
updateSpeed = (s = furls.getState().speed) ->
  s = parseInt s
  s = 0 if isNaN s
  speed = 1.2 ** s

timeout = (ms) -> new Promise (done) -> setTimeout done, ms
simulate = ->
  return unless recording
  await timeout 0  # wait for all animations to start
  before = now
  now = Math.min ...(anim.t for anim in anims when not anim.sync)
  return if now == before
  image = new Image recording.options.width, recording.options.height
  await new Promise (loaded) ->
    image.onload = loaded
    viewbox = svg.viewbox()
    image.src = "data:image/svg+xml,#{svgExplicit svg}"
    ## Size image to target
    .replace /(width=")[^"]*(")/, "$1#{recording.options.width}$2"
    .replace /(height=")[^"]*(")/, "$1#{recording.options.height}$2"
    ## Add white background (Chrome doesn't seem to respect transparency)
    .replace /<svg[^<>]*>/, """$&<rect fill="white" x="#{viewbox.x}" y="#{viewbox.y}" width="#{viewbox.width}" height="#{viewbox.height}"/>"""
  recording.addFrame image,
    copy: true
    delay: now - before
  for anim, i in anims when anim.t == now and not anim.sync
    anim.advance()
    anim.advance = null
sleep = (delay, myAnim) -> new Promise (done) ->
  delay *= 1000
  if recording
    anims[myAnim].t += Math.round delay
    anims[myAnim].advance = done
    simulate()
  else
    setTimeout ->
      updateSpeed()
      done()
    , delay
sync = (myAnim) -> new Promise (done) ->
  #console.log myAnim, anims.length, 'sync', waiting.length
  anims[myAnim].sync = true
  waiting.push done
  if anims.length == waiting.length  # everyone has reached sync
    waiters = waiting
    waiting = []
    waiter() for waiter in waiters
    tMax = Math.max ...(anim.t for anim in anims)
    for anim in anims
      anim.t = tMax
      anim.sync = false
  else
    simulate()

animate = (group, glyph, state) ->
  rotate = state.rotate
  rotate = false if state.puzzle
  myRound = round
  myAnim = anims.length
  numAnim = 1
  numAnim = glyph.order.length if state.puzzle
  updateSpeed state.speed
  for i in [0...numAnim]
    anims.push
      t: 0
      advance: null
  loop
    puzzleY = glyph.height - 3
    jobs = []
    for pieceName, pieceIndex in glyph.order
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
        jobs.push do (pieceIndex, startY, polygon, transform) ->
          for y in [startY..glyph[pieceName].ty]
            await sleep vertDelay / speed, myAnim + pieceIndex unless y == startY
            return unless round == myRound
            transform.translateY = y
            polygon.transform transform
          await sleep pieceDelay / speed, myAnim + pieceIndex
          return unless round == myRound
          await sync myAnim + pieceIndex
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
            await sleep rotateDelay / speed, myAnim unless a == angles[0]
            return unless round == myRound
            transform.rotate = a
            polygon.transform transform
        for x in [startX..glyph[pieceName].tx]
          await sleep horizDelay / speed, myAnim unless x == startX
          return unless round == myRound
          transform.translateX = x
          polygon.transform transform
        for y in [startY..glyph[pieceName].ty]
          await sleep vertDelay / speed, myAnim unless y == startY
          return unless round == myRound
          transform.translateY = y
          polygon.transform transform
        await sleep pieceDelay / speed, myAnim
        return unless round == myRound
    if jobs.length
      await Promise.all jobs
    else
      await Promise.all (sync myAnim + i for i in [0...numAnim])
    return unless round == myRound
    await Promise.all (sleep loopDelay, myAnim + i for i in [0...numAnim])
    return unless round == myRound
    group.clear()
    drawBase group, glyph
    if recording?
      recording.on 'finished', (blob) ->
        statusGIF false, 'Downloading Animated GIF...'
        download = document.getElementById 'download'
        download.href = URL.createObjectURL blob
        download.download = 'tetris.gif'
        download.click()
        statusGIF true, normalStatus
      statusGIF false, 'Processing Animated GIF...'
      recording.render()
      recording = null

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
    animate.call @, group, glyph, state
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
  ## Allow GIF when animating, unless currently downloading
  statusGIF state.anim
  recording = null unless changed.recording
  document.getElementById 'output'
  .className = (
    for setting in ['black', 'floor']
      if state[setting]
        setting
      else
        ''
  ).join ' '
  return unless changed.text or changed.anim or changed.recording or changed.rotate or changed.puzzle
  round++
  waiters = waiting
  waiter() for waiter in waiters  # clear waiters
  #await sleep 0
  now = 0
  anims = []
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
        x += charKern state unless c == 0
        letter = drawLetter.call @, char, svg, state
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

normalStatus = 'Download Animated GIF'
statusGIF = (enable, text) ->
  gifButton = document.getElementById 'downloadGIF'
  if text? or gifButton.innerText == normalStatus
    gifButton.disabled = not enable
    gifButton.innerText = text if text?

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
    download = document.getElementById 'download'
    download.href = URL.createObjectURL \
      new Blob [explicit], type: "image/svg+xml"
    download.download = 'tetris.svg'
    download.click()

  document.getElementById 'downloadGIF'
  ?.addEventListener 'click', ->
    width = parseInt document.getElementById('width').value
    width = 1024 if isNaN(width) or width <= 0
    viewbox = svg.viewbox()
    height = Math.floor width * viewbox.height / viewbox.width
    await import('./node_modules/gif.js/dist/gif.js')
    recording = new GIF
      workerScript: './node_modules/gif.js/dist/gif.worker.js'
      width: width
      height: height
    statusGIF false, 'Rendering Animated GIF...'
    updateText.call furls, recording: true

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
