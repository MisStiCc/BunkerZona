# Карточки из моделей Meshy: прозрачный рендер + градиент роли + рамка редкости.
import bpy, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'models_anim', 'card_raw')
os.makedirs(OUT, exist_ok=True)
MODELS = ['kremen', 'rzhavnik', 'sporonosets', 'chrevo',
          'iskropluy', 'kosar', 'mayak', 'horovod']


def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def render(name):
    clean()
    path = os.path.join(HERE, 'models_anim', f'{name}_anim.glb')
    bpy.ops.import_scene.gltf(filepath=path)
    mn = Vector((1e9,) * 3)
    mx = Vector((-1e9,) * 3)
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mn = Vector(map(min, mn, w))
                mx = Vector(map(max, mx, w))
    ctr = (mn + mx) / 2
    dim = max((mx - mn).length, 0.1)
    az = math.radians(30)
    dist = dim * 1.05
    cam = bpy.data.cameras.new('C')
    cam.lens = 55
    co = bpy.data.objects.new('Cam', cam)
    bpy.context.scene.collection.objects.link(co)
    d = Vector((math.sin(az) * dist, -math.cos(az) * dist, ctr.z + dim * 0.05))
    co.location = ctr + d
    look = (ctr - co.location).normalized()
    co.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = co
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('S', 'SUN'))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
    bpy.context.scene.collection.objects.link(sun)
    key = bpy.data.lights.new('K', 'AREA')
    key.energy = 400 * dim * dim
    key.size = dim * 2
    ko = bpy.data.objects.new('Key', key)
    ko.location = ctr + Vector((-dim, -dim * 1.5, dim * 0.8))
    bpy.context.scene.collection.objects.link(ko)
    ko.rotation_euler = (Vector((ctr - ko.location)).to_track_quat('-Z', 'Y').to_euler())
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 64
    sc.render.resolution_x = 840
    sc.render.resolution_y = 840
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    # поза idle
    arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)
    if arm:
        if arm.animation_data is None:
            arm.animation_data_create()
        for a in bpy.data.actions:
            if 'idle' in a.name.split('|')[-1].lower():
                arm.animation_data.action = a
                break
    sc.frame_set(0)
    sc.render.filepath = os.path.join(OUT, f'{name}.png')
    bpy.ops.render.render(write_still=True)
    print('CARD RAW OK', name)


for m in MODELS:
    try:
        render(m)
    except Exception as e:
        print('CARD RAW FAIL', m, e)
print('CARD RAW DONE')
