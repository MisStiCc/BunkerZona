# Аватарки: крупный план «лица/ядра» каждой модели, RGBA 320px.
import bpy
import os
import math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'models_anim', 'avatar_raw')
os.makedirs(OUT, exist_ok=True)
# (id, z_frac — высота центра кадра в долях роста, dist_k — мнитель дистанции)
MODELS = [
    ('kremen', 0.50, 0.55),
    ('rzhavnik', 0.50, 0.70),
    ('iskropluy', 0.85, 0.55),
    ('kosar', 0.75, 0.50),
]


def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)


for name, zf, dk in MODELS:
    clean()
    src = os.path.join(HERE, 'models_anim', name + '_anim.glb')
    bpy.ops.import_scene.gltf(filepath=src)
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mn = Vector(map(min, mn, w))
                mx = Vector(map(max, mx, w))
    dim = max((mx - mn).length, 0.1)
    xoff = 0.10 * dim if name == 'iskropluy' else 0.0
    ctr = Vector(((mn.x + mx.x) / 2 + xoff, (mn.y + mx.y) / 2, mn.z + (mx.z - mn.z) * zf))
    az = math.radians(25)
    dist = dim * dk
    cam = bpy.data.cameras.new('C')
    cam.lens = 55
    co = bpy.data.objects.new('Cam', cam)
    bpy.context.scene.collection.objects.link(co)
    d = Vector((math.sin(az) * dist, -math.cos(az) * dist, dim * 0.12))
    co.location = ctr + d
    look = (ctr - co.location).normalized()
    co.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = co
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('S', 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(55), 0, math.radians(-35))
    bpy.context.scene.collection.objects.link(sun)
    key = bpy.data.lights.new('K', 'AREA')
    key.energy = 260 * dim * dim
    key.size = dim
    ko = bpy.data.objects.new('Key', key)
    ko.location = ctr + Vector((-dim * 0.7, -dim, dim * 0.5))
    bpy.context.scene.collection.objects.link(ko)
    ko.rotation_euler = (ctr - ko.location).to_track_quat('-Z', 'Y').to_euler()
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    sc.render.resolution_x = 320
    sc.render.resolution_y = 320
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.render.filepath = os.path.join(OUT, name + '.png')
    bpy.ops.render.render(write_still=True)
    print('AVATAR RAW OK', name)
print('AVATARS RAW DONE')
