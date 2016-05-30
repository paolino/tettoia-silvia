import Vis
import Linear.V3


bar x = Box (x,0.120,0.080) Solid red
plane = Plane (V3 0 1 0) blue white

alli = VisObjects [plane,bar 1]


main = display defaultOpts alli
