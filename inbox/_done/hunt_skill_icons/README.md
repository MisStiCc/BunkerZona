# Иконки скиллов боссов ОХОТЫ (12 шт, 96px)

Заменяют эмодзи-глифы из `SKILL_GLYPH` (ui/lab/hunt_calendar.gd:19) в
Календаре ОХОТЫ и Босс-табе гильдии (хелпер `HuntCalendar.portrait`).

Файлы названы ПО ID СКИЛЛА из data/boss_hunt_data.gd:
skill_quake, skill_blink, skill_dot_zone, skill_summon, skill_stun_nearest,
skill_vampiric, skill_dash, skill_shield, skill_regen, skill_backstab,
skill_hop_regen, skill_mark (.png)

Подключение: маппинг id -> путь "res://<папка>/skill_%s.png" вместо
глифа; там, где иконка не влезает (строка текста), оставить глиф.
Стиль — как assets/ui/abilities (тёмная октагон-пластина + золотое кольцо).
