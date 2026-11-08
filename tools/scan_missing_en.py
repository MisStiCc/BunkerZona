# -*- coding: utf-8 -*-
import io

s = io.open('core/localization.gd', encoding='utf-8').read()
lines = s.split(chr(10))
missing = []
for ln in lines:
    if '"ru":' not in ln or '"en"' in ln:
        continue
    i = ln.find('"')
    j = ln.find('"', i + 1)
    if i < 0 or j < 0:
        continue
    key = ln[i + 1:j]
    k = ln.find('"ru": "')
    if k < 0:
        continue
    ru_start = k + len('"ru": "')
    ru_end = ln.find('"', ru_start)
    ru = ln[ru_start:ru_end]
    missing.append((key, ru))
print('MISSING_EN:', len(missing))
out = io.open('.zcode/missing_en.txt', 'w', encoding='utf-8')
for k, ru in missing:
    out.write(k + ' | ' + ru + chr(10))
out.close()
