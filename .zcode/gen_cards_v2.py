# -*- coding: utf-8 -*-
# Карточки v2: многослойная живопись - фон с лучом, ореол, тень под субъектом,
# тёмный низ/светлый верх у фигур, блики-спекуляры, виньетка, двойная рамка-камея
import os

OUT = "ui/cards"
os.makedirs(OUT, exist_ok=True)

RAR = {
    "common":    ("#43454f", "#2a2b33", "#17181d", "#93959f"),
    "uncommon":  ("#3a5c37", "#22381f", "#121e11", "#72d97c"),
    "rare":      ("#31518a", "#1d3050", "#101a2c", "#6ea8ff"),
    "legendary": ("#7a5518", "#452f0b", "#241805", "#ffbe45"),
}

def header(r):
    c1, c2, c3, border = RAR[r]
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<defs>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="{c1}"/><stop offset="0.55" stop-color="{c2}"/><stop offset="1" stop-color="{c3}"/>
</linearGradient>
<radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
<stop offset="0" stop-color="{border}" stop-opacity="0.5"/><stop offset="1" stop-color="{border}" stop-opacity="0"/>
</radialGradient>
<radialGradient id="vig" cx="0.5" cy="0.42" r="0.75">
<stop offset="0.55" stop-color="#000000" stop-opacity="0"/><stop offset="1" stop-color="#000000" stop-opacity="0.42"/>
</radialGradient>
<linearGradient id="beam" x1="0" y1="0" x2="1" y2="1">
<stop offset="0" stop-color="#ffffff" stop-opacity="0.10"/><stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/>
</linearGradient>
<linearGradient id="metal" x1="0" y1="0" x2="0" y2="1">
<stop offset="0" stop-color="#e8e8ec"/><stop offset="1" stop-color="#8a8a92"/>
</linearGradient>
</defs>'''

def frame(r):
    c1, c2, c3, border = RAR[r]
    return f'''
<rect x="2.5" y="2.5" width="123" height="123" rx="13" fill="none" stroke="{border}" stroke-width="3"/>
<rect x="7" y="7" width="114" height="114" rx="9" fill="none" stroke="{border}" stroke-width="1" opacity="0.45"/>
<circle cx="10" cy="10" r="2.2" fill="{border}"/><circle cx="118" cy="10" r="2.2" fill="{border}"/>
<circle cx="10" cy="118" r="2.2" fill="{border}"/><circle cx="118" cy="118" r="2.2" fill="{border}"/>'''

def base(r):
    return f'''
<rect x="2" y="2" width="124" height="124" rx="14" fill="url(#bg)"/>
<rect x="2" y="2" width="124" height="124" rx="14" fill="url(#beam)"/>'''

def halo(cx, cy, rx):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{rx}" fill="url(#halo)"/>'

def ground(cx, cy, rx, op=0.4):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{rx*0.28:.0f}" fill="#000000" opacity="{op}"/>'

def spec(cx, cy, rx, ry, op=0.75, color="#ffffff"):
    return f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{color}" opacity="{op}"/>'

def finish(r, body):
    return header(r) + base(r) + body + '\n<rect x="2" y="2" width="124" height="124" rx="14" fill="url(#vig)"/>' + frame(r) + '\n</svg>'

M = {}

# ================= МУТАНТЫ v2 =================
M["zombie"] = ("common", ground(64, 112, 40) + f'''
<ellipse cx="64" cy="90" rx="31" ry="26" fill="#5c6b52"/>
<ellipse cx="64" cy="98" rx="31" ry="18" fill="#46523d"/>
<ellipse cx="64" cy="58" rx="21" ry="19" fill="#748562" transform="rotate(-10 64 58)"/>
<ellipse cx="58" cy="50" rx="10" ry="7" fill="#8a9c74" transform="rotate(-10 58 50)"/>
<rect x="32" y="70" width="28" height="11" rx="5.5" fill="#5c6b52" transform="rotate(20 46 75)"/>
<rect x="70" y="70" width="27" height="11" rx="5.5" fill="#4d5943" transform="rotate(-16 83 75)"/>
<path d="M50 56 L62 63 L76 54" stroke="#39422f" stroke-width="2.6" fill="none"/>
<path d="M56 74 L58 82 M66 72 L64 80 M74 76 L72 84" stroke="#39422f" stroke-width="2" opacity="0.7"/>
<circle cx="57" cy="55" r="6" fill="url(#halo)" opacity="0.5"/>
<circle cx="72" cy="53" r="6" fill="url(#halo)" opacity="0.5"/>
<circle cx="57" cy="55" r="2.6" fill="#ff6a3c"/><circle cx="72" cy="53" r="2.6" fill="#ff6a3c"/>''')

M["dog_mutant"] = ("common", ground(64, 112, 42) + f'''
<path d="M28 88 Q26 70 42 64 Q58 58 78 62 Q98 66 100 80 Q101 92 88 94 L38 94 Q29 94 28 88 Z" fill="#75604c"/>
<path d="M30 90 Q30 78 44 72 Q60 66 78 70 L78 90 Z" fill="#8a7258" opacity="0.55"/>
<path d="M92 68 Q106 60 110 48 Q112 44 106 46 Q95 52 88 62 Z" fill="#75604c"/>
<path d="M100 54 Q106 50 109 47" stroke="#a08a6c" stroke-width="2" fill="none" stroke-linecap="round"/>
<rect x="35" y="88" width="10" height="20" rx="4.5" fill="#5c4a3a"/>
<rect x="52" y="90" width="10" height="18" rx="4.5" fill="#65523f"/>
<rect x="72" y="90" width="10" height="18" rx="4.5" fill="#5c4a3a"/>
<rect x="87" y="88" width="10" height="20" rx="4.5" fill="#65523f"/>
<path d="M98 82 L114 88 L100 93 Z" fill="#5c4a3a"/>
<circle cx="99" cy="61" r="5" fill="url(#halo)" opacity="0.6"/>
<circle cx="99" cy="61" r="2.6" fill="#ff453a"/>
<path d="M38 70 L48 66 M60 64 L72 62" stroke="#4a3a2c" stroke-width="2" opacity="0.6"/>''')

M["flesh"] = ("common", ground(64, 112, 42) + f'''
<ellipse cx="64" cy="74" rx="42" ry="31" fill="#a8504e"/>
<path d="M26 70 Q30 52 48 48 Q60 44 74 48 Q94 52 100 66 Q102 76 96 82 Q80 92 60 92 Q40 92 30 82 Q24 76 26 70 Z" fill="#b85555"/>
<ellipse cx="46" cy="62" rx="13" ry="10" fill="#d97f78"/>
<ellipse cx="80" cy="84" rx="11" ry="8" fill="#8a3b3c"/>
<ellipse cx="90" cy="62" rx="8" ry="6" fill="#c96b64"/>
<circle cx="64" cy="76" r="8" fill="#f2e6c9"/><circle cx="66" cy="74" r="4" fill="#2c2320"/>
<circle cx="66" cy="73" r="1.6" fill="#ffffff"/>
<path d="M38 78 Q44 74 50 78 M74 58 Q80 54 86 58" stroke="#8a3b3c" stroke-width="2.2" fill="none" opacity="0.8"/>''')

M["snork_mutant"] = ("uncommon", ground(64, 112, 36) + f'''
<ellipse cx="64" cy="90" rx="25" ry="21" fill="#4a5544"/>
<path d="M44 96 Q52 84 64 84 Q76 84 84 96 Z" fill="#39423a"/>
<ellipse cx="64" cy="58" rx="20" ry="18" fill="#5c6a50"/>
<ellipse cx="58" cy="50" rx="10" ry="6" fill="#718061"/>
<circle cx="64" cy="61" r="12" fill="#39423a"/>
<circle cx="64" cy="65" r="6" fill="#1c211b"/>
<circle cx="62" cy="63" r="2" fill="#4a5a3c" opacity="0.8"/>
<rect x="55" y="43" width="18" height="7" rx="3.5" fill="#39423a"/>
<rect x="42" y="82" width="15" height="10" rx="5" fill="#4a5544" transform="rotate(26 49 87)"/>
<rect x="71" y="82" width="15" height="10" rx="5" fill="#414c3c" transform="rotate(-26 78 87)"/>
<circle cx="59" cy="57" r="2.2" fill="#c9e64a"/><circle cx="69" cy="57" r="2.2" fill="#c9e64a"/>''')

M["pseudodog"] = ("uncommon", ground(64, 112, 40) + f'''
<path d="M38 90 Q34 74 50 67 Q66 60 82 66 Q94 72 94 84 L94 92 L38 92 Z" fill="#87705a"/>
<path d="M42 88 Q42 76 56 71 Q70 66 82 72 L82 88 Z" fill="#9c8468" opacity="0.6"/>
<path d="M86 68 Q100 56 104 40 Q105 36 99 40 Q89 50 82 60 Z" fill="#87705a"/>
<path d="M44 64 L38 44 Q37 40 43 44 L54 58 Z" fill="#9c8468"/>
<path d="M40 46 L43 56 L48 49 Z" fill="#5f4c3a"/>
<rect x="44" y="88" width="9" height="17" rx="4" fill="#6a5844"/>
<rect x="80" y="88" width="9" height="17" rx="4" fill="#76634c"/>
<path d="M94 84 L110 90 L94 93 Z" fill="#6a5844"/>
<circle cx="96" cy="55" r="5.5" fill="url(#halo)" opacity="0.6"/>
<circle cx="96" cy="55" r="2.8" fill="#ffd24a"/>''')

M["poltergeist"] = ("uncommon", f'''
<ellipse cx="64" cy="62" rx="38" ry="40" fill="url(#halo)" opacity="0.7"/>
<path d="M64 24 Q94 28 91 60 Q90 80 83 94 L75 84 L66 96 L57 84 L48 94 Q40 80 39 58 Q37 28 64 24 Z" fill="#5f947f"/>
<path d="M64 24 Q84 28 84 54 Q84 70 78 80 Q70 86 64 86 Q58 86 52 80 Q46 70 46 54 Q46 28 64 24 Z" fill="#79b39a" opacity="0.75"/>
<path d="M50 52 Q64 44 78 52" stroke="#3e6b5c" stroke-width="3" fill="none"/>
<path d="M52 62 Q64 56 76 62" stroke="#3e6b5c" stroke-width="2" fill="none" opacity="0.7"/>
<circle cx="57" cy="52" r="5" fill="url(#halo)" opacity="0.8"/><circle cx="71" cy="52" r="5" fill="url(#halo)" opacity="0.8"/>
<circle cx="57" cy="52" r="3.4" fill="#eafff2"/><circle cx="71" cy="52" r="3.4" fill="#eafff2"/>''')

M["controller_mutant"] = ("rare", ground(64, 114, 34) + f'''
<ellipse cx="64" cy="62" rx="40" ry="40" fill="url(#halo)" opacity="0.55"/>
<ellipse cx="64" cy="94" rx="20" ry="15" fill="#5a4a6e"/>
<ellipse cx="64" cy="99" rx="20" ry="10" fill="#443856"/>
<ellipse cx="64" cy="55" rx="28" ry="25" fill="#7a6890"/>
<path d="M44 44 Q54 30 64 33 Q78 29 84 44" stroke="#9c8ab2" stroke-width="3" fill="none"/>
<path d="M42 56 Q37 48 42 40 M86 56 Q91 48 86 40" stroke="#9c8ab2" stroke-width="3" fill="none"/>
<path d="M52 36 Q56 30 62 30 M70 30 Q76 30 78 35" stroke="#9c8ab2" stroke-width="2" fill="none" opacity="0.7"/>
<circle cx="55" cy="55" r="5.5" fill="url(#halo)" opacity="0.9"/><circle cx="73" cy="55" r="5.5" fill="url(#halo)" opacity="0.9"/>
<circle cx="55" cy="55" r="3.2" fill="#ff4ad2"/><circle cx="73" cy="55" r="3.2" fill="#ff4ad2"/>
{spec(56, 46, 9, 5, 0.5)}''')

M["bloodsucker"] = ("rare", ground(64, 114, 34) + f'''
<ellipse cx="64" cy="60" rx="36" ry="38" fill="url(#halo)" opacity="0.4"/>
<ellipse cx="64" cy="88" rx="27" ry="23" fill="#43584a"/>
<path d="M42 94 Q50 82 64 82 Q78 82 86 94 Z" fill="#33453a"/>
<ellipse cx="64" cy="52" rx="22" ry="21" fill="#516b5b"/>
<ellipse cx="58" cy="42" rx="11" ry="7" fill="#688570"/>
<path d="M49 58 Q46 72 51 82 M58 61 Q56 76 60 86 M70 61 Q72 76 68 86 M79 58 Q82 72 77 82" stroke="#2c3c32" stroke-width="4.5" fill="none" stroke-linecap="round"/>
<path d="M49 58 Q47 68 50 76" stroke="#8aa691" stroke-width="1.6" fill="none" opacity="0.6"/>
<circle cx="56" cy="48" r="4.5" fill="url(#halo)" opacity="0.9"/><circle cx="72" cy="48" r="4.5" fill="url(#halo)" opacity="0.9"/>
<circle cx="56" cy="48" r="2.8" fill="#ff3b30"/><circle cx="72" cy="48" r="2.8" fill="#ff3b30"/>''')

M["pseudogiant"] = ("legendary", ground(64, 116, 46, 0.5) + f'''
<ellipse cx="64" cy="58" rx="44" ry="42" fill="url(#halo)" opacity="0.5"/>
<ellipse cx="64" cy="92" rx="41" ry="25" fill="#6e6258"/>
<path d="M28 100 Q30 80 44 74 Q64 66 84 74 Q98 80 100 100 Z" fill="#7d7062" opacity="0.7"/>
<ellipse cx="64" cy="45" rx="18" ry="15" fill="#857462"/>
<ellipse cx="58" cy="38" rx="9" ry="5" fill="#9c8a74"/>
<rect x="18" y="56" width="19" height="36" rx="9.5" fill="#6e6258"/>
<rect x="91" y="56" width="19" height="36" rx="9.5" fill="#5f5348"/>
<path d="M38 34 L52 24 M90 34 L76 24" stroke="#5a4f45" stroke-width="5" stroke-linecap="round"/>
<circle cx="57" cy="43" r="4" fill="url(#halo)" opacity="0.9"/><circle cx="71" cy="43" r="4" fill="url(#halo)" opacity="0.9"/>
<circle cx="57" cy="43" r="2.6" fill="#ffb63d"/><circle cx="71" cy="43" r="2.6" fill="#ffb63d"/>
<path d="M44 66 L54 60 M74 60 L84 66" stroke="#4c4237" stroke-width="2.4" opacity="0.7"/>''')

M["chimera"] = ("legendary", ground(64, 114, 44, 0.5) + f'''
<ellipse cx="64" cy="56" rx="44" ry="40" fill="url(#halo)" opacity="0.6"/>
<path d="M32 88 Q28 68 46 62 Q62 56 80 60 Q96 64 98 80 L98 92 L32 92 Z" fill="#6d5764"/>
<path d="M36 88 Q38 72 52 66 Q64 62 78 66 L78 88 Z" fill="#826775" opacity="0.55"/>
<ellipse cx="43" cy="50" rx="15" ry="13" fill="#7a636c"/>
<ellipse cx="85" cy="50" rx="15" ry="13" fill="#6d5764"/>
<path d="M30 44 L24 28 Q23 24 29 28 L40 40 Z" fill="#8a7180"/>
<path d="M98 44 L104 28 Q105 24 99 28 L88 40 Z" fill="#7a636c"/>
<path d="M26 30 L30 34 M102 30 L98 34" stroke="#4c3b44" stroke-width="2.5" stroke-linecap="round"/>
<rect x="38" y="88" width="10" height="17" rx="4.5" fill="#513f4a"/>
<rect x="80" y="88" width="10" height="17" rx="4.5" fill="#5d4a56"/>
<circle cx="38" cy="48" r="4" fill="#ff453a"/><circle cx="49" cy="48" r="4" fill="#ff453a"/>
<circle cx="80" cy="48" r="4" fill="#ff453a"/><circle cx="91" cy="48" r="4" fill="#ff453a"/>
<circle cx="38" cy="47" r="1.4" fill="#ffd0cc"/><circle cx="80" cy="47" r="1.4" fill="#ffd0cc"/>''')

A = {}

# ================= АРТЕФАКТЫ v2 =================
def artifact_body(inner, glow_r=38, spec_pos=(52, 46)):
    cx, cy = spec_pos
    return inner + f'\n{spec(cx, cy, 8, 5, 0.65)}'

A["common_artifact"] = ("common", f'''
{halo(64, 66, 34)}
<circle cx="64" cy="66" r="27" fill="#8f8f97"/>
<path d="M38 60 Q42 44 58 40 Q80 36 88 54 Q92 66 86 80 Q76 94 60 92 Q42 92 36 76 Q34 68 38 60 Z" fill="#9c9ca4"/>
<path d="M40 66 Q44 54 58 50" stroke="#c9c9d1" stroke-width="4" fill="none" stroke-linecap="round" opacity="0.8"/>
<path d="M52 58 L60 68 L54 78 M68 54 L74 64 L68 74" stroke="#6b6b73" stroke-width="2.6" fill="none"/>
<ellipse cx="58" cy="88" rx="10" ry="4" fill="#5f5f67" opacity="0.7"/>''')

A["battery_artifact"] = ("common", f'''
{halo(64, 66, 34)}
<rect x="49" y="40" width="30" height="54" rx="7" fill="#3f7a46"/>
<rect x="52" y="43" width="24" height="48" rx="5" fill="#4f9456"/>
<rect x="55" y="31" width="18" height="10" rx="3" fill="url(#metal)"/>
<rect x="60" y="27" width="8" height="6" rx="2" fill="#b5bdc7"/>
<path d="M68 46 L56 70 L64 70 L58 88 L74 64 L66 64 Z" fill="#ffd24a"/>
<path d="M68 46 L62 58 L66 58 Z" fill="#ffe89c"/>
<rect x="52" y="82" width="24" height="6" rx="3" fill="#2c5732" opacity="0.7"/>''')

A["glowstick_artifact"] = ("common", f'''
{halo(64, 64, 46)}
<g transform="rotate(24 64 64)">
<rect x="55" y="22" width="18" height="84" rx="9" fill="#5fd06e"/>
<rect x="59" y="26" width="10" height="76" rx="5" fill="#8fe898"/>
<rect x="61" y="30" width="4" height="68" rx="2" fill="#e2ffe4" opacity="0.9"/>
<rect x="55" y="22" width="18" height="10" rx="5" fill="#3f9a4c"/>
<rect x="55" y="96" width="18" height="10" rx="5" fill="#3f9a4c"/>
</g>''')

A["slime_artifact"] = ("common", f'''
{halo(64, 70, 36)}
<path d="M36 84 Q32 60 52 52 Q60 36 76 44 Q98 50 92 72 Q97 88 74 93 Q46 98 36 84 Z" fill="#79c14e"/>
<path d="M40 80 Q38 64 54 58 Q62 46 74 52 Q88 58 86 72 Q88 82 72 86 Q50 90 40 80 Z" fill="#8fd463" opacity="0.8"/>
<circle cx="54" cy="68" r="5.5" fill="#b8ec8e"/><circle cx="74" cy="78" r="4.5" fill="#b8ec8e"/><circle cx="68" cy="56" r="3" fill="#b8ec8e"/>
<circle cx="56" cy="66" r="1.8" fill="#e8ffd0"/><circle cx="75" cy="76" r="1.4" fill="#e8ffd0"/>
<path d="M46 88 Q64 94 82 88" stroke="#5aa038" stroke-width="2.4" fill="none" opacity="0.8"/>''')

A["spark_artifact"] = ("common", f'''
{halo(64, 64, 40)}
<path d="M66 26 L46 64 L61 64 L52 100 L84 54 L69 54 L82 26 Z" fill="#7fb8f2"/>
<path d="M66 26 L56 46 L64 46 L58 60 L66 60 Z" fill="#c9e6ff"/>
<path d="M84 54 L69 54 L64 74 Z" fill="#a8d4ff" opacity="0.7"/>''')

A["gas_bottle_artifact"] = ("common", f'''
{halo(64, 64, 34)}
<path d="M52 46 Q45 56 45 68 L45 88 Q45 95 52 95 L76 95 Q83 95 83 88 L83 68 Q83 56 76 46 Z" fill="#b0622e"/>
<path d="M54 48 Q50 58 50 68 L50 86 Q50 90 54 91 L60 91 L60 48 Z" fill="#c9773c" opacity="0.8"/>
<rect x="57" y="32" width="14" height="13" rx="3" fill="url(#metal)"/>
<rect x="60" y="28" width="8" height="6" rx="2" fill="#8a8f96"/>
<rect x="53" y="60" width="22" height="7" rx="3.5" fill="#d88a4a"/>
<path d="M53 63 L75 63" stroke="#8a4a1f" stroke-width="1.6" opacity="0.7"/>''')

A["rare_artifact"] = ("rare", f'''
{halo(64, 62, 42)}
<path d="M64 24 L93 58 L64 104 L35 58 Z" fill="#3f7ecb"/>
<path d="M64 24 L79 58 L64 104 L49 58 Z" fill="#5f9ce8"/>
<path d="M64 24 L72 58 L64 90 L56 58 Z" fill="#8fc0ff" opacity="0.85"/>
<path d="M35 58 L93 58" stroke="#2a5a94" stroke-width="2"/>
<path d="M49 58 L79 58 M64 24 L64 104" stroke="#2a5a94" stroke-width="1.4" opacity="0.7"/>''')

A["energy_artifact"] = ("rare", f'''
{halo(64, 64, 40)}
<circle cx="64" cy="64" r="31" fill="#22364e"/>
<circle cx="64" cy="64" r="31" fill="none" stroke="#6ea8ff" stroke-width="3"/>
<circle cx="64" cy="64" r="25" fill="none" stroke="#6ea8ff" stroke-width="1.2" opacity="0.5"/>
<path d="M70 40 L50 68 L63 68 L57 90 L80 58 L67 58 Z" fill="#ffe45c"/>
<path d="M70 40 L60 56 L66 56 Z" fill="#fff6b8"/>''')

A["clock_artifact"] = ("rare", f'''
{halo(64, 64, 38)}
<circle cx="64" cy="64" r="29" fill="#a89670"/>
<circle cx="64" cy="64" r="29" fill="none" stroke="#6e5f42" stroke-width="3"/>
<circle cx="64" cy="64" r="23" fill="#efe6c9"/>
<circle cx="64" cy="64" r="23" fill="none" stroke="#c9bb94" stroke-width="1.5" opacity="0.8"/>
<path d="M64 46 L64 50 M64 78 L64 82 M46 64 L50 64 M78 64 L82 64" stroke="#4a4232" stroke-width="2.5"/>
<path d="M64 64 L64 50 M64 64 L75 70" stroke="#3a3222" stroke-width="3" stroke-linecap="round"/>
<circle cx="64" cy="64" r="2.6" fill="#3a3222"/>
{spec(54, 48, 7, 4, 0.5)}''')

A["hourglass_artifact"] = ("rare", f'''
{halo(64, 64, 34)}
<path d="M45 32 L83 32 L83 45 Q83 57 69 64 Q83 71 83 83 L83 96 L45 96 L45 83 Q45 71 59 64 Q45 57 45 45 Z" fill="#8a5f3a"/>
<path d="M49 36 L79 36 Q77 52 64 58 Q51 52 49 36 Z" fill="#3a2c1c"/>
<path d="M49 92 L79 92 Q79 78 64 72 Q49 78 49 92 Z" fill="#3a2c1c"/>
<path d="M52 39 L76 39 Q74 51 64 55 Q54 51 52 39 Z" fill="#e8d49a"/>
<path d="M55 89 L73 89 Q73 80 64 76 Q55 80 55 89 Z" fill="#e8d49a"/>
<rect x="42" y="29" width="44" height="6" rx="3" fill="#6e4a2c"/>
<rect x="42" y="93" width="44" height="6" rx="3" fill="#6e4a2c"/>
{spec(56, 40, 5, 3, 0.5)}''')

A["graviton_artifact"] = ("rare", f'''
{halo(64, 64, 42)}
<circle cx="64" cy="64" r="19" fill="#191a24"/>
<circle cx="64" cy="64" r="19" fill="none" stroke="#5f9dff" stroke-width="2.5"/>
<ellipse cx="64" cy="64" rx="36" ry="13" fill="none" stroke="#8fc0ff" stroke-width="3.5" transform="rotate(-18 64 64)"/>
<ellipse cx="64" cy="64" rx="36" ry="13" fill="none" stroke="#5f9dff" stroke-width="2" transform="rotate(28 64 64)" opacity="0.65"/>
<circle cx="97" cy="52" r="3.5" fill="#c9e6ff"/>
<circle cx="33" cy="78" r="2.8" fill="#8fc0ff"/>
<circle cx="64" cy="64" r="7" fill="#2a3448"/><circle cx="61" cy="61" r="2" fill="#8fc0ff" opacity="0.9"/>''')

A["fireball_artifact"] = ("rare", f'''
{halo(64, 64, 44)}
<path d="M64 22 Q86 40 84 66 Q86 90 64 98 Q42 90 44 66 Q42 40 64 22 Z" fill="#d84f1f"/>
<path d="M64 34 Q78 48 76 68 Q77 84 64 90 Q51 84 52 68 Q50 48 64 34 Z" fill="#ef7a2c"/>
<path d="M64 46 Q73 56 71 70 Q72 80 64 84 Q56 80 57 70 Q55 56 64 46 Z" fill="#ffb63d"/>
<path d="M64 60 Q68 66 66 72 Q67 77 64 79 Q61 77 62 72 Q61 66 64 60 Z" fill="#ffe45c"/>''')

A["jumper_artifact"] = ("rare", f'''
{halo(64, 64, 36)}
<path d="M45 94 Q38 94 40 85 Q44 68 61 61 Q80 54 85 42" stroke="#5f9dff" stroke-width="8" fill="none" stroke-linecap="round"/>
<path d="M45 94 Q42 80 55 73 Q70 66 75 55" stroke="#8fc0ff" stroke-width="5" fill="none" stroke-linecap="round"/>
<path d="M48 90 Q46 80 56 75 Q66 70 70 62" stroke="#d6e8ff" stroke-width="2.5" fill="none" stroke-linecap="round" opacity="0.85"/>
<path d="M78 30 L94 41 L77 53 Z" fill="#d6e8ff"/>
<path d="M81 34 L89 40 L81 47 Z" fill="#5f9dff"/>''')

A["flesh_artifact"] = ("rare", f'''
{halo(64, 66, 34)}
<path d="M40 58 Q38 42 55 38 Q72 32 87 42 Q97 53 91 67 Q95 82 78 89 Q59 96 49 85 Q36 78 40 58 Z" fill="#c9555f"/>
<path d="M44 58 Q44 48 58 44 Q72 40 82 48 Q90 56 86 66 Q89 76 76 82 Q62 88 53 80 Q43 74 44 58 Z" fill="#d96f76" opacity="0.8"/>
<ellipse cx="60" cy="56" rx="11" ry="7" fill="#ec9aa0"/>
<rect x="44" y="80" width="38" height="8" rx="4" fill="#efe6c9" transform="rotate(-12 63 84)"/>
<circle cx="80" cy="84" r="4.5" fill="#dcd2b4"/>
<circle cx="46" cy="88" r="4.5" fill="#dcd2b4"/>''')

A["void_artifact"] = ("legendary", f'''
{halo(64, 64, 48)}
<circle cx="64" cy="64" r="26" fill="#0d0a16"/>
<circle cx="64" cy="64" r="26" fill="none" stroke="#a86ae8" stroke-width="3"/>
<circle cx="64" cy="64" r="31" fill="none" stroke="#a86ae8" stroke-width="1.2" opacity="0.4"/>
<ellipse cx="64" cy="64" rx="37" ry="10" fill="none" stroke="#c99af2" stroke-width="2.6" transform="rotate(-22 64 64)"/>
<ellipse cx="64" cy="64" rx="37" ry="10" fill="none" stroke="#8a4ac9" stroke-width="1.6" transform="rotate(30 64 64)" opacity="0.7"/>
<circle cx="64" cy="64" r="9" fill="#241536"/>
<circle cx="61" cy="61" r="2.4" fill="#c99af2" opacity="0.9"/>''')

A["heart_artifact"] = ("legendary", f'''
{halo(64, 62, 44)}
<path d="M64 98 Q28 74 28 50 Q28 32 46 32 Q58 32 64 45 Q70 32 82 32 Q100 32 100 50 Q100 74 64 98 Z" fill="#c93a48"/>
<path d="M64 92 Q34 72 33 52 Q33 38 47 38 Q57 38 62 48 L64 52 Z" fill="#e05a66" opacity="0.85"/>
<path d="M45 47 Q47 40 54 40" stroke="#ff9aa2" stroke-width="3" fill="none" stroke-linecap="round"/>
<path d="M64 56 Q66 64 70 70 Q66 76 64 82 Q62 76 58 70 Q62 64 64 56 Z" fill="#ff8a94" opacity="0.9"/>
{spec(46, 44, 7, 5, 0.5)}''')

A["storm_artifact"] = ("legendary", f'''
{halo(64, 64, 42)}
<path d="M38 60 Q26 60 26 48 Q26 36 41 36 Q45 22 61 22 Q78 22 82 37 Q97 37 97 50 Q97 60 84 60 Z" fill="#556379"/>
<path d="M42 56 Q34 56 34 48 Q34 40 44 40 Q47 30 60 30 Q72 30 76 40 Q86 40 86 49 Q86 56 77 56 Z" fill="#6e7f9a" opacity="0.9"/>
<path d="M68 58 L48 84 L61 84 L52 106 L80 74 L67 74 Z" fill="#ffe45c"/>
<path d="M68 58 L58 72 L64 72 Z" fill="#fff6b8"/>''')

A["uranium_artifact"] = ("legendary", f'''
{halo(64, 64, 42)}
<rect x="34" y="34" width="60" height="60" rx="12" fill="#3f5c31"/>
<rect x="38" y="38" width="52" height="52" rx="9" fill="#4f7440"/>
<rect x="38" y="38" width="52" height="24" rx="9" fill="#628a4f" opacity="0.7"/>
<circle cx="64" cy="64" r="6.5" fill="#b8e86e"/>
<path d="M64 64 L64 44 A20 20 0 0 1 81 54 Z" fill="#b8e86e" opacity="0.9"/>
<path d="M64 64 L48 74 A20 20 0 0 1 46 56 Z" fill="#b8e86e" opacity="0.9"/>
<path d="M64 64 L82 72 A20 20 0 0 1 64 84 Z" fill="#b8e86e" opacity="0.9"/>
<circle cx="64" cy="64" r="20" fill="none" stroke="#d6ffb0" stroke-width="1.4" opacity="0.5"/>''')

n = 0
for name, (r, body) in M.items():
    open(f"{OUT}/mut_{name}.svg", "w", encoding="utf-8", newline="\n").write(finish(r, body))
    n += 1
for name, (r, body) in A.items():
    open(f"{OUT}/art_{name}.svg", "w", encoding="utf-8", newline="\n").write(finish(r, body))
    n += 1
print("v2 cards:", n)
