# =============================================================================================
# AZRAKOTH · 07_Azrakoth_Presentation.py
# Escena de presentación: cielo carmesí, eclipse, arena de piedra con grietas, torres góticas
# lejanas, luces, cámaras (heroica, frente, perfil, espalda, tres cuartos, casco y escala),
# un jugador de 5 studs para comparar tamaños y bloom en el compositor.
# Nada de esto se exporta a Roblox: vive en la colección AZR_Presentacion.
# =============================================================================================
import math
import random

import bpy
from mathutils import Matrix, Vector

V = Vector


def _material_simple(c, nombre, color, rug=0.6, metal=0.0, emision=None, fuerza=0.0):
    m = bpy.data.materials.get(c.PREFIJO + nombre) or bpy.data.materials.new(c.PREFIJO + nombre)
    try:
        m.use_nodes = True
    except Exception:
        pass
    p = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Roughness"].default_value = rug
    p.inputs["Metallic"].default_value = metal
    if emision:
        p.inputs["Emission Color"].default_value = (*emision, 1)
        p.inputs["Emission Strength"].default_value = fuerza
    return m


def _objeto(c, nombre, t, mats, col, matriz=None):
    pz = c.Pieza(nombre)
    pz.agregar(t, matriz)
    ob = c.a_objeto(pz, mats, col)
    return ob


def suelo(c, matmod, col):
    g = bpy.data.node_groups.get(c.PREFIJO + "GrietasMagma") or matmod.grupo_grietas(c)
    m = matmod._piedra(c, g, "GroundStone", (0.018, 0.015, 0.016), (0.06, 0.045, 0.045), 0.05, 0.45, 0.8,
                       0.06, 0.025, 0.3, 2.0, rel=0.6)
    t = c.caja((420, 420, 1.0), 0.0)
    ob = _objeto(c, "Suelo", t, [m], col, Matrix.Translation((0, 60, -0.5)))
    return ob


def eclipse(c, col):
    negro = _material_simple(c, "EclipseDisk", (0.0, 0.0, 0.0), 1.0)
    corona = _material_simple(c, "EclipseCorona", (1.0, 0.1, 0.02), 0.5, 0.0, (1.0, 0.09, 0.02), 40.0)
    halo = _material_simple(c, "EclipseGlow", (0.5, 0.03, 0.01), 0.5, 0.0, (0.9, 0.06, 0.01), 4.0)
    M = Matrix.Translation((14, 330, 150)) @ Matrix.Rotation(math.radians(90), 4, "X")
    obs = [
        _objeto(c, "Eclipse_Disco", c.cilindro(48, 48, 1.0, 64), [negro], col, M),
        _objeto(c, "Eclipse_Corona", c.anillo(51.5, 47.5, 0.6, 96), [corona], col, M @ Matrix.Translation((0, 0, 1.0))),
        _objeto(c, "Eclipse_Resplandor", c.anillo(70, 51, 0.4, 96), [halo], col, M @ Matrix.Translation((0, 0, 1.4))),
    ]
    return obs


def torres(c, mats, col):
    """Torres góticas lejanas (silueta del fondo, como en la referencia)."""
    rng = random.Random(c.SEMILLA + 7)
    pz = c.Pieza("Torres")
    for i in range(16):
        ang = math.radians(rng.uniform(40, 140)) if i < 11 else math.radians(rng.choice((rng.uniform(150, 200),
                                                                                         rng.uniform(-20, 30))))
        dist = rng.uniform(150, 280)
        x, y = math.cos(ang) * dist, math.sin(ang) * dist
        alto = rng.uniform(55, 130)
        ancho = rng.uniform(9, 18)
        pz.agregar(c.tronco((ancho, ancho), (ancho * 0.8, ancho * 0.8), alto, (0, 0), 0.0), Matrix.Translation((x, y, 0)),
                   c.OBS)
        pz.agregar(c.tronco((ancho * 1.15, ancho * 1.15), (ancho * 1.1, ancho * 1.1), 3.0, (0, 0), 0.0),
                   Matrix.Translation((x, y, alto * 0.7)), c.OBS)
        pz.agregar(c.pua(ancho * 0.62, alto * 0.45, 4, 1.0, 0.0, 2), Matrix.Translation((x, y, alto)), c.OBS)
        for k in (-1, 1):
            pz.agregar(c.pua(ancho * 0.2, alto * 0.22, 4, 1.0, 0.0, 2),
                       Matrix.Translation((x + k * ancho * 0.42, y, alto * 0.7 + 3)), c.OBS)
    return c.a_objeto(pz, mats, col)


def jugador_escala(c, col):
    """Avatar R15 de bloques de 5 studs, para comparar el tamaño del boss."""
    m = _material_simple(c, "EscalaJugador", (0.55, 0.55, 0.6), 0.5)
    rojo = _material_simple(c, "EscalaCapa", (0.4, 0.02, 0.02), 0.8)
    pz = c.Pieza("EscalaJugador", (14, -16, 0))
    T = Matrix.Translation
    base = V((14, -16, 0))
    for tam, pos, mat in (((1.2, 1.2, 1.2), (0, 0, 4.4), 0), ((2.0, 1.0, 1.6), (0, 0, 3.0), 0),
                          ((2.0, 1.0, 0.4), (0, 0, 2.0), 0), ((0.95, 1.0, 2.0), (-0.52, 0, 1.0), 0),
                          ((0.95, 1.0, 2.0), (0.52, 0, 1.0), 0), ((1.0, 1.0, 2.0), (-1.5, 0, 2.8), 0),
                          ((1.0, 1.0, 2.0), (1.5, 0, 2.8), 0), ((2.2, 0.15, 2.6), (0, 0.6, 2.4), 1)):
        pz.agregar(c.caja(tam, 0.06), T(base + V(pos)), mat)
    return c.a_objeto(pz, [m, rojo], col)


def luces(c, obs, col):
    creados = []

    def luz(nombre, tipo, pos, energia, color, tam=1.0, apunta=None, padre=None):
        dato = bpy.data.lights.new(c.PREFIJO + nombre, tipo)
        dato.energy, dato.color = energia, color
        if tipo == "AREA":
            dato.size = tam
        elif tipo in ("POINT", "SPOT"):
            dato.shadow_soft_size = tam
        elif tipo == "SUN":
            dato.angle = math.radians(tam)
        ob = bpy.data.objects.new(c.PREFIJO + nombre, dato)
        ob.location = pos
        if apunta is not None:
            ob.rotation_euler = (V(apunta) - V(pos)).to_track_quat("-Z", "Y").to_euler()
        col.objects.link(ob)
        if padre is not None:
            c.anclar(ob, obs, padre)
        creados.append(ob)
        return ob

    luz("Sol_Clave", "SUN", (-60, -90, 90), 1.6, (1.0, 0.66, 0.48), 3.0, (0, 0, 30))
    luz("Sol_Contra", "SUN", (20, 120, 60), 5.5, (1.0, 0.18, 0.06), 2.0, (0, 0, 35))
    luz("Sol_Relleno", "SUN", (90, -60, 20), 0.35, (0.55, 0.45, 0.6), 8.0, (0, 0, 30))
    luz("Luz_Nucleo", "POINT", obs["ChestCore"].location + V((0, -6, 0)), 4000, (1.0, 0.3, 0.06), 1.0,
        padre="ChestCore")
    luz("Luz_Ojos", "POINT", V((0, -9, 52.5)), 500, (1.0, 0.35, 0.08), 0.5, padre="Helmet")
    luz("Luz_Halo", "POINT", c.ART["HaloCenter"] + V((0, 3, 0)), 12000, (1.0, 0.12, 0.03), 3.0, padre="Halo")
    luz("Luz_Espada", "POINT", c.AGARRE_ESPADA - c.EJE_ESPADA * 14 + V((0, -3, 0)), 12000, (1.0, 0.25, 0.05), 2.0,
        padre="Sword")
    luz("Luz_Suelo", "POINT", c.PUNTA_ESPADA + V((0, -2, 2)), 8000, (1.0, 0.3, 0.05), 3.0, padre="Sword")
    return creados


CAMARAS = {
    # nombre: (posición, mira a, lente mm, ancho, alto)
    "Heroica": ((-26, -66, 5), (-3, 0, 42), 23, 1000, 1500),
    "Frente": ((0, -128, 34), (0, 0, 33), 35, 1600, 1100),
    "Perfil": ((118, 6, 34), (0, 6, 32), 35, 1200, 1100),
    "Espalda": ((0, 138, 36), (0, 0, 34), 35, 1600, 1100),
    "TresCuartos": ((-82, -96, 44), (0, 2, 32), 35, 1500, 1100),
    "Casco": ((9, -34, 54), (0, 0, 52.5), 50, 1100, 1100),
    "Escala": ((26, -50, 9), (8, -6, 12), 30, 1400, 1000),
}


def camaras(c, col):
    cams = {}
    for nombre, (pos, mira, lente, w, h) in CAMARAS.items():
        cam = bpy.data.cameras.new(c.PREFIJO + "Cam_" + nombre)
        cam.lens = lente
        cam.clip_end = 2000
        ob = bpy.data.objects.new(c.PREFIJO + "Cam_" + nombre, cam)
        ob.location = pos
        ob.rotation_euler = (V(mira) - V(pos)).to_track_quat("-Z", "Y").to_euler()
        ob["resolucion"] = (w, h)
        col.objects.link(ob)
        cams[nombre] = ob
    bpy.context.scene.camera = cams["Heroica"]
    return cams


def mundo(c):
    w = bpy.data.worlds.get(c.PREFIJO + "Mundo") or bpy.data.worlds.new(c.PREFIJO + "Mundo")
    try:
        w.use_nodes = True
    except Exception:
        pass
    nt = w.node_tree
    bg = next(n for n in nt.nodes if n.type == "BACKGROUND")
    for n in list(nt.nodes):
        if n.type not in ("BACKGROUND", "OUTPUT_WORLD"):
            nt.nodes.remove(n)
    # degradé vertical: rojo humo en el horizonte, casi negro arriba
    tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    rampa = nt.nodes.new("ShaderNodeValToRGB")
    el = rampa.color_ramp.elements
    el[0].position, el[0].color = 0.5, (0.32, 0.03, 0.015, 1)
    el[1].position, el[1].color = 0.75, (0.03, 0.006, 0.006, 1)
    nt.links.new(sep.outputs["Z"], rampa.inputs["Fac"])
    nt.links.new(rampa.outputs["Color"], bg.inputs["Color"])
    bg.inputs["Strength"].default_value = 0.45
    bpy.context.scene.world = w


def compositor(c):
    """Bloom: Glare tipo Bloom + un poco de Fog Glow (Blender 5: compositing_node_group)."""
    esc = bpy.context.scene
    viejo = bpy.data.node_groups.get(c.PREFIJO + "Compositor")
    if viejo:
        bpy.data.node_groups.remove(viejo)
    try:
        ng = bpy.data.node_groups.new(c.PREFIJO + "Compositor", "CompositorNodeTree")
        ng.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
        rl = ng.nodes.new("CompositorNodeRLayers")
        g1 = ng.nodes.new("CompositorNodeGlare")
        g2 = ng.nodes.new("CompositorNodeGlare")
        out = ng.nodes.new("NodeGroupOutput")
        for g, tipo, umbral, fuerza, tam in ((g1, "Bloom", 1.2, 0.35, 0.6), (g2, "Fog Glow", 3.0, 0.2, 0.5)):
            try:
                g.inputs["Type"].default_value = tipo
            except Exception:
                pass
            for nombre, val in (("Highlights Threshold", umbral), ("Strength", fuerza), ("Size", tam)):
                if nombre in g.inputs:
                    try:
                        g.inputs[nombre].default_value = val
                    except Exception:
                        pass
        ng.links.new(rl.outputs["Image"], g1.inputs["Image"])
        ng.links.new(g1.outputs[0], g2.inputs["Image"])
        ng.links.new(g2.outputs[0], out.inputs[0])
        esc.compositing_node_group = ng
        esc.render.use_compositing = True
    except Exception as e:
        c.log(f"Aviso: no armé el bloom del compositor ({e}). El boss se ve igual, con menos resplandor.")


def ajustes_render(c):
    esc = bpy.context.scene
    motor = "BLENDER_EEVEE"
    ids = [i.identifier for i in esc.render.bl_rna.properties["engine"].enum_items]
    if motor not in ids:
        motor = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in ids else "CYCLES"
    esc.render.engine = motor
    try:
        esc.eevee.use_raytracing = True
        esc.eevee.taa_render_samples = 64
    except Exception:
        pass
    esc.view_settings.view_transform = "AgX"
    looks = [i.identifier for i in esc.view_settings.bl_rna.properties["look"].enum_items]
    esc.view_settings.look = next((x for x in looks if "Medium High Contrast" in x), "None")
    esc.render.resolution_x, esc.render.resolution_y = 1000, 1500


def construir(c, matmod, obs, mats, cols):
    col = cols["AZR_Presentacion"]
    extra = [suelo(c, matmod, col), torres(c, mats, col), jugador_escala(c, col)]
    extra += eclipse(c, col)
    extra += luces(c, obs, col)
    cams = camaras(c, col)
    mundo(c)
    compositor(c)
    ajustes_render(c)
    c.log(f"Escena de presentación: {len(cams)} cámaras, eclipse, arena, torres y jugador de escala (5 studs)")
    return cams
