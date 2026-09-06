# Generates fonts.js and allfont.html from the ASCII font sources.

fs = require 'fs'
path = require 'path'
pieceList = require './pieces'

pieceASCII =
  I: ['IIII']
  J: ['J  ',
      'JJJ']
  L: ['  L',
      'LLL']
  O: ['OO',
      'OO']
  S: [' SS',
      'SS ']
  T: [' T ',
      'TTT']
  Z: ['ZZ ',
      ' ZZ']
pieceCells = {}
for pieceType, ascii of pieceASCII
  pieceCells[pieceType] = []
  for row, i in ascii
    for char, j in row when char != ' '
      pieceCells[pieceType].push {i, j}

rotateCells = (pieceType, cells) =>
  center = pieceList[pieceType].center
  for {i, j} in cells
    # Rotate around center, with 0.5 to translate between vertex and cell coords.
    i -= center[1] - 0.5
    j -= center[0] - 0.5
    [i, j] = [j, -i]
    i += center[1] - 0.5
    j += center[0] - 0.5
    {i, j}

# Discover font7 plus homogeneous fonts named fontI, fontI2, fontJ, etc.
entries = fs.readdirSync '.', withFileTypes: true
fontDirs = (entry.name for entry in entries when entry.isDirectory() and
  /^font(?:7|[IJLOSTZ][0-9]*)$/.test entry.name).sort()
fonts = for dirname in fontDirs
  name = dirname[4..]
  id: name
  dirname: dirname
  pieceType: if name == '7' then undefined else name[0]

out = ['''
  <STYLE>
    .pieces img { padding: 5px; border: solid black; }
    img { margin: 10px; vertical-align: bottom; }
    .halfgrid, .tall { outline: red solid; }
    .unstable { outline: orange solid; }
    .invalid { outline: magenta solid; }
  </STYLE>
''']

symbols =
  question: '?'

best = (name) -> name.length == 1
fontData = {}
errors = []

for font in fonts
  heights = new Set
  out.push "\n<H1>#{font.id}</H1>\n"
  out.push "<H2>Current Selection</H2>\n"
  out.push bestLetters = []
  out.push "\n<H2>Alternatives</H2>\n"
  out.push letters = []

  # The old diagnostic gallery splits the mixed font by tetromino type.
  # Monotype sources use their characters as instance IDs, so their useful
  # diagnostic is the composite SVG above instead.
  pieces = null
  unless font.pieceType?
    out.push '\n<details class="pieces"><summary>Individual tetromino checks</summary>'
    pieces = {}
    for pieceType in ['I', 'O', 'T', 'J', 'L', 'S', 'Z']
      out.push "\n<H2>#{pieceType}</H2>"
      out.push pieces[pieceType] = []

  fontData[font.id] =
    pieceType: font.pieceType
    glyphs: glyphs = {}

  for filename in fs.readdirSync font.dirname when filename.endsWith '.asc'
    letter = filename[...-4]
    letter = symbols[letter] if letter of symbols
    space = if best letter then ' ' else ''
    pathname = path.join font.dirname, filename
    console.log font.id, letter, pathname
    text = fs.readFileSync pathname, encoding: 'utf8'
    lines = text.split /\r?\n/
    lines.pop() if lines[lines.length-1] == ''
    heights.add lines.length if best letter
    problems = []

    classes = []
    if lines.length not in [8, 16]
      classes.push 'tall'
    if lines.length > 9
      classes.push 'halfgrid'
    # Use the same six pixels per grid cell for every glyph.
    suffix = " height=\"#{lines.length*6}\""

    # Each nonspace character identifies one physical piece instance.  In a
    # monotype font the font supplies its type; otherwise the ID is the type.
    instances = new Map
    for line, i in lines
      for pieceId, j in line when pieceId != ' '
        instances.set pieceId, [] unless instances.has pieceId
        instances.get(pieceId).push {i, j}
    pieceIds = Array.from instances.keys()
    problems.push 'Empty glyph' unless pieceIds.length
    # Compute vertical precedence constraints between piece instances.
    dependencies = {}
    for pieceId in pieceIds
      deps = new Set
      for {i, j} in instances.get pieceId
        for i2 in [i+1...lines.length]
          if lines[i2][j] not in [undefined, ' ', pieceId]
            deps.add lines[i2][j]
            break
      dependencies[pieceId] = Array.from deps

    # Find one valid construction order, from bottom to top, by repeatedly
    # removing a piece with nothing remaining above it.
    order = []
    remaining = pieceIds[..]
    while remaining.length
      next = remaining.find (pieceId) =>
        remaining.every (other) =>
          pieceId not in dependencies[other]
      break unless next?
      order.unshift next
      remaining.splice remaining.indexOf(next), 1
    if order.length != pieceIds.length
      problems.push "Cyclic dependencies among pieces #{remaining.join ', '}"

    # Compute translation and rotation for each physical piece.
    transforms = {}
    for pieceId in pieceIds
      type = font.pieceType ? pieceId
      unless type of pieceList
        problems.push "Unknown piece type #{type}"
        continue
      actual = instances.get pieceId
      unless actual.length == 4
        problems.push "Piece #{pieceId} has #{actual.length} cells, expected 4"
        continue
      cells = pieceCells[type]
      iDelta = Math.min ...(i for {i} in actual)
      jDelta = Math.min ...(j for {j} in actual)
      for rotate in [0...360] by 90
        iMin = Math.min ...(i for {i} in cells)
        jMin = Math.min ...(j for {j} in cells)
        match = cells.every ({i, j}) =>
          lines[iDelta+i-iMin]?[jDelta+j-jMin] == pieceId
        if match
          transforms[pieceId] =
            r: rotate
            tx: jDelta - jMin
            ty: iDelta - iMin
          break
        cells = rotateCells type, cells
      problems.push "Piece #{pieceId} is not a rotated #{type}" unless match

    if problems.length
      classes.push 'invalid'
      for problem in problems
        message = "#{pathname}: #{problem}"
        console.warn message
        errors.push message if best letter
    else
      # In construction order, every piece must touch the floor or a stable
      # piece immediately below it.  A dependency across a gap is not support.
      stable = new Set
      for pieceId in order
        supported = instances.get(pieceId).some ({i, j}) =>
          i == lines.length-1 or stable.has lines[i+1]?[j]
        stable.add pieceId if supported
      if stable.size != pieceIds.length
        classes.push 'unstable'
        console.warn "#{pathname}: Unsupported pieces #{(id for id in pieceIds when not stable.has id).join ', '}"

    if best(letter) and not problems.length
      index = {}
      index[pieceId] = i for pieceId, i in order
      placements = for pieceId in order
        {
          ...transforms[pieceId]
          type: if font.pieceType? then undefined else pieceId
          deps: (index[dep] for dep in dependencies[pieceId])
        }
      glyphs[letter] =
        placements: placements
        height: lines.length
        width: Math.max ...(line.trimRight().length for line in lines)

    if classes.length
      suffix += " class=\"#{classes.join ' '}\""
    letters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>"""
    bestLetters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>""" if best letter

    if pieces?
      for type, pieceOut of pieces
        size = switch type
          when 'O' then 2
          when 'I' then 4
          else 3
        pieceSuffix = if 'halfgrid' in classes
          """ style="max-height: #{size*10}px; max-width: #{size*10}px\""""
        else
          ''
        pieceOut.push """<img title="#{letter}"#{space} src="#{font.dirname.replace 'font', 'pieces'}/#{type}/#{letter}.svg"#{pieceSuffix}>"""
  out.push '\n</details>\n' if pieces?
  heights = Array.from(heights).sort (a, b) => a-b
  heightSummary = "Selected glyph heights: #{heights.join ', '}"
  heightSummary += ' (inconsistent heights)' if heights.length > 1
  bestLetters.unshift "<p>#{heightSummary}</p>"
  if heights.length > 1
    console.warn "#{font.id}: #{heightSummary}"
  else
    console.log "#{font.id}: #{heightSummary}"

for part, i in out
  out[i] = part.join '\n' unless typeof part == 'string'
fs.writeFileSync 'allfont.html', out.join('\n')+'\n', encoding: 'utf8'
throw new Error "Invalid selected glyphs:\n#{errors.join '\n'}" if errors.length
fs.writeFileSync 'fonts.js', "var fonts = #{JSON.stringify fontData}", encoding: 'utf8'
