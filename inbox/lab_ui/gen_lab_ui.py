# -*- coding: utf-8 -*-
# Генератор арта лаборатории и меню (ЗАДАЧА 7). Стиль: графит + болотная
# зелень + жёлтый акцент, как баннеры mode_ui и UiTheme. Всё процедурно, CC0.
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\lab_ui'
random.seed(20261018)

# Палитра проекта (UiTheme + HUD)
GRAPHITE = (13, 15, 18)        # фон
PANEL = (38, 42, 40)           # панель
PANEL_DK = (22, 25, 22)
OLIVE = (51, 54, 44)           # оливковый металл
BEV_L = (74, 79, 64)           # бевел светлый
BEV_D = (18, 21, 17)           # бевел тёмный
SWAMP = (87, 107, 79)          # болотная окантовка
SWAMP_GLOW = (110, 150, 90)    # свечение болотное
GOLD = (212, 175, 55)          # золото
GOLD_MUT = (138, 122, 30)
GOLD_BRT = (255, 207, 77)
CREAM = (237, 230, 196)


def np_img(w, h, color):
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[..., :3] = color
    arr[..., 3] = 255
    return arr


def grain(arr, amount=8, alpha_only=False):
    """Зерно/шум по всему изображению."""
    h, w = arr.shape[:2]
    n = np.random.default_rng(random.randrange(1 << 30)).integers(
        -amount, amount + 1, (h, w, 1 if alpha_only else 3))
    arr[..., :3 if not alpha_only else 3] = np.clip(
        arr[..., :3].astype(np.int16) + n, 0, 255).astype(np.uint8)
    return arr


def scratches(draw, w, h, n, color=(200, 195, 170, 26), max_len=None):
    """Тонкие царапины под металла."""
    for _ in range(n):
        x, y = random.uniform(0, w), random.uniform(0, h)
        ang = random.uniform(0, math.tau)
        ln = random.uniform(14, max_len or min(w, h) * 0.25)
        draw.line([x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln],
                  fill=color, width=1)


def vignette(img, strength=0.55):
    """Плавное радиальное затемнение к краям (без полос)."""
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 1.42
    a = np.clip(d, 0, 1) ** 2.0 * strength * 255
    dark = np.zeros((h, w, 4), dtype=np.uint8)
    dark[..., 3] = a.astype(np.uint8)
    out = img.copy()
    out.alpha_composite(Image.fromarray(dark))
    return out


def radial_glow(size, color, max_alpha=255, power=2.0):
    """Мягкое радиальное пятно (RGBA)."""
    m = np_img(size, size, (0, 0, 0))
    yy, xx = np.mgrid[0:size, 0:size]
    c = size / 2
    d = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    a = np.clip(1 - d, 0, 1) ** power * max_alpha
    m[..., 0], m[..., 1], m[..., 2], m[..., 3] = *color, a.astype(np.uint8)
    return Image.fromarray(m)


# ----------------------------------------------------------------------------
# 1. lab_background: интерьер бункера-лаборатории, 2K. Читаются края и верх.
# ----------------------------------------------------------------------------
def lab_background():
    W, H = 2560, 1440
    base = np_img(W, H, GRAPHITE)
    # вертикальный градиент: темнее к полу (но не в черноту)
    g = np.linspace(1.3, 0.66, H).reshape(H, 1, 1)
    base[..., :3] = np.clip(base[..., :3].astype(np.float32) * g, 0, 255).astype(np.uint8)
    img = Image.fromarray(base)
    d = ImageDraw.Draw(img, 'RGBA')

    # --- задняя стена: панели с рёбрами -----------------------------------
    wall_l, wall_r, wall_t, wall_b = 0, W, 0, int(H * 0.62)
    step = 213
    for i, x in enumerate(range(wall_l, wall_r, step)):
        shade = PANEL if i % 2 == 0 else OLIVE
        d.rectangle([x, wall_t, min(x + step, wall_r), wall_b], fill=shade + (255,))
        d.line([x, wall_t, x, wall_b], fill=BEV_L + (70,), width=2)
        d.line([x + 1, wall_t, x + 1, wall_b], fill=BEV_D + (110,), width=2)
        # заклёпки: блик сверху-слева, тень снизу-справа
        for ry in range(60, wall_b - wall_t, 150):
            for rx in (x + 18, x + step - 34):
                d.ellipse([rx, wall_t + ry, rx + 12, wall_t + ry + 12], fill=BEV_D + (200,))
                d.ellipse([rx, wall_t + ry, rx + 10, wall_t + ry + 10], fill=BEV_L + (150,))

    # горизонтальная разводка панелей
    for fy in (0.18, 0.40):
        y = int(H * fy)
        d.rectangle([0, y, W, y + 16], fill=PANEL_DK + (255,))
        d.line([0, y, W, y], fill=BEV_L + (60,), width=2)
        d.line([0, y + 16, W, y + 16], fill=BEV_D + (140,), width=2)

    # --- трубы под потолком ------------------------------------------------
    for (py, pr, col) in [(int(H * 0.08), 34, (64, 58, 44)), (int(H * 0.13), 22, (52, 60, 50)),
                          (int(H * 0.165), 15, (70, 62, 40))]:
        d.rectangle([0, py - pr, W, py + pr], fill=col + (255,))
        d.line([0, py - pr, W, py - pr], fill=BEV_L + (90,), width=3)
        d.line([0, py + pr, W, py + pr], fill=BEV_D + (170,), width=3)
        d.line([0, py - pr // 2, W, py - pr // 2], fill=(160, 150, 110, 40), width=3)
        for x in range(200, W, 640):  # хомуты
            d.rectangle([x, py - pr - 8, x + 26, py + pr + 8], fill=BEV_D + (255,))
            d.line([x, py - pr - 8, x, py + pr + 8], fill=BEV_L + (80,), width=2)

    # --- кабели от нижней трубы вниз к стене --------------------------------
    cable_y0 = int(H * 0.165) + 15
    for i in range(5):
        x0 = int(220 + i * 500 + random.randint(-60, 60))
        pts = []
        sag = random.randint(70, 170)
        for t in range(21):
            tt = t / 20
            pts.append((x0 + math.sin(tt * math.pi) * random.randint(20, 60),
                        cable_y0 + int(sag * math.sin(tt * math.pi))))
        d.line(pts, fill=(12, 13, 11, 235), width=5)

    # --- вентиляционные решётки по самым краям (не под мониторами) ---------
    for (gx, gy, gw, gh) in [(44, int(H * 0.20), 150, 290), (W - 194, int(H * 0.20), 150, 290)]:
        d.rectangle([gx, gy, gx + gw, gy + gh], fill=PANEL_DK + (255,))
        d.rectangle([gx, gy, gx + gw, gy + gh], outline=BEV_L + (90,), width=3)
        for y in range(gy + 14, gy + gh - 8, 22):
            d.rectangle([gx + 12, y, gx + gw - 12, y + 10], fill=(8, 9, 8, 255))
            d.line([gx + 12, y, gx + gw - 12, y], fill=BEV_L + (50,), width=1)

    # --- аварийные лампы сверху (жёлтые, мягкий конус + пятно на полу) -------
    cones = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cones)
    for lx in (int(W * 0.22), int(W * 0.5), int(W * 0.78)):
        d.rectangle([lx - 40, 96, lx + 40, 122], fill=PANEL_DK + (255,))
        d.rectangle([lx - 34, 100, lx + 34, 118], fill=GOLD_MUT + (255,))
        d.rectangle([lx - 30, 104, lx + 30, 114], fill=GOLD_BRT + (230,))
        img.alpha_composite(radial_glow(820, GOLD, 120, 2.6), (lx - 410, -104))
        cd.polygon([(lx - 46, 118), (lx + 46, 118),
                    (lx + 230, int(H * 0.66)), (lx - 230, int(H * 0.66))],
                   fill=(212, 175, 55, 26))
    img.alpha_composite(cones.filter(ImageFilter.GaussianBlur(34)))
    d = ImageDraw.Draw(img, 'RGBA')
    for lx in (int(W * 0.22), int(W * 0.5), int(W * 0.78)):  # световые лужи на полу
        pool = radial_glow(560, GOLD, 34, 2.0).resize((760, 220))
        img.alpha_composite(pool, (lx - 380, wall_b + 40))
        d = ImageDraw.Draw(img, 'RGBA')

    # --- мониторы на стене (болотное свечение, глухие, без текста) ----------
    for (mx, my, mw, mh) in [(int(W * 0.115), int(H * 0.28), 340, 220),
                             (int(W * 0.435), int(H * 0.33), 420, 250),
                             (int(W * 0.755), int(H * 0.28), 340, 220)]:
        d.rectangle([mx, my, mx + mw, my + mh], fill=PANEL_DK + (255,))
        d.rectangle([mx, my, mx + mw, my + mh], outline=SWAMP + (255,), width=3)
        inset = 10
        scr = (8, 16, 10, 235)
        d.rectangle([mx + inset, my + inset, mx + mw - inset, my + mh - inset], fill=scr)
        for sy in range(my + inset + 8, my + mh - inset, 9):  # сканлайны
            d.line([mx + inset, sy, mx + mw - inset, sy], fill=(30, 52, 30, 90), width=2)
        # видный кабель от верхней трубы к монитору
        d.line([mx + mw // 2, int(H * 0.165) + 15, mx + mw // 2 - 26, my],
               fill=(12, 13, 11, 235), width=5)
        glow = radial_glow(700, SWAMP_GLOW, 46, 2.6)
        img.alpha_composite(glow, (mx + mw // 2 - 350, my + mh // 2 - 350))

    # --- стык стены и пола: плинтус + мягкая тень ----------------------------
    d.rectangle([0, wall_b, W, wall_b + 24], fill=(16, 18, 16, 255))
    d.line([0, wall_b, W, wall_b], fill=BEV_L + (80,), width=2)
    d.line([0, wall_b + 24, W, wall_b + 24], fill=(0, 0, 0, 200), width=2)
    seam = np.zeros((90, W, 4), dtype=np.uint8)
    seam[..., 3] = (np.linspace(150, 0, 90).reshape(90, 1)).astype(np.uint8)
    img.alpha_composite(Image.fromarray(seam), (0, wall_b + 24))
    d = ImageDraw.Draw(img, 'RGBA')

    # --- пол: тёмный металл, плиты ------------------------------------------
    d.rectangle([0, wall_b + 24, W, H], fill=(16, 18, 16, 255))
    for x in range(-200, W + 200, 200):
        d.line([x, H, x + 560, wall_b + 24], fill=(6, 7, 6, 200), width=3)
    for y in range(wall_b + 70, H, 130):
        d.line([0, y, W, y], fill=(30, 34, 30, 130), width=2)
        d.line([0, y + 2, W, y + 2], fill=(6, 7, 6, 160), width=2)
    # мокрый блик от мониторов на полу
    for mx in (int(W * 0.285), int(W * 0.5), int(W * 0.925)):
        glow = radial_glow(900, SWAMP_GLOW, 30, 3.0)
        img.alpha_composite(glow, (mx - 450, H - 520))

    # --- общая грязь: зерно + редкие царапины вне центра ---------------------
    arr = np.array(img)
    arr = grain(arr, 7)
    img = Image.fromarray(arr)
    d = ImageDraw.Draw(img, 'RGBA')
    n = 0
    while n < 34:
        x, y = random.uniform(0, W), random.uniform(0, H * 0.6)
        if W * 0.3 < x < W * 0.7 and H * 0.22 < y < H * 0.6:
            continue  # центр остаётся чистым под панели
        ang = random.uniform(0, math.tau)
        ln = random.uniform(20, 130)
        d.line([x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln],
               fill=(190, 185, 160, 15), width=1)
        n += 1
    img = vignette(img, 0.42)
    img.save(f'{OUT}\\lab_background_2k.png')
    print('lab_background_2k.png', img.size)


# ----------------------------------------------------------------------------
# 2. menu_background: пейзаж зоны с ЧАЭС на горизонте, 2K.
# ----------------------------------------------------------------------------
def menu_background():
    W, H = 2560, 1440
    base = np_img(W, H, GRAPHITE)
    # небо: холодный верх -> болотный низ
    yy = np.mgrid[0:H, 0:W][0].reshape(H, W, 1) / H
    top = np.array([16, 19, 24], dtype=np.float32)
    bot = np.array([46, 50, 38], dtype=np.float32)
    base[..., :3] = (top + (bot - top) * (yy ** 1.4)).astype(np.uint8)
    img = Image.fromarray(base)
    d = ImageDraw.Draw(img, 'RGBA')

    horizon = int(H * 0.62)

    # тяжёлые облака
    for _ in range(60):
        cx, cy = random.uniform(0, W), random.uniform(0, horizon * 0.75)
        r = random.uniform(120, 420)
        shade = random.randint(20, 44)
        d.ellipse([cx - r, cy - r * 0.36, cx + r, cy + r * 0.36],
                  fill=(shade + 8, shade + 10, shade + 8, 60))
    img = img.filter(ImageFilter.GaussianBlur(6))
    d = ImageDraw.Draw(img, 'RGBA')

    # холодная луна за облаками (ореол строго по центру диска)
    mcx, mcy = int(W * 0.72), 252
    img.alpha_composite(radial_glow(520, (150, 160, 150), 90, 2.2), (mcx - 260, mcy - 260))
    d = ImageDraw.Draw(img, 'RGBA')
    d.ellipse([mcx - 42, mcy - 42, mcx + 42, mcy + 42],
              fill=(180, 186, 178, 140))

    # зарево аварии слева (болотное)
    glow = radial_glow(900, (96, 130, 70), 60, 2.6)
    img.alpha_composite(glow, (-200, horizon - 500))

    # дальний план: холмы
    ridge_far = [(0, horizon)]
    x = 0
    while x < W:
        ridge_far.append((x, horizon - random.randint(10, 60)))
        x += random.randint(140, 300)
    ridge_far += [(W, horizon), (W, H), (0, H)]
    d.polygon(ridge_far, fill=(24, 28, 24, 255))

    # ЧАЭС: градирня + труба + машинный зал
    px = int(W * 0.56)
    # градирня (гиперболоид)
    gt_x, gb_x, gt_y, gb_y = px - 95, px - 150, horizon - 420, horizon
    d.polygon([(gt_x, gt_y), (gt_x + 190, gt_y), (gb_x + 190, gb_y), (gb_x, gb_y)],
              fill=(30, 33, 30, 255))
    d.polygon([(gt_x + 26, gt_y + 420), (gt_x + 164, gt_y + 420),
               (gb_x + 190, gb_y), (gb_x, gb_y)], fill=(24, 26, 24, 255))
    # дым из градирни (мягкий слой с размытием)
    smoke = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(smoke)
    for i in range(9):
        sx = px + random.randint(-24, 24)
        sy = gt_y - i * 26
        sd.ellipse([sx - 38 - i * 6, sy - 18, sx + 38 + i * 6, sy + 18],
                   fill=(54, 57, 54, max(14, 30 - i * 2)))
    smoke = smoke.filter(ImageFilter.GaussianBlur(16))
    img.alpha_composite(smoke)
    d = ImageDraw.Draw(img, 'RGBA')
    # труба вент tallest
    d.polygon([(px - 235, horizon - 560), (px - 205, horizon - 560),
               (px - 195, horizon), (px - 245, horizon)], fill=(33, 36, 33, 255))
    d.line([px - 235, horizon - 560, px - 245, horizon], fill=(60, 64, 58, 90), width=2)
    fy = horizon - 470
    d.rectangle([px - 238, fy, px - 202, fy + 14], fill=(70, 60, 30, 45))  # одна тусклая banda
    # машинный зал (длинный блок)
    d.polygon([(px - 80, horizon - 190), (px + 480, horizon - 150),
               (px + 480, horizon), (px - 80, horizon)], fill=(30, 33, 30, 255))
    d.line([px - 80, horizon - 190, px + 480, horizon - 150], fill=(66, 70, 62, 90), width=2)
    # окна-щёлки машинного зала: часть погасла, остальные тусклые
    for i in range(14):
        if random.random() < 0.35:
            continue
        wx = px - 40 + i * 36
        d.rectangle([wx, horizon - 110, wx + 18, horizon - 70],
                    fill=(96, 130, 78, random.randint(26, 64)))
    # саркофаг: светлее зала, с лунной кромкой справа
    d.polygon([(px + 520, horizon - 260), (px + 760, horizon - 220),
               (px + 740, horizon), (px + 500, horizon)], fill=(38, 41, 37, 255))
    d.line([px + 760, horizon - 220, px + 740, horizon], fill=(96, 100, 92, 130), width=3)
    d.line([px + 520, horizon - 260, px + 740, horizon], fill=(56, 60, 54, 100), width=2)

    # средний план: мёртвый лес (не перед станцией — иначе ветки ломают силуэт)
    plant_l, plant_r = px - 300, px + 800
    for _ in range(52):
        tx = random.uniform(0, W)
        if plant_l < tx < plant_r:
            continue
        th = random.randint(70, 160)
        base_y = horizon + random.randint(6, 40)
        trunk(tx, base_y, th, d, (11, 13, 11, 255))

    # передний план: evacuated холмы травы + болотная вода
    fore = [(0, H), (0, H - 120)]
    x = 0
    while x < W:
        fore.append((x, H - 120 - random.randint(0, 90) - 40 * math.sin(x / 300)))
        x += 60
    fore.append((W, H - 120))
    fore.append((W, H))
    d.polygon(fore, fill=(12, 14, 11, 255))
    # трава-силуэты
    for _ in range(400):
        gx = random.uniform(0, W)
        gy = H - random.randint(0, 130)
        ln = random.randint(12, 42)
        ang = random.uniform(-0.5, 0.5)
        d.line([gx, gy, gx + math.sin(ang) * ln, gy - ln],
               fill=(22, 26, 18, 255), width=2)
    # жёлтые огоньки в траве (одинаковые по силе)
    for _ in range(6):
        lx = random.uniform(80, W - 80)
        ly = H - random.randint(24, 96)
        img.alpha_composite(radial_glow(170, GOLD_BRT, 130, 2.5), (int(lx) - 85, int(ly) - 85))
        d = ImageDraw.Draw(img, 'RGBA')
        d.ellipse([lx - 3, ly - 3, lx + 3, ly + 3], fill=GOLD_BRT + (255,))

    # туман над горизонтом (с лёгким шумом против бандинга)
    fog = Image.new('RGBA', (W, 260), (120, 126, 108, 0))
    fd = ImageDraw.Draw(fog)
    for y in range(260):
        a = int(46 * math.sin(y / 260 * math.pi))
        fd.line([0, y, W, y], fill=(122, 128, 110, a))
    fog = fog.filter(ImageFilter.GaussianBlur(30))
    farr = np.array(fog).astype(np.int16)
    farr[..., 3] = np.clip(farr[..., 3] + np.random.default_rng(7).integers(-6, 7, (260, W)), 0, 255)
    img.alpha_composite(Image.fromarray(farr.astype(np.uint8)), (0, horizon - 170))

    arr = np.array(img)
    arr = grain(arr, 6)
    img = vignette(Image.fromarray(arr), 0.45)
    img.save(f'{OUT}\\menu_background_2k.png')
    print('menu_background_2k.png', img.size)


def trunk(x, base_y, h, d, color):
    """Мёртвое дерево-силуэт."""
    top = base_y - h
    lean = random.uniform(-0.16, 0.16)
    d.line([x, base_y, x + lean * h, top], fill=color, width=max(3, h // 30))
    for _ in range(5):
        by = base_y - random.randint(int(h * 0.3), int(h * 0.9))
        ba = random.uniform(0.5, 1.3) * random.choice([-1, 1])
        bl = random.randint(int(h * 0.22), int(h * 0.5))
        d.line([x + lean * (base_y - by), by, x + lean * (base_y - by) + math.sin(ba) * bl,
                by - abs(math.cos(ba)) * bl], fill=color, width=3)


# ----------------------------------------------------------------------------
# 3. panel_frame_9patch 96x96: болотная окантовка, центр прозрачный.
# ----------------------------------------------------------------------------
def panel_frame():
    S = 96
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([1, 1, S - 2, S - 2], radius=7, outline=SWAMP + (235,), width=3)
    d.rounded_rectangle([4, 4, S - 5, S - 5], radius=5, outline=BEV_L + (70,), width=1)
    d.rounded_rectangle([7, 7, S - 8, S - 8], radius=4, outline=(0, 0, 0, 130), width=1)
    # уголки-акценты
    for (cx, cy, dx, dy) in [(6, 6, 1, 1), (S - 7, 6, -1, 1), (6, S - 7, 1, -1), (S - 7, S - 7, -1, -1)]:
        d.line([cx, cy, cx + 14 * dx, cy], fill=GOLD + (150,), width=3)
        d.line([cx, cy, cx, cy + 14 * dy], fill=GOLD + (150,), width=3)
    img.save(f'{OUT}\\panel_frame_9patch.png')
    print('panel_frame_9patch.png')


# ----------------------------------------------------------------------------
# 4. Иконки станций 256x256.
# ----------------------------------------------------------------------------
def station_icon(name, draw_fn):
    S = 256
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # плашка со срезанными углами (стиль баннеров mode_ui)
    cut = 26
    pts = [(cut, 0), (S - cut, 0), (S, cut), (S, S - cut), (S - cut, S), (0, S - cut), (0, cut), (cut, 0)]
    d.polygon(pts, fill=(31, 35, 31, 242))
    d.line(pts, fill=SWAMP + (255,), width=6, joint='curve')
    for i in range(len(pts) - 1):  # внутренняя тонкая
        pass
    d.line([(cut + 8, 8), (S - cut - 8, 8), (S - 8, cut + 8), (S - 8, S - cut - 8),
            (S - cut - 8, S - 8), (cut + 8, S - 8), (8, S - cut - 8), (8, cut + 8), (cut + 8, 8)],
           fill=BEV_L + (60,), width=1)
    draw_fn(d, img)
    arr = np.array(img)
    arr = grain(arr, 5)
    img = Image.fromarray(arr)
    d = ImageDraw.Draw(img, 'RGBA')
    scratches(d, S, S, 6, (200, 195, 170, 22))
    img.save(f'{OUT}\\{name}.png')
    print(name + '.png')


def _glow_behind(img, xy, size, color=SWAMP_GLOW, alpha=90):
    img.alpha_composite(radial_glow(size, color, alpha, 2.4), (xy[0] - size // 2, xy[1] - size // 2))


def icon_anomaly(d, img):
    _glow_behind(img, (128, 128), 260)
    d = ImageDraw.Draw(img)
    # спиральный вихрь из трёх дуг
    for i, r in enumerate((34, 52, 70)):
        a0 = i * 2.1
        d.arc([128 - r, 128 - r, 128 + r, 128 + r], math.degrees(a0),
              math.degrees(a0 + 3.6), fill=SWAMP_GLOW + (255 - i * 40,), width=9 - i)
    d.ellipse([118, 118, 138, 138], fill=GOLD_BRT + (255,))
    for (sx, sy, ln) in [(178, 70, 22), (72, 186, 18), (186, 176, 14)]:
        d.line([sx, sy, sx + ln, sy - ln], fill=GOLD_BRT + (200,), width=3)


def icon_mutant(d, img):
    _glow_behind(img, (128, 150), 260, (120, 90, 70), 70)
    d = ImageDraw.Draw(img)
    # три когтя-царапины
    for i, dx in enumerate((-34, 0, 34)):
        x = 128 + dx
        d.line([x - 16, 66, x + 20, 190], fill=(196, 176, 120, 255), width=13 - i)
        d.line([x + 20, 190, x + 12, 208], fill=(150, 130, 84, 255), width=8)
    # брызги
    for (bx, by, br) in [(88, 92, 4), (172, 108, 3), (140, 84, 3)]:
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=GOLD + (220,))


def icon_monolith(d, img):
    _glow_behind(img, (128, 128), 280, (150, 140, 80), 80)
    d = ImageDraw.Draw(img)
    # крупный гранёный кристалл в тонком кольце
    d.ellipse([128 - 92, 128 - 92, 128 + 92, 128 + 92], outline=SWAMP + (230,), width=4)
    body = [(128, 44), (168, 112), (152, 200), (104, 200), (88, 112)]
    d.polygon(body, fill=(64, 78, 56, 255), outline=GOLD + (255,))
    # грань: светлая левая половина, тёмная правая
    d.polygon([(128, 44), (168, 112), (152, 200), (128, 200)], fill=(38, 46, 34, 255))
    d.polygon([(128, 44), (88, 112), (104, 200), (128, 200)], fill=(96, 116, 78, 255))
    d.polygon([(128, 44), (168, 112), (128, 124)], fill=(70, 86, 58, 255))
    d.line([128, 44, 128, 124], fill=GOLD_BRT + (200,), width=2)
    # луч вверх
    d.line([128, 44, 128, 22], fill=GOLD_BRT + (235,), width=5)
    d.ellipse([120, 14, 136, 30], fill=GOLD_BRT + (255,))


def icon_shop(d, img):
    _glow_behind(img, (128, 140), 240, (110, 110, 80), 60)
    d = ImageDraw.Draw(img)
    # крупный ящик: доски + две вертикальные ленты
    d.polygon([(56, 92), (200, 92), (204, 196), (52, 196)], fill=(58, 54, 40, 255),
              outline=BEV_L + (170,))
    # крышка-слэты
    d.polygon([(56, 92), (200, 92), (210, 72), (66, 72)], fill=(70, 64, 46, 255),
              outline=BEV_L + (170,))
    for i in range(4):  # доски
        y = 116 + i * 20
        d.line([58, y, 198, y], fill=(34, 31, 22, 200), width=2)
    for x in (88, 168):  # ленты-стяжки через крышку и корпус
        d.line([x - 8, 72, x - 4, 196], fill=GOLD + (255,), width=9)
        d.line([x + 8, 72, x + 4, 196], fill=GOLD_MUT + (255,), width=3)
    for (bx, by) in [(64, 100), (188, 100), (64, 186), (188, 186)]:  # угловые скобы
        d.ellipse([bx, by, bx + 10, by + 10], outline=BEV_L + (160,), width=2)


def icon_farm(d, img):
    _glow_behind(img, (128, 128), 240, SWAMP_GLOW, 70)
    d = ImageDraw.Draw(img)
    # колба с болотной жидкостью
    d.line([112, 56, 112, 96], fill=(150, 155, 140, 255), width=7)
    d.line([144, 56, 144, 96], fill=(150, 155, 140, 255), width=7)
    d.polygon([(104, 96), (152, 96), (188, 176), (168, 200), (88, 200), (68, 176)],
              outline=(160, 165, 150, 255), width=5)
    d.polygon([(86, 150), (170, 150), (188, 176), (168, 200), (88, 200), (68, 176)],
              fill=(70, 110, 62, 235))
    for _ in range(9):  # пузыри
        bx, by = random.randint(96, 160), random.randint(160, 192)
        d.ellipse([bx, by, bx + 7, by + 7], outline=(150, 200, 130, 180), width=2)
    d.line([98, 150, 158, 150], fill=(160, 165, 150, 255), width=4)


def icon_gacha(d, img):
    _glow_behind(img, (128, 128), 280, (150, 140, 80), 80)
    d = ImageDraw.Draw(img)
    # рулетка-циферблат + искра
    d.ellipse([128 - 84, 128 - 84, 128 + 84, 128 + 84], fill=(28, 30, 26, 255),
              outline=GOLD + (255,), width=6)
    d.ellipse([128 - 60, 128 - 60, 128 + 60, 128 + 60], outline=SWAMP + (255,), width=3)
    for i in range(12):
        a = i * math.tau / 12
        r0, r1 = 62, 76
        d.line([128 + math.cos(a) * r0, 128 + math.sin(a) * r0,
                128 + math.cos(a) * r1, 128 + math.sin(a) * r1], fill=BEV_L + (170,), width=3)
    d.polygon([(128, 128), (128 + 46, 128 - 20), (128 + 34, 128 + 10)],
              fill=GOLD_BRT + (255,))
    d.ellipse([120, 120, 136, 136], fill=(24, 27, 24, 255), outline=GOLD + (255,), width=2)
    d.line([196, 60, 214, 42], fill=GOLD_BRT + (230,), width=4)
    d.line([204, 84, 226, 78], fill=GOLD_BRT + (180,), width=3)


# ----------------------------------------------------------------------------
# 5. Кнопки 64x64 nine-patch.
# ----------------------------------------------------------------------------
def button(name, hover=False):
    S = 64
    img = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    if hover:
        body, border = (74, 84, 62, 255), GOLD + (255,)
        img.alpha_composite(radial_glow(S * 2, GOLD, 60, 2.0), (-S // 2, -S // 2))
        d = ImageDraw.Draw(img, 'RGBA')
    else:
        body, border = (47, 53, 46, 255), SWAMP + (255,)
    d.rounded_rectangle([1, 1, S - 2, S - 2], radius=6, fill=body)
    d.rounded_rectangle([1, 1, S - 2, S - 2], radius=6, outline=border, width=4)
    if hover:
        d.rounded_rectangle([8, 8, S - 9, S - 9], radius=3, outline=GOLD_MUT + (220,), width=2)
    d.line([7, 7, S - 8, 7], fill=(BEV_L + (190,)) if not hover else (210, 200, 130, 200), width=2)
    d.line([7, S - 8, S - 8, S - 8], fill=(0, 0, 0, 150), width=2)
    img.save(f'{OUT}\\{name}.png')
    print(name + '.png')


# ----------------------------------------------------------------------------
# 6. Декоративные вставки lab_terminal_*.
# ----------------------------------------------------------------------------
def lab_terminal():
    # монитор со сканлайнами, на устойчивой подставке
    W, H = 640, 440
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([6, 6, W - 6, H - 56], radius=14, fill=(24, 26, 24, 248),
                        outline=SWAMP + (255,), width=5)
    d.rectangle([28, 28, W - 28, H - 78], fill=(7, 14, 8, 255))
    for y in range(32, H - 82, 7):
        d.line([28, y, W - 28, y], fill=(26, 48, 26, 80), width=1)
    # осциллограмма-помехи
    pts = []
    for x in range(28, W - 28, 4):
        pts.append((x, (H - 110) // 2 + int(30 * math.sin(x / 26.0) * random.uniform(0.4, 1.2))))
    d.line(pts, fill=(96, 160, 88, 220), width=3)
    # подставка: стойка + широкая база + тень
    d.rectangle([W // 2 - 70, H - 56, W // 2 + 70, H - 34], fill=(20, 22, 20, 250))
    d.rectangle([W // 2 - 130, H - 34, W // 2 + 130, H - 14], fill=(26, 28, 25, 252))
    d.line([W // 2 - 130, H - 34, W // 2 + 130, H - 34], fill=BEV_L + (120,), width=2)
    d.ellipse([W // 2 - 150, H - 18, W // 2 + 150, H], fill=(0, 0, 0, 90))
    arr = np.array(img)
    arr = grain(arr, 5)
    Image.fromarray(arr).save(f'{OUT}\\lab_terminal_monitor.png')
    print('lab_terminal_monitor.png')

    # аварийная лампа: конус-колпак + баллон + свечение
    W, H = 320, 420
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([W // 2 - 7, 36, W // 2 + 7, 104], fill=(40, 42, 38, 255))
    # колпак-конус
    d.polygon([(W // 2 - 78, 128), (W // 2 + 78, 128), (W // 2 + 34, 96), (W // 2 - 34, 96)],
              fill=(44, 46, 40, 255), outline=BEV_L + (170,))
    # баллон-лампа
    d.ellipse([W // 2 - 58, 120, W // 2 + 58, 238], fill=(30, 32, 28, 255),
              outline=BEV_L + (170,), width=4)
    d.ellipse([W // 2 - 44, 134, W // 2 + 44, 224], fill=GOLD_MUT + (255,))
    d.ellipse([W // 2 - 30, 146, W // 2 + 16, 182], fill=(255, 230, 150, 130))
    img.alpha_composite(radial_glow(440, GOLD, 120, 2.3), (W // 2 - 220, 60))
    Image.fromarray(np.array(img)).save(f'{OUT}\\lab_terminal_lamp.png')
    print('lab_terminal_lamp.png')


if __name__ == '__main__':
    lab_background()
    menu_background()
    panel_frame()
    station_icon('station_anomaly', icon_anomaly)
    station_icon('station_mutant', icon_mutant)
    station_icon('station_monolith', icon_monolith)
    station_icon('station_shop', icon_shop)
    station_icon('station_farm', icon_farm)
    station_icon('station_gacha', icon_gacha)
    button('button_normal')
    button('button_hover', hover=True)
    lab_terminal()
    print('готово')
