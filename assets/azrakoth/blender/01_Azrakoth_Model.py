# =============================================================================================
# AZRAKOTH · 01_Azrakoth_Model.py
# Geometría completa del boss: casco con corona de púas, halo del eclipse, armadura volcánica,
# hombreras, brazos y puños, piernas y botas, telas, seis segmentos de ala y el Espadón del Eclipse.
#
# Cada pieza es un objeto aparte con el origen en su articulación (ver c.ART en el Core) y forma
# una jerarquía (cadera → torso → brazos…), así se puede posar ya mismo y el rig de la etapa 2
# la pega a sus huesos sin mover nada. Todo se arma con bmesh (sin operadores que dependan de
# la ventana activa), así que corre igual desde el editor de texto o desde la consola.
# =============================================================================================
import math
import random

from mathutils import Matrix, Vector

V = Vector


def construir(c, mats, cols):
    rng = random.Random(c.SEMILLA)
    P = {}  # nombre → Pieza
    OBS, OBSG, ORO, BRILLO, TELA, TELA2, MEMB, HOJA, HIERRO, RUNA = (
        c.OBS, c.OBSG, c.ORO, c.BRILLO, c.TELA, c.TELA2, c.MEMB, c.HOJA, c.HIERRO, c.RUNA)
    A = c.ART
    T = Matrix.Translation

    def pieza(nombre, pivote):
        P[nombre] = c.Pieza(nombre, pivote)
        return P[nombre]

    def banda(p, M, ancho, prof, z, alto=0.5, mat=None):
        """Ribete dorado: una franja apenas más grande que el bloque, en su borde de abajo."""
        p.agregar(c.caja((ancho + 0.35, prof + 0.35, alto), 0.08), M @ T((0, 0, z + alto / 2)), ORO if mat is None
                  else mat)

    def nivel(p, M, abajo, arriba, alto, z, mat=OBS, oro=True, corr=(0, 0), bisel=0.22):
        """Bloque escalonado de armadura (tronco) con su ribete dorado abajo."""
        p.agregar(c.tronco(abajo, arriba, alto, corr, bisel), M @ T((0, 0, z)), mat)
        if oro:
            banda(p, M, abajo[0], abajo[1], z - 0.05)

    def escalar_contorno(pts, extra):
        xs, ys = [q[0] for q in pts], [q[1] for q in pts]
        cx, cy = (max(xs) + min(xs)) / 2, (max(ys) + min(ys)) / 2
        sx = (max(xs) - min(xs) + 2 * extra) / max(1e-4, max(xs) - min(xs))
        sy = (max(ys) - min(ys) + 2 * extra) / max(1e-4, max(ys) - min(ys))
        return [((q[0] - cx) * sx + cx, (q[1] - cy) * sy + cy) for q in pts]

    def placa(p, contorno, grosor, M, mat=OBS, ribete=0.35, bisel=0.12):
        """Placa con silueta propia y ribete dorado que asoma por todo el borde."""
        p.agregar(c.prisma(contorno, grosor, bisel), M, mat)
        if ribete > 0:
            p.agregar(c.prisma(escalar_contorno(contorno, ribete), grosor * 0.55, 0.05),
                      M @ T((0, 0, -grosor * 0.3)), ORO)

    def pua_en(p, base, direccion, radio, largo, mat=ORO, lados=4, aplanar=1.0, curva=0.0, arriba=V((0, -1, 0))):
        p.agregar(c.pua(radio, largo, lados, aplanar, curva, 4), c.marco(base, direccion, arriba), mat)

    # =========================================================================================
    # PIERNAS
    # =========================================================================================
    for s, l in ((1, "L"), (-1, "R")):
        H, K, An = A["Hip_" + l], A["Knee_" + l], A["Ankle_" + l]
        # ---- muslo
        p = pieza("UpperLeg_" + l, H)
        M = c.marco_hueso(H, K)
        L = (K - H).length
        p.agregar(c.tronco((6.6, 7.0), (7.8, 8.2), L + 1.5, (0, 0), 0.3), M @ T((0, 0, -L - 0.4)), OBS)
        nivel(p, M, (8.4, 8.8), (8.0, 8.4), 3.2, -L + 1.2, OBS)
        nivel(p, M, (8.8, 9.2), (8.2, 8.6), 3.4, -L + 4.2, OBSG)
        cont = [(-3.6, -4.5), (3.6, -4.5), (4.0, 2.8), (0.0, 4.4), (-4.0, 2.8)]
        placa(p, cont, 1.1, M @ c.ejes((0, -4.7, -4.4), (1, 0, 0), (0, -0.12, 1)), OBS)
        lado = [(-4.2, -3.0), (3.8, -3.6), (4.4, 2.6), (0.6, 4.8), (-4.0, 2.2)]
        placa(p, lado, 1.0, M @ c.ejes((s * 4.6, 0.2, -4.0), (0, 1, 0), (0, 0, 1)), OBSG)
        # ---- canillera (grebas escalonadas, rodillera con púa)
        p = pieza("LowerLeg_" + l, K)
        M = c.marco_hueso(K, An)
        L = (An - K).length
        nivel(p, M, (9.4, 9.6), (8.8, 9.0), 3.6, -L - 0.3, OBS)
        nivel(p, M, (8.9, 9.1), (8.3, 8.5), 3.6, -L + 3.1, OBSG)
        nivel(p, M, (8.3, 8.5), (7.6, 7.8), 3.9, -L + 6.5, OBS)
        cresta = [(-1.4, -4.2), (1.4, -4.2), (1.0, 3.2), (0, 4.4), (-1.0, 3.2)]
        p.agregar(c.prisma(cresta, 1.2, 0.1), M @ c.ejes((0, -4.95, -L * 0.45), (1, 0, 0), (0, -0.08, 1)), ORO)
        rodilla = [(-3.4, -1.0), (3.4, -1.0), (3.8, 1.8), (0, 3.6), (-3.8, 1.8)]
        Mr = M @ c.ejes((0, -4.6, 0.6), (1, 0, 0), (0, -0.55, 1))
        placa(p, rodilla, 1.6, Mr, OBS)
        pua_en(p, M @ V((0, -5.6, 1.6)), (M.to_3x3() @ V((0, -1.0, 0.75))), 1.15, 4.6, OBS, curva=0.15)
        pua_en(p, M @ V((s * 4.2, -0.5, -L + 6.0)), (M.to_3x3() @ V((s * 1, 0.25, 0.45))), 0.7, 2.4, ORO)
        # ---- bota (pie colosal: suela, empeine, puntera en punta, espolón)
        p = pieza("Foot_" + l, An)
        M = T(An)
        z0 = -An.z
        p.agregar(c.tronco((8.4, 12.8), (8.2, 12.4), 1.6, (0, 0), 0.25), M @ T((0, -2.6, z0)), OBS)
        banda(p, M, 8.2, 12.4, z0 + 1.5, 0.45)
        p.agregar(c.tronco((7.8, 10.4), (7.0, 6.6), 3.8, (0, 1.4), 0.3), M @ T((0, -1.8, z0 + 1.9)), OBSG)
        p.agregar(c.tronco((7.0, 4.2), (5.2, 1.8), 2.5, (0, -0.4), 0.2), M @ T((0, -6.9, z0 + 1.9)), OBS)
        pua_en(p, M @ V((0, -8.4, z0 + 2.6)), V((0, -1, 0.12)), 1.1, 2.6, ORO)
        pua_en(p, M @ V((0, 3.8, z0 + 2.2)), V((0, 1, -0.2)), 0.9, 2.4, OBS)
        nivel(p, M, (8.2, 8.6), (7.6, 8.0), 2.6, z0 + 5.3, OBS)
        for k in (-1, 1):
            pua_en(p, M @ V((k * 1.8, -4.6, z0 + 4.3)), V((k * 0.2, -0.7, 0.7)), 0.55, 1.8, ORO)

    # =========================================================================================
    # CADERA, CINTURÓN Y ESCARCELAS
    # =========================================================================================
    p = pieza("Pelvis", A["Hips"])
    p.agregar(c.tronco((12.4, 9.2), (14.2, 10.2), 5.2, (0, 0), 0.3), T((0, 0.2, 23.6)), OBS)
    p.agregar(c.tronco((15.0, 10.8), (15.4, 11.0), 2.6, (0, 0), 0.15), T((0, 0.2, 28.2)), OBS)
    banda(p, T((0, 0.2, 0)), 15.0, 10.8, 28.0, 0.45)
    banda(p, T((0, 0.2, 0)), 15.4, 11.0, 30.6, 0.45)
    Mh = c.ejes((0, -5.55, 29.5), (1, 0, 0), (0, 0, 1))
    p.agregar(c.prisma(c.contorno_estrella(8, 2.9, 1.25), 0.9, 0.06), Mh, ORO)
    p.agregar(c.esfera(0.75, 12, 8), T((0, -6.05, 29.5)), BRILLO)
    # escarcelas: dos láminas por lado, abiertas hacia afuera
    for ang in (-60, -25, 25, 60, 115, 145, 215, 245):
        a = math.radians(ang - 90)
        radial = V((math.cos(a), math.sin(a), 0))
        tang = V((-radial.y, radial.x, 0))
        base = V((0, 0.2, 28.4)) + V((radial.x * 7.0, radial.y * 5.4, 0))
        for k, (ancho, largo, dz) in enumerate(((5.6, 6.4, 0.0), (5.0, 5.2, -4.6))):
            cont = [(-ancho / 2, 0), (ancho / 2, 0), (ancho / 2 * 0.95, -largo * 0.8), (0, -largo),
                    (-ancho / 2 * 0.95, -largo * 0.8)]
            M = c.ejes(base + radial * (0.9 + k * 0.9) + V((0, 0, dz)), tang, V((0, 0, 1)) - radial * 0.32)
            placa(p, cont, 0.9, M, OBSG if k else OBS, 0.3)

    # =========================================================================================
    # ABDOMEN (segmentos articulados)
    # =========================================================================================
    p = pieza("Abdomen", A["Spine"])
    for k, (z, w) in enumerate(((30.3, 13.4), (32.5, 13.9), (34.7, 14.6))):
        nivel(p, T((0, 0.3, 0)), (w, 9.6 + k * 0.4), (w + 0.5, 10.0 + k * 0.4), 2.5, z, OBSG if k == 1 else OBS)

    # =========================================================================================
    # TORSO: coraza, pectorales, gorjal, espaldar y montura de alas
    # =========================================================================================
    def octo(w, d, z, cy, ch=0.28):
        x, y, a, b = w / 2, d / 2, w / 2 * (1 - ch), d / 2 * (1 - ch)
        return [(V((px, py + cy, z))) for px, py in
                ((-a, -y), (a, -y), (x, -b), (x, b), (a, y), (-a, y), (-x, b), (-x, -b))]

    p = pieza("Chest", A["Chest"])
    secs = [octo(14.6, 10.0, 36.6, 0.4), octo(18.4, 12.0, 40.0, 0.4), octo(20.2, 12.6, 43.6, 0.5),
            octo(19.0, 11.6, 46.4, 0.6), octo(12.0, 8.6, 47.8, 0.6, 0.35)]
    p.agregar(c.loft(secs), None, OBS)
    for s in (1, -1):
        pec = [(0.4, -3.4), (8.8, -1.6), (9.6, 2.8), (8.0, 5.6), (1.0, 4.8), (0.0, 1.4)]
        if s < 0:
            pec = [(-x, y) for x, y in reversed(pec)]
        M = c.ejes((0, -6.55, 40.6), V((math.cos(math.radians(16)), s * math.sin(math.radians(16)), 0)),
                   (0, -0.16, 1))
        placa(p, pec, 1.7, M, OBSG, 0.4)
    # placa baja del esternón y alojamiento del núcleo
    placa(p, [(-4.8, -1.6), (4.8, -1.6), (5.4, 1.4), (0, 3.2), (-5.4, 1.4)], 1.4,
          c.ejes((0, -6.1, 37.4), (1, 0, 0), (0, -0.12, 1)), OBS, 0.3)
    p.agregar(c.cilindro(2.6, 2.6, 1.6, c.n_lados(20)), c.marco((0, -7.0, 42.3), (0, -1, 0)), OBS)
    p.agregar(c.anillo(3.5, 2.2, 1.5, c.n_lados(32)), c.marco((0, -7.9, 42.3), (0, -1, 0)), ORO)
    # gorjal escalonado
    nivel(p, T((0, 0.6, 0)), (12.8, 9.8), (11.8, 9.2), 1.5, 46.4, OBS)
    nivel(p, T((0, 0.6, 0)), (11.2, 8.8), (9.8, 8.0), 1.4, 47.8, OBSG)
    for s in (1, -1):
        for k, (dx, dz, ln) in enumerate(((4.6, 47.6, 2.6), (5.6, 46.8, 2.0))):
            pua_en(p, V((s * dx, 0.4, dz)), V((s * 0.8, -0.1, 0.6)), 0.55, ln, ORO)
    # espaldar con cresta de púas y montura de alas
    placa(p, [(-7.0, -5.0), (7.0, -5.0), (8.2, 3.0), (5.0, 5.4), (-5.0, 5.4), (-8.2, 3.0)], 1.4,
          c.ejes((0, 7.0, 41.6), (-1, 0, 0), (0, 0.1, 1)), OBSG, 0.35)
    for k, z in enumerate((36.8, 39.0, 41.2, 43.4, 45.4)):
        pua_en(p, V((0, 7.4, z)), V((0, 1.0, 0.55)), 0.75, 2.2 + 0.4 * (k % 2), ORO)
    for s in (1, -1):
        Mw = T(A["WingRoot_" + ("L" if s > 0 else "R")] + V((-s * 0.4, 0.4, 0)))
        p.agregar(c.caja((4.8, 3.6, 6.0), 0.4), Mw, OBS)
        banda(p, Mw, 4.8, 3.6, -3.2, 0.6)
        p.agregar(c.caja((3.6, 1.0, 3.4), 0.2), Mw @ T((0, 2.1, 0.4)), ORO)

    # ---- núcleo del pecho (objeto propio: punto débil, estados de daño)
    nucleo = A["Chest"] + V((0, -8.1, 4.8))
    p = pieza("ChestCore", nucleo)
    p.agregar(c.esfera(2.05, c.n_lados(28), c.n_lados(18)), T(nucleo + V((0, 0.35, 0))), RUNA, suave=True)
    Mn = c.ejes(nucleo + V((0, -0.55, 0)), (1, 0, 0), (0, 0, 1))
    rayos = []
    for i in range(14):
        a = math.tau * i / 14 + 0.12
        largo = (4.2 if i % 2 == 0 else 2.6) * (0.85 + rng.random() * 0.3)
        r0 = 3.1
        d = V((math.cos(a), math.sin(a)))
        n = V((-d.y, d.x))
        b0, b1, pt = d * r0 + n * 0.6, d * r0 - n * 0.6, d * (r0 + largo)
        rayos.append((b0, b1, pt))
        p.agregar(c.prisma([(b1.x, b1.y), (pt.x, pt.y), (b0.x, b0.y)], 0.7, 0.04), Mn, ORO)
    p.agregar(c.anillo(2.45, 2.05, 0.9, c.n_lados(32)), Mn @ T((0, 0, -0.1)), BRILLO)

    # =========================================================================================
    # HOMBRERAS (enormes, en capas, con púas doradas)
    # =========================================================================================
    for s, l in ((1, "L"), (-1, "R")):
        S = A["Shoulder_" + l]
        p = pieza("Pauldron_" + l, S)
        M = T(S + V((s * 0.6, 0, 1.6))) @ Matrix.Rotation(math.radians(-s * 20), 4, "Y") @ Matrix.Scale(1.15, 4)
        nivel(p, M @ T((s * 3.0, 0, 0)), (11.2, 13.2), (11.0, 12.8), 1.8, -4.6, OBS)
        nivel(p, M @ T((s * 2.8, 0, 0)), (11.6, 13.6), (10.9, 12.8), 2.4, -2.8, OBSG)
        nivel(p, M @ T((s * 2.6, 0, 0)), (11.4, 13.2), (10.4, 12.2), 2.6, -0.5, OBS)
        nivel(p, M @ T((s * 2.5, 0, 0)), (10.6, 12.4), (7.2, 8.6), 3.6, 2.0, OBSG, corr=(s * -0.6, 0))
        # cresta dorada frontal y púas
        p.agregar(c.caja((8.0, 0.8, 1.0), 0.15), M @ T((s * 2.6, -6.4, 2.6)), ORO)
        for (dx, dy, dz, dirx, diry, ln, r) in ((1.0, -2.6, 5.2, 0.25, -0.2, 6.0, 1.3), (3.6, 0.6, 5.0, 0.6, 0.1, 7.6, 1.5),
                                                (1.4, 3.4, 4.9, 0.2, 0.45, 4.6, 1.1), (5.6, -2.8, 3.6, 0.9, -0.3, 3.6, 0.9),
                                                (5.8, 3.2, 3.4, 0.9, 0.4, 3.2, 0.8)):
            base = M @ V((s * dx, dy, dz))
            pua_en(p, base, M.to_3x3() @ V((s * dirx, diry, 1.0)), r, ln, ORO, curva=0.06)
            p.agregar(c.cilindro(r * 1.25, r * 1.1, 0.7, 6), c.marco(base - (M.to_3x3() @ V((0, 0, 0.3))),
                                                                       M.to_3x3() @ V((s * dirx, diry, 1.0))), OBS)

    # =========================================================================================
    # BRAZOS, ANTEBRAZOS Y PUÑOS
    # =========================================================================================
    for s, l in ((1, "L"), (-1, "R")):
        S, E, W, Hn = A["Shoulder_" + l], A["Elbow_" + l], A["Wrist_" + l], A["Hand_" + l]
        p = pieza("UpperArm_" + l, S)
        M = c.marco_hueso(S, E)
        L = (E - S).length
        p.agregar(c.tronco((5.4, 5.6), (6.0, 6.2), L + 0.8, (0, 0), 0.25), M @ T((0, 0, -L - 0.2)), OBS)
        nivel(p, M, (6.8, 7.0), (6.4, 6.6), 2.4, -L * 0.62, OBSG)
        nivel(p, M, (7.0, 7.2), (6.6, 6.8), 2.0, -L * 0.85, OBS)
        # codera con púa hacia atrás
        placa(p, [(-2.6, -1.8), (2.6, -1.8), (2.2, 1.6), (0, 2.8), (-2.2, 1.6)], 1.2,
              M @ c.ejes((0, 3.6, -L), (1, 0, 0), (0, 0.5, 1)), OBS, 0.3)
        pua_en(p, M @ V((0, 4.4, -L - 0.4)), M.to_3x3() @ V((0, 1.0, -0.5)), 0.95, 3.6, ORO)

        p = pieza("Forearm_" + l, E)
        M = c.marco_hueso(E, W)
        L = (W - E).length
        p.agregar(c.tronco((7.2, 7.4), (5.8, 6.0), L + 0.6, (0, 0), 0.3), M @ T((0, 0, -L)), OBS)
        nivel(p, M, (8.6, 8.8), (7.8, 8.0), 1.8, -L - 0.4, OBSG)
        banda(p, M, 7.0, 7.2, -L * 0.45, 0.45)
        for k, z in enumerate((-L * 0.25, -L * 0.5, -L * 0.75)):
            pua_en(p, M @ V((s * 3.4, 0.8, z)), M.to_3x3() @ V((s * 1.0, 0.5, 0.35)), 0.7, 2.2 + 0.5 * (k == 1), ORO)

        # puño: el eje local +Z va a lo largo del mango (o del antebrazo en la mano izquierda)
        if l == "R":
            eje, nudillos = c.EJE_ESPADA, V((-0.35, -1.0, 0))
        else:
            eje, nudillos = (W - Hn).normalized(), V((0.6, -0.8, 0))
        Mf = c.marco(Hn, eje, -nudillos)  # -Y local = nudillos
        p = pieza("Hand_" + l, W)
        p.agregar(c.caja((4.8, 4.6, 5.4), 0.4), Mf @ T((0, 0.4, 0)), OBS)
        p.agregar(c.caja((5.4, 2.0, 5.8), 0.3), Mf @ T((0, 2.4, 0.2)), OBSG)  # dorso / guantelete
        banda(p, Mf @ T((0, 2.4, 0)), 5.4, 2.0, -3.0, 0.5)
        dorso = Mf @ V((0, 2.9, 0.2))
        p.agregar(c.tronco((5.6, 4.8), (5.0, 4.4), (W - dorso).length + 1.0, (0, 0), 0.25),
                  c.marco(dorso, W - dorso, (0, 0, 1)), OBS)
        p = pieza("Fingers_" + l, Hn)
        for i in range(4):
            z = -2.0 + i * 1.33
            p.agregar(c.caja((4.9, 1.7, 1.18), 0.18), Mf @ T((0, -2.3, z)), OBS)
            p.agregar(c.caja((4.3, 0.55, 0.85), 0.1), Mf @ T((0, -3.2, z)), ORO)
            p.agregar(c.pua(0.33, 1.1, 4, 1.0, 0.0, 2), Mf @ c.marco((1.5 - i % 2 * 1.4, -3.4, z), (0, -1, 0.15)), ORO)
        p = pieza("Thumb_" + l, Hn)
        lado_pulgar = -1.0 if l == "R" else 1.0
        p.agregar(c.caja((1.7, 3.4, 1.7), 0.2), Mf @ T((lado_pulgar * 2.7, -1.0, 2.0)), OBS)
        p.agregar(c.caja((1.2, 0.6, 1.2), 0.1), Mf @ T((lado_pulgar * 2.7, -2.9, 2.0)), ORO)

    # =========================================================================================
    # CASCO: máscara cerrada, visera, ojos de energía, ranura vertical y corona de púas
    # =========================================================================================
    p = pieza("Helmet", A["Neck"])
    cy = 0.3

    def seccion(z, w, d, proa):
        f = cy - d / 2
        return [V((0, f - proa, z)), V((w * 0.36, f, z)), V((w / 2, cy - d * 0.08, z)), V((w * 0.4, cy + d / 2, z)),
                V((-w * 0.4, cy + d / 2, z)), V((-w / 2, cy - d * 0.08, z)), V((-w * 0.36, f, z))]

    secs = [seccion(46.6, 6.4, 6.4, 0.3), seccion(48.0, 7.8, 7.6, 1.5), seccion(49.6, 8.2, 8.2, 1.25),
            seccion(52.2, 8.6, 8.6, 1.05), seccion(54.4, 8.0, 8.2, 0.7), seccion(55.9, 6.0, 6.6, 0.25)]
    p.agregar(c.loft(secs), None, OBS)

    def plano_cara(z, d, w, proa, lado):
        """Matriz sobre la cara frontal del casco (mitad izquierda o derecha de la proa)."""
        f = cy - d / 2
        proa_p = V((0, f - proa, z))
        esquina = V((lado * w * 0.36, f, z))
        u = (esquina - proa_p).normalized()
        n = u.cross(V((0, 0, 1)))
        if n.y > 0:
            n = -n
        return c.ejes(proa_p + n * 0.02, u, (0, 0, 1)), (esquina - proa_p).length

    espejo = Matrix.Scale(-1, 4, (1, 0, 0))
    for lado in (1, -1):
        Mc, ancho = plano_cara(52.0, 8.6, 8.6, 1.05, 1)
        if lado < 0:
            Mc = espejo @ Mc  # el lado derecho es el izquierdo espejado
        ojo = [(0.6, -0.15), (ancho * 0.92, 0.55), (ancho * 0.86, 1.05), (0.5, 0.35)]
        p.agregar(c.prisma(ojo, 0.55, 0.0), Mc @ T((0, 0, 0.0)), BRILLO)
        ceja = [(0.0, 1.0), (ancho * 1.02, 1.55), (ancho * 1.0, 2.2), (0.0, 1.75)]
        p.agregar(c.prisma(ceja, 0.7, 0.05), Mc @ T((0, 0, 0.2)), ORO)
        mejilla = [(0.2, -2.8), (ancho * 0.95, -1.2), (ancho * 0.9, -0.4), (0.3, -0.7)]
        p.agregar(c.prisma(mejilla, 0.8, 0.08), Mc @ T((0, 0, 0.25)), OBSG)
        # aletas laterales barridas hacia atrás
        aleta = [(-2.6, 0.0), (1.2, 0.4), (5.6, 2.6), (1.6, 1.9), (-2.4, 1.5)]
        Ma = c.ejes((4.25, 0.8, 51.3), (0, 1, 0.18), (0, -0.25, 1))
        if lado < 0:
            Ma = espejo @ Ma
        placa(p, aleta, 0.7, Ma, OBS, 0.25)
    p.agregar(c.caja((0.42, 0.7, 4.4), 0.05), T((0, cy - 4.3 - 1.05 - 0.05, 50.4)), BRILLO)  # ranura vertical
    p.agregar(c.pua(0.95, 2.4, 4, 0.8, 0.0, 2), c.marco((0, cy - 3.8 - 1.4, 48.6), (0, -0.35, -1)), OBS)  # mandíbula
    # diadema dorada y corona de púas
    p.agregar(c.loft([seccion(53.9, 8.8, 8.9, 0.95), seccion(55.0, 8.0, 8.2, 0.7)]), None, ORO)
    corona = [(0.0, -1.2, 54.6, 0.0, -0.05, 10.6, 1.45),
              (1.9, -0.9, 54.6, 0.16, 0.0, 8.4, 1.25), (-1.9, -0.9, 54.6, -0.16, 0.0, 8.4, 1.25),
              (3.3, 0.2, 54.3, 0.38, 0.05, 6.4, 1.1), (-3.3, 0.2, 54.3, -0.38, 0.05, 6.4, 1.1),
              (2.2, 2.6, 54.4, 0.25, 0.35, 5.2, 1.0), (-2.2, 2.6, 54.4, -0.25, 0.35, 5.2, 1.0),
              (0.0, 3.4, 54.4, 0.0, 0.45, 4.4, 0.9)]
    p = pieza("Crown", A["Head"])  # corona aparte: en la fase 3 puede romperse o brillar distinto
    for x, y, z, dx, dy, ln, r in corona:
        d = V((dx, dy, 1.0))
        p.agregar(c.pua(r, ln, 4, 0.5, 0.04, 5, giro=0.0), c.marco((x, y, z), d, (0, -1, 0)), OBS)
        p.agregar(c.pua(r * 0.45, ln * 0.55, 4, 0.5, 0.0, 3, giro=0.0),
                  c.marco(V((x, y, z)) + V((0, -r * 0.35, 0.4)), d, (0, -1, 0)), ORO)

    # =========================================================================================
    # HALO DEL ECLIPSE (anillo fracturado con espinas, runas y núcleo de energía)
    # =========================================================================================
    Hc = A["HaloCenter"]
    p = pieza("Halo", Hc)
    Mh = T(Hc) @ Matrix.Rotation(math.radians(90), 4, "X")  # el anillo mira al frente (-Y)
    huecos = [(math.radians(196), math.radians(207)), (math.radians(331), math.radians(338))]
    arcos, inicio = [], huecos[-1][1] - math.tau
    for h0, h1 in huecos:
        arcos.append((inicio, h0))
        inicio = h1
    n = c.n_lados(96)
    for a0, a1 in arcos:
        p.agregar(c.anillo(12.0, 10.4, 1.5, n, OBS, (a0, a1)), Mh, OBS)
        p.agregar(c.anillo(12.35, 11.75, 1.0, n, ORO, (a0, a1)), Mh, ORO)
        p.agregar(c.anillo(10.75, 10.15, 1.0, n, ORO, (a0, a1)), Mh, ORO)
        p.agregar(c.anillo(11.45, 10.95, 1.6, n, HIERRO, (a0 + 0.02, a1 - 0.02)), Mh, HIERRO)
        for extremo in (a0, a1):  # astillas en los bordes rotos
            for k in range(2):
                ang = extremo + (0.03 if extremo == a0 else -0.03)
                r = 10.6 + k * 1.0
                base = V((math.cos(ang) * r, math.sin(ang) * r, 0))
                haciaf = V((-math.sin(ang), math.cos(ang), 0)) * (-1 if extremo == a0 else 1)
                p.agregar(c.pua(0.55, 1.3 + rng.random(), 4, 0.7, 0.0, 2), Mh @ c.marco(base, haciaf), OBS)
    p.agregar(c.anillo(9.9, 9.5, 0.5, n, RUNA), Mh, RUNA)  # núcleo de energía rojo
    for i in range(18):
        ang = math.tau * i / 18 + 0.09
        if any(h0 - 0.08 < ang < h1 + 0.08 for h0, h1 in huecos):
            continue
        largo = (5.4 if i % 3 == 0 else 3.4 if i % 3 == 1 else 2.3) * (0.85 + rng.random() * 0.3)
        d = V((math.cos(ang), math.sin(ang), (rng.random() - 0.5) * 0.25))
        base = V((math.cos(ang) * 11.6, math.sin(ang) * 11.6, 0))
        p.agregar(c.pua(0.95 if i % 3 == 0 else 0.7, largo, 4, 0.5, 0.0, 3, giro=0.0),
                  Mh @ c.marco(base, d, (0, 0, 1)), ORO if i % 3 == 0 else OBS)
    for i in range(30):  # runas: glifos en relieve sobre la cara frontal
        ang = math.tau * (i + 0.5) / 30
        if any(h0 - 0.05 < ang < h1 + 0.05 for h0, h1 in huecos):
            continue
        r = 11.2
        u = V((-math.sin(ang), math.cos(ang), 0))
        rad = V((math.cos(ang), math.sin(ang), 0))
        forma = rng.choice(([(-0.3, -0.3), (0.3, -0.3), (0.0, 0.35)], [(-0.12, -0.35), (0.12, -0.35), (0.12, 0.35),
                            (-0.12, 0.35)], [(-0.3, 0.0), (0.0, -0.32), (0.3, 0.0), (0.0, 0.32)]))
        p.agregar(c.prisma(forma, 0.3, 0.0), Mh @ c.ejes(rad * r + V((0, 0, 0.98)), u, rad), RUNA)

    # =========================================================================================
    # ALAS: hueso de obsidiana, coyunturas doradas con púas, plumas-membrana desgarradas y cadenas
    # =========================================================================================
    def curva_hueso(a, b, alzada):
        medio = (a + b) / 2 + V((0, 0, alzada))
        return lambda t: a * (1 - t) ** 2 + medio * 2 * t * (1 - t) + b * t * t

    for s, l in ((1, "L"), (-1, "R")):
        R, E, W, Tp = A["WingRoot_" + l], A["WingElbow_" + l], A["WingWrist_" + l], A["WingTip_" + l]
        tramos = ((R, E, 1.9, 1.45, 2.0), (E, W, 1.45, 1.1, 1.6), (W, Tp, 1.1, 0.35, 1.2))
        largo_total = sum((b - a).length for a, b, *_ in tramos)
        recorrido = 0.0
        for k, (a, b, r0, r1, alz) in enumerate(tramos):
            p = pieza(f"Wing_{l}_{k + 1}", a)
            f = curva_hueso(a, b, alz)
            secs = []
            pasos = 8
            for i in range(pasos + 1):
                t = i / pasos
                q = f(t)
                tang = (f(min(1, t + 0.01)) - f(max(0, t - 0.01))).normalized()
                r = r0 + (r1 - r0) * t
                M = c.marco(q, tang, (0, 0, 1))
                secs.append([M @ V((math.cos(j / 6 * math.tau) * r, math.sin(j / 6 * math.tau) * r * 0.8, 0))
                             for j in range(6)])
            if k == 2:
                secs.append([Tp + (Tp - W).normalized() * 3.0])
            p.agregar(c.loft(secs), None, OBS)
            # espinas sobre el borde de ataque
            for i in range(1, 5):
                t = i / 5
                q = f(t)
                pua_en(p, q + V((0, 0, (r0 + (r1 - r0) * t) * 0.6)), V((s * 0.25, 0.15, 1.0)),
                       0.5 + 0.15 * (i % 2), 1.8 + 0.8 * (i % 2), OBS)
            # coyuntura dorada con púas (al principio del tramo 2 y 3)
            if k > 0:
                p.agregar(c.esfera(r0 * 1.5, 10, 7), T(a), OBS)
                p.agregar(c.anillo(r0 * 1.75, r0 * 1.2, 1.0, 12), c.marco(a, (b - a)), ORO)
                for j in range(6):
                    ang = j / 6 * math.tau
                    d = V((s * math.cos(ang) * 0.6, math.sin(ang) * 0.5, 0.9 + 0.3 * math.cos(ang)))
                    pua_en(p, a, d, 0.85, 3.8 + 1.8 * (j % 2), ORO, curva=0.08)
            # plumas en abanico: membrana roja (atrás), plumas largas de obsidiana (adelante)
            # y una fila de cobertoras cortas con borde dorado pegada al hueso
            cuantas = (6, 7, 7)[k]
            largo_tramo = (b - a).length
            for i in range(cuantas):
                t = (i + 0.3 + 0.3 * rng.random()) / cuantas
                g = (recorrido + t * largo_tramo) / largo_total
                q = f(t) + V((0, 0, -0.5))
                abre = math.radians(4 + 30 * g ** 1.2 + rng.uniform(-3, 3))
                d = V((s * math.sin(abre), 0.07 + 0.05 * g, -math.cos(abre))).normalized()
                largo = (30 + 9 * math.sin(min(1.0, g / 0.6) * math.pi * 0.85) - 26 * max(0.0, g - 0.55)) * \
                    (0.85 + rng.random() * 0.3)
                ancho = (5.0 - 1.6 * g) * (0.85 + rng.random() * 0.3)
                tang = (f(min(1, t + 0.01)) - f(max(0, t - 0.01))).normalized()
                u = tang - d * tang.dot(d)
                capas = [(MEMB, 1.0, 1.0, 0.0, 3, 0.45, 3, 0.1, 0.0)]
                if i % 3 == 0:
                    capas.append((OBSG, 0.72, 0.55, -0.75, 2, 0.7, 1, 0.3, 0.0))
                if i % 2 == 1 or k == 0:
                    capas.append((OBS, 0.24, 0.8, -1.4, 2, 0.8, 0, 0.35, 1.6))
                for mat, esc_l, esc_a, dy, dientes, grosor, muescas, punta, sube in capas:
                    cont = c.contorno_desgarrado(ancho * esc_a, largo * esc_l, dientes, rng, 0.4, muescas, punta=punta)
                    t2 = c.prisma(cont, grosor, 0.0)
                    copa = 0.04 + 0.04 * rng.random()
                    giro = math.radians(rng.uniform(-6, 6))
                    c.deformar(t2, lambda co, copa=copa, giro=giro: V((
                        co.x * math.cos(giro * co.y / 10) - co.z * math.sin(giro * co.y / 10), co.y,
                        co.z + 0.01 * co.y * co.y + copa * co.x * co.x)))
                    origen = q + V((0, dy, sube))
                    M = c.ejes(origen, u, -d)
                    if (M.to_3x3() @ V((0, 0, 1))).y < 0:  # la curva va hacia atrás
                        M = c.ejes(origen, -u, -d)
                    p.agregar(t2, M, mat)
            # cadenas colgantes con un fragmento de piedra
            if k in (0, 1):
                anc = f(0.55 if k == 0 else 0.4) + V((0, 1.0, -1.2))
                eslabones = 11 if k == 0 else 8
                for j in range(eslabones):
                    pos = anc + V((s * 0.15 * j, 0.05 * j, -j * 1.35))
                    rot = Matrix.Rotation(math.radians(90 * (j % 2)), 4, "Z")
                    p.agregar(c.anillo(0.95, 0.55, 0.32, 10), T(pos) @ rot @ Matrix.Rotation(math.radians(90), 4, "X")
                              @ Matrix.Diagonal((0.75, 1.25, 1.0, 1.0)), HIERRO)
                frag = anc + V((s * 0.15 * eslabones, 0.05 * eslabones, -eslabones * 1.35 - 1.2))
                p.agregar(c.caja((2.0, 1.6, 2.6), 0.2), T(frag) @ Matrix.Rotation(0.5, 4, V((1, 1, 0.3)).normalized()),
                          OBSG)
            recorrido += largo_tramo

    # =========================================================================================
    # ESPADÓN DEL ECLIPSE (eje local +Z hacia el pomo; la hoja va hacia -Z)
    # =========================================================================================
    G = c.AGARRE_ESPADA
    Ms = c.marco(G, c.EJE_ESPADA, (0, 1, 0))
    p = pieza("Sword", G)
    p.agregar(c.cilindro(0.95, 0.95, 5.8, 8), Ms @ T((0, 0, -2.7)), HIERRO)
    for z in (-2.5, 0.3, 2.9):
        p.agregar(c.cilindro(1.18, 1.18, 0.4, 8), Ms @ T((0, 0, z - 0.2)), ORO)
    p.agregar(c.cilindro(1.35, 1.0, 0.7, 8), Ms @ T((0, 0, 3.0)), ORO)
    p.agregar(c.esfera(1.45, 8, 6), Ms @ T((0, 0, 4.6)), OBS)
    for j in range(6):
        ang = j / 6 * math.tau
        p.agregar(c.pua(0.45, 1.5, 4, 1.0, 0.0, 2), Ms @ c.marco((0, 0, 4.6), (math.cos(ang), math.sin(ang), 0.5)), ORO)
    p.agregar(c.pua(0.6, 1.8, 4, 1.0, 0.0, 2), Ms @ T((0, 0, 5.8)), ORO)
    # guarda: disco solar con núcleo rojo y rayos
    zc = -4.2
    Mg = Ms @ T((0, 0, zc)) @ Matrix.Rotation(math.radians(90), 4, "X")  # plano XZ local de la espada
    p.agregar(c.cilindro(3.0, 3.0, 2.0, c.n_lados(20)), Mg @ T((0, 0, -1.0)), OBS)
    p.agregar(c.anillo(3.45, 2.75, 2.3, c.n_lados(24)), Mg, ORO)
    p.agregar(c.esfera(1.75, c.n_lados(20), c.n_lados(14)), Ms @ T((0, 0, zc)), RUNA, suave=True)
    for i in range(16):
        ang = math.tau * i / 16
        if math.sin(ang) > 0.55:  # los rayos de arriba chocarían con el puño
            continue
        horizontal = abs(math.sin(ang)) < 0.2
        largo = 6.2 if horizontal else (3.8 if i % 2 == 0 else 2.4)
        d = V((math.cos(ang), math.sin(ang), 0))
        if horizontal:
            d = (d + V((0, -0.35, 0))).normalized()
        p.agregar(c.pua(0.75 if horizontal else 0.6, largo, 4, 0.45, 0.08 if horizontal else 0.0, 4, giro=0.0),
                  Mg @ c.marco(d * 3.0, d, (0, 0, 1)), ORO if i % 2 == 0 else OBS)
    # hoja: sección romboidal con filos irregulares que se cierra en punta
    z_ini, z_fin = -5.2, -c.GRIP_A_PUNTA
    pasos = c.n_lados(30)
    secs, centro_i = [], []
    for i in range(pasos):
        f = i / pasos
        z = z_ini + (z_fin - z_ini) * f
        w = 6.3 * (1 + 0.12 * math.sin(min(1, f / 0.3) * math.pi * 0.5) - 0.42 * f ** 1.6)
        w *= 1 - max(0.0, (f - 0.84) / 0.16) ** 1.4
        t = 1.6 * (1 - 0.55 * f)
        ji = (rng.random() - 0.3) * 0.55 * (i % 2 == 0) * (f < 0.85)
        jd = (rng.random() - 0.3) * 0.55 * (i % 2 == 1) * (f < 0.85)
        secs.append([V((-w / 2 + ji, 0, z)), V((-w * 0.2, -t / 2, z)), V((w * 0.2, -t / 2, z)),
                     V((w / 2 - jd, 0, z)), V((w * 0.2, t / 2, z)), V((-w * 0.2, t / 2, z))])
        if 0.04 < f < 0.8:
            cw = 0.32 * (1 - f)
            centro_i.append((z, cw, t))
    secs.append([V((0, 0, z_fin))])
    p.agregar(c.loft(secs), Ms, HOJA)
    for lado in (-1, 1):  # canal de magma en las dos caras
        cinta = [[V((-cw, lado * (t / 2 + 0.03), z)), V((cw, lado * (t / 2 + 0.03), z))] for z, cw, t in centro_i]
        p.agregar(c.loft(cinta, cerrado=False), Ms, RUNA)

    # =========================================================================================
    # TELAS: tabardo carmesí con emblema, tabardo hueso, faldones laterales y capa
    # =========================================================================================
    def largos(n, minimo, rng):
        return [minimo + (1 - minimo) * rng.random() ** 0.6 for _ in range(n + 1)]

    top = V((0, -6.0, 30.2))
    p = pieza("Tabard_Front", top)
    Mt = T(top) @ Matrix.Rotation(math.radians(-7), 4, "X")
    p.agregar(c.tela(7.6, 23.5, 8, 16, largos(8, 0.72, rng), 0.3, 0.32, 3.0, 0.0, TELA), Mt, TELA, suave=True)
    Me = Mt @ T((0, -0.75, -8.6)) @ Matrix.Rotation(math.radians(90), 4, "X")
    p.agregar(c.anillo(2.3, 1.85, 0.3, 24), Me, ORO)
    p.agregar(c.prisma(c.contorno_estrella(4, 3.2, 0.6), 0.3, 0.0), Me, ORO)
    p.agregar(c.prisma(c.contorno_estrella(4, 1.6, 0.4, 45), 0.3, 0.0), Me @ T((0, 0, 0.05)), ORO)

    top = V((0, -5.5, 30.4))
    p = pieza("Tabard_Under", top)
    Mt = T(top) @ Matrix.Rotation(math.radians(-5), 4, "X")
    p.agregar(c.tela(10.6, 26.0, 10, 18, largos(10, 0.55, rng), 0.25, 0.45, 4.0, 0.0, TELA2), Mt, TELA2, suave=True)

    for s, l in ((1, "L"), (-1, "R")):
        top = V((s * 7.8, 0.2, 29.6))
        p = pieza("ClothSide_" + l, top)
        Mt = T(top) @ Matrix.Rotation(math.radians(90), 4, "Z") @ Matrix.Rotation(math.radians(-6 * s), 4, "Y") \
            @ Matrix.Rotation(math.radians(-8), 4, "X")
        p.agregar(c.tela(6.0, 17.0, 6, 12, largos(6, 0.5, rng), 0.25, 0.4, 3.0, 0.0, TELA), Mt, TELA, suave=True)

    top = V((0, 7.6, 47.0))
    p = pieza("Cape", top)
    Mt = T(top) @ Matrix.Rotation(math.radians(7), 4, "X")
    p.agregar(c.tela(17.5, 43.0, 14, 24, largos(14, 0.62, rng), 0.3, 0.7, 5.0, -9.0, TELA), Mt, TELA, suave=True)

    # =========================================================================================
    # OBJETOS, JERARQUÍA Y PUNTOS
    # =========================================================================================
    destino = {
        "Wing": "AZR_Alas", "Halo": "AZR_Halo", "Sword": "AZR_Espadon", "Tabard": "AZR_Telas",
        "ClothSide": "AZR_Telas", "Cape": "AZR_Telas",
    }
    obs = {}
    for nombre, pz in P.items():
        col = cols[next((v for k, v in destino.items() if nombre.startswith(k)), "AZR_Cuerpo")]
        obs[nombre] = c.a_objeto(pz, mats, col)

    raiz = c.punto("Root", (0, 0, 0), cols["AZR_Cuerpo"], tipo="ARROWS", tam=6.0)
    raiz.hide_render = True
    padres = {
        "Pelvis": "Root", "Abdomen": "Pelvis", "Chest": "Abdomen", "ChestCore": "Chest", "Helmet": "Chest",
        "Halo": "Chest", "Cape": "Chest", "Crown": "Helmet", "Tabard_Front": "Pelvis", "Tabard_Under": "Pelvis",
        "ClothSide_L": "Pelvis", "ClothSide_R": "Pelvis", "Sword": "Hand_R",
    }
    for l in ("L", "R"):
        padres.update({
            f"Pauldron_{l}": f"UpperArm_{l}", f"UpperArm_{l}": "Chest", f"Forearm_{l}": f"UpperArm_{l}",
            f"Hand_{l}": f"Forearm_{l}", f"Fingers_{l}": f"Hand_{l}", f"Thumb_{l}": f"Hand_{l}",
            f"UpperLeg_{l}": "Pelvis", f"LowerLeg_{l}": f"UpperLeg_{l}", f"Foot_{l}": f"LowerLeg_{l}",
            f"Wing_{l}_1": "Chest", f"Wing_{l}_2": f"Wing_{l}_1", f"Wing_{l}_3": f"Wing_{l}_2",
        })
    # de la raíz hacia afuera, así cada padre ya está ubicado
    orden = ["Pelvis"]
    while len(orden) < len(padres):
        for h, pa in padres.items():
            if h not in orden and (pa == "Root" or pa in orden):
                orden.append(h)
    for h in orden:
        pa = raiz if padres[h] == "Root" else obs[padres[h]]
        c.emparentar(obs[h], pa)
    obs["Root"] = raiz
    puntos(c, obs, cols)
    colisiones(c, obs, cols)
    return obs


def puntos(c, obs, cols):
    """Empties del espadón (agarre, estela, hitboxes de referencia, emisores) y otros puntos de VFX."""
    col = cols["AZR_Puntos"]
    sw = obs["Sword"]
    G, eje = c.AGARRE_ESPADA, c.EJE_ESPADA
    c.punto("Sword_Grip", G, col, sw, "ARROWS", 2.0)
    c.punto("Sword_TrailBase", G - eje * 6.0, col, sw, "SPHERE", 0.6)
    c.punto("Sword_TrailTip", G - eje * 35.6, col, sw, "SPHERE", 0.6)
    c.punto("Sword_FX_Core", G - eje * 4.2, col, sw, "SPHERE", 1.0)
    rot = c.marco(G, eje, (0, 1, 0)).to_euler()
    for i, d in enumerate((12.0, 21.0, 30.0)):
        c.punto(f"Sword_Hitbox_{i + 1}", G - eje * d, col, sw, "CUBE", 1.0, (3.4, 1.0, 4.6), rot)
    c.punto("Core_FX", obs["ChestCore"].location + Vector((0, -0.6, 0)), col, obs["ChestCore"], "SPHERE", 2.5)
    c.punto("Halo_FX_Center", c.ART["HaloCenter"], col, obs["Halo"], "CIRCLE", 12.0, None,
            (math.radians(90), 0, 0))
    c.punto("Helmet_Eyes", Vector((0, -4.9, 52.4)), col, obs["Helmet"], "SPHERE", 0.8)
    for l in ("L", "R"):
        c.punto(f"Wing_{l}_FX_Tip", c.ART["WingTip_" + l], col, obs[f"Wing_{l}_3"], "SPHERE", 1.5)
        c.punto(f"Pauldron_{l}_FX", c.ART["Shoulder_" + l] + Vector((0, 0, 5)), col, obs[f"Pauldron_{l}"],
                "SPHERE", 2.0)
        c.punto(f"Foot_{l}_Ground", Vector((c.ART["Ankle_" + l].x, -2.6, 0)), col, obs[f"Foot_{l}"],
                "CIRCLE", 4.0)


def colisiones(c, obs, cols):
    """Cajas simples (no se renderizan) emparentadas a cada pieza: para hitboxes y física del boss."""
    import bmesh
    import bpy
    col = cols["AZR_Colision"]
    A = c.ART
    caja = [
        ("Head", "Helmet", (A["Neck"] + A["Head"]) / 2 + Vector((0, 0, 3)), (9, 9, 9.5), None),
        ("Chest", "Chest", Vector((0, 0.5, 42)), (21, 13, 11), None),
        ("Abdomen", "Abdomen", Vector((0, 0.3, 33.5)), (15, 10.5, 6.5), None),
        ("Pelvis", "Pelvis", Vector((0, 0.2, 27)), (15.5, 11, 6), None),
    ]
    for l in ("L", "R"):
        caja += [
            ("UpperLeg_" + l, "UpperLeg_" + l, (A["Hip_" + l] + A["Knee_" + l]) / 2, (8.8, 9.2, 12), None),
            ("LowerLeg_" + l, "LowerLeg_" + l, (A["Knee_" + l] + A["Ankle_" + l]) / 2, (9.4, 9.6, 11), None),
            ("Foot_" + l, "Foot_" + l, Vector((A["Ankle_" + l].x, -2.4, 2.8)), (8.4, 12.8, 5.6), None),
            ("UpperArm_" + l, "UpperArm_" + l, (A["Shoulder_" + l] + A["Elbow_" + l]) / 2, (7, 7, 10.5),
             (A["Shoulder_" + l], A["Elbow_" + l])),
            ("Forearm_" + l, "Forearm_" + l, (A["Elbow_" + l] + A["Wrist_" + l]) / 2, (8.6, 8.8, 9.8),
             (A["Elbow_" + l], A["Wrist_" + l])),
        ]
    for nombre, padre, centro, tam, hueso in caja:
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        for v in bm.verts:
            v.co = Vector((v.co.x * tam[0], v.co.y * tam[1], v.co.z * tam[2]))
        me = bpy.data.meshes.new(c.PREFIJO + "COL_" + nombre)
        bm.to_mesh(me)
        bm.free()
        ob = bpy.data.objects.new(c.PREFIJO + "COL_" + nombre, me)
        col.objects.link(ob)
        ob.location = centro
        if hueso:
            ob.rotation_euler = c.marco_hueso(hueso[0], hueso[1]).to_euler()
        ob.display_type = "WIRE"
        ob.hide_render = True
        c.emparentar(ob, obs[padre])
    # punto débil del núcleo: esfera simple
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=3.2)
    me = bpy.data.meshes.new(c.PREFIJO + "HIT_ChestCore")
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(c.PREFIJO + "HIT_ChestCore", me)
    col.objects.link(ob)
    ob.location = obs["ChestCore"].location
    ob.display_type = "WIRE"
    ob.hide_render = True
    c.emparentar(ob, obs["ChestCore"])
