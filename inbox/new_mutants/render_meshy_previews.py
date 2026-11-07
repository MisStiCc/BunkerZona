# Рендер-превью собранных моделей Meshy: idle + walk кадры, 3/4 ракурс.
import bpy, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'models_anim', 'preview')
os.makedirs(OUT, exist_ok=True)
MODELS = ['kremen', 'rzhavnik', 'sporonosets', 'chrevo',
          'iskropluy', 'kosar', 'mayak', 'horovod']


def clean():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def render(name, pose):
    clean()
    path = os.path.join(HERE, 'models_anim', f'{name}_anim.glb')
    bpy.ops.import_scene.gltf(filepath=path)
    # bbox
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
    # камера 3/4
    az = math.radians(35)
    dist = dim * 1.35
    cam = bpy.data.cameras.new('C')
    cam.lens = 60
    co = bpy.data.objects.new('Cam', cam)
    bpy.context.scene.collection.objects.link(co)
    d = Vector((math.sin(az) * dist, -math.cos(az) * dist, ctr.z + dim * 0.18))
    co.location = ctr + d
    look = (ctr - co.location).normalized()
    co.rotation_euler = look.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = co
    # свет
    sun = bpy.data.objects.new('Sun', bpy.data.lights.new('S', 'SUN'))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(35))
    bpy.context.scene.collection.objects.link(sun)
    w = bpy.data.worlds.new('W')
    w.use_nodes = True
    w.node_tree.nodes['Background'].inputs[0].default_value = (0.16, 0.17, 0.15, 1)
    w.node_tree.nodes['Background'].inputs[1].default_value = 0.6
    bpy.context.scene.world = w
    # поза: нужный клип в середину
    arm = next((o for o in bpy.context.scene.objects if o.type == 'ARMATURE'), None)
    if arm and arm.animation_data is None:
        arm.animation_data_create()
    act = None
    if arm is not None:
        for a in bpy.data.actions:
            base = a.name.split('|')[-1].lower()
            if pose in base:
                act = a
                break
        if act is not None:
            arm.animation_data.action = act
    sc = bpy.context.scene
    sc.frame_set(int(act.frame_range[1]) if act else 0)
    sc.render.engine = 'CYCLES'
    sc.cycles.samples = 48
    sc.render.resolution_x = 560
    sc.render.resolution_y = 560
    sc.render.filepath = os.path.join(OUT, f'{name}_{pose}.png')
    bpy.ops.render.render(write_still=True)
    print('RENDER OK', name, pose)


for m in MODELS:
    for pose in ('idle', 'walk'):
        try:
            render(m, pose)
        except Exception as e:
            print('RENDER FAIL', m, pose, e)
print('PREVIEWS DONE')
