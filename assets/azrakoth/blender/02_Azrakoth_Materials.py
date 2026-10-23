# =============================================================================================
# AZRAKOTH · 02_Azrakoth_Materials.py
# Materiales PBR procedurales (nodos) + el objeto de control AZR_Control, cuyas propiedades
# (Lava, Nucleo, Runas) manejan por driver la intensidad de las grietas, el núcleo y el halo.
# Animando esas propiedades se hacen los pulsos, la carga del Rayo del Eclipse y la fase 3.
#
# Las grietas de magma son fracturas: un voronoi deformado por ruido, con ancho variable,
# ramas finas, una máscara que las reparte por zonas y relieve hundido (no líneas pegadas).
# Para Roblox esto se hornea a texturas (BaseColor, Normal, Roughness, Metalness, Emissive)
# en 06_Azrakoth_Export.py (etapa de exportación).
# =============================================================================================
import warnings

import bpy


def _nuevo(c, nombre):
    viejo = bpy.data.materials.get(c.PREFIJO + nombre)
    if viejo:
        bpy.data.materials.remove(viejo)
    m = bpy.data.materials.new(c.PREFIJO + nombre)
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        try:
            m.use_nodes = True  # en Blender 5 ya viene con nodos; en versiones previas hay que pedirlo
        except Exception:
            pass
    return m


def _bsdf(m):
    return next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")


def _in(node, *nombres):
    for n in nombres:
        if n in node.inputs:
            return node.inputs[n]
    raise KeyError(f"{node.name}: no encontré {nombres}")


class Nodos:
    """Atajos para armar árboles de nodos sin repetir diez líneas por nodo."""

    def __init__(self, nt):
        self.nt = nt

    def n(self, tipo, **props):
        nodo = self.nt.nodes.new(tipo)
        for k, v in props.items():
            setattr(nodo, k, v)
        return nodo

    def link(self, a, b):
        self.nt.links.new(a, b)

    def val(self, entrada, v):
        if isinstance(v, (int, float, tuple)):
            entrada.default_value = v if not isinstance(v, tuple) or len(v) == len(entrada.default_value) \
                else (*v, 1.0)
        else:
            self.link(v, entrada)

    def math(self, op, a, b=None, clamp=False):
        m = self.n("ShaderNodeMath", operation=op)
        m.use_clamp = clamp
        self.val(m.inputs[0], a)
        if b is not None:
            self.val(m.inputs[1], b)
        return m.outputs["Value"]

    def rango(self, v, a, b, c=0.0, d=1.0, suave=False):
        mr = self.n("ShaderNodeMapRange")
        if suave:
            mr.interpolation_type = "SMOOTHSTEP"
        mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = a, b
        mr.inputs["To Min"].default_value, mr.inputs["To Max"].default_value = c, d
        self.val(mr.inputs["Value"], v)
        return mr.outputs["Result"]

    def ruido(self, co, escala, detalle=6.0, rug=0.55, salida="Fac"):
        r = self.n("ShaderNodeTexNoise")
        r.inputs["Scale"].default_value = escala
        r.inputs["Detail"].default_value = detalle
        r.inputs["Roughness"].default_value = rug
        self.link(co, r.inputs["Vector"])
        return r.outputs[salida]

    def rampa(self, fac, paradas):
        r = self.n("ShaderNodeValToRGB")
        el = r.color_ramp.elements
        while len(el) < len(paradas):
            el.new(0.5)
        for e, (pos, col) in zip(el, paradas):
            e.position = pos
            e.color = (*col, 1.0)
        self.val(r.inputs["Fac"], fac)
        return r.outputs["Color"]

    def mezcla(self, fac, a, b):
        m = self.n("ShaderNodeMix", data_type="RGBA")
        self.val(m.inputs["Factor"], fac)
        self.val(m.inputs[6], a)
        self.val(m.inputs[7], b)
        return m.outputs[2]

    def coord(self, escala=(1, 1, 1)):
        tc = self.n("ShaderNodeTexCoord")
        if escala == (1, 1, 1):
            return tc.outputs["Object"]
        vm = self.n("ShaderNodeVectorMath", operation="MULTIPLY")
        self.link(tc.outputs["Object"], vm.inputs[0])
        vm.inputs[1].default_value = escala
        return vm.outputs["Vector"]

    def relieve(self, p, altura, fuerza, dist=0.1):
        b = self.n("ShaderNodeBump")
        b.inputs["Strength"].default_value = fuerza
        b.inputs["Distance"].default_value = dist
        self.link(altura, b.inputs["Height"])
        self.link(b.outputs["Normal"], _in(p, "Normal"))

    def control(self, c, prop, defecto=1.0):
        """Valor manejado por un driver desde AZR_Control[prop] (animable)."""
        nodo = self.n("ShaderNodeValue", label=prop)
        nodo.outputs[0].default_value = defecto
        try:
            fc = nodo.outputs[0].driver_add("default_value")
            d = fc.driver
            d.type = "AVERAGE"  # sin expresión de Python: funciona aunque el auto-run esté apagado
            var = d.variables.new()
            var.name, var.type = "v", "SINGLE_PROP"
            var.targets[0].id_type = "OBJECT"
            var.targets[0].id = c.CONTROL
            var.targets[0].data_path = f'["{prop}"]'
        except Exception as e:
            c.log(f"Aviso: no pude crear el driver {prop} ({e}); queda fijo en {defecto}")
        return nodo.outputs[0]


# ---------------------------------------------------------------------------------------------
# GRUPO: GRIETAS DE MAGMA
# ---------------------------------------------------------------------------------------------
def grupo_grietas(c):
    nombre = c.PREFIJO + "GrietasMagma"
    viejo = bpy.data.node_groups.get(nombre)
    if viejo:
        bpy.data.node_groups.remove(viejo)
    g = bpy.data.node_groups.new(nombre, "ShaderNodeTree")
    io = g.interface
    io.new_socket("Vector", in_out="INPUT", socket_type="NodeSocketVector")
    for nom, v in (("Escala", 0.25), ("Ancho", 0.06), ("Cobertura", 0.6), ("Distorsion", 0.6), ("Ramas", 0.7)):
        s = io.new_socket(nom, in_out="INPUT", socket_type="NodeSocketFloat")
        s.default_value = v
    io.new_socket("Grieta", in_out="OUTPUT", socket_type="NodeSocketFloat")
    io.new_socket("Calor", in_out="OUTPUT", socket_type="NodeSocketFloat")
    io.new_socket("Mascara", in_out="OUTPUT", socket_type="NodeSocketFloat")
    N = Nodos(g)
    ent = N.n("NodeGroupInput")
    sal = N.n("NodeGroupOutput")

    esc = N.n("ShaderNodeVectorMath", operation="SCALE")
    N.link(ent.outputs["Vector"], esc.inputs[0])
    N.link(ent.outputs["Escala"], esc.inputs["Scale"])
    co = esc.outputs["Vector"]

    # deformación con ruido: las fracturas no son celdas rectas
    rd = N.n("ShaderNodeTexNoise")
    rd.inputs["Scale"].default_value = 1.6
    rd.inputs["Detail"].default_value = 4.0
    N.link(co, rd.inputs["Vector"])
    centrado = N.n("ShaderNodeVectorMath", operation="SUBTRACT")
    N.link(rd.outputs["Color"], centrado.inputs[0])
    centrado.inputs[1].default_value = (0.5, 0.5, 0.5)
    amp = N.n("ShaderNodeVectorMath", operation="SCALE")
    N.link(centrado.outputs["Vector"], amp.inputs[0])
    N.link(ent.outputs["Distorsion"], amp.inputs["Scale"])
    co2 = N.n("ShaderNodeVectorMath", operation="ADD")
    N.link(co, co2.inputs[0])
    N.link(amp.outputs["Vector"], co2.inputs[1])
    cod = co2.outputs["Vector"]

    def borde(escala, mult):
        v = N.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
        v.inputs["Scale"].default_value = escala
        N.link(cod, v.inputs["Vector"])
        # ancho variable a lo largo de la grieta
        var = N.rango(N.ruido(cod, 2.3, 2.0), 0.3, 0.7, 0.35, 1.5)
        ancho = N.math("MULTIPLY", N.math("MULTIPLY", var, ent.outputs["Ancho"]), mult)
        t = N.math("DIVIDE", v.outputs["Distance"], N.math("MAXIMUM", ancho, 1e-4))
        return N.math("SUBTRACT", 1.0, t, clamp=True)

    principal = borde(1.0, 1.0)
    ramas = N.math("MULTIPLY", borde(2.7, 0.45), ent.outputs["Ramas"])
    grieta = N.math("MAXIMUM", principal, ramas)

    # máscara: las grietas aparecen por zonas (cobertura 0 = ninguna, 1 = por todos lados)
    mz = N.ruido(co, 0.55, 3.0, 0.5)
    umbral = N.math("SUBTRACT", 0.68, N.math("MULTIPLY", ent.outputs["Cobertura"], 0.36))
    mascara_bruta = N.math("SUBTRACT", mz, umbral)
    mascara = N.math("MULTIPLY", mascara_bruta, 9.0, clamp=True)
    final = N.math("MULTIPLY", grieta, mascara)
    calor = N.math("POWER", final, 3.0)
    N.link(final, sal.inputs["Grieta"])
    N.link(calor, sal.inputs["Calor"])
    N.link(mascara, sal.inputs["Mascara"])
    return g


def _grietas(N, g, co, escala, ancho, cobertura, distorsion=0.6, ramas=0.7):
    n = N.n("ShaderNodeGroup")
    n.node_tree = g
    N.link(co, n.inputs["Vector"])
    for nom, v in (("Escala", escala), ("Ancho", ancho), ("Cobertura", cobertura), ("Distorsion", distorsion),
                   ("Ramas", ramas)):
        n.inputs[nom].default_value = v
    return n.outputs["Grieta"], n.outputs["Calor"]


MAGMA = [(0.0, (0.05, 0.004, 0.002)), (0.35, (0.55, 0.035, 0.006)), (0.7, (1.0, 0.28, 0.025)),
         (1.0, (1.0, 0.78, 0.32))]


def _piedra(c, g, nombre, base_a, base_b, metal, rug_a, rug_b, escala, ancho, cobertura, fuerza, rel=0.5,
            co_escala=(1, 1, 1)):
    """Obsidiana / metal ennegrecido con fracturas de magma."""
    m = _nuevo(c, nombre)
    N = Nodos(m.node_tree)
    p = _bsdf(m)
    co = N.coord(co_escala)
    tono = N.ruido(co, 0.35, 5.0, 0.6)
    fino = N.ruido(co, 3.2, 8.0, 0.65)
    grieta, calor = _grietas(N, g, co, escala, ancho, cobertura)
    base = N.mezcla(N.rango(tono, 0.35, 0.7), base_a, base_b)
    lava = N.rampa(grieta, MAGMA)
    # la grieta tiñe el borde (piedra recalentada) aunque no brille
    N.link(N.mezcla(N.math("POWER", grieta, 1.4), base, lava), _in(p, "Base Color"))
    _in(p, "Metallic").default_value = metal
    N.link(N.rango(fino, 0.3, 0.75, rug_a, rug_b), _in(p, "Roughness"))
    lava_ctrl = N.control(c, "Lava")
    N.link(lava, _in(p, "Emission Color"))
    intensidad = N.math("MULTIPLY", N.math("ADD", N.math("MULTIPLY", calor, 2.0), N.math("POWER", grieta, 2.0)), fuerza)
    N.link(N.math("MULTIPLY", intensidad, lava_ctrl), _in(p, "Emission Strength"))
    # relieve: la grieta se hunde en la piedra, y la piedra tiene astillas finas
    vor = N.n("ShaderNodeTexVoronoi", feature="F1")
    vor.inputs["Scale"].default_value = 1.4
    N.link(co, vor.inputs["Vector"])
    astillas = N.math("MULTIPLY", vor.outputs["Distance"], 0.25)
    altura = N.math("SUBTRACT", N.math("ADD", N.math("MULTIPLY", fino, 0.35), astillas),
                    N.math("MULTIPLY", grieta, 1.2))
    N.relieve(p, altura, rel, 0.12)
    return m


def mat_oro(c):
    m = _nuevo(c, "AgedGold")
    N = Nodos(m.node_tree)
    p = _bsdf(m)
    co = N.coord()
    sucio = N.ruido(co, 0.9, 6.0, 0.6)
    raya = N.ruido(N.coord((6, 6, 0.6)), 1.0, 4.0, 0.5)
    N.link(N.rampa(N.math("MULTIPLY", sucio, N.rango(raya, 0.2, 0.8, 0.85, 1.15)),
                   [(0.3, (0.11, 0.065, 0.025)), (0.52, (0.42, 0.26, 0.08)), (0.75, (0.78, 0.53, 0.2))]),
           _in(p, "Base Color"))
    _in(p, "Metallic").default_value = 1.0
    N.link(N.rango(sucio, 0.3, 0.75, 0.62, 0.26), _in(p, "Roughness"))
    N.relieve(p, N.ruido(co, 4.0, 6.0, 0.6), 0.25, 0.06)
    return m


def mat_brillo(c, nombre, centro, borde, fuerza, prop):
    """Energía incandescente: centro casi blanco y borde rojo (fresnel)."""
    m = _nuevo(c, nombre)
    N = Nodos(m.node_tree)
    p = _bsdf(m)
    lw = N.n("ShaderNodeLayerWeight")
    lw.inputs["Blend"].default_value = 0.45
    col = N.mezcla(lw.outputs["Facing"], centro, borde)
    N.link(col, _in(p, "Base Color"))
    N.link(col, _in(p, "Emission Color"))
    pulso = N.rango(N.ruido(N.coord(), 1.5, 2.0), 0.3, 0.7, 0.8, 1.15)
    N.link(N.math("MULTIPLY", N.math("MULTIPLY", pulso, fuerza), N.control(c, prop)), _in(p, "Emission Strength"))
    _in(p, "Roughness").default_value = 0.3
    return m


def mat_tela(c, nombre, a, b, oscuro):
    m = _nuevo(c, nombre)
    N = Nodos(m.node_tree)
    p = _bsdf(m)
    co = N.coord()
    trama = N.ruido(N.coord((14, 14, 1.0)), 2.0, 3.0, 0.5)
    manchas = N.ruido(co, 0.45, 5.0, 0.6)
    base = N.mezcla(N.rango(manchas, 0.35, 0.7), a, b)
    quemado = N.rango(N.ruido(co, 0.9, 6.0, 0.7), 0.6, 0.72)
    N.link(N.mezcla(quemado, base, oscuro), _in(p, "Base Color"))
    N.link(N.rango(trama, 0.3, 0.7, 0.78, 0.95), _in(p, "Roughness"))
    for nombre_in, v in (("Sheen Weight", 0.35), ("Sheen Roughness", 0.5)):
        if nombre_in in p.inputs:
            p.inputs[nombre_in].default_value = v
    N.relieve(p, trama, 0.15, 0.05)
    return m


def mat_membrana(c, g):
    m = _nuevo(c, "WingMembrane")
    N = Nodos(m.node_tree)
    p = _bsdf(m)
    co = N.coord()
    largo = N.coord((1.0, 1.0, 0.3))  # venas estiradas a lo largo de la pluma
    grieta, calor = _grietas(N, g, largo, 0.35, 0.035, 0.45, 0.9, 0.6)
    tono = N.ruido(co, 0.5, 5.0, 0.6)
    base = N.mezcla(N.rango(tono, 0.3, 0.7), (0.32, 0.022, 0.016), (0.11, 0.008, 0.006))
    lava = N.rampa(grieta, MAGMA)
    N.link(N.mezcla(N.math("POWER", grieta, 1.4), base, lava), _in(p, "Base Color"))
    N.link(lava, _in(p, "Emission Color"))
    N.link(N.math("MULTIPLY", N.math("MULTIPLY", N.math("ADD", N.math("POWER", grieta, 2.0), calor), 2.5),
                  N.control(c, "Lava")), _in(p, "Emission Strength"))
    _in(p, "Roughness").default_value = 0.6
    if "Sheen Weight" in p.inputs:
        p.inputs["Sheen Weight"].default_value = 0.25
    N.relieve(p, N.math("SUBTRACT", N.ruido(co, 2.5, 6.0, 0.6), grieta), 0.35, 0.08)
    return m


def mat_hierro(c):
    m = _nuevo(c, "DarkIron")
    N = Nodos(m.node_tree)
    p = _bsdf(m)
    co = N.coord()
    oxido = N.ruido(co, 1.4, 6.0, 0.6)
    N.link(N.rampa(oxido, [(0.35, (0.022, 0.02, 0.02)), (0.7, (0.09, 0.035, 0.02))]), _in(p, "Base Color"))
    _in(p, "Metallic").default_value = 0.85
    N.link(N.rango(oxido, 0.3, 0.7, 0.35, 0.7), _in(p, "Roughness"))
    return m


def crear_control(c, col):
    """AZR_Control: perillas animables (Lava, Nucleo, Runas) que leen los materiales por driver."""
    ob = bpy.data.objects.new(c.PREFIJO + "Control", None)
    ob.empty_display_type = "SPHERE"
    ob.empty_display_size = 2.0
    ob.location = (0, -14, 0)
    col.objects.link(ob)
    for prop, v, desc in (("Lava", 1.0, "Brillo de las grietas de magma (fase 3: ~2)"),
                          ("Nucleo", 1.0, "Brillo del núcleo del pecho, ojos y espadón"),
                          ("Runas", 1.0, "Brillo de las runas del halo (carga del Rayo del Eclipse: ~4)")):
        ob[prop] = v
        try:
            ui = ob.id_properties_ui(prop)
            ui.update(min=0.0, soft_max=5.0, description=desc)
        except Exception:
            pass
    ob.hide_render = True
    c.CONTROL = ob
    return ob


def crear(c, col_control):
    """Crea todos los materiales en el orden de c.MATERIALES y devuelve la lista."""
    crear_control(c, col_control)
    g = grupo_grietas(c)
    mats = {
        "Obsidian": _piedra(c, g, "Obsidian", (0.012, 0.011, 0.013), (0.035, 0.03, 0.032), 0.2, 0.25, 0.55,
                            0.22, 0.035, 0.32, 2.5),
        "ObsidianCracked": _piedra(c, g, "ObsidianCracked", (0.016, 0.01, 0.01), (0.045, 0.024, 0.022), 0.15,
                                   0.3, 0.6, 0.3, 0.06, 0.62, 5.0, rel=0.7),
        "AgedGold": mat_oro(c),
        "Glow": mat_brillo(c, "Glow", (1.0, 0.55, 0.15), (0.9, 0.06, 0.01), 7.0, "Nucleo"),
        "CrimsonCloth": mat_tela(c, "CrimsonCloth", (0.24, 0.014, 0.014), (0.1, 0.006, 0.007),
                                 (0.025, 0.008, 0.006)),
        "BoneCloth": mat_tela(c, "BoneCloth", (0.4, 0.33, 0.25), (0.2, 0.15, 0.11), (0.05, 0.035, 0.03)),
        "WingMembrane": mat_membrana(c, g),
        "BladeMetal": _piedra(c, g, "BladeMetal", (0.01, 0.009, 0.011), (0.03, 0.026, 0.028), 0.55, 0.16, 0.38,
                              0.3, 0.045, 0.5, 4.0, rel=0.6, co_escala=(1.0, 1.0, 0.45)),
        "DarkIron": mat_hierro(c),
        "RuneGlow": mat_brillo(c, "RuneGlow", (0.9, 0.1, 0.015), (1.0, 0.3, 0.04), 2.6, "Runas"),
    }
    lista = [mats[n] for n in c.MATERIALES]
    c.log(f"Materiales: {len(lista)} (grietas, oro, energía, telas, membrana, espadón, hierro, runas)")
    return lista
