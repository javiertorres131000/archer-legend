# =============================================================================================
# AZRAKOTH · 04_Azrakoth_Animations.py
# Las 20 animaciones del boss como acciones de Blender (AZR_<Nombre>) sobre AZR_Rig, a 30 FPS,
# con marcadores en los momentos que importan para el juego (Telegraph, Hit, FX_..., Recover).
# Esos marcadores son los que después sincronizan hitboxes y VFX en Roblox (KeyframeMarker).
#
# Cómo se escriben las poses: cada hueso recibe una rotación (x, y, z) en grados medida en los
# ejes del boss en reposo (X = su izquierda, -Y = su frente, Z = arriba), sumada a la pose de
# reposo. Así se leen fácil:
#   torso, cuello, cabeza:  +X se inclina hacia adelante · +Z gira hacia su izquierda
#   piernas (apuntan abajo): -X la pierna va adelante · +X atrás · rodilla: +X dobla
#   brazos:  -X levanta el brazo hacia adelante · izq -Y / der +Y lo abre al costado
#   alas:    izq -Y / der +Y suben · izq +Z / der -Z se pliegan hacia atrás
#   "loc:Hueso": traslación en studs (Root para despegar y caer, Hips para agacharse)
# La pose de reposo es la de presentación: el espadón clavado de punta a su derecha.
# =============================================================================================
import math

import bpy
from mathutils import Euler, Quaternion, Vector

FPS = 30


# ---------------------------------------------------------------------------------------------
# HERRAMIENTAS DE POSE
# ---------------------------------------------------------------------------------------------
def m(*poses, **extra):
    """Mezcla poses (las de la derecha pisan a las de la izquierda)."""
    r = {}
    for p in poses:
        r.update(p)
    r.update({k.replace("__", ":"): v for k, v in extra.items()})
    return r


def espejo(p):
    """Pose espejada: izquierda ↔ derecha (Y y Z cambian de signo; X en traslación también)."""
    r = {}
    for k, v in p.items():
        k2 = k.replace("_L", "_TMP").replace("_R", "_L").replace("_TMP", "_R")
        if k.startswith("loc:"):
            r[k2] = (-v[0], v[1], v[2])
        else:
            r[k2] = (v[0], -v[1], -v[2])
    return r


def alas(p1, p2=(0, 0, 0), p3=(0, 0, 0)):
    """Pose simétrica de alas dada para el ala izquierda."""
    izq = {"Wing_L_1": p1, "Wing_L_2": p2, "Wing_L_3": p3}
    return m(izq, espejo(izq))


def capa(x1, x2=None, x3=None, z=0.0):
    x2 = x1 * 1.4 if x2 is None else x2
    x3 = x1 * 1.8 if x3 is None else x3
    return {"Cape_1": (x1, 0, z), "Cape_2": (x2, 0, z * 0.5), "Cape_3": (x3, 0, 0)}


def tabardo(x1, x2=None):
    x2 = x1 * 1.4 if x2 is None else x2
    return {"Tabard_1": (x1, 0, 0), "Tabard_2": (x2, 0, 0), "TabardUnder_1": (x1 * 0.8, 0, 0),
            "TabardUnder_2": (x2 * 0.8, 0, 0)}


# ---------------------------------------------------------------------------------------------
# POSES BASE
# ---------------------------------------------------------------------------------------------
ALAS_REPOSO = alas((0, 0, 0))
ALAS_PLEGADAS = alas((0, 22, 28), (0, 26, 18), (0, 20, 8))
ALAS_ABIERTAS = alas((0, -14, -14), (0, -10, -6), (0, -6, 0))
ALAS_ARRIBA = alas((0, -38, -8), (0, -12, 0), (0, 10, 0))
ALAS_ABAJO = alas((0, 34, -18), (0, 18, 0), (0, 6, 0))
ALAS_FURIA = alas((0, -24, -22), (0, -16, -10), (0, -10, -4))

# Guardia: el espadón sale del suelo y apunta adelante y abajo; la izquierda en puño
GUARDIA = m({"UpperArm_R": (-12, 6, 0), "Forearm_R": (-8, 0, 0), "Hand_R": (-38, 12, 0),
             "UpperArm_L": (-8, -6, 0), "Forearm_L": (-12, 0, 0), "Chest": (4, 0, -4), "Spine": (2, 0, 0),
             "Head": (-4, 0, 4)}, alas((0, 8, 10), (0, 10, 6), (0, 6, 0)))

AGACHADO = {"loc:Hips": (0, 0, -3.0), "UpperLeg_L": (-28, 0, -4), "UpperLeg_R": (-28, 0, 4),
            "LowerLeg_L": (52, 0, 0), "LowerLeg_R": (52, 0, 0), "Foot_L": (-24, 0, 0), "Foot_R": (-24, 0, 0),
            "Spine": (14, 0, 0)}

ARRODILLADO = {"loc:Hips": (0, 2.0, -10.4), "UpperLeg_L": (-78, 0, -6), "LowerLeg_L": (80, 0, 0), "Foot_L": (-2, 0, 0),
               "UpperLeg_R": (-6, 0, 6), "LowerLeg_R": (96, 0, 0), "Foot_R": (-60, 0, 0),
               "Spine": (16, 0, 0), "Chest": (10, 0, 0), "Neck": (14, 0, 0), "Head": (10, 0, 0),
               "UpperArm_R": (-20, 6, 0), "apunta": (-0.05, -0.75, -0.66),  # el espadón apoyado delante
               "Cape_1": (-20, 0, 0), "Cape_2": (-10, 0, 0)}

ESPADA_ARRIBA = {"UpperArm_R": (-150, 18, 0), "Forearm_R": (-30, 0, 0), "Hand_R": (-25, 0, 0),
                 "Chest": (-10, 0, -8), "Spine": (-4, 0, 0), "Head": (-10, 0, 0)}
ESPADA_GOLPE = {"UpperArm_R": (-50, 8, 6), "Forearm_R": (-8, 0, 0), "Hand_R": (-8, 0, 0),
                "Chest": (26, 0, 4), "Spine": (14, 0, 0), "Head": (-8, 0, 0)}


# ---------------------------------------------------------------------------------------------
# LAS 20 ANIMACIONES
# claves: (cuadro, pose) · marcas: {nombre: cuadro} · ciclo: se repite en bucle
# ---------------------------------------------------------------------------------------------
def animaciones():
    A = []

    def anim(nombre, fin, claves, marcas=None, ciclo=False, desc=""):
        A.append({"nombre": nombre, "fin": fin, "claves": claves, "marcas": marcas or {}, "ciclo": ciclo,
                  "desc": desc})

    # 1 · Idle: respira, el halo vibra, las alas y la capa se mecen
    respira = m({"Chest": (-1.8, 0, 0), "Spine": (-0.8, 0, 0), "Head": (-2, 0, 1),
                 "Shoulder_L": (0, -2, 0), "Shoulder_R": (0, 2, 0), "loc:Hips": (0, 0, 0.25)},
                alas((0, -4, -3), (0, -3, 0), (0, -2, 0)), capa(-2), tabardo(-1.5))
    anim("Idle", 120, [(0, {}), (60, respira), (120, {})], {}, True, "Respira con el espadón clavado")

    # 2 · Caminar pesado (en el lugar; Roblox mueve el modelo). 72 cuadros = 2 pasos
    def paso(lado):
        s = 1 if lado == "L" else -1
        o = "R" if lado == "L" else "L"
        return m(GUARDIA, ALAS_PLEGADAS, {
            f"UpperLeg_{lado}": (-26, 0, 0), f"LowerLeg_{lado}": (18, 0, 0), f"Foot_{lado}": (10, 0, 0),
            f"UpperLeg_{o}": (16, 0, 0), f"LowerLeg_{o}": (10, 0, 0), f"Foot_{o}": (-14, 0, 0),
            "Hips": (0, -4 * s, 6 * s), "Chest": (6, 2 * s, -4 - 7 * s), "loc:Hips": (0, 0, -1.4),
            "UpperArm_L": (-8 + 10 * s, -6, 0)}, capa(3, 4, 5, 3 * s), tabardo(-8 * s * 0.5 - 4))

    def pasando(lado):
        o = "R" if lado == "L" else "L"
        return m(GUARDIA, ALAS_PLEGADAS, {
            f"UpperLeg_{lado}": (-8, 0, 0), f"LowerLeg_{lado}": (34, 0, 0), f"Foot_{lado}": (-10, 0, 0),
            f"UpperLeg_{o}": (2, 0, 0), "loc:Hips": (0, 0, 0.5), "Chest": (4, 0, -4)},
                 capa(3, 4, 6), tabardo(-2))

    anim("Walk", 72, [(0, paso("L")), (18, pasando("R")), (36, paso("R")), (54, pasando("L")), (72, paso("L"))],
         {"Step_L": 0, "Step_R": 36}, True, "Paso pesado: cada pisada (Step) sacude el suelo")

    # 3 · Giro hacia un objetivo (90° a su izquierda en el lugar; para la derecha, espejar)
    anim("Turn", 48, [
        (0, GUARDIA),
        (12, m(GUARDIA, {"Chest": (4, 0, 22), "Head": (-4, 0, 18), "Hips": (0, 0, 8)})),
        (24, m(GUARDIA, {"loc:Hips": (0, 0, -1.2), "Root": (0, 0, 45), "Chest": (4, 0, 14), "Head": (-4, 0, 10),
                         "UpperLeg_L": (-20, 0, 0), "LowerLeg_L": (30, 0, 0)})),
        (36, m(GUARDIA, {"Root": (0, 0, 80), "UpperLeg_R": (-18, 0, 0), "LowerLeg_R": (28, 0, 0),
                         "loc:Hips": (0, 0, -1.2)})),
        (48, m(GUARDIA, {"Root": (0, 0, 90)})),
    ], {"Step_L": 24, "Step_R": 40}, False, "Gira 90° a su izquierda pisando dos veces")

    # 4 · Ataque horizontal (barrido de derecha a izquierda)
    carga_h = m(GUARDIA, ALAS_ABIERTAS, {"Chest": (2, 0, -38), "Spine": (0, 0, -14), "Hips": (0, 0, -8),
                                         "UpperArm_R": (-30, 70, -20), "Forearm_R": (-20, 0, 0),
                                         "Head": (-4, 0, 26), "apunta": (-0.65, 0.45, -0.45)})
    corte_h = m(GUARDIA, ALAS_ABIERTAS, {"Chest": (6, 0, 34), "Spine": (2, 0, 14), "Hips": (0, 0, 8),
                                         "UpperArm_R": (-80, 20, 50), "Forearm_R": (-10, 0, 0),
                                         "Head": (-4, 0, -14), "loc:Hips": (0, 0, -2.5), "UpperLeg_L": (-18, 0, 0),
                                         "LowerLeg_L": (16, 0, 0), "apunta": (0.45, -0.45, -0.77)})
    remate_h = m(corte_h, {"Chest": (8, 0, 42), "apunta": (0.7, 0.3, -0.6)})
    anim("AttackHorizontal", 66, [
        (0, GUARDIA), (24, carga_h), (28, m(carga_h, {"Chest": (2, 0, -42)})), (34, corte_h),
        (44, remate_h), (66, GUARDIA),
    ], {"Telegraph": 0, "HitStart": 30, "Hit": 32, "HitEnd": 36, "Recover": 44}, False,
        "Barrido amplio; la ventana de daño va de HitStart a HitEnd")

    # 5 · Ataque vertical = Juicio Carmesí (1,5 s de carga, golpe al suelo)
    arriba = m(ALAS_ABIERTAS, ESPADA_ARRIBA, {"loc:Hips": (0, 0, 0.6)})
    golpe = m(ALAS_ABAJO, ESPADA_GOLPE, AGACHADO, capa(-34, -6, -2), tabardo(-24, -6))
    anim("AttackVertical", 84, [
        (0, GUARDIA), (20, m(arriba, {"Chest": (-6, 0, -6)})), (45, arriba), (51, golpe),
        (56, m(golpe, {"Chest": (30, 0, 4)})), (66, golpe), (84, GUARDIA),
    ], {"Telegraph": 0, "FX_ChargeBlade": 10, "Hit": 51, "FX_Shockwave": 51, "CameraShake": 51, "Recover": 66},
        False, "Juicio Carmesí: levanta 1,5 s y golpea el suelo (onda en FX_Shockwave)")

    # 6 · Combo de tres golpes (Danza del Verdugo)
    reves_carga = m(remate_h, {"Chest": (4, 0, 36), "UpperArm_R": (-90, 0, 60), "apunta": (0.75, 0.3, -0.1)})
    reves = m(GUARDIA, ALAS_ABIERTAS, {"Chest": (4, 0, -30), "Spine": (0, 0, -10), "UpperArm_R": (-60, 60, -20),
                                       "Forearm_R": (-20, 0, 0), "Head": (-4, 0, 20), "apunta": (-0.45, -0.45, -0.77)})
    anim("Combo3", 120, [
        (0, GUARDIA), (10, carga_h), (18, corte_h), (26, reves_carga),
        (36, reves), (44, m(reves, {"Chest": (6, 0, -38), "apunta": (-0.7, 0.3, -0.6)})),
        (56, m(GUARDIA, ALAS_FURIA)), (78, m(arriba, ALAS_FURIA)), (86, golpe), (96, golpe), (120, GUARDIA),
    ], {"Hit1": 18, "Hit2": 36, "Telegraph3": 56, "Hit3": 86, "FX_Shockwave": 86, "Recover": 96}, False,
        "Danza del Verdugo: dos tajos rápidos y un tercero con carga larga (castiga la esquiva temprana)")

    # 7 · Apertura de alas
    anim("WingsOpen", 45, [
        (0, GUARDIA), (14, m(GUARDIA, alas((0, 12, 8), (0, 16, 6)), {"Chest": (8, 0, 0)})),
        (30, m(GUARDIA, ALAS_FURIA, {"Chest": (-8, 0, 0), "Head": (-10, 0, 0)})),
        (45, m(GUARDIA, ALAS_ABIERTAS, {"Chest": (-3, 0, 0)})),
    ], {"FX_WingBurst": 30}, False, "Despliega las alas (antes de Tormenta de Alas)")

    # 8 · Despegue
    anim("TakeOff", 60, [
        (0, GUARDIA), (16, m(GUARDIA, AGACHADO, ALAS_ARRIBA)),
        (26, m(GUARDIA, ALAS_ABAJO, {"loc:Root": (0, 0, 6), "UpperLeg_L": (10, 0, 0), "UpperLeg_R": (10, 0, 0),
                                     "Foot_L": (30, 0, 0), "Foot_R": (30, 0, 0)})),
        (40, m(GUARDIA, ALAS_ARRIBA, {"loc:Root": (0, 0, 16), "LowerLeg_L": (20, 0, 0), "LowerLeg_R": (26, 0, 0)})),
        (60, m(GUARDIA, ALAS_ABAJO, {"loc:Root": (0, 0, 26), "LowerLeg_L": (20, 0, 0), "LowerLeg_R": (26, 0, 0)})),
    ], {"FX_TakeOffDust": 22, "Airborne": 26}, False, "Se agacha, bate las alas y sube 26 studs")

    # 9 · Vuelo (bucle; la altura la mantiene Roblox)
    vuela = m(GUARDIA, {"apunta": (-0.1, 0.35, -0.93), "LowerLeg_L": (20, 0, 0), "LowerLeg_R": (28, 0, 0), "UpperLeg_L": (8, 0, 0),
                        "UpperLeg_R": (14, 0, 0), "Spine": (10, 0, 0), "loc:Root": (0, 0, 26)}, capa(18, 22, 26))
    anim("Fly", 40, [
        (0, m(vuela, ALAS_ARRIBA)), (20, m(vuela, ALAS_ABAJO, {"loc:Root": (0, 0, 27.5)})), (40, m(vuela, ALAS_ARRIBA)),
    ], {"FX_WingBeat": 20}, True, "Aleteo en el aire")

    # 10 · Caída del Serafín
    picado = m(alas((0, 10, 40), (0, 20, 30), (0, 16, 10)), {"loc:Root": (0, 0, 22),
               "UpperArm_R": (-60, 0, 0), "Forearm_R": (-40, 0, 0), "apunta": (0.0, -0.25, -1.0),
               "UpperLeg_L": (-30, 0, 0), "UpperLeg_R": (-10, 0, 0), "LowerLeg_L": (60, 0, 0),
               "LowerLeg_R": (40, 0, 0)}, capa(-30, -20, -10))
    anim("SeraphFall", 100, [
        (0, m(vuela, ALAS_ARRIBA, {"loc:Root": (0, 0, 40)})), (20, m(vuela, ALAS_ABIERTAS, {"loc:Root": (0, 0, 42)})),
        (34, m(picado, {"loc:Root": (0, 0, 38)})), (46, picado), (50, m(golpe, ALAS_FURIA)),
        (64, m(golpe, ALAS_FURIA)), (100, GUARDIA),
    ], {"Telegraph": 0, "FX_LandingMarker": 0, "Dive": 34, "Hit": 50, "FX_FireColumn": 50, "FX_Crater": 50,
        "CameraShake": 50, "Recover": 64}, False,
        "Planea, marca el aterrizaje, cae en picada con la espada y golpea (columna de fuego)")

    # 11 · Invocación de cadenas
    puño_arriba = {"UpperArm_L": (-150, -20, 0), "Forearm_L": (-30, 0, 0), "Head": (-14, 0, 0), "Chest": (-8, 0, 0)}
    puño_suelo = m(AGACHADO, capa(-40, -8, -2), {"UpperArm_L": (-20, -10, 0), "Forearm_L": (-5, 0, 0),
                                               "Chest": (34, 0, 0), "Spine": (22, 0, 0), "Head": (-14, 0, 0),
                                               "loc:Hips": (0, 0, -6.0), "apunta": (-0.4, -0.7, -0.45)})
    anim("ChainSummon", 75, [
        (0, GUARDIA), (24, m(GUARDIA, ALAS_ABIERTAS, puño_arriba)), (34, m(GUARDIA, ALAS_ABAJO, puño_suelo)),
        (54, m(GUARDIA, ALAS_ABAJO, puño_suelo)), (75, GUARDIA),
    ], {"Telegraph": 0, "FX_SummonCircles": 10, "Cast": 34, "Recover": 54}, False,
        "Levanta el puño y golpea el suelo: salen las cadenas (círculos de aviso desde FX_SummonCircles)")

    # 12 · Carga del núcleo (Corazón del Eclipse) — bucle mientras haya cristales
    abre = m(ALAS_FURIA, {"UpperArm_L": (-20, -60, 0), "UpperArm_R": (-20, 40, 0), "Forearm_L": (-20, 0, 0),
                          "Chest": (-14, 0, 0), "Spine": (-6, 0, 0), "Head": (-20, 0, 0), "loc:Hips": (0, 0, 0.8)})
    anim("CoreCharge", 60, [
        (0, abre), (30, m(abre, {"Chest": (-18, 0, 0), "Head": (-24, 0, 0), "loc:Hips": (0, 0, 1.4)})), (60, abre),
    ], {"FX_CorePulse": 0, "FX_CorePulse2": 30}, True, "Pecho abierto absorbiendo energía (núcleo vulnerable)")

    # 13 · Invocación de soldados (clava la espada)
    alza = m(ALAS_ABIERTAS, {"UpperArm_R": (-165, 10, 0), "Forearm_R": (-10, 0, 0), "apunta": (0.05, -0.1, 1.0),
                             "Head": (-16, 0, 0), "Chest": (-10, 0, 0)})
    clava = m(AGACHADO, ALAS_ABAJO, capa(-30, -6, -2), {"UpperArm_R": (-50, 10, 0), "Forearm_R": (-30, 0, 0),
                                                        "apunta": (0.0, -0.2, -1.0), "Chest": (26, 0, 0),
                                                        "loc:Hips": (0, 0, -5)})
    anim("SummonSoldiers", 80, [
        (0, GUARDIA), (28, alza), (40, clava), (60, clava), (80, GUARDIA),
    ], {"Telegraph": 0, "Summon": 40, "FX_Portals": 40, "Recover": 60}, False,
        "Alza el espadón y lo clava: se abren los portales de los cuatro caballeros")

    # 14 · Carga del Rayo del Eclipse (bucle)
    carga_rayo = m(ALAS_FURIA, {"Chest": (-12, 0, 0), "Neck": (-10, 0, 0), "Head": (-14, 0, 0),
                                "UpperArm_L": (-30, -50, 0), "Forearm_L": (-30, 0, 0), "Hand_R": (-20, 0, 0)})
    anim("BeamCharge", 60, [
        (0, carga_rayo), (30, m(carga_rayo, {"Chest": (-15, 0, 0), "Halo": (0, 0, 0)})), (60, carga_rayo),
    ], {"FX_HaloSpinUp": 0, "FX_Runes": 0}, True, "El halo acelera y junta energía (cristales interrumpen)")

    # 15 · Rayo del Eclipse: barrido de su derecha a su izquierda
    dispara = m(ALAS_FURIA, {"Chest": (12, 0, 0), "Neck": (8, 0, 0), "Head": (6, 0, 0), "UpperArm_L": (-20, -40, 0)})
    anim("BeamFire", 100, [
        (0, carga_rayo), (10, m(dispara, {"Chest": (12, 0, -40), "Hips": (0, 0, -10)})),
        (85, m(dispara, {"Chest": (12, 0, 40), "Hips": (0, 0, 10)})), (100, GUARDIA),
    ], {"BeamStart": 10, "BeamEnd": 85, "Recover": 90}, False,
        "Barre de derecha a izquierda: la dirección se lee en el giro del pecho")

    # 16 · Transformación de fase (Ira del Serafín Caído)
    anim("PhaseTransform", 130, [
        (0, GUARDIA), (20, m(GUARDIA, AGACHADO, {"Chest": (30, 0, 0), "Head": (20, 0, 0),
                                                 "apunta": (-0.3, -0.75, -0.55)}, ALAS_PLEGADAS)),
        (60, m(ARRODILLADO, ALAS_PLEGADAS, {"UpperArm_L": (-40, -10, 0)})),
        (78, m(abre, {"loc:Hips": (0, 0, 0.5), "Chest": (-22, 0, 0), "Head": (-30, 0, 0)})),
        (100, m(abre, {"Chest": (-22, 0, 0), "Head": (-30, 0, 0)})), (130, m(GUARDIA, ALAS_FURIA)),
    ], {"FX_Implode": 20, "FX_Burst": 78, "CameraShake": 78, "PhaseChange": 78, "Recover": 110}, False,
        "Cae de rodillas, junta energía y explota: cambia la iluminación y las grietas brillan más")

    # 17 · Aturdimiento (bucle de rodillas)
    aturdido = m(ARRODILLADO, alas((0, 30, 20), (0, 30, 10), (0, 20, 0)), {"UpperArm_L": (-30, 0, 0)})
    anim("Stunned", 60, [
        (0, aturdido), (30, m(aturdido, {"Chest": (14, 4, 6), "Head": (16, 0, -8)})), (60, aturdido),
    ], {"FX_StunStars": 0}, True, "De rodillas y tambaleando: ventana para castigarlo")

    # 18 · Recibir daño
    golpeado = m(GUARDIA, {"Chest": (-10, 0, 6), "Head": (-14, 0, 8), "Spine": (-4, 0, 0)},
                 alas((0, -10, -6)))
    anim("HitReact", 22, [(0, GUARDIA), (5, golpeado), (22, GUARDIA)], {"Hit": 0}, False, "Retrocede al recibir daño")

    # 19 · Muerte
    anim("Death", 160, [
        (0, GUARDIA), (20, m(golpeado, {"Chest": (-18, 0, 10)})), (50, m(ARRODILLADO, alas((0, 30, 30)),
                                                                          {"Hand_R": (-20, 0, 0)})),
        (90, m(ARRODILLADO, alas((0, 40, 40), (0, 30, 20)), {"Chest": (30, 0, 0), "Head": (30, 0, 0),
                                                             "apunta": (-0.85, -0.35, -0.4), "Fingers_R": (-60, 0, 0)})),
        (130, m(ARRODILLADO, alas((0, 40, 60), (0, 30, 30), (0, 20, 10)), capa(-60, -10, 0), {
            "loc:Hips": (0, -4, -12.0), "Spine": (40, 0, 0), "Chest": (40, 0, 0), "Head": (30, 0, 0),
            "UpperArm_L": (-40, 0, 0), "UpperArm_R": (-30, 20, 0), "apunta": (-0.95, -0.25, -0.15),
            "Fingers_R": (-60, 0, 0)})),
        (160, m(ARRODILLADO, alas((0, 42, 62), (0, 32, 30), (0, 20, 10)), capa(-62, -10, 0), {
            "loc:Hips": (0, -4.5, -12.5), "Spine": (42, 0, 0), "Chest": (42, 0, 0), "Head": (32, 0, 0),
            "UpperArm_L": (-42, 0, 0), "UpperArm_R": (-32, 20, 0), "apunta": (-0.97, -0.22, -0.1),
            "Fingers_R": (-60, 0, 0)})),
    ], {"FX_CoreCrack": 20, "FX_Knees": 50, "FX_SwordDrop": 90, "FX_Collapse": 130, "Dead": 150}, False,
        "Se quiebra el núcleo, cae de rodillas, suelta el espadón y se derrumba")

    # 20 · Presentación cinematográfica
    anim("Intro", 200, [
        (0, m(ARRODILLADO, ALAS_PLEGADAS, {"Head": (30, 0, 0), "Neck": (20, 0, 0)})),
        (40, m(ARRODILLADO, ALAS_PLEGADAS, {"Head": (10, 0, 0)})),
        (100, m({}, ALAS_PLEGADAS, {"loc:Hips": (0, 0, 0.2)})),
        (140, m({}, ALAS_FURIA, {"Chest": (-6, 0, 0)})),
        (165, m(ALAS_FURIA, {"UpperArm_R": (-160, 10, 0), "Forearm_R": (-10, 0, 0), "apunta": (-0.1, -0.1, 1.0),
                             "Head": (-18, 0, 0), "Chest": (-8, 0, 0)})),
        (200, m(GUARDIA, ALAS_ABIERTAS)),
    ], {"FX_EyesOn": 40, "FX_Rise": 60, "FX_WingsUnfurl": 110, "Roar": 160, "CameraShake": 160, "Fight": 200},
        False, "Arrodillado con las alas cerradas, se levanta, despliega las alas y alza el espadón")
    return A


# ---------------------------------------------------------------------------------------------
# ESCRITURA DE LAS ACCIONES
# ---------------------------------------------------------------------------------------------
def _q(rot):
    return Euler(tuple(math.radians(a) for a in rot), "XYZ").to_quaternion()


def resolver(rig, pose):
    """"apunta": (x, y, z) orienta el espadón hacia esa dirección (en ejes del boss) calculando el
    giro de la muñeca derecha a partir de cómo quedaron el torso y el brazo en esa misma pose."""
    if "apunta" not in pose:
        return pose
    pose = dict(pose)
    destino = Vector(pose.pop("apunta")).normalized()
    cadena = []
    b = rig.data.bones["Hand_R"].parent
    while b is not None:
        cadena.append(b.name)
        b = b.parent
    q_padres = Quaternion()
    for nombre in reversed(cadena):  # de la raíz hacia la mano: q_raíz · … · q_antebrazo
        q_padres = q_padres @ _q(pose.get(nombre, (0, 0, 0)))
    sw = rig.data.bones["Sword"]
    reposo = (sw.tail_local - sw.head_local).normalized()
    q_mano = q_padres.inverted() @ reposo.rotation_difference(destino)
    pose["Hand_R"] = tuple(math.degrees(a) for a in q_mano.to_euler("XYZ"))
    return pose


def _quat_local(rig, hueso, rot):
    R = rig.data.bones[hueso].matrix_local.to_quaternion()
    qw = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_quaternion()
    return R.inverted() @ qw @ R


def _loc_local(rig, hueso, d):
    R = rig.data.bones[hueso].matrix_local.to_quaternion()
    return R.inverted() @ Vector(d)


def crear_accion(c, rig, a):
    nombre = c.PREFIJO + a["nombre"]
    vieja = bpy.data.actions.get(nombre)
    if vieja:
        bpy.data.actions.remove(vieja)
    act = bpy.data.actions.new(nombre)
    act.use_fake_user = True  # queda guardada aunque no esté asignada
    rig.animation_data_create()
    rig.animation_data.action = act
    usados = {k[4:] if k.startswith("loc:") else k for _, p in a["claves"] for k in p if k != "apunta"}
    faltan = [h for h in usados if h not in rig.pose.bones]
    # se clavan TODOS los huesos en cada clave: un hueso sin clave quedaría con la pose de la
    # animación anterior (en Blender y en Roblox)
    rot_huesos = [pb.name for pb in rig.pose.bones]
    loc_huesos = ["Root", "Hips"]
    if faltan:
        raise KeyError(f"{a['nombre']}: huesos que no existen: {faltan}")
    anterior = {}
    for cuadro, pose in a["claves"]:
        pose = resolver(rig, pose)
        for h in rot_huesos:
            pb = rig.pose.bones[h]
            q = _quat_local(rig, h, pose.get(h, (0, 0, 0)))
            if h in anterior and anterior[h].dot(q) < 0:  # mismo giro, sin dar la vuelta larga
                q = -q
            anterior[h] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=cuadro, group=h)
        for h in loc_huesos:
            pb = rig.pose.bones[h]
            pb.location = _loc_local(rig, h, pose.get("loc:" + h, (0, 0, 0)))
            pb.keyframe_insert("location", frame=cuadro, group=h)
    for marca, cuadro in sorted(a["marcas"].items(), key=lambda x: x[1]):
        mk = act.pose_markers.new(marca)
        mk.frame = cuadro
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, a["fin"]
    try:
        act.use_cyclic = a["ciclo"]
    except Exception:
        pass
    act["descripcion"] = a["desc"]
    act["bucle"] = a["ciclo"]
    for pb in rig.pose.bones:  # vuelve a reposo para la próxima acción
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    return act


def ejecutar(ctx):
    c = ctx["core"]
    rig = ctx.get("rig") or c.RIG
    if rig is None:
        c.log("Animaciones: no hay rig (falta 03_Azrakoth_Rig.py); no creo acciones.")
        return
    esc = bpy.context.scene
    esc.render.fps = FPS
    acciones = [crear_accion(c, rig, a) for a in animaciones()]
    rig.animation_data.action = bpy.data.actions[c.PREFIJO + "Idle"]
    esc.frame_start, esc.frame_end = 0, 120
    esc.frame_set(0)
    ctx["acciones"] = acciones
    marcas = sum(len(a.pose_markers) for a in acciones)
    c.log(f"Animaciones: {len(acciones)} acciones a {FPS} FPS con {marcas} marcadores (activa: AZR_Idle)")
