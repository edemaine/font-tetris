#!/bin/sh
for font in 7
do
  mkdir -p pieces$font
  for piece in I J L O S T Z
  do
    mkdir -p pieces$font/$piece
    for x in font$font/*.asc
    do
      out="`echo $x | sed 's/font/pieces/' | sed 's#/#/'$piece'/#'`"
      sed -e 's/[^ '$piece']/ /g' "$x" >$out
    done
  done
done
