# https://tetris.fandom.com/wiki/SRS

pieces =
  I:
    polygon: [[2,1], [2,0], [-2,0], [-2,1]]
    center: [0,1]
  J:
    polygon: [[-1,0], [0,0], [0,1], [2,1], [2,2], [-1,2]]
    center: [0.5,0.5]
  L:
    polygon: [[-1,1], [1,1], [1,0], [2,0], [2,2], [-1,2]]
    center: [0.5,0.5]
  O:
    polygon: [[-1,0], [1,0], [1,2], [-1,2]]
    center: [0,1]
  S:
    polygon: [[0,0], [2,0], [2,1], [1,1], [1,2], [-1,2], [-1,1], [0,1]]
    center: [0.5,1.5]
  T:
    polygon: [[0,0], [1,0], [1,1], [2,1], [2,2], [-1,2], [-1,1], [0,1]]
    center: [0.5,1.5]
  Z:
    polygon: [[-1,0], [1,0], [1,1], [2,1], [2,2], [0,2], [0,1], [-1,1]]
    center: [0.5,1.5]

module?.exports = pieces
window?.pieces = pieces
