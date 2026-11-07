# data/zone_mutations_data.gd
extends RefCounted
class_name ZoneMutations

## D28 МУТАЦИИ ЗОНЫ (NG+ витальность): с цикла 2+ каждый цикл получает
## 2-3 детерминированных правила-мутации — «характер цикла». Спека
## design_inbox/zone_mutations. Ранняя кампания и цикл 1 — чистые.

## Антагонисты, которые никогда не активны одновременно
const ANTAGONISTS := [
	["m_rain_heal", "m_rain_flood"],
	["m_mono_regen", "m_aging"],
]

## Таблица мутаций (15): id, RU/EN название, эффект одной строкой
const MUTATIONS := {
	"m_dual_art": {"ru": "ДВОЙНОЙ КЛАД", "en": "TWIN HOARDS", "effect_ru": "Сталкеры несут по 2 артефакта", "effect_en": "Stalkers carry 2 artifacts each"},
	"m_aging": {"ru": "СТАРЕЮЩИЕ АНОМАЛИИ", "en": "AGING ANOMALIES", "effect_ru": "Аномалии распадаются за 6 минут", "effect_en": "Anomalies decay in 6 minutes"},
	"m_rain_heal": {"ru": "БЛАГОСЛОВЕННЫЙ ДОЖДЬ", "en": "BLESSED RAIN", "effect_ru": "Дождь лечит сталкеров 2 ХП/с", "effect_en": "Rain heals stalkers 2 HP/s"},
	"m_mono_regen": {"ru": "АУРА МОНОЛИТА", "en": "MONOLITH AURA", "effect_ru": "Носители регенерируют 3 ХП/с у Монолита", "effect_en": "Carriers regen 3 HP/s near the Monolith"},
	"m_shield": {"ru": "ПАНЦИРИ", "en": "CARAPACES", "effect_ru": "Сталкеры стартуют со щитом 25% ХП", "effect_en": "Stalkers start with a 25% HP shield"},
	"m_sprint": {"ru": "СПРИНТЕРЫ", "en": "SPRINTERS", "effect_ru": "Скорость сталкеров +20%", "effect_en": "Stalker speed +20%"},
	"m_broken_map": {"ru": "ГЛУХАЯ КАРТА", "en": "DEAD MAP", "effect_ru": "Мини-карта глухая", "effect_en": "The minimap is dead"},
	"m_greed": {"ru": "ЖАДНОСТЬ ЗОНЫ", "en": "ZONE'S GREED", "effect_ru": "Биомасса ×0.8, артефакты ×1.5 ценой", "effect_en": "Biomass x0.8, artifacts x1.5 value"},
	"m_cold": {"ru": "ХОЛОД", "en": "COLD", "effect_ru": "Реген энергии ×0.85", "effect_en": "Energy regen x0.85"},
	"m_swarm": {"ru": "РОЕНИЕ", "en": "SWARMING", "effect_ru": "Волны +15% сталкеров", "effect_en": "Waves +15% stalkers"},
	"m_elite": {"ru": "ЭЛИТА", "en": "ELITE", "effect_ru": "Каждый 5-й сталкер - мастер", "effect_en": "Every 5th stalker is a master"},
	"m_fog": {"ru": "ЭМ-ТУМАН ВЕЧЕН", "en": "EM FOG ETERNAL", "effect_ru": "Туман не рассеивается весь забег", "effect_en": "The fog never lifts"},
	"m_loot_curse": {"ru": "ПРОКЛЯТЫЕ СКЛАДЫ", "en": "CURSED STORES", "effect_ru": "Сундуки кампании - вдвое реже", "effect_en": "Campaign chests are twice as rare"},
	"m_rain_flood": {"ru": "ПРОКЛЯТЫЙ ДОЖДЬ", "en": "CURSED RAIN", "effect_ru": "Дождь ускоряет сталкеров на 15%", "effect_en": "Rain speeds stalkers by 15%"},
	"m_silent": {"ru": "ТИШИНА", "en": "SILENCE", "effect_ru": "Предупреждений о волнах нет", "effect_en": "No wave warnings"},
}


## Активные мутации цикла: детерминированно, 2 (с 5-го цикла 3),
## антагонисты не совпадают. Возвращает Array[String] id
static func active_for_cycle(cycle: int) -> Array:
	if cycle < 2:
		return []
	var ids: Array = MUTATIONS.keys()
	var picks: Array = []
	var i1: int = (cycle * 7) % ids.size()
	var i2: int = (cycle * 7 + 5) % ids.size()
	picks.append(str(ids[i1]))
	picks.append(str(ids[i2]))
	if cycle >= 5:
		var i3: int = (cycle * 11) % ids.size()
		if not picks.has(str(ids[i3])):
			picks.append(str(ids[i3]))
	# антагонисты: второй из пары заменяется сдвигом
	for pair in ANTAGONISTS:
		var both: int = 0
		for p in picks:
			if pair.has(str(p)):
				both += 1
		if both >= 2:
			var repl: int = (int(picks[0]) + 3) % ids.size()
			picks[1] = str(ids[repl])
	return picks


## Активны ли мутации в этом забеге (кампания, цикл 2+)
static func is_active(run_params: Dictionary) -> bool:
	return str(run_params.get("run_mode", "campaign")) == "campaign" \
		and int(run_params.get("campaign_cycle", 1)) >= 2
