# =============================================================================================
# AZRAKOTH — EL SERAFÍN DEL ECLIPSE CARMESÍ · Build_Azrakoth.py
# Script principal para Blender 5.2.2 LTS.
#
# CÓMO USARLO
#   1. Dejá la carpeta AZRAKOTH/blender completa (todos los .py juntos).
#   2. Blender → pestaña Scripting → Abrir → Build_Azrakoth.py → Alt + P (o el botón ▶).
#   3. Se arma todo dentro de la colección AZRAKOTH_BOSS. Correrlo de nuevo lo rehace sin
#      duplicar nada y sin tocar objetos que no sean del proyecto (todo lleva el prefijo AZR_).
#
# Por consola (opcional):
#   blender --background --python Build_Azrakoth.py
#   Variables: AZR_RENDER=1 (renderiza las cámaras en AZRAKOTH/output), AZR_GUARDAR=1 (guarda
#   Azrakoth.blend), AZR_DETALLE=0.6/1.0/1.5, AZR_MUESTRAS=64, AZR_MOTOR=CYCLES.
#
# Si Blender no encuentra los demás scripts (pasa si pegaste el texto en un bloque nuevo sin
# guardarlo), escribí la ruta de la carpeta en CARPETA_MANUAL.
# =============================================================================================
import importlib.util
import math
import os
import sys
import time
import traceback

import bpy

CARPETA_MANUAL = ""  # ej.: r"C:\Users\vos\Documents\AZRAKOTH\blender"

ETAPAS = [
    # (archivo, obligatoria)
    ("00_Azrakoth_Core.py", True),
    ("02_Azrakoth_Materials.py", True),
    ("01_Azrakoth_Model.py", True),
    ("03_Azrakoth_Rig.py", False),          # etapa 2
    ("04_Azrakoth_Animations.py", False),   # etapa 2
    ("05_Azrakoth_VFX_Preview.py", False),  # etapa 3
    ("07_Azrakoth_Presentation.py", True),
    ("06_Azrakoth_Export.py", False),       # etapa de exportación a Roblox
]


def carpeta_scripts():
    candidatos = []
    if CARPETA_MANUAL:
        candidatos.append(CARPETA_MANUAL)
    f = globals().get("__file__")
    if f:
        candidatos.append(os.path.dirname(os.path.abspath(bpy.path.abspath(f))))
    for txt in bpy.data.texts:  # corriendo desde el editor de texto: la ruta del archivo abierto
        if txt.filepath and "Build_Azrakoth" in os.path.basename(txt.filepath):
            candidatos.append(os.path.dirname(bpy.path.abspath(txt.filepath)))
    if bpy.data.filepath:
        base = os.path.dirname(bpy.data.filepath)
        candidatos += [base, os.path.join(base, "blender"), os.path.join(base, "AZRAKOTH", "blender")]
    for cand in candidatos:
        if cand and os.path.isfile(os.path.join(cand, "00_Azrakoth_Core.py")):
            return cand
    raise RuntimeError(
        "No encuentro 00_Azrakoth_Core.py. Abrí Build_Azrakoth.py desde la carpeta AZRAKOTH/blender "
        "(Texto → Abrir) o escribí la ruta en CARPETA_MANUAL, arriba de este script.")


def cargar(carpeta, archivo):
    ruta = os.path.join(carpeta, archivo)
    nombre = "azrakoth_" + os.path.splitext(archivo)[0].lower()
    spec = importlib.util.spec_from_file_location(nombre, ruta)
    mod = importlib.util.module_from_spec(spec)
    sys.modules[nombre] = mod  # se recarga en cada corrida (no queda una versión vieja en memoria)
    spec.loader.exec_module(mod)
    return mod


def validar(c, obs, cams):
    """Medidas y chequeos del modelo armado. Devuelve la lista de problemas (vacía si está todo bien)."""
    bpy.context.view_layer.update()
    problemas, info = [], []
    modelo = [o for o in obs.values() if o.type == "MESH"]
    nan = [o.name for o in modelo if any(not math.isfinite(x) for v in o.data.vertices for x in v.co)]
    if nan:
        problemas.append(f"Vértices inválidos (NaN) en: {', '.join(nan)}")
    sin_mat = [o.name for o in modelo if not o.data.materials or any(m is None for m in o.data.materials)]
    if sin_mat:
        problemas.append(f"Piezas sin material: {', '.join(sin_mat)}")
    duplicados = [o.name for o in modelo if "." in o.name]
    if duplicados:
        problemas.append(f"Nombres duplicados (con .001): {', '.join(duplicados)}")
    vacias = [o.name for o in modelo if len(o.data.polygons) == 0]
    if vacias:
        problemas.append(f"Piezas vacías: {', '.join(vacias)}")

    def caja(objetos):
        pts = [o.matrix_world @ v.co for o in objetos for v in o.data.vertices]
        mn = [min(p[i] for p in pts) for i in range(3)]
        mx = [max(p[i] for p in pts) for i in range(3)]
        return mn, mx

    mn, mx = caja(modelo)
    sin_corona = [o for o in modelo if not o.name.startswith(tuple(c.PREFIJO + n for n in (
        "Crown", "Halo", "Pauldron")))]
    altura_total = caja([o for o in modelo if not o.name.startswith((c.PREFIJO + "Wing", c.PREFIJO + "Halo"))])[1][2]
    info.append(f"  (las alas llegan a Z = {mx[2]:.1f} y el halo a "
                f"{caja([obs['Halo']])[1][2]:.1f}; la altura total se mide hasta la corona)")
    envergadura = mx[0] - mn[0]
    cuerpo = caja([o for o in sin_corona if not o.name.startswith(c.PREFIJO + "Wing")])[1][2]
    hombros = (c.ART["Shoulder_L"] - c.ART["Shoulder_R"]).length
    sw = obs.get("Sword")
    largo_espada = 0.0
    if sw:
        eje = c.EJE_ESPADA
        proy = [(sw.matrix_world @ v.co).dot(eje) for v in sw.data.vertices]
        largo_espada = max(proy) - min(proy)
    halo = 2 * 12.35  # anillo exterior (sin espinas)
    pie = caja([obs["Foot_L"]])
    ancho_pie = pie[1][0] - pie[0][0]
    pisa = min(caja([obs["Foot_L"], obs["Foot_R"]])[0][2], 99)
    medidas = [
        ("altura_total", altura_total), ("altura_cuerpo", cuerpo), ("hombros", hombros),
        ("envergadura", envergadura), ("espadon", largo_espada), ("halo", halo), ("pie", ancho_pie),
    ]
    for clave, valor in medidas:
        objetivo = c.MEDIDAS[clave]
        desvio = abs(valor - objetivo) / objetivo
        estado = "ok" if desvio <= 0.08 else "REVISAR"
        info.append(f"  {clave:<14} {valor:7.1f} studs  (objetivo {objetivo:.0f})  {estado}")
        if desvio > 0.08:
            problemas.append(f"{clave}: {valor:.1f} studs (objetivo {objetivo:.0f})")
    if abs(pisa) > 0.05:
        problemas.append(f"Los pies no apoyan en Z=0 (la suela está en {pisa:.2f})")
    total_tris = sum(c.tris(o) for o in modelo)
    info.append(f"  piezas: {len(modelo)} · triángulos (alta calidad): {total_tris:,}".replace(",", "."))
    info.append(f"  la punta del espadón queda en Z = {(c.PUNTA_ESPADA.z):.2f} (clavada en el suelo)")
    return problemas, info, medidas


def render(c, cams, salida):
    esc = bpy.context.scene
    motor_original = esc.render.engine
    motor = os.environ.get("AZR_MOTOR")
    if motor:
        esc.render.engine = motor
    if esc.render.engine == "CYCLES":
        esc.cycles.samples = int(os.environ.get("AZR_MUESTRAS", "64"))
        esc.cycles.use_denoising = True
    elegidas = os.environ.get("AZR_CAMARAS")
    nombres = elegidas.split(",") if elegidas else list(cams)
    for nombre in nombres:
        cam = cams[nombre]
        w, h = cam["resolucion"]
        esc.render.resolution_x, esc.render.resolution_y = int(w), int(h)
        esc.render.resolution_percentage = int(os.environ.get("AZR_PORCENTAJE", "100"))
        esc.camera = cam
        esc.render.filepath = os.path.join(salida, f"Azrakoth_{nombre}.png")
        t0 = time.time()
        bpy.ops.render.render(write_still=True)
        c.log(f"Render {nombre}: {time.time() - t0:.0f} s → {esc.render.filepath}")
    esc.camera = cams["Heroica"]
    esc.render.engine = motor_original  # el .blend queda con el motor de la escena (Eevee)
    w, h = cams["Heroica"]["resolucion"]
    esc.render.resolution_x, esc.render.resolution_y, esc.render.resolution_percentage = int(w), int(h), 100


def main():
    t0 = time.time()
    carpeta = carpeta_scripts()
    salida = os.path.abspath(os.path.join(carpeta, "..", "output"))
    etapa = "inicio"
    try:
        if bpy.context.object and bpy.context.object.mode != "OBJECT":
            bpy.ops.object.mode_set(mode="OBJECT")
        etapa = "00 Core"
        c = cargar(carpeta, "00_Azrakoth_Core.py")
        c.log(f"Scripts en {carpeta}")
        etapa = "limpieza"
        c.limpiar()
        c.quitar_cubo_inicial()
        raiz, cols = c.preparar_colecciones()
        etapa = "02 Materiales"
        matmod = cargar(carpeta, "02_Azrakoth_Materials.py")
        mats = matmod.crear(c, raiz)
        etapa = "01 Modelo"
        modelo = cargar(carpeta, "01_Azrakoth_Model.py")
        obs = modelo.construir(c, mats, cols)
        c.log(f"Modelo: {sum(1 for o in obs.values() if o.type == 'MESH')} piezas")
        ctx = {"core": c, "mats": mats, "obs": obs, "cols": cols, "salida": salida}
        for archivo, obligatoria in ETAPAS:
            if archivo in ("00_Azrakoth_Core.py", "02_Azrakoth_Materials.py", "01_Azrakoth_Model.py",
                           "07_Azrakoth_Presentation.py"):
                continue
            ruta = os.path.join(carpeta, archivo)
            if not os.path.isfile(ruta):
                c.log(f"{archivo}: todavía no está (llega en una próxima etapa); sigo sin él.")
                continue
            etapa = archivo
            mod = cargar(carpeta, archivo)
            mod.ejecutar(ctx)
        etapa = "07 Presentación"
        pres = cargar(carpeta, "07_Azrakoth_Presentation.py")
        cams = pres.construir(c, matmod, obs, mats, cols)
        etapa = "validación"
        problemas, info, _ = validar(c, obs, cams)
        c.log("Medidas del boss:")
        for linea in info:
            print(linea)
        for prob in problemas:
            c.log("PROBLEMA: " + prob)
        if os.environ.get("AZR_RENDER") == "1":
            etapa = "render"
            os.makedirs(salida, exist_ok=True)
            render(c, cams, salida)
        if os.environ.get("AZR_GUARDAR") == "1":
            etapa = "guardar .blend"
            os.makedirs(salida, exist_ok=True)
            bpy.ops.wm.save_as_mainfile(filepath=os.path.join(salida, "Azrakoth.blend"))
            c.log("Guardado: " + os.path.join(salida, "Azrakoth.blend"))
        c.log(f"Listo en {time.time() - t0:.0f} s" + (f" · {len(problemas)} problema(s) para revisar"
                                                       if problemas else " · sin problemas"))
    except Exception:
        print(f"\n[AZRAKOTH] Falló la etapa «{etapa}». Detalle:\n")
        traceback.print_exc()
        raise


if __name__ == "__main__":
    main()
