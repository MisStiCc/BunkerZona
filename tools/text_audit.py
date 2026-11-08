# -*- coding: utf-8 -*-
# Аудит русских текстов: кривые слова, слипшаяся пунктуация, дубли слов,
# смешанный регист внутри слова, подозрительный сленг
import io
import re

s = io.open('core/localization.gd', encoding='utf-8').read()
lines = s.split(chr(10))

issues = []
for idx, ln in enumerate(lines, 1):
    if '"ru":' not in ln:
        continue
    k = ln.find('"ru": "')
    if k < 0:
        continue
    key_start = ln.rfind('"', 0, k)
    key = ln[key_start + 1:k]
    ru_start = k + len('"ru": "')
    ru_end = ln.find('"', ru_start)
    ru = ln[ru_start:ru_end]
    flags = []
    # 1. смешанный регист внутри слова (СЕЗОна / кАша)
    for w in re.findall(r'[А-Яа-яЁё]+', ru):
        if len(w) > 3 and re.search(r'[а-яё][А-ЯЁ]', w) and not w.isupper():
            flags.append('MIXCASE:' + w)
        if re.search(r'[А-ЯЁ][а-яё][А-ЯЁ]', w) and len(w) > 3:
            flags.append('MIXCASE2:' + w)
    # 2. слипшийся текст: слово.Слово без пробела
    if re.search(r'[а-яё]\.[А-ЯЁ]', ru):
        flags.append('NOSPACE_DOT')
    if re.search(r'[а-яё],[А-Яа-яЁё]', ru):
        flags.append('NOSPACE_COMMA')
    # 3. дубли слов подряд (и и / в в / не не)
    if re.search(r'\b(и|в|на|не|по|за|что|как) \1\b', ru, re.IGNORECASE):
        flags.append('DUP_WORD')
    # 4. тройные+ пробелы в середине
    if re.search(r'\S  +\S', ru):
        flags.append('MULTI_SPACE')
    # 5. подозрительный сленг/опечатки (словарь)
    for bad in ['зани ', 'зани.', 'кашка', 'опробыв', 'вообщем', 'течит ы',
                'сдлелал', 'мутантов с ', 'паникуешь', 'наделал']:
        if bad in ru.lower():
            flags.append('SLANG:' + bad.strip())
    # 6. битые плейсхолдеры {n } { n}
    if re.search(r'\{\s+[a-z]', ru) or re.search(r'[a-z]\s+\}', ru):
        flags.append('PLACEHOLDER')
    # 7. %d без аргументов не проверить, но %s %s рядом ок
    # 8. латиница внутри кириллического слова (omGETZа)
    if re.search(r'[а-яё][a-z]{2,}[а-яё]', ru, re.IGNORECASE):
        flags.append('LATIN_MIX')
    if flags:
        issues.append((idx, key, ru[:90], flags))

print('TOTAL_FLAGS:', len(issues))
for idx, key, ru, flags in issues:
    print(f'{idx} | {key} | {flags} | {ru}')
