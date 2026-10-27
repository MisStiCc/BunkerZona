# Настройки доступности (D14)

Опора: `settings.cfg` (уже хранит lang/music/sfx/слот/карту — паттерн есть),
настройки меню (`main_menu._setup_settings`) и лаборатории
(`lab_controller`, экран настроек), `ui/ui_theme.gd` + `BunkerUI` (шрифты),
`ui/cards/` (иконки карт), `RarityColors`/`BunkerUI.RARHEX`,
`ui/hud/ceremony_overlay.gd` + `BunkerUI`-шейки (тряска),
`atmosphere/postfx_layer.gd` + `shaders/grim_postfx.gdshader` (зерно/мерцание).

## 1. Настройки (4 штуки, клиентские)

| Ключ settings.cfg | Тип | Дефолт | Что делает |
|---|---|---|---|
| `[ui] ui_scale` | float 0.8–1.3 | 1.0 | масштаб UI-слоя лаборатории/меню (не HUD боя) |
| `[ui] colorblind` | int 0/1/2 | 0 | 0 выкл, 1 протаноп-режим, 2 дейтераноп-режим (иконки-формы + палитра) |
| `[ui] screen_shake` | float 0–1 | 1.0 | множитель амплитуды тряски (0 = выкл) |
| `[ui] flicker` | float 0–1 | 1.0 | множитель мерцания/зерна постэффекта |

## 2. Реализация по пунктам

### 2.1 Масштаб UI
- Потребитель: `ui/lab/lab.tscn` (root Control) и меню — `scale` на корне
  контента с pivot в центре; HUD забега НЕ масштабируется (баланс
  читаемости боя отдельная тема, не в этом задании).
- Ручки: шаг слайдера 0.05; clamp 0.8–1.3 (при 1.3 станции в лаборатории
  переносятся — проверить, layout HBox это переносит сам).
- Применение: `Accessibility.apply_ui_scale(root)` после `Loc.changed`
  (при смене языка rebuild UI — масштаб переapply).

### 2.2 Дальтоник-режим
- **Форма вместо цвета** (главное): у рамок карт/тайлов редкости добавляется
  пиктограмма-оверлей 24 px в углу — common ▢ (квадрат), uncommon △
  (треугольник), rare ◇ (ромб), legendary ★ (звезда). Точка правки одна:
  `cards_util`/`_make_icon_rect`-подобные фабрики лаборатории + тайлы
  коллекции гачи (`_make_coll_tile`) + дроп-строки. Функция
  `Accessibility.rarity_glyph(rarity) -> String`.
- **Палитра** (дополнительная): при colorblind=1/2 заменять RARHEX-цвета
  на дальтонико-безопасные (1: оранжевый/жёлтый/синий/белый, 2: сине-
  фиолетовая шкала). Точка: `BunkerUI.RARHEX` чтение через
  `Accessibility.rarity_color(key)`; прямые Color("73d980") в коде —
  свести на геттер (поиск по «RARHEX\|rarity_color»).
- Не трогать: цвета редкости в 3D (свет артефактов) — там есть формы/эффекты.

### 2.3 Тряска
- Все шейки проходят через один хелпер `Accessibility.shake(amplitude) ->
  float` (умножает на `screen_shake`). Точки: ceremony_overlay
  (`KEEPER_SLAM_SHAKE` ×2 места), интро-баннер (нет шейка — ок), HUD
  (тряска на красном призраке/ошибках, если есть). Поиск: «_shake\|shake_»
  по ui/ и entities/.
- При 0: анимации панчей масштаба остаются (они не трясут камеру/панель).

### 2.4 Мерцание
- `GrimPostfxLayer`/`grim_postfx.gdshader`: параметр `flicker_strength`
  (0..1), применяется к зерно-осцилляции и мерцанию, десатурация/виньетка
  НЕ трогаются (это читаемость, не дискомфорт). ZoneController при создании
  слоя и при смене силы читает настройку.
- Дополнительно: `emission_fx` (Выброс) — `sky_gain`/столбы имеют
  собственное мерцание; при flicker=0 пиллары горят ровно (множитель в
  emission_controller._apply_intensity, одна строка).

## 3. Готовый блок

```gdscript
# data/accessibility_data.gd — настройки доступности (спека D14)
extends RefCounted
class_name Accessibility

const CFG := "user://settings.cfg"

## Чтение (кэш в статике; запись - set_* + ConfigFile)
static var _cache: Dictionary = {}

static func get_value(key: String, def):
	if _cache.is_empty():
		var cfg := ConfigFile.new()
		if cfg.load(CFG) == OK:
			_cache = {"scale": cfg.get_value("ui", "ui_scale", 1.0),
				"cb": int(cfg.get_value("ui", "colorblind", 0)),
				"shake": cfg.get_value("ui", "screen_shake", 1.0),
				"flicker": cfg.get_value("ui", "flicker", 1.0)}
		else:
			_cache = {"scale": 1.0, "cb": 0, "shake": 1.0, "flicker": 1.0}
	return _cache.get(key, def)

static func set_value(key: String, value) -> void:
	_cache[key] = value
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	cfg.set_value("ui", {"scale": "ui_scale", "cb": "colorblind",
		"shake": "screen_shake", "flicker": "flicker"}[key], value)
	cfg.save(CFG)

static func ui_scale() -> float: return clampf(get_value("scale", 1.0), 0.8, 1.3)
static func colorblind() -> int: return clampi(get_value("cb", 0), 0, 2)
static func shake_mult() -> float: return clampf(get_value("shake", 1.0), 0.0, 1.0)
static func flicker_mult() -> float: return clampf(get_value("flicker", 1.0), 0.0, 1.0)

static func shake(amplitude: float) -> float:
	return amplitude * shake_mult()

## Пиктограмма редкости (дальтоник-режим; вне режима - пусто)
static func rarity_glyph(rarity: String) -> String:
	if colorblind() == 0:
		return ""
	match rarity:
		"legendary", "ex": return "★"
		"rare": return "◇"
		"uncommon": return "△"
		_: return "▢"

## Дальтонико-безопасная палитра редкости (по colorblind())
static func rarity_color(rarity: String, base: Color) -> Color:
	match colorblind():
		1:  # протаноп: различаемо по светлоте и синему
			return {"legendary": Color("ffd23f"), "ex": Color("ffffff"),
				"rare": Color("4d9fff"), "uncommon": Color("e8a33d"),
				"common": Color("9aa0a6")}.get(rarity, base)
		2:  # дейтераноп
			return {"legendary": Color("ffd23f"), "ex": Color("ffffff"),
				"rare": Color("6a8cff"), "uncommon": Color("d9c04d"),
				"common": Color("9aa0a6")}.get(rarity, base)
	return base
```

UI-контролы: в существующие экраны настроек добавить 2 слайдера (масштаб,
тряска), 1 слайдер (мерцание), 1 цикл-кнопку (Дальтоник: ВЫКЛ/ПРОТАНОП/
ДЕЙТЕРАНОП) — по образцу слайдеров громкости. Подписи — ключи Loc
`access.*`.

## 4. Чек-лист приёмки

1. Слайдер масштаба 0.8/1.0/1.3: лаборатория и меню масштабируются, HUD
   боя прежний, после перезапуска настройка живёт.
2. Дальтоник=1: у карт/тайлов/дропов появились пиктограммы ▢△◇★, рамки
   перекрашены;=0 — всё как было.
3. Тряска=0: слэм Хранителя без тряски, панчи масштаба остались.
4. Мерцание=0: зерно/мерцание исчезло, десатурация/виньетка на месте;
   столбы Выброса горят ровно.
5. Смена языка не сбрасывает настройки доступности.
6. Сейвы забегов/прогресс не задеты (только settings.cfg).
