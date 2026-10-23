"""Initial Blender materials. Procedural nodes require baking before Roblox."""
import bpy

PREFIX = 'AET::'


def material(name, color, metallic=0, roughness=.65, emission=0):
    mat = bpy.data.materials.new(PREFIX+name)
    mat['aetherion_owned'] = True
    mat.diffuse_color = (*color,1)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    output = nodes.new('ShaderNodeOutputMaterial')
    bsdf = nodes.new('ShaderNodeBsdfPrincipled')
    bsdf.inputs['Base Color'].default_value = (*color,1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        socket = bsdf.inputs.get('Emission Color') or bsdf.inputs.get('Emission')
        if socket is None:
            raise RuntimeError('Principled BSDF: missing emission socket')
        socket.default_value = (*color,1)
        bsdf.inputs['Emission Strength'].default_value = emission
    links.new(bsdf.outputs['BSDF'],output.inputs['Surface'])
    return mat, bsdf


def build():
    result = {}
    for name, color in [('StoneDark',(.075,.09,.12)), ('StoneLight',(.29,.32,.36))]:
        mat, bsdf = material(name,color)
        n,l = mat.node_tree.nodes,mat.node_tree.links
        tex = n.new('ShaderNodeTexNoise')
        tex.inputs['Scale'].default_value = 5
        tex.inputs['Detail'].default_value = 4
        ramp = n.new('ShaderNodeValToRGB')
        ramp.color_ramp.elements[0].color = (*(c*.4 for c in color),1)
        ramp.color_ramp.elements[1].color = (*(c*1.6 for c in color),1)
        l.new(tex.outputs['Fac'],ramp.inputs['Fac'])
        l.new(ramp.outputs['Color'],bsdf.inputs['Base Color'])
        fine = n.new('ShaderNodeTexNoise')
        fine.inputs['Scale'].default_value = 75
        bump=n.new('ShaderNodeBump')
        bump.inputs['Strength'].default_value=.38
        bump.inputs['Distance'].default_value=.065
        l.new(fine.outputs['Fac'],bump.inputs['Height'])
        l.new(bump.outputs['Normal'],bsdf.inputs['Normal'])
        result[name]=mat
    result['Gold'], gold = material('Gold',(.64,.35,.085),.78,.32)
    n,l=result['Gold'].node_tree.nodes,result['Gold'].node_tree.links
    noise=n.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value=36
    ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(.18,.18,.18,1)
    ramp.color_ramp.elements[1].color=(.55,.55,.55,1)
    l.new(noise.outputs['Fac'],ramp.inputs['Fac'])
    l.new(ramp.outputs['Color'],gold.inputs['Roughness'])
    result['Energy'],_=material('Energy',(.005,.38,1),.15,.25,4)
    result['Core'],_=material('Core',(.025,.8,1),.35,.18,6)
    result['Cavity'],_=material('Cavity',(.008,.012,.02),.05,.85)
    result['Cloth'],cloth=material('Cloth',(.72,.69,.58),0,.9)
    n,l=result['Cloth'].node_tree.nodes,result['Cloth'].node_tree.links
    noise=n.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value=115
    bump=n.new('ShaderNodeBump')
    bump.inputs['Strength'].default_value=.15
    bump.inputs['Distance'].default_value=.018
    l.new(noise.outputs['Fac'],bump.inputs['Height'])
    l.new(bump.outputs['Normal'],cloth.inputs['Normal'])
    return result
