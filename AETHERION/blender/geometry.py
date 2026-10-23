"""Pure geometry: testable without Blender. X lateral, -Y front, Z up."""
import math
import random


def stone(size, seed=0, rings=4, sides=8):
    """Closed chipped octagonal masonry, triangulated irregular side facets."""
    rng = random.Random(seed)
    sx, sy, sz = size
    outline = [(-.34, -.5), (.34, -.5), (.5, -.34), (.5, .34),
               (.34, .5), (-.34, .5), (-.5, .34), (-.5, -.34)]
    vertices, faces = [], []
    for row in range(rings):
        t = row / (rings - 1)
        taper = .82 if row in (0, rings - 1) else 1.0
        for x, y in outline:
            jitter = rng.uniform(.92, 1.04)
            vertices.append((x*sx*taper*jitter, y*sy*taper*jitter,
                             (t-.5)*sz))
    faces.append(tuple(reversed(range(8))))
    for row in range(rings-1):
        for j in range(8):
            a, b = row*8+j, row*8+(j+1)%8
            c, d = b+8, a+8
            faces.extend([(a,b,c), (a,c,d)])
    faces.append(tuple((rings-1)*8+j for j in range(8)))
    return vertices, faces


def arc(radius, width, depth, start=0, end=math.tau, steps=64):
    """Annular architectural extrusion in XZ, thickness along Y."""
    vertices, faces = [], []
    for i in range(steps+1):
        a = start + (end-start)*i/steps
        for r, y in ((radius-width/2,-depth/2), (radius+width/2,-depth/2),
                     (radius+width/2,depth/2), (radius-width/2,depth/2)):
            vertices.append((r*math.cos(a), y, r*math.sin(a)))
    for i in range(steps):
        for j in range(4):
            a = i*4+j
            b = i*4+(j+1)%4
            faces.append((a,b,b+4,a+4))
    faces.extend([(3,2,1,0), tuple(steps*4+j for j in range(4))])
    return vertices, faces


def crystal(width, height, depth):
    vertices = [(0,0,height/2), (0,0,-height/2),
                (-width/2,0,0), (0,-depth/2,0), (width/2,0,0), (0,depth/2,0)]
    faces = []
    for a,b in ((2,3),(3,4),(4,5),(5,2)):
        faces.extend([(0,a,b),(1,b,a)])
    return vertices, faces


def cloth_point(u, t, width, length, side):
    taper = 1-.40*t
    x = u*width*taper + side*1.8*t*t
    y = -.55*math.sin(t*math.pi) + .22*math.cos(u*math.pi*3)*t - .7*t*t
    z = -length*t + .50*abs(u)*t**8
    return x,y,z


def cloth(width, length, side, columns=12, rows=20):
    vertices = [cloth_point(i/columns-.5,j/rows,width,length,side)
                for j in range(rows+1) for i in range(columns+1)]
    faces = []
    for j in range(rows):
        for i in range(columns):
            a=j*(columns+1)+i
            faces.append((a,a+1,a+columns+2,a+columns+1))
    return vertices, faces


def validate(vertices, faces):
    assert vertices and faces, 'Empty mesh'
    assert all(len(v)==3 and all(math.isfinite(x) for x in v) for v in vertices)
    for f in faces:
        assert len(f)>=3 and len(set(f))==len(f)
        assert all(0<=i<len(vertices) for i in f)
