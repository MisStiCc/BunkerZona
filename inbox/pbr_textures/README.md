# Настоящие PBR-текстуры (ЗАДАЧА 14)

## Что сделано

18 паков `assets/textures/pbr/<категория>/` были заглушками по 105 байт
(однотонные jpg) — весь PBR-вид террейна и строений рендерился серыми
плашками. Заменены настоящими текстурами ambientCG 1K по маппингу из
`manifest.json` (он остался актуальным). Итог: 48 МБ, 91 файл, импорт
Godot 4.6.1 без ошибок, заглушек не осталось.

## Раскладка (схема `_pbr_material`, terrain_generator.gd:362)

| Файл | Источник в паке ambientCG | Конверсия |
|---|---|---|
| `albedo.jpg` | `<Asset>_Color.jpg` | RGB, quality 88 |
| `normal.png` | `<Asset>_NormalGL.jpg` (OpenGL) | переконвертирован в PNG |
| `roughness.jpg` | `<Asset>_Roughness.jpg` | grayscale |
| `ao.jpg` | `<Asset>_AmbientOcclusion.jpg` | grayscale |

`displacement`/`metalness` код не читает — не клались. AO отсутствует у
трёх паков (concrete_wall_clean, rust_heavy, leak_stains ×2 — так и в
манифесте), код проверяет `ResourceLoader.exists`.

## Категория → ассет ambientCG (18)

asphalt_worn→Asphalt022, asphalt_old→Asphalt006, concrete_wall_dirty→Concrete037,
concrete_wall_clean→Concrete036, concrete_floor→Concrete041A, brick_dark→Bricks091,
rust_heavy→Rust005, corrugated_rust→CorrugatedSteel005, corrugated_metal→CorrugatedSteel002,
dirt_dry→Ground063, gravel_dirty→Gravel025, gravel_fine→Gravel015, dead_grass→Grass005,
wood_planks_old→Planks035A, plaster_cracked→Plaster007, moss→Moss002,
leak_stains→Leaking004, leak_stains_2→Leaking002.

## Проверка

- Импорт headless: 0 ошибок; файлов 91 (по 4-5 на пак), заглушек 0.
- Визуально: albedo 8 категорий — реальные фототекстуры. Яркие (мох/трава)
  гасятся тинтом в коде (`albedo_color = tint` — так задумано пайплайном).
- Первый визуальный запуск за основным агентом: террейн/руины должны
  получить фактуру вместо серых плашек.
