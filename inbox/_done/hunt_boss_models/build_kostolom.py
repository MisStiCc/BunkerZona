# -*- coding: utf-8 -*-
# Босс 1/6: КОСТОЛОМ — костяной колосс-сборщик 5.5 м, хребты-шипы.
import bpy, math, os, sys
sys.path.insert(0, r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models')
from boss_kit import *
import importlib
import boss_kit
importlib.reload(boss_kit)
from boss_kit import *

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models'
sc = new_scene()

BONE = (0.86, 0.84, 0.78)
BONE_DK = (0.62, 0.60, 0.54)
MARROW = (0.5, 0.42, 0.3)
EMI = (1.0, 0.85, 0.55)

m_bone = mat_simple('bone', BONE)
m_dk = mat_simple('bone_dark', BONE_DK)
m_marrow = mat_simple('marrow', MARROW, EMI, 1.6)

BONES = [
    ('root', None, (0, 0, 2.6), (0, 0, 3.4)),
    ('spine1', 'root', (0, 0, 3.0), (0, 0, 4.0)),
    ('spine2', 'spine1', (0, 0, 4.0), (0, 0, 4.8)),
    ('chest', 'spine2', (0, 0, 4.8), (0, 0, 5.5)),
    ('head', 'chest', (0, 0, 5.5), (0, 0, 6.2)),
    ('jaw', 'head', (0, 0, 5.7), (0.7, 0, 5.45)),
    # руки
    ('armL', 'chest', (-1.1, 0, 5.2), (-1.9, 0, 4.4)),
    ('foreL', 'armL', (-1.9, 0, 4.4), (-2.5, 0, 3.4)),
    ('clawL', 'foreL', (-2.5, 0, 3.4), (-2.9, 0, 2.6)),
    ('armR', 'chest', (1.1, 0, 5.2), (1.9, 0, 4.4)),
    ('foreR', 'armR', (1.9, 0, 4.4), (2.5, 0, 3.4)),
    ('clawR', 'foreR', (2.5, 0, 3.4), (2.9, 0, 2.6)),
    # ноги
    ('legFL', 'root', (-0.75, 0, 2.5), (-0.95, 0, 1.2)),
    ('shinFL', 'legFL', (-0.95, 0, 1.2), (-1.0, 0, 0.15)),
    ('legFR', 'root', (0.75, 0, 2.5), (0.95, 0, 1.2)),
    ('shinFR', 'legFR', (0.95, 0, 1.2), (1.0, 0, 0.15)),
    ('legBL', 'root', (-0.7, 0, 2.5), (-1.15, 0.55, 1.25)),
    ('shinBL', 'legBL', (-1.15, 0.55, 1.25), (-1.25, 0.75, 0.15)),
    ('legBR', 'root', (0.7, 0, 2.5), (1.15, 0.55, 1.25)),
    ('shinBR', 'legBR', (1.15, 0.55, 1.25), (1.25, 0.75, 0.15)),
]
arm = make_armature('KostolomArm', BONES)

parts = []
P = lambda *a, **kw: parts.append(add_part(*a, **kw))

# торс из позвонков + рёбра
for i, z in enumerate((2.7, 3.3, 3.9, 4.5)):
    P(f'spine_{i}', 'box', (1.5 - i * 0.08, 1.1, 0.55), (0, 0, z), m_bone, 'spine1')
    for sx in (-1, 1):  # рёбра
        P(f'rib_{i}_{sx}', 'box', (0.5, 0.16, 0.4), (sx * (0.9 - i * 0.05), 0, z + 0.18),
          m_bone, 'spine1')
# таз
P('pelvis', 'box', (1.7, 1.2, 0.8), (0, 0, 2.55), m_dk, 'root')
# голова: череп + челюсть + рога
P('skull', 'box', (0.75, 0.9, 0.85), (0, 0, 5.75), m_bone, 'head')
P('jaw', 'box', (0.6, 0.7, 0.28), (0.3, 0, 5.45), m_dk, 'jaw')
for sx in (-1, 1):
    P(f'horn_{sx}', 'cone', (0.14, 0.03, 0.9), (sx * 0.34, 0, 6.35), m_dk, 'head',
      rot=(0.5 * sx, 0, 0.25 * sx))
# глаза-впадины светятся
P('eyeL', 'sphere', 0.09, (-0.22, -0.44, 5.8), m_marrow, 'head')
P('eyeR', 'sphere', 0.09, (0.22, -0.44, 5.8), m_marrow, 'head')
# шипы-хребет по спине
for i in range(6):
    z = 2.5 + i * 0.62
    s = 0.5 - i * 0.04
    P(f'spike_{i}', 'cone', (s * 0.3, 0.03, s), (0, 0.55, z + 0.2), m_dk, 'spine1',
      rot=(math.radians(105), 0, 0))
# руки: плечи-шипы + сегменты + когти
for sx, up, fore, claw in ((-1, 'armL', 'foreL', 'clawL'), (1, 'armR', 'foreR', 'clawR')):
    P(f'shoulder_{sx}', 'sphere', 0.42, (sx * 1.12, 0, 5.1), m_dk, up)
    P(f'upper_{sx}', 'box', (0.55, 0.55, 1.5), (sx * 1.5, 0, 4.75), m_bone, up)
    P(f'fore_{sx}', 'box', (0.45, 0.45, 1.6), (sx * 2.2, 0, 3.85), m_bone, fore)
    for k in range(3):  # когти-пальцы
        P(f'claw_{sx}_{k}', 'cone', (0.1, 0.02, 0.65),
          (sx * 2.55 + k * 0.16 - 0.16, -0.18, 3.0), m_dk, claw, rot=(math.radians(160), 0, 0))
# ноги: бедро/голень/ступня
for tag, leg, shin, px, py in (('FL', 'legFL', 'shinFL', -0.85, -0.1),
                               ('FR', 'legFR', 'shinFR', 0.85, -0.1),
                               ('BL', 'legBL', 'shinBL', -1.1, 0.6),
                               ('BR', 'legBR', 'shinBR', 1.1, 0.6)):
    P(f'thigh_{tag}', 'box', (0.62, 0.62, 1.7), (px, py, 1.85), m_bone, leg)
    P(f'sh_{tag}', 'box', (0.45, 0.45, 1.35), (px * 1.05, py * 1.15, 0.65), m_dk, shin)
    P(f'foot_{tag}', 'box', (0.72, 1.0, 0.3), (px * 1.05, py * 1.1 - 0.1, 0.12), m_bone, shin)

bind_parts(parts, arm)

# ================= клипы =================
an = Anim(arm)
CLIPS = {}

# idle: дыхание, хребет шевелится, челюсть клацает редко
an.reset()
act = an.action('idle')
for f in range(1, 97, 8):
    t = f / 96 * math.tau
    an.pose(f, {
        'root': [('Z', math.sin(t) * 1.5), ('move', (0, 0, 0.05 * math.sin(t)))],
        'spine1': [('X', math.sin(t) * 2.0)],
        'chest': [('X', math.sin(t + 0.6) * 2.5)],
        'head': [('X', math.sin(t + 1.0) * 3.0), ('Y', math.sin(t * 0.5) * 5.0)],
        'jaw': [('X', abs(math.sin(t * 0.5)) * -10.0)],
        'armL': [('X', math.sin(t) * 2.5)], 'armR': [('X', math.sin(t + 1) * 2.5)],
    })
CLIPS['idle'] = (1, 96)

# walk: тяжёлый шаг, 1.6 с
an.reset()
act = an.action('walk')
WF = 48
for f in range(1, WF + 1, 3):
    t = f / WF * math.tau
    an.pose(f, {
        'legFL': [('X', math.sin(t) * 20.0)], 'shinFL': [('X', -max(0, math.sin(t + 1.8)) * 22.0)],
        'legFR': [('X', math.sin(t + math.pi) * 20.0)], 'shinFR': [('X', -max(0, math.sin(t + 1.8 + math.pi)) * 22.0)],
        'legBL': [('X', math.sin(t + math.pi / 2) * 18.0)], 'shinBL': [('X', -max(0, math.sin(t + 1.8 + math.pi / 2)) * 20.0)],
        'legBR': [('X', math.sin(t + 3 * math.pi / 2) * 18.0)], 'shinBR': [('X', -max(0, math.sin(t + 1.8 + 3 * math.pi / 2)) * 20.0)],
        'root': [('move', (0, 0, 0.1 * abs(math.sin(t * 2))))],
        'spine1': [('Y', math.sin(t) * 3.0)],
        'armL': [('X', math.sin(t + math.pi) * 8.0)], 'armR': [('X', math.sin(t) * 8.0)],
        'head': [('X', math.sin(t * 2) * 2.0)],
    })
CLIPS['walk'] = (1, WF)

# attack: замах двумя руками вверх -> сокрушительный удар вниз
an.reset()
act = an.action('attack')
K = [(1, 0.0), (8, -1.0), (16, 1.0), (28, 0.0)]
for f, k in K:
    an.pose(f, {
        'armL': [('X', k * -55.0)], 'foreL': [('X', k * -25.0)],
        'armR': [('X', k * -55.0)], 'foreR': [('X', k * -25.0)],
        'clawL': [('X', k * -15.0)], 'clawR': [('X', k * -15.0)],
        'chest': [('X', k * -10.0)], 'head': [('X', k * -8.0)],
        'root': [('move', (0, k * -0.4, k * 0.15))],
        'jaw': [('X', k * -14.0)],
    })
CLIPS['attack'] = (1, 28)

# death: оседание, крен набок, развал
an.reset()
act = an.action('death')
for f in range(1, 43, 3):
    t = min(1.0, f / 30.0)
    an.pose(f, {
        'root': [('Z', 16.0 * t), ('move', (0, 0, -1.7 * t))],
        'spine1': [('Y', 12.0 * t)],
        'legFL': [('X', 30.0 * t)], 'legFR': [('X', 30.0 * t)],
        'legBL': [('X', 30.0 * t)], 'legBR': [('X', 30.0 * t)],
        'armL': [('Z', 30.0 * t)], 'armR': [('Z', -30.0 * t)],
        'head': [('X', -20.0 * t), ('Z', 18.0 * t)],
    })
CLIPS['death'] = (1, 42)

export_glb(os.path.join(OUT, 'kostolom_anim.glb'), arm)
render_clips(OUT, arm, CLIPS, center=(0, 0, 3.2), cam_dist=(7.5, -10.5, 3.6))
print('KOSTOLOM DONE')
