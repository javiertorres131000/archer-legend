#!/usr/bin/env python3
"""Pruebas automatizadas fuera de Roblox Studio.

Copia los módulos de src/ a tests/.build, cambia los require de Roblox por rutas de archivo,
les inyecta la imitación de la API de Roblox (tests/mocks.luau) y corre cada tests/test_*.luau
con el intérprete `luau`.

Uso:   python tests/run.py            (necesita `luau` en el PATH, o la variable LUAU=ruta)
Bajar luau: https://github.com/luau-lang/luau/releases  (luau-windows.zip / luau-ubuntu.zip)

Estas pruebas cubren la LÓGICA (estados, rescates, oleadas, IA). No reemplazan probar en
Studio: la física, la red, la interfaz y los ProximityPrompt reales solo se ven ahí.
"""
import glob
import os
import re
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILD = os.path.join(HERE, ".build")
LUAU = os.environ.get("LUAU", "luau")

HEADER = (
    'local __M = require("./mocks")\n'
    "local game, workspace, script, Instance, Vector3, Vector2, CFrame, Color3, UDim2, UDim, Enum, "
    "task, os, typeof, TweenInfo, Random, warn = __M.game, __M.workspace, __M.script, __M.Instance, __M.Vector3, "
    "__M.Vector2, __M.CFrame, __M.Color3, __M.UDim2, __M.UDim, __M.Enum, __M.task, __M.os, "
    "__M.typeof, __M.TweenInfo, __M.Random, __M.warn\n"
)

REQUIRE_PATTERNS = [
    # require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("X"))
    (re.compile(r'require\((?:game:GetService\("ReplicatedStorage"\)|ReplicatedStorage)'
                r':WaitForChild\("Shared"\):WaitForChild\("(\w+)"\)\)'), r'require("./\1")'),
    # require(Shared:WaitForChild("X"))
    (re.compile(r'require\(Shared:WaitForChild\("(\w+)"\)\)'), r'require("./\1")'),
    # require(script.Parent.Data.X) / require(script.Parent.X)
    (re.compile(r'require\(script\.Parent\.Data\.(\w+)\)'), r'require("./\1")'),
    (re.compile(r'require\(script\.Parent\.(\w+)\)'), r'require("./\1")'),
]


def build():
    shutil.rmtree(BUILD, ignore_errors=True)
    os.makedirs(BUILD)
    shutil.copy(os.path.join(HERE, "mocks.luau"), os.path.join(BUILD, "mocks.luau"))
    for path in glob.glob(os.path.join(ROOT, "src", "**", "*.lua"), recursive=True):
        name = os.path.basename(path)
        if name.endswith(".client.lua"):
            continue  # el cliente no se prueba acá
        is_script = name.endswith(".server.lua")
        if is_script:
            name = name.replace(".server.lua", ".lua")
        src = open(path, encoding="utf-8").read()
        for pattern, repl in REQUIRE_PATTERNS:
            src = pattern.sub(repl, src)
        src = src.replace("--!strict\n", "", 1)
        if is_script:
            src += "\nreturn {}\n"  # para poder cargarlo con require desde una prueba
        open(os.path.join(BUILD, name.replace(".lua", ".luau")), "w", encoding="utf-8").write(HEADER + src)
    for path in glob.glob(os.path.join(HERE, "test_*.luau")):
        shutil.copy(path, BUILD)


def main():
    build()
    tests = sorted(glob.glob(os.path.join(BUILD, "test_*.luau")))
    if len(sys.argv) > 1:
        tests = [t for t in tests if any(a in t for a in sys.argv[1:])]
    failed = 0
    for t in tests:
        print(f"\n=== {os.path.basename(t)}")
        r = subprocess.run([LUAU, os.path.basename(t)], cwd=BUILD, capture_output=True, text=True)
        out = (r.stdout + r.stderr).strip()
        print(out)
        if r.returncode != 0:
            failed += 1
    print(f"\n{len(tests) - failed}/{len(tests)} archivos de prueba OK")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
