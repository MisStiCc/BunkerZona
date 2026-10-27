# data/accessibility_data.gd
extends RefCounted
class_name Accessibility

## Настройки доступности (спека D14, design_inbox/_done/accessibility).
## Живут в settings.cfg [ui] - как язык; на геймплей не влияют.

const CFG := "user://settings.cfg"

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


## Тряска экрана/баннера через одну точку: 0 = панчи масштаба остаются
static func shake(amplitude: float) -> float:
	return amplitude * shake_mult()


## Пиктограмма редкости (дальтоник-режим; вне режима - пусто):
## common ▢ / uncommon △ / rare ◇ / legendary+ex ★
static func rarity_glyph(rarity: String) -> String:
	if colorblind() == 0:
		return ""
	match rarity:
		"legendary", "ex": return "★"
		"rare": return "◇"
		"uncommon": return "△"
		_: return "▢"


## Дальтонико-безопасная палитра редкости; вне режима возвращает base
static func rarity_color(rarity: String, base: Color) -> Color:
	match colorblind():
		1:  # протаноп: различаемо по светлоте и синему
			return {"legendary": Color("ffd23f"), "ex": Color("ffffff"),
				"rare": Color("4d9fff"), "uncommon": Color("e8a33d"),
				"common": Color("9aa0a6")}.get(rarity, base)
		2:  # дейтераноп: сине-фиолетовая шкала
			return {"legendary": Color("ffd23f"), "ex": Color("ffffff"),
				"rare": Color("6a8cff"), "uncommon": Color("d9c04d"),
				"common": Color("9aa0a6")}.get(rarity, base)
	return base


## Применить масштаб UI к корню контента (лаборатория/меню; HUD боя не трогаем)
static func apply_ui_scale(root: Control) -> void:
	if root == null:
		return
	var s := ui_scale()
	root.scale = Vector2(s, s)
	root.pivot_offset = root.size / 2.0
