# -*- coding: utf-8 -*-
# ЗАДАЧА 39: фон главного меню «ЗОНА ДЫШИТ» — ржавые ЛЭП, туман,
# ЧАЭС-саркофаг вдали, гроза, вороньё. Процедурно, CC0.
import math
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = r'E:\StalkerRevert\StalkerRevert\inbox\menu_background'


def make_scene(W, H, seed=39):
    r = random.Random(seed)
    img = Image.new('RGBA', (W, H))
    d = ImageDraw.Draw(img, 'RGBA')

    # --- грозовое небо: тёмно-серо-синий верх -> болотный горизонт ---
    yy = np.mgrid[0:H, 0:W][0].reshape(H, W, 1) / H
    top = np.array([26, 30, 40], dtype=np.float32)
    mid = np.array([52, 52, 48], dtype=np.float32)
    bot = np.array([70, 66, 50], dtype=np.float32)
    sky = top + (mid - top) * (yy / 0.62)
    sky += (bot - mid) * np.clip((yy - 0.62) / 0.38, 0, 1)
    horizon = int(H * 0.62)
    # зарево грозы за саркофагом (справа)
    gx, gy = W * 0.74, horizon * 0.8
    dd = np.sqrt(((np.mgrid[0:H, 0:W][1] - gx) / (W * 0.24)) ** 2 +
                 ((np.mgrid[0:H, 0:W][0] - gy) / (H * 0.18)) ** 2)
    sky += np.clip(1 - dd, 0, 1)[..., None] * np.array([90, 70, 30], dtype=np.float32)[None, None, :]
    base = Image.fromarray(np.clip(sky, 0, 255).astype(np.uint8)).convert('RGBA')
    d = ImageDraw.Draw(base, 'RGBA')

    # --- тучи ---
    cloud = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cd = ImageDraw.Draw(cloud)
    for _ in range(90):
        cx, cy = r.uniform(0, W), r.uniform(0, horizon * 0.9)
        rx, ry = r.uniform(W * 0.05, W * 0.16), r.uniform(H * 0.02, H * 0.06)
        shade = r.randint(24, 52)
        cd.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=(shade, shade + 2, shade + 6, 90))
    cloud = cloud.filter(ImageFilter.GaussianBlur(H * 0.012))
    base.alpha_composite(cloud)

    # --- молния вдали ---
    d = ImageDraw.Draw(base, 'RGBA')
    lx, ly = W * (0.60 if W > H else 0.70), H * (0.14 if W > H else 0.10)
    pts = [(lx, ly)]
    while pts[-1][1] < horizon * 0.72:
        pts.append((pts[-1][0] + r.uniform(-28, 28), pts[-1][1] + r.uniform(24, 46)))
    d.line(pts, fill=(255, 240, 200, 200), width=3)
    d.line([(p[0] + 3, p[1]) for p in pts], fill=(255, 220, 150, 90), width=7)
    flash = radial_img(W, H, pts[len(pts) // 2][0], pts[len(pts) // 2][1], W * 0.14, (255, 230, 170), 70)
    base.alpha_composite(flash)

    # --- ЧАЭС-саркофаг на горизонте (справа) ---
    d = ImageDraw.Draw(base, 'RGBA')
    sx, sy = W * 0.70, horizon
    sw, sh = W * 0.19, H * 0.13
    d.polygon([(sx - sw / 2, sy), (sx - sw * 0.36, sy - sh), (sx + sw * 0.36, sy - sh * 0.92),
               (sx + sw / 2, sy)], fill=(36, 39, 36, 255))
    d.polygon([(sx - sw * 0.2, sy - sh * 0.55), (sx + sw * 0.28, sy - sh * 0.5),
               (sx + sw * 0.25, sy - sh * 0.12), (sx - sw * 0.16, sy - sh * 0.14)],
              fill=(48, 52, 44, 255))
    # труба-вентиляция
    d.rectangle([sx + sw * 0.3, sy - sh * 1.25, sx + sw * 0.34, sy - sh * 0.4], fill=(26, 28, 26, 255))
    # тёплое окно-огонёк
    d.rectangle([sx - sw * 0.06, sy - sh * 0.3, sx - sw * 0.02, sy - sh * 0.22],
                fill=(255, 190, 90, 170))

    # --- мёртвые деревья на среднем плане ---
    for _ in range(14):
        tx = r.uniform(0, W)
        if W * 0.3 < tx < W * 0.75:
            continue
        th = r.uniform(H * 0.06, H * 0.14)
        ty = horizon + r.uniform(-H * 0.01, H * 0.02)
        d.line([tx, ty, tx + r.uniform(-8, 8), ty - th], fill=(14, 14, 12, 255), width=max(2, int(th * 0.06)))
        for _ in range(4):
            bx = tx + r.uniform(-10, 10)
            by = ty - r.uniform(th * 0.4, th * 0.9)
            d.line([bx, by, bx + r.uniform(-16, 16), by - r.uniform(8, 22)],
                   fill=(14, 14, 12, 255), width=2)

    # --- ЛЭП вышки (ржавые фермы, 2 ближних справа-слева) ---
    def pylon(px, pw, ph, base_y, alpha=255):
        col = (30, 26, 20, alpha)
        # опоры
        d.polygon([(px - pw / 2, base_y), (px - pw * 0.18, base_y - ph), (px - pw * 0.05, base_y - ph),
                   (px - pw * 0.38, base_y)], fill=col)
        d.polygon([(px + pw / 2, base_y), (px + pw * 0.18, base_y - ph), (px + pw * 0.05, base_y - ph),
                   (px + pw * 0.38, base_y)], fill=col)
        # траверсы
        for k, ty in enumerate((base_y - ph * 0.78, base_y - ph * 0.9, base_y - ph * 0.98)):
            tw = pw * (1.15 - k * 0.22)
            d.line([px - tw, ty, px + tw, ty], fill=col, width=max(3, int(ph * 0.014)))
        # перекладины решётки
        y = base_y
        while y > base_y - ph + 14:
            d.line([px - pw * (0.44 * (base_y - y) / ph + 0.14), y,
                    px + pw * (0.44 * (base_y - y) / ph + 0.14), y - 16], fill=col, width=2)
            y -= 34
        # провисшие провода
        for ty in (base_y - ph * 0.78, base_y - ph * 0.9):
            sag_pts = [(px + tw * 0.9 + i * 26, ty + 18 * math.sin(i / 12.0 * math.pi))
                       for i in range(13)]
            d.line(sag_pts, fill=(26, 24, 20, alpha - 40), width=2)

    pylon(W * 0.16, W * 0.05, H * 0.30, horizon + H * 0.05)
    pylon(W * 0.30, W * 0.032, H * 0.20, horizon + H * 0.03, alpha=220)

    # --- туманы ---
    fog = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fog)
    for _ in range(34):
        x, y = r.uniform(0, W), r.uniform(horizon - H * 0.05, H)
        rx, ry = r.uniform(W * 0.1, W * 0.28), r.uniform(H * 0.015, H * 0.045)
        fd.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(150, 152, 138, 26))
    fog = fog.filter(ImageFilter.GaussianBlur(H * 0.008))
    base.alpha_composite(fog)

    # --- земля: тёмная нижняя треть (спокойная под кнопки) ---
    d = ImageDraw.Draw(base, 'RGBA')
    d.rectangle([0, int(H * 0.72), W, H], fill=(16, 17, 14, 255))
    for _ in range(30):
        x, y = r.uniform(0, W), r.uniform(H * 0.73, H)
        rr = r.uniform(20, 70)
        d.ellipse([x - rr, y - rr * 0.3, x + rr, y + rr * 0.3], fill=(20, 22, 17, 120))
    # туман стелется по земле
    groundfog = Image.new('RGBA', (W, int(H * 0.3)), (0, 0, 0, 0))
    gfd = ImageDraw.Draw(groundfog)
    for _ in range(20):
        x, y = r.uniform(0, W), r.uniform(0, H * 0.3)
        rx, ry = r.uniform(W * 0.12, W * 0.3), r.uniform(10, 30)
        gfd.ellipse([x - rx, y - ry, x + rx, y + ry], fill=(140, 142, 128, 20))
    groundfog = groundfog.filter(ImageFilter.GaussianBlur(H * 0.01))
    base.alpha_composite(groundfog, (0, int(H * 0.7)))

    # --- вороньё ---
    d = ImageDraw.Draw(base, 'RGBA')
    for _ in range(9):
        x, y = r.uniform(W * 0.15, W * 0.9), r.uniform(H * 0.08, H * 0.3)
        s = r.uniform(4, 9)
        c = (10, 10, 10, 230)
        d.line([x - s, y - s * 0.5, x, y], fill=c, width=2)
        d.line([x, y, x + s, y - s * 0.5], fill=c, width=2)

    # --- зерно ---
    a = np.array(base).astype(np.int16)
    n = np.random.default_rng(seed).integers(-4, 5, (H, W, 1))
    a[..., :3] = np.clip(a[..., :3] + n, 0, 255)
    return Image.fromarray(a.astype(np.uint8)).convert('RGB')


def radial_img(w, h, cx, cy, r, color, alpha):
    m = np.zeros((h, w, 4), dtype=np.uint8)
    yy, xx = np.mgrid[0:h, 0:w]
    dd = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / r
    m[..., 0], m[..., 1], m[..., 2] = color
    m[..., 3] = (np.clip(1 - dd, 0, 1) ** 2.2 * alpha).astype(np.uint8)
    return Image.fromarray(m)


if __name__ == '__main__':
    import os
    os.makedirs(OUT, exist_ok=True)
    make_scene(1920, 1080, 39).save(os.path.join(OUT, 'menu_bg.png'))
    print('menu_bg.png')
    make_scene(1080, 1920, 139).save(os.path.join(OUT, 'menu_bg_v.png'))
    print('menu_bg_v.png')
