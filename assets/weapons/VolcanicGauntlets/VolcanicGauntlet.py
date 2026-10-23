# Guantelete Volcánico — modelo por código (Blender 5.x, bpy)
# Uso: blender -b -P VolcanicGauntlet.py -- <carpeta_salida>
# Genera 3 piezas (una por material, así Roblox las importa como 3 MeshParts):
#   Armor (placas de basalto/metal oscuro), Rock (rocas volcánicas y púas), Glow (magma brillante)
# El puño apunta a -Y de Blender (en Roblox queda hacia adelante con el exportador FBX estándar).
import bpy, bmesh, math, os, sys
from mathutils import Vector, Matrix, Euler

out = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
os.makedirs(out, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

def mat(name, color, metal=0.0, rough=0.5, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (*emit, 1)
        b.inputs["Emission Strength"].default_value = strength
    return m

M_ARMOR = mat("Armor", (0.16, 0.11, 0.09), metal=0.8, rough=0.42)
M_ROCK = mat("Rock", (0.05, 0.04, 0.04), metal=0.0, rough=0.85)
M_GLOW = mat("Glow", (1.0, 0.35, 0.05), emit=(1.0, 0.28, 0.03), strength=4)

parts = {"Armor": [], "Rock": [], "Glow": []}

def new_obj(name, bm, kind):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    parts[kind].append(o)
    return o

def box(kind, size, loc, rot=(0, 0, 0), taper=None, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        if taper and v.co.y > 0:  # se afina hacia +Y local
            v.co.x *= taper[0]; v.co.z *= taper[1]
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect='EDGES', profile=0.6)
    m = Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return new_obj(kind + "_box", bm, kind)

def cyl(kind, r1, r2, depth, loc, rot=(0, 0, 0), seg=10, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=r2, depth=depth)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=[e for e in bm.edges if len(e.link_faces) == 2 and abs(e.calc_face_angle(0)) > 0.6], offset=bevel, segments=2, affect='EDGES')
    m = Matrix.Translation(Vector(loc)) @ Euler(rot).to_matrix().to_4x4()
    bmesh.ops.transform(bm, matrix=m, verts=bm.verts)
    return new_obj(kind + "_cyl", bm, kind)

def spike(kind, base, direction, length, radius, seg=6):
    d = Vector(direction).normalized()
    rot = d.to_track_quat('Z', 'Y').to_euler()
    center = Vector(base) + d * (length / 2)
    return cyl(kind, radius, 0.0, length, center, rot, seg)

def sphere(kind, r, loc, scale=(1, 1, 1), sub=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    for v in bm.verts:
        v.co = Vector((v.co.x * scale[0], v.co.y * scale[1], v.co.z * scale[2]))
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return new_obj(kind + "_sph", bm, kind)

def rock(kind, r, loc, seed):
    import random
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    for v in bm.verts:
        v.co *= rnd.uniform(0.75, 1.2)
    bmesh.ops.translate(bm, vec=Vector(loc), verts=bm.verts)
    return new_obj(kind + "_rock", bm, kind)

# Ejes: X = ancho de la mano, Y = largo (el puño hacia -Y), Z = arriba (dorso de la mano)
# --- Antebrazo (brazal): anillos de placas que se ensanchan hacia el codo
for i in range(4):
    y = 1.2 + i * 0.75
    r = 0.62 + i * 0.07
    cyl("Armor", r, r + 0.06, 0.62, (0, y, 0), (math.radians(90), 0, 0), seg=10, bevel=0.03)
    # grieta de magma entre placas
    cyl("Glow", r - 0.02, r - 0.02, 0.1, (0, y + 0.36, 0), (math.radians(90), 0, 0), seg=10)
# Brocal del codo con púas de roca
cyl("Armor", 0.95, 0.85, 0.35, (0, 4.1, 0), (math.radians(90), 0, 0), seg=12, bevel=0.03)
for k in range(6):
    a = k / 6 * math.pi * 2 + 0.3
    d = Vector((math.cos(a), 0.55, math.sin(a)))
    spike("Rock", (math.cos(a) * 0.9, 4.15, math.sin(a) * 0.9), d, 0.9 + 0.25 * (k % 2), 0.17)
# Placa superior del antebrazo con runa de magma
box("Armor", (0.7, 2.6, 0.18), (0, 2.3, 0.72), bevel=0.05)
box("Glow", (0.12, 2.2, 0.06), (0, 2.3, 0.82))
for k in range(3):
    box("Glow", (0.42, 0.08, 0.06), (0, 1.6 + k * 0.7, 0.82))

# --- Muñeca y mano
cyl("Armor", 0.58, 0.62, 0.5, (0, 0.65, 0), (math.radians(90), 0, 0), seg=10, bevel=0.03)
box("Armor", (1.25, 1.3, 0.75), (0, -0.25, 0.02), bevel=0.12)            # palma/dorso
box("Armor", (1.05, 1.0, 0.22), (0, -0.2, 0.48), bevel=0.06)             # placa del dorso
# Núcleo de magma en el dorso, dentro de un engaste de roca
cyl("Rock", 0.38, 0.32, 0.22, (0, -0.2, 0.62), seg=8)
sphere("Glow", 0.26, (0, -0.2, 0.72), (1, 1, 0.75))
for k in range(4):
    a = k / 4 * math.pi * 2 + math.pi / 4
    spike("Rock", (math.cos(a) * 0.32, -0.2 + math.sin(a) * 0.32, 0.66), (math.cos(a) * 0.3, math.sin(a) * 0.3, 1), 0.35, 0.07, 5)

# --- Nudillos: 4 bloques con púa volcánica y vetas de magma
for f in range(4):
    x = -0.45 + f * 0.3
    box("Armor", (0.27, 0.42, 0.5), (x, -1.05, 0.12), bevel=0.06)
    box("Glow", (0.2, 0.05, 0.38), (x, -1.27, 0.12))
    spike("Rock", (x, -1.15, 0.32), (0, -0.55, 0.8), 0.5, 0.1, 5)
    # dedos cerrados (dos falanges)
    box("Armor", (0.24, 0.32, 0.36), (x, -1.32, -0.12), (math.radians(-20), 0, 0), bevel=0.04)
    box("Armor", (0.22, 0.28, 0.3), (x, -1.32, -0.42), (math.radians(-70), 0, 0), bevel=0.04)
# Pulgar
box("Armor", (0.3, 0.55, 0.3), (0.72, -0.55, -0.12), (0, math.radians(-25), math.radians(35)), bevel=0.05)
# Lado: aleta de roca
for k in range(3):
    spike("Rock", (-0.66, 0.1 + k * 0.4, 0.1), (-1, 0.4, 0.3), 0.45, 0.1, 5)

# --- Roca volcánica incrustada en el brazal
for k, (x, y, z) in enumerate([(0.65, 1.6, 0.35), (-0.62, 2.4, 0.4), (0.55, 3.2, -0.45), (-0.5, 1.4, -0.5)]):
    rock("Rock", 0.22 + (k % 2) * 0.06, (x, y, z), k)

# --- Juntar por material
def join(kind, material):
    objs = parts[kind]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active
    o.name = kind
    o.data.name = kind
    o.data.materials.clear()
    o.data.materials.append(material)
    for poly in o.data.polygons:
        poly.use_smooth = True
    # Normales: bordes duros por ángulo (look de placas)
    try:
        bpy.ops.object.shade_auto_smooth(angle=math.radians(40))
    except Exception:
        pass
    return o

objs = [join("Armor", M_ARMOR), join("Rock", M_ROCK), join("Glow", M_GLOW)]
tris = {o.name: sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs}
print("TRIS", tris)

# --- Exportar FBX (escala 1, Y arriba)
bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, "VolcanicGauntlets.fbx"), use_selection=True,
    apply_unit_scale=True, axis_forward='-Z', axis_up='Y', object_types={'MESH'}, mesh_smooth_type='FACE')

# --- Render de presentación
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
light = bpy.data.objects.new("Key", bpy.data.lights.new("Key", 'AREA'))
light.data.energy = 1600; light.data.size = 6
light.location = (4, -3, 6); light.rotation_euler = (math.radians(45), 0, math.radians(50))
scene.collection.objects.link(light)
rim = bpy.data.objects.new("Rim", bpy.data.lights.new("Rim", 'AREA'))
rim.data.energy = 500; rim.data.size = 4; rim.data.color = (1, 0.5, 0.3)
rim.location = (-4, 4, 3); rim.rotation_euler = (math.radians(-60), 0, math.radians(220))
scene.collection.objects.link(rim)
world = bpy.data.worlds.new("W"); world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.02, 0.018, 0.02, 1)
scene.world = world
scene.render.engine = 'CYCLES'
scene.cycles.samples = 48
scene.cycles.use_denoising = True
scene.render.resolution_x = 900; scene.render.resolution_y = 700
try:
    scene.view_settings.view_transform = 'AgX'
except Exception:
    pass
for name, loc, target in [("render_34", (5.2, -5.5, 3.6), (0, 0.8, 0)), ("render_lado", (-6.5, 0.6, 1.2), (0, 0.9, 0)), ("render_frente", (0.6, -7.5, 2.4), (0, 0.3, 0))]:
    cam.location = loc
    d = (Vector(target) - Vector(loc))
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    cam.data.lens = 50
    scene.render.filepath = os.path.join(out, name + ".png")
    bpy.ops.render.render(write_still=True)
print("OK")
