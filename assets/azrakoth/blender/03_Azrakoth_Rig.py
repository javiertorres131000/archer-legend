# =============================================================================================
# AZRAKOTH · 03_Azrakoth_Rig.py
# Esqueleto propio del coloso (no es el R15): columna, cuello, cabeza, corona, hombros, brazos,
# manos, dedos, piernas, pies, 3 segmentos por ala, halo, núcleo, espadón y cadenas de huesos
# para la capa, los tabardos y los faldones.
#
# Cómo se pegan las piezas: cada pieza rígida va al 100 % a su hueso (vertex group + modificador
# Armature), y las telas se reparten suave entre los huesos de su cadena. Las colisiones, los
# puntos de VFX y las luces se emparentan a los huesos, así siguen cualquier animación.
# Los huesos nacen en las mismas articulaciones con las que se armó el modelo (c.ART), así que
# ninguna pieza se mueve al riggear.
# =============================================================================================
import math

import bpy
from mathutils import Matrix, Vector

V = Vector

# Cadenas de tela: (pieza, prefijo de huesos, hueso padre, cantidad de huesos)
TELAS = (
    ("Cape", "Cape", "Chest", 3),
    ("Tabard_Front", "Tabard", "Hips", 2),
    ("Tabard_Under", "TabardUnder", "Hips", 2),
    ("ClothSide_L", "ClothSide_L", "Hips", 2),
    ("ClothSide_R", "ClothSide_R", "Hips", 2),
)


def _telas_info(c):
    """Arriba, dirección y largo de cada tela (las mismas matrices que usa 01_Azrakoth_Model)."""
    R = Matrix.Rotation
    abajo = V((0, 0, -1))
    info = {
        "Cape": (V((0, 7.6, 47.0)), (R(math.radians(7), 4, "X") @ abajo), 43.0),
        "Tabard_Front": (V((0, -6.0, 30.2)), (R(math.radians(-7), 4, "X") @ abajo), 23.5),
        "Tabard_Under": (V((0, -5.5, 30.4)), (R(math.radians(-5), 4, "X") @ abajo), 26.0),
    }
    for s, l in ((1, "L"), (-1, "R")):
        m = R(math.radians(90), 4, "Z") @ R(math.radians(-6 * s), 4, "Y") @ R(math.radians(-8), 4, "X")
        info["ClothSide_" + l] = (V((s * 7.8, 0.2, 29.6)), (m @ abajo), 17.0)
    return {k: (a, d.to_3d().normalized(), L) for k, (a, d, L) in info.items()}


def definir_huesos(c):
    """Lista de (hueso, cabeza, cola, padre). Las posiciones salen de c.ART."""
    A = c.ART
    nucleo = A["Chest"] + V((0, -8.1, 4.8))
    h = [
        ("Root", V((0, 0, 0)), V((0, 0, 4)), None),
        ("Hips", A["Hips"], A["Spine"], "Root"),
        ("Spine", A["Spine"], A["Chest"], "Hips"),
        ("Chest", A["Chest"], A["Neck"], "Spine"),
        ("Neck", A["Neck"], A["Head"], "Chest"),
        ("Head", A["Head"], A["Head"] + V((0, 0, 5.0)), "Neck"),
        ("Crown", V((0, 0.4, 55.2)), V((0, 0.4, 62.0)), "Head"),
        ("Halo", A["HaloCenter"], A["HaloCenter"] + V((0, -4.0, 0)), "Chest"),  # gira sobre su eje (Y local)
        ("Core", nucleo, nucleo + V((0, -3.0, 0)), "Chest"),
    ]
    for s, l in ((1, "L"), (-1, "R")):
        mano = A["Hand_" + l]
        if l == "R":
            eje, nudillos, pulgar = c.EJE_ESPADA, V((-0.35, -1.0, 0)), -1.0
        else:
            eje, nudillos, pulgar = (A["Wrist_L"] - mano).normalized(), V((0.6, -0.8, 0)), 1.0
        Mf = c.marco(mano, eje, -nudillos)
        h += [
            ("Shoulder_" + l, V((s * 3.6, 0.6, 46.0)), A["Shoulder_" + l], "Chest"),
            ("UpperArm_" + l, A["Shoulder_" + l], A["Elbow_" + l], "Shoulder_" + l),
            ("Forearm_" + l, A["Elbow_" + l], A["Wrist_" + l], "UpperArm_" + l),
            ("Hand_" + l, A["Wrist_" + l], mano, "Forearm_" + l),
            ("Fingers_" + l, mano, Mf @ V((0, -3.2, 0)), "Hand_" + l),
            ("Thumb_" + l, Mf @ V((pulgar * 1.6, -0.4, 2.0)), Mf @ V((pulgar * 2.7, -3.0, 2.0)), "Hand_" + l),
            ("UpperLeg_" + l, A["Hip_" + l], A["Knee_" + l], "Hips"),
            ("LowerLeg_" + l, A["Knee_" + l], A["Ankle_" + l], "UpperLeg_" + l),
            ("Foot_" + l, A["Ankle_" + l], A["Toe_" + l], "LowerLeg_" + l),
            (f"Wing_{l}_1", A["WingRoot_" + l], A["WingElbow_" + l], "Chest"),
            (f"Wing_{l}_2", A["WingElbow_" + l], A["WingWrist_" + l], f"Wing_{l}_1"),
            (f"Wing_{l}_3", A["WingWrist_" + l], A["WingTip_" + l], f"Wing_{l}_2"),
        ]
    h.append(("Sword", c.AGARRE_ESPADA, c.PUNTA_ESPADA, "Hand_R"))  # la cola es la punta de la hoja
    for pieza, prefijo, padre, n in TELAS:
        arriba, d, L = _telas_info(c)[pieza]
        anterior = padre
        for i in range(n):
            nombre = f"{prefijo}_{i + 1}"
            h.append((nombre, arriba + d * (L * i / n), arriba + d * (L * (i + 1) / n), anterior))
            anterior = nombre
    return h


PIEZA_A_HUESO = {
    "Pelvis": "Hips", "Abdomen": "Spine", "Chest": "Chest", "ChestCore": "Core", "Helmet": "Head",
    "Crown": "Crown", "Halo": "Halo", "Sword": "Sword",
}
for _l in ("L", "R"):
    PIEZA_A_HUESO.update({
        f"Pauldron_{_l}": f"Shoulder_{_l}", f"UpperArm_{_l}": f"UpperArm_{_l}", f"Forearm_{_l}": f"Forearm_{_l}",
        f"Hand_{_l}": f"Hand_{_l}", f"Fingers_{_l}": f"Fingers_{_l}", f"Thumb_{_l}": f"Thumb_{_l}",
        f"UpperLeg_{_l}": f"UpperLeg_{_l}", f"LowerLeg_{_l}": f"LowerLeg_{_l}", f"Foot_{_l}": f"Foot_{_l}",
        f"Wing_{_l}_1": f"Wing_{_l}_1", f"Wing_{_l}_2": f"Wing_{_l}_2", f"Wing_{_l}_3": f"Wing_{_l}_3",
    })


def crear_armature(c, col):
    arm = bpy.data.armatures.new(c.PREFIJO + "Rig")
    arm.display_type = "OCTAHEDRAL"
    rig = bpy.data.objects.new(c.PREFIJO + "Rig", arm)
    col.objects.link(rig)
    rig.show_in_front = True
    vl = bpy.context.view_layer
    # el modo edición necesita el rig activo y visible: se fija el contexto explícitamente
    vl.update()  # la capa de vista se pone al día con los objetos recién creados
    for ob in vl.objects:
        if ob is not None and ob.select_get():
            ob.select_set(False)
    vl.objects.active = rig
    rig.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    try:
        eb = arm.edit_bones
        for nombre, cabeza, cola, padre in definir_huesos(c):
            b = eb.new(nombre)
            b.head, b.tail = cabeza, cola
            d = (cola - cabeza).normalized()
            b.align_roll(V((0, -1, 0)) if abs(d.z) > 0.7 else V((0, 0, 1)))
            if padre:
                b.parent = eb[padre]
                b.use_connect = False
            b.use_deform = True
    finally:
        bpy.ops.object.mode_set(mode="OBJECT")
    for pb in rig.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return rig


def _pesos_tela(c, ob, pieza, prefijo, n):
    arriba, d, L = _telas_info(c)[pieza]
    grupos = [ob.vertex_groups.new(name=f"{prefijo}_{i + 1}") for i in range(n)]
    mw = c.matriz_mundo(ob)
    centros = [(i + 0.5) / n for i in range(n)]
    for v in ob.data.vertices:
        t = max(0.0, min(1.0, ((mw @ v.co) - arriba).dot(d) / L))
        if t <= centros[0]:
            grupos[0].add([v.index], 1.0, "REPLACE")
            continue
        if t >= centros[-1]:
            grupos[-1].add([v.index], 1.0, "REPLACE")
            continue
        k = int((t - centros[0]) * n)
        w = (t - centros[k]) * n
        grupos[k].add([v.index], 1.0 - w, "REPLACE")
        grupos[k + 1].add([v.index], w, "REPLACE")


def ejecutar(ctx):
    c, obs, cols = ctx["core"], ctx["obs"], ctx["cols"]
    col = c.coleccion("AZR_Rig", bpy.data.collections[c.COL_RAIZ])
    rig = crear_armature(c, col)
    # matrices de mundo de todo lo que hay que reubicar, antes de cambiar padres
    mallas = {n: o for n, o in obs.items() if o.type == "MESH"}
    hijos = [o for o in list(cols["AZR_Colision"].objects) + list(cols["AZR_Puntos"].objects)]
    mw = {o.name: c.matriz_mundo(o) for o in list(mallas.values()) + hijos}
    padre_de = {o.name: (o.parent.name[len(c.PREFIJO):] if o.parent else None) for o in hijos}
    telas = {t[0]: t for t in TELAS}

    for nombre, ob in mallas.items():
        ob.parent = rig
        ob.parent_type = "OBJECT"
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob.location, rot, ob.scale = mw[ob.name].decompose()
        ob.rotation_mode = "XYZ"
        ob.rotation_euler = rot.to_euler("XYZ")
        ob.vertex_groups.clear()
        if nombre in telas:
            _, prefijo, _, n = telas[nombre]
            _pesos_tela(c, ob, nombre, prefijo, n)
            c.HUESO_DE_PIEZA[nombre] = f"{prefijo}_1"
        else:
            hueso = PIEZA_A_HUESO[nombre]
            ob.vertex_groups.new(name=hueso).add(range(len(ob.data.vertices)), 1.0, "REPLACE")
            c.HUESO_DE_PIEZA[nombre] = hueso
        mod = ob.modifiers.new("Rig", "ARMATURE")
        mod.object = rig
        mod.use_vertex_groups = True

    c.RIG = rig
    for o in hijos:
        pieza = padre_de[o.name]
        if pieza in c.HUESO_DE_PIEZA:
            o.parent = None
            o.matrix_parent_inverse = Matrix.Identity(4)
            o.location, rot, o.scale = mw[o.name].decompose()
            o.rotation_euler = rot.to_euler("XYZ")
            c.pegar_a_hueso(o, rig, c.HUESO_DE_PIEZA[pieza])

    viejo = obs.pop("Root", None)  # la raíz pasa a ser el rig
    if viejo is not None:
        bpy.data.objects.remove(viejo, do_unlink=True)
    obs["Rig"] = rig
    ctx["rig"] = rig
    c.log(f"Rig: {len(rig.data.bones)} huesos · {len(mallas)} piezas pegadas "
          f"({len(TELAS)} telas con pesos suaves) · {len(hijos)} colisiones/puntos en huesos")
