# -*- coding: utf-8 -*-
# ЗАДАЧА 8: арт-пак карточек гачи и эффектов вскрытия. Процедурно, стиль
# проекта (графит + болотная зелень + золото, как mode_ui/UiTheme).
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\gacha_cards'
random.seed(20261026)

GRAPHITE = (13, 15, 18)
PANEL = (30, 33, 30)
PANEL_DK = (20, 22, 20)
BEV_L = (74, 79, 64)
BEV_D = (10, 12, 10)
SWAMP = (87, 107, 79)
GOLD = (212, 175, 55)
GOLD_BRT = (255, 207, 77)
CREAM = (237, 230, 196)

# редкости: цвета из RARITY_COLORS (data/gacha_data.gd); epic — фиолетовый
# (в игре такой редкости пока нет, рамка на вырост)
RARITY = {
    'common':    (191, 191, 200),
    'rare':      (115, 166, 255),
    'epic':      (180, 140, 255),
    'legendary': (255, 184, 64),
}

# окно иконки в рамках карты (одинаковое у всех редкостей)
ICON_WIN = (58, 118, 198, 258)  # x0, y0, x1, y1 (256x360)


def np_canvas(w, h, color=(0, 0, 0, 0)):
    arr = np.zeros((h, w, 4), dtype=np.uint8)
    arr[..., :3] = color[:3]
    if len(color) > 3:
        arr[..., 3] = color[3]
    return arr


def grain(img, amount=6):
    arr = np.array(img).astype(np.int16)
    n = np.random.default_rng(random.randrange(1 << 30)).integers(
        -amount, amount + 1, arr[..., :3].shape)
    arr[..., :3] = np.clip(arr[..., :3] + n, 0, 255)
    return Image.fromarray(arr.astype(np.uint8))


def scratches(d, w, h, n, alpha=18):
    for _ in range(n):
        x, y = random.uniform(0, w), random.uniform(0, h)
        ang = random.uniform(0, math.tau)
        ln = random.uniform(12, w * 0.3)
        d.line([x, y, x + math.cos(ang) * ln, y + math.sin(ang) * ln],
               fill=(200, 195, 170, alpha), width=1)


def radial(size, color, max_alpha=255, power=2.0, core=0.0):
    yy, xx = np.mgrid[0:size, 0:size]
    c = size / 2
    dd = np.sqrt((xx - c) ** 2 + (yy - c) ** 2) / c
    a = np.clip(1 - dd, 0, 1) ** power * max_alpha
    if core:
        a += np.clip(1 - dd / max(core, 1e-3), 0, 1) * max_alpha * 0.4
    m = np.zeros((size, size, 4), dtype=np.uint8)
    m[..., 0], m[..., 1], m[..., 2] = color
    m[..., 3] = np.clip(a, 0, 255).astype(np.uint8)
    return Image.fromarray(m)


def cut_corners(pts, w, h, cut):
    return [(cut, 0), (w - cut, 0), (w, cut), (w, h - cut), (w - cut, h), (0, h - cut), (0, cut), (cut, 0)]


# ---------------------------------------------------------------- rubashka
def card_back():
    W, H = 256, 360
    img = Image.fromarray(np_canvas(W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    pts = cut_corners(None, W, H, 18)
    d.polygon(pts, fill=PANEL + (250,))
    # фон рубашки: тонкая диагональная сетка
    for x in range(-H, W + H, 14):
        d.line([x, 0, x + H, H], fill=(44, 48, 42, 90), width=1)
        d.line([x, H, x + H, 0], fill=(38, 42, 37, 60), width=1)
    # центральный дуговой узор вокруг знака
    cx, cy = W // 2, H // 2 - 8
    for r, a in ((66, 70), (84, 40), (100, 26)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=SWAMP + (a,), width=2)
    # знак Зоны: трефойл радиации из трёх секторов
    for i in range(3):
        a0 = 90 + i * 120 - 24
        d.pieslice([cx - 40, cy - 40, cx + 40, cy + 40], a0, a0 + 48, fill=GOLD + (235,))
    d.ellipse([cx - 9, cy - 9, cx + 9, cy + 9], fill=GOLD + (255,))
    # рамки
    d.line(pts, fill=SWAMP + (255,), width=4, joint='curve')
    d.line([(24, 24), (W - 24, 24), (W - 24, H - 24), (24, H - 24), (24, 24)],
           fill=BEV_L + (70,), width=1)
    # золотые уголки
    for (x, y, dx, dy) in [(14, 14, 1, 1), (W - 15, 14, -1, 1), (14, H - 15, 1, -1), (W - 15, H - 15, -1, -1)]:
        d.line([x, y, x + 16 * dx, y], fill=GOLD + (170,), width=3)
        d.line([x, y, x, y + 16 * dy], fill=GOLD + (170,), width=3)
    # нижняя хазард-полоска
    for x in range(20, W - 40, 18):
        d.polygon([(x, H - 18), (x + 9, H - 18), (x - 4 + 9, H - 8), (x - 4, H - 8)], fill=GOLD + (110,))
    img = grain(img, 5)
    d = ImageDraw.Draw(img, 'RGBA')
    scratches(d, W, H, 10)
    img.save(f'{OUT}\\card_back.png')
    print('card_back.png')


# ---------------------------------------------------------------- рамки
def card_frame(rarity):
    W, H = 256, 360
    col = RARITY[rarity]
    strong = rarity in ('epic', 'legendary')
    img = Image.fromarray(np_canvas(W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    pts = cut_corners(None, W, H, 18)
    d.polygon(pts, fill=PANEL_DK + (235,))          # тёмное поле
    x0, y0, x1, y1 = ICON_WIN                        # окно иконки — прозрачное
    d.polygon([(x0 - 4, y0 - 4), (x1 + 4, y0 - 4), (x1 + 4, y1 + 4), (x0 - 4, y1 + 4)],
              fill=(0, 0, 0, 0))
    # внешняя рамка редкости (легче/тяжелее)
    bw = 5 if strong else 3
    d.line(pts, fill=col + (255,), width=bw, joint='curve')
    # внутренняя тонкая + бевелы
    m = bw + 6
    d.line(cut_corners(None, W - 2 * m, H - 2 * m, 12), fill=col + (90,), width=1)
    # золотые/цветные уголки-скобы
    for (x, y, dx, dy) in [(12, 12, 1, 1), (W - 13, 12, -1, 1), (12, H - 13, 1, -1), (W - 13, H - 13, -1, -1)]:
        d.line([x, y, x + 18 * dx, y], fill=col + (230,), width=4)
        d.line([x, y, x, y + 18 * dy], fill=col + (230,), width=4)
    # орнамент для высоких редкостей: шевроны сверху и снизу
    if strong:
        for i in range(3):
            xx = W // 2 - 30 + i * 30
            d.line([xx - 10, 34, xx, 26, xx + 10, 34], fill=col + (200,), width=3)
            d.line([xx - 10, H - 34, xx, H - 26, xx + 10, H - 34], fill=col + (200,), width=3)
    # ниша под имя сверху и полоска статуса снизу (тёмные зоны, текст рисует игра)
    d.rectangle([26, 60, W - 26, 96], fill=(8, 10, 9, 120))
    d.rectangle([26, y1 + 14, W - 26, y1 + 38], fill=(8, 10, 9, 120))
    d.line([26, y1 + 14, W - 26, y1 + 14], fill=col + (70,), width=1)
    # мягкое свечение рамки для высоких редкостей
    if strong:
        glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(glow)
        gd.line(pts, fill=col + (110,), width=bw + 6, joint='curve')
        glow = glow.filter(ImageFilter.GaussianBlur(5))
        img.alpha_composite(glow)
        d = ImageDraw.Draw(img, 'RGBA')
        d.line(pts, fill=col + (255,), width=bw, joint='curve')
    # окно иконки: вырезаем альфу (рисование прозрачным не стирает)
    arr = np.array(img)
    arr[y0:y1 + 1, x0:x1 + 1, 3] = 0
    img = Image.fromarray(arr)
    d = ImageDraw.Draw(img, 'RGBA')
    d.rectangle([x0 - 2, y0 - 2, x1 + 2, y1 + 2], outline=col + (130,), width=2)
    img = grain(img, 4)
    img.save(f'{OUT}\\card_frame_{rarity}.png')
    print(f'card_frame_{rarity}.png')


# ---------------------------------------------------------------- ореолы
def glow(rarity):
    col = RARITY[rarity]
    power = {'common': 3.0, 'rare': 2.4, 'epic': 1.9, 'legendary': 1.5}[rarity]
    alpha = {'common': 110, 'rare': 150, 'epic': 190, 'legendary': 235}[rarity]
    radial(512, col, alpha, power).save(f'{OUT}\\glow_{rarity}.png')
    print(f'glow_{rarity}.png')


# ---------------------------------------------------------------- вспышки
def burst(rarity):
    col = RARITY[rarity]
    S = 512
    img = radial(S, col, 120, 2.6).copy()
    d = ImageDraw.Draw(img, 'RGBA')
    c = S // 2
    rays = 14 if rarity == 'epic' else 18
    for i in range(rays):
        a = i * math.tau / rays + random.uniform(-0.05, 0.05)
        ln = random.uniform(0.45, 0.95) * c
        wdt = random.choice([2, 3, 5])
        d.line([c, c, c + math.cos(a) * ln, c + math.sin(a) * ln],
               fill=col + (random.randint(120, 210),), width=wdt)
    # ядро
    core = radial(S // 2, (255, 250, 235), 235, 2.2)
    img.alpha_composite(core, (c // 2, c // 2))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    img.save(f'{OUT}\\burst_{rarity}.png')
    print(f'burst_{rarity}.png')


# ---------------------------------------------------------------- плашки
def ribbon(name, color, accent):
    W, H = 192, 64
    img = Image.fromarray(np_canvas(W, H))
    d = ImageDraw.Draw(img, 'RGBA')
    pts = [(10, 0), (W - 10, 0), (W, H // 2), (W - 10, H), (10, H), (0, H // 2)]
    d.polygon(pts, fill=color + (240,))
    d.line(pts, fill=accent + (255,), width=3, joint='curve')
    d.line([(16, 10), (W - 16, 10)], fill=(255, 255, 255, 40), width=2)
    d.line([(16, H - 10), (W - 16, H - 10)], fill=(0, 0, 0, 90), width=2)
    # зона под текст: 24..168 x 20..44 (текст рисует игра, как в mode_ui)
    img = grain(img, 4)
    img.save(f'{OUT}\\ribbon_{name}.png')
    print(f'ribbon_{name}.png')


# ---------------------------------------------------------------- искры
def spark(idx):
    S = 128
    img = Image.fromarray(np_canvas(S, S))
    d = ImageDraw.Draw(img, 'RGBA')
    c = S // 2
    if idx == 1:  # четырёхлучевая звезда
        for (dx, dy, ln, wd) in [(1, 0, 52, 5), (-1, 0, 52, 5), (0, 1, 52, 5), (0, -1, 52, 5),
                                 (1, 1, 30, 3), (-1, -1, 30, 3), (1, -1, 30, 3), (-1, 1, 30, 3)]:
            d.line([c, c, c + dx * ln, c + dy * ln], fill=GOLD_BRT + (235,), width=wd)
        d.ellipse([c - 7, c - 7, c + 7, c + 7], fill=(255, 252, 240, 255))
    elif idx == 2:  # мягкая точка-свечение
        img.alpha_composite(radial(S, GOLD_BRT, 235, 2.0))
    else:           # росчерк-штрих
        d.line([c - 40, c + 18, c + 34, c - 26], fill=GOLD_BRT + (230,), width=7)
        d.line([c - 30, c + 26, c + 20, c - 10], fill=(255, 250, 230, 150), width=3)
    img = img.filter(ImageFilter.GaussianBlur(0.6))
    img.save(f'{OUT}\\spark_card_{idx:02d}.png')
    print(f'spark_card_{idx:02d}.png')


if __name__ == '__main__':
    card_back()
    for r in RARITY:
        card_frame(r)
        glow(r)
    for r in ('epic', 'legendary'):
        burst(r)
    ribbon('new', (150, 118, 30), GOLD_BRT)
    ribbon('dup', (52, 60, 50), SWAMP)
    for i in range(1, 4):
        spark(i)
    print('готово')
