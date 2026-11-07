# -*- coding: utf-8 -*-
# Общий фреймворк сборки боссов ОХОТЫ: процедурные части + риг + 4 клипа.
# Части жёстко привязаны к костям (vertex group = кость) — без weight paint.
import bpy
import math
from mathutils import Quaternion, Vector

FPS = 30


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return bpy.context.scene


def make_armature(name, bones):
    """bones: [(name, parent|None, head(x,y,z), tail(x,y,z))]."""
    ad = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, ad)
    bpy.context.scene.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    eb = ad.edit_bones
    created = {}
    for name, parent, head, tail in bones:
        b = eb.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = created[parent]
        created[name] = b
    bpy.ops.object.mode_set(mode='OBJECT')
    return obj


def mat_simple(name, color, emission=None, estrength=1.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*color, 1.0)
    b.inputs['Roughness'].default_value = 0.8
    if emission:
        b.inputs['Emission Color'].default_value = (*emission, 1.0)
        b.inputs['Emission Strength'].default_value = estrength
    return m


def add_part(name, kind, size, loc, mat, bone, rot=(0, 0, 0)):
    """Примитив-часть, все вершины в группу кости, арматурный модификатор."""
    if kind == 'box':
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    elif kind == 'cone':
        bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=size[0], radius2=size[1],
                                        depth=size[2], location=loc)
    elif kind == 'sphere':
        bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=size, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size if kind == 'box' else (1, 1, 1)
    obj.rotation_euler = rot
    obj.data.materials.append(mat)
    bpy.ops.object.transform_apply(scale=True)
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
    return obj


def bind_parts(parts, arm):
    for p in parts:
        mod = p.modifiers.new("Arm", 'ARMATURE')
        mod.object = arm
        p.parent = arm


# ---- анимация ----

class Anim:
    def __init__(self, arm, mw=None):
        self.arm = arm
        self.mw = mw or arm.matrix_world
        if arm.animation_data is None:
            arm.animation_data_create()

    AXIS = {'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}

    def wq(self, bone, axis, deg):
        pb = self.arm.pose.bones[bone]
        rest_w = self.mw @ pb.bone.matrix_local
        axis_vec = self.AXIS.get(axis, axis)
        q_world = Quaternion(Vector(axis_vec).normalized(), math.radians(deg))
        rq = rest_w.to_quaternion()
        return rq.inverted() @ q_world @ rq

    def reset(self):
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)
            pb.scale = (1.0, 1.0, 1.0)

    def action(self, name):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        self.arm.animation_data.action = act
        while len(self.arm.animation_data.nla_tracks) > 0:
            self.arm.animation_data.nla_tracks.remove(self.arm.animation_data.nla_tracks[0])
        return act

    def pose(self, f, spec):
        """spec: {bone: [(axis, deg, phase_offset)...] или ('move', (dx,dy,dz))}"""
        sc = bpy.context.scene
        sc.frame_set(f)
        for bone, moves in spec.items():
            q = Quaternion((1, 0, 0, 0))
            move = None
            scale = None
            for mv in moves:
                if mv[0] == 'scale':
                    scale = mv[1]
                    continue
                if mv[0] == 'move':
                    move = mv[1]
                    continue
                axis, deg = mv[0], mv[1] + (mv[2] if len(mv) > 2 else 0.0) * 0.0
                q = self.wq(bone, axis, deg) @ q
            pb = self.arm.pose.bones[bone]
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=f)
            if scale is not None:
                pb.scale = (scale, scale, scale)
                pb.keyframe_insert("scale", frame=f)
            if move:
                rest_w = self.mw @ pb.bone.matrix_local
                m = rest_w.to_quaternion().inverted().to_matrix() @ Vector(move)
                pb.location = m  # АБСОЛЮТНО: накопление ломает монотонные смещения (фикс з.44)
                pb.keyframe_insert("location", frame=f)


def light_and_cam(sc, center, dist, out_w=560, out_h=560):
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'MATERIAL'
    sc.render.resolution_x, sc.render.resolution_y = out_w, out_h
    cam = bpy.data.objects.new("VCam", bpy.data.cameras.new("VCam"))
    sc.collection.objects.link(cam)
    cam.location = Vector(center) + Vector((dist[0], dist[1], dist[2]))
    dir_v = Vector(center) - cam.location
    cam.rotation_euler = dir_v.to_track_quat('-Z', 'Y').to_euler()
    sc.camera = cam
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (0.9, 0.2, 0.6)
    sc.collection.objects.link(sun)
    return cam


def render_clips(out_dir, arm, clips, center, cam_dist, prefix=""):
    sc = bpy.context.scene
    light_and_cam(sc, center, cam_dist)
    for cname, (f0, f1) in clips.items():
        act = bpy.data.actions.get(cname)
        if not act:
            continue
        if arm.animation_data.action_slot is None and len(act.slots):
            arm.animation_data.action_slot = act.slots[0]
        arm.animation_data.action = act
        sc.frame_set(int((f0 + f1) / 2))
        sc.render.filepath = rf"{out_dir}\{prefix}check_{cname}.png"
        bpy.ops.render.render(write_still=True)
        print('  rendered', cname)


def export_glb(path, arm):
    sc = bpy.context.scene
    sc.frame_set(1)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB',
                              export_animation_mode='ACTIONS', export_animations=True,
                              export_apply=False)
    print('  EXPORT OK', path.split('\\')[-1])
