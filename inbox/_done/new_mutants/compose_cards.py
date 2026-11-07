# Композ карточек: градиент роли + свечение + рамка редкости, 620px, цвет/серая.
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageOps

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, 'models_anim', 'card_raw')
CARDS = os.path.join(HERE, 'cards')
GRAY = os.path.join(CARDS, 'gray')
os.makedirs(GRAY, exist_ok=True)

S = 620
ROLE = {
    'TANK': ((32, 36, 40), (74, 70, 48)),
    'HEAL': ((14, 34, 20), (44, 74, 36)),
    'DMG':  ((38, 16, 12), (86, 42, 18)),
    'BUFF': ((24, 16, 40), (58, 36, 80)),
}
RARITY = {
    'uncommon': (122, 168, 96),
    'rare': (90, 160, 216),
    'epic': (176, 96, 216),
    'legendary': (232, 178, 58),
}
M = {
    'kremen': ('TANK', 'uncommon'),
    'rzhavnik': ('TANK', 'rare'),
    'sporonosets': ('HEAL', 'uncommon'),
    'chrevo': ('HEAL', 'epic'),
    'iskropluy': ('DMG', 'rare'),
    'kosar': ('DMG', 'legendary'),
    'mayak': ('BUFF', 'uncommon'),
    'horovod': ('BUFF', 'legendary'),
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


for name, (role, rar) in M.items():
    top, bot = ROLE[role]
    bg = Image.new('RGB', (S, S))
    px = bg.load()
    for y in range(S):
        t = y / (S - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        for x in range(S):
            px[x, y] = (r, g, b)
    card = bg.convert('RGBA')
    # радиальное свечение за моделью
    glow_c = tuple(min(255, c + 70) for c in bot)
    card.alpha_composite(radial_glow(S, glow_c, 110))
    # модель
    fg = Image.open(os.path.join(RAW, f'{name}.png')).convert('RGBA')
    fg.thumbnail((S - 36, S - 36), Image.LANCZOS)
    fg = ImageEnhance.Contrast(fg).enhance(1.05)
    # тень под моделью
    sh = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    alpha = fg.split()[3]
    foot = alpha.crop((0, max(0, fg.height - 40), fg.width, fg.height))
    foot_w = int(fg.width * 1.15)
    foot = foot.resize((foot_w, max(6, foot.height // 3)))
    sh.paste(foot, ((S - foot_w)//2, S - 44 - foot.height))
    r_, g_, b_, a_ = sh.split()
    a_ = a_.point(lambda v: v * 45 // 100)
    sh = Image.merge('RGBA', (r_, g_, b_, a_))
    sh = sh.filter(ImageFilter.GaussianBlur(9))
    card.alpha_composite(sh)
    card.alpha_composite(fg, ((S - fg.width)//2, S - 24 - fg.height))
    # виньетка
    vig = Image.new('L', (S, S), 0)
    dv = ImageDraw.Draw(vig)
    dv.rectangle([0, 0, S, S], fill=90)
    dv.ellipse([-S*0.35, -S*0.35, S*1.35, S*1.35], fill=0)
    vig = vig.filter(ImageFilter.GaussianBlur(40))
    dark = Image.new('RGBA', (S, S), (0, 0, 0, 255))
    dark.putalpha(vig)
    card.alpha_composite(dark)
    # рамка редкости
    rim = RARITY[rar]
    d = ImageDraw.Draw(card)
    d.rectangle([0, 0, S-1, S-1], outline=rim + (255,), width=10)
    d.rectangle([10, 10, S-11, S-11], outline=(10, 12, 10, 255), width=3)
    out = os.path.join(CARDS, f'{name}.png')
    card.convert('RGB').save(out)
    # серая
    gr = ImageOps.grayscale(card.convert('RGB')).convert('RGB')
    gr = ImageEnhance.Brightness(gr).enhance(0.85)
    gr.save(os.path.join(GRAY, f'{name}.png'))
    print('CARD OK', name, role, rar)

print('CARDS DONE')
