# -*- coding: utf-8 -*-
# Добивка гильд-магазина: баннер-шапка (940x140, текста нет — Label лежит
# в коде) + 9-патч рамка карточек товаров (140x88, золото/фиолет).
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\guild_shop_art'
rng = np.random.default_rng(91)


def vgrad(w, h, top, bot, noise_amp=2.0, seed=5):
    img = Image.new('RGB', (w, h))
    px = img.load()
    n = np.random.default_rng(seed).normal(0, noise_amp, (h, w, 1))
    for y in range(h):
        t = y / (h - 1)
        r = top[0] + (bot[0] - top[0]) * t
        g = top[1] + (bot[1] - top[1]) * t
        b = top[2] + (bot[2] - top[2]) * t
        for x in range(w):
            k = n[y, x, 0]
            px[x, y] = (max(0, min(255, int(r + k))), max(0, min(255, int(g + k))),
                        max(0, min(255, int(b + k))))
    return img.convert('RGBA')


def torn(img, side, color=(6, 5, 8, 255), lo=8, hi=24):
    """Рваная кромка сверху (side='top') или снизу ('bottom')."""
    w, h = img.size
    d = ImageDraw.Draw(img)
    x = 0
    while x < w:
        w2 = int(rng.integers(24, 60))
        h2 = int(rng.integers(lo, hi))
        if side == 'top':
            d.polygon([(x, 0), (x + w2, 0), (x + w2 // 2, h2)], fill=color)
        else:
            d.polygon([(x, h), (x + w2, h), (x + w2 // 2, h - h2)], fill=color)
        x += w2
    return img


def glow_blob(d, cx, cy, rx, ry, color, alpha):
    steps = 12
    for i in range(steps, 0, -1):
        k = i / steps
        a = int(alpha * (1 - k) ** 1.6)
        d.ellipse([cx - rx * k, cy - ry * k, cx + rx * k, cy + ry * k], fill=color + (a,))


# ==================== БАННЕР 940x140 ====================
BW, BH = 940, 140
b = vgrad(BW, BH, (14, 10, 22), (40, 26, 58), seed=11)
# туман
fog = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
fd = ImageDraw.Draw(fog)
glow_blob(fd, 120, 70, 240, 90, (100, 60, 150), 55)
glow_blob(fd, 820, 70, 240, 90, (90, 55, 140), 50)
glow_blob(fd, 470, 60, 300, 80, (190, 130, 60), 34)
fog = fog.filter(ImageFilter.GaussianBlur(40))
b.alpha_composite(fog)
# центральная тёмная полоса под заголовок (Label читается поверх)
band = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
bd = ImageDraw.Draw(band)
bd.rectangle([90, 18, BW - 90, BH - 18], fill=(8, 6, 12, 150))
band = band.filter(ImageFilter.GaussianBlur(6))
b.alpha_composite(band)
# орнамент: монолит-水印 слева, расходящиеся лучи от центра
orn = Image.new('RGBA', (BW, BH), (0, 0, 0, 0))
od = ImageDraw.Draw(orn)
# малый монолит слева
cx, cy = 70, 74
od.polygon([(cx - 20, cy + 30), (cx + 20, cy + 30), (cx + 10, cy - 26),
            (cx, cy - 42), (cx - 10, cy - 26)], fill=(255, 214, 120, 90))
od.rectangle([cx - 6, cy + 2, cx + 6, cy + 14], fill=(255, 214, 120, 70))
# лучи-орбиты справа
for i in range(5):
    rr = 16 + i * 11
    od.arc([BW - 70 - rr, cy - rr, BW - 70 + rr, cy + rr], 200, 340,
           fill=(190, 140, 255, 70 - i * 8), width=3)
orn = orn.filter(ImageFilter.GaussianBlur(1))
b.alpha_composite(orn)
# золотые нити сверху и снизу
gd = ImageDraw.Draw(b)
gd.line([14, 6, BW - 14, 6], fill=(232, 178, 58, 200), width=2)
gd.line([14, BH - 6, BW - 14, BH - 6], fill=(232, 178, 58, 160), width=2)
# рваные кромки по краям серии
torn(b, 'top', lo=6, hi=16)
torn(b, 'bottom', lo=6, hi=16)
b.save(os.path.join(OUT, 'guild_shop_banner.png'))
print('BANNER OK')

# ==================== РАМКА КАРТОЧКИ 140x88 (9-патч) ====================
FW, FH = 140, 88
f = Image.new('RGBA', (FW, FH), (0, 0, 0, 0))
fd = ImageDraw.Draw(f)
cut = 14
pts = [(cut, 3), (FW - cut, 3), (FW - 3, cut), (FW - 3, FH - cut),
       (FW - cut, FH - 3), (cut, FH - 3), (3, FH - cut), (3, cut), (cut, 3)]
# полупрозрачная заливка центра (панель чуть темнее фона)
fd.polygon(pts, fill=(16, 11, 24, 200))
# золотая окантовка с внешней тенью-подложкой
fd.line(pts, fill=(60, 42, 12, 255), width=6)          # тёмная подложка
f2 = f.filter(ImageFilter.GaussianBlur(1))
fd2 = ImageDraw.Draw(f2)
fd2.line(pts, fill=(232, 178, 58, 255), width=3)       # золото
fd2.line([(cut - 6, 8), (FW - cut + 6, 8), (FW - 8, cut - 6), (FW - 8, FH - cut + 6),
          (FW - cut + 6, FH - 8), (cut - 6, FH - 8), (8, FH - cut + 6),
          (8, cut - 6), (cut - 6, 8)], fill=(120, 80, 160, 120), width=1)  # фиолетовый кант
# блик сверху (золото ярче на верхней кромке)
fd2.line([(cut, 4), (FW - cut, 4)], fill=(255, 214, 110, 220), width=2)
# заклёпки-уголки
for bx, by in [(cut - 4, cut - 4), (FW - cut + 4, cut - 4),
               (cut - 4, FH - cut + 4), (FW - cut + 4, FH - cut + 4)]:
    fd2.ellipse([bx - 3, by - 3, bx + 3, by + 3], fill=(255, 214, 120, 200))
f2.save(os.path.join(OUT, 'guild_card_frame.png'))
print('FRAME OK')
