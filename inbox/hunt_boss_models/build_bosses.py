# -*- coding: utf-8 -*-
# Боссы 2-6: Туманница, Пожиратель, Столп Грозы, Хромец, Мать-в-болоте.
import bpy, math, os, sys
sys.path.insert(0, r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models')
import importlib
from boss_kit import *
import boss_kit
importlib.reload(boss_kit)
from boss_kit import *

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models'


def P(parts, name, kind, size, loc, mat, bone, rot=(0, 0, 0)):
    parts.append(add_part(name, kind, size, loc, mat, bone, rot))


# ================= ТУМАННИЦА (4 м, парящая в саване) =================
def tumannitsa():
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 2.6), (0, 0, 3.0)),
        ('body', 'root', (0, 0, 2.2), (0, 0, 1.0)),
        ('veil', 'body', (0, 0, 1.4), (0, 0, 0.2)),
        ('armL', 'body', (-0.55, 0, 2.6), (-1.0, -0.15, 1.7)),
        ('armR', 'body', (0.55, 0, 2.6), (1.0, -0.15, 1.7)),
        ('handL', 'armL', (-1.0, -0.15, 1.7), (-1.25, -0.2, 1.1)),
        ('handR', 'armR', (1.0, -0.15, 1.7), (1.25, -0.2, 1.1)),
        ('head', 'root', (0, 0, 3.05), (0, 0, 3.75)),
    ]
    arm = make_armature('TumannitsaArm', BONES)
    parts = []
    veil = mat_simple('veil', (0.75, 0.78, 0.85), (0.45, 0.55, 0.75), 1.2)
    dark = mat_simple('shade', (0.25, 0.28, 0.35))
    eye = mat_simple('eyes', (0.1, 0.1, 0.12), (0.7, 0.9, 1.0), 2.5)
    # саван: конус + внутренний тёмный слой
    P(parts, 'veil_outer', 'cone', (1.15, 0.25, 3.0), (0, 0, 1.35), veil, 'veil')
    P(parts, 'veil_inner', 'cone', (0.8, 0.15, 2.4), (0, 0, 1.5), dark, 'veil')
    # капюшон/голова
    P(parts, 'hood', 'sphere', 0.55, (0, 0, 3.35), veil, 'head')
    P(parts, 'face', 'sphere', 0.34, (0, -0.18, 3.3), dark, 'head')
    for dx in (-0.14, 0.14):  # глаза-точки
        P(parts, f'eye_{dx}', 'sphere', 0.05, (dx, -0.42, 3.36), eye, 'head')
    # руки-рукава
    for sx, up, hand in ((-1, 'armL', 'handL'), (1, 'armR', 'handR')):
        P(parts, f'sleeve_{sx}', 'cone', (0.28, 0.1, 1.3), (sx * 0.75, -0.05, 2.15), veil, up,
          rot=(math.radians(-25 * sx), 0, 0))
        P(parts, f'hand_{sx}', 'sphere', 0.16, (sx * 1.12, -0.18, 1.4), eye, hand)
    bind_parts(parts, arm)
    an = Anim(arm)
    clips = {}
    # idle: парение + колыхание савана
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.14 * math.sin(t)), ), ('X', math.sin(t) * 2.0)],
            'veil': [('Y', math.sin(t * 0.7) * 5.0)],
            'armL': [('Z', math.sin(t) * 6.0)], 'armR': [('Z', math.sin(t + math.pi) * 6.0)],
            'head': [('X', math.sin(t + 0.8) * 3.0)],
        })
    clips['idle'] = (1, 96)
    # walk = дрейф вперёд-назад (стоит на месте по лору)
    an.reset(); an.action('walk')
    for f in range(1, 49, 6):
        t = f / 48 * math.tau
        an.pose(f, {
            'root': [('move', (0, -0.5 * math.sin(t), 0.12 * math.sin(t * 2)))],
            'veil': [('Y', math.sin(t * 1.4) * 7.0)],
            'armL': [('Z', math.sin(t) * 9.0)], 'armR': [('Z', math.sin(t + math.pi) * 9.0)],
        })
    clips['walk'] = (1, 48)
    # attack: руки вскинулись, саван вспыхнул рывком
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'armL': [('Z', k * -40.0), ('X', k * -25.0)],
            'armR': [('Z', k * 40.0), ('X', k * -25.0)],
            'handL': [('X', k * -15.0)], 'handR': [('X', k * -15.0)],
            'head': [('X', k * -12.0)],
            'root': [('move', (0, k * -0.5, k * 0.2))],
        })
    clips['attack'] = (1, 28)
    # death: оседание + растворение (усадка и наклон)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 32.0)
        an.pose(f, {
            'root': [('move', (0, 0, -1.6 * t)), ('Z', 25.0 * t)],
            'veil': [('X', 18.0 * t)],
            'armL': [('Z', 50.0 * t)], 'armR': [('Z', -50.0 * t)],
            'head': [('X', -25.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(os.path.join(OUT, 'tumannitsa_anim.glb'), arm)
    render_clips(OUT, arm, clips, center=(0, 0, 2.0), cam_dist=(3.2, -4.6, 1.6), prefix='tum_')
    print('TUMANNITSA DONE')


# ================= ПОЖИРАТЕЛЬ (3.5 м пятиногая пасть-бочка) =================
def pozhiratel():
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 2.3), (0, 0, 2.9)),
        ('maw', 'root', (0, 0, 2.5), (0, 0, 3.1)),
        ('jaw_top', 'maw', (0, -0.5, 3.0), (0, -1.1, 2.9)),
        # 5 ног по кругу
        ('leg1', 'root', (1.2, 0.0, 1.5), (1.7, 0.0, 0.4)),
        ('leg2', 'root', (0.37, 1.14, 1.5), (0.53, 1.63, 0.4)),
        ('leg3', 'root', (-0.97, 0.71, 1.5), (-1.37, 1.02, 0.4)),
        ('leg4', 'root', (-0.97, -0.71, 1.5), (-1.37, -1.02, 0.4)),
        ('leg5', 'root', (0.37, -1.14, 1.5), (0.53, -1.63, 0.4)),
    ]
    arm = make_armature('PozhiratelArm', BONES)
    parts = []
    hide = mat_simple('hide', (0.45, 0.28, 0.18))
    hide2 = mat_simple('hide2', (0.36, 0.22, 0.15))
    maw = mat_simple('maw', (0.16, 0.05, 0.04), (0.8, 0.15, 0.1), 0.9)
    tooth = mat_simple('tooth', (0.92, 0.88, 0.75))
    # бочка-туловище
    P(parts, 'barrel', 'sphere', 1.25, (0, 0, 2.1), hide, 'root')
    P(parts, 'barrel_top', 'sphere', 0.95, (0, -0.2, 2.75), hide2, 'maw')
    # пасть: верхняя челюсть-крышка + зубы по кругу
    P(parts, 'jawtop', 'sphere', 0.78, (0, -0.35, 3.05), hide2, 'jaw_top')
    for i in range(8):
        a = math.tau * i / 8
        P(parts, f'tooth_{i}', 'cone', (0.09, 0.02, 0.3),
          (math.cos(a) * 0.62, -0.35 + math.sin(a) * 0.62, 2.55), tooth, 'jaw_top',
          rot=(0, 0, -a))
    # глазки-бугорки вокруг
    for i in range(5):
        a = math.tau * i / 5 + 0.5
        P(parts, f'eye_{i}', 'sphere', 0.11, (math.cos(a) * 1.05, -0.15 + math.sin(a) * 1.05, 3.0),
          tooth, 'maw')
    # 5 ног: бедро + ступня
    for i, leg in enumerate(('leg1', 'leg2', 'leg3', 'leg4', 'leg5')):
        a = math.tau * i / 5
        hx, hy = math.cos(a) * 1.2, math.sin(a) * 1.2
        fx, fy = math.cos(a) * 1.7, math.sin(a) * 1.7
        P(parts, f'thigh_{i}', 'cone', (0.34, 0.2, 1.4), (hx, hy, 1.15), hide2, leg,
          rot=(math.radians(-70), 0, -a + math.pi / 2))
        P(parts, f'foot_{i}', 'sphere', 0.3, (fx, fy, 0.22), hide, leg)
    bind_parts(parts, arm)
    an = Anim(arm)
    clips = {}
    # idle: пасть дышит, бочка колышется
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.08 * math.sin(t)))],
            'jaw_top': [('X', -8.0 + math.sin(t) * 7.0)],
            'maw': [('X', math.sin(t) * 2.0)],
        })
    clips['idle'] = (1, 96)
    # walk: впялить шаг — ноги по очереди
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        spec = {'root': [('move', (0, 0, 0.06 * abs(math.sin(t * 2.5))))]}
        for i, leg in enumerate(('leg1', 'leg2', 'leg3', 'leg4', 'leg5')):
            a = math.tau * i / 5
            spec[leg] = [('X', math.sin(t + a) * 14.0)]
        an.pose(f, spec)
    clips['walk'] = (1, 48)
    # attack: пасть раскрывается широко + рывок вперёд
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'jaw_top': [('X', k * -38.0)],
            'maw': [('X', k * 8.0)],
            'root': [('move', (0, k * -0.7, k * 0.1))],
            'leg1': [('X', k * -12.0)], 'leg2': [('X', k * -6.0)], 'leg5': [('X', k * -6.0)],
        })
    clips['attack'] = (1, 28)
    # death: ноги подкашиваются, бочка опрокидывается
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        spec = {'root': [('move', (0, 0.3 * t, -0.9 * t)), ('Y', 55.0 * t)]}
        for i, leg in enumerate(('leg1', 'leg2', 'leg3', 'leg4', 'leg5')):
            spec[leg] = [('X', 30.0 * t)]
        spec['maw'] = [('X', 12.0 * t)]
        an.pose(f, spec)
    clips['death'] = (1, 42)
    export_glb(os.path.join(OUT, 'pozhiratel_anim.glb'), arm)
    render_clips(OUT, arm, clips, center=(0, 0, 1.9), cam_dist=(3.6, -5.2, 1.8), prefix='poz_')
    print('POZHIRATEL DONE')


# ================= СТОЛП ГРОЗЫ (6 м тотем на дугах-ногах) =================
def stolp():
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 3.1), (0, 0, 3.9)),
        ('totem', 'root', (0, 0, 3.9), (0, 0, 5.4)),
        ('crown', 'totem', (0, 0, 5.4), (0, 0, 6.1)),
        ('legL', 'root', (-1.1, 0, 2.6), (-1.8, 0, 0.9)),
        ('footL', 'legL', (-1.8, 0, 0.9), (-2.0, 0, 0.1)),
        ('legR', 'root', (1.1, 0, 2.6), (1.8, 0, 0.9)),
        ('footR', 'legR', (1.8, 0, 0.9), (2.0, 0, 0.1)),
        ('legB', 'root', (0, 0.9, 2.6), (0, 1.6, 0.9)),
        ('footB', 'legB', (0, 1.6, 0.9), (0, 1.85, 0.1)),
    ]
    arm = make_armature('StolpArm', BONES)
    parts = []
    stone = mat_simple('stone', (0.22, 0.24, 0.3))
    stone2 = mat_simple('stone2', (0.16, 0.18, 0.24))
    glyph = mat_simple('glyph', (0.5, 0.5, 0.6), (0.45, 0.65, 1.0), 2.6)
    arc = mat_simple('arc', (0.3, 0.34, 0.42))
    # тотем: ярусы
    tiers = [(0, 3.1, 1.15, 1.0), (1.05, 3.9, 0.95, 0.9), (2.0, 4.6, 0.8, 0.8), (2.85, 5.3, 0.62, 0.75)]
    for i, (y, h, r1, r2) in enumerate(tiers):
        P(parts, f'tier_{i}', 'cone', (r1, r2, h), (0, 0, y + h / 2), stone if i % 2 == 0 else stone2, 'totem')
        P(parts, f'glyph_{i}', 'box', (0.1, 0.5, 0.5), (r1 * 0.92, 0, y + h / 2), glyph, 'totem')
    # корона: 4 зубца
    for i in range(4):
        a = math.tau * i / 4
        P(parts, f'crown_{i}', 'cone', (0.12, 0.02, 0.8),
          (math.cos(a) * 0.3, math.sin(a) * 0.3, 5.75), glyph, 'crown',
          rot=(0.35 * math.sin(a), -0.35 * math.cos(a), 0))
    # лицевая щель с эмиссией
    P(parts, 'face', 'box', (0.16, 0.34, 0.6), (0.68, 0, 4.7), glyph, 'totem')
    # дуги-ноги (3 штуки): сегменты
    for tag, leg, foot in (('L', 'legL', 'footL'), ('R', 'legR', 'footR'), ('B', 'legB', 'footB')):
        P(parts, f'arc_{tag}_a', 'box', (0.3, 0.3, 1.9), (1.45, 0, 1.75) if tag != 'B' else (0, 1.45, 1.75),
          arc, leg, rot=(math.radians(-18) if tag != 'B' else math.radians(-18), math.radians(18) if tag == 'L' else (-math.radians(18) if tag == 'R' else 0), 0))
        P(parts, f'arc_{tag}_b', 'box', (0.26, 0.26, 1.1), (1.8, 0, 0.55) if tag != 'B' else (0, 1.75, 0.55),
          stone2, foot, rot=(math.radians(-30), 0, 0) if tag != 'B' else (math.radians(-30), 0, 0))
    bind_parts(parts, arm)
    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.1 * math.sin(t)))],
            'totem': [('Z', math.sin(t) * 2.0)],
            'crown': [('Z', math.sin(t + 0.8) * 5.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'legL': [('X', math.sin(t) * 8.0)], 'legR': [('X', math.sin(t + math.pi) * 8.0)],
            'legB': [('X', math.sin(t + math.pi / 2) * 8.0)],
            'root': [('move', (0, 0, 0.06 * abs(math.sin(t * 2))))],
            'totem': [('Y', math.sin(t) * 2.5)],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (8, -1.0), (18, 1.0), (30, 0.0)):
        an.pose(f, {
            'totem': [('X', k * -6.0)],
            'crown': [('Z', k * 14.0)],
            'root': [('move', (0, k * -0.4, k * 0.25))],
            'legL': [('X', k * -8.0)], 'legR': [('X', k * -8.0)], 'legB': [('X', k * -8.0)],
        })
    clips['attack'] = (1, 30)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0.4 * t, -2.2 * t)), ('Y', 45.0 * t)],
            'legL': [('X', 20.0 * t)], 'legR': [('X', -20.0 * t)], 'legB': [('X', 20.0 * t)],
            'crown': [('Z', 30.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(os.path.join(OUT, 'stolp_anim.glb'), arm)
    render_clips(OUT, arm, clips, center=(0, 0, 3.2), cam_dist=(5.0, -7.4, 2.8), prefix='sto_')
    print('STOLP DONE')


# ================= ХРОМЕЦ (2.5 м тощий двуногий бегун) =================
def hromets():
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 1.5), (0, 0, 1.75)),
        ('spine', 'root', (0, 0, 1.55), (0.12, 0, 2.05)),
        ('neck', 'spine', (0.12, 0, 2.05), (0.3, 0, 2.25)),
        ('head', 'neck', (0.3, 0, 2.25), (0.5, 0, 2.3)),
        ('jawL', 'head', (0.42, 0.08, 2.2), (0.58, 0.1, 2.14)),
        ('jawR', 'head', (0.42, -0.08, 2.2), (0.58, -0.1, 2.14)),
        ('armBig', 'spine', (-0.05, -0.3, 1.7), (-0.75, -0.55, 1.25)),
        ('clawBig', 'armBig', (-0.75, -0.55, 1.25), (-1.05, -0.7, 0.85)),
        ('armSm', 'spine', (0.2, 0.3, 1.68), (0.45, 0.45, 1.3)),
        ('legL', 'root', (-0.22, 0.1, 1.4), (-0.4, 0.16, 0.85)),
        ('shinL', 'legL', (-0.4, 0.16, 0.85), (-0.32, 0.1, 0.12)),
        ('legR', 'root', (0.26, -0.05, 1.42), (0.44, -0.02, 0.9)),
        ('shinR', 'legR', (0.44, -0.02, 0.9), (0.34, -0.06, 0.1)),
    ]
    arm = make_armature('HrometsArm', BONES)
    parts = []
    skin = mat_simple('skin', (0.5, 0.42, 0.3))
    skin2 = mat_simple('skin2', (0.4, 0.34, 0.24))
    clawm = mat_simple('claw', (0.85, 0.82, 0.72))
    eye = mat_simple('eye', (0.05, 0.05, 0.05), (1.0, 0.5, 0.2), 2.2)
    P(parts, 'torso', 'box', (0.4, 0.5, 0.7), (0.05, 0, 1.7), skin, 'root')
    P(parts, 'chest2', 'box', (0.3, 0.4, 0.5), (0.1, 0, 2.0), skin2, 'spine')
    P(parts, 'neck_b', 'box', (0.16, 0.16, 0.5), (0.2, 0, 2.15), skin2, 'neck',
      rot=(0, math.radians(-24), 0))
    P(parts, 'head', 'box', (0.34, 0.28, 0.24), (0.42, 0, 2.26), skin, 'head')
    for tag in ('jawL', 'jawR'):
        P(parts, f'jaw_{tag}', 'box', (0.24, 0.09, 0.09), (0.5, 0.09 if tag == 'jawL' else -0.09, 2.16),
          skin2, tag)
    for dx in (-0.06, 0.1):
        P(parts, f'eye_{dx}', 'sphere', 0.045, (0.52, dx, 2.3), eye, 'head')
    # асимметрия: большая рука-коса и рудимент
    P(parts, 'arm_big', 'box', (0.22, 0.22, 1.15), (-0.4, -0.42, 1.5), skin, 'armBig',
      rot=(0, math.radians(18), 0))
    P(parts, 'claw_big', 'cone', (0.12, 0.02, 0.75), (-0.9, -0.62, 1.05), clawm, 'clawBig',
      rot=(0, math.radians(-35), math.radians(20)))
    P(parts, 'arm_small', 'box', (0.13, 0.13, 0.62), (0.33, 0.38, 1.5), skin2, 'armSm',
      rot=(0, math.radians(-14), 0))
    # двуногие кривые ноги
    for tag, leg, shin, px, py in (('L', 'legL', 'shinL', -0.32, 0.13), ('R', 'legR', 'shinR', 0.35, -0.03)):
        P(parts, f'thigh_{tag}', 'box', (0.18, 0.2, 0.85), (px, py, 1.15), skin2, leg)
        P(parts, f'sh_{tag}', 'box', (0.12, 0.14, 1.0), (px * 0.9, py * 0.8, 0.5), skin, shin)
        P(parts, f'foot_{tag}', 'box', (0.26, 0.4, 0.14), (px * 0.85, py * 0.6 - 0.1, 0.06), clawm, shin)
    bind_parts(parts, arm)
    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 73, 6):
        t = f / 72 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.02 * math.sin(t * 2)))],
            'neck': [('X', math.sin(t) * 4.0), ('Y', math.sin(t * 0.7) * 6.0)],
            'head': [('X', math.sin(t + 0.7) * 3.0)],
            'armBig': [('X', math.sin(t) * 3.5)],
            'spine': [('Z', math.sin(t * 0.6) * 3.0)],
        })
    clips['idle'] = (1, 72)
    an.reset(); an.action('walk')
    for f in range(1, 25, 2):   # быстрый семенящий шаг
        t = f / 24 * math.tau
        an.pose(f, {
            'legL': [('X', math.sin(t) * 30.0)], 'legR': [('X', math.sin(t + math.pi) * 30.0)],
            'shinL': [('X', -max(0, math.sin(t + 2.0)) * 35.0)],
            'shinR': [('X', -max(0, math.sin(t + 2.0 + math.pi)) * 35.0)],
            'root': [('move', (0, 0, 0.04 * abs(math.sin(t * 2))))],
            'spine': [('X', 8.0)],
            'armBig': [('X', math.sin(t + math.pi) * 10.0)],
            'armSm': [('X', math.sin(t) * 12.0)],
            'neck': [('X', -6.0)],
        })
    clips['walk'] = (1, 24)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (6, -1.0), (13, 1.0), (24, 0.0)):
        an.pose(f, {
            'armBig': [('X', k * -60.0)],
            'clawBig': [('X', k * -25.0)],
            'spine': [('Y', k * -12.0), ('X', k * -8.0)],
            'head': [('X', k * -10.0)],
            'jawL': [('X', k * -14.0)], 'jawR': [('X', k * -14.0)],
            'legL': [('X', k * -20.0)], 'legR': [('X', k * 12.0)],
            'root': [('move', (0, k * -0.3, k * 0.05))],
        })
    clips['attack'] = (1, 24)
    an.reset(); an.action('death')
    for f in range(1, 37, 3):
        t = min(1.0, f / 26.0)
        an.pose(f, {
            'root': [('move', (0, 0.2 * t, -0.55 * t)), ('Y', 40.0 * t)],
            'legL': [('X', 35.0 * t)], 'legR': [('X', -25.0 * t)],
            'shinL': [('X', -30.0 * t)],
            'neck': [('X', -20.0 * t)], 'head': [('X', -15.0 * t)],
            'armBig': [('Z', 40.0 * t)],
        })
    clips['death'] = (1, 36)
    export_glb(os.path.join(OUT, 'hromets_anim.glb'), arm)
    render_clips(OUT, arm, clips, center=(0, 0, 1.2), cam_dist=(2.6, -3.8, 1.3), prefix='hro_')
    print('HROMETS DONE')


# ================= МАТЬ-В-БОЛОТЕ (4 м морда на корневищах) =================
def mat_bolota():
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 2.2), (0, 0, 2.8)),
        ('mound', 'root', (0, 0, 1.7), (0, 0, 0.9)),
        ('maw', 'root', (0, -0.6, 2.0), (0, -1.3, 1.9)),
        ('jaw', 'maw', (0, -1.0, 1.75), (0, -1.7, 1.7)),
        ('rootlegFL', 'root', (-0.9, -0.2, 1.2), (-1.6, -0.5, 0.25)),
        ('rootlegFR', 'root', (0.9, -0.2, 1.2), (1.6, -0.5, 0.25)),
        ('rootlegBL', 'root', (-0.7, 0.5, 1.2), (-1.3, 0.9, 0.25)),
        ('rootlegBR', 'root', (0.7, 0.5, 1.2), (1.3, 0.9, 0.25)),
    ]
    arm = make_armature('MatBolotaArm', BONES)
    parts = []
    moss = mat_simple('moss', (0.32, 0.42, 0.22))
    moss2 = mat_simple('moss2', (0.26, 0.34, 0.18))
    mawm = mat_simple('mawm', (0.12, 0.08, 0.05), (0.35, 0.15, 0.05), 0.7)
    glow = mat_simple('glowm', (0.6, 0.75, 0.4), (0.5, 0.75, 0.25), 1.8)
    # курган-тело
    P(parts, 'mound_b', 'sphere', 1.15, (0, 0.45, 1.35), moss, 'mound')
    P(parts, 'mound_t', 'sphere', 0.85, (0, -0.05, 1.85), moss2, 'mound')
    # морда-маска на фронте
    P(parts, 'faceplate', 'sphere', 0.62, (0, -1.0, 2.15), moss2, 'maw')
    P(parts, 'maw_hole', 'sphere', 0.42, (0, -1.35, 1.9), mawm, 'maw')
    for dx in (-0.3, 0.3):  # глаза-щели светятся
        P(parts, f'eye_{dx}', 'box', (0.24, 0.12, 0.1), (dx, -1.45, 2.42), glow, 'maw')
    # гребень
    for i in range(5):
        z = 2.5 + i * 0.16
        P(parts, f'crest_{i}', 'cone', (0.12, 0.02, 0.5 - i * 0.06), (0, 0.1 + i * 0.12, z),
          moss2, 'mound', rot=(math.radians(100), 0, 0))
    # пасть: верхняя губа + зубы
    P(parts, 'lip', 'cone', (0.55, 0.3, 0.5), (0, -1.1, 2.25), moss, 'maw')
    for i in range(6):
        a = math.pi * (0.15 + 0.7 * i / 5)
        P(parts, f'tooth_{i}', 'cone', (0.07, 0.02, 0.24),
          (math.cos(a) * 0.42, -1.28, 1.85 + math.sin(a) * 0.1), moss2, 'jaw')
    # корневища-ноги (4)
    for tag, leg, px, py in (('FL', 'rootlegFL', -1.25, -0.35), ('FR', 'rootlegFR', 1.25, -0.35),
                             ('BL', 'rootlegBL', -1.0, 0.7), ('BR', 'rootlegBR', 1.0, 0.7)):
        P(parts, f'root_{tag}', 'cone', (0.26, 0.12, 1.7), (px, py, 0.8), moss2, leg,
          rot=(math.radians(65), 0, math.atan2(py, px) + math.pi / 2))
        P(parts, f'clawroot_{tag}', 'cone', (0.18, 0.04, 0.5), (px * 1.08, py * 1.08, 0.18),
          moss, leg, rot=(math.radians(80), 0, math.atan2(py, px) + math.pi / 2))
    bind_parts(parts, arm)
    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.09 * math.sin(t)))],
            'mound': [('X', math.sin(t) * 2.0)],
            'maw': [('X', math.sin(t + 0.5) * 3.0)],
            'jaw': [('X', math.sin(t + 0.7) * 5.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        spec = {'root': [('move', (0, 0, 0.05 * abs(math.sin(t * 2))))],
                'maw': [('X', math.sin(t) * 2.0)]}
        for i, leg in enumerate(('rootlegFL', 'rootlegFR', 'rootlegBL', 'rootlegBR')):
            spec[leg] = [('X', math.sin(t + i * math.pi / 2) * 10.0),
                         ('Y', math.cos(t + i * math.pi / 2) * 5.0)]
        an.pose(f, spec)
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'maw': [('X', k * -10.0)],
            'jaw': [('X', k * -24.0)],
            'root': [('move', (0, k * -0.6, k * 0.08))],
            'rootlegFL': [('X', k * -14.0)], 'rootlegFR': [('X', k * -14.0)],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        spec = {'root': [('move', (0, 0.2 * t, -0.9 * t)), ('X', 12.0 * t)],
                'maw': [('X', 15.0 * t)], 'jaw': [('X', 20.0 * t)]}
        for leg in ('rootlegFL', 'rootlegFR', 'rootlegBL', 'rootlegBR'):
            spec[leg] = [('X', 25.0 * t), ('Y', 25.0 * t)]
        an.pose(f, spec)
    clips['death'] = (1, 42)
    export_glb(os.path.join(OUT, 'mat_bolota_anim.glb'), arm)
    render_clips(OUT, arm, clips, center=(0, 0, 1.7), cam_dist=(3.8, -5.6, 1.8), prefix='mat_')
    print('MAT_BOLOTA DONE')


if __name__ == '__main__':
    tumannitsa()
    pozhiratel()
    stolp()
    hromets()
    mat_bolota()
    print('ALL BOSSES DONE')
