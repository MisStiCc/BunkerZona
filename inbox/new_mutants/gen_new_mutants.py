# -*- coding: utf-8 -*-
# ЗАДАЧА 43: 8 новых оригинальных мутантов (модель+риг+4 клипа) + карточки.
# Фреймворк boss_kit. Роли под пачки: ТАНК/ЛЕЧ/УРОН/БАФ.
import bpy
import math
import os
import sys

sys.path.insert(0, r'E:\StalkerRevert\StalkerRevert\inbox\hunt_boss_models')
import importlib
import boss_kit
importlib.reload(boss_kit)
from boss_kit import (new_scene, make_armature, mat_simple, bind_parts, Anim,
                      export_glb, add_part, light_and_cam, render_clips)

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\new_mutants'
MODELS = os.path.join(OUT, 'models')
CARDS = os.path.join(OUT, 'cards')


def P(parts, name, kind, size, loc, mat, bone, rot=(0, 0, 0)):
    parts.append(add_part(name, kind, size, loc, mat, bone, rot))


def part(name, kind, size, loc, mat, bone, rot=(0, 0, 0)):
    """Создать часть без регистрации в списке (для объектов-не-частей)."""
    return add_part(name, kind, size, loc, mat, bone, rot)


# ============================================================
# 1. КРЕМЕНЬ — каменный панцирник-таран (ТАНК, uncommon)
# ============================================================
def build_kremen(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 0.55), (0, 0, 0.95)),
        ('shell', 'root', (0, 0, 0.95), (0, 0, 1.25)),
        ('head', 'root', (0.95, 0, 0.55), (1.35, 0, 0.6)),
        ('legFL', 'root', (-0.55, -0.5, 0.35), (-0.75, -0.62, 0.0)),
        ('legFR', 'root', (0.55, -0.5, 0.35), (0.75, -0.62, 0.0)),
        ('legBL', 'root', (-0.55, 0.5, 0.35), (-0.75, 0.62, 0.0)),
        ('legBR', 'root', (0.55, 0.5, 0.35), (0.75, 0.62, 0.0)),
        ('tail', 'root', (-0.95, 0, 0.7), (-1.45, 0, 0.55)),
    ]
    arm = make_armature('KremenArm', BONES)
    parts = []
    rock = mat_simple('km_rock', (0.38, 0.39, 0.36))
    rock2 = mat_simple('km_rock2', (0.30, 0.32, 0.28))
    moss = mat_simple('km_moss', (0.32, 0.42, 0.22))
    eye = mat_simple('km_eye', (0.05, 0.05, 0.05), (1.0, 0.55, 0.2), 2.0)
    # купол-панцирь (сплюснутая сфера)
    P(parts, 'dome', 'sphere', 0.95, (0, 0, 0.85), rock, 'shell')
    # наросты на панцире
    for i in range(5):
        a = math.tau * i / 5 + 0.4
        P(parts, f'growth_{i}', 'sphere', 0.28 + (i % 2) * 0.1,
          (math.cos(a) * 0.55, math.sin(a) * 0.45, 1.05 + (i % 3) * 0.08), moss, 'shell')
    # голова-таран
    P(parts, 'ram', 'box', (0.55, 0.62, 0.5), (1.12, 0, 0.62), rock2, 'head')
    P(parts, 'brow', 'box', (0.2, 0.5, 0.18), (1.28, 0, 0.82), rock2, 'head')
    for dy in (-0.14, 0.14):
        P(parts, f'eye_{dy}', 'sphere', 0.06, (1.3, dy, 0.66), eye, 'head')
    # 4 лапы (бедро+ступня одним мешом на кость)
    for tag, leg in (('FL', 'legFL'), ('FR', 'legFR'), ('BL', 'legBL'), ('BR', 'legBR')):
        h = bones_head(BONES, leg)
        P(parts, f'leg_{tag}', 'box', (0.34, 0.34, 0.5), (h[0], h[1], 0.18), rock2, leg)
    # обломок хвоста
    P(parts, 'tail', 'cone', (0.22, 0.06, 0.6), (-1.2, 0, 0.62), rock2, 'tail',
      rot=(0, 0, math.radians(-90)))
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.03 * math.sin(t)))],
            'shell': [('X', math.sin(t) * 1.2)],
            'head': [('X', math.sin(t + 0.7) * 3.0), ('Y', math.sin(t * 0.5) * 4.0)],
            'tail': [('Z', math.sin(t) * 6.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'legFL': [('Z', math.sin(t) * 10.0)], 'legBR': [('Z', math.sin(t) * 10.0)],
            'legFR': [('Z', math.sin(t + math.pi) * 10.0)], 'legBL': [('Z', math.sin(t + math.pi) * 10.0)],
            'root': [('move', (0, 0, 0.04 * abs(math.sin(t * 2))))],
            'head': [('X', math.sin(t * 2) * 2.0)],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (15, 1.0), (28, 0.0)):
        an.pose(f, {
            'head': [('move', (k * 0.45, 0, 0)), ('X', k * -6.0)],
            'root': [('move', (0, 0, k * -0.12))],
            'shell': [('X', k * 4.0)],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0, -0.25 * t)), ('X', 10.0 * t)],
            'shell': [('Z', 14.0 * t)],
            'head': [('move', (0, 0, -0.3 * t))],
            'legFL': [('Z', 25.0 * t)], 'legFR': [('Z', -25.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 0.8)


def bones_head(bones, name):
    for n, p, h, t in bones:
        if n == name:
            return h
    return (0, 0, 0)


# ============================================================
# 2. РЖАВНИК — ржавый краб-сборщик (ТАНК, rare)
# ============================================================
def build_rzhavnik(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 0.95), (0, 0, 1.3)),
        ('lens', 'root', (0, -0.62, 1.35), (0, -0.75, 1.4)),
        ('clawL', 'root', (-0.72, -0.3, 1.05), (-1.15, -0.5, 0.9)),
        ('clawR', 'root', (0.72, -0.3, 1.05), (1.15, -0.5, 0.9)),
        ('legL1', 'root', (-0.5, 0.15, 0.75), (-1.05, 0.3, 0.3)),
        ('legR1', 'root', (0.5, 0.15, 0.75), (1.05, 0.3, 0.3)),
        ('legL2', 'root', (-0.5, 0.35, 0.75), (-1.0, 0.65, 0.3)),
        ('legR2', 'root', (0.5, 0.35, 0.75), (1.0, 0.65, 0.3)),
    ]
    arm = make_armature('RzhavnikArm', BONES)
    parts = []
    rust = mat_simple('rz_rust', (0.45, 0.26, 0.14))
    rust2 = mat_simple('rz_rust2', (0.36, 0.20, 0.11))
    metal = mat_simple('rz_metal', (0.30, 0.31, 0.33))
    lens = mat_simple('rz_lens', (0.1, 0.1, 0.1), (1.0, 0.6, 0.2), 2.6)
    P(parts, 'hull', 'cylinder' if False else 'sphere', 0.72, (0, 0, 1.05), rust, 'root')
    P(parts, 'hull_top', 'sphere', 0.4, (0, 0, 1.55), rust2, 'root')
    P(parts, 'lens_rim', 'cone', (0.2, 0.12, 0.3), (0, -0.6, 1.4), metal, 'lens',
      rot=(math.radians(-90), 0, 0))
    P(parts, 'lens', 'sphere', 0.13, (0, -0.72, 1.4), lens, 'lens')
    # антенна
    P(parts, 'antenna', 'box', (0.04, 0.04, 0.5), (0.15, -0.1, 1.95), metal, 'root')
    # клешни-ковши
    for sx, claw in ((-1, 'clawL'), (1, 'clawR')):
        P(parts, f'arm_{sx}', 'box', (0.24, 0.24, 0.9), (sx * 0.95, -0.4, 0.95), rust2, claw,
          rot=(math.radians(-35), 0, 0))
        P(parts, f'bucket_{sx}', 'box', (0.42, 0.5, 0.36), (sx * 1.2, -0.62, 0.62), metal, claw,
          rot=(0, 0, math.radians(sx * 12)))
        P(parts, f'tooth_{sx}', 'cone', (0.09, 0.02, 0.3), (sx * 1.2, -0.85, 0.48), metal, claw,
          rot=(math.radians(150), 0, 0))
    # 4 ноги-краба (2 сегмента)
    for tag, leg, px, py in (('L1', 'legL1', -0.78, 0.22), ('R1', 'legR1', 0.78, 0.22),
                             ('L2', 'legL2', -0.75, 0.5), ('R2', 'legR2', 0.75, 0.5)):
        P(parts, f'thigh_{tag}', 'cone', (0.16, 0.08, 0.75), (px, py, 0.55), rust2, leg,
          rot=(math.radians(-55), 0, math.atan2(py, px)))
        P(parts, f'sh_{tag}', 'cone', (0.12, 0.05, 0.55), (px * 1.55, py * 1.45, 0.2), rust, leg,
          rot=(math.radians(115), 0, math.atan2(py, px)))
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.05 * math.sin(t)))],
            'clawL': [('X', math.sin(t) * 5.0)], 'clawR': [('X', math.sin(t + 1) * 5.0)],
            'lens': [('Y', math.sin(t * 0.6) * 8.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'legL1': [('Z', math.sin(t) * 12.0)], 'legR2': [('Z', math.sin(t) * 12.0)],
            'legR1': [('Z', math.sin(t + math.pi) * 12.0)], 'legL2': [('Z', math.sin(t + math.pi) * 12.0)],
            'root': [('move', (0, 0, 0.05 * abs(math.sin(t * 2))))],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (15, 1.0), (28, 0.0)):
        an.pose(f, {
            'clawL': [('X', k * -30.0), ('Y', k * -14.0)],
            'clawR': [('X', k * -30.0), ('Y', k * 14.0)],
            'root': [('move', (0, k * -0.3, 0))],
            'lens': [('X', k * 8.0)],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0.15 * t, -0.45 * t)), ('X', 14.0 * t)],
            'clawL': [('Z', 30.0 * t)], 'clawR': [('Z', -30.0 * t)],
            'lens': [('X', -20.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.2)


# ============================================================
# 3. СПОРОНОСЕЦ — гриб-страж (ЛЕЧ, uncommon)
# ============================================================
def build_sporonosets(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 0.15), (0, 0, 0.5)),
        ('stalk', 'root', (0, 0, 0.5), (0, 0, 1.7)),
        ('cap', 'stalk', (0, 0, 1.7), (0, 0, 2.2)),
        ('tend1', 'stalk', (0.2, -0.1, 1.5), (0.55, -0.3, 0.7)),
        ('tend2', 'stalk', (-0.2, 0.1, 1.5), (-0.55, 0.3, 0.7)),
        ('tend3', 'stalk', (0.1, 0.2, 1.45), (0.4, 0.5, 0.75)),
        ('tend4', 'stalk', (-0.1, -0.2, 1.45), (-0.4, -0.5, 0.75)),
    ]
    arm = make_armature('SporonosetsArm', BONES)
    parts = []
    stalk = mat_simple('sp_stalk', (0.62, 0.58, 0.46))
    cap = mat_simple('sp_cap', (0.42, 0.5, 0.3))
    glow = mat_simple('sp_glow', (0.55, 0.75, 0.4), (0.5, 0.8, 0.3), 2.2)
    P(parts, 'base', 'cone', (0.34, 0.2, 0.4), (0, 0, 0.2), stalk, 'root')
    P(parts, 'stalk_m', 'cone', (0.22, 0.15, 1.3), (0, 0, 1.1), stalk, 'stalk')
    P(parts, 'cap_m', 'sphere', 0.85, (0, 0, 1.85), cap, 'cap')
    P(parts, 'cap_glow', 'sphere', 0.5, (0, 0, 1.7), glow, 'cap')
    for i in range(6):  # поры под шляпкой
        a = math.tau * i / 6
        P(parts, f'pore_{i}', 'sphere', 0.09, (math.cos(a) * 0.5, math.sin(a) * 0.5, 1.55), glow, 'cap')
    for i, t in enumerate(('tend1', 'tend2', 'tend3', 'tend4')):
        h = bones_head(BONES, t)
        P(parts, f'tendr_{i}', 'cone', (0.1, 0.03, 1.1), (h[0] * 0.6, h[1] * 0.6, 1.1), stalk, t,
          rot=(math.radians(55), 0, math.atan2(h[1], h[0])))
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.04 * math.sin(t)))],
            'cap': [('X', math.sin(t) * 3.0), ('Y', math.cos(t) * 3.0)],
            'tend1': [('X', math.sin(t) * 6.0)], 'tend2': [('X', math.sin(t + 1.6) * 6.0)],
            'tend3': [('Z', math.sin(t + 0.8) * 6.0)], 'tend4': [('X', math.sin(t + 2.4) * 6.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'stalk': [('X', math.sin(t) * 5.0)],
            'root': [('move', (0, 0, 0.05 * abs(math.sin(t))))],
            'cap': [('Y', math.sin(t) * 4.0)],
            'tend1': [('X', math.sin(t) * 8.0)], 'tend3': [('X', math.sin(t + math.pi) * 8.0)],
            'tend2': [('Z', math.sin(t) * 6.0)], 'tend4': [('Z', math.sin(t + math.pi) * 6.0)],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'cap': [('X', k * -14.0)],
            'root': [('move', (0, 0, k * 0.1))],
            'tend1': [('X', k * 25.0)], 'tend2': [('X', k * 25.0)],
            'tend3': [('X', k * 20.0)], 'tend4': [('X', k * 20.0)],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0, -0.5 * t)), ('X', 20.0 * t)],
            'cap': [('X', 24.0 * t)],
            'stalk': [('X', 15.0 * t)],
            'tend1': [('X', 30.0 * t)], 'tend4': [('Z', 25.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.4)


# ============================================================
# 4. ЧРЕВО — пульсирующая плоть (ЛЕЧ, epic)
# ============================================================
def build_chrevo(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 0.9), (0, 0, 1.2)),
        ('body', 'root', (0, 0, 0.9), (0, 0, 1.4)),
        ('womb', 'body', (0, -0.35, 1.05), (0, -0.5, 1.15)),
        ('tend1', 'root', (-0.7, -0.2, 0.6), (-1.2, -0.35, 0.05)),
        ('tend2', 'root', (0.7, -0.2, 0.6), (1.2, -0.35, 0.05)),
        ('tend3', 'root', (-0.5, 0.45, 0.6), (-0.9, 0.7, 0.05)),
        ('tend4', 'root', (0.5, 0.45, 0.6), (0.9, 0.7, 0.05)),
        ('nub', 'body', (0, 0.45, 1.35), (0, 0.55, 1.5)),
    ]
    arm = make_armature('ChrevoArm', BONES)
    parts = []
    flesh = mat_simple('ch_flesh', (0.42, 0.2, 0.24))
    flesh2 = mat_simple('ch_flesh2', (0.32, 0.15, 0.18))
    womb_g = mat_simple('ch_womb', (0.5, 0.25, 0.3), (1.0, 0.3, 0.4), 2.4)
    P(parts, 'body_b', 'sphere', 0.95, (0, 0.1, 0.95), flesh, 'body')
    P(parts, 'body_t', 'sphere', 0.7, (0, -0.1, 1.3), flesh2, 'body')
    P(parts, 'womb_core', 'sphere', 0.5, (0, -0.42, 1.08), womb_g, 'womb')
    P(parts, 'nub_head', 'sphere', 0.24, (0, 0.5, 1.42), flesh2, 'nub')
    for i in range(4):
        t = ('tend1', 'tend2', 'tend3', 'tend4')[i]
        h = bones_head(BONES, t)
        P(parts, f'tendr_{i}', 'cone', (0.16, 0.05, 1.2), (h[0] * 0.55, h[1] * 0.55, 0.5),
          flesh2, t, rot=(math.radians(68), 0, math.atan2(h[1], h[0])))
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 6):   # пульс чаще дыхания
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.05 * math.sin(t * 1.5)))],
            'womb': [('X', math.sin(t * 2.0) * 5.0)],
            'tend1': [('X', math.sin(t + 0.5) * 5.0)], 'tend2': [('X', math.sin(t + 2.0) * 5.0)],
            'tend3': [('Z', math.sin(t + 1.2) * 5.0)], 'tend4': [('Z', math.sin(t + 2.8) * 5.0)],
            'nub': [('Y', math.sin(t) * 5.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'tend1': [('X', math.sin(t) * 9.0)], 'tend2': [('X', math.sin(t + math.pi) * 9.0)],
            'tend3': [('Z', math.sin(t + math.pi / 2) * 8.0)], 'tend4': [('Z', math.sin(t + 3 * math.pi / 2) * 8.0)],
            'root': [('move', (0, 0, 0.06 * abs(math.sin(t))))],
            'womb': [('X', math.sin(t * 2) * 4.0)],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'womb': [('move', (0, k * -0.5, 0)), ('X', k * 15.0)],
            'tend1': [('X', k * -20.0)], 'tend2': [('X', k * -20.0)],
            'tend3': [('X', k * -14.0)], 'tend4': [('X', k * -14.0)],
            'root': [('move', (0, k * -0.25, 0))],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0.2 * t, -0.4 * t)), ('X', 14.0 * t)],
            'womb': [('X', -25.0 * t)],
            'tend1': [('Z', 30.0 * t)], 'tend4': [('Z', -30.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.1)


# ============================================================
# 5. ИСКРОПЛЮЙ — парящий электрический угорь (УРОН, rare)
# ============================================================
def build_iskropluy(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 1.5), (0, 0, 1.8)),
        ('seg1', 'root', (0, 0, 1.8), (0, -0.35, 1.95)),
        ('seg2', 'seg1', (0, -0.35, 1.95), (0.1, -0.75, 1.8)),
        ('seg3', 'seg2', (0.1, -0.75, 1.8), (0.35, -1.0, 1.5)),
        ('seg4', 'seg3', (0.35, -1.0, 1.5), (0.7, -1.05, 1.2)),
        ('seg5', 'seg4', (0.7, -1.05, 1.2), (1.0, -0.9, 0.95)),
        ('hornL', 'seg1', (-0.12, -0.4, 2.05), (-0.3, -0.6, 2.45)),
        ('hornR', 'seg1', (0.12, -0.4, 2.05), (0.05, -0.62, 2.5)),
    ]
    arm = make_armature('IskropluyArm', BONES)
    parts = []
    body = mat_simple('is_body', (0.14, 0.16, 0.22))
    belly = mat_simple('is_belly', (0.25, 0.3, 0.4))
    spark = mat_simple('is_spark', (0.3, 0.35, 0.5), (0.4, 0.75, 1.0), 2.8)
    segs = [('seg1', 0.3), ('seg2', 0.34), ('seg3', 0.3), ('seg4', 0.24), ('seg5', 0.16)]
    for i, (sn, r) in enumerate(segs):
        h = bones_head(BONES, sn)
        P(parts, f'seg_{i}', 'sphere', r, h, body if i % 2 == 0 else belly, sn)
    P(parts, 'head', 'sphere', 0.26, (0, 0.12, 1.72), body, 'seg1')
    P(parts, 'jaw', 'cone', (0.1, 0.03, 0.34), (0, -0.15, 1.62), body, 'seg1',
      rot=(math.radians(-70), 0, 0))
    for sx in (-1, 1):
        P(parts, f'eye_{sx}', 'sphere', 0.055, (sx * 0.11, 0.02, 1.8), spark, 'seg1')
    for h in (('hornL', (-0.12, -0.4, 2.05)), ('hornR', (0.12, -0.4, 2.05))):
        pass
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 73, 6):
        t = f / 72 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.12 * math.sin(t)))],
            'seg2': [('X', math.sin(t) * 7.0)], 'seg3': [('X', math.sin(t + 0.8) * 8.0)],
            'seg4': [('X', math.sin(t + 1.6) * 7.0)], 'seg5': [('X', math.sin(t + 2.4) * 9.0)],
            'seg1': [('Y', math.sin(t * 0.7) * 5.0)],
        })
    clips['idle'] = (1, 72)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'root': [('move', (0, -0.3 * math.sin(t), 0.08 * math.sin(t * 2)))],
            'seg2': [('X', math.sin(t) * 10.0)], 'seg3': [('X', math.sin(t + 0.7) * 11.0)],
            'seg4': [('X', math.sin(t + 1.4) * 10.0)], 'seg5': [('X', math.sin(t + 2.1) * 11.0)],
            'seg1': [('Y', math.sin(t) * 4.0)],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'seg1': [('X', k * -18.0)],
            'seg2': [('X', k * -14.0)], 'seg3': [('X', k * -10.0)],
            'hornL': [('Z', k * 20.0)], 'hornR': [('Z', k * -20.0)],
            'root': [('move', (0, k * -0.4, k * 0.15))],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0, -1.0 * t))],
            'seg2': [('X', 20.0 * t)], 'seg3': [('X', -15.0 * t)], 'seg4': [('X', 18.0 * t)],
            'seg5': [('X', -10.0 * t)],
            'seg1': [('Z', 20.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.6)


# ============================================================
# 6. КОСАРЬ — жнец с руками-лезвиями (УРОН, LEGENDARY)
# ============================================================
def build_kosar(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 1.6), (0, 0, 1.9)),
        ('body', 'root', (0, 0, 1.7), (0, 0, 2.5)),
        ('chest', 'body', (0, 0, 2.5), (0, 0, 2.9)),
        ('hood', 'chest', (0, 0, 2.95), (0, 0, 3.25)),
        ('armL', 'chest', (-0.55, 0, 2.75), (-1.25, -0.1, 2.1)),
        ('bladeL', 'armL', (-1.25, -0.1, 2.1), (-1.9, -0.2, 1.1)),
        ('armR', 'chest', (0.55, 0, 2.75), (1.25, 0.1, 2.1)),
        ('bladeR', 'armR', (1.25, 0.1, 2.1), (1.9, 0.2, 1.1)),
        ('legL', 'root', (-0.3, 0, 1.55), (-0.4, 0, 0.75)),
        ('shinL', 'legL', (-0.4, 0, 0.75), (-0.42, 0, 0.05)),
        ('legR', 'root', (0.3, 0, 1.55), (0.4, 0, 0.75)),
        ('shinR', 'legR', (0.4, 0, 0.75), (0.42, 0, 0.05)),
    ]
    arm = make_armature('KosarArm', BONES)
    parts = []
    cloth = mat_simple('ks_cloth', (0.16, 0.15, 0.13))
    cloth2 = mat_simple('ks_cloth2', (0.22, 0.2, 0.16))
    skin = mat_simple('ks_skin', (0.5, 0.48, 0.4))
    steel = mat_simple('ks_steel', (0.75, 0.76, 0.8), (0.4, 0.6, 0.8), 0.8)
    P(parts, 'robe', 'cone', (0.75, 0.45, 1.7), (0, 0, 1.45), cloth, 'root')
    P(parts, 'torso', 'box', (0.55, 0.4, 0.9), (0, 0, 2.35), cloth2, 'body')
    P(parts, 'hood_m', 'cone', (0.4, 0.12, 0.75), (0, 0, 3.05), cloth, 'hood')
    P(parts, 'mask', 'sphere', 0.2, (0, -0.12, 2.95), skin, 'hood')
    # безглазая маска: просто щель
    d_none = None
    P(parts, 'slit', 'box', (0.18, 0.05, 0.03), (0, -0.28, 2.96), skin, 'hood')
    # руки-лезвия: плечо + длинное стальное лезвие
    for sx, up, bl in ((-1, 'armL', 'bladeL'), (1, 'armR', 'bladeR')):
        P(parts, f'shoulder_{sx}', 'sphere', 0.18, (sx * 0.55, 0, 2.72), cloth2, up)
        P(parts, f'arm_{sx}', 'box', (0.14, 0.14, 1.1), (sx * 0.9, -0.05, 2.45), skin, up,
          rot=(0, 0, math.radians(-sx * 12)))
        P(parts, f'blade_{sx}', 'box', (0.09, 0.5, 1.5), (sx * 1.55, -0.14, 1.6), steel, bl,
          rot=(math.radians(-14), 0, math.radians(-sx * 16)))
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 8):
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.06 * math.sin(t)))],
            'body': [('X', math.sin(t) * 2.0)],
            'hood': [('Y', math.sin(t * 0.5) * 5.0)],
            'armL': [('X', math.sin(t) * 3.0)], 'armR': [('X', math.sin(t + math.pi) * 3.0)],
            'legL': [('Y', math.sin(t * 0.5) * 2.0)],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        an.pose(f, {
            'legL': [('X', math.sin(t) * 20.0)], 'legR': [('X', math.sin(t + math.pi) * 20.0)],
            'shinL': [('X', -max(0, math.sin(t + 2.0)) * 18.0)],
            'shinR': [('X', -max(0, math.sin(t + 2.0 + math.pi)) * 18.0)],
            'root': [('move', (0, 0, 0.035 * abs(math.sin(t * 2))))],
            'armL': [('X', math.sin(t + math.pi) * 5.0)], 'armR': [('X', math.sin(t) * 5.0)],
            'hood': [('Y', math.sin(t) * 2.5)],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (8, -1.0), (17, 1.0), (29, 0.0)):
        an.pose(f, {
            'armL': [('Z', k * -55.0), ('X', k * -20.0)],
            'bladeL': [('X', k * -18.0)],
            'armR': [('Z', k * 45.0), ('X', k * -12.0)],
            'bladeR': [('X', k * -12.0)],
            'chest': [('Y', k * -16.0)],
            'hood': [('X', k * -8.0)],
            'root': [('move', (0, k * -0.4, k * 0.08))],
        })
    clips['attack'] = (1, 29)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0.15 * t, -0.7 * t)), ('X', 18.0 * t)],
            'body': [('X', 15.0 * t)],
            'hood': [('X', -22.0 * t)],
            'armL': [('Z', 35.0 * t)], 'armR': [('Z', -25.0 * t)],
            'legL': [('X', 28.0 * t)], 'legR': [('X', 20.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.7)


# ============================================================
# 7. МАЯК — мутант-маяк (БАФ, uncommon)
# ============================================================
def build_mayak(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 0.25), (0, 0, 0.55)),
        ('tower', 'root', (0, 0, 0.55), (0, 0, 2.4)),
        ('lamp', 'tower', (0, 0, 2.4), (0, 0, 2.85)),
    ]
    arm = make_armature('MayakArm', BONES)
    parts = []
    stone = mat_simple('mk_stone', (0.34, 0.36, 0.32))
    stone2 = mat_simple('mk_stone2', (0.28, 0.30, 0.27))
    lens = mat_simple('mk_lens', (0.4, 0.4, 0.35), (1.0, 0.85, 0.4), 3.0)
    P(parts, 'base_r', 'cylinder' if False else 'cone', (0.75, 0.55, 0.5), (0, 0, 0.25), stone, 'root')
    P(parts, 'tower_b', 'cone', (0.55, 0.4, 1.0), (0, 0, 1.0), stone, 'tower')
    P(parts, 'tower_t', 'cone', (0.42, 0.3, 0.95), (0, 0, 1.95), stone2, 'tower')
    for i in range(4):  # окна-щели
        y = 0.85 + i * 0.42
        P(parts, f'win_{i}', 'box', (0.1, 0.08, 0.2), (0.42 - i * 0.04, 0, y), lens, 'tower')
    P(parts, 'lamp_room', 'cylinder' if False else 'sphere', 0.34, (0, 0, 2.6), stone2, 'lamp')
    P(parts, 'lamp_lens', 'sphere', 0.2, (0, -0.22, 2.6), lens, 'lamp')
    P(parts, 'cap', 'cone', (0.3, 0.03, 0.35), (0, 0, 3.0), stone, 'lamp')
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 97, 6):   # прожектор вращается ровно за клип
        t = f / 96 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.03 * math.sin(t)))],
            'tower': [('X', math.sin(t) * 1.2)],
            'lamp': [('Y', 360.0 * (f / 96.0))],
        })
    clips['idle'] = (1, 96)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):   # скольжение-шаг (двигается телепортом рывками)
        t = f / 48 * math.tau
        an.pose(f, {
            'root': [('move', (0, 0, 0.06 * math.sin(t * 2)), )],
            'tower': [('Z', math.sin(t) * 3.0), ('X', math.sin(t * 2) * 1.5)],
            'lamp': [('Y', 360.0 * (f / 48.0))],
        })
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (7, -1.0), (16, 1.0), (28, 0.0)):
        an.pose(f, {
            'lamp': [('X', k * -14.0), ('Y', k * 30.0)],
            'tower': [('X', k * 3.0)],
            'root': [('move', (0, 0, k * 0.1))],
        })
    clips['attack'] = (1, 28)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        an.pose(f, {
            'root': [('move', (0, 0, -0.15 * t))],
            'tower': [('X', 40.0 * t), ('Z', 20.0 * t)],
            'lamp': [('X', -30.0 * t)],
        })
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.5)


# ============================================================
# 8. ХОРОВОД — кольцо трёх фигур (БАФ, LEGENDARY)
# ============================================================
def build_horovod(out_path):
    sc = new_scene()
    BONES = [
        ('root', None, (0, 0, 1.15), (0, 0, 1.4)),
        ('ring', 'root', (0, 0, 1.15), (0, 0, 1.3)),
        ('fig1', 'ring', (0, -0.95, 1.15), (0, -0.95, 1.9)),
        ('fig2', 'ring', (0.82, 0.48, 1.15), (0.82, 0.48, 1.9)),
        ('fig3', 'ring', (-0.82, 0.48, 1.15), (-0.82, 0.48, 1.9)),
    ]
    arm = make_armature('HorovodArm', BONES)
    parts = []
    robe = mat_simple('hd_robe', (0.3, 0.32, 0.4))
    robe2 = mat_simple('hd_robe2', (0.26, 0.28, 0.38))
    eth = mat_simple('hd_eth', (0.35, 0.3, 0.5), (0.55, 0.4, 1.0), 2.4)
    # кольцо-основание: плоский тор из 6 сегментов-боксов
    for i in range(6):
        a = math.tau * i / 6
        P(parts, f'ringseg_{i}', 'box', (0.62, 0.5, 0.22),
          (math.cos(a) * 0.95, math.sin(a) * 0.95, 0.12), robe2, 'ring',
          rot=(0, 0, a))
    # три фигуры: тело + голова + руки
    for i, fig in enumerate(('fig1', 'fig2', 'fig3')):
        a = math.tau * i / 3
        fx, fy = math.cos(a) * 0.95, math.sin(a) * 0.95
        P(parts, f'body_{i}', 'box', (0.44, 0.36, 1.05), (fx, fy, 0.95), robe, fig,
          rot=(0, 0, a))
        P(parts, f'head_{i}', 'sphere', 0.2, (fx, fy, 1.72), robe2, fig)
        P(parts, f'horn_{i}', 'cone', (0.07, 0.02, 0.3), (fx, fy, 2.0), eth, fig)
        for sx in (-1, 1):
            aa = a + math.pi / 2
            ddx = math.cos(aa) * sx * 0.3
            ddy = math.sin(aa) * sx * 0.3
            P(parts, f'arm_{i}_{sx}', 'cone', (0.09, 0.03, 0.6),
              (fx + ddx, fy + ddy, 1.3), robe2, fig,
              rot=(math.radians(-35), 0, aa + math.pi / 2))
    bind_parts(parts, arm)

    an = Anim(arm)
    clips = {}
    an.reset(); an.action('idle')
    for f in range(1, 121, 8):   # 4 с, вращение ровно за клип
        t = f / 120 * math.tau
        spec = {
            'root': [('move', (0, 0, 0.1 * math.sin(t)))],
            'ring': [('Z', 360.0 * (f / 120.0))],
        }
        for i, fig in enumerate(('fig1', 'fig2', 'fig3')):
            spec[fig] = [('X', math.sin(t + i * 2.1) * 4.0)]
        an.pose(f, spec)
    clips['idle'] = (1, 120)
    an.reset(); an.action('walk')
    for f in range(1, 49, 4):
        t = f / 48 * math.tau
        spec = {
            'root': [('move', (0, -0.3 * math.sin(t), 0.08 * abs(math.sin(t * 2)))),
                     ('Z', 360.0 * (f / 48.0) * 1.0)],
        }
        for i, fig in enumerate(('fig1', 'fig2', 'fig3')):
            spec[fig] = [('X', math.sin(t + i * 2.1) * 6.0)]
        an.pose(f, spec)
    clips['walk'] = (1, 48)
    an.reset(); an.action('attack')
    for f, k in ((1, 0.0), (8, -1.0), (18, 1.0), (30, 0.0)):
        spec = {
            'ring': [('Z', k * 60.0)],
            'root': [('move', (0, k * -0.3, k * 0.15))],
        }
        for i, fig in enumerate(('fig1', 'fig2', 'fig3')):
            spec[fig] = [('X', k * -18.0)]
        an.pose(f, spec)
    clips['attack'] = (1, 30)
    an.reset(); an.action('death')
    for f in range(1, 43, 3):
        t = min(1.0, f / 30.0)
        spec = {'root': [('move', (0, 0, -0.75 * t)), ('Z', 30.0 * t)]}
        for i, fig in enumerate(('fig1', 'fig2', 'fig3')):
            spec[fig] = [('X', 30.0 * t), ('Y', (i - 1) * 25.0 * t)]
        an.pose(f, spec)
    clips['death'] = (1, 42)
    export_glb(out_path, arm)
    return arm, clips, (0, 0, 1.2)


BONES_DATA = {}   # сохраняем спеки для справки


def bones_head(bones, name):
    for n, p, h, t in bones:
        if n == name:
            return h
    return (0, 0, 0)


BUILDERS = {
    'kremen': build_kremen, 'rzhavnik': build_rzhavnik, 'sporonosets': build_sporonosets,
    'chrevo': build_chrevo, 'iskropluy': build_iskropluy, 'kosar': build_kosar,
    'mayak': build_mayak, 'horovod': build_horovod,
}

if __name__ == '__main__':
    for name, fn in BUILDERS.items():
        arm, clips, center = fn(os.path.join(MODELS, f'{name}.glb'))
        print(f'{name}: клипов {len(clips)}')
