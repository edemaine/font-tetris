all:
	./pieces.sh
	svgtiler svgtileset.coffee font*/*.asc pieces*/*/*.asc
