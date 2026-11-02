# -*- coding: utf-8 -*-
# ЗАДАЧА 42: Хранитель Башни — страж-монолит, клипы idle/attack/death.
import bpy, math, os, sys
sys.path.insert(0, r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models')
import importlib
from boss_kit import *
import boss_kit
importlib.reload(boss_kit)
from boss_kit import *

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\keeper_model'
sc = new_scene()

STONE = (0.14, 0.15, 0.18)
STONE2 = (0.1, 0.11, 0.14)
ETH = (0.55, 0.4, 1.0)

BONES = [
    ('root', None, (0, 0, 2.8), (0, 0, 3.6)),
    ('body', 'root', (0, 0, 2.8), (0, 0, 4.6)),
    ('crown', 'body', (0, 0, 4.6), (0, 0, 5.2)),
    ('core', 'body', (0, -0.15, 3.4), (0, -0.2, 3.7)),
    ('deb1', 'root', (-0.9, 0, 4.3), (-1.1, 0, 4.5)),
    ('deb2', 'root', (0.9, 0, 4.3), (1.1, 0, 4.5)),
    ('deb3', 'root', (-0.7, 0, 1.6), (-0.9, 0, 1.4)),
    ('deb4', 'root', (0.7, 0, 1.6), (0.9, 0, 1.4)),
    ('deb5', 'root', (0, -0.4, 4.9), (0, -0.5, 5.2)),
]
arm = make_armature('KeeperArm', BONES)
parts = []
stone = mat_simple('kstone', STONE)
stone2 = mat_simple('kstone2', STONE2)
eth = mat_simple('eth', (0.3, 0.25, 0.5), ETH, 3.2)

P = lambda *a, **kw: parts.append(add_part(*a, **kw))
P('body_low', 'box', (1.5, 1.1, 1.4), (0, 0, 2.7), stone, 'body')
P('body_mid', 'box', (1.25, 0.95, 1.1), (0, 0, 3.9), stone2, 'body')
P('body_top', 'box', (1.0, 0.8, 0.7), (0, 0, 4.75), stone, 'body')
P('face_slit', 'box', (0.12, 0.5, 0.7), (0, -0.66, 4.35), eth, 'body')
P('face_brow', 'box', (0.5, 0.14, 0.12), (0, -0.62, 4.75), eth, 'body')
P('core', 'sphere', 0.26, (0, -0.28, 3.45), eth, 'core')
P('shard_1', 'box', (0.55, 0.35, 0.3), (-1.0, 0, 4.35), stone2, 'deb1', rot=(0.2, 0.15, 0.1))
P('shard_2', 'box', (0.55, 0.35, 0.3), (1.0, 0, 4.35), stone2, 'deb2', rot=(0.15, -0.2, -0.1))
P('shard_3', 'box', (0.4, 0.3, 0.26), (-0.8, 0, 1.5), stone2, 'deb3', rot=(0.1, 0.25, 0))
P('shard_4', 'box', (0.4, 0.3, 0.26), (0.8, 0, 1.5), stone2, 'deb4', rot=(0.1, -0.25, 0))
P('shard_5', 'box', (0.45, 0.3, 0.22), (0, -0.45, 5.05), stone, 'deb5', rot=(0.3, 0, 0.2))
bind_parts(parts, arm)

an = Anim(arm)
clips = {}
# idle: парение, пульс ядра, обломки на орбитах (4 с = ровный круг)
an.reset(); an.action('idle')
for f in range(1, 121, 8):
    t = f / 120 * math.tau
    spec = {
        'root': [('move', (0, 0, 0.16 * math.sin(t))), ('X', math.sin(t) * 1.5)],
        'core': [('X', 8.0 * math.sin(t))],
    }
    for i, deb in enumerate(('deb1', 'deb2', 'deb3', 'deb4', 'deb5')):
        spec[deb] = [('Z', 360.0 * (f / 120.0) + i * 72.0)]
    an.pose(f, spec)
clips['idle'] = (1, 120)
# attack: разлом груди — ядро выпирает, обломки взлетают, рывок вперёд
an.reset(); an.action('attack')
for f, k in ((1, 0.0), (8, -1.0), (18, 1.0), (32, 0.0)):
    an.pose(f, {
        'core': [('move', (0, k * -0.55, 0)), ('X', k * 20.0)],
        'deb1': [('move', (k * -0.5, k * -0.4, k * 0.4))],
        'deb2': [('move', (k * 0.5, k * -0.4, k * 0.4))],
        'deb3': [('move', (k * -0.3, k * -0.3, k * -0.2))],
        'deb4': [('move', (k * 0.3, k * -0.3, k * -0.2))],
        'deb5': [('move', (0, k * -0.6, k * 0.5))],
        'body': [('X', k * -6.0)],
        'root': [('move', (0, k * -0.6, k * 0.1))],
    })
clips['attack'] = (1, 32)
# death: рассыпание — обломки разлетаются, тело валится и оседает
an.reset(); an.action('death')
for f in range(1, 49, 3):
    t = min(1.0, f / 32.0)
    spec = {'root': [('move', (0, 0.3 * t, -1.3 * t)), ('Y', 40.0 * t)],
            'core': [('X', -30.0 * t)]}
    dirs = ((-1.5, -0.3, 0.8), (1.6, -0.2, 1.0), (-1.2, 0.4, 0.3), (1.3, 0.5, 0.5), (0, -1.0, 1.2))
    for i, deb in enumerate(('deb1', 'deb2', 'deb3', 'deb4', 'deb5')):
        dx, dy, dz = dirs[i]
        spec[deb] = [('move', (dx * t, dy * t, dz * t - 1.2 * t * t)), ('Z', 120.0 * t)]
    an.pose(f, spec)
clips['death'] = (1, 48)
export_glb(os.path.join(OUT, 'keeper_anim.glb'), arm)
print('EXPORT DONE')

# верификация-рендеры
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.color_type = 'MATERIAL'
sc.render.resolution_x, sc.render.resolution_y = 520, 620
cam = bpy.data.objects.new("VCam", bpy.data.cameras.new("VCam"))
sc.collection.objects.link(cam)
cam.location = (3.8, -4.8, 3.9)
dir_v = Vector((0, 0, 3.8)) - Vector(cam.location)
cam.rotation_euler = dir_v.to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
sun.data.energy = 3.0
sun.rotation_euler = (0.9, 0.2, 0.6)
sc.collection.objects.link(sun)
for cname in ('idle', 'attack', 'death'):
    act = bpy.data.actions.get(cname)
    arm.animation_data.action = act
    if arm.animation_data.action_slot is None and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    fr = act.frame_range
    sc.frame_set(int((fr[0] + fr[1]) / 2))
    sc.render.filepath = os.path.join(OUT, f'check_{cname}.png')
    bpy.ops.render.render(write_still=True)
    print('rendered', cname)
print('KEEPER DONE')
