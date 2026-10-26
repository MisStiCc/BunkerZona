# data/radiation_data.gd
extends RefCounted
class_name RadiationData

## Радиационный фон Припяти: зоны по расстоянию Монолит -> Саркофаг.
## Действует ТОЛЬКО на карте Припяти (выживание - ярус 1 - всегда clean).
## Все множители - поверх существующих систем (умножение, не замена).
## Спека: design_inbox/pripyat_radiation/pripyat_radiation.md.

# Границы зон по дистанции до точки Саркофага, м. Подобраны под текущий
# MONOLITH_ROUTE (ярусы 1-4 дальше 2600 м; 5-7 - 1500-2600; 8 - 952;
# 9-10 - ближе 400). Уточнение маршрута точками карты зоны не ломает.
const ZONE_BANDS := [
	{"id": "lethal", "max_dist": 400.0,  "bg": 7500.0, "title_ru": "СМЕРТЕЛЬНЫЙ ФОН", "title_en": "LETHAL BACKGROUND"},
	{"id": "high",   "max_dist": 1500.0, "bg": 1200.0, "title_ru": "СИЛЬНЫЙ ФОН",     "title_en": "HIGH BACKGROUND"},
	{"id": "low",    "max_dist": 2600.0, "bg": 300.0,  "title_ru": "СЛАБЫЙ ФОН",      "title_en": "LOW BACKGROUND"},
	{"id": "clean",  "max_dist": 1.0e9,  "bg": 40.0,   "title_ru": "ЧИСТАЯ ЗОНА",     "title_en": "CLEAN ZONE"},
]

# Эффекты по id зоны. bg - число для HUD (мкЗв/ч), механика - на множителях.
const ZONE_EFFECTS := {
	"clean":  {"regen_mult": 1.0,  "anomaly_cost_mult": 1.0,  "drain_hp": 0.0,
		"drain_hp_master": 0.0,  "reward_mult": 1.0,  "postfx_mult": 1.0},
	"low":    {"regen_mult": 0.9,  "anomaly_cost_mult": 1.10, "drain_hp": 0.3,
		"drain_hp_master": 0.1,  "reward_mult": 1.10, "postfx_mult": 1.05},
	"high":   {"regen_mult": 0.8,  "anomaly_cost_mult": 1.25, "drain_hp": 0.8,
		"drain_hp_master": 0.3,  "reward_mult": 1.25, "postfx_mult": 1.10},
	"lethal": {"regen_mult": 0.65, "anomaly_cost_mult": 1.40, "drain_hp": 1.5,
		"drain_hp_master": 0.5,  "reward_mult": 1.50, "postfx_mult": 1.20},
}

# Косметика (не баланс): цвета зон. HUD-индикатор - жёлто-красная гамма
# опасности, свет Монолита - «фонит зелёным» по нарастанию.
const HUD_COLORS := {
	"clean": Color(0.55, 0.75, 0.5),
	"low": Color(0.85, 0.8, 0.35),
	"high": Color(0.9, 0.55, 0.25),
	"lethal": Color(0.85, 0.25, 0.2),
}
const LIGHT_COLORS := {
	"clean": Color(0.95, 0.95, 0.9),
	"low": Color(0.6, 0.8, 0.55),
	"high": Color(0.4, 0.85, 0.4),
	"lethal": Color(0.3, 1.0, 0.3),
}

# Тик дрейфа HP сталкеров
const RAD_TICK_INTERVAL: float = 1.0   # раз в секунду; крупнее - рывками, мельче - даром процессор
# Пол общий для всех тиков (сталкер не умирает от фона быстрее, чем за N сек):
const RAD_EXECUTION_FLOOR: float = 0.0 # 0 = фон добивает; 5.0 = фон оставляет 5 HP (мягкий вариант)

# Капы согласования с другими системами
const POSTFX_TOTAL_CAP: float = 1.6        # общий кап «мрачности» (ночь + фон + карта)
const MAX_TOTAL_REGEN_MULT: float = 0.35   # реген: туман x фон не глубже этого (0.5x0.65=0.325 - впритык, ок)

# Ручки перебора:
# - поздняя кампания стала невыносимой -> drain_hp -30% и anomaly_cost_mult -0.05 во всех зонах
# - инфляция наград -> reward_mult в high/lethal: 1.25/1.5 -> 1.15/1.3
# - наоборот, фону не хватает веса -> lethal: regen 0.6, cost 1.5, drain 2.0


## Зона по расстоянию до Саркофага (метры)
static func get_zone_by_distance(dist: float) -> String:
	for band in ZONE_BANDS:
		if dist <= float(band["max_dist"]):
			return String(band["id"])
	return "clean"


## Эффекты зоны (словарь из ZONE_EFFECTS; clean - если id неизвестен)
static func get_effects(zone_id: String) -> Dictionary:
	return ZONE_EFFECTS.get(zone_id, ZONE_EFFECTS["clean"])


## Данные зоны для HUD (фон мкЗв/ч + название), по id
static func get_zone_info(zone_id: String) -> Dictionary:
	for band in ZONE_BANDS:
		if band["id"] == zone_id:
			return band
	return ZONE_BANDS[ZONE_BANDS.size() - 1]


## Зона по уровню кампании/этажу башни без карты (fallback, если позиция
## ещё не известна): ярус = (level-1)/10 + 1, ярусы 1-4 clean, 5-7 low,
## 8 high, 9-10 lethal. Дублирует полосы - второстепенный путь.
static func get_zone_for_level(level: int) -> String:
	var tier: int = clampi((level - 1) / 10 + 1, 1, 10)
	if tier <= 4:
		return "clean"
	if tier <= 7:
		return "low"
	if tier == 8:
		return "high"
	return "lethal"
