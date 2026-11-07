# -*- coding: utf-8 -*-
# 8 HUD-иконок новых мутантов (96px, стиль ability_icons з.23) +
# 4 бейджа ролей пачек (64px, стиль pack_icons з.37).
import math
import os
import sys

sys.path.insert(0, r'E:\StalkerRevert\StalkerRevert\inbox\_done\ability_icons')
import gen_ability_icons as G  # plate/glow/L/eye, C=48, S=96

import numpy as np
from PIL import Image, ImageDraw

OUT_ICONS = r'E:\StalkerRevert\StalkerRevert\inbox\mutant_hud_icons_8\mutant'
OUT_BADGES = r'E:\StalkerRevert\StalkerRevert\inbox\pack_role_badges'
os.makedirs(OUT_ICONS, exist_ok=True)
os.makedirs(OUT_BADGES, exist_ok=True)

C = G.C


# ---------------- глифы 8 мутантов (вид «голова/силуэт», как у старых) ----------------
def kremen(d, img):
    G.glow(d, C, 50, 32, (150, 160, 100), 45)
    # купол-панцирь
    d.pieslice([C - 30, 18, C + 30, 74], 180, 360, fill=(104, 108, 96, 255),
               outline=(58, 62, 52, 255))
    # мшистые пятна
    d.ellipse([C - 18, 28, C - 6, 38], fill=(120, 140, 90, 200))
    d.ellipse([C + 8, 24, C + 20, 32], fill=(120, 140, 90, 180))
    # голова-таран
    d.ellipse([C - 10, 56, C + 10, 76], fill=(92, 96, 84, 255), outline=(58, 62, 52, 255))
    G.eye(d, C - 5, 65, 2.5, (255, 190, 90))
    G.eye(d, C + 5, 65, 2.5, (255, 190, 90))
    # лапы
    for dx in (-22, 22):
        d.rounded_rectangle([C + dx - 7, 62, C + dx + 7, 78], radius=4,
                            fill=(88, 92, 80, 255), outline=(58, 62, 52, 255))


def rzhavnik(d, img):
    G.glow(d, C, 48, 32, (230, 120, 60), 45)
    # паучьи ноги-трубы
    for (dx, dy) in [(-24, 66), (24, 66), (-12, 74), (12, 74)]:
        d.line([C + dx * 0.55, 54, C + dx, dy], fill=(120, 74, 44, 255), width=5)
    # корпус из сваренных листов
    d.ellipse([C - 26, 30, C + 26, 66], fill=(150, 92, 52, 255), outline=(86, 50, 28, 255))
    d.arc([C - 18, 34, C + 2, 62], 200, 340, fill=(86, 50, 28, 255), width=2)
    d.arc([C + 0, 34, C + 20, 60], 200, 340, fill=(86, 50, 28, 255), width=2)
    # линза-глаз
    d.ellipse([C - 9, 42, C + 9, 58], fill=(30, 26, 22, 255), outline=(255, 150, 50, 255))
    d.ellipse([C - 5, 46, C + 5, 54], fill=(255, 150, 50, 255))
    # клешни-ковши
    for sx in (-1, 1):
        d.polygon([(C + sx * 20, 40), (C + sx * 40, 30), (C + sx * 44, 52), (C + sx * 28, 56)],
                  fill=(130, 80, 46, 255), outline=(86, 50, 28, 255))
    # антенна
    d.line([C + 6, 30, C + 14, 14], fill=(86, 50, 28, 255), width=2)
    d.ellipse([C + 12, 10, C + 16, 14], fill=(255, 150, 50, 255))


def sporonosets(d, img):
    G.glow(d, C, 44, 32, (126, 200, 80), 55)
    # ножка
    d.polygon([(C - 10, 78), (C + 10, 78), (C + 6, 46), (C - 6, 46)],
              fill=(214, 206, 178, 255), outline=(140, 132, 104, 255))
    # шляпка-купол
    d.pieslice([C - 30, 20, C + 30, 64], 180, 360, fill=(96, 142, 72, 255),
               outline=(54, 84, 42, 255))
    # светящиеся лозы
    for (x0, x1) in [(-20, -26), (-8, -12), (6, 10), (20, 24)]:
        d.line([C + x0, 42, C + x1, 70], fill=(126, 200, 80, 220), width=3)
        d.ellipse([C + x1 - 2, 68, C + x1 + 2, 72], fill=(170, 255, 120, 255))
    # споры
    for (sx, sy) in [(-26, 30), (24, 26), (0, 14), (-14, 16), (14, 32)]:
        d.ellipse([C + sx - 2, sy - 2, C + sx + 2, sy + 2], fill=(190, 255, 140, 230))


def chrevo(d, img):
    G.glow(d, C, 48, 34, (220, 70, 110), 55)
    # тело-курган
    d.ellipse([C - 28, 30, C + 28, 78], fill=(176, 62, 96, 255), outline=(110, 36, 62, 255))
    # соцветие-ядро
    G.glow(d, C, 44, 10, (255, 190, 90), 60)
    d.ellipse([C - 9, 36, C + 9, 54], fill=(255, 190, 90, 255), outline=(160, 100, 30, 255))
    # щупальца-опоры
    for (x0, x1, y1) in [(-24, -34, 72), (-10, -14, 80), (12, 18, 80), (26, 36, 72)]:
        d.line([C + x0, 62, C + x1, y1], fill=(150, 48, 80, 255), width=5)
        d.ellipse([C + x1 - 3, y1 - 3, C + x1 + 3, y1 + 3], fill=(220, 90, 120, 255))
    # бугорки
    for (bx, by) in [(-18, 40), (18, 42), (-6, 68), (10, 66)]:
        d.ellipse([C + bx - 3, by - 3, C + bx + 3, by + 3], fill=(210, 100, 130, 220))


def iskropluy(d, img):
    G.glow(d, C, 48, 34, G.ELEC, 60)
    # S-изгиб тела
    pts = [(C - 30, 62), (C - 14, 46), (C + 2, 58), (C + 18, 40), (C + 30, 28)]
    d.line(pts, fill=(40, 46, 40, 255), width=13)
    d.line(pts, fill=(70, 90, 70, 255), width=9)
    for (px, py) in pts[1:-1]:
        d.line([px - 4, py + 5, px + 2, py - 5], fill=(30, 34, 30, 255), width=2)
    # голова + рога-разрядники
    d.ellipse([C + 22, 18, C + 38, 34], fill=(46, 52, 46, 255), outline=(24, 28, 24, 255))
    G.eye(d, C + 31, 25, 2.5, (140, 220, 255))
    d.line([C + 26, 19, C + 18, 8], fill=(40, 46, 40, 255), width=3)
    d.line([C + 34, 19, C + 40, 8], fill=(40, 46, 40, 255), width=3)
    # искра между рогами
    d.polygon([(C + 24, 12), (C + 30, 4), (C + 28, 12), (C + 36, 6)],
              fill=(160, 230, 255, 255))
    # разряды вдоль тела
    d.line([C - 6, 50, C - 12, 40], fill=(120, 200, 255, 220), width=2)
    d.line([C + 12, 46, C + 20, 52], fill=(120, 200, 255, 200), width=2)


def kosar(d, img):
    G.glow(d, C, 46, 32, G.ASHC, 45)
    # плащ
    d.polygon([(C - 18, 26), (C + 18, 26), (C + 24, 78), (C - 24, 78)],
              fill=(84, 88, 92, 255), outline=(48, 50, 54, 255))
    # капюшон и маска
    d.ellipse([C - 12, 16, C + 12, 42], fill=(64, 66, 70, 255), outline=(44, 46, 50, 255))
    d.ellipse([C - 7, 24, C + 7, 38], fill=(18, 18, 20, 255))
    d.line([C - 5, 30, C + 5, 30], fill=(210, 220, 220, 200), width=2)
    # коса-лезвие справа
    d.line([C + 14, 30, C + 32, 18], fill=(150, 156, 160, 255), width=4)
    d.arc([C + 12, 6, C + 46, 36], 230, 330, fill=(230, 236, 240, 255), width=6)
    # второе лезвие слева
    d.arc([C - 46, 26, C - 12, 56], 130, 230, fill=(200, 206, 212, 255), width=6)


def mayak(d, img):
    G.glow(d, C, 46, 34, (255, 180, 70), 55)
    # каменное тело
    d.rounded_rectangle([C - 20, 44, C + 20, 78], radius=8, fill=(104, 100, 88, 255),
                        outline=(60, 58, 50, 255))
    d.line([C - 8, 44, C - 4, 78], fill=(60, 58, 50, 255), width=2)
    d.line([C + 10, 44, C + 14, 78], fill=(60, 58, 50, 255), width=2)
    # трещины со светом
    d.line([C - 14, 56, C - 6, 64], fill=(255, 200, 110, 230), width=2)
    # колпак-прожектор
    d.polygon([(C - 14, 44), (C + 14, 44), (C + 10, 24), (C - 10, 24)],
              fill=(70, 68, 60, 255), outline=(44, 42, 38, 255))
    d.ellipse([C - 8, 26, C + 8, 42], fill=(255, 210, 120, 255))
    # луч
    d.polygon([(C + 8, 28), (C + 40, 12), (C + 40, 40), (C + 8, 38)],
              fill=(255, 200, 100, 150))


def horovod(d, img):
    G.glow(d, C, 48, 34, G.GRAV, 60)
    # сияние-венец
    d.ellipse([C - 26, 12, C + 26, 44], outline=(190, 140, 255, 160), width=2)
    # три фигуры по кругу
    for i in range(3):
        a = i * math.tau / 3 - math.pi / 2
        fx = C + math.cos(a) * 17
        fy = 52 + math.sin(a) * 12
        d.polygon([(fx - 7, fy + 16), (fx - 5, fy - 6), (fx, fy - 12),
                   (fx + 5, fy - 6), (fx + 7, fy + 16)], fill=(150, 140, 170, 235))
        d.ellipse([fx - 3, fy - 10, fx + 3, fy - 4], fill=(210, 160, 255, 255))
    # кольцо рук
    d.arc([C - 22, 34, C + 22, 70], 40, 140, fill=(190, 140, 255, 150), width=2)


MUTANTS8 = {
    'kremen': kremen, 'rzhavnik': rzhavnik, 'sporonosets': sporonosets,
    'chrevo': chrevo, 'iskropluy': iskropluy, 'kosar': kosar,
    'mayak': mayak, 'horovod': horovod,
}


# ---------------- бейджи ролей 64px (стиль pack_icons: плита + заклёпки) ----------------
BS = 64
BC = 32


def badge(glyph_fn, rim):
    img = Image.new('RGBA', (BS, BS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cut = 11
    pts = [(cut, 2), (BS - cut, 2), (BS - 2, cut), (BS - 2, BS - cut),
           (BS - cut, BS - 2), (cut, BS - 2), (2, BS - cut), (2, cut), (cut, 2)]
    d.polygon(pts, fill=(22, 25, 20, 248))
    d.line(pts, fill=rim + (220,), width=3)
    # заклёпки по углам
    for (bx, by) in [(cut - 3, cut - 3), (BS - cut + 3, cut - 3),
                     (cut - 3, BS - cut + 3), (BS - cut + 3, BS - cut + 3)]:
        d.ellipse([bx - 2, by - 2, bx + 2, by + 2], fill=rim + (180,))
    glyph_fn(d, img)
    a = np.array(img).astype(np.int16)
    n = np.random.default_rng(hash(glyph_fn.__name__) % (1 << 30)).integers(-3, 4, (BS, BS, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8))


# роли: цвета согласованы с градиентами карточек v2
R_TANK = (150, 155, 150)     # сталь
R_HEAL = (126, 200, 80)      # болотный
R_DMG = (240, 110, 60)       # уголь/огонь
R_BUFF = (176, 120, 240)     # фиолет


def b_tank(d, img):
    # щит
    d.polygon([(BC, 8), (BC + 16, 14), (BC + 16, 34), (BC, 54), (BC - 16, 34), (BC - 16, 14)],
              fill=(120, 126, 122, 255), outline=(180, 186, 180, 255))
    d.polygon([(BC, 14), (BC + 11, 18), (BC + 11, 32), (BC, 47), (BC - 11, 32), (BC - 11, 18)],
              fill=(80, 86, 84, 255))
    d.line([BC, 18, BC, 44], fill=(200, 206, 200, 255), width=3)
    d.line([BC - 7, 26, BC + 7, 26], fill=(200, 206, 200, 255), width=3)


def b_heal(d, img):
    # лист-побег
    d.ellipse([BC - 14, 12, BC + 2, 34], fill=(126, 200, 80, 255), outline=(60, 110, 40, 255))
    d.line([BC + 1, 33, BC - 4, 52], fill=(90, 150, 60, 255), width=4)
    d.line([BC - 3, 42, BC + 8, 38], fill=(90, 150, 60, 255), width=3)
    d.ellipse([BC - 2, 14, BC + 3, 19], fill=(190, 255, 140, 255))
    # капля-спора
    d.ellipse([BC + 4, 40, BC + 14, 50], fill=(170, 255, 120, 230))


def b_dmg(d, img):
    # скрещённые клинки
    for sx in (-1, 1):
        d.line([BC + sx * 12, 12, BC - sx * 12, 50], fill=(220, 226, 230, 255), width=5)
        d.polygon([(BC - sx * 12 - 3, 50), (BC - sx * 12 + 3, 50), (BC - sx * 12, 58)],
                  fill=(240, 110, 60, 255))
    d.ellipse([BC - 4, 28, BC + 4, 36], fill=(240, 110, 60, 255), outline=(120, 40, 20, 255))


def b_buff(d, img):
    # аура-спираль + стрелка вверх
    for i, r in enumerate((20, 13)):
        d.arc([BC - r, 34 - r, BC + r, 34 + r], 200 + i * 40, 340 + i * 40,
              fill=(176, 120, 240, 255 - i * 60), width=4 - i)
    d.line([BC, 50, BC, 22], fill=(210, 160, 255, 255), width=4)
    d.polygon([(BC - 7, 24), (BC + 7, 24), (BC, 12)], fill=(210, 160, 255, 255))


ROLES = {'role_tank': (b_tank, R_TANK), 'role_heal': (b_heal, R_HEAL),
         'role_dmg': (b_dmg, R_DMG), 'role_buff': (b_buff, R_BUFF)}


if __name__ == '__main__':
    for name, fn in MUTANTS8.items():
        G.plate(fn, (140, 130, 110)).save(os.path.join(OUT_ICONS, name + '.png'))
        print('mutant/' + name)
    for name, (fn, rim) in ROLES.items():
        badge(fn, rim).save(os.path.join(OUT_BADGES, name + '.png'))
        print('badge/' + name)
    print('DONE')
