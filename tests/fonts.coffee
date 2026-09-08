assert = require 'node:assert/strict'
fs = require 'node:fs'
path = require 'node:path'
vm = require 'node:vm'
test = require 'node:test'
coffee = require 'coffeescript'
pieces = require '../pieces.coffee'

root = path.resolve __dirname, '..'
source = (file) => fs.readFileSync path.join(root, file), 'utf8'
generator = coffee.compile source('allfont.coffee'), bare: true

# Exercise the actual generator without changing source or generated files.
generate = (sources) =>
  output = {}
  warnings = []
  input = if sources?
    readdirSync: (dir) =>
      if dir == '.'
        ({name, isDirectory: => true} for name of sources)
      else
        Object.keys sources[dir]
    readFileSync: (file) => sources[path.dirname(file)][path.basename(file)]
  else
    readdirSync: (dir, options) => fs.readdirSync path.join(root, dir), options
    readFileSync: (file, options) => fs.readFileSync path.join(root, file), options
  input.writeFileSync = (file, text) => output[file] = text
  error = null
  try
    vm.runInNewContext generator,
      require: (name) =>
        switch name
          when 'fs' then input
          when './pieces' then pieces
          else require name
      console: {log: =>, warn: (message) => warnings.push message}
  catch caught
    error = caught
  fonts = JSON.parse output['fonts.js'][12..] if output['fonts.js']?
  {fonts, output, warnings, error}

test 'CRLF, LF, and absent final newline produce the same font', =>
  expected = generate fontI: {'A.asc': '0000\n1111\n'}
  assert.equal expected.error, null
  assert.deepEqual expected.warnings, []
  for text in ['0000\r\n1111\r\n', '0000\n1111']
    actual = generate fontI: {'A.asc': text}
    assert.equal actual.error, null
    assert.deepEqual actual.fonts, expected.fonts

test 'invalid selected glyphs cannot overwrite the runtime bundle', =>
  for text, message of {
    '00000': /has 5 cells/
    '000': /has 3 cells/
    '00\n00': /not a rotated I/
    '': /Empty glyph/
    'aa\nbb\naa\nbb': /Cyclic dependencies/
  }
    actual = generate fontI: {'A.asc': text}
    assert.match actual.error?.message ? '', message
    assert.equal actual.fonts, undefined
    assert.match actual.output['allfont.html'], /<img[^>]*class="[^"]*\binvalid\b/
  actual = generate font7: {'A.asc': 'xxxx'}
  assert.match actual.error?.message ? '', /Unknown piece type x/

test 'invalid alternatives are diagnostic only', =>
  actual = generate fontI: {'A.asc': '0000', 'A1.asc': '00000'}
  assert.equal actual.error, null
  assert.deepEqual Object.keys(actual.fonts.I.glyphs), ['A']
  assert.match actual.warnings.join('\n'), /A1.asc: Piece 0 has 5 cells/

test 'stability warnings flag unsupported pieces, not disconnected components', =>
  unsupported = generate fontI: {'A.asc': '0000\n\n1111'}
  assert.match unsupported.warnings.join('\n'), /Unsupported pieces 0/
  assert.equal unsupported.warnings.length, 2
  detached = generate fontI: {'A.asc': '0000  1111'}
  assert.equal detached.error, null
  assert.deepEqual detached.warnings, []
  assert.doesNotMatch detached.output['allfont.html'], /disconnected/i
  corner = generate fontI: {'A.asc': '0000\n    1111'}
  assert.equal corner.warnings.length, 2
  assert.match corner.warnings[0], /Unsupported pieces 0/

test 'final unsupported-piece warning summarizes selected glyphs only', =>
  actual = generate fontI:
    'A.asc': '0000\n\n1111'
    'B1.asc': '0000\n\n1111'
  assert.equal actual.error, null
  summary = actual.warnings[actual.warnings.length-1]
  assert.match summary, /\*\*\* WARNING: UNSUPPORTED PIECES IN SELECTED GLYPHS \*\*\*/
  assert.match summary, /A\.asc: Unsupported pieces 0/
  assert.doesNotMatch summary, /B1\.asc/
  alternatives = generate fontI:
    'A.asc': '0000'
    'B1.asc': '0000\n\n1111'
  assert.equal alternatives.warnings.length, 1
  assert.doesNotMatch alternatives.warnings[0], /SELECTED GLYPHS/

test 'selected heights are unique, numerically sorted, and exclude alternatives', =>
  sources = fontI:
    'A.asc': '0000\n1111'
    'B.asc': '0000\n1111'
    'A1.asc': '0\n0\n0\n0'
  uniform = generate sources
  assert.equal uniform.error, null
  assert.deepEqual uniform.warnings, []
  assert.match uniform.output['allfont.html'], /<p>Selected glyph heights: 2<\/p>/
  sources.fontI['C.asc'] = (id.repeat(4) for id in '0123456789ab').join '\n'
  mixed = generate sources
  assert.equal mixed.error, null
  assert.deepEqual mixed.warnings, ['I: Selected glyph heights: 2, 12 (inconsistent heights)']
  assert.match mixed.output['allfont.html'], /<p>Selected glyph heights: 2, 12 \(inconsistent heights\)<\/p>/

test 'gallery glyphs use a fixed scale across heights and fonts', =>
  stack = (n) => (id.repeat(4) for id in '0123456789abcdef'[...n]).join '\n'
  actual = generate
    fontI: {'A.asc': stack(8), 'B.asc': stack(10), 'A1.asc': stack(16)}
    fontI2: {'A.asc': stack(12)}
  assert.equal actual.error, null
  for [file, height] in [['fontI/A', 48], ['fontI/B', 60], ['fontI/A1', 96], ['fontI2/A', 72]]
    assert.ok actual.output['allfont.html'].includes "src=\"#{file}.svg\" height=\"#{height}\""
  assert.match actual.output['allfont.html'], /vertical-align: bottom/
  assert.doesNotMatch actual.output['allfont.html'], /<img[^>]*class="[^"]*\b(tall|halfgrid)\b/

test 'legacy half-grid glyphs scale and validate as full-size tetrominoes', =>
  actual = generate font7:
    'A.asc': 'IIII'
    'B.asc': 'IIIIIIII\nIIIIIIII'
    'C.asc': 'II\nII\nII\nII\nII\nII\nII\nII'
    'D.asc': ' IIIIIIII\n IIIIIIII'
  assert.equal actual.error, null
  assert.deepEqual actual.fonts['7'].glyphs.A, actual.fonts['7'].glyphs.B
  assert.equal actual.fonts['7'].glyphs.C.height, 4
  assert.equal actual.fonts['7'].glyphs.C.width, 1
  assert.equal actual.fonts['7'].glyphs.D.placements[0].tx, 0.5
  assert.match actual.output['allfont.html'], /src="font7\/B.svg" height="6" class="tall halfgrid"/
  # Cell count detects the scale, but does not excuse an incorrect shape.
  invalid = generate font7: {'A.asc': 'IIII\nIIII\nIIII\nIIII'}
  assert.match invalid.error?.message ? '', /not a rotated I/
  monotype = generate fontI: {'A.asc': '00000000\n00000000'}
  assert.match monotype.error?.message ? '', /has 16 cells, expected 4/
  repository = generate()
  assert.doesNotMatch repository.warnings.join('\n'), /A1.asc: Piece .*expected 4/
  assert.match repository.output['allfont.html'], /src="font7\/A1.svg" height="48" class="halfgrid(?: unstable)?"/

test 'all eight alphabets export complete placements and backward dependencies', =>
  actual = generate()
  assert.equal actual.error, null
  html = actual.output['allfont.html']
  assert.doesNotMatch html, /<details\b|pieces7\//
  assert.ok html.includes 'font7/A.svg'
  assert.deepEqual Object.keys(actual.fonts).sort(), ['7', 'I', 'I2', 'J', 'L', 'S', 'T', 'Z']
  for id, font of actual.fonts
    for char in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
      assert.ok font.glyphs[char], "Missing #{id}/#{char}"
    for char, glyph of font.glyphs
      assert.ok glyph.width > 0 and glyph.height > 0
      assert.ok glyph.placements.length > 0
      for placement, index in glyph.placements
        assert.ok Number.isInteger(placement.r) and placement.r in [0, 90, 180, 270]
        assert.ok Number.isFinite placement.tx
        assert.ok Number.isFinite placement.ty
        assert.ok pieces[font.pieceType ? placement.type]
        assert.equal 'type' of placement, not font.pieceType?
        for dep in placement.deps
            assert.ok Number.isInteger(dep) and 0 <= dep < index

test 'runtime polygons reproduce every selected ASCII cell exactly', =>
  # Rasterize the renderer's polygons independently of the compiler's shapes.
  cells = {}
  for type, {polygon} of pieces
    cells[type] = []
    for y in [0...4]
      for x in [0...4]
        inside = false
        for [x1, y1], i in polygon
          [x2, y2] = polygon[(i+1) % polygon.length]
          if (y1 > y+0.5) != (y2 > y+0.5) and
             x+0.5 < (x2-x1)*(y+0.5-y1)/(y2-y1)+x1
            inside = not inside
        cells[type].push [x, y] if inside
  for id, font of generate().fonts
    for char, glyph of font.glyphs
      filename = if char == '?' then 'question' else char
      ascii = source "font#{id}/#{filename}.asc"
      expected = []
      for line, y in ascii.split /\r?\n/
        for cell, x in line when cell != ' '
          expected.push "#{x},#{y}"
      actual = []
      for placement in glyph.placements
        type = font.pieceType ? placement.type
        [cx, cy] = pieces[type].center
        for [x, y] in cells[type]
          x -= cx-0.5
          y -= cy-0.5
          for rotation in [0...placement.r] by 90
            [x, y] = [-y, x]
          actual.push "#{x+cx-0.5+placement.tx},#{y+cy-0.5+placement.ty}"
      assert.deepEqual actual.sort(), expected.sort(), "#{id}/#{char}"

test 'randomized runtime order respects dependencies', =>
  runtime = source('index.coffee').split('orderLetter = ')[1].split('\ndrawLetter = ')[0]
  orderLetter = vm.runInNewContext coffee.compile("orderLetter = #{runtime}\norderLetter", bare: true)
  for id, font of generate().fonts
    for char, glyph of font.glyphs
      for repeat in [0...5]
        order = Array.from orderLetter glyph
        assert.equal new Set(order).size, glyph.placements.length
        for index, position in order
          for dep in glyph.placements[index].deps
            assert.ok order.indexOf(dep) < position, "#{id}/#{char}"

test 'inline font switches preserve spacing, dropdown state, and animation snapshots', =>
  runtime = source('index.coffee').split('updateText = ')[1].split('\n## Based on meouw')[0]
  code = coffee.compile "waiting = []\nround = 0\nupdateText = #{runtime}\nupdateText", bare: true
  fonts = generate().fonts
  render = (text, options = {}) =>
    state = Object.freeze {text, font: '7', anim: false, puzzle: false, ...options}
    drawn = []
    context =
      window: {fonts}
      updateLink: =>
      statusGIF: =>
      margin: 1
      headRoom: 3
      charKern: => 1
      charSpace: => 3
      lineKern: => 2
      svg: {clear: =>, viewbox: =>}
      drawLetter: (char, svg, snapshot) =>
        entry = {char, state: snapshot}
        drawn.push entry
        glyph = (fonts[snapshot.font] ? fonts['7']).glyphs[char]
        group:
          translate: (x, y) =>
            entry.x = x
            entry.y = y
        x: 0
        y: 0
        width: glyph.width
        height: glyph.height
    update = vm.runInNewContext code, context
    update.call {getState: => state}, {text: true}
    {state, drawn}
  for options in [{}, {anim: true}, {anim: true, puzzle: true}]
    {state, drawn} = render 'A[T]B[i2]C\nD[7]1', options
    assert.deepEqual (entry.char for entry in drawn), ['A', 'B', 'C', 'D', '1']
    assert.deepEqual (entry.state.font for entry in drawn), ['7', 'T', 'I2', 'I2', '7']
    assert.equal state.font, '7'
    for entry in drawn
      assert.equal entry.state.anim, state.anim
      assert.equal entry.state.puzzle, state.puzzle
  tagged = render '[T]A[T][T]B'
  plain = render 'AB', font: 'T'
  assert.deepEqual (entry.x for entry in tagged.drawn), (entry.x for entry in plain.drawn)
  spaced = render '[T]A [I2]B'
  assert.equal spaced.drawn[1].x, fonts.T.glyphs.A.width + 4
  assert.deepEqual (entry.char for entry in render('[T]1[7]1').drawn), ['1']
  assert.deepEqual (entry.char for entry in render('[NOPE]A').drawn), ['N', 'O', 'P', 'E', 'A']
  assert.deepEqual (entry.char for entry in render('[T').drawn), ['T']
  assert.equal render('[T][I2]').drawn.length, 0
  assert.equal render('').drawn.length, 0
  assert.equal render('A', font: 'invalid').drawn.length, 1

test 'diagnostic tiles draw all outside edges, including empty-string neighbors', =>
  mapping = source('svgtileset.coffee').replace 'export default tiles', 'tiles'
  tiles = vm.runInNewContext coffee.compile mapping, bare: true
  for key in [null, undefined, '', ' ']
    svg = tiles['0'].call {key: '0', neighbor: => {key}}
    assert.equal svg.match(/<line /g).length, 4
    assert.match svg, /stroke-width="0.1"/
