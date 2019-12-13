# https://tetris.fandom.com/wiki/SRS

pieces =
  I:
    polygon: [[4,1], [4,0], [0,0], [0,1]]
    center: [2,1]
  J:
    polygon: [[0,0], [1,0], [1,1], [3,1], [3,2], [0,2]]
    center: [1.5,1.5]
  L:
    polygon: [[0,1], [2,1], [2,0], [3,0], [3,2], [0,2]]
    center: [1.5,1.5]
  O:
    polygon: [[0,0], [2,0], [2,2], [0,2]]
    center: [1,1]
  S:
    polygon: [[1,0], [3,0], [3,1], [2,1], [2,2], [0,2], [0,1], [1,1]]
    center: [1.5,1.5]
  T:
    polygon: [[1,0], [2,0], [2,1], [3,1], [3,2], [0,2], [0,1], [1,1]]
    center: [1.5,1.5]
  Z:
    polygon: [[0,0], [2,0], [2,1], [3,1], [3,2], [1,2], [1,1], [0,1]]
    center: [1.5,1.5]

module?.exports = pieces
window?.pieces = pieces
