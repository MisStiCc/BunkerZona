# -*- coding: utf-8 -*-
# ЗАДАЧА 10: models/props/Textures/colormap.png — объединённая приглушённая
# палитра Kenney (car-kit + graveyard-kit) под пост-советскую Припять.
# Ячейки 8x8 по 64px (512x512). Конфликтные ячейки (стекло машин/фонарь) —
# тёплый янтарный компромисс.
import colorsys

from PIL import Image

CAR = 'C:/Users/VB/AppData/Local/Temp/pp10/carx/Models/GLB format/Textures/colormap.png'
GRAVE = 'C:/Users/VB/AppData/Local/Temp/pp10/gravex/Models/GLB format/Textures/colormap.png'
OUT = 'C:/Users/VB/AppData/Local/Temp/pp10/merged_colormap.png'

# ячейки фактического сэмплирования (из UV декодирования пропсов 3db9523)
CAR_CELLS = {
    (2, 3), (2, 4), (2, 6), (3, 3), (3, 4), (3, 6),
    (4, 2), (4, 3), (4, 5), (4, 6),
    (5, 2), (5, 3), (5, 5), (5, 6),
    (6, 0), (6, 1), (6, 2),
    (7, 0), (7, 1), (7, 2),
}
GRAVE_CELLS = {(5, 1), (6, 7), (7, 7), (4, 1)}
# пересечение: стекло машин (каровая палитра) и фонарь (кладбищенская) — янтарь
CONFLICT = {(4, 5): (196, 148, 84), (5, 5): (170, 124, 70), (5, 6): (226, 186, 118)}


def cell_color(img, r, c):
    return img.getpixel((c * 64 + 32, r * 64 + 32))[:3]


def mute(rgb, desat=0.35, dark=0.78, warm=1.04):
    """Приглушение: десатурация + затемнение + лёгкий тёплый сдвиг."""
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in rgb))
    s *= (1.0 - desat)
    l *= dark
    r, g, b = (v * 255 for v in colorsys.hls_to_rgb(h, l, s))
    return (min(255, r * warm), g, b)


car_img = Image.open(CAR).convert('RGB')
grave_img = Image.open(GRAVE).convert('RGB')
canvas = Image.new('RGB', (512, 512), (24, 24, 22))

for r in range(8):
    for c in range(8):
        cell = (r, c)
        if cell in CONFLICT:
            col = CONFLICT[cell]
        elif cell in CAR_CELLS:
            col = mute(cell_color(car_img, r, c))
        elif cell in GRAVE_CELLS:
            col = mute(cell_color(grave_img, r, c))
        else:
            continue  # неиспользуемые ячейки остаются тёмными
        px = Image.new('RGB', (64, 64), tuple(int(v) for v in col))
        canvas.paste(px, (c * 64, r * 64))

canvas.save(OUT)
print('готово:', OUT, canvas.size)
