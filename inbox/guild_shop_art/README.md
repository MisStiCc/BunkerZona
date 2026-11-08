# Арт для гильд-магазина (D21) + ДИАГНОЗ пустых иконок

## ДИАГНОЗ (главному): почему витрина «пустая» — это НЕ ассеты

Иконки товаров НЕ грузятся из-за двойного префикса в
`ui/lab/guild_overlay.gd` (вкладка МАГАЗИН, ~строка 384):

```gdscript
var icon_types := {
    "rolls_mut_5": ["mut_dog_mutant", true], "rolls_art_5": ["art_spark_artifact", false],
    "bio_100k": ["mut_flesh", true], "star_feed_1": ["art_clock_artifact", false],
}
```

`GachaData.card_icon_path(type, is_mutant)` УЖЕ добавляет префикс
`mut_`/`art_` к типу (gacha_data.gd:510) — а гильд-оверлей передаёт тип
с префиксом. Итог: ищется `res://ui/cards/mut_mut_dog_mutant.png`
(не существует) → фолбэк на несуществующий `.svg` → `ResourceLoader.exists
== false` → TextureRect пустой. Лабораторный магазин работает, потому что
передаёт ГОЛЫЕ типы (`SHOP_MUTANTS` = `["zombie", ...]`).

**Фикс (одна строка логики):** передавать голые id:

```gdscript
var icon_types := {
    "rolls_mut_5": ["dog_mutant", true], "rolls_art_5": ["spark_artifact", false],
    "bio_100k": ["flesh", true], "star_feed_1": ["clock_artifact", false],
}
```

Или красивее — по sku напрямую из готового набора стора (уже в ассетах,
в релизе живёт):

```gdscript
var sku_icons := {
    "rolls_mut_5": "res://assets/ui/store_icons/icon_pull.png",
    "rolls_art_5": "res://assets/ui/store_icons/icon_pull.png",
    "bio_100k": "res://assets/ui/store_icons/icon_biomass.png",
    "star_feed_1": "res://assets/ui/currency/icon_sparks.png",
}
# для неизвестных sku — фолбэк icon_tokens.png (иконка валюты, она уже
# подгружена в шапке вкладки)
```

Вариант со store_icons предпочтительнее: иконки товаров читаются как
«что купишь», а не «какой мутант тебе выпадет».

## Поставляемый ассет: фон витрины

`guild_shop_bg.png` (980×840) — тёмно-фиолетовый градиент + туманные
пятна + watermark Монолита + рваные кромки сверху/снизу (серия баннеров).
Генератор `gen_guild_bg.py` (PIL, детерминированный seed), CC0.

Как встроить (по образцу store_panel.gd build(), строки с bg):

```gdscript
var bg := TextureRect.new()
bg.texture = load("res://assets/ui/guild/guild_shop_bg.png")
bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
bg.stretch_mode = TextureRect.STRETCH_SCALE   # или COVER
bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
<панель>.add_child(bg)
<панель>.move_child(bg, 0)   # фон под всем контентом
```

Путь кладки: `assets/ui/guild/guild_shop_bg.png` (рядом с
guild_banner_crimson.png и guild_emblem_256.png).

## Проверка

Фон проверен визуально: тёмный, watermark приглушён (не спорит со
списком товаров), кромки рваные по серии. Иконки после фикса проверять
на витрине: 4 товара + фолбэк для sku без маппинга.

## CREDITS

CC0, процедурный PIL — см. CREDITS.md.
