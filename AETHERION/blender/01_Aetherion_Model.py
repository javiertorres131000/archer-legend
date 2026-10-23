"""Stage 1 sculptural construction. No Blender operators or external packages."""
import math
import random
import bpy
import bmesh
from mathutils import Vector


class Builder:
    def __init__(self, collection, materials, geometry, detail):
        self.collection=collection
        self.m=materials
        self.g=geometry
        self.detail=detail
        self.rng=random.Random(1701)
        self.pivots={}
        self.count=0
        self.prefix=detail+'::'

    def pivot(self,name,pos,parent=None):
        obj=bpy.data.objects.new(self.prefix+name,None)
        obj.empty_display_type='PLAIN_AXES'
        obj.empty_display_size=.45
        self.collection.objects.link(obj)
        obj['aetherion_owned']=True
        obj['role']='pivot'
        obj['joint_id']=name
        if parent:
            obj.parent=self.pivots[parent]
            obj.location=Vector(pos)-obj.parent.matrix_world.translation
        else:
            obj.location=pos
        self.pivots[name]=obj
        bpy.context.view_layer.update()
        return obj

    def mesh(self,name,data,pos,mat,parent,bevel=0):
        verts,faces=data
        self.g.validate(verts,faces)
        mesh=bpy.data.meshes.new(self.prefix+name)
        mesh['aetherion_owned']=True
        mesh.from_pydata(verts,[],faces)
        mesh.update()
        bm=bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(mesh)
        bm.free()
        obj=bpy.data.objects.new(self.prefix+name,mesh)
        self.collection.objects.link(obj)
        obj['aetherion_owned']=True
        obj['role']='visual'
        obj['joint_id']=parent
        obj.parent=self.pivots[parent]
        obj.location=Vector(pos)-obj.parent.matrix_world.translation
        mesh.materials.append(self.m[mat])
        if bevel:
            mod=obj.modifiers.new('Carved edges','BEVEL')
            mod.width=bevel
            mod.segments=2 if self.detail=='CINEMATIC' else 1
        self.count+=1
        return obj

    def stone(self,name,pos,size,parent,mat='StoneDark',rot=0):
        obj=self.mesh(name,self.g.stone(size,self.rng.randrange(999999),
                      5 if self.detail=='CINEMATIC' else 3),pos,mat,parent,.055)
        obj.rotation_euler[1]=rot
        return obj

    def jewel(self,name,pos,size,parent,mat='Core'):
        return self.mesh(name,self.g.crystal(size[0],size[2],size[1]),pos,mat,parent)

    def arc(self,name,pos,radius,width,depth,parent,mat='Gold',start=0,end=math.tau):
        steps=max(4,int((64 if self.detail=='CINEMATIC' else 36)*(end-start)/math.tau))
        return self.mesh(name,self.g.arc(radius,width,depth,start,end,steps),pos,mat,parent,.025)

    def line(self,name,points,parent,mat='Gold',radius=.055):
        """Closed square-section extrusions; used for inlays and textile piping."""
        verts,faces=[],[]
        for i,point in enumerate(points):
            tangent=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(0,i-1)])
            tangent.normalize()
            axis=Vector((0,1,0))
            if abs(tangent.dot(axis))>.95:
                axis=Vector((1,0,0))
            u=tangent.cross(axis).normalized()*radius
            v=tangent.cross(u).normalized()*radius
            for off in (-u-v,u-v,u+v,-u+v):
                verts.append(tuple(Vector(point)+off))
        for i in range(len(points)-1):
            for j in range(4):
                faces.append((i*4+j,i*4+(j+1)%4,(i+1)*4+(j+1)%4,(i+1)*4+j))
        faces.extend([(3,2,1,0),tuple((len(points)-1)*4+j for j in range(4))])
        return self.mesh(name,(verts,faces),(0,0,0),mat,parent)

    def rune(self,name,x,y,z,size,parent):
        # Deliberately engraved-symbol geometry, distinct from structural fractures.
        pts=[(0,1),(.45,.5),(0,0),(-.45,.5),(0,1),(0,-.85),(.4,-.5)]
        self.line(name,[(x+a*size,y,z+b*size) for a,b in pts],parent,'Energy',.045)

    def build(self):
        self.pivot('Root',(0,0,0))
        self.pivot('Pelvis',(0,0,17),'Root')
        self.pivot('LowerTorso',(0,0,20),'Pelvis')
        self.pivot('UpperTorso',(0,0,26),'LowerTorso')
        self.pivot('Head',(0,0,32),'UpperTorso')
        self.pivot('Core',(0,-3.05,26),'UpperTorso')
        self.body()
        self.head()
        for side,label in [(-1,'L'),(1,'R')]:
            self.arm(side,label)
            self.leg(side,label)
        self.halos()
        self.fabric()
        self.debris()
        return self

    def body(self):
        self.stone('PelvicKeystone',(0,0,17.4),(6.2,4.1,3),'Pelvis')
        # Gaps between carved ribs expose recessed energy, not painted-on cracks.
        for row in range(3):
            z=20+row*2.4
            for side in (-1,1):
                self.stone(f'Rib_{row}_{side}',(side*(2.1+row*.35),0,z),
                           (4.0+row*.7,4.7,2.15),'UpperTorso',rot=side*.10)
                self.stone(f'Dorsal_{row}_{side}',(side*2,2.4,z),(3.7,1.1,2),
                           'UpperTorso','StoneLight',side*.08)
            self.jewel(f'InnerEnergy_{row}',(0,0,z),(3.5,2.6,2.4),'UpperTorso','Energy')
        for side in (-1,1):
            parent=f'ChestPlate_{side}'
            self.pivot(parent,(side*3.3,-1.7,26),'UpperTorso')
            self.stone(f'Pectoral_{side}',(side*3.7,-2.25,27.4),(4.8,1.35,3.5),parent,'StoneLight',side*.23)
            self.line(f'ChestTrim_{side}',[(side*1.5,-3,29),(side*4,-3,29.5),
                       (side*6,-2.7,28),(side*5,-2.9,25)],parent,'Gold',.18)
            self.stone(f'Belt_{side}',(side*2,-2.1,17.9),(3.7,.65,.8),'Pelvis','Gold')
            self.jewel(f'BeltGem_{side}',(side*3,-2.55,18),(.35,.25,.6),'Pelvis')
        self.arc('CoreSocket',(0,-2.8,26),2.45,.48,.65,'Core','Cavity')
        self.arc('CoreGoldOuter',(0,-3.2,26),2.55,.27,.42,'Core')
        self.arc('CoreEnergyInner',(0,-3.48,26),1.92,.13,.22,'Core','Energy')
        self.jewel('CoreCrystal',(0,-3.5,26),(2.5,1.9,3.7),'Core')
        self.jewel('CoreHeart',(0,-4.4,26),(.7,.35,1.4),'Core')
        for i in range(8):
            a=i*math.tau/8
            self.jewel(f'CoreClasp_{i}',(math.cos(a)*2.5,-3.6,26+math.sin(a)*2.5),
                       (.45,.4,.65),'Core','Gold')
        self.line('BackSpine',[(0,2.9,18),(0,3,23),(0,2.9,29)],'UpperTorso','Gold',.2)
        self.rune('BackSeal',0,3.15,25,1.7,'UpperTorso')

    def head(self):
        self.stone('Neck',(0,0,30.5),(2.5,2.5,1.6),'Head','Gold')
        self.stone('Helmet',(0,.3,33.3),(3.9,3.1,4.7),'Head')
        self.stone('FaceRecess',(0,-1.30,33.1),(2.9,.5,3.5),'Head','Cavity')
        for side in (-1,1):
            self.stone(f'Cheek_{side}',(side*1.42,-1.65,32.9),(.65,.65,3.5),'Head','Gold',side*-.12)
            self.line(f'Brow_{side}',[(side*.12,-1.72,34.15),(side*.7,-1.86,34.55),
                       (side*1.7,-1.55,34.7)],'Head','Gold',.19)
            self.jewel(f'Eye_{side}',(side*.65,-1.64,33.65),(.72,.25,.28),'Head')
            self.jewel(f'CrownSide_{side}',(side*1.45,-.1,35.55),(.7,.9,3.1),'Head','Gold')
            self.rune(f'CheekRune_{side}',side*1.42,-2.01,32.5,.35,'Head')
        self.line('NoseKeel',[(0,-1.9,34.2),(0,-2.2,33.3),(0,-1.85,31.6)],'Head','Gold',.13)
        self.jewel('ForeheadSetting',(0,-1.45,35.15),(1.3,.75,2.3),'Head','Gold')
        self.jewel('ForeheadGem',(0,-1.95,35.15),(.75,.5,1.55),'Head')
        self.jewel('CrownApex',(0,.15,36.5),(.6,.75,3),'Head','Gold')

    def arm(self,s,label):
        shoulder='Shoulder_'+label
        upper='UpperArm_'+label
        fore='Forearm_'+label
        fist='Fist_'+label
        self.pivot(shoulder,(s*7,0,28),'UpperTorso')
        self.pivot(upper,(s*8.2,0,26),shoulder)
        self.pivot(fore,(s*10,0,21),upper)
        self.pivot(fist,(s*11.8,-.4,15.5),fore)
        for i in range(5):
            a=.15+math.pi*.90*i/4
            self.stone(f'ArchStone_{label}_{i}',(s*(7+math.cos(a)*3),0,28+math.sin(a)*2),
                       (2.3,5.1,2.1),shoulder,'StoneLight',a-math.pi/2)
        self.arc('ShoulderCornice_'+label,(s*7,-2.65,28),3.2,.33,.35,shoulder,
                 start=.1,end=math.pi-.1)
        for row in range(3):
            self.stone(f'ArmSegment_{label}_{row}',(s*(8.1+row*.6),0,25.8-row*1.65),
                       (3.7,3.8,1.4),upper,rot=s*.15)
        self.jewel('ElbowEnergy_'+label,(s*10,0,21),(2.7,2.8,2.1),fore,'Energy')
        for row in range(3):
            self.stone(f'ForearmBlock_{label}_{row}',(s*(10.3+row*.45),-.2,20-row*1.4),
                       (4.5,4.4,1.2),fore,'StoneDark',s*.13)
        for z in (17.1,20.4):
            self.stone(f'BracerGold_{label}_{z}',(s*10.7,-2.5,z),(4.35,.35,.45),fore,'Gold')
        self.rune('BracerRune_'+label,s*10.8,-2.53,18.8,1.1,fore)
        self.stone('Palm_'+label,(s*11.8,-.4,14.7),(5,4.4,3.8),fist)
        for finger in range(4):
            x=s*(9.65+finger*1.43)
            joint=f'Finger_{label}_{finger}'
            self.pivot(joint,(x,-1.5,15.2),fist)
            self.stone('Knuckle_'+joint,(x,-2.2,14.7),(1.28,2.4,1.8),joint,'StoneLight')
            self.stone('Tip_'+joint,(x,-2.25,13.25),(1.22,2,1.05),joint)
        thumb='Thumb_'+label
        self.pivot(thumb,(s*8.9,-.6,15),fist)
        self.stone('ThumbStone_'+label,(s*8.9,-1.25,14.3),(1.5,2,2.4),thumb,rot=s*.4)
        self.jewel('WristEnergy_'+label,(s*11.5,-.3,16.7),(2.8,2.8,1.1),fist,'Energy')

    def leg(self,s,label):
        thigh='Thigh_'+label
        shin='Shin_'+label
        foot='Foot_'+label
        self.pivot(thigh,(s*3.3,0,17),'Pelvis')
        self.pivot(shin,(s*3.7,0,9),thigh)
        self.pivot(foot,(s*4,0,2.1),shin)
        for i in range(3):
            self.stone(f'ThighStone_{label}_{i}',(s*(3.3+.1*i),0,15.4-i*2),
                       (4.2,4,1.75),thigh,rot=s*.06)
        self.jewel('KneeGap_'+label,(s*3.7,0,9),(2.7,2.7,1.4),shin,'Energy')
        self.stone('KneeGuard_'+label,(s*3.7,-2,9.5),(3.4,1.2,2.3),shin,'Gold')
        self.jewel('KneeGem_'+label,(s*3.7,-2.7,9.5),(.8,.6,1.3),shin)
        for i in range(3):
            self.stone(f'ShinStone_{label}_{i}',(s*4,0,7.6-i*1.85),(4.5,4.1,1.6),shin)
        self.stone('ShinTablet_'+label,(s*4,-2.05,5.7),(2.65,.45,4.8),shin,'StoneLight')
        self.rune('ShinRune_'+label,s*4,-2.34,5.6,1.7,shin)
        for z in (3.1,8):
            self.stone(f'GreaveTrim_{label}_{z}',(s*4,-2.25,z),(4.5,.45,.45),shin,'Gold')
        # Bottom exactly z=0; no external floor included in character dimensions.
        self.stone('Heel_'+label,(s*4,.3,1.05),(4.7,4.1,2.1),foot)
        for i in range(3):
            self.stone(f'Toe_{label}_{i}',(s*4+(i-1)*1.55,-2.6,.9),(1.43,2.6,1.8),foot,'StoneLight')

    def halos(self):
        for index,(radius,y) in enumerate(((9,3.7),(6.9,4.2),(4.9,4.7))):
            parent=f'Halo_{index}'
            self.pivot(parent,(0,y,28.3),'UpperTorso')
            self.arc(parent+'_Band',(0,y,28.3),radius,.32,.42,parent)
            self.arc(parent+'_Inlay',(0,y-.25,28.3),radius-.35,.055,.08,parent,'Energy')
            for j in range(12):
                a=j*math.tau/12
                x,z=radius*math.cos(a),28.3+radius*math.sin(a)
                self.jewel(f'HaloSeal_{index}_{j}',(x,y-.3,z),(.5,.4,.9),parent,'Gold')
                if j%3==0:
                    self.jewel(f'HaloGem_{index}_{j}',(x,y-.6,z),(.3,.35,.5),parent)
                if index==0 and j%3==0:
                    self.line(f'HaloSpoke_{j}',[(x*.77,y,28.3+(z-28.3)*.77),(x,y,z)],parent,'Gold',.09)

    def fabric(self):
        for side,label,width,length in [(-1,'L',2.8,11),(1,'R',2.8,10.5),(0,'Center',2.4,12)]:
            name='Cloth_'+label
            pos=Vector((side*2.2,-2.7,17.4))
            self.pivot(name,pos,'Pelvis')
            cols,rows=(12,24) if self.detail=='CINEMATIC' else (6,12)
            obj=self.mesh(name,self.g.cloth(width,length,side,cols,rows),pos,'Cloth',name)
            mod=obj.modifiers.new('Woven thickness','SOLIDIFY')
            mod.thickness=.055
            for edge in (-.5,.5):
                points=[tuple(pos+Vector(self.g.cloth_point(edge,t/rows,width,length,side))) for t in range(rows+1)]
                self.line(f'{name}_Hem_{edge}',points,name,'Gold',.055)
            # Deformation weights ready for later cloth bones (no rig claimed here).
            for section in range(3):
                group=obj.vertex_groups.new(name=f'{name}_{section}')
                for i,v in enumerate(obj.data.vertices):
                    t=max(0,min(1,-v.co.z/length))
                    weight=max(0,1-abs(t*2-section))
                    if weight>0:
                        group.add([i],weight,'REPLACE')

    def debris(self):
        count=18 if self.detail=='CINEMATIC' else 8
        for i in range(count):
            a=i*2.39996
            z=5+(i*3.7)%24
            r=8+(i%3)*1.7
            pos=(math.cos(a)*r,math.sin(a)*5,z)
            name=f'Fragment_{i:02}'
            self.pivot(name,pos,'Root')
            size=.5+(i%4)*.3
            obj=self.stone(name,pos,(size,size*.8,size*1.4),name)
            obj['role']='decorative_fragment'
            obj.rotation_euler=(a*.3,a*.7,a)


def build(collection,materials,geometry,detail):
    return Builder(collection,materials,geometry,detail).build()
