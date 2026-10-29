# -*- coding: utf-8 -*-
# ЗАДАЧА 25: иконка приложения и лаунчер-набор Android.
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\app_icon'

GOLD = (232, 179, 57)
GOLD_HI = (255, 214, 110)
SWAMP = (87, 107, 79)
DARK = (13, 15, 12)
DARK2 = (26, 30, 22)


def bg(w, h):
    """Тёмная текстура: графит с зелёным отсветом снизу + зерно."""
    yy = np.mgrid[0:h, 0:w][0].reshape(h, w, 1) / h
    top = np.array([16, 18, 14], dtype=np.float32)
    bot = np.array([30, 36, 26], dtype=np.float32)
    img = top + (bot - top) * (yy ** 1.5)
    n = np.random.default_rng(25).normal(0, 1.6, (h, w, 1))
    return Image.fromarray(np.clip(img + n, 0, 255).astype(np.uint8))


def trefoil(d, cx, cy, R, col, blade_col=None):
    blade_col = blade_col or col
    for i in range(3):
        a0 = 90 + i * 120 - 26
        d.pieslice([cx - R, cy - R, cx + R, cy + R], a0, a0 + 52, fill=blade_col)
    d.ellipse([cx - R * 0.2, cy - R * 0.2, cx + R * 0.2, cy + R * 0.2], fill=blade_col)
    # вырез центра под цвет фона сделает игра маской; оставляем точку


def draw_icon(size, rounded=False, safe=1.0):
    """Иконка: тёмная плита, золото трефойл, болотное кольцо, потёртости."""
    img = bg(size, size).convert('RGBA')
    d = ImageDraw.Draw(img)
    cx = cy = size / 2
    R = size * 0.30 * safe
    # болотное кольцо
    d.ellipse([cx - R * 1.32, cy - R * 1.32, cx + R * 1.32, cy + R * 1.32],
              outline=SWAMP + (220,), width=max(3, int(size * 0.025)))
    # мягкое золотое свечение
    glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - R * 1.15, cy - R * 1.15, cx + R * 1.15, cy + R * 1.15],
               fill=(232, 179, 57, 70))
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.04))
    img.alpha_composite(glow)
    d = ImageDraw.Draw(img)
    trefoil(d, cx, cy, R, GOLD)
    d.ellipse([cx - R * 0.2, cy - R * 0.2, cx + R * 0.2, cy + R * 0.2],
              fill=(24, 26, 18, 255))
    d.ellipse([cx - R * 0.12, cy - R * 0.12, cx + R * 0.12, cy + R * 0.12], fill=GOLD_HI + (255,))
    # потёртости: выедаем шумом
    a = np.array(img)
    m = np.random.default_rng(5).random((size, size)) < 0.06
    a[m, 3] = (a[m, 3] * 0.75).astype(np.uint8)
    img = Image.fromarray(a)
    return img


def rounded(img, radius, corner_fill=(10, 12, 9, 255)):
    """Скруглить углы (для desktop icon — маска альфой)."""
    mask = Image.new('L', img.size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, img.size[0] - 1, img.size[1] - 1], radius=radius, fill=255)
    out = img.copy()
    out.putalpha(mask)
    return out


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    # 1) основная иконка 256 (config/icon), скруглённая
    draw_icon(256).resize((256, 256), Image.LANCZOS)
    icon = draw_icon(512).resize((256, 256), Image.LANCZOS)
    rounded(icon, 44).save(f'{OUT}\\icon_256.png')
    print('icon_256.png')
    # 2) Android main launcher 192 (полный квадрат, маску накинет лаунчер)
    draw_icon(192).save(f'{OUT}\\main_192x192.png')
    print('main_192x192.png')
    # 3) adaptive foreground 432: трефойл в безопасной зоне (66% центра), прозрачный фон
    fg = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
    d = ImageDraw.Draw(fg)
    cx = cy = 216
    R = 432 * 0.20  # 20% от 432 = внутри safe zone (66% диаметр)
    glow = Image.new('RGBA', (432, 432), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([cx - R * 1.4, cy - R * 1.4, cx + R * 1.4, cy + R * 1.4], fill=(232, 179, 57, 80))
    fg.alpha_composite(glow.filter(ImageFilter.GaussianBlur(10)))
    d = ImageDraw.Draw(fg)
    trefoil(d, cx, cy, R, GOLD)
    d.ellipse([cx - R * 0.2, cy - R * 0.2, cx + R * 0.2, cy + R * 0.2], fill=(0, 0, 0, 0))
    fg.save(f'{OUT}\\adaptive_foreground_432x432.png')
    print('adaptive_foreground_432x432.png')
    # 4) adaptive background 432: тёмная текстура с болотным кольцом
    b = bg(432, 432).convert('RGBA')
    d = ImageDraw.Draw(b)
    d.ellipse([216 - 150, 216 - 150, 216 + 150, 216 + 150], outline=SWAMP + (160,), width=8)
    a = np.array(b).astype(np.int16)
    n = np.random.default_rng(9).integers(-3, 4, (432, 432, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    Image.fromarray(a.astype(np.uint8)).save(f'{OUT}\\adaptive_background_432x432.png')
    print('adaptive_background_432x432.png')
