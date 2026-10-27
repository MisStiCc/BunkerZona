# -*- coding: utf-8 -*-
# ЗАДАЧА 19: PNG-карточки вариантов мутантов уровня арта художника.
# Метод: живописный артовый реколор базы тинтом варианта (из EXCLUSIVE_MUTANTS)
# с защитой теней/рамки; для аномалий-вариантов - процедурный центр + рамка
# с реальной PNG-карточки; серые версии в ui/cards/gray/.
import math

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

CARDS = r'E:\StalkerRevert\StalkerRevert\ui\cards'
rng = np.random.default_rng(19)

# вариант -> (база, tint) — ровно из data/gacha_data.gd EXCLUSIVE_MUTANTS
VARIANTS = {
    'alpha_pseudodog':        ('mut_pseudodog',        [1.9, 1.85, 1.8]),
    'ash_snork':              ('mut_snork_mutant',     [0.56, 0.55, 0.52]),
    'obsidian_controller':    ('mut_controller_mutant', [0.5, 0.44, 0.6]),
    'dvoroviy_pes':           ('mut_dog_mutant',       [0.7, 0.68, 0.66]),
    'tuhlaya_plot':           ('mut_flesh',            [0.72, 0.85, 0.6]),
    'gniloy_zombie':          ('mut_zombie',           [0.62, 0.72, 0.58]),
    'brodyashiy_snork':       ('mut_snork_mutant',     [0.75, 0.65, 0.5]),
    'besheniy_pes':           ('mut_dog_mutant',       [0.8, 0.5, 0.45]),
    'tolstaya_plot':          ('mut_flesh',            [1.05, 0.85, 0.85]),
    'lutiy_pseudodog':        ('mut_pseudodog',        [0.85, 0.55, 0.5]),
    'mercayushiy_poltergeist': ('mut_poltergeist',     [0.6, 0.9, 0.95]),
    'nochnoy_krovosos':       ('mut_bloodsucker',      [0.45, 0.5, 0.6]),
    'psi_controller':         ('mut_controller_mutant', [0.7, 0.55, 0.95]),
    'krovaviy_snork':         ('mut_snork_mutant',     [0.9, 0.4, 0.4]),
    'ten_pseudodog':          ('mut_pseudodog',        [0.4, 0.4, 0.45]),
    'crimson_chimera':        ('mut_chimera',          [1.15, 0.35, 0.3]),
    'obsidian_titan':         ('mut_pseudogiant',      [0.35, 0.32, 0.38]),
}

ANOMALIES = ['ash_tornado', 'crimson_heat', 'void_loop']


def smoothstep(x, a, b):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def recolor(img, tint):
    """Живописный реколор: пер-канальное умножение с защитой теней (рамка/тени
    почти не меняются), мягкий клип светов, десатурация для ярких мастей."""
    a = np.asarray(img.convert('RGB')).astype(np.float32) / 255.0
    luma = a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    w = smoothstep(luma, 0.05, 0.32)[..., None]           # 0 — рамка/тени
    tinted = a * np.asarray(tint, dtype=np.float32)
    out = a * (1 - w) + tinted * w
    # мягкий клип светов (без жёсткой резки)
    out = 1.0 - np.exp(-out * 1.25)
    # яркие масти (tint_luma > 1) тянутся к белому: десатурация
    tint_luma = 0.299 * tint[0] + 0.587 * tint[1] + 0.114 * tint[2]
    ds = np.clip((tint_luma - 1.0) * 0.9, 0.0, 0.8)
    if ds > 0:
        g = out.mean(axis=2, keepdims=True)
        out = out * (1 - ds) + g * ds
    return Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8))


def gray_version(img):
    """Серая версия для ui/cards/gray/ (как у существующих)."""
    a = np.asarray(img.convert('RGB')).astype(np.float32)
    g = (a[..., 0] * 0.3 + a[..., 1] * 0.59 + a[..., 2] * 0.11)[..., None]
    out = a * 0.25 + g * 0.75
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8))


# ---------------------------------------------------------------- аномалии
def frame_of(sample_path):
    """Рамка с реальной PNG-карточки: всё, кроме внутреннего скруглённого окна."""
    base = Image.open(sample_path).convert('RGB')
    w, h = base.size
    mask = Image.new('L', (w, h), 255)
    d = ImageDraw.Draw(mask)
    inset = 84
    d.rounded_rectangle([inset, inset, w - inset, h - inset], radius=52, fill=0)
    mask = mask.filter(ImageFilter.GaussianBlur(2))
    return base, mask


def painterly_bg(w, h, top, bottom):
    """Живописный тёмный фон: вертикальный градиент + крупные пятна + зерно."""
    yy = np.mgrid[0:h, 0:w][0].reshape(h, w, 1) / h
    top = np.array(top, dtype=np.float32) / 255.0
    bot = np.array(bottom, dtype=np.float32) / 255.0
    img = (top + (bot - top) * (yy ** 1.3)) * np.ones((h, w, 1), dtype=np.float32)
    # пятна облаков/дыма
    for _ in range(26):
        cx, cy = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(w * 0.12, w * 0.4)
        shade = rng.uniform(0.75, 1.2)
        m = np.clip(1 - np.sqrt((np.mgrid[0:h, 0:w][1] - cx) ** 2 + (np.mgrid[0:h, 0:w][0] - cy) ** 2) / r, 0, 1) ** 2
        img += (m * (shade - 1))[..., None] * img
    img = np.clip(img + rng.normal(0, 0.006, (h, w, 1)), 0, 1)
    from PIL import Image as _I
    return _I.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1))


def glow(d, xy, r, color, alpha):
    """Мягкое пятно слоями."""
    for k, rr in enumerate((r, r * 0.66, r * 0.4)):
        a = int(alpha * (0.35, 0.55, 0.9)[k])
        d.ellipse([xy[0] - rr, xy[1] - rr * 0.85, xy[0] + rr, xy[1] + rr * 0.85],
                  fill=color + (a,))


def anomaly_ash_tornado():
    w = h = 460
    img = painterly_bg(w, h, (30, 28, 24), (14, 13, 12)).convert('RGBA')
    lay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx = w // 2
    # столб смерча: сужающиеся эллипсы
    for i, (yf, rw, rh) in enumerate([(0.9, 0.14, 0.075), (0.76, 0.1, 0.07), (0.62, 0.08, 0.065),
                                      (0.48, 0.12, 0.07), (0.34, 0.2, 0.075), (0.2, 0.3, 0.085),
                                      (0.09, 0.4, 0.09)]):
        y = h * yf
        col = (168, 160, 148, 120 - i * 8)
        d.ellipse([cx - w * rw, y - h * rh, cx + w * rw, y + h * rh], fill=col)
        d.ellipse([cx - w * rw * 0.55, y - h * rh * 0.9, cx + w * rw * 0.55, y + h * rh * 0.6],
                  fill=(196, 190, 178, 90 - i * 8))
    lay = lay.filter(ImageFilter.GaussianBlur(6))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img, 'RGBA')
    # пепел
    for _ in range(90):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(1, 3.4)
        a = int(rng.uniform(40, 130))
        d.ellipse([x - r, y - r, x + r, y + r], fill=(210, 205, 195, a))
    # тлеющие угли у подножия
    for _ in range(12):
        x = cx + rng.uniform(-90, 90)
        y = h * 0.88 + rng.uniform(-14, 10)
        r = rng.uniform(1.5, 3.5)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, rng.integers(120, 170), 40, 200))
    return img


def anomaly_crimson_heat():
    w = h = 460
    img = painterly_bg(w, h, (44, 16, 10), (16, 6, 5)).convert('RGBA')
    lay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    # жар: слои свечения из центра
    glow(d, (w / 2, h * 0.58), w * 0.5, (255, 90, 20), 60)
    glow(d, (w / 2, h * 0.62), w * 0.3, (255, 140, 30), 90)
    # языки пламени: треугольники с блюром
    for i in range(9):
        x = w * (0.2 + 0.075 * i) + rng.uniform(-8, 8)
        base = h * 0.86
        top = base - rng.uniform(h * 0.25, h * 0.52)
        wd = rng.uniform(14, 30)
        d.polygon([(x - wd, base), (x + wd, base), (x + rng.uniform(-6, 6), top)],
                  fill=(255, rng.integers(70, 130), 10, 170))
    lay = lay.filter(ImageFilter.GaussianBlur(7))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img, 'RGBA')
    # искры
    for _ in range(46):
        x, y = rng.uniform(w * 0.2, w * 0.8), rng.uniform(h * 0.2, h * 0.9)
        r = rng.uniform(1, 3)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, rng.integers(150, 220), 60, 210))
    return img


def anomaly_void_loop():
    w = h = 460
    img = painterly_bg(w, h, (26, 18, 40), (10, 8, 18)).convert('RGBA')
    lay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay)
    cx, cy = w / 2, h * 0.5
    # петля: вложенные кольца-эллипсы с наклоном
    for i in range(6):
        r = w * (0.42 - i * 0.055)
        wd = 14 - i * 1.4
        a = 150 - i * 14
        bbox = [cx - r, cy - r * 0.62, cx + r, cy + r * 0.62]
        d.ellipse(bbox, outline=(168, 110, 255, a), width=max(3, int(wd)))
        d.ellipse([bbox[0] + 8, bbox[1] + 5, bbox[2] - 8, bbox[3] - 5],
                  outline=(120, 70, 220, a - 40), width=3)
    lay = lay.filter(ImageFilter.GaussianBlur(4))
    img.alpha_composite(lay)
    d = ImageDraw.Draw(img, 'RGBA')
    # ядро
    glow(d, (cx, cy), 42, (200, 150, 255), 120)
    # звёздная пыль
    for _ in range(40):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        r = rng.uniform(0.8, 2.2)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(220, 190, 255, rng.integers(60, 160)))
    return img


def corners_of(sample_path, size=118):
    """4 золотых уголка с реальной PNG-карточки."""
    base = Image.open(sample_path).convert('RGBA')
    w, h = base.size
    out = []
    for (x0, y0) in [(0, 0), (w - size, 0), (0, h - size), (w - size, h - size)]:
        out.append(base.crop((x0, y0, x0 + size, y0 + size)))
    return out


def compose_anomaly(name, center_img, corners):
    """Тёмный живописный фон -> центр в скруглённом окне -> рамка -> уголки арта."""
    W = H = 627
    out = painterly_bg(W, H, (26, 22, 18), (8, 7, 6)).convert('RGBA')
    # виньетка-рамка
    d = ImageDraw.Draw(out, 'RGBA')
    for i, wd in enumerate(range(30, 4, -5)):
        a = 40 + i * 14
        d.rounded_rectangle([i * 5, i * 5, W - i * 5, H - i * 5], radius=40 + i * 2,
                            outline=(10, 8, 6, a), width=wd)
    # окно центра
    inset = 84
    hole = Image.new('L', (W, H), 0)
    hd = ImageDraw.Draw(hole)
    hd.rounded_rectangle([inset, inset, W - inset, H - inset], radius=52, fill=255)
    hole = hole.filter(ImageFilter.GaussianBlur(1.5))
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    layer.paste(center_img.resize((W - 2 * inset, H - 2 * inset), Image.LANCZOS), (inset, inset))
    layer.putalpha(hole)
    out.alpha_composite(layer)
    # тонкая золотая окантовка окна
    d = ImageDraw.Draw(out, 'RGBA')
    d.rounded_rectangle([inset - 3, inset - 3, W - inset + 3, H - inset + 3], radius=54,
                        outline=(150, 118, 48, 200), width=4)
    # уголки арта
    cs = 118
    for (x, y), cimg in zip([(0, 0), (W - cs, 0), (0, H - cs), (W - cs, H - cs)], corners):
        out.alpha_composite(cimg, (x, y))
    return out.convert('RGB')


if __name__ == '__main__':
    import os
    made = []
    for var, (base, tint) in VARIANTS.items():
        src = Image.open(os.path.join(CARDS, base + '.png'))
        art = recolor(src, tint)
        art.save(os.path.join(CARDS, f'mut_{var}.png'))
        gray_version(art).save(os.path.join(CARDS, 'gray', f'mut_{var}.png'))
        made.append(var)
        print('вариант:', var, '<-', base)
    corners = corners_of(os.path.join(CARDS, 'mut_chimera.png'))
    for name, gen in [('ash_tornado', anomaly_ash_tornado),
                      ('crimson_heat', anomaly_crimson_heat),
                      ('void_loop', anomaly_void_loop)]:
        art = compose_anomaly(name, gen(), corners)
        art.save(os.path.join(CARDS, f'art_{name}.png'))
        gray_version(art).save(os.path.join(CARDS, 'gray', f'art_{name}.png'))
        made.append('art_' + name)
        print('аномалия:', name)
    print('всего:', len(made))
