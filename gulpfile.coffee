gulp = require 'gulp'
gulpCoffee = require 'gulp-coffee'
gulpPug = require 'gulp-pug'
gulpChmod = require 'gulp-chmod'
child_process = require 'child_process'

## npm run pug / npx gulp pug: builds index.html from index.pug etc.
exports.pug = pug = ->
  gulp.src '*.pug'
  .pipe gulpPug pretty: false #true
    # working around bug that <label> and <input> add extra spaces
    # in pretty mode
  .pipe gulpChmod 0o644
  .pipe gulp.dest './'

## npm run coffee / npx gulp coffee: builds index.js from index.coffee etc.
exports.coffee = coffee = ->
  gulp.src ['index.coffee', 'pieces.coffee'], ignore: 'gulpfile.coffee'
  .pipe gulpCoffee()
  .pipe gulpChmod 0o644
  .pipe gulp.dest './'

## npm run build / npx gulp build: all of the above
exports.build = build = gulp.series pug, coffee

## npm run font / npx gulp font:
## * builds pieces7 from font7 via pieces.sh
## * builds pieces7/*/*.svg via svgtiler
## * builds allfont.html via `coffee allfont.coffee`
exports.font = font = ->
  for command in [
    './pieces.sh'
    'svgtiler svgtileset.coffee font*/*.asc pieces*/*/*.asc'
    'coffee allfont.coffee'
  ]
    console.log "\t#{command}"
    child_process.spawnSync command,
      stdio: 'inherit'
      shell: true

## npm run watch / npx gulp watch: continuously update above
exports.watch = watch = ->
  gulp.watch '*.pug', ignoreInitial: false, pug
  gulp.watch '*.styl', pug
  gulp.watch ['index.coffee', 'pieces.coffee'],
    ignoreInitial: false
  , coffee
  #gulp.watch ['allfont.coffee', 'pieces.coffee', 'font7/*'], ignoreInitial: false, allfont

exports.default = pug
