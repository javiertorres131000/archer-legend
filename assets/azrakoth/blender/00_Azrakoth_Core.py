# =============================================================================================
# AZRAKOTH — El Serafín del Eclipse Carmesí
# 00_Azrakoth_Core.py · Base común: medidas, esqueleto de referencia, colecciones, limpieza y
# herramientas de malla (bmesh) que usan los demás scripts.
#
# No se ejecuta solo: lo carga Build_Azrakoth.py.
# Convención: 1 unidad de Blender = 1 stud de Roblox · Z arriba · el boss mira hacia -Y (el frente
# de Blender) · su derecha está en -X · los pies apoyan en Z = 0.
# =============================================================================================
import math
import os
import random
import time

import bmesh
import bpy
from mathutils import Matrix, Vector

V = Vector
TAU = math.tau

# ---------------------------------------------------------------------------------------------
# OPCIONES (también se pueden cambiar con variables de entorno al correr Blender por consola)
# ---------------------------------------------------------------------------------------------
DETALLE = float(os.environ.get("AZR_DETALLE", "1.0"))  # 0.6 liviano · 1.0 normal · 1.5 alto
SEMILLA = 66  # misma semilla = mismo boss en cada corrida

PREFIJO = "AZR_"  # todo lo que crea el proyecto lleva este prefijo
COL_RAIZ = "AZRAKOTH_BOSS"
SUBCOLECCIONES = (
    "AZR_Cuerpo",       # casco, armadura, brazos, manos y piernas
    "AZR_Alas",
    "AZR_Halo",
    "AZR_Espadon",
    "AZR_Telas",        # capa, tabardos y faldones (huesos propios en la etapa del rig)
    "AZR_Colision",     # colisiones simplificadas (no se ven en el render)
    "AZR_Puntos",       # empties: agarre, estelas, hitboxes de referencia, emisores de VFX
    "AZR_Presentacion",  # luces, cámaras, suelo, eclipse, jugador de escala
)

# ---------------------------------------------------------------------------------------------
# MEDIDAS OBJETIVO (studs). Son de diseño, no límites: la validación avisa si se alejan mucho.
# ---------------------------------------------------------------------------------------------
MEDIDAS = {
    "altura_total": 65.0,   # hasta la punta de la corona
    "altura_cuerpo": 56.0,  # hasta la parte alta del casco, sin puntas
    "hombros": 22.0,        # entre articulaciones de hombro (las hombreras sobresalen más)
    "envergadura": 105.0,
    "espadon": 42.0,
    "halo": 24.0,           # diámetro exterior del anillo (sin espinas)
    "pie": 8.0,
}

# ---------------------------------------------------------------------------------------------
# ESQUELETO DE REFERENCIA (posiciones de articulaciones en pose de presentación)
# El modelo se arma con el origen de cada pieza en su articulación, y el rig de la etapa 2
# usa exactamente estos puntos: así cada pieza queda pegada a su hueso sin reajustar nada.
# ---------------------------------------------------------------------------------------------
ART = {
    "Root": V((0, 0, 0)),
    "Hips": V((0, 0.2, 27.0)),
    "Spine": V((0, 0.2, 31.0)),
    "Chest": V((0, 0.4, 37.5)),
    "Neck": V((0, 0.6, 47.2)),
    "Head": V((0, 0.4, 50.0)),
    "HaloCenter": V((0, 5.0, 53.0)),
}
for _s, _l in ((1, "L"), (-1, "R")):
    ART["Shoulder_" + _l] = V((10.8 * _s, 0.6, 44.0))
    ART["Hip_" + _l] = V((5.4 * _s, 0.3, 26.0))
    ART["Knee_" + _l] = V((6.1 * _s, -0.9, 15.4))
    ART["Ankle_" + _l] = V((6.4 * _s, 0.1, 5.4))
    ART["Toe_" + _l] = V((6.6 * _s, -6.4, 1.2))
    ART["WingRoot_" + _l] = V((4.4 * _s, 6.0, 44.0))
    ART["WingElbow_" + _l] = V((17.0 * _s, 10.0, 62.5))
    ART["WingWrist_" + _l] = V((28.5 * _s, 14.0, 68.5))
    ART["WingTip_" + _l] = V((41.5 * _s, 17.0, 64.0))

LARGO_BRAZO = 10.2  # hombro → codo
LARGO_ANTEBRAZO = 9.6  # codo → muñeca
# Agarre del espadón (mano derecha) y descanso de la mano izquierda, como en la referencia:
# la espada clavada de punta al costado derecho y el puño izquierdo cerrado junto a la cadera.
AGARRE_ESPADA = V((-19.0, -8.2, 36.2))
EJE_ESPADA = V((0.05, 0.09, 1.0)).normalized()  # hacia el pomo: la punta queda abajo, adelante y afuera
GRIP_A_PUNTA = 36.6  # del centro del mango a la punta
PUNTA_ESPADA = AGARRE_ESPADA - EJE_ESPADA * GRIP_A_PUNTA
MANO_IZQ = V((16.6, -3.0, 27.6))


def ik_dos_huesos(a, objetivo, l1, l2, polo):
    """Codo de un brazo de dos huesos que va de a hasta objetivo, doblado hacia polo."""
    d = objetivo - a
    dist = max(1e-4, min(d.length, l1 + l2 - 1e-3))
    eje = d.normalized()
    x = (l1 * l1 - l2 * l2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(0.0, l1 * l1 - x * x))
    p = polo - eje * polo.dot(eje)
    if p.length < 1e-5:
        p = V((0, 0, 1)) - eje * eje.z
    return a + eje * x + p.normalized() * h


ART["Wrist_R"] = AGARRE_ESPADA + V((1.3, 2.4, 0.8))  # la muñeca va detrás del puño (del lado del cuerpo)
ART["Elbow_R"] = ik_dos_huesos(ART["Shoulder_R"], ART["Wrist_R"], LARGO_BRAZO, LARGO_ANTEBRAZO, V((-0.6, 0.8, -0.1)))
ART["Wrist_L"] = MANO_IZQ + V((0.0, 0.0, 2.0))
ART["Elbow_L"] = ik_dos_huesos(ART["Shoulder_L"], ART["Wrist_L"], LARGO_BRAZO, LARGO_ANTEBRAZO, V((0.5, 0.9, 0.0)))
ART["Hand_R"] = AGARRE_ESPADA
ART["Hand_L"] = MANO_IZQ


def log(msg):
    print(f"[AZRAKOTH {time.strftime('%H:%M:%S')}] {msg}")


def n_lados(n):
    """Lados de una malla según DETALLE (mínimo 3)."""
    return max(3, int(round(n * DETALLE)))


# ---------------------------------------------------------------------------------------------
# COLECCIONES Y LIMPIEZA (idempotente: solo toca lo que lleva el prefijo del proyecto)
# ---------------------------------------------------------------------------------------------
def coleccion(nombre, padre=None):
    col = bpy.data.collections.get(nombre) or bpy.data.collections.new(nombre)
    destino = padre.children if padre else bpy.context.scene.collection.children
    if col.name not in destino:
        destino.link(col)
    return col


def preparar_colecciones():
    raiz = coleccion(COL_RAIZ)
    return raiz, {n: coleccion(n, raiz) for n in SUBCOLECCIONES}


def limpiar():
    """Borra lo que dejó una corrida anterior. No toca objetos ajenos al proyecto."""
    raiz = bpy.data.collections.get(COL_RAIZ)
    if raiz:
        for ob in list(raiz.all_objects):
            bpy.data.objects.remove(ob, do_unlink=True)
        for hijo in list(raiz.children_recursive):
            bpy.data.collections.remove(hijo)
        bpy.data.collections.remove(raiz)
    for ob in list(bpy.data.objects):
        if ob.name.startswith(PREFIJO):
            bpy.data.objects.remove(ob, do_unlink=True)
    datos = (bpy.data.meshes, bpy.data.materials, bpy.data.images, bpy.data.lights, bpy.data.cameras,
             bpy.data.node_groups, bpy.data.curves, bpy.data.worlds, bpy.data.armatures, bpy.data.actions,
             bpy.data.particles)
    for grupo in datos:
        for dato in list(grupo):
            if dato.name.startswith(PREFIJO) and dato.users == 0:
                grupo.remove(dato)


def quitar_cubo_inicial():
    """El cubo de una escena nueva queda en el centro, donde va el boss."""
    cubo = bpy.data.objects.get("Cube")
    if cubo and cubo.type == "MESH" and len(cubo.data.vertices) == 8 and cubo.location.length < 1e-4 \
            and tuple(cubo.scale) == (1.0, 1.0, 1.0):
        bpy.data.objects.remove(cubo, do_unlink=True)
        log("Saqué el cubo de la escena nueva.")


# ---------------------------------------------------------------------------------------------
# MATRICES
# ---------------------------------------------------------------------------------------------
def mtx(pos=(0, 0, 0), rot=(0, 0, 0), esc=(1, 1, 1)):
    """Matriz desde posición, rotación en grados (XYZ) y escala."""
    from mathutils import Euler
    r = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal((*esc, 1.0)) if not isinstance(esc, (int, float)) else Matrix.Scale(esc, 4)
    return Matrix.Translation(V(pos)) @ r @ s


def marco(pos, direccion, arriba=V((0, -1, 0))):
    """Matriz con el eje local +Z apuntando a `direccion` y el +Y local lo más cerca posible de `arriba`."""
    z = V(direccion).normalized()
    y = V(arriba) - z * V(arriba).dot(z)
    if y.length < 1e-5:
        alt = V((0, 0, 1)) if abs(z.z) < 0.9 else V((0, -1, 0))
        y = alt - z * alt.dot(z)
    y.normalize()
    x = y.cross(z)
    m = Matrix((x, y, z)).transposed().to_4x4()
    m.translation = V(pos)
    return m


def ejes(origen, u, v):
    """Matriz con columnas u, v (ortogonalizado) y u×v: para apoyar un contorno 2D en cualquier plano."""
    u = V(u).normalized()
    v = V(v) - u * V(v).dot(u)
    v.normalize()
    n = u.cross(v)
    m = Matrix((u, v, n)).transposed().to_4x4()
    m.translation = V(origen)
    return m


def marco_hueso(a, b, frente=V((0, -1, 0))):
    """Marco de un segmento de extremidad: origen en a, -Z local hacia b, -Y local al frente."""
    m = marco(a, a - b, -V(frente))
    return m


# ---------------------------------------------------------------------------------------------
# PIEZA: acumula primitivas en un bmesh y al final la vuelve un objeto con el origen en su pivote
# ---------------------------------------------------------------------------------------------
class Pieza:
    def __init__(self, nombre, pivote=(0, 0, 0)):
        self.nombre = nombre
        self.pivote = V(pivote)
        self.bm = bmesh.new()

    def agregar(self, t, matriz=None, mat=None, suave=False):
        """Copia el bmesh temporal t (transformado por matriz) a la pieza y libera t."""
        if matriz is not None:
            bmesh.ops.transform(t, matrix=matriz, verts=t.verts)
            if matriz.determinant() < 0:
                bmesh.ops.reverse_faces(t, faces=t.faces)
        mapa = {}
        for v in t.verts:
            mapa[v] = self.bm.verts.new(v.co)
        for f in t.faces:
            try:
                nf = self.bm.faces.new([mapa[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = f.material_index if mat is None else mat
            nf.smooth = suave
        t.free()
        return self


def a_objeto(pieza, mats, col, suave_angulo=None):
    """Crea el objeto de una Pieza con su origen en el pivote. mats: lista de materiales (slots)."""
    bm = pieza.bm
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.translate(bm, vec=-pieza.pivote, verts=bm.verts)
    bm.normal_update()
    me = bpy.data.meshes.new(PREFIJO + pieza.nombre)
    bm.to_mesh(me)
    bm.free()
    usados = sorted({p.material_index for p in me.polygons})
    remap = {old: i for i, old in enumerate(usados)}
    for m in usados:
        me.materials.append(mats[m])
    for p in me.polygons:
        p.material_index = remap[p.material_index]
    ob = bpy.data.objects.new(PREFIJO + pieza.nombre, me)
    ob.location = pieza.pivote
    col.objects.link(ob)
    return ob


# ---------------------------------------------------------------------------------------------
# PRIMITIVAS (devuelven un bmesh temporal en coordenadas locales; Pieza.agregar lo ubica)
# ---------------------------------------------------------------------------------------------
def _bisel(t, b, seg=1, bordes=None):
    if b <= 0:
        return
    geom = list(bordes) if bordes is not None else list(t.edges)
    if not geom:
        return
    try:
        bmesh.ops.bevel(t, geom=geom, offset=b, offset_type="OFFSET", segments=seg, profile=0.5,
                        affect="EDGES", clamp_overlap=True)
    except Exception as e:  # una geometría rara no tiene que frenar todo el armado
        log(f"Aviso: bisel omitido ({e})")


def caja(tam, bisel=0.0, mat=0):
    """Caja centrada en el origen."""
    t = bmesh.new()
    bmesh.ops.create_cube(t, size=1.0)
    for v in t.verts:
        v.co = V((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2]))
    _bisel(t, bisel)
    for f in t.faces:
        f.material_index = mat
    return t


def tronco(abajo, arriba, alto, corrimiento=(0, 0), bisel=0.0, mat=0):
    """Tronco de pirámide rectangular: abajo=(ancho, prof) en z=0, arriba=(ancho, prof) en z=alto,
    corrido (dx, dy) arriba. Sirve para placas, grebas, botas y todo lo que se angosta."""
    t = bmesh.new()
    (w0, d0), (w1, d1) = abajo, arriba
    dx, dy = corrimiento
    vs = [t.verts.new(p) for p in (
        (-w0 / 2, -d0 / 2, 0), (w0 / 2, -d0 / 2, 0), (w0 / 2, d0 / 2, 0), (-w0 / 2, d0 / 2, 0),
        (-w1 / 2 + dx, -d1 / 2 + dy, alto), (w1 / 2 + dx, -d1 / 2 + dy, alto),
        (w1 / 2 + dx, d1 / 2 + dy, alto), (-w1 / 2 + dx, d1 / 2 + dy, alto))]
    for idx in ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        t.faces.new([vs[i] for i in idx])
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    _bisel(t, bisel)
    for f in t.faces:
        f.material_index = mat
    return t


def prisma(contorno, grosor, bisel=0.0, mat=0, tapa_mat=None):
    """Contorno 2D (XY, en orden antihorario) extruido en Z de -grosor/2 a +grosor/2.
    Es la base de las placas con siluetas agresivas, plumas desgarradas, emblemas y filos."""
    t = bmesh.new()
    pts = [V((p[0], p[1], 0)) for p in contorno]
    # quita puntos repetidos seguidos
    lim = [pts[0]]
    for p in pts[1:]:
        if (p - lim[-1]).length > 1e-4:
            lim.append(p)
    if (lim[0] - lim[-1]).length < 1e-4:
        lim.pop()
    abajo = [t.verts.new((p.x, p.y, -grosor / 2)) for p in lim]
    arriba = [t.verts.new((p.x, p.y, grosor / 2)) for p in lim]
    n = len(lim)
    f1 = t.faces.new(list(reversed(abajo)))
    f2 = t.faces.new(arriba)
    lados = []
    for i in range(n):
        j = (i + 1) % n
        lados.append(t.faces.new((abajo[i], abajo[j], arriba[j], arriba[i])))
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    for f in t.faces:
        f.material_index = mat
    if tapa_mat is not None:
        f1.material_index = f2.material_index = tapa_mat
    if bisel > 0:
        bordes = [e for e in t.edges if not (len(e.link_faces) == 2 and
                                             all(f in lados for f in e.link_faces))]
        _bisel(t, bisel, bordes=bordes)
    # las tapas cóncavas se triangulan para que no se rompan al exportar
    tapas = [f for f in t.faces if len(f.verts) > 4]
    if tapas:
        bmesh.ops.triangulate(t, faces=tapas, quad_method="BEAUTY", ngon_method="BEAUTY")
    return t


def pua(radio, largo, lados=4, aplanar=1.0, curva=0.0, segmentos=4, mat=0, giro=45.0):
    """Púa facetada a lo largo de +Z (base en z=0). curva > 0 la dobla hacia +Y."""
    t = bmesh.new()
    anillos = []
    for k in range(segmentos):
        f = k / segmentos
        r = radio * (1 - f) ** 0.9
        dz = largo * f
        dy = curva * largo * f * f
        anillo = []
        for i in range(lados):
            a = TAU * i / lados + math.radians(giro)
            anillo.append(t.verts.new((math.cos(a) * r, math.sin(a) * r * aplanar + dy, dz)))
        anillos.append(anillo)
    punta = t.verts.new((0, curva * largo, largo))
    t.faces.new(list(reversed(anillos[0])))
    for a, b in zip(anillos, anillos[1:]):
        for i in range(lados):
            j = (i + 1) % lados
            t.faces.new((a[i], a[j], b[j], b[i]))
    for i in range(lados):
        j = (i + 1) % lados
        t.faces.new((anillos[-1][i], anillos[-1][j], punta))
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    for f in t.faces:
        f.material_index = mat
    return t


def anillo(r_ext, r_int, grosor, n=48, mat=0, arco=(0.0, TAU)):
    """Anillo de sección rectangular en el plano XY (o un arco si arco no es la vuelta completa)."""
    t = bmesh.new()
    a0, a1 = arco
    completo = abs((a1 - a0) - TAU) < 1e-6
    pasos = n if completo else max(2, int(n * (a1 - a0) / TAU) + 1)
    anillos = []
    for i in range(pasos):
        a = a0 + (a1 - a0) * i / (pasos if completo else pasos - 1)
        c, s = math.cos(a), math.sin(a)
        anillos.append([t.verts.new((c * r, s * r, z)) for r, z in
                        ((r_int, -grosor / 2), (r_ext, -grosor / 2), (r_ext, grosor / 2), (r_int, grosor / 2))])
    total = pasos if completo else pasos - 1
    for i in range(total):
        a, b = anillos[i], anillos[(i + 1) % pasos]
        for k in range(4):
            q = (k + 1) % 4
            t.faces.new((a[k], b[k], b[q], a[q]))
    if not completo:
        t.faces.new(list(reversed(anillos[0])))
        t.faces.new(anillos[-1])
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    for f in t.faces:
        f.material_index = mat
    return t


def esfera(radio, u=24, v=14, mat=0):
    t = bmesh.new()
    bmesh.ops.create_uvsphere(t, u_segments=max(6, u), v_segments=max(4, v), radius=radio)
    for f in t.faces:
        f.material_index = mat
    return t


def cilindro(r1, r2, alto, n=12, mat=0, tapas=True):
    """Cilindro / cono truncado a lo largo de +Z, base en z=0."""
    t = bmesh.new()
    bmesh.ops.create_cone(t, cap_ends=tapas, cap_tris=False, segments=max(3, n), radius1=r1, radius2=r2,
                          depth=alto, matrix=Matrix.Translation((0, 0, alto / 2)))
    for f in t.faces:
        f.material_index = mat
    return t


def loft(secciones, cerrado=True, tapa_inicio=True, tapa_fin=True, mat=0):
    """Une secciones (listas de puntos 3D con la misma cantidad) en una superficie continua.
    Una sección de un solo punto hace de punta. Es la herramienta para cascos, huesos de ala y hojas."""
    t = bmesh.new()
    anillos = [[t.verts.new(V(p)) for p in s] for s in secciones]
    for a, b in zip(anillos, anillos[1:]):
        if len(b) == 1:
            n = len(a)
            for i in range(n if cerrado else n - 1):
                t.faces.new((a[i], a[(i + 1) % n], b[0]))
        elif len(a) == 1:
            n = len(b)
            for i in range(n if cerrado else n - 1):
                t.faces.new((a[0], b[(i + 1) % n], b[i]))
        else:
            n = len(a)
            for i in range(n if cerrado else n - 1):
                j = (i + 1) % n
                t.faces.new((a[i], a[j], b[j], b[i]))
    if cerrado and tapa_inicio and len(anillos[0]) > 2:
        t.faces.new(list(reversed(anillos[0])))
    if cerrado and tapa_fin and len(anillos[-1]) > 2:
        t.faces.new(anillos[-1])
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    tapas = [f for f in t.faces if len(f.verts) > 4]
    if tapas:
        bmesh.ops.triangulate(t, faces=tapas, quad_method="BEAUTY", ngon_method="BEAUTY")
    for f in t.faces:
        f.material_index = mat
    return t


def deformar(t, fn):
    """Aplica fn(co) -> co nuevo a todos los vértices de un bmesh temporal."""
    for v in t.verts:
        v.co = fn(v.co.copy())
    return t


def tela(ancho, largo, columnas, filas, largos, grosor=0.25, ondas=0.6, frecuencia=3.0, curva=0.0, mat=0,
         rng=None):
    """Tela colgante en el plano XZ (cuelga hacia -Z desde z=0, cara hacia -Y). largos[i] (0..1) es
    cuánto baja cada columna: así el borde de abajo queda desgarrado. ondas: profundidad de pliegues."""
    t = bmesh.new()
    rng = rng or random.Random(1)
    grilla = {}
    for i in range(columnas + 1):
        u = i / columnas
        fin = largos[min(i, len(largos) - 1)]
        for k in range(filas + 1):
            w = k / filas
            if w > fin + 1e-6:
                continue
            x = (u - 0.5) * ancho
            z = -w * largo
            y = math.sin(u * TAU * frecuencia * 0.5 + w * 1.3) * ondas * (0.35 + 0.65 * w) + curva * (u - 0.5) ** 2
            grilla[(i, k)] = t.verts.new((x, y, z))
    for i in range(columnas):
        for k in range(filas):
            q = [(i, k), (i + 1, k), (i + 1, k + 1), (i, k + 1)]
            if all(p in grilla for p in q):
                t.faces.new([grilla[p] for p in q])
            elif (i, k) in grilla and (i + 1, k) in grilla and (i, k + 1) in grilla:
                t.faces.new([grilla[(i, k)], grilla[(i + 1, k)], grilla[(i, k + 1)]])
            elif (i, k) in grilla and (i + 1, k) in grilla and (i + 1, k + 1) in grilla:
                t.faces.new([grilla[(i, k)], grilla[(i + 1, k)], grilla[(i + 1, k + 1)]])
    sueltos = [v for v in t.verts if not v.link_faces]
    if sueltos:
        bmesh.ops.delete(t, geom=sueltos, context="VERTS")
    bmesh.ops.recalc_face_normals(t, faces=t.faces)
    if grosor > 0:
        bmesh.ops.solidify(t, geom=t.faces[:], thickness=grosor)
    for f in t.faces:
        f.material_index = mat
    return t


def contorno_desgarrado(ancho, largo, dientes, rng, profundidad=0.25, muescas=2, punta=0.0):
    """Contorno 2D de una pluma/tira: arriba recto (y=0), cuelga hacia -Y, abajo con dientes de distinto
    largo y muescas en los costados (desgarros). Devuelve puntos en orden antihorario."""
    izq, der = [], []
    pasos = 6
    for k in range(pasos + 1):
        f = k / pasos
        y = -largo * f * 0.82
        ang = 1.0 - punta * f
        mi = (rng.random() * 0.35 if 0 < k < pasos and rng.random() < muescas / pasos else 0.0)
        md = (rng.random() * 0.35 if 0 < k < pasos and rng.random() < muescas / pasos else 0.0)
        izq.append((-ancho / 2 * ang + ancho * mi, y))
        der.append((ancho / 2 * ang - ancho * md, y))
    abajo = []
    base_y = -largo * 0.82
    x0, x1 = der[-1][0], izq[-1][0]
    for d in range(dientes):
        fa = (d + 0.5) / dientes
        xa = x0 + (x1 - x0) * fa
        xb = x0 + (x1 - x0) * min(1.0, (d + 1) / dientes)
        largo_diente = largo * (0.18 * (0.4 + rng.random()) + profundidad * rng.random() * 0.2)
        abajo.append((xa, base_y - largo_diente))
        if d < dientes - 1:
            abajo.append((xb, base_y - largo * 0.04 * rng.random()))
    # antihorario: borde derecho hacia abajo, dientes de derecha a izquierda, borde izquierdo hacia arriba
    return [(der[0][0], 0.0)] + der[1:] + abajo + list(reversed(izq[1:])) + [(izq[0][0], 0.0)]


def contorno_estrella(puntas, r_ext, r_int, giro=0.0, irregular=0.0, rng=None):
    pts = []
    for i in range(puntas * 2):
        r = r_ext if i % 2 == 0 else r_int
        if irregular and rng and i % 2 == 0:
            r *= 1 + (rng.random() - 0.5) * irregular
        a = TAU * i / (puntas * 2) + math.radians(giro) + math.pi / 2
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


# ---------------------------------------------------------------------------------------------
# EMPTIES (puntos de agarre, estelas, hitboxes de referencia, emisores)
# ---------------------------------------------------------------------------------------------
def matriz_mundo(ob):
    """Matriz de mundo calculada desde las propiedades (sin esperar a que Blender evalúe la escena)."""
    local = Matrix.LocRotScale(ob.location, ob.rotation_euler.to_quaternion() if ob.rotation_mode != "QUATERNION"
                               else ob.rotation_quaternion, ob.scale)
    if ob.parent is None:
        return local
    return matriz_mundo(ob.parent) @ ob.matrix_parent_inverse @ local


def emparentar(hijo, padre):
    """Emparenta conservando la posición en el mundo."""
    mw = matriz_mundo(hijo)
    hijo.parent = padre
    hijo.matrix_parent_inverse = matriz_mundo(padre).inverted()
    hijo.location, rot, hijo.scale = mw.decompose()
    hijo.rotation_mode = "XYZ"
    hijo.rotation_euler = rot.to_euler("XYZ")


def punto(nombre, pos, col, padre=None, tipo="PLAIN_AXES", tam=1.0, escala=None, rot=None):
    """Empty en una posición del mundo (opcionalmente emparentado sin moverse)."""
    ob = bpy.data.objects.new(PREFIJO + nombre, None)
    ob.empty_display_type = tipo
    ob.empty_display_size = tam
    col.objects.link(ob)
    ob.location = V(pos)
    if rot is not None:
        ob.rotation_euler = rot
    if escala is not None:
        ob.scale = escala
    if padre is not None:
        emparentar(ob, padre)
    ob.hide_render = True
    return ob


def tris(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons) if ob.type == "MESH" else 0


# ---------------------------------------------------------------------------------------------
# ÍNDICES DE MATERIAL (los crea 02_Azrakoth_Materials.py en este mismo orden)
# ---------------------------------------------------------------------------------------------
MATERIALES = (
    "Obsidian",         # 0 · obsidiana con grietas finas de magma
    "ObsidianCracked",  # 1 · obsidiana muy fracturada (grietas anchas y brillantes)
    "AgedGold",         # 2 · oro envejecido
    "Glow",             # 3 · energía incandescente (ojos, núcleos, ranuras)
    "CrimsonCloth",     # 4 · tela carmesí envejecida
    "BoneCloth",        # 5 · tela hueso/ceniza
    "WingMembrane",     # 6 · membrana del ala con venas de lava
    "BladeMetal",       # 7 · metal negro del espadón
    "DarkIron",         # 8 · hierro oscuro (cadenas, anillos interiores)
    "RuneGlow",         # 9 · runas del halo (rojo más profundo)
)
OBS, OBSG, ORO, BRILLO, TELA, TELA2, MEMB, HOJA, HIERRO, RUNA = range(len(MATERIALES))


# ---------------------------------------------------------------------------------------------
# RIG: lo llena 03_Azrakoth_Rig.py. Si existe, las luces y los puntos se pegan a los huesos.
# ---------------------------------------------------------------------------------------------
RIG = None
HUESO_DE_PIEZA = {}  # nombre de pieza → hueso que la mueve


def pegar_a_hueso(hijo, rig, hueso):
    """Emparenta un objeto a un hueso del rig sin moverlo (Blender emparenta a la COLA del hueso)."""
    mw = matriz_mundo(hijo)
    b = rig.data.bones[hueso]
    hijo.parent = rig
    hijo.parent_type = "BONE"
    hijo.parent_bone = hueso
    cola = matriz_mundo(rig) @ b.matrix_local @ Matrix.Translation((0, b.length, 0))
    hijo.matrix_parent_inverse = cola.inverted()
    hijo.location, rot, hijo.scale = mw.decompose()
    hijo.rotation_mode = "XYZ"
    hijo.rotation_euler = rot.to_euler("XYZ")


def anclar(hijo, obs, pieza):
    """Pega un objeto (luz, empty) a una pieza: a su hueso si ya hay rig, si no al objeto."""
    if RIG is not None and pieza in HUESO_DE_PIEZA:
        pegar_a_hueso(hijo, RIG, HUESO_DE_PIEZA[pieza])
    else:
        emparentar(hijo, obs[pieza])
