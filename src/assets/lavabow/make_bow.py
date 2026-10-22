"""Arco de lava (estilo bloque, como el Demonio Ígneo).
Ejes Blender: Z = largo del arco, -Y = panza (hacia adelante), +Y = cuerda, X = grosor.
Objetos: LavaBow_Body (texturado), LavaBow_Gem, LavaBow_Tips (neón), LavaBow_String.
"""
import bpy, bmesh, math, sys
from mathutils import Vector, Matrix

OUT = sys.argv[sys.argv.index("--") + 1]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def box(name, size, loc, rot=None, taper=None):
    """Caja con tamaño (x,y,z); taper=(fx,fy) escala la cara de arriba (+Z local)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co.x *= size[0]
        v.co.y *= size[1]
        v.co.z *= size[2]
        if taper and v.co.z > 0:
            v.co.x *= taper[0]
            v.co.y *= taper[1]
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    m = Matrix.Translation(Vector(loc))
    if rot is not None:
        m = m @ rot
    ob.matrix_world = m
    return ob


def cone(name, r, h, loc, rot, verts=4):
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=0.0, depth=h)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.matrix_world = Matrix.Translation(Vector(loc)) @ rot
    return ob


def align_z(direction):
    """Rotación que lleva +Z a `direction`."""
    d = Vector(direction).normalized()
    return d.to_track_quat('Z', 'Y').to_matrix().to_4x4()


body, tips = [], []

# --- Empuñadura (riser) ---
body.append(box("Riser", (0.30, 0.42, 1.10), (0, 0, 0)))
for z in (-0.32, -0.12, 0.08):  # vendas de la empuñadura
    body.append(box("Wrap", (0.34, 0.46, 0.08), (0, 0, z)))
# placas en V arriba y abajo de la empuñadura
for s in (1, -1):
    body.append(box("Plate", (0.36, 0.50, 0.16), (0, -0.02, s * 0.5)))
# gema (diamante) en la panza
gem = cone("GemTop", 0.2, 0.26, (0, -0.33, 0.32), Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(45), 4, 'Z'))
gem2 = cone("GemBot", 0.2, 0.12, (0, -0.27, 0.32), Matrix.Rotation(math.radians(-90), 4, 'X') @ Matrix.Rotation(math.radians(45), 4, 'Z'))
body.append(box("GemFrame", (0.46, 0.12, 0.46), (0, -0.22, 0.32), Matrix.Rotation(math.radians(45), 4, 'Y')))
gems = [gem, gem2]

# protectores a los costados de la gema (alitas hacia atrás)
for x in (1, -1):
    body.append(box("Guard", (0.10, 0.34, 0.5), (x * 0.2, -0.05, 0.32), Matrix.Rotation(math.radians(-x * 18), 4, 'Y'), (0.5, 0.6)))


def shard(name, base, direction, length, width):
    """Cristal plano y filoso (fino en X) que sale de `base` hacia `direction`."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    h = width / 2
    v = [bm.verts.new(p) for p in [(-0.03, -h, 0), (0.03, -h, 0), (0.03, h, 0), (-0.03, h, 0), (0, 0, length), (0, h * 0.4, length * 0.55)]]
    bm.faces.new((v[0], v[1], v[4]))
    bm.faces.new((v[1], v[2], v[5], v[4]))
    bm.faces.new((v[2], v[3], v[5]))
    bm.faces.new((v[3], v[0], v[4], v[5]))
    bm.faces.new((v[3], v[2], v[1], v[0]))
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.matrix_world = Matrix.Translation(Vector(base)) @ align_z(direction)
    return ob


# --- Palas (limbs) ---
SEG = 7
LIMB = 1.85
for s in (1, -1):  # 1 = arriba, -1 = abajo
    def center(t):
        z = s * (0.55 + LIMB * t)
        # curva hacia la cuerda (+Y) y recurva: la última parte vuelve hacia adelante
        y = 0.95 * t * t - 0.55 * max(0.0, t - 0.75) ** 2 * 8
        return Vector((0, y, z))
    for i in range(SEG):
        t0, t1 = i / SEG, (i + 1) / SEG
        a, b = center(t0), center(t1)
        mid = (a + b) / 2
        d = b - a
        length = d.length * 1.1
        w0 = 0.34 - 0.16 * t0
        dep0 = 0.42 - 0.22 * t0
        taper = ((0.34 - 0.16 * t1) / w0, (0.42 - 0.22 * t1) / dep0)
        body.append(box(f"Limb{s}_{i}", (w0, dep0, length), mid, align_z(d), taper))
        # normal de la panza (hacia adelante, perpendicular a la pala)
        belly = Vector((0, -d.z, d.y)).normalized()
        if belly.y > 0:
            belly = -belly
        # cristales de lava en la panza (brillan) y púas oscuras entre medio
        if i in (1, 2, 3, 4):
            out = (belly + d.normalized() * 0.55).normalized()
            size = 0.62 if i in (2, 3) else 0.45
            tips.append(shard(f"Shard{s}_{i}", mid + belly * dep0 * 0.4, out, size, 0.2))
        if i in (1, 3, 5):
            for x in (1, -1):
                sd = (Vector((x * 0.9, 0, 0)) + belly * 0.4 + d.normalized() * 0.3).normalized()
                body.append(cone(f"Spike{s}_{i}", 0.06, 0.24, mid + Vector((x * w0 * 0.45, 0, 0)) + sd * 0.08, align_z(sd), 4))
    # cuerno grande en la punta: sigue la recurva y se dobla hacia adelante (-Y)
    tip = center(1.0)
    last = (center(1.0) - center(0.95)).normalized()
    dirs = [last, (last + Vector((0, -0.5, 0))).normalized(), Vector((0, -0.9, s * 0.45)).normalized()]
    pos = tip
    r = 0.15
    for k, dvec in enumerate(dirs):
        L = 0.34 if k < 2 else 0.5
        if k < 2:
            body.append(box(f"Horn{s}_{k}", (r * 2, r * 2, L * 1.15), pos + dvec * L / 2, align_z(dvec), (0.78, 0.78)))
            r *= 0.78
        else:
            tips.append(cone(f"HornTip{s}", r * 1.15, L, pos + dvec * L / 2, align_z(dvec), 4))
        pos = pos + dvec * L
    # brasa donde se ata la cuerda
    nockPos = center(0.93) + Vector((0, 0.2, 0))
    tips.append(cone(f"Nock{s}", 0.08, 0.2, nockPos, align_z(Vector((0, 1, 0))), 4))

# --- Cuerda ---
top = nockPos + Vector((0, 0.08, 0))  # nockPos del último lado (abajo): lo espejamos
top = Vector((0, top.y, abs(top.z)))
bot = Vector((top.x, top.y, -top.z))
string = box("String", (0.035, 0.035, (top - bot).length), (top + bot) / 2)


def join(objs, name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return ob


bodyOb = join(body, "LavaBow_Body")
# bisel para que se vea "macizo" como el demonio
mod = bodyOb.modifiers.new("Bevel", 'BEVEL')
mod.width = 0.025
mod.segments = 2
mod.limit_method = 'ANGLE'
bpy.context.view_layer.objects.active = bodyOb
bpy.ops.object.modifier_apply(modifier="Bevel")
# UV
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
bpy.ops.object.mode_set(mode='OBJECT')

gemOb = join(gems, "LavaBow_Gem")
tipsOb = join(tips, "LavaBow_Tips")
string.name = "LavaBow_String"

for ob in (bodyOb, gemOb, tipsOb, string):
    bpy.ops.object.select_all(action='DESELECT')
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.shade_flat()

tris = sum(len(o.data.polygons) for o in (bodyOb, gemOb, tipsOb, string))
print("faces", tris, "dims", bodyOb.dimensions)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.fbx(filepath=OUT, use_selection=True, apply_unit_scale=True, axis_forward='-Z', axis_up='Y', mesh_smooth_type='FACE')
bpy.ops.wm.obj_export(filepath=OUT.replace('.fbx', '.obj'), export_selected_objects=True, export_materials=False)
print("exported", OUT)
