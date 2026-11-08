# data/events_data.gd
extends RefCounted
class_name EventsData

## Циклические события live-ops (спека D24, design_inbox/liveops_events):
## полугодовой календарь 26 недель = 13 ивентов по 2 недели, 6 мини-игр.
## Валюта ивента — «Осколки Зоны», сгорают в финале полугодия.

const HALF_YEAR_WEEKS: int = 26
const EVENT_LENGTH_WEEKS: int = 2

# Тест-переключатель: принудительный ивент ("uley", "labyrinth", ...).
# Работает ТОЛЬКО в debug-сборках (OS.is_debug_build) — в релизе игнор.
# static (не const): current_event() статическая и читает её
static var FORCE_EVENT: String = ""   # чек-лист релиза: пусто, ивент по календарю

## ТЕСТ-СТЕНД владельца: в хабе ивентов открыт блок со ВСЕМИ шестью
## мини-играми независимо от календаря (руками протестировать каждую).
## Только в dev-сборках (OS.is_debug_build) — тот же паттерн, что у
## FORCE_EVENT и П0: в релизный АПК тест-стенд попасть не может.
static var TEST_STAND: bool = OS.is_debug_build()

# 13 слотов полугодия (id мини-игры)
const SCHEDULE := ["zharva", "uley", "labyrinth", "chain", "zharva2",
	"vault", "bolts", "uley2", "labyrinth2", "chain2", "vault2", "bolts2",
	"finale"]

# Базовые ивенты: имя/описание/осколки за очко (повторы наследуют с ×1.1)
const EVENTS := {
	"zharva": {"title_ru": "ЖАТВА", "title_en": "HARVEST",
		"desc_ru": "Артефакты созрели — собирай урожай линиями по три.",
		"desc_en": "The artifacts have ripened — harvest lines of three.",
		"shards_per_score": 0.01},
	"uley": {"title_ru": "УЛЕЙ", "title_en": "THE HIVE",
		"desc_ru": "Ты — Химера. Пять комнат, волны сталкеров, Бункер-командир.",
		"desc_en": "You are the Chimera. Five rooms, stalker waves, the Bunker commander.",
		"shards_per_score": 1.0 / 150.0},
	"labyrinth": {"title_ru": "ЛАБИРИНТ ВЫБРОСА", "title_en": "BLOWOUT LABYRINTH",
		"desc_ru": "Сталкеры идут к выходу. Строй аномалии — жги и задерживай.",
		"desc_en": "Stalkers march to the exit. Build anomalies - burn and delay.",
		"shards_per_score": 1.0 / 80.0},
	"chain": {"title_ru": "ЦЕПЬ ЭЛЕКТРЫ", "title_en": "ELECTRA CIRCUIT",
		"desc_ru": "Вращай трубы, замкни цепь от Теслы к Монолиту.",
		"desc_en": "Rotate pipes, close the circuit from Tesla to the Monolith.",
		"shards_per_score": 1.0 / 300.0},
	"vault": {"title_ru": "ВЗЛОМ КОТЕЛКА", "title_en": "KOTELOK'S VAULT",
		"desc_ru": "Сейфы с кодом из аномалий. Электра подсказывает.",
		"desc_en": "Vaults with an anomaly code. Electra gives hints.",
		"shards_per_score": 1.0 / 40.0},
	"bolts": {"title_ru": "БОЛТЫ ГРАВИТОНА", "title_en": "GRAVITON BOLTS",
		"desc_ru": "Рогатка и гравитационные карманы — порази мишени дугой.",
		"desc_en": "A slingshot and gravity wells - hit targets with an arc.",
		"shards_per_score": 1.0 / 200.0},
	"finale": {"title_ru": "ПОЛУГОДИЕ ЗОНЫ", "title_en": "HALF-YEAR OF THE ZONE",
		"desc_ru": "Все ивенты открыты. Финальная распродажа осколков.",
		"desc_en": "All events open. Final shard sale.",
		"shards_per_score": 0.01},
}

# Вехи: счёт за ивент -> награда payload
const MILESTONE_SCORES := [200, 400, 600, 800, 1000, 1200, 1400, 1600, 1800, 2000]
const MILESTONE_REWARDS := [
	{"rolls_mut": 2},
	{"rolls_art": 2},
	{"bio": 20000.0},
	{"rolls_mut": 3},
	{"cos_frame": "frame_event"},
	{"rolls_art": 3},
	{"sparks": 10},
	{"rolls_mut": 4},
	{"bio": 50000.0},
	{"cos_title": "title_event", "cos_frame": "frame_event2"},
]

# Магазин ивента (осколки -> payload)
const SHOP := {
	"shop_rolls_mut": {"shards": 150, "rolls_mut": 1, "name_ru": "Крутка мутантов", "name_en": "Mutant roll"},
	"shop_rolls_art": {"shards": 150, "rolls_art": 1, "name_ru": "Крутка артефактов", "name_en": "Artifact roll"},
	"shop_sparks": {"shards": 250, "sparks": 10, "name_ru": "Искры ×10", "name_en": "Sparks ×10"},
	"shop_bio": {"shards": 100, "bio": 50000.0, "name_ru": "Биомасса 50К", "name_en": "Biomass 50K"},
	"shop_frame": {"shards": 600, "cos_frame": "frame_event", "name_ru": "Рамка ивента", "name_en": "Event frame"},
}

## Ивент по номеру недели с эпохи; returns {id, base, title, desc, mult, ends_unix, days_left}
static func current_event(now_unix: int) -> Dictionary:
	var ev := _calendar_event(now_unix)
	# Тест-гейт: форс только в debug-сборках (в релизе календарь честный)
	if FORCE_EVENT != "" and OS.is_debug_build() and EVENTS.has(FORCE_EVENT):
		var base: String = FORCE_EVENT.trim_suffix("2")
		if base == "finale":
			base = "zharva"
		var info: Dictionary = EVENTS[base]
		# форс финала тоже показывает его титул (механика — база Жатвы)
		if FORCE_EVENT.begins_with("finale"):
			info = EVENTS["finale"]
		ev["id"] = FORCE_EVENT
		ev["base"] = base
		ev["title_ru"] = str(info["title_ru"])
		ev["title_en"] = str(info["title_en"])
		ev["desc_ru"] = str(info["desc_ru"])
		ev["desc_en"] = str(info["desc_en"])
		ev["mult"] = 1.1 if FORCE_EVENT.ends_with("2") else 1.0
	return ev


static func _calendar_event(now_unix: int) -> Dictionary:
	var week: int = int(now_unix / 604800.0)  # недель с эпохи (Чт 00:00 UTC — историческое)
	var slot: int = week % HALF_YEAR_WEEKS
	var season: int = week / HALF_YEAR_WEEKS
	# Ивент = ПАРА недель (13 ивентов × 2 = 26): SCHEDULE короткий (13),
	# индекс — номер ПАРЫ. Голое SCHEDULE[slot] падало out-of-bounds на
	# неделях 13–25 полугодия (включая финал) — поймано тестом test_mail.
	var event_key: String = SCHEDULE[slot / EVENT_LENGTH_WEEKS]
	var base: String = event_key.trim_suffix("2")
	if base == "finale":
		base = "zharva"
	var info: Dictionary = EVENTS.get(base, EVENTS["zharva"])
	# Неделя финала: титул/описание — свои («ПОЛУГОДИЕ ЗОНЫ»), механика
	# недели остаётся базой Жатвы (base не трогаем — флаги финала по id)
	if event_key == "finale":
		info = EVENTS["finale"]
	var weeks_left: int = EVENT_LENGTH_WEEKS - slot % EVENT_LENGTH_WEEKS  # нужен для desc
	var end_unix: int = (week / EVENT_LENGTH_WEEKS + 1) * EVENT_LENGTH_WEEKS * 604800
	var days_left: int = int(ceil(float(end_unix - now_unix) / 86400.0))
	var mult: float = 1.0
	if event_key.ends_with("2"):
		mult = 1.1
	return {
		"id": event_key, "base": base, "season": season, "slot": slot,
		"title_ru": str(info["title_ru"]), "title_en": str(info["title_en"]),
		"desc_ru": str(info["desc_ru"]), "desc_en": str(info["desc_en"]),
		"mult": mult, "end_unix": end_unix, "days_left": maxi(1, days_left),
	}


## Осколки за очки (повторные ивенты ×1.1)
static func shards_for(event_key: String, score: int) -> int:
	var base: String = event_key.trim_suffix("2")
	if base == "finale":
		base = "zharva"
	var rate: float = float(EVENTS.get(base, EVENTS["zharva"])["shards_per_score"])
	if event_key.ends_with("2"):
		rate *= 1.1
	return int(round(float(score) * rate))
