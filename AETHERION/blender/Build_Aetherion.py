"""Open this saved file in Blender's Text Editor and press Alt+P.

Stage 1 only: complete static model, initial materials, articulation pivots.
No automatic export, saving, rigging, or combat animation.
"""
from pathlib import Path
import importlib.util
import json
import traceback
import bpy
from mathutils import Vector

ACTIVE_VARIANT = 'GAMEPLAY'  # GAMEPLAY or CINEMATIC
BUILD_BOTH = True
PRESENTATION = True
OWNER = 'aetherion_owned'


def directory():
    file = globals().get('__file__')
    if file and Path(file).is_file():
        return Path(file).resolve().parent
    text = getattr(bpy.context.space_data,'text',None)
    if text and text.filepath:
        return Path(bpy.path.abspath(text.filepath)).resolve().parent
    raise RuntimeError('Abrí Build_Aetherion.py desde disco en Scripting; no pegues solamente su contenido.')


def load(path,name):
    spec=importlib.util.spec_from_file_location('aetherion_'+name,path/name)
    if spec is None or spec.loader is None:
        raise RuntimeError('No se puede cargar '+name)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def collection(name,parent=None):
    col=bpy.data.collections.new(name)
    col[OWNER]=True
    (parent.children if parent else bpy.context.scene.collection.children).link(col)
    return col


def remove_project(root):
    """Remove owned content only. Preserve user additions by linking them to scene."""
    def visit(col):
        for child in list(col.children):
            if child.get(OWNER):
                visit(child)
            elif child.name not in bpy.context.scene.collection.children:
                bpy.context.scene.collection.children.link(child)
        for obj in list(col.objects):
            if obj.get(OWNER):
                for dependent in list(obj.children):
                    if not dependent.get(OWNER):
                        world=dependent.matrix_world.copy()
                        dependent.parent=None
                        dependent.matrix_world=world
                bpy.data.objects.remove(obj,do_unlink=True)
            elif obj.name not in bpy.context.scene.collection.objects:
                bpy.context.scene.collection.objects.link(obj)
        bpy.data.collections.remove(col)
    visit(root)
    for datablocks in (bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights):
        for data in list(datablocks):
            if data.get(OWNER) and data.users==0:
                datablocks.remove(data)


def presentation(root):
    col=collection('AETHERION_PRESENTATION',root)
    def obj(name,data,pos):
        data[OWNER]=True
        ob=bpy.data.objects.new(name,data)
        ob[OWNER]=True
        col.objects.link(ob)
        ob.location=pos
        return ob
    camera=obj('Aetherion_Camera',bpy.data.cameras.new('Aetherion_Camera'),(47,-76,35))
    camera.rotation_euler=(Vector((0,0,19))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.lens=48
    for name,pos,power,color,size in [
        ('Key',(13,-24,43),18000,(1,.83,.63),18),
        ('Fill',(-22,-12,24),11000,(.2,.55,1),16),
        ('Rim',(8,15,33),23000,(.15,.6,1),14)]:
        data=bpy.data.lights.new('Aetherion_'+name,'AREA')
        data.energy=power
        data.color=color
        data.shape='DISK'
        data.size=size
        light=obj('Aetherion_'+name,data,pos)
        light.rotation_euler=(Vector((0,0,20))-light.location).to_track_quat('-Z','Y').to_euler()
    return camera


def inspect(builder):
    """Base geometry report; evaluated triangles include bevel and cloth thickness."""
    bpy.context.view_layer.update()
    deps=bpy.context.evaluated_depsgraph_get()
    corners=[]
    tris=0
    meshes=[o for o in builder.collection.objects if o.type=='MESH']
    for obj in meshes:
        if not obj.data.materials or obj.parent is None:
            raise RuntimeError('Objeto incompleto: '+obj.name)
        if any(not all(__import__('math').isfinite(c) for c in v.co) for v in obj.data.vertices):
            raise RuntimeError('Coordenadas inválidas: '+obj.name)
        evaluated=obj.evaluated_get(deps)
        mesh=evaluated.to_mesh()
        try:
            mesh.calc_loop_triangles()
            tris+=len(mesh.loop_triangles)
        finally:
            evaluated.to_mesh_clear()
        corners.extend(obj.matrix_world@Vector(v) for v in obj.bound_box)
    low=[min(v[i] for v in corners) for i in range(3)]
    high=[max(v[i] for v in corners) for i in range(3)]
    height=high[2]-low[2]
    if not 37<=height<=39:
        raise RuntimeError(f'Altura inesperada: {height:.3f}; objetivo 38 unidades')
    required=['Root','Pelvis','Head','Core','Fist_L','Fist_R','Halo_0','Foot_L','Foot_R']
    assert all(name in builder.pivots for name in required)
    report={'variant':builder.detail,'mesh_objects':len(meshes),'pivots':len(builder.pivots),
            'evaluated_triangles':tris,'dimensions_xyz':[round(high[i]-low[i],3) for i in range(3)],
            'height_target':38,'stage':1,'rigged':False,'animations':False}
    builder.collection['report']=json.dumps(report)
    if builder.detail=='GAMEPLAY' and (tris>65000 or len(meshes)>350):
        print('[AETHERION] Aviso: presupuesto provisional excedido; ver PERFORMANCE.md')
    print('[AETHERION] '+json.dumps(report,ensure_ascii=False))
    return report


def main():
    if ACTIVE_VARIANT not in ('GAMEPLAY','CINEMATIC'):
        raise ValueError('ACTIVE_VARIANT debe ser GAMEPLAY o CINEMATIC')
    if bpy.context.mode!='OBJECT':
        raise RuntimeError('Cambiá a Object Mode antes de ejecutar el generador.')
    base=directory()
    for filename in ('geometry.py','01_Aetherion_Model.py','02_Aetherion_Materials.py'):
        if not (base/filename).is_file():
            raise FileNotFoundError('Falta el módulo '+str(base/filename))
    old=bpy.data.collections.get('AETHERION_BOSS')
    if old and not old.get(OWNER):
        raise RuntimeError('Ya existe una colección ajena AETHERION_BOSS. Renombrala antes de continuar.')
    geometry=load(base,'geometry.py')
    model=load(base,'01_Aetherion_Model.py')
    materials=load(base,'02_Aetherion_Materials.py')
    staging=collection('AETHERION_BUILDING')
    try:
        print('[AETHERION] Etapa 1; Blender '+bpy.app.version_string)
        mats=materials.build()
        variants=('GAMEPLAY','CINEMATIC') if BUILD_BOTH else (ACTIVE_VARIANT,)
        created=[]
        for variant in variants:
            print('[AETHERION] Construyendo '+variant)
            col=collection('AETHERION_'+variant+'_BUILDING',staging)
            builder=model.build(col,mats,geometry,variant)
            inspect(builder)
            created.append((variant,col))
        camera=presentation(staging) if PRESENTATION else None
    except Exception:
        remove_project(staging)
        raise
    # Commit only after every model passes construction and runtime validation.
    if old:
        remove_project(old)
    staging.name='AETHERION_BOSS'
    staging['stage']=1
    staging['units']='1 Blender unit = 1 Roblox stud; verify importer dimensions'
    for variant,col in created:
        col.name='AETHERION_'+variant
        col.hide_viewport=variant!=ACTIVE_VARIANT
        col.hide_render=variant!=ACTIVE_VARIANT
    if camera:
        bpy.context.scene.camera=camera
    print('[AETHERION] Listo: modelo estático, materiales iniciales y pivotes. Sin rig ni animaciones todavía.')
    print('[AETHERION] Guardá el .blend manualmente. Material Preview o Rendered para ver los materiales.')


if __name__=='__main__':
    try:
        main()
    except Exception:
        print('[AETHERION] Falló la construcción. La versión anterior se conserva si existía.')
        traceback.print_exc()
        raise
