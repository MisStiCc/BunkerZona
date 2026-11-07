# ЗАДАЧА 45: бонусные клипы pounce (прыжок-бросок) и rage (ярость)
# поверх игровой chimera_rig_anim.glb (оптимизированной, 92k трис).
# Базовые 5 клипов (idle/walk/gallop/attack/death) НЕ трогаем — приходят
# из импорта как есть, уходим в экспорт вместе с новыми двумя.
import bpy, math
from mathutils import Vector, Quaternion

SRC = r"D:\StalkerRevert\StalkerRevert\models\chimera_rig_anim.glb"
OUT = r"D:\StalkerRevert\Tools\chimera_anim\chimera_rig_anim_bonus.glb"

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
arm = next(o for o in sc.objects if o.type == 'ARMATURE')
print('BONES:', len(arm.data.bones))
print('ACTIONS_AFTER_IMPORT:', sorted(a.name for a in bpy.data.actions))
if arm.animation_data and arm.animation_data.nla_tracks:
    print('NLA_TRACKS:', len(arm.animation_data.nla_tracks))

# все импортированные действия защищаем от мусорки — они должны попасть в экспорт
for a in bpy.data.actions:
    a.use_fake_user = True

ARM_MW = arm.matrix_world
FPS = 30


def world_delta_quat(bone_name, axis, deg):
    """Кватернион дельты в ЛОКАЛЬНЫХ осях кости, заданный мировой осью."""
    b = arm.pose.bones[bone_name]
    rest_w = ARM_MW @ b.bone.matrix_local
    rot_rest = rest_w.to_quaternion()
    axis_map = {'X': (1, 0, 0), 'Y': (0, 1, 0), 'Z': (0, 0, 1)}
    axis_vec = Vector(axis_map.get(axis, axis)).normalized()
    q_world = Quaternion(axis_vec, math.radians(deg))
    return rot_rest.inverted() @ q_world @ rot_rest


def swing(bone, axis, keys_deg):
    pb = arm.pose.bones[bone]
    for f, deg in keys_deg:
        sc.frame_set(f)
        pb.rotation_quaternion = world_delta_quat(bone, axis, deg)
        pb.keyframe_insert("rotation_quaternion", frame=f)


def move(bone, keys_vec):
    """Перенос кости (корня) — АБСОЛЮТНАЯ позиция от rest (0,0,0), мировые оси.
    В отличие от animate.py здесь НЕ инкремент: я подаю полную траекторию."""
    pb = arm.pose.bones[bone]
    rest_w = ARM_MW @ pb.bone.matrix_local
    for f, vec in keys_vec:
        sc.frame_set(f)
        delta_w = Vector(vec)
        m = rest_w.to_quaternion().inverted().to_matrix() @ delta_w
        pb.location = m
        pb.keyframe_insert("location", frame=f)


def reset_pose():
    for pb in arm.pose.bones:
        pb.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)


def new_action(name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    while len(arm.animation_data.nla_tracks) > 0:
        tr = arm.animation_data.nla_tracks[0]
        arm.animation_data.nla_tracks.remove(tr)
    return act


LEG_FRONT_L = ['Bone_045', 'Bone_044', 'Bone_043', 'Bone_042', 'Bone_041', 'Bone_040']
LEG_FRONT_R = ['Bone_051', 'Bone_050', 'Bone_049', 'Bone_048', 'Bone_047', 'Bone_046']
LEG_HIND_R = ['Bone_017', 'Bone_016', 'Bone_015', 'Bone_014', 'Bone_013']
LEG_HIND_L = ['Bone_024', 'Bone_023', 'Bone_022', 'Bone_021', 'Bone_020', 'Bone_019']
NECKS = ['Bone_026', 'Bone_025']
HEADS = ['Bone_034', 'Bone_036']
TAIL = ['Bone_009', 'Bone_008', 'Bone_007', 'Bone_006', 'Bone_005', 'Bone_004']
SPINE = ['Bone_002', 'Bone_012', 'Bone_011', 'Bone_010']

# ============ pounce: прыжок-бросок (1.1 с, 33 кадра) ============
# Вперед по миру = -Y (как в attack: бросок давал k*-0.35 по Y при k=-1).
# Фазы: 0-9 приседание, 10-21 полёт по дуге, 22-26 удар-укус на приземлении,
# 27-33 гашение и возврат в rest (модель не уезжает, движок сам двигает).
reset_pose()
new_action('pounce')
PF = 33
# траектория корня: (кадр, fwd_y, z)
root_path = [
    (0, 0.0, 0.0),
    (5, 0.02, -0.12),
    (9, 0.0, -0.20),   # присед
    (13, -0.18, 0.14),  # отрыв
    (18, -0.52, 0.42),  # апекс
    (22, -0.78, 0.12),  # падение
    (25, -0.85, -0.04),  # контакт
    (29, -0.45, -0.02),
    (33, 0.0, 0.0),     # возврат в rest
]
move('Bone_000', [(f, (0, fy, z)) for f, fy, z in root_path])
for f in range(0, PF + 1, 3):
    t = f / PF
    if f <= 9:  # приседание: корпус вниз-вперёд, задние сгибаются
        c = f / 9.0
        for leg in (LEG_HIND_L, LEG_HIND_R):
            swing(leg[0], 'X', [(f, 26.0 * c)])
        for leg in (LEG_FRONT_L, LEG_FRONT_R):
            swing(leg[0], 'X', [(f, -16.0 * c)])
        swing('Bone_002', 'X', [(f, 10.0 * c)])
        swing('Bone_012', 'X', [(f, 7.0 * c)])
        # головы замахиваются вверх-назад
        swing('Bone_025', 'X', [(f, 10.0 * c)])
        swing('Bone_034', 'X', [(f, 9.0 * c)])
        swing('Bone_036', 'X', [(f, 9.0 * c)])
        for i, tb in enumerate(TAIL):
            swing(tb, 'Z', [(f, 6.0 * c * math.sin(i * 0.8))])
    elif f <= 22:  # полёт: тело вытянуто дугой
        u = (f - 9) / 13.0
        arc = math.sin(u * math.pi)
        for leg in (LEG_HIND_L, LEG_HIND_R):
            swing(leg[0], 'X', [(f, 26.0 - 44.0 * u)])   # разгибание-толчок
        for leg in (LEG_FRONT_L, LEG_FRONT_R):
            swing(leg[0], 'X', [(f, -16.0 + 40.0 * u)])  # вытяжка вперёд
        swing('Bone_002', 'X', [(f, 10.0 - 16.0 * u)])
        swing('Bone_010', 'X', [(f, -9.0 * arc)])
        swing('Bone_001', 'Y', [(f, 7.0 * arc)])
        # головы распрямляются и целятся вперёд-вниз
        swing('Bone_025', 'X', [(f, 10.0 - 22.0 * u)])
        swing('Bone_034', 'X', [(f, 9.0 - 19.0 * u)])
        swing('Bone_036', 'X', [(f, 9.0 - 19.0 * u)])
        for i, tb in enumerate(TAIL):
            swing(tb, 'Z', [(f, (1.0 - u) * 6.0 * math.sin(i * 0.8))])
            swing(tb, 'X', [(f, 8.0 * arc)])
    else:  # 25..33: укус-удар и гашение
        u = (f - 22) / 11.0
        bite = math.sin(min(1.0, u * 1.6) * math.pi)
        swing('Bone_025', 'X', [(f, -12.0 + 12.0 * u + bite * 8.0)])
        swing('Bone_034', 'X', [(f, -10.0 + 10.0 * u + bite * 12.0)])
        swing('Bone_036', 'X', [(f, -10.0 + 10.0 * u + bite * 12.0)])
        damp = 1.0 - u
        for leg in (LEG_HIND_L, LEG_HIND_R):
            swing(leg[0], 'X', [(f, -18.0 * damp)])
        for leg in (LEG_FRONT_L, LEG_FRONT_R):
            swing(leg[0], 'X', [(f, 24.0 * damp)])
        swing('Bone_001', 'Y', [(f, 5.0 * damp)])
        for i, tb in enumerate(TAIL):
            swing(tb, 'Z', [(f, math.sin(u * math.tau - i * 0.5) * 9.0 * damp)])

# ============ rage: ярость (1.6 с, 48 кадров) ============
# Стойка ярости: корпус приподнимается, головы расходятся и трясутся в
# противофазе, хвост хлещет, передние лапы царапают воздух. 2 цикла рыка.
reset_pose()
new_action('rage')
RF = 48
for f in range(0, RF + 1, 3):
    t = f / RF
    if f <= 10:  # подъём и раскрыв
        c = f / 10.0
        move('Bone_000', [(f, (0, 0, 0.26 * c))])
        swing('Bone_002', 'X', [(f, -8.0 * c)])
        swing('Bone_012', 'X', [(f, -6.0 * c)])
        swing('Bone_025', 'X', [(f, -14.0 * c)])
        # головы расходятся в стороны
        swing('Bone_034', 'Z', [(f, 16.0 * c)])
        swing('Bone_036', 'Z', [(f, -16.0 * c)])
        swing('Bone_034', 'X', [(f, -6.0 * c)])
        swing('Bone_036', 'X', [(f, -6.0 * c)])
    elif f <= 34:  # 2 цикла тряски/рыка
        u = (f - 10) / 24.0
        wave = math.sin(u * 2.0 * math.tau)
        move('Bone_000', [(f, (0, 0, 0.26 + 0.03 * wave))])
        swing('Bone_025', 'X', [(f, -14.0 + wave * 4.0)])
        swing('Bone_026', 'X', [(f, wave * 3.0)])
        # головы трясутся в противофазе
        swing('Bone_034', 'X', [(f, -6.0 + wave * 13.0)])
        swing('Bone_036', 'X', [(f, -6.0 - wave * 13.0)])
        swing('Bone_034', 'Z', [(f, 16.0 + wave * 6.0)])
        swing('Bone_036', 'Z', [(f, -16.0 + wave * 6.0)])
        # хвост хлещет с большой амплитудой
        for i, tb in enumerate(TAIL):
            swing(tb, 'Z', [(f, math.sin(u * 2.0 * math.tau - i * 0.55) * 18.0)])
        # передние лапы царапают воздух попеременно
        sw = math.sin(u * 2.0 * math.tau)
        swing('Bone_045', 'X', [(f, 20.0 + sw * 14.0)])
        swing('Bone_051', 'X', [(f, 20.0 - sw * 14.0)])
        swing('Bone_002', 'X', [(f, -8.0 + wave * 2.5)])
    else:  # спуск и возврат
        u = (f - 34) / 14.0
        d = 1.0 - u
        move('Bone_000', [(f, (0, 0, 0.26 * d))])
        swing('Bone_002', 'X', [(f, -8.0 * d)])
        swing('Bone_012', 'X', [(f, -6.0 * d)])
        swing('Bone_025', 'X', [(f, (-14.0 + wave * 4.0) * d)])
        swing('Bone_026', 'X', [(f, wave * 3.0 * d)])
        swing('Bone_034', 'X', [(f, (-6.0 + wave * 13.0) * d)])
        swing('Bone_036', 'X', [(f, (-6.0 - wave * 13.0) * d)])
        swing('Bone_034', 'Z', [(f, (16.0 + wave * 6.0) * d)])
        swing('Bone_036', 'Z', [(f, (-16.0 + wave * 6.0) * d)])
        swing('Bone_045', 'X', [(f, (20.0 + sw * 14.0) * d)])
        swing('Bone_051', 'X', [(f, (20.0 - sw * 14.0) * d)])
        for i, tb in enumerate(TAIL):
            swing(tb, 'Z', [(f, math.sin(u * math.tau - i * 0.55) * 18.0 * d)])

# ============ экспорт: все action'ы = 7 клипов ============
sc.frame_set(1)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format='GLB',
    export_animation_mode='ACTIONS',
    export_animations=True,
    export_apply=False)
print('EXPORT OK ->', OUT)

# ============ верификация: рендеры фаз новых клипов ============
sc.render.engine = 'BLENDER_WORKBENCH'
sc.display.shading.color_type = 'MATERIAL'
sc.render.resolution_x, sc.render.resolution_y = 560, 560
cam = bpy.data.objects.new("VCam", bpy.data.cameras.new("VCam"))
sc.collection.objects.link(cam)
cam.location = (2.6, -4.4, 1.3)
dir_v = Vector((0, -0.2, 0.7)) - Vector(cam.location)
cam.rotation_euler = dir_v.to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, -0.3, -0.01))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
sun.data.energy = 3.0
sun.rotation_euler = (0.9, 0.2, 0.6)
sc.collection.objects.link(sun)

SHOTS = {
    'pounce': [5, 9, 18, 25, 33],   # присед, апекс, удар, возврат
    'rage': [10, 22, 34, 48],        # подъём, тряска, спуск, rest
}
for cname, frames in SHOTS.items():
    act = bpy.data.actions.get(cname)
    if not act:
        print('НЕТ ЭКШЕНА', cname)
        continue
    arm.animation_data.action = act
    if arm.animation_data.action_slot is None and len(act.slots):
        arm.animation_data.action_slot = act.slots[0]
    for fr in frames:
        sc.frame_set(fr)
        sc.render.filepath = rf"D:\StalkerRevert\Tools\chimera_anim\check_{cname}_{fr:02d}.png"
        bpy.ops.render.render(write_still=True)
        print('rendered', cname, fr)

# итоговый список действий
print('FINAL_ACTIONS:', sorted(a.name for a in bpy.data.actions if a.use_fake_user))
