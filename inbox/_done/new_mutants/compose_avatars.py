# Композ аватарок 256px: градиент роли + свечение + модель крупным планом.
import os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'models_anim', 'avatar_raw')
OUTDIR = r'E:\StalkerRevert\StalkerRevert\inbox\mutant_avatars'
os.makedirs(OUTDIR, exist_ok=True)
S = 256
ROLE = {
    'kremen': ((32, 36, 40), (74, 70, 48)),
    'rzhavnik': ((32, 36, 40), (74, 70, 48)),
    'sporonosets': ((14, 34, 20), (44, 74, 36)),
    'chrevo': ((14, 34, 20), (44, 74, 36)),
    'iskropluy': ((38, 16, 12), (86, 42, 18)),
    'kosar': ((38, 16, 12), (86, 42, 18)),
    'mayak': ((24, 16, 40), (58, 36, 80)),
    'horovod': ((24, 16, 40), (58, 36, 80)),
}


def radial_glow(size, color, alpha):
    g = Image.new('L', (size, size), 0)
    d = ImageDraw.Draw(g)
    steps = 24
    for i in range(steps, 0, -1):
        r = int(size * 0.48 * i / steps)
        a = int(alpha * (1 - i / steps) ** 1.6)
        d.ellipse([size//2 - r, size//2 - r, size//2 + r, size//2 + r], fill=a)
    layer = Image.new('RGBA', (size, size), color + (0,))
    layer.putalpha(g)
    return layer


for name, (top, bot) in ROLE.items():
    bg = Image.new('RGB', (S, S))
    px = bg.load()
    for y in range(S):
        t = y / (S - 1)
        px_row = (int(top[0] + (bot[0] - top[0]) * t),
                  int(top[1] + (bot[1] - top[1]) * t),
                  int(top[2] + (bot[2] - top[2]) * t))
        for x in range(S):
            px[x, y] = px_row
    card = bg.convert('RGBA')
    glow_c = tuple(min(255, c + 70) for c in bot)
    card.alpha_composite(radial_glow(S, glow_c, 100))
    if name == 'iskropluy':
        # голова из карточного рендера (в 3D-кадре прячется за телом)
        src = Image.open(os.path.join(HERE, 'models_anim', 'card_raw', 'iskropluy.png')).convert('RGBA')
        fg = src.crop((50, 0, 500, 360))
    else:
        fg = Image.open(os.path.join(RAW, name + '.png')).convert('RGBA')
    fg.thumbnail((S - 20, S - 20), Image.LANCZOS)
    card.alpha_composite(fg, ((S - fg.width) // 2, (S - fg.height) // 2))
    # виньетка мягче, чем у карточек
    vig = Image.new('L', (S, S), 0)
    dv = ImageDraw.Draw(vig)
    dv.rectangle([0, 0, S, S], fill=70)
    dv.ellipse([-S * 0.35, -S * 0.35, S * 1.35, S * 1.35], fill=0)
    vig = vig.filter(ImageFilter.GaussianBlur(30))
    dark = Image.new('RGBA', (S, S), (0, 0, 0, 255))
    dark.putalpha(vig)
    card.alpha_composite(dark)
    card.convert('RGB').save(os.path.join(OUTDIR, 'avatar_' + name + '.png'))
    print('AVATAR OK', name)
print('AVATARS DONE')
