# -*- coding: utf-8 -*-
# ЗАДАЧА 30: логотип «БУНКЕР: ЗОНА» — Impact, золото с тёмной обводкой,
# скол/потёртости в стиле mode_ui. Прозрачный фон.
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\logo'
FONT = r'C:\Windows\Fonts\impact.ttf'
GOLD = (232, 179, 57)
GOLD_HI = (255, 218, 120)
DARK = (16, 14, 8)


def render(text, font_size, pad, two_line=False):
    font = ImageFont.truetype(FONT, font_size)
    tmp = Image.new('RGBA', (10, 10))
    td = ImageDraw.Draw(tmp)
    if two_line:
        lines = text.split('\n')
        w1 = td.textbbox((0, 0), lines[0], font=font)[2]
        w2 = td.textbbox((0, 0), lines[1], font=font)[2]
        W = max(w1, w2) + pad * 2
        H = int(font_size * 1.18 * 2) + pad * 2
    else:
        bb = td.textbbox((0, 0), text, font=font)
        W = bb[2] - bb[0] + pad * 2
        H = bb[3] - bb[1] + pad * 2
    img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    bottoms = []

    def stamp(y0, line):
        # тёмная обводка (толстая, несколько проходов)
        for off in [(0, 5), (0, -5), (5, 0), (-5, 0), (4, 4), (-4, 4), (4, -4), (-4, -4)]:
            d.text((pad + off[0], y0 + pad + off[1]), line, font=font, fill=DARK + (255,))
        # золотая заливка с вертикальным градиентом
        grad = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        gd = ImageDraw.Draw(grad)
        gd.text((pad, y0 + pad), line, font=font, fill=GOLD + (255,))
        arr = np.array(grad).astype(np.float32)
        rows = np.linspace(1.18, 0.72, H).reshape(H, 1, 1)
        arr[..., :3] = np.clip(arr[..., :3] * rows, 0, 255)
        img.alpha_composite(Image.fromarray(arr.astype(np.uint8)))
        # верхний блик
        hl = Image.new('RGBA', (W, H), (0, 0, 0, 0))
        hd = ImageDraw.Draw(hl)
        hd.text((pad, y0 + pad), line, font=font, fill=(255, 240, 190, 110))
        hl_arr = np.array(hl)
        hl_arr[int(pad + font_size * 0.12):int(pad + font_size * 0.42), :, 3] = 0
        img.alpha_composite(Image.fromarray(hl_arr))
        bb2 = d.textbbox((pad, y0 + pad), line, font=font)
        bottoms.append(bb2[3])

    if two_line:
        stamp(0, text.split('\n')[0])
        stamp(int(font_size * 1.18), text.split('\n')[1])
    else:
        stamp(0, text)

    # сколы/потёртости: выедаем шумом
    a = np.array(img)
    r = np.random.default_rng(30)
    m = r.random((H, W)) < 0.085
    a[..., 3] = np.where(m, (a[..., 3] * 0.25).astype(np.uint8), a[..., 3])
    # рваная нижняя кромка (треугольные выщербины)
    out = Image.fromarray(a)
    d2 = ImageDraw.Draw(out)
    bb = d2.textbbox((pad, pad), text.split('\n')[0], font=font)
    base_y = (bb[3] + 6) if not two_line else int(font_size * 1.18) + int(pad * 0.2)
    x = pad
    while x < W - pad:
        step = int(r.integers(14, 34))
        depth = int(r.integers(0, 14))
        d2.polygon([(x, base_y - 4), (x + step, base_y - 4), (x + step // 2, base_y - 4 - depth)],
                   fill=(0, 0, 0, 0))
        x += step
    return out


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    wide = render('БУНКЕР: ЗОНА', 150, 40)
    wide.save(f'{OUT}\\logo_wide.png')
    print('logo_wide.png', wide.size)
    stack = render('БУНКЕР\nЗОНА', 190, 46, two_line=True)
    stack.save(f'{OUT}\\logo_stack.png')
    print('logo_stack.png', stack.size)
