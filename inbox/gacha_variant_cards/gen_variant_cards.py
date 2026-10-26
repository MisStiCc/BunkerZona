# -*- coding: utf-8 -*-
# ЗАДАЧА 11: карточки вариантов мутантов из EXCLUSIVE_MUTANTS (data/gacha_data.gd).
# Метод по заданию: копия SVG базы, основные цвета fill умножаются на tint,
# glow-ореол (halo/рамка/заклёпки/глаз) перекрашивается в accent варианта.
import os
import re

ROOT = r'E:\StalkerRevert\StalkerRevert'
CARDS = os.path.join(ROOT, 'ui', 'cards')
DATA = os.path.join(ROOT, 'data', 'gacha_data.gd')
MODELS = os.path.join(ROOT, 'models')

# --- 1. Разбор EXCLUSIVE_MUTANTS ------------------------------------------------
src = open(DATA, encoding='utf-8').read()
m = re.search(r'const EXCLUSIVE_MUTANTS := \[(.*?)\n\]', src, re.S)
block = m.group(1)
entries = []
cur = {}
for tok in re.finditer(r'"(\w+)":\s*("[^"]*"|\[[^\]]*\]|[\d.]+)', block):
    key, val = tok.group(1), tok.group(2)
    if key == 'type' and cur:
        entries.append(cur)
        cur = {}
    if key in ('type', 'base', 'accent'):
        cur[key] = val.strip('"')
    elif key == 'tint':
        cur['tint'] = [float(x) for x in re.findall(r'[\d.]+', val)]
if cur:
    entries.append(cur)
print(f'вариантов в данных: {len(entries)}')

HEX_RE = re.compile(r'#[0-9a-fA-F]{6}\b')


def clamp(v):
    return max(0, min(255, int(round(v))))


def mul_hex(hexc, tint):
    r = clamp(int(hexc[1:3], 16) * tint[0])
    g = clamp(int(hexc[3:5], 16) * tint[1])
    b = clamp(int(hexc[5:7], 16) * tint[2])
    return f'#{r:02x}{g:02x}{b:02x}'


def make_variant(base_svg: str, tint, accent: str) -> str:
    base_accent_m = re.search(
        r'id="halo".*?stop-color="(#[0-9a-fA-F]{6})"', base_svg, re.S)
    base_accent = base_accent_m.group(1).lower() if base_accent_m else None
    # фон карточки тонирован мягче (tint*0.45+0.55), чтобы силуэт читался;
    # у тела — нижний порог яркости, чтобы тёмные масти не тонули в фоне
    bg_tint = [t * 0.45 + 0.55 for t in tint]

    # границы секции фона: от id="bg" до закрывающего </linearGradient>
    bg_zone = re.search(r'id="bg".*?</linearGradient>', base_svg, re.S)
    bg_span = bg_zone.span() if bg_zone else (len(base_svg), len(base_svg))

    def repl_factory(start: int):
        def repl(m):
            c = m.group(0)
            cl = c.lower()
            if cl == '#000000' or cl == '#ffffff':
                return c  # тени и блики не трогаем
            if base_accent and cl == base_accent:
                return '#' + accent.lower()  # glow-ореол -> accent варианта
            use_tint = bg_tint if m.start() >= bg_span[0] and m.start() < bg_span[1] else tint
            hexm = mul_hex(cl, use_tint)
            if use_tint is tint:  # пол яркости только для тела
                r = max(int(hexm[1:3], 16), 28)
                g = max(int(hexm[3:5], 16), 28)
                b = max(int(hexm[5:7], 16), 28)
                hexm = f'#{r:02x}{g:02x}{b:02x}'
            return hexm
        return repl

    return HEX_RE.sub(repl_factory(0), base_svg)


made, skipped = [], []
for e in entries:
    t, base, tint, accent = e['type'], e['base'], e['tint'], e['accent']
    dst = os.path.join(CARDS, f'mut_{t}.svg')
    if os.path.exists(dst):
        skipped.append(t)
        continue
    srcf = os.path.join(CARDS, f'mut_{base}.svg')
    if not os.path.exists(srcf):
        print(f'!! нет базы {base} для {t}')
        continue
    svg = open(srcf, encoding='utf-8').read()
    open(dst, 'w', encoding='utf-8', newline='\n').write(make_variant(svg, tint, accent))
    made.append(t)

print('создано:', ', '.join(made))
print('уже были (не тронуты):', ', '.join(skipped))

# --- 2. ЧАСТЬ В: ревизия моделей баз -------------------------------------------
print('\nревизия моделей (models/ и models/animals/):')
missing = []
for e in entries:
    base = e['base']
    found = None
    for sub in ('', 'animals'):
        p = os.path.join(MODELS, sub, f'{base}.glb')
        if os.path.exists(p):
            found = (p, os.path.exists(p + '.import'))
            break
    if not found:
        missing.append(base)
        print(f'  НЕТ МОДЕЛИ: {base}')
    elif not found[1]:
        print(f'  без .import: {base}')
if not missing:
    print('  все базы на месте, все импортированы')
