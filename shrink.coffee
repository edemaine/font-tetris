# Shrink 2x2 scaled files down to 1x1

fs = require 'fs'
path = require 'path'

dirname = process.argv[2]
for filename in fs.readdirSync dirname when filename.endsWith 'asc'
  pathname = path.join dirname, filename
  text = fs.readFileSync pathname, encoding: 'utf8'
  lines = text.split '\n'
  lines.pop() if lines[lines.length-1] == ''
  get = (row, col) ->
    (lines[row] ? [])[col] ? ' '
  nRows = lines.length
  nCols = Math.max ...(line.length for line in lines)
  nRows = 2 * Math.ceil nRows / 2
  nCols = 2 * Math.ceil nCols / 2
  valid = true
  for row in [0...nRows] by 2
    for col in [0...nCols] by 2
      unless get(row, col) == get(row+1, col) == get(row, col+1) == get(row+1, col+1)
        valid = false
        break
    break unless valid
  console.log pathname, valid
  if valid
    out =
      (for row in [0...nRows] by 2
        (for col in [0...nCols] by 2
          get(row, col)
        ).join ''
      ).join('\n') + '\n'
    console.log out
    fs.writeFileSync pathname, out, encoding: 'utf8'
