# Generates allfont.html

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
for pieceName, ascii of pieceASCII
  pieceCells[pieceName] = []
  for row, i in ascii
    for char, j in row when char != ' '
      pieceCells[pieceName].push {i, j, char}
rotateCells = (pieceName, cells) ->
  center = pieceList[pieceName].center
  for {i, j, char} in cells
    # Rotate around center, with 0.5 to translate between vertex and cell coords
    i -= center[1] - 0.5
    j -= center[0] - 0.5
    [i, j] = [j, -i]
    i += center[1] - 0.5
    j += center[0] - 0.5
    {i, j, char}

out = ['''
  <STYLE>
    .pieces img { padding: 5px; border: solid black; }
    img { margin: 10px; }
    .halfgrid, .tall { outline: red solid; }
    .unstable { outline: orange solid; }
  </STYLE>
''']

fonts = [
  title: '7-tetromino font'
  dirname: 'font7'
]

symbols =
  question: '?'

best = (name) -> name.length == 1

for font in fonts
  out.push "\n<H1>#{font.title}</H1>\n"
  out.push "<H2>Current Selection</H2>\n"
  out.push bestLetters = []
  out.push "\n<H2>Alternatives</H2>\n"
  out.push letters = []
  out.push '\n<div class="pieces">'
  pieces = {}
  for piece in ['I', 'O', 'T', 'J', 'L', 'S', 'Z']
    out.push "\n<H2>#{piece}</H2>"
    out.push pieces[piece] = []
  font.out = {} # for font.js

  for filename in fs.readdirSync font.dirname when filename.endsWith '.asc'
    letter = filename[...-4]
    letter = symbols[letter] if letter of symbols
    space = ''
    if best letter
      space = ' '
    pathname = path.join font.dirname, filename
    console.log letter, pathname
    text = fs.readFileSync pathname, encoding: 'utf8'
    lines = text.split '\n'
    lines.pop() if lines[lines.length-1] == ''

    classes = []
    if lines.length not in [8, 16]
      classes.push 'tall'
    if lines.length > 9
      suffix = ' height="80"'
      classes.push 'halfgrid'
    else
      suffix = ''
      pieceSuffix = ''

    # Check stability
    stable = {}
    frontier = []
    for j in [0...lines[lines.length-1].length]
      frontier.push [lines.length, j]
    while frontier.length
      [i, j] = frontier.pop()
      continue if [i, j] of stable
      stable[[i, j]] = true
      if i >= 0
        if lines[i-1]?[j] not in [' ', undefined]
          frontier.push [i-1, j]
      if lines[i]?[j-1] == lines[i]?[j] != undefined
        frontier.push [i, j-1]
      if lines[i]?[j+1] == lines[i]?[j] != undefined
        frontier.push [i, j+1]
      if lines[i+1]?[j] == lines[i]?[j] != undefined
        frontier.push [i+1, j]
    unstable = false
    for line, i in lines
      for char, j in line
        if char != ' ' and not stable[[i,j]]
          unstable = true
    classes.push 'unstable' if unstable

    # Compute piece partial order: which pieces each piece depends on
    partial = {}
    for pieceName of pieceList
      deps = new Set
      for line, i in lines when pieceName in line
        for j in [0...line.length] when line[j] == pieceName
          for i2 in [i+1...lines.length]
            if lines[i2][j] not in [undefined, ' ', pieceName]
              deps.add lines[i2][j]
              break
      partial[pieceName] = Array.from(deps).join ''

    # Compute piece ordering
    order = []
    for which in [0...7]
      for pieceName of pieceList when pieceName not in order
        droppable = true
        for line, i in lines when pieceName in line
          for j in [0...line.length] when line[j] == pieceName
            for i2 in [0...i]
              if lines[i2][j] not in order.concat [undefined, ' ', pieceName]
                droppable = false
        if droppable
          order.push pieceName
          break
    if order.length != 7
      console.warn "Couldn't order #{letter}: #{order}"
    order.reverse()

    if classes.length
      suffix += " class=\"#{classes.join ' '}\""
    letters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>"""
    bestLetters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>""" if best letter

    # Compute translation and rotation for each piece (and verify it's there)
    if best letter
      font.out[letter] =
        order: order
        partial: partial
        height: lines.length
        width: Math.max ...(line.trimRight().length for line in lines)
      for pieceName, piece of pieceList
        cells = pieceCells[pieceName]
        iDelta = (i for line, i in lines when pieceName in line)[0]
        jDelta = Math.min ...(line.indexOf pieceName for line in lines when pieceName in line)
        for rotate in [0...360] by 90
          iMin = Math.min ...(i for {i} in cells)
          jMin = Math.min ...(j for {j} in cells)
          #console.log 'Looking for:', cells, iMin, jMin
          match = true
          for {i, j, char} in cells
            if lines[iDelta+i-iMin]?[jDelta+j-jMin] != char
              match = false
          if match
            font.out[letter][pieceName] =
              r: rotate
              tx: jDelta - jMin
              ty: iDelta - iMin
            break
          cells = rotateCells pieceName, cells
        unless match
          console.warn "No match for #{pieceName} in #{letter}"

    for piece, pieceOut of pieces
      size =
        switch piece
          when 'O' then 2
          when 'I' then 4
          else 3
      if 'halfgrid' in classes
        pieceSuffix = """ style="max-height: #{size*10}; max-width: #{size*10}\""""
      pieceOut.push """<img title="#{letter}"#{space} src="#{font.dirname.replace 'font', 'pieces'}/#{piece}/#{letter}.svg"#{pieceSuffix}>"""
  out.push '\n</div>\n'

  fs.writeFileSync "#{font.dirname}.js", "var font = #{JSON.stringify font.out}"

for part, i in out
  if typeof part != 'string'
    out[i] = part.join '\n'
out = out.join('\n')+'\n'
fs.writeFileSync 'allfont.html', out, encoding: 'utf8'
