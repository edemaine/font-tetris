# Generates allfont.html

fs = require 'fs'
path = require 'path'

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
  for filename in fs.readdirSync font.dirname when filename.endsWith '.asc'
    letter = filename[...-4]
    space = ''
    if letter.length == 1
      space = ' '
    pathname = path.join font.dirname, filename
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

    if classes.length
      suffix += " class=\"#{classes.join ' '}\""
    letters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>"""
    bestLetters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>""" if letter.length == 1

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

for part, i in out
  if typeof part != 'string'
    out[i] = part.join '\n'
out = out.join('\n')+'\n'
fs.writeFileSync 'allfont.html', out, encoding: 'utf8'
