# Иконки способностей HUD (ЗАДАЧА 23)

## Что это

26 иконок 96px для кнопок забега (`ui/hud/hud.gd`): 16 аномалий по
`ANOMALY_ORDER` + 10 мутантов по `MUTANT_ORDER`. Стиль mode_ui: тёмная
плашка со срезанными углами, цветная окантовка по стихии (у аномалий),
цветной глиф, зерно. Читаются на тёмной подложке HUD (проверено листом).

## Файлы

| Папка | Имена (= type из hud.gd) |
|---|---|
| `anomaly/` | heat_anomaly, electric_anomaly, acid_anomaly, gravity_vortex, gravity_lift, gravity_whirlwind, thermal_steam, thermal_comet, chemical_jelly, chemical_gas, chemical_acid_cloud, radiation_hotspot, time_dilation, teleport, electric_tesla, bio_burning_fluff |
| `mutant/` | zombie, dog_mutant, flesh, snork_mutant, pseudodog, poltergeist, controller_mutant, bloodsucker, chimera, pseudogiant |

Цвета окантовки аномалий по стихиям: огонь #ff7a1e, электра #5ab8ff,
кислота #7ec850, гравитация #a06ce8 (вихрь #9696d2), химия #aadc5a,
радиация #dce65a, время #5adce6, телепорт #8c78ff, био #ff8c3c.

## Как встроить (рекомендация, не делал сам)

1. Папки перенести в `assets/ui/abilities/` (или путь по вкусу).
2. В `_style_el_button`/создании кнопок HUD: `icon = load(...)` поверх
   текущей текстовой метки (текст оставить как подпись под иконкой или в
   tooltip). Для эксклюзивов (альфа-пёс и т.д.) иконка варианта мутанта-
   базы + золотая рамка через `modulate`/StyleBox — на усмотрение.
3. Состояние «дорого» — текущее покраснение текста; иконке можно
   `modulate = Color(0.6, 0.6, 0.6)`.

Генератор: `gen_ability_icons.py` (PIL; глифы процедурные, детерминированные).

## Эксклюзивы (дополнение 28.10.2026)

`exclusive/<type>.png` (17 шт) — иконка базы, перекрашенная под масть
варианта (tint из EXCLUSIVE_MUTANTS, защита теней), + золотая окантовка 4px.
Имена = type эксклюза. Генерация — см. журнал подготовщика (тот же реколор,
что у карточек).
