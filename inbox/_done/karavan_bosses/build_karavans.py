# -*- coding: utf-8 -*-
# ЗАДАЧА 44: три каравана-босса кампании. Процедурный boss_kit (з.41),
# клипы idle/walk/attack/death, масштаб в метрах, origin в «лапах» (Z=0).
import os
import sys
import math

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boss_kit import (new_scene, make_armature, mat_simple, add_part,
                      bind_parts, Anim, export_glb, render_clips)

HERE = r'E:\StalkerRevert\StalkerRevert\inbox\karavan_bosses'
OUT = os.path.join(HERE, 'models')
os.makedirs(OUT, exist_ok=True)
CHECK = os.path.join(HERE, 'check')
os.makedirs(CHECK, exist_ok=True)

TAU = math.tau
FPS = 30


def make_mats():
    # палитра (после new_scene! read_factory_settings стирает данные)
    global STEEL, STEEL2, RUST, RUST_D, OLIVE, GUN, GLASS, LIGHT, ART_G, ART_A, ART_B, MOSS, TRACK
    n = lambda r, g, b: (r / 255.0, g / 255.0, b / 255.0)  # Blender 0..1!
    STEEL = mat_simple('steel', n(58, 56, 52))
    STEEL2 = mat_simple('steel2', n(78, 76, 70))
    RUST = mat_simple('rust', n(130, 74, 38))
    RUST_D = mat_simple('rust_d', n(96, 54, 28))
    OLIVE = mat_simple('olive', n(78, 88, 60))
    GUN = mat_simple('gun', n(44, 46, 44))
    GLASS = mat_simple('glass', n(22, 28, 26))
    LIGHT = mat_simple('light', n(255, 214, 120), emission=n(255, 190, 90), estrength=1.5)
    ART_G = mat_simple('art_g', n(150, 255, 130), emission=n(120, 255, 100), estrength=2.0)
    ART_A = mat_simple('art_a', n(255, 190, 90), emission=n(255, 170, 60), estrength=2.0)
    ART_B = mat_simple('art_b', n(120, 210, 255), emission=n(90, 190, 255), estrength=2.0)
    MOSS = mat_simple('moss', n(88, 108, 58))
    TRACK = mat_simple('track', n(36, 38, 36))


def box(name, size, loc, mat, bone, rot=(0, 0, 0)):
    return add_part(name, 'box', size, loc, mat, bone, rot)


def swing(an, f, spec, legs, amp, period, phase_map):
    """Синус-качание костей: deg = amp*sin(tau*f/period + phase)."""
    for bone, phase in phase_map.items():
        spec[bone] = [('X', amp * math.sin(TAU * f / period + phase))]


# ==================== 1. ГРУЗОВИК КАРАВАНА (~5 м) ====================
def build_gruz():
    new_scene()
    make_mats()
    bones = [
        ('root', None, (0, 0, 0.9), (0, 0, 1.0)),
        ('body', 'root', (0, 0, 1.35), (0, 0, 1.75)),
        ('cab', 'body', (0, -1.35, 1.9), (0, -1.35, 2.4)),
        ('gun', 'cab', (0, -2.0, 1.55), (0, -2.7, 1.55)),
        ('cage', 'body', (0, 0.9, 1.75), (0, 0.9, 2.45)),
        ('cargo', 'cage', (0, 0.9, 2.0), (0, 0.9, 2.3)),
        ('hip_fl', 'body', (-0.95, -1.35, 1.15), (-0.95, -1.35, 0.6)),
        ('foot_fl', 'hip_fl', (-0.95, -1.35, 0.6), (-0.95, -1.35, 0.05)),
        ('hip_fr', 'body', (0.95, -1.35, 1.15), (0.95, -1.35, 0.6)),
        ('foot_fr', 'hip_fr', (0.95, -1.35, 0.6), (0.95, -1.35, 0.05)),
        ('hip_bl', 'body', (-0.95, 1.45, 1.15), (-0.95, 1.45, 0.6)),
        ('foot_bl', 'hip_bl', (-0.95, 1.45, 0.6), (-0.95, 1.45, 0.05)),
        ('hip_br', 'body', (0.95, 1.45, 1.15), (0.95, 1.45, 0.6)),
        ('foot_br', 'hip_br', (0.95, 1.45, 0.6), (0.95, 1.45, 0.05)),
    ]
    arm = make_armature('gruz_rig', bones)
    p = []
    # шасси
    p.append(box('chassis', (1.9, 4.4, 0.4), (0, 0.05, 1.2), STEEL, 'body'))
    p.append(box('skirt_l', (0.12, 3.2, 0.5), (-1.0, 0.05, 1.0), RUST_D, 'body'))
    p.append(box('skirt_r', (0.12, 3.2, 0.5), (1.0, 0.05, 1.0), RUST_D, 'body'))
    # бронекабина со скошенной nosой плитой
    p.append(box('cab_main', (1.95, 1.6, 1.1), (0, -1.35, 2.0), OLIVE, 'cab'))
    p.append(box('cab_nose', (1.8, 0.5, 0.7), (0, -2.2, 1.75), OLIVE, 'cab', rot=(0.5, 0, 0)))
    p.append(box('windshield', (1.5, 0.1, 0.4), (0, -2.16, 2.25), GLASS, 'cab', rot=(0.5, 0, 0)))
    p.append(box('roof', (2.0, 1.7, 0.12), (0, -1.35, 2.6), STEEL2, 'cab'))
    p.append(box('bullbar', (1.9, 0.25, 0.6), (0, -2.5, 1.25), RUST, 'cab'))
    p.append(box('hl_l', (0.3, 0.1, 0.2), (-0.6, -2.22, 1.55), LIGHT, 'cab'))
    p.append(box('hl_r', (0.3, 0.1, 0.2), (0.6, -2.22, 1.55), LIGHT, 'cab'))
    p.append(box('exhaust', (0.18, 0.18, 0.9), (0.75, -0.6, 2.8), RUST_D, 'cab'))
    # пулемёт на носу
    p.append(box('gun_base', (0.4, 0.4, 0.3), (0, -2.45, 1.65), GUN, 'gun'))
    p.append(box('gun_barrel', (0.14, 0.9, 0.14), (0, -2.9, 1.7), GUN, 'gun'))
    # кузов-клетка
    cx, cy, cz = 0, 0.9, 2.05
    for sx in (-0.85, 0.85):
        for sy in (-0.95, 0.95):
            p.append(box(f'post_{sx}_{sy}', (0.1, 0.1, 1.5), (sx, cy + sy, cz + 0.45), RUST, 'cage'))
    for i in range(4):
        yy = cy - 0.95 + i * 0.63
        p.append(box(f'bar_l_{i}', (0.06, 0.06, 1.5), (-0.85, yy, cz + 0.45), RUST_D, 'cage'))
        p.append(box(f'bar_r_{i}', (0.06, 0.06, 1.5), (0.85, yy, cz + 0.45), RUST_D, 'cage'))
    p.append(box('cage_roof', (1.8, 2.0, 0.08), (cx, cy, cz + 1.2), RUST, 'cage'))
    p.append(box('cage_floor', (1.8, 2.0, 0.1), (cx, cy, cz - 0.3), STEEL, 'cage'))
    # артефакты в клетке
    p.append(box('art1', (0.3, 0.3, 0.3), (-0.4, cy - 0.3, cz + 0.05), ART_G, 'cargo', rot=(0.3, 0.4, 0)))
    p.append(box('art2', (0.26, 0.26, 0.34), (0.35, cy + 0.2, cz + 0.02), ART_A, 'cargo', rot=(0.5, 0, 0.3)))
    p.append(box('art3', (0.32, 0.24, 0.26), (0.1, cy - 0.55, cz + 0.0), ART_B, 'cargo', rot=(0, 0.5, 0.2)))
    # лапы: бедро + голень + ступня
    for tag, y in (('fl', -1.35), ('fr', -1.35), ('bl', 1.45), ('br', 1.45)):
        sx = -0.95 if 'l' in tag else 0.95
        p.append(box(f'thigh_{tag}', (0.42, 0.5, 0.75), (sx, y, 0.88), RUST_D, f'hip_{tag}'))
        p.append(box(f'shin_{tag}', (0.34, 0.4, 0.7), (sx, y, 0.33), RUST, f'foot_{tag}'))
        p.append(box(f'paw_{tag}', (0.55, 0.62, 0.16), (sx, y + 0.03, 0.08), GUN, f'foot_{tag}'))
    bind_parts(p, arm)
    return arm


def clips_gruz(arm):
    an = Anim(arm)
    LEGS = {'hip_fl': 0.0, 'hip_fr': math.pi, 'hip_bl': math.pi, 'hip_br': 0.0,
            'foot_fl': 0.0, 'foot_fr': math.pi, 'foot_bl': math.pi, 'foot_br': 0.0}

    def mk(name, frames, per_frame):
        an.reset()
        an.action(name)
        for f in range(frames):
            an.pose(f, per_frame(f))
        print('  clip', name, frames)

    # idle: двигатель дрожит, клетка гремит, пулемёт сканирует
    def idle(f):
        s = {
            'body': [('X', 0.8 * math.sin(TAU * f / 36)), ('Z', 0.5 * math.sin(TAU * f / 72 + 1)),
                     ('move', (0, 0, 0.015 * math.sin(TAU * f / 36)))],
            'cage': [('X', 0.9 * math.sin(TAU * f / 24 + 0.7))],
            'cargo': [('Z', 2.0 * math.sin(TAU * f / 30))],
            'gun': [('Y', 7.0 * math.sin(TAU * f / 72))],
        }
        return s
    mk('idle', 72, idle)

    # walk: тяжёлый шаг, корнус качается
    def walk(f):
        s = {}
        for bone, ph in LEGS.items():
            amp = 24 if bone.startswith('hip') else 16
            s[bone] = [('X', amp * math.sin(TAU * f / 72 + ph))]
        s['body'] = [('X', 2.0 * math.sin(TAU * f / 72)),
                     ('Z', 1.2 * math.sin(TAU * f / 36)),
                     ('move', (0, 0, 0.06 * math.sin(TAU * f / 36)))]
        s['cab'] = [('X', 1.5 * math.sin(TAU * f / 72 + 0.5))]
        s['cage'] = [('X', 2.2 * math.sin(TAU * f / 36 + 0.9))]
        return s
    mk('walk', 72, walk)

    # attack: таран — привстал и ударил вниз с выстрелом
    def attack(f):
        t = f / 60.0
        if t < 0.35:
            lift = -9.0 * (t / 0.35)
        elif t < 0.62:
            lift = -9.0 + 14.0 * ((t - 0.35) / 0.27)
        else:
            lift = 5.0 - 5.0 * ((t - 0.62) / 0.38)
        s = {'root': [('X', lift)],
             'root2m': [('move', (0, -0.9 * math.sin(min(1.0, t * 1.6) * math.pi), 0))]}
        # рывок вперёд через body (root фиксирован у игры) — дублируем на body
        s['body'] = [('move', (0, -0.8 * math.sin(min(1.0, t * 1.5) * math.pi), 0)),
                     ('X', lift * 0.4)]
        rec = -26.0 * math.exp(-((t - 0.55) ** 2) / 0.004) if t > 0.4 else 0.0
        s['gun'] = [('X', rec)]
        for bone, ph in LEGS.items():
            amp = 10 if bone.startswith('hip') else 6
            s[bone] = [('X', amp * math.sin(TAU * f / 60 + ph))]
        s.pop('root2m')
        return s
    mk('attack', 60, attack)

    # death: лапы подкашиваются, туша валится на бок, артефакты сыплются
    def death(f):
        t = f / 54.0
        s = {}
        drop = min(1.0, t * 1.4)
        s['root'] = [('move', (0, 0, -0.75 * drop))]
        s['body'] = [('X', 6.0 * drop), ('Z', 22.0 * drop * drop)]
        for i, (bone, _) in enumerate(LEGS.items()):
            buck = 55.0 * drop if bone.startswith('hip') else -30.0 * drop
            s[bone] = [('X', buck), ('Z', 14.0 * drop * (1 if i % 2 else -1))]
        s['cage'] = [('X', 12.0 * drop), ('Z', 10.0 * drop)]
        s['cargo'] = [('move', (0.2 * drop, 0.1 * drop, 0.25 * math.sin(min(1, t * 2) * math.pi) - 0.1 * drop))]
        s['gun'] = [('X', -18.0 * drop)]
        return s
    mk('death', 54, death)
    return {'idle': (0, 72), 'walk': (0, 72), 'attack': (0, 60), 'death': (0, 54)}


# ==================== 2. БРОНЕКОЛОННА (~6 м) ====================
def build_kolonna():
    new_scene()
    make_mats()
    bones = [
        ('root', None, (0, 0, 0.9), (0, 0, 1.0)),
        ('seg1', 'root', (0, -2.0, 1.35), (0, -2.0, 1.6)),
        ('seg2', 'root', (0, 0.0, 1.35), (0, 0.0, 1.6)),
        ('seg3', 'root', (0, 2.0, 1.35), (0, 2.0, 1.6)),
        ('turret', 'seg1', (0, -2.05, 2.0), (0, -2.05, 2.3)),
        ('barrel', 'turret', (0, -2.05, 2.15), (0, -3.3, 2.15)),
    ]
    for si, sy in enumerate((-2.0, 0.0, 2.0), start=1):
        for li, ly in enumerate((-0.55, 0.55)):
            for sx in (-1.05, 1.05):
                tag = f's{si}{"l" if sx < 0 else "r"}{li}'
                bones.append((f'leg_{tag}', f'seg{si}',
                              (sx, sy + ly, 1.1), (sx, sy + ly + 0.08, 0.55)))
                bones.append((f'paw_{tag}', f'leg_{tag}',
                              (sx, sy + ly + 0.08, 0.55), (sx, sy + ly + 0.12, 0.05)))
    arm = make_armature('kolonna_rig', bones)
    p = []
    for si, sy in enumerate((-2.0, 0.0, 2.0), start=1):
        p.append(box(f'segbox{si}', (1.95, 1.75, 1.05), (0, sy, 1.5), OLIVE if si != 2 else STEEL2, f'seg{si}'))
        p.append(box(f'lid{si}', (1.7, 1.5, 0.14), (0, sy, 2.06), STEEL2, f'seg{si}'))
        p.append(box(f'hatch{si}', (0.55, 0.55, 0.12), (0.3, sy + 0.2, 2.16), RUST, f'seg{si}'))
        p.append(box(f'skirtl{si}', (0.14, 1.8, 0.45), (-1.0, sy, 1.05), RUST_D, f'seg{si}'))
        p.append(box(f'skirtr{si}', (0.14, 1.8, 0.45), (1.0, sy, 1.05), RUST_D, f'seg{si}'))
        p.append(box(f'moss{si}', (1.4, 0.5, 0.1), (0, sy + 0.5, 2.14), MOSS, f'seg{si}'))
    # гармошки-сцепки
    for sy in (-1.0, 1.0):
        p.append(box(f'bellows_{sy}', (1.3, 0.5, 0.85), (0, sy, 1.5), RUST_D, 'root'))
        p.append(box(f'couple_{sy}', (0.3, 0.3, 0.3), (0, sy, 1.15), GUN, 'root'))
    # головная секция: клин + башня-пушка + фары
    p.append(box('nose', (1.8, 0.7, 0.8), (0, -3.1, 1.55), OLIVE, 'seg1', rot=(0.35, 0, 0)))
    p.append(box('turret_base', (1.0, 1.0, 0.45), (0, -2.05, 2.2), GUN, 'turret'))
    p.append(box('turret_top', (0.8, 0.8, 0.25), (0, -2.05, 2.5), STEEL2, 'turret'))
    p.append(box('barrel_part', (0.22, 1.5, 0.22), (0, -3.0, 2.28), GUN, 'barrel'))
    p.append(box('muzzle', (0.3, 0.25, 0.3), (0, -3.8, 2.28), RUST_D, 'barrel'))
    p.append(box('hl_l', (0.28, 0.1, 0.2), (-0.55, -3.42, 1.5), LIGHT, 'seg1'))
    p.append(box('hl_r', (0.28, 0.1, 0.2), (0.55, -3.42, 1.5), LIGHT, 'seg1'))
    # корма: выхлоп
    p.append(box('stack', (0.22, 0.22, 1.0), (0.6, 2.85, 2.4), RUST_D, 'seg3'))
    # лапы: бедро-голень + ступня-лыжа
    for si, sy in enumerate((-2.0, 0.0, 2.0), start=1):
        for li, ly in enumerate((-0.55, 0.55)):
            for sx in (-1.05, 1.05):
                tag = f's{si}{"l" if sx < 0 else "r"}{li}'
                p.append(box(f'thigh_{tag}', (0.3, 0.42, 0.62), (sx, sy + ly, 0.82), RUST_D, f'leg_{tag}'))
                p.append(box(f'ski_{tag}', (0.4, 0.62, 0.14), (sx, sy + ly + 0.1, 0.08), GUN, f'paw_{tag}'))
    bind_parts(p, arm)
    return arm


def clips_kolonna(arm):
    an = Anim(arm)
    # фазы лап: метахрональная волна по Y
    LEG_PHASE = {}
    for si, sy in enumerate((-2.0, 0.0, 2.0), start=1):
        for li, ly in enumerate((-0.55, 0.55)):
            for sx in (-1.05, 1.05):
                side = -1 if sx < 0 else 1
                tag = f's{si}{"l" if sx < 0 else "r"}{li}'
                LEG_PHASE[(f'leg_{tag}', f'paw_{tag}')] = (sy * 0.9, side)

    def mk(name, frames, per_frame):
        an.reset()
        an.action(name)
        for f in range(frames):
            an.pose(f, per_frame(f))
        print('  clip', name, frames)

    def idle(f):
        s = {'turret': [('Y', 9.0 * math.sin(TAU * f / 90))],
             'barrel': [('X', 2.0 * math.sin(TAU * f / 45))]}
        for si in range(1, 4):
            s[f'seg{si}'] = [('X', 0.9 * math.sin(TAU * f / 36 + si * 2.1))]
        for (leg, paw), (ph, side) in LEG_PHASE.items():
            s[leg] = [('X', 3.0 * math.sin(TAU * f / 36 + ph))]
        return s
    mk('idle', 72, idle)

    def walk(f):
        s = {}
        for (leg, paw), (ph, side) in LEG_PHASE.items():
            s[leg] = [('X', 20.0 * math.sin(TAU * f / 60 + ph * side))]
            s[paw] = [('X', 12.0 * math.sin(TAU * f / 60 + ph * side + 0.8))]
        for si in range(1, 4):
            s[f'seg{si}'] = [('X', 2.4 * math.sin(TAU * f / 30 + si * 2.1)),
                             ('Z', 1.4 * math.sin(TAU * f / 60 + si * 1.05))]
        s['root'] = [('move', (0, 0, 0.045 * math.sin(TAU * f / 30)))]
        s['turret'] = [('X', 1.5 * math.sin(TAU * f / 60))]
        return s
    mk('walk', 60, walk)

    def attack(f):
        t = f / 60.0
        s = {}
        s['body0'] = None
        rec = -24.0 * math.exp(-((t - 0.5) ** 2) / 0.005) if t > 0.35 else 0.0
        s['barrel'] = [('X', rec)]
        s['turret'] = [('X', rec * 0.3)]
        lunge = math.sin(min(1.0, t * 1.5) * math.pi) * 0.9
        s['seg1'] = [('move', (0, -lunge, 0)), ('X', 4.0 * math.sin(t * math.pi))]
        s['seg2'] = [('move', (0, -lunge * 0.5, 0))]
        s['seg3'] = [('move', (0, -lunge * 0.25, 0))]
        for (leg, paw), (ph, side) in LEG_PHASE.items():
            s[leg] = [('X', 12.0 * math.sin(TAU * f / 60 + ph * side))]
        s.pop('body0')
        return s
    mk('attack', 60, attack)

    def death(f):
        t = f / 60.0
        s = {}
        drop = min(1.0, t * 1.3)
        s['root'] = [('move', (0, 0, -0.85 * drop))]
        for si in range(1, 4):
            s[f'seg{si}'] = [('X', (18.0 if si % 2 else -14.0) * drop),
                             ('Z', 9.0 * drop * (1 if si != 2 else -1))]
        for (leg, paw), (ph, side) in LEG_PHASE.items():
            s[leg] = [('X', 60.0 * drop * side, )]
            s[paw] = [('X', -35.0 * drop)]
        s['turret'] = [('X', -16.0 * drop), ('Z', 14.0 * drop)]
        s['barrel'] = [('X', -22.0 * drop)]
        return s
    mk('death', 60, death)
    return {'idle': (0, 72), 'walk': (0, 60), 'attack': (0, 60), 'death': (0, 60)}


# ==================== 3. ЦАРЬ-КАРАВАН (~8 м) ====================
def build_tsar():
    new_scene()
    make_mats()
    bones = [('root', None, (0, 0, 1.3), (0, 0, 1.5))]
    WY = [-3.2, -1.6, 0.0, 1.6, 3.2]
    for wi in range(5):
        bones.append((f'w{wi + 1}', 'root', (0, WY[wi], 1.55), (0, WY[wi], 1.75)))
    bones += [
        ('tur_f', 'w1', (0, -3.3, 2.3), (0, -3.3, 2.6)),
        ('bar_f', 'tur_f', (0, -3.3, 2.5), (0, -4.5, 2.5)),
        ('tur_m', 'w3', (0, 0.0, 2.45), (0, 0.0, 2.75)),
        ('bar_m', 'tur_m', (0, 0.0, 2.68), (0, -1.1, 2.68)),
        ('tur_r', 'w5', (0, 3.2, 2.3), (0, 3.2, 2.6)),
        ('bar_r', 'tur_r', (0, 3.3, 2.5), (0, 4.5, 2.5)),
    ]
    arm = make_armature('tsar_rig', bones)
    p = []
    for wi, wy in enumerate(WY, start=1):
        b = f'w{wi}'
        p.append(box(f'wagon{wi}', (2.3, 1.55, 1.35), (0, wy, 1.85), OLIVE if wi % 2 else STEEL2, b))
        p.append(box(f'roof{wi}', (2.35, 1.6, 0.12), (0, wy, 2.6), STEEL, b))
        # ряд окон-щелей
        p.append(box(f'win{wi}', (2.34, 1.0, 0.22), (0, wy, 2.15), GLASS, b))
        # юбка-гусеница с катками
        p.append(box(f'track{wi}', (2.5, 1.65, 0.5), (0, wy, 0.95), TRACK, b))
        for k in range(3):
            p.append(box(f'wheel{wi}_{k}', (2.0, 0.28, 0.34), (0, wy - 0.5 + k * 0.5, 0.8), GUN, b))
        p.append(box(f'rust{wi}', (1.6, 0.4, 0.12), (0.2, wy + 0.4, 2.66), RUST_D, b))
        if wi < 5:
            p.append(box(f'coup{wi}', (1.4, 0.35, 0.8), (0, wy + 0.78, 1.8), RUST_D, b))
    # нос: скос, прожектор, отбойник-плуг
    p.append(box('nose', (2.2, 0.8, 1.1), (0, -4.15, 1.8), OLIVE, 'w1', rot=(0.3, 0, 0)))
    p.append(box('plow', (2.3, 0.5, 0.7), (0, -4.45, 1.0), RUST, 'w1', rot=(0.4, 0, 0)))
    p.append(box('headlight', (0.6, 0.14, 0.35), (0, -4.5, 2.35), LIGHT, 'w1'))
    p.append(box('light2', (0.3, 0.12, 0.22), (-0.8, -4.4, 1.5), LIGHT, 'w1'))
    p.append(box('light3', (0.3, 0.12, 0.22), (0.8, -4.4, 1.5), LIGHT, 'w1'))
    # три башни: база + ствол (боковая смотрит вбок)
    for tag, wy, sy in (('f', -3.3, 0), ('m', 0.0, 0), ('r', 3.3, 0)):
        p.append(box(f'tb_{tag}', (1.15, 1.15, 0.5), (0, wy + sy, 2.85 if tag == 'm' else 2.72), GUN, f'tur_{tag}'))
        p.append(box(f'tt_{tag}', (0.9, 0.9, 0.28), (0, wy + sy, (3.12 if tag == 'm' else 2.99)), STEEL2, f'tur_{tag}'))
        p.append(box(f'br_{tag}', (0.26, 1.6, 0.26), (0, wy + sy + (-1.0 if tag != 'r' else 1.0),
                                                      (2.95 if tag == 'm' else 2.82)), GUN, f'bar_{tag}'))
    # мох и ржавчина по борту
    p.append(box('moss1', (2.0, 0.6, 0.1), (-0.3, -1.0, 2.62), MOSS, 'w2'))
    p.append(box('moss2', (1.4, 0.5, 0.1), (0.4, 2.2, 2.62), MOSS, 'w4'))
    bind_parts(p, arm)
    return arm


def clips_tsar(arm):
    an = Anim(arm)
    TUR = [('tur_f', 'bar_f', 0.0), ('tur_m', 'bar_m', 2.1), ('tur_r', 'bar_r', 4.2)]

    def mk(name, frames, per_frame):
        an.reset()
        an.action(name)
        for f in range(frames):
            an.pose(f, per_frame(f))
        print('  clip', name, frames)

    def idle(f):
        s = {}
        for wi in range(1, 6):
            s[f'w{wi}'] = [('X', 0.7 * math.sin(TAU * f / 36 + wi * 1.3)),
                           ('move', (0, 0, 0.012 * math.sin(TAU * f / 36 + wi * 1.3)))]
        for tur, bar, ph in TUR:
            s[tur] = [('Y', 8.0 * math.sin(TAU * f / 90 + ph))]
            s[bar] = [('X', 1.6 * math.sin(TAU * f / 45 + ph))]
        return s
    mk('idle', 90, idle)

    def walk(f):
        s = {}
        for wi in range(1, 6):
            s[f'w{wi}'] = [('X', 2.0 * math.sin(TAU * f / 48 + wi * 1.05)),
                           ('Z', 1.1 * math.sin(TAU * f / 24 + wi * 2.1)),
                           ('move', (0, 0, 0.035 * math.sin(TAU * f / 24 + wi * 2.1)))]
        s['root'] = [('move', (0, 0, 0.04 * math.sin(TAU * f / 24)))]
        for tur, bar, ph in TUR:
            s[tur] = [('X', 1.2 * math.sin(TAU * f / 48 + ph))]
        return s
    mk('walk', 48, walk)

    def attack(f):
        # залп трёх башен с интервалом
        s = {}
        for k, (tur, bar, ph) in enumerate(TUR):
            t0 = 0.25 + k * 0.18
            rec = -22.0 * math.exp(-((f / 72.0 - t0) ** 2) / 0.0022) if f / 72.0 > t0 - 0.15 else 0.0
            s[tur] = [('X', rec * 0.25)]
            s[bar] = [('X', rec)]
        brace = -2.5 * math.sin(min(1.0, f / 72.0) * math.pi)
        s['root'] = [('X', brace)]
        for wi in range(1, 6):
            s[f'w{wi}'] = [('X', 1.2 * math.sin(TAU * f / 36 + wi))]
        return s
    mk('attack', 72, attack)

    def death(f):
        t = f / 66.0
        s = {}
        drop = min(1.0, t * 1.25)
        s['root'] = [('move', (0, 0, -0.7 * drop)), ('X', 2.5 * drop)]
        for wi in range(1, 6):
            tilt = 5.0 * (1 if wi % 2 else -1)
            s[f'w{wi}'] = [('Z', tilt * drop), ('X', (10.0 if wi < 3 else -6.0) * drop),
                           ('move', (0, 0, -0.1 * drop * wi))]
        for tur, bar, ph in TUR:
            s[tur] = [('X', -14.0 * drop), ('Z', 10.0 * drop * (1 if ph < 3 else -1))]
            s[bar] = [('X', -20.0 * drop)]
        return s
    mk('death', 66, death)
    return {'idle': (0, 90), 'walk': (0, 48), 'attack': (0, 72), 'death': (0, 66)}


if __name__ == '__main__':
    JOBS = [
        ('karavan_gruz', build_gruz, clips_gruz, (0, 0, 1.6), (7.5, -9.0, 4.5)),
        ('karavan_bronekolonna', build_kolonna, clips_kolonna, (0, -0.5, 1.7), (8.0, -10.5, 5.0)),
        ('karavan_tsar', build_tsar, clips_tsar, (0, 0, 2.0), (10.0, -13.0, 6.0)),
    ]
    for name, builder, clipper, center, cam in JOBS:
        print('BUILD', name)
        arm = builder()
        clips = clipper(arm)
        export_glb(os.path.join(OUT, name + '_anim.glb'), arm)
        render_clips(CHECK, arm, clips, center, cam, prefix=name + '_')
    print('ALL KARAVANS DONE')
