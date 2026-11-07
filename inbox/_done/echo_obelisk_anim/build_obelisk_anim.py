# -*- coding: utf-8 -*-
# ЗАДАЧА 45: анимации Эхо-обелиска на СУЩЕСТВУЮЩЕЙ геометрии.
# Меш расщепляется по материалам (камень/руны = та же геометрия), риг
# base/mid/top x (камень, руны), клипы idle (парение + пульс рун) и
# death (оседание + трещина-перелом верха).
import bpy
import bmesh
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boss_kit import make_armature, bind_parts, Anim, export_glb

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = r'E:\StalkerRevert\StalkerRevert\models\echo_obelisk.glb'
OUT = os.path.join(HERE, 'echo_obelisk_anim.glb')
CHECK = os.path.join(HERE, 'check')
os.makedirs(CHECK, exist_ok=True)
TAU = math.tau

Z_RANGES = [(0.0, 2.4), (2.4, 4.8), (4.8, 7.5)]


def new_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def split_by_material():
    bpy.ops.import_scene.gltf(filepath=SRC)
    src = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    parts = {}
    for mi, mat in enumerate(src.data.materials):
        bm = bmesh.new()
        bm.from_mesh(src.data)
        bm.faces.ensure_lookup_table()
        keep = [f for f in bm.faces if f.material_index == mi]
        drop = [f for f in bm.faces if f.material_index != mi]
        bmesh.ops.delete(bm, geom=drop, context='FACES')
        me = bpy.data.meshes.new('ob_' + mat.name)
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new('ob_' + mat.name, me)
        obj.data.materials.append(mat)
        bpy.context.scene.collection.objects.link(obj)
        parts[mat.name] = obj
        print('SPLIT', mat.name, len(me.vertices), 'verts')
    bpy.data.objects.remove(src)
    return parts


def build_armature(parts):
    bones = [('root', None, (0, 0, 0.0), (0, 0, 0.3))]
    for pre, zr in (('b', Z_RANGES),):
        for i, (z0, z1) in enumerate(zr):
            bones.append((f'{pre}{i}', 'root', (0, 0, z0 + 0.05), (0, 0, z1)))
    for i, (z0, z1) in enumerate(Z_RANGES):
        bones.append((f'r{i}', 'root', (0, 0, z0 + 0.05), (0, 0, z1)))
    arm = make_armature('obelisk_rig', bones)
    all_parts = []
    for name, obj in parts.items():
        pre = 'b' if name == 'dark_stone' else 'r'
        # привязка вершин по Z-ярусам
        vg_names = []
        for i, (z0, z1) in enumerate(Z_RANGES):
            vg = obj.vertex_groups.new(name=f'{pre}{i}')
            idx = [v.index for v in obj.data.vertices if z0 <= v.co.z < z1]
            if idx:
                vg.add(idx, 1.0, 'REPLACE')
            vg_names.append(f'{pre}{i}')
        # вершины выше последнего яруса (плавающий контур) — в верхний
        top_vg = obj.vertex_groups.get(vg_names[-1])
        tail = [v.index for v in obj.data.vertices
                if v.co.z >= Z_RANGES[-1][1]]
        if tail:
            top_vg.add(tail, 1.0, 'ADD')
        all_parts.append(obj)
    bind_parts(all_parts, arm)
    return arm


def clips(arm):
    an = Anim(arm)

    def mk(name, frames, per_frame):
        an.reset()
        an.action(name)
        for f in range(frames):
            an.pose(f, per_frame(f))
        print('  clip', name, frames)

    # idle 4 c: парение + дрейф + пульс рун (руны «дышат» масштабом)
    def idle(f):
        s = {'root': [('move', (0, 0, 0.045 * math.sin(TAU * f / 60))),
                      ('Y', 2.0 * math.sin(TAU * f / 120))]}
        pulse = 1.0 + 0.02 * math.sin(TAU * f / 60)
        for i in range(3):
            s[f'r{i}'] = [('scale', pulse)]
        # лёгкое колыхание верха
        s['b2'] = [('Y', 0.6 * math.sin(TAU * f / 60 + 0.8))]
        return s
    mk('idle', 120, idle)

    # death 1.6 c: дрожь — оседание — трещина, верх переламывается
    def death(f):
        t = f / 48.0
        s = {}
        if t < 0.25:  # дрожь
            j = math.sin(TAU * f / 6) * 0.8
            s['root'] = [('Z', j), ('X', j * 0.6)]
        else:
            settle = min(1.0, (t - 0.25) / 0.55)
            s['root'] = [('Z', 0.4 * math.sin(TAU * max(0.0, (t - 0.25)) / 6) * (1 - settle)),
                         ('X', 3.5 * settle),
                         ('move', (0, 0, -0.14 * settle))]
            s['b1'] = [('move', (0, 0, -0.08 * settle))]
            # трещина: верх переламывается с рывком
            crack_t = max(0.0, (t - 0.55) / 0.45)
            snap = min(1.0, crack_t * 1.6)
            s['b2'] = [('X', -8.0 * snap), ('move', (0, 0, -0.16 * settle))]
            s['r2'] = [('X', -8.0 * snap), ('move', (0, 0, -0.16 * settle))]
            s['r1'] = [('move', (0, 0, -0.08 * settle))]
        return s
    mk('death', 48, death)
    return {'idle': (0, 120), 'death': (0, 48)}


if __name__ == '__main__':
    new_scene()
    parts = split_by_material()
    arm = build_armature(parts)
    clips(arm)
    export_glb(OUT, arm)
    print('OBELISK DONE')
