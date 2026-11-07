# -*- coding: utf-8 -*-
# Пакетная обработка 8 Meshy-мутантов: нормализация -> decimate -> риг ->
# авто-веса -> клипы idle/walk/attack/death -> GLB. Фреймворк boss_kit.
import bpy
import math
import os
import sys
from mathutils import Quaternion, Vector

SRC = r'E:\StalkerRevert\StalkerRevert\inbox\new_mutants\models'
sys.path.insert(0, r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models')
from boss_kit import (new_scene, make_armature, mat_simple, bind_parts, Anim,
                      export_glb, light_and_cam, render_clips)

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\new_mutants\models_anim'
os.makedirs(OUT, exist_ok=True)
AXIS = {'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}

# (id, fbx_path, target_height, decimate_ratio, rig_class)
MODELS = [
    ('kremen',      os.path.join(SRC, 'kremen-good-texture', 'Meshy_AI_Mossback_Ram_Tortoise_20261103_texture.fbx'), 1.4, 0.18, 'quad'),
    ('rzhavnik',    os.path.join(SRC, 'rzhavnik', 'rzhavnik.fbx'), 1.8, 0.12, 'quad'),
    ('sporonosets', os.path.join(SRC, 'sporonosets', 'sporonosets.fbx'), 2.4, 0.14, 'stalk'),
    ('chrevo',      os.path.join(SRC, 'chrevo', 'chrevo.fbx'), 1.9, 0.06, 'blob'),
    ('iskropluy',   os.path.join(SRC, 'iskropluy', 'iskropluy.fbx'), 2.5, 0.18, 'floater'),
    ('kosar',       os.path.join(SRC, 'kosar', 'kosar.fbx'), 3.1, 0.14, 'strider'),
    ('mayak',       os.path.join(SRC, 'mayak.fbx'), 2.9, 0.06, 'hover'),
    ('horovod',     os.path.join(SRC, 'horovod', 'horovod.fbx'), 2.4, 0.03, 'ring'),
]


def wq(arm, bone, axis, deg):
    pb = arm.pose.bones[bone]
    rest_w = arm.matrix_world @ pb.bone.matrix_local
    q_world = Quaternion(Vector(AXIS[axis]).normalized(), math.radians(deg))
    rq = rest_w.to_quaternion()
    return rq.inverted() @ q_world @ rq


class Rig:
    AXIS = {'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}

    def __init__(self, arm):
        self.arm = arm
        self.mw = arm.matrix_world

    def wq(self, bone, axis, deg):
        pb = self.arm.pose.bones[bone]
        rest_w = self.mw @ pb.bone.matrix_local
        q_world = Quaternion(Vector(self.AXIS[axis]).normalized(), math.radians(deg))
        rq = rest_w.to_quaternion()
        return rq.inverted() @ q_world @ rq

    def reset(self):
        for pb in self.arm.pose.bones:
            pb.rotation_quaternion = (1, 0, 0, 0)
            pb.location = (0, 0, 0)

    def action(self, name):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        if self.arm.animation_data is None:
            self.arm.animation_data_create()
        self.arm.animation_data.action = act
        while len(self.arm.animation_data.nla_tracks) > 0:
            self.arm.animation_data.nla_tracks.remove(self.arm.animation_data.nla_tracks[0])
        return act

    def pose(self, f, spec):
        sc = bpy.context.scene
        sc.frame_set(f)
        for bone, moves in spec.items():
            if bone not in self.arm.pose.bones:
                continue
            q = Quaternion((1, 0, 0, 0))
            move = None
            for mv in moves:
                if mv[0] == 'move':
                    move = mv[1]
                    continue
                axis, deg = mv[0], mv[1]
                q = self.wq(bone, axis, deg) @ q
            pb = self.arm.pose.bones[bone]
            pb.rotation_quaternion = q
            pb.keyframe_insert('rotation_quaternion', frame=f)
            if move:
                rest_w = self.mw @ pb.bone.matrix_local
                m = rest_w.to_quaternion().inverted().to_matrix() @ Vector(move)
                pb.location = pb.location + m
                pb.keyframe_insert('location', frame=f)


def process(name, fbx, target_h, ratio, rig_class):
    sc = new_scene()
    bpy.ops.import_scene.fbx(filepath=fbx)
    meshes = [o for o in sc.objects if o.type == 'MESH']
    # габарит
    mn = [1e9] * 3
    mx = [-1e9] * 3
    for m in meshes:
        for c in m.bound_box:
            wc = m.matrix_world @ __import__('mathutils').Vector(c)
            for i in range(3):
                mn[i] = min(mn[i], wc[i])
                mx[i] = max(mx[i], wc[i])
    h = mx[1] - mn[1]
    k = target_h / h
    cx = (mn[0] + mx[0]) / 2
    cz = (mn[1] + mx[1]) / 2
    # нормализация: высота -> target, лапы на Y=0, центр по XY
    for o in sc.objects:
        o.scale = (o.scale[0] * k, o.scale[1] * k, o.scale[2] * k)
        o.location = Vector((
            (o.location[0] - cx) * k,
            (o.location[1] - cz) * k,
            (o.location[2] - mn[2]) * k))
    bpy.context.view_layer.update()
    # decimate до бюджета (каждому мешу свой модификатор + apply)
    tris = 0
    for m in meshes:
        m.data.calc_loop_triangles()
        tris += len(m.data.loop_triangles)
    for m in meshes:
        bpy.context.view_layer.objects.active = m
        mod = m.modifiers.new('Dec', 'DECIMATE')
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier='Dec')
    tris2 = 0
    for m in meshes:
        m.data.calc_loop_triangles()
        tris2 += len(m.data.loop_triangles)

    # ---- риг по классу (кости в долях от target_h, от земли) ----
    H = target_h
    if rig_class == 'quad':
        BONES = [
            ('root', None, (0, 0, 0.55 * H), (0, 0, 0.75 * H)),
            ('head', 'root', (0.32 * H, 0, 0.72 * H), (0.5 * H, 0, 0.78 * H)),
            ('legFL', 'root', (-0.3 * H, -0.28 * H, 0.45 * H), (-0.38 * H, -0.34 * H, 0.0)),
            ('legFR', 'root', (0.3 * H, -0.28 * H, 0.45 * H), (0.38 * H, -0.34 * H, 0.0)),
            ('legBL', 'root', (-0.3 * H, 0.28 * H, 0.45 * H), (-0.38 * H, 0.34 * H, 0.0)),
            ('legBR', 'root', (0.3 * H, 0.28 * H, 0.45 * H), (0.38 * H, 0.34 * H, 0.0)),
        ]
    elif rig_class == 'stalk':
        BONES = [
            ('root', None, (0, 0, 0.1 * H), (0, 0, 0.3 * H)),
            ('stalk', 'root', (0, 0, 0.3 * H), (0, 0, 0.72 * H)),
            ('cap', 'stalk', (0, 0, 0.72 * H), (0, 0, 0.92 * H)),
            ('tend1', 'stalk', (0.12 * H, -0.06 * H, 0.62 * H), (0.3 * H, -0.2 * H, 0.28 * H)),
            ('tend2', 'stalk', (-0.12 * H, 0.06 * H, 0.62 * H), (-0.3 * H, 0.2 * H, 0.28 * H)),
        ]
    elif rig_class == 'blob':
        BONES = [
            ('root', None, (0, 0, 0.45 * H), (0, 0, 0.62 * H)),
            ('womb', 'root', (0, -0.2 * H, 0.55 * H), (0, -0.35 * H, 0.6 * H)),
            ('tend1', 'root', (-0.25 * H, -0.1 * H, 0.35 * H), (-0.45 * H, -0.18 * H, 0.02 * H)),
            ('tend2', 'root', (0.25 * H, -0.1 * H, 0.35 * H), (0.45 * H, -0.18 * H, 0.02 * H)),
            ('tend3', 'root', (-0.18 * H, 0.22 * H, 0.35 * H), (-0.35 * H, 0.32 * H, 0.02 * H)),
            ('tend4', 'root', (0.18 * H, 0.22 * H, 0.35 * H), (0.35 * H, 0.32 * H, 0.02 * H)),
        ]
    elif rig_class == 'floater':
        BONES = [
            ('root', None, (0, 0, 0.72 * H), (0, 0, 0.85 * H)),
            ('seg2', 'root', (0, -0.18 * H, 0.8 * H), (0.08 * H, -0.4 * H, 0.74 * H)),
            ('seg3', 'seg2', (0.08 * H, -0.4 * H, 0.74 * H), (0.22 * H, -0.55 * H, 0.62 * H)),
            ('seg4', 'seg3', (0.22 * H, -0.55 * H, 0.62 * H), (0.42 * H, -0.58 * H, 0.48 * H)),
            ('seg5', 'seg4', (0.42 * H, -0.58 * H, 0.48 * H), (0.6 * H, -0.5 * H, 0.36 * H)),
            ('hornL', 'root', (-0.06 * H, -0.15 * H, 0.88 * H), (-0.14 * H, -0.25 * H, 1.05 * H)),
            ('hornR', 'root', (0.06 * H, -0.15 * H, 0.88 * H), (0.02 * H, -0.26 * H, 1.07 * H)),
        ]
    elif rig_class == 'strider':
        BONES = [
            ('root', None, (0, 0, 0.5 * H), (0, 0, 0.62 * H)),
            ('chest', 'root', (0, 0, 0.62 * H), (0, 0, 0.82 * H)),
            ('hood', 'chest', (0, 0, 0.82 * H), (0, 0, 0.95 * H)),
            ('armL', 'chest', (-0.18 * H, 0, 0.78 * H), (-0.42 * H, -0.03 * H, 0.58 * H)),
            ('bladeL', 'armL', (-0.42 * H, -0.03 * H, 0.58 * H), (-0.62 * H, -0.06 * H, 0.3 * H)),
            ('armR', 'chest', (0.18 * H, 0, 0.78 * H), (0.42 * H, 0.03 * H, 0.58 * H)),
            ('bladeR', 'armR', (0.42 * H, 0.03 * H, 0.58 * H), (0.62 * H, 0.06 * H, 0.3 * H)),
            ('legL', 'root', (-0.1 * H, 0, 0.48 * H), (-0.13 * H, 0, 0.24 * H)),
            ('legR', 'root', (0.1 * H, 0, 0.48 * H), (0.13 * H, 0, 0.24 * H)),
        ]
    elif rig_class == 'hover':
        BONES = [
            ('root', None, (0, 0, 0.1 * H), (0, 0, 0.2 * H)),
            ('body', 'root', (0, 0, 0.2 * H), (0, 0, 0.82 * H)),
            ('lamp', 'body', (0, 0, 0.82 * H), (0, 0, 0.95 * H)),
        ]
    else:  # ring
        BONES = [
            ('root', None, (0, 0, 0.48 * H), (0, 0, 0.55 * H)),
            ('ring', 'root', (0, 0, 0.48 * H), (0, 0, 0.55 * H)),
            ('fig1', 'ring', (0, -0.38 * H, 0.48 * H), (0, -0.38 * H, 0.78 * H)),
            ('fig2', 'ring', (0.33 * H, 0.19 * H, 0.48 * H), (0.33 * H, 0.19 * H, 0.78 * H)),
            ('fig3', 'ring', (-0.33 * H, 0.19 * H, 0.48 * H), (-0.33 * H, 0.19 * H, 0.78 * H)),
        ]
    ad = bpy.data.armatures.new(name + 'Arm')
    arm = bpy.data.objects.new(name + 'Arm', ad)
    sc.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    eb = ad.edit_bones
    created = {}
    for bn, par, head, tail in BONES:
        b = eb.new(bn)
        b.head = head
        b.tail = tail
        if par:
            b.parent = created[par]
        created[bn] = b
    bpy.ops.object.mode_set(mode='OBJECT')

    # авто-веса: меш <- арматура
    for m in meshes:
        mod = m.modifiers.new('Arm', 'ARMATURE')
        mod.object = arm
        m.parent = arm
    bpy.ops.object.select_all(action='DESELECT')
    for m in meshes:
        m.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type='ARMATURE_AUTO')

    # ---- клипы ----
    an = Rig(arm)
    clips = {}

    def idle_clip(F=96, step=8):
        an.reset(); an.action('idle')
        for f in range(1, F + 1, step):
            t = f / F * math.tau
            spec = {'root': [('move', (0, 0, 0.04 * H * math.sin(t)))]}
            if rig_class in ('quad', 'strider'):
                spec['head' if rig_class == 'quad' else 'hood'] = [('X', math.sin(t) * 3.0)]
            if rig_class == 'quad':
                for lb in ('legFL', 'legFR', 'legBL', 'legBR'):
                    spec[lb] = [('X', math.sin(t) * 2.0)]
            if rig_class == 'stalk':
                spec['cap'] = [('X', math.sin(t) * 3.0), ('Y', math.cos(t) * 3.0)]
                spec['tend1'] = [('X', math.sin(t) * 6.0)]
                spec['tend2'] = [('X', math.sin(t + 1.6) * 6.0)]
            if rig_class == 'blob':
                spec['womb'] = [('X', math.sin(t * 2) * 5.0)]
                for tb in ('tend1', 'tend2', 'tend3', 'tend4'):
                    spec[tb] = [('X', math.sin(t + hash(tb) % 3) * 5.0)]
            if rig_class == 'floater':
                for i, sn in enumerate(('seg2', 'seg3', 'seg4', 'seg5')):
                    spec[sn] = [('X', math.sin(t + i * 0.8) * 7.0)]
                spec['hornL'] = [('Z', math.sin(t) * 8.0)]
                spec['hornR'] = [('Z', math.sin(t + 1) * 8.0)]
            if rig_class == 'strider':
                spec['armL'] = [('X', math.sin(t) * 3.0)]
                spec['armR'] = [('X', math.sin(t + math.pi) * 3.0)]
            if rig_class == 'hover':
                spec['lamp'] = [('Z', 360.0 * (f / F)), ('X', math.sin(t) * 4.0)]
            if rig_class == 'ring':
                spec['ring'] = [('Z', 360.0 * (f / F))]
                for i, fg in enumerate(('fig1', 'fig2', 'fig3')):
                    spec[fg] = [('X', math.sin(t + i * 2.1) * 4.0)]
            an.pose(f, spec)

    def walk_clip(F, step, amp, drift, drift_axis='-Y'):
        an.reset(); an.action('walk')
        n = max(1, int(round(drift * 0 + F)))
        for f in range(1, F + 1, step):
            t = f / F * math.tau
            spec = {'root': [('move', (0, 0, 0.03 * H * abs(math.sin(t * 2))))]}
            if rig_class in ('quad', 'crab'):
                for gi, lb in enumerate(('legFL', 'legFR', 'legBL', 'legBR')):
                    spec[lb] = [('X', math.sin(t + gi * math.pi / 2) * amp)]
            if rig_class == 'stalk':
                spec['stalk'] = [('X', math.sin(t) * 5.0)]
                spec['tend1'] = [('X', math.sin(t) * 9.0)]
                spec['tend2'] = [('X', math.sin(t + math.pi) * 9.0)]
            if rig_class == 'blob':
                for i, tb in enumerate(('tend1', 'tend2', 'tend3', 'tend4')):
                    spec[tb] = [('X', math.sin(t + i * math.pi / 2) * 9.0)]
            if rig_class == 'floater':
                for i, sn in enumerate(('seg2', 'seg3', 'seg4', 'seg5')):
                    spec[sn] = [('X', math.sin(t + i * 0.7) * 10.0)]
            if rig_class == 'strider':
                spec['legL'] = [('X', math.sin(t) * 22.0)]
                spec['legR'] = [('X', math.sin(t + math.pi) * 22.0)]
                spec['armL'] = [('X', math.sin(t + math.pi) * 6.0)]
                spec['armR'] = [('X', math.sin(t) * 6.0)]
                spec['hood'] = [('Y', math.sin(t) * 3.0)]
            if rig_class == 'hover':
                spec['body'] = [('Z', math.sin(t) * 3.0)]
                spec['lamp'] = [('Y', 360.0 * (f / F))]
            if rig_class == 'ring':
                spec['ring'] = [('Z', 360.0 * (f / F))]
                for i, fg in enumerate(('fig1', 'fig2', 'fig3')):
                    spec[fg] = [('X', math.sin(t + i * 2.1) * 6.0)]
            an.pose(f, spec)

    def attack_clip(F, step):
        an.reset(); an.action('attack')
        K = [(1, 0.0), (F // 4, -1.0), (F // 2, 1.0), (F, 0.0)]
        for f, k in K:
            spec = {'root': [('move', (0, k * -0.25 * H / 2.4, k * 0.05))]}
            if rig_class == 'quad':
                spec['head'] = [('move', (k * 0.3 * H / 2.4, 0, 0)), ('X', k * -5.0)]
            if rig_class == 'crab' or rig_class == 'quad':
                pass
            if rig_class == 'stalk':
                spec['cap'] = [('X', k * -10.0)]
                spec['tend1'] = [('X', k * 22.0)]
                spec['tend2'] = [('X', k * 22.0)]
            if rig_class == 'blob':
                spec['womb'] = [('move', (0, k * -0.28, 0)), ('X', k * 12.0)]
                for tb in ('tend1', 'tend2', 'tend3', 'tend4'):
                    spec[tb] = [('X', k * -18.0)]
            if rig_class == 'floater':
                spec['seg1'] = [('X', k * -16.0)]
                spec['hornL'] = [('Z', k * 22.0)]
                spec['hornR'] = [('Z', k * -22.0)]
            if rig_class == 'strider':
                spec['armL'] = [('Z', k * -50.0), ('X', k * -18.0)]
                spec['bladeL'] = [('X', k * -15.0)]
                spec['armR'] = [('Z', k * 40.0), ('X', k * -10.0)]
                spec['hood'] = [('X', k * -8.0)]
            if rig_class == 'hover':
                spec['lamp'] = [('X', k * -12.0), ('Y', k * 25.0)]
            if rig_class == 'ring':
                spec['ring'] = [('Z', k * 45.0)]
                for i, fg in enumerate(('fig1', 'fig2', 'fig3')):
                    spec[fg] = [('X', k * -12.0)]
            an.pose(f, spec)

    def death_clip(F=42, step=3):
        an.reset(); an.action('death')
        for f in range(1, F + 1, step):
            t = min(1.0, f / (F * 0.72))
            spec = {'root': [('move', (0, 0.1 * H * t, -0.35 * H * t)), ('Z', 18.0 * t)]}
            if rig_class in ('quad', 'crab'):
                for lb in ('legFL', 'legFR', 'legBL', 'legBR'):
                    spec[lb] = [('X', 25.0 * t)]
                if rig_class == 'quad':
                    spec['head'] = [('X', -14.0 * t)]
            if rig_class == 'stalk':
                spec['stalk'] = [('X', 22.0 * t)]
                spec['cap'] = [('X', 18.0 * t)]
                for tb in ('tend1', 'tend2'):
                    spec[tb] = [('X', 25.0 * t)]
            if rig_class == 'blob':
                spec['womb'] = [('X', -20.0 * t)]
                for i, tb in enumerate(('tend1', 'tend2', 'tend3', 'tend4')):
                    spec[tb] = [('Z', (30 if i % 2 == 0 else -30) * t)]
            if rig_class == 'floater':
                spec['root'] = [('move', (0, 0, -0.6 * H * t))]
                spec['seg2'] = [('X', 20.0 * t)]
                spec['seg3'] = [('X', -15.0 * t)]
                spec['seg4'] = [('X', 18.0 * t)]
            if rig_class == 'strider':
                spec['legL'] = [('X', 30.0 * t)]
                spec['legR'] = [('X', 22.0 * t)]
                spec['body'] = [('X', 18.0 * t)]
                spec['hood'] = [('X', -18.0 * t)]
                spec['armL'] = [('Z', 30.0 * t)]
                spec['armR'] = [('Z', -25.0 * t)]
            if rig_class == 'hover':
                spec['tower' if 'tower' in an.arm.pose.bones else 'body'] = [('X', 40.0 * t)]
                spec['lamp'] = [('X', -25.0 * t)]
            if rig_class == 'ring':
                spec['root'] = [('move', (0, 0, -0.3 * H * t)), ('Z', 25.0 * t)]
                for i, fg in enumerate(('fig1', 'fig2', 'fig3')):
                    spec[fg] = [('X', 30.0 * t), ('Y', (i - 1) * 25.0 * t)]
            an.pose(f, spec)

    idle_clip()
    walk_clip(36, 3, 22.0, 0.6) if rig_class in ('quad', 'crab', 'strider') else walk_clip(36, 3, 9.0, 0.6)
    attack_clip(28, 3)
    death_clip()
    clips = {n: (1, int(bpy.data.actions[n].frame_range[1])) for n in ('idle', 'walk', 'attack', 'death')}

    out = os.path.join(OUT, f'{name}_anim.glb')
    export_glb(out, arm)
    print(f'BUILT {name}: {tris}->{tris2} трис, клипов {len(clips)}')
    return tris, tris2


if __name__ == '__main__':
    for name, fbx, th, ratio, rc in MODELS:
        try:
            process(name, fbx, th, ratio, rc)
        except Exception as e:
            import traceback
            print(f'ОШИБКА {name}:', e)
            traceback.print_exc()
    print('ALL DONE')
