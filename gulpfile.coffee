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

## npm run allfont / npx gulp allfont: builds allfont.html via
## `coffee allfont.coffee`
exports.allfont = font = ->
  child_process.exec 'coffee allfont.coffee'

## npm run watch / npx gulp watch: continuously update above
exports.watch = watch = ->
  gulp.watch '*.pug', ignoreInitial: false, pug
  gulp.watch '*.styl', pug
  gulp.watch ['index.coffee', 'pieces.coffee'],
    ignoreInitial: false
  , coffee
  #gulp.watch ['allfont.coffee', 'pieces.coffee', 'font7/*'], ignoreInitial: false, allfont

exports.default = pug
