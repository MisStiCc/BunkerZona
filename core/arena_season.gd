# core/arena_season.gd
extends RefCounted
class_name ArenaSeason

## Сезоны арены (D25, по фидбеку владельца): понедельничный rollover —
## сброс сезонных задач/медалей/счётчиков, расчёт места, награда «письмом»
## в ящик лаборатории (забирается кнопкой). Офлайн детерминирован; онлайн-
## этап (Этап 3) подменит только список членов борда.
## Место в рейтинге: лучшие волны СЕЗОНА против соперников недели
## (соперники генерируются seed'ом сезона — у всех один сезон-сетап).
## ДВЕ таблицы соперников (решение владельца 02.11.2026): rivals() —
## зал славы арены (сетка 30+3/сезон), LETTER_RIVALS — место в письме
## итогов (фиксированные волны «лиг»). ЕДИНАЯ точка rollover — здесь:
## ensure_season зовут и лаба (арена), и MailOverlay.open(); ключ сезона
## один — "S<N>" (N = недели от базы), вторых схем ключей быть не должно.

const SEASON_START_UNIX := 1789670400   # Пн 19.10.2026 00:00 локального (база код-агента)
const WEEK: int = 604800

## Номер сезона и границы текущего сезона
static func season_info() -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var idx: int = int(floor(maxf(0.0, now - SEASON_START_UNIX) / float(WEEK)))
	var start_unix: int = SEASON_START_UNIX + idx * WEEK
	var end_unix: int = start_unix + WEEK
	return {"idx": idx, "start": start_unix, "end": end_unix,
		"left_days": maxi(0, int(ceil(float(end_unix - now) / 86400.0)))}


## Ключ сезона для полей lab_data
static func season_key() -> String:
	return "S%d" % season_info()["idx"]


## Соперники сезона: как _arena_make_rivals (имена/кланы), но волны —
## от сезона: ramp по номеру сезона, чтобы «Стрелок 44 волн» не жил вечно.
static func rivals(season_idx: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91000 + season_idx
	var defs := [
		["МЕЧЕНЫЙ", "«Легенда Зоны»", "Химера"],
		["СТРЕЛОК", "«Легенда Зоны»", "Кряж"],
		["ВОЛК", "«Долг»", "Пиявец"],
		["ПРИЗРАК", "«Свобода»", "Полтергейст"],
		["ЛУЧНИК", "«Наёмники»", "Сновод"],
		["КЛЫК", "«Наёмники»", "Сумеречник"],
		["ДЕГТЯРЁВ", "«Долг»", "Пиявец"],
		["БАРМЕН", "«Долг»", "Болотник"],
		["ШТЫРЬ", "«Одиночки»", "Сумеречник"],
		["КРОТ", "«Одиночки»", "Болотник"],
	]
	var top_wave: int = 30 + season_idx * 3          # топ соперника растёт по сезонам
	var out: Array = []
	for i in defs.size():
		var frac: float = 1.0 - float(i) / float(defs.size())
		var wave: int = clampi(int(round(float(top_wave) * (0.25 + 0.75 * frac)))
			+ rng.randi_range(-2, 2), 3, top_wave + 4)
		var power: int = wave * 500 + rng.randi_range(0, 900)
		out.append({"name": str(defs[i][0]), "clan": str(defs[i][1]),
			"power": power, "wave": wave, "pet": str(defs[i][2])})
	return out


## Rollover: смена сезона -> письмо с наградой за место + сброс сезонных
## полей lab_data. Вызывать из лабы при открытии арены/почты (статика).
## Письмо не приходит на первый запуск и в сезон без оборонённых волн.
## СЕЙВ — на вызывающих (UI-слой, gm.save_to_active_slot()): у SaveData
## нет метода сохранения, статика его дёргать не должна (паттерн GuildSys).
## Возврат: {} — сезона не менялся; {"changed": true} — rollover без письма;
## {"changed": true, "place": N, "reward": {...}} — rollover с письмом.
static func ensure_season(save) -> Dictionary:
	if save == null or save.lab_data == null:
		return {}
	var lab = save.lab_data
	var key := season_key()
	if lab.arena_season_key == key:
		return {}
	var prev_key: String = lab.arena_season_key
	lab.arena_season_key = key
	# сброс сезонных коллекций (прошлый сезон закрыт)
	lab.arena_medals_claimed = {}
	lab.arena_season_tasks_claimed = {}
	lab.arena_wins_challenge = 0
	lab.arena_wins_defense = 0
	var waves: int = lab.arena_season_waves
	lab.arena_season_waves = 0
	if prev_key == "" or waves <= 0:
		return {"changed": true}
	# письмо: место по сезонным волнам против ФИКСИРОВАННОЙ таблицы лиг
	var place: int = letter_place(season_idx_from_key(prev_key), waves)
	var reward := place_reward(place)
	var box: Array = save.guild_state.get("mail", [])
	box.insert(0, {
		"from": "АРЕНА «ВЫБРОС I»",
		"title_ru": "ИТОГИ СЕЗОНА: %d МЕСТО" % place,
		"title_en": "SEASON RESULT: PLACE %d" % place,
		"body_ru": "Лучшая оборона сезона: %d волн. Награда за место — в приложении." % waves,
		"body_en": "Best defense of the season: %d waves. The placement reward is attached." % waves,
		"reward": reward, "claimed": false,
	})
	save.guild_state["mail"] = box.slice(0, 30)
	return {"changed": true, "place": place, "reward": reward}


## Фиксированная таблица «лиг» для письма итогов (канон письма, решение
## владельца): волны соперников стоят на местах (топ-1 = 50) + рамп 3/сезон
## и джиттер seed'ом сезона. Зал славы считает СВОЮ сетку в rivals().
const LETTER_RIVALS := [
	["МЕЧЕНЫЙ", 50], ["СТРЕЛОК", 44], ["ВОЛК", 38], ["ПРИЗРАК", 32],
	["ЛУЧНИК", 26], ["КЛЫК", 21], ["ДЕГТЯРЁВ", 16], ["БАРМЕН", 12],
	["ШТЫРЬ", 8], ["КРОТ", 4],
]


## Место в письме: сколько «лиг» перекрыли наши сезонные волны
static func letter_place(season_idx: int, my_waves: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91700 + season_idx
	var place := 1
	for d in LETTER_RIVALS:
		var rival_wave: int = int(d[1]) + rng.randi_range(-2, 2) + season_idx * 3
		if rival_wave >= my_waves:
			place += 1
	return place


static func season_idx_from_key(key: String) -> int:
	var digits := ""
	for c in key:
		if c >= "0" and c <= "9":
			digits += c
	return int(digits) if digits != "" else season_info()["idx"]


## Награда за место (1-3 жирные, дальше — утешительные)
static func place_reward(place: int) -> Dictionary:
	match place:
		1: return {"rolls_mut": 20, "sparks": 10, "cos_frame": "frame_champion"}
		2: return {"rolls_mut": 12, "sparks": 6, "cos_frame": "frame_vice"}
		3: return {"rolls_mut": 8, "sparks": 4}
		_:
			if place <= 5:
				return {"rolls_mut": 5, "rolls_art": 2}
			return {"rolls_art": 1, "bio": 20000.0}


## Отметить сезонные волны (зывается из учёта забегов выживания/обороны;
## хранится только ЛУЧШАЯ оборона сезона)
static func note_season_wave(save, waves: int) -> void:
	if save == null or save.lab_data == null or waves <= 0:
		return
	if waves > save.lab_data.arena_season_waves:
		save.lab_data.arena_season_waves = waves
