# -*- coding: utf-8 -*-
# Скан захардкоженных RU-строк в коде: кривые слова/грамматика
import io
import os
import re

FILES = []
for root in ['ui', 'zones', 'core', 'data', 'managers', 'entities', 'components']:
    for dirpath, _, files in os.walk(root):
        if '.godot' in dirpath or '_done' in dirpath:
            continue
        for f in files:
            if f.endswith('.gd'):
                FILES.append(os.path.join(dirpath, f).replace('\\', '/'))

# словарь кривых/сленговых обрывков (lowercase, подстрока)
BAD = [
    'не зани', 'зани ', 'они умные',  # сленг онбординга
    'кашка', 'опробыв', 'вообщем', 'сдлелал', 'сделон', 'мутанте',
    'занять позицию ', 'паникуй',
    'жрёт', 'жрет', 'жрёт всё',  # разговорное
    'не фиг', 'нахрен', 'нехрен', 'заеб', 'хрен ',
    'Глухая карта глухая', 'мутации мутации',
    'бункера твой', 'твой бункер бункер',
]
# грамматические паттерны
PATTERNS = [
    (r'[а-яё]\.[А-ЯЁ]', 'NOSPACE_DOT'),
    (r'\b(и|в|на|не|по|за|что|как) \1\b', 'DUP_WORD'),
    (r'[а-яё]{2}[А-ЯЁ]{1}[а-яё]{1,}', 'MIXCASE'),
]

issues = []
for path in FILES:
    try:
        s = io.open(path, encoding='utf-8').read()
    except Exception:
        continue
    # только строковые литералы с кириллицей
    for m in re.finditer(r'"((?:[^"' + chr(92) + '"]|' + chr(92) + '.)*)"', s):
        st = m.group(1)
        if not re.search(r'[а-яё]', st, re.IGNORECASE):
            continue
        low = st.lower()
        for bad in BAD:
            if bad in low:
                issues.append((path, 'SLANG:' + bad, st[:100]))
        for pat, name in PATTERNS:
            if re.search(pat, st):
                issues.append((path, name, st[:100]))

print('TOTAL_FLAGS:', len(issues))
seen = set()
for path, flag, st in issues:
    sig = flag + st[:60]
    if sig in seen:
        continue
    seen.add(sig)
    print(path, '|', flag, '|', st)
