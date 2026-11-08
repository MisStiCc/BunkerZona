# data/store_data.gd
extends RefCounted
class_name StoreData

## Витрина и границы монетизации (спека D16, design_inbox/monetization).
##
## ГЛАВНЫЙ ВЫКЛЮЧАТЕЛЬ. Деговнизация (D17) выполнена 28.10.2026 -
## вариант А + «Глухая падь». true = витрина доступна.
##
## П0.1/П0.2 security_audit (03.11.2026): флаги — АВТО-ДЕТЕКТ сборки,
## «забыть выключить эмуляцию» физически невозможно: редактор/дев-сборка =
## витрина с эмуляцией, релизный экспорт = витрина закрыта. Когда будет
## настоящий биллинг (плагин GodotGooglePlayBilling + листинг без IP +
## юр.консультация — чек-лист Этапа 0 D16), поднять ENABLED для релиза
## отдельной ручкой здесь же. static var (не const): OS.is_debug_build()
## не константа времени компиляции.

## Ручка-оверрайд: true = витрина с эмуляцией в ЭКСПОРТНЫХ сборках тоже
## (дев-фаза по команде владельца 09.11.2026: «дай полную версию со всеми
## открыто»). К РЕЛИЗУ ДЛЯ ИГРОКОВ: перевернуть в false — витрина закроется
## в релизном экспорте (П0), включится настоящий биллинг когда подключён.
const FORCE_EMULATE: bool = true

static var ENABLED: bool = OS.is_debug_build() or FORCE_EMULATE

## ЭМУЛЯЦИЯ ПОКУПОК (dev): биллинга нет - "оплата" мгновенная и бесплатная,
## начисления настоящие (в сейв). Витрина помечена жёлтой плашкой ЭМУЛЯЦИЯ.
## В релизе всегда false (авто-детект выше).
static var EMULATE_PURCHASES: bool = OS.is_debug_build() or FORCE_EMULATE

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

## Фиксированные премии пропуска (ключевые ступени; чередования - генератором).
## Правило баланса: премиум ступени всегда жирнее бесплатного сундука над ним -
## полоса «★ ПРЕМИУМ» не имеет права выглядеть беднее (ревизия 09.11.2026).
const PASS_PREMIUM := {
	5: {"cos_frame": "frame_season", "rolls_mut": 3, "bio": 20000.0},
	10: {"cos_avatar": "avatar_season", "rolls_mut": 5, "rolls_art": 3},
	20: {"cos_title": "title_season", "rolls_art": 6, "bio": 50000.0},
	30: {"cos_set": "season_full", "rolls_mut": 12, "rolls_art": 8, "bio": 150000.0},
}
# Шаг чередования для рядов 1-9 / 11-19 / 21-29: цикл из трёх наград.
# Крутки всегда в паре с биомассой: голые «★мут ×2» выглядели беднее сундука.
const PASS_ALT_STEP := [
	{"rolls_mut": 2, "bio": 20000.0},
	{"rolls_art": 2, "bio": 20000.0},
	{"rolls_mut": 1, "rolls_art": 1, "bio": 35000.0},
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
## Чередования растут к концу сезона (полоса x1.0 -> x1.5 -> x2.0 - как у
## сундуков +50%) и x1.25 за цикл трека: премиум не отстаёт от циклов.
## Возвращает словарь payload ({} - ступень без премиума быть не может:
## премиум на КАЖДОЙ из 30 ступеней). duplicate() - константы заморожены.
static func premium_reward(tier: int, cycle: int = 1) -> Dictionary:
	if PASS_PREMIUM.has(tier):
		return PASS_PREMIUM[tier].duplicate()
	var band: int
	if tier <= 9:
		band = 0
	elif tier <= 19:
		band = 1
	else:
		band = 2
	var idx: int = (tier - 1 + band) % PASS_ALT_STEP.size()
	var prem: Dictionary = PASS_ALT_STEP[idx].duplicate()
	var mult: float = (1.0 + 0.5 * float(band)) * (1.0 + 0.25 * float(maxi(int(cycle), 1) - 1))
	if prem.has("bio"):
		prem["bio"] = float(prem["bio"]) * mult
	if prem.has("rolls_mut"):
		prem["rolls_mut"] = int(ceil(float(prem["rolls_mut"]) * mult))
	if prem.has("rolls_art"):
		prem["rolls_art"] = int(ceil(float(prem["rolls_art"]) * mult))
	return prem


## Премиум ступени пройден, но ещё не забран (трек/кнопка ЗАБРАТЬ ВСЁ)
static func prem_claim_pending(tier: int, cycle: int, owned: Dictionary) -> bool:
	return not owned.has("prem_%d_%d" % [cycle, tier])


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
