# =============================================================================================
# AZRAKOTH · 06_Azrakoth_Export.py
# Versión GAMEPLAY OPTIMIZED para Roblox:
#   · una pieza rígida por hueso (las telas se cortan por hueso), con el nombre del hueso
#   · como mucho TRIS_MAX triángulos por pieza
#   · texturas horneadas por pieza: Color, Normal, Roughness, Metalness y Emissive
#   · output/roblox/Azrakoth_Roblox.fbx  (sin esqueleto: las piezas se unen con Motor6D en Roblox)
#   · output/roblox/Azrakoth_Rig.json y AzrakothAnimData.lua: articulaciones y las 20 animaciones
#     ya convertidas a ejes de Roblox, listas para Motor6D.Transform o KeyframeSequence.
# Hornear tarda varios minutos, por eso NO corre en cada Alt + P: poné EXPORTAR = True abajo
# (o la variable AZR_EXPORTAR=1) y corré Build_Azrakoth.py.
# =============================================================================================
import json
import math
import os

import bmesh
import bpy
from mathutils import Matrix, Quaternion, Vector

EXPORTAR = os.environ.get("AZR_EXPORTAR") == "1"
TRIS_MAX = 6000
TEX_GRANDE = ("Chest", "Wing_L_1", "Wing_R_1", "Wing_L_2", "Wing_R_2", "Sword", "Cape_1", "Cape_2", "Halo",
              "Shoulder_L", "Shoulder_R")
# Blender (X izq. del boss, -Y frente, Z arriba) → Roblox (frente -Z, Y arriba): (x, y, z) → (-x, z, y)
EJES = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def a_roblox(v):
    return EJES @ Vector(v)


def _sel(obs):
    vl = bpy.context.view_layer
    vl.update()
    for o in vl.objects:
        if o is not None and o.select_get():
            o.select_set(False)
    for o in obs:
        o.select_set(True)
    vl.objects.active = obs[0] if obs else None


def piezas_por_hueso(c, obs, col):
    """Copia cada pieza (en reposo, sin modificadores) y corta las telas por su hueso dominante."""
    partes = {}
    for nombre, ob in obs.items():
        if ob.type != "MESH":
            continue
        grupos = {g.index: g.name for g in ob.vertex_groups}
        bm = bmesh.new()
        bm.from_mesh(ob.data)
        capa = bm.verts.layers.deform.verify()
        por_hueso = {}
        for f in bm.faces:
            suma = {}
            for v in f.verts:
                for gi, w in v[capa].items():
                    suma[gi] = suma.get(gi, 0.0) + w
            hueso = grupos[max(suma, key=suma.get)] if suma else c.HUESO_DE_PIEZA[nombre]
            por_hueso.setdefault(hueso, []).append(f.index)
        for hueso, caras in por_hueso.items():
            b2 = bm.copy()
            b2.faces.ensure_lookup_table()
            quedan = set(caras)
            bmesh.ops.delete(b2, geom=[f for f in b2.faces if f.index not in quedan], context="FACES")
            me = bpy.data.meshes.new(c.PREFIJO + "RBX_" + hueso)
            b2.to_mesh(me)
            b2.free()
            for m in ob.data.materials:
                me.materials.append(m)
            cp = bpy.data.objects.new(c.PREFIJO + "RBX_" + hueso, me)
            col.objects.link(cp)
            # el origen va en la articulación del hueso (cabeza), en el mundo
            cabeza = c.RIG.data.bones[hueso].head_local
            cp.location = cabeza
            me.transform(Matrix.Translation(c.matriz_mundo(ob).translation - cabeza))
            partes[hueso] = cp
        bm.free()
    return partes


def _bsdf(m):
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _salida(m):
    return next(n for n in m.node_tree.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)


def _destino(m, img):
    nt = m.node_tree
    nodo = nt.nodes.get("_HORNEAR") or nt.nodes.new("ShaderNodeTexImage")
    nodo.name = "_HORNEAR"
    nodo.image = img
    nt.nodes.active = nodo


def _hornear_entrada(ob, img, entrada):
    temporales = []
    for m in ob.data.materials:
        nt, p, out = m.node_tree, _bsdf(m), _salida(m)
        orig = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].links else None
        em = nt.nodes.new("ShaderNodeEmission")
        sock = p.inputs[entrada]
        if sock.links:
            nt.links.new(sock.links[0].from_socket, em.inputs["Color"])
        else:
            v = sock.default_value
            em.inputs["Color"].default_value = (v, v, v, 1) if isinstance(v, float) else tuple(v)
        nt.links.new(em.outputs["Emission"], out.inputs["Surface"])
        temporales.append((m, em, orig))
        _destino(m, img)
    bpy.ops.object.bake(type="EMIT", margin=4, use_clear=True)
    for m, em, orig in temporales:
        m.node_tree.nodes.remove(em)
        if orig:
            m.node_tree.links.new(orig, _salida(m).inputs["Surface"])


def hornear(c, ob, nombre, tam, carpeta):
    _sel([ob])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006)
    bpy.ops.object.mode_set(mode="OBJECT")
    imgs = {}
    for clave, datos in (("Color", False), ("Emissive", False), ("Normal", True), ("Roughness", True),
                         ("Metalness", True)):
        img = bpy.data.images.new(f"{c.PREFIJO}{nombre}_{clave}", tam, tam, alpha=False)
        if datos:
            img.colorspace_settings.name = "Non-Color"
        imgs[clave] = img
    _hornear_entrada(ob, imgs["Color"], "Base Color")
    _hornear_entrada(ob, imgs["Roughness"], "Roughness")
    _hornear_entrada(ob, imgs["Metalness"], "Metallic")
    for m in ob.data.materials:
        _destino(m, imgs["Emissive"])
    bpy.ops.object.bake(type="EMIT", margin=4, use_clear=True)
    for m in ob.data.materials:
        _destino(m, imgs["Normal"])
    bpy.ops.object.bake(type="NORMAL", normal_space="TANGENT", margin=4, use_clear=True)
    for clave, img in imgs.items():
        img.filepath_raw = os.path.join(carpeta, f"{nombre}_{clave}.png")
        img.file_format = "PNG"
        img.save()
    m = bpy.data.materials.new(c.PREFIJO + "Baked_" + nombre)
    try:
        m.use_nodes = True
    except Exception:
        pass
    nt, p = m.node_tree, _bsdf(m)

    def tex(img):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = img
        return n.outputs["Color"]

    nt.links.new(tex(imgs["Color"]), p.inputs["Base Color"])
    nt.links.new(tex(imgs["Metalness"]), p.inputs["Metallic"])
    nt.links.new(tex(imgs["Roughness"]), p.inputs["Roughness"])
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(tex(imgs["Normal"]), nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], p.inputs["Normal"])
    nt.links.new(tex(imgs["Emissive"]), p.inputs["Emission Color"])
    p.inputs["Emission Strength"].default_value = 1.0
    ob.data.materials.clear()
    ob.data.materials.append(m)
    for pol in ob.data.polygons:
        pol.material_index = 0


def datos_rig_y_animaciones(c, partes, anim_mod):
    """Articulaciones y animaciones en ejes de Roblox (rotaciones relativas al padre, en la articulación)."""
    rig = c.RIG
    q_ejes = EJES.to_quaternion()
    huesos = []
    for b in rig.data.bones:
        huesos.append({
            "nombre": b.name,
            "padre": b.parent.name if b.parent else None,
            "articulacion": [round(x, 4) for x in a_roblox(b.head_local)],
            "parte": b.name if b.name in partes else None,
        })
    anims = []
    for a in anim_mod.animaciones():
        claves = []
        for cuadro, pose in a["claves"]:
            pose = anim_mod.resolver(rig, pose)
            rot, loc = {}, {}
            for k, v in pose.items():
                if k.startswith("loc:"):
                    d = a_roblox(v)
                    if d.length > 1e-4:
                        loc[k[4:]] = [round(x, 4) for x in d]
                else:
                    q = anim_mod._q(v)
                    qr = q_ejes @ q @ q_ejes.inverted()
                    if abs(qr.angle) > 1e-4:
                        rot[k] = [round(qr.w, 5), round(qr.x, 5), round(qr.y, 5), round(qr.z, 5)]
            claves.append({"t": round(cuadro / anim_mod.FPS, 4), "rot": rot, "loc": loc})
        anims.append({"nombre": a["nombre"], "duracion": round(a["fin"] / anim_mod.FPS, 4), "bucle": a["ciclo"],
                      "marcas": {k: round(v / anim_mod.FPS, 4) for k, v in a["marcas"].items()},
                      "claves": claves})
    return {"version": 1, "fps": anim_mod.FPS, "ejes": "Roblox: frente -Z, arriba +Y, izquierda del boss -X",
            "nota": "rot = cuaternión (w,x,y,z) del hueso respecto de su padre, en la articulación y en ejes del "
                    "mundo en reposo (como Motor6D.Transform si C0/C1 son articulaciones sin rotación)",
            "huesos": huesos, "animaciones": anims}


def _lua(v, sangria=""):
    if isinstance(v, dict):
        if not v:
            return "{}"
        partes = []
        for k, x in v.items():
            clave = k if k.isidentifier() else f'["{k}"]'
            partes.append(f"{sangria}\t{clave} = {_lua(x, sangria + chr(9))},")
        return "{\n" + "\n".join(partes) + f"\n{sangria}}}"
    if isinstance(v, list):
        if all(not isinstance(x, (dict, list)) for x in v):
            return "{ " + ", ".join(_lua(x) for x in v) + " }"
        return "{\n" + "\n".join(f"{sangria}\t{_lua(x, sangria + chr(9))}," for x in v) + f"\n{sangria}}}"
    if isinstance(v, bool):
        return "true" if v else "false"
    if v is None:
        return "nil"
    if isinstance(v, str):
        return '"' + v.replace('"', '\\"') + '"'
    return repr(v)


def ejecutar(ctx):
    c = ctx["core"]
    if not EXPORTAR:
        c.log("Exportación a Roblox: apagada (EXPORTAR = True o AZR_EXPORTAR=1 para hornear y exportar).")
        return
    if c.RIG is None:
        raise RuntimeError("La exportación necesita el rig (03_Azrakoth_Rig.py).")
    import importlib.util
    spec = importlib.util.spec_from_file_location("azr_anim_exp", os.path.join(os.path.dirname(__file__),
                                                                                 "04_Azrakoth_Animations.py"))
    anim_mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(anim_mod)
    salida = os.path.join(ctx["salida"], "roblox")
    tex = os.path.join(salida, "textures")
    os.makedirs(tex, exist_ok=True)
    col = c.coleccion("AZR_Roblox", bpy.data.collections[c.COL_RAIZ])
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    partes = piezas_por_hueso(c, ctx["obs"], col)
    esc = bpy.context.scene
    motor = esc.render.engine
    esc.render.engine = "CYCLES"
    esc.cycles.samples = 1
    total = 0
    for hueso, ob in partes.items():
        n = c.tris(ob)
        if n > TRIS_MAX:
            dec = ob.modifiers.new("Decimar", "DECIMATE")
            dec.ratio = TRIS_MAX / n
            _sel([ob])
            bpy.ops.object.modifier_apply(modifier="Decimar")
        total += c.tris(ob)
        hornear(c, ob, hueso, 1024 if hueso in TEX_GRANDE else 512, tex)
    esc.render.engine = motor
    for m in bpy.data.materials:  # saca los nodos de horneado de los materiales originales
        if m.node_tree and m.node_tree.nodes.get("_HORNEAR") and not m.name.startswith(c.PREFIJO + "Baked_"):
            m.node_tree.nodes.remove(m.node_tree.nodes["_HORNEAR"])
    # FBX con los nombres de hueso exactos (sin prefijo)
    for hueso, ob in partes.items():
        ob.name = hueso
    _sel(list(partes.values()))
    bpy.ops.export_scene.fbx(filepath=os.path.join(salida, "Azrakoth_Roblox.fbx"), use_selection=True,
                             object_types={"MESH"}, use_mesh_modifiers=True, mesh_smooth_type="FACE",
                             path_mode="COPY", embed_textures=True, apply_scale_options="FBX_SCALE_ALL",
                             bake_anim=False)
    for hueso, ob in partes.items():
        ob.name = c.PREFIJO + "RBX_" + hueso
    col.hide_viewport = col.hide_render = True
    datos = datos_rig_y_animaciones(c, partes, anim_mod)
    with open(os.path.join(salida, "Azrakoth_Rig.json"), "w", encoding="utf-8") as f:
        json.dump(datos, f, ensure_ascii=False, indent=1)
    with open(os.path.join(salida, "AzrakothAnimData.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- AzrakothAnimData (ModuleScript) · GENERADO por 06_Azrakoth_Export.py: no editar a mano.\n")
        f.write("-- Articulaciones y animaciones de Azrakoth en ejes de Roblox (ver Azrakoth_Rig.json).\n")
        f.write("return " + _lua(datos) + "\n")
    c.log(f"Roblox: {len(partes)} piezas · {total:,} triángulos · texturas en {tex} · "
          f"FBX, JSON y AzrakothAnimData.lua en {salida}".replace(",", "."))
