# svgtiler tile set for simple visualization
pixel = (fill) -> """<rect width="10" height="10" fill="#{fill}" stroke="#{fill}" stroke-width="0.5" />"""
I: pixel 'yellow'
O: pixel 'green'
S: pixel 'red'
Z: pixel 'pink'
T: pixel 'purple'
L: pixel 'blue'
J: pixel 'cyan'
' ': '<svg viewBox="0 0 10 10"></svg>'
