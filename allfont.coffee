# Generates allfont.html

fs = require 'fs'
path = require 'path'

out = ['''
  <STYLE>
    .pieces img { padding: 5px; border: solid black; }
    img { margin: 10px; }
    .halfgrid { outline: red solid; }
  </STYLE>
''']

fonts = [
  title: '7-tetromino font'
  dirname: 'font7'
]

for font in fonts
  out.push "\n<H1>#{font.title}</H1>\n"
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
    if lines.length > 9
      console.assert lines.length == 16, "#{pathname} not 16 lines"
      suffix = ' height="80" class="halfgrid"'
    else
      console.assert lines.length in [8, 9], "#{pathname} not 8 or 9 lines"
      suffix = ''
      pieceSuffix = ''
    letters.push """<img title="#{letter}"#{space} src="#{font.dirname}/#{letter}.svg"#{suffix}>"""
    for piece, pieceOut of pieces
      size =
        switch piece
          when 'O' then 2
          when 'I' then 4
          else 3
      if suffix
        pieceSuffix = """ style="max-height: #{size*10}; max-width: #{size*10}\""""
      pieceOut.push """<img title="#{letter}"#{space} src="#{font.dirname.replace 'font', 'pieces'}/#{piece}/#{letter}.svg"#{pieceSuffix}>"""
  out.push '\n</div>\n'

for part, i in out
  if typeof part != 'string'
    out[i] = part.join '\n'
out = out.join('\n')+'\n'
fs.writeFileSync 'allfont.html', out, encoding: 'utf8'
