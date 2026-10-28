# data/store_data.gd
extends RefCounted
class_name StoreData

## Витрина и границы монетизации (спека D16, design_inbox/monetization).
##
## ГЛАВНЫЙ ВЫКЛЮЧАТЕЛЬ. true только после деговнизации (Этап 0, D17) и
## подключения биллинга. false = весь UI магазина скрыт, биллинг не стартует,
## игра остаётся бесплатной фан-игрой без покупок (юраудит §5).

const ENABLED: bool = false

## id SKU -> {type: "nc"|"c", price_rub: int, kind, payload}
## type: nc = non-consumable (владение навсегда), c = consumable.
const PRODUCTS := {
	"pass_s1": {"type": "nc", "price_rub": 299, "kind": "pass"},
	"offer_first": {"type": "c", "price_rub": 99, "kind": "pack",
		"rolls_mut": 3, "cos_frame": "frame_first_blood"},
	"rolls_mut_3": {"type": "c", "price_rub": 99, "kind": "rolls", "rolls_mut": 3},
	"rolls_mut_10": {"type": "c", "price_rub": 299, "kind": "rolls", "rolls_mut": 10},
	"rolls_mut_10p": {"type": "c", "price_rub": 499, "kind": "rolls", "rolls_mut": 12},
	"rolls_art_5": {"type": "c", "price_rub": 149, "kind": "rolls", "rolls_art": 5},
	"rolls_art_15": {"type": "c", "price_rub": 399, "kind": "rolls", "rolls_art": 15},
	"excl_choice": {"type": "c", "price_rub": 499, "kind": "excl"},
	"bio_50k": {"type": "c", "price_rub": 99, "kind": "bio", "bio": 50000.0},
	"bio_200k": {"type": "c", "price_rub": 299, "kind": "bio", "bio": 200000.0},
	"conv_slots12": {"type": "nc", "price_rub": 149, "kind": "conv", "slots": 12},
	"conv_autofill": {"type": "nc", "price_rub": 99, "kind": "conv", "autofill": true},
}

## Фиксированные премии пропуска (ключевые ступени; чередования - генератором)
const PASS_PREMIUM := {
	5: {"cos_frame": "frame_season"},
	10: {"rolls_mut": 4, "cos_avatar": "avatar_season"},
	20: {"rolls_art": 5, "cos_title": "title_season"},
	30: {"rolls_mut": 10, "cos_set": "season_full"},
}
# Шаг чередования для рядов 1-9 / 11-19 / 21-29: цикл из трёх наград
const PASS_ALT_STEP := [
	{"rolls_mut": 2},
	{"rolls_art": 2},
	{"bio": 20000.0},
]

## Граница торга: ЭТО НЕ ПРОДАЁМ НИКОГДА
const FORBIDDEN := ["energy_direct", "run_victory", "campaign_levels",
	"radiation_off", "timers", "stat_mults", "start_squads"]


## SKU пропуска для цикла N (свой non-consumable на сезон)
static func pass_sku(cycle: int) -> String:
	return "pass_s%d" % maxi(int(cycle), 1)


## Активен ли пропуск в текущем цикле (владение кэшируется в сейве)
static func pass_active(cycle: int, owned: Dictionary) -> bool:
	if not ENABLED:
		return false
	return owned.has(pass_sku(cycle))


## Премиум-награда ступени: фиксированные ключевые + чередование рядов.
## Возвращает словарь payload ({} - ступень без премиума быть не может:
## премиум на КАЖДОЙ из 30 ступеней).
static func premium_reward(tier: int, _cycle: int) -> Dictionary:
	if PASS_PREMIUM.has(tier):
		return PASS_PREMIUM[tier]
	var band: int
	if tier <= 9:
		band = 0
	elif tier <= 19:
		band = 1
	else:
		band = 2
	var idx: int = (tier - 1 + band) % PASS_ALT_STEP.size()
	return PASS_ALT_STEP[idx]


## Слоты набора: 12 при купленных conv_slots12, иначе 9
static func slots_allowed(owned: Dictionary) -> int:
	if ENABLED and owned.has("conv_slots12"):
		return 12
	return 9


## Автосбор фермы доступен при conv_autofill
static func autofill_enabled(owned: Dictionary) -> bool:
	return ENABLED and owned.has("conv_autofill")


## Косметика/удобства: владение (nc-покупки и награды пропуска)
static func cos_owned(owned: Dictionary, cos_id: String) -> bool:
	return owned.has("cos_" + cos_id) or owned.has(cos_id)
