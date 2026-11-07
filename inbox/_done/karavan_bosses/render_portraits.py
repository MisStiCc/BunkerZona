# -*- coding: utf-8 -*-
# ЗАДАЧА 46а: портреты 3 караванов ~612px (серия boss_portraits з.36):
# драматичный низкий ракурс + тёплое свечение + виньетка.
import bpy
import os
import math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'portrait_raw')
os.makedirs(RAW, exist_ok=True)
JOBS = [
    ('karavan_gruz', (0, 0, 1.9), 6.2, (150, 100, 45)),
    ('karavan_bronekolonna', (0, -0.4, 1.9), 6.6, (140, 70, 40)),
    ('karavan_tsar', (0, 0, 2.1), 7.6, (155, 115, 55)),
]


def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)


for name, ctr, dist, glow in JOBS:
    clean()
    bpy.ops.import_scene.gltf(filepath=os.path.join(HERE, 'models', name + '_anim.glb'))
    arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)
    if arm:
        if arm.animation_data is None:
            arm.animation_data_create()
        for a in bpy.data.actions:
            if a.name == 'idle':
                arm.animation_data.action = a
                if arm.animation_data.action_slot is None and len(a.slots):
                    arm.animation_data.action_slot = a.slots[0]
                break
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mn = Vector(map(min, mn, w))
                mx = Vector(map(max, mx, w))
    dim = max((mx - mn).length, 0.1)
    ctr_v = Vector(ctr)
    az = math.radians(38)
    cam = bpy.data.cameras.new('C')
    cam.lens = 52
    co = bpy.data.objects.new('Cam', cam)
    bpy.context.scene.collection.objects.link(co)
    d = Vector((math.sin(az) * dist, -math.cos(az) * dist, dim * 0.10))
    co.location = ctr_v + d
    look = (ctr_v - co.location).normalized()
    co.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = co
    # тёплый ключ + холодная подсветка сзади
    key = bpy.data.lights.new('K', 'SUN')
    key.energy = 2.6
    key.angle = 0.35
    key.color = (1.0, 0.85, 0.65)
    ko = bpy.data.objects.new('Key', key)
    ko.rotation_euler = (math.radians(55), 0, math.radians(-35))
    bpy.context.scene.collection.objects.link(ko)
    rim = bpy.data.lights.new('R', 'AREA')
    rim.energy = 28 * dim * dim
    rim.size = dim * 2
    rim.color = (0.55, 0.65, 0.7)
    ro = bpy.data.objects.new('Rim', rim)
    ro.location = ctr_v + Vector((dim * 0.6, dim * 1.4, dim * 0.9))
    bpy.context.scene.collection.objects.link(ro)
    ro.rotation_euler = (ctr_v - ro.location).to_track_quat('-Z', 'Y').to_euler()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 64
    sc.render.resolution_x = 860
    sc.render.resolution_y = 860
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.frame_set(10)
    sc.render.filepath = os.path.join(RAW, name + '.png')
    bpy.ops.render.render(write_still=True)
    print('PORTRAIT RAW OK', name)
print('PORTRAITS RAW DONE')
