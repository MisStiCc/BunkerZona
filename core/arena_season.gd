# core/arena_season.gd
extends RefCounted
class_name ArenaSeason

## Сезоны арены (D25, по фидбеку владельца): понедельничный rollover —
## сброс сезонных задач/медалей/счётчиков, расчёт места, награда «письмом»
## в ящик лаборатории (забирается кнопкой). Офлайн детерминирован; онлайн-
## этап (Этап 3) подменит только список членов борда.
## Место в рейтинге: лучшие волны СЕЗОНА против соперников недели
## (соперники генерируются seed'ом сезона — у всех один сезон-сетап).

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
## полей lab_data. Вызывать из лабы при открытии арены/лабы (статика).
static func ensure_season(save) -> Dictionary:
	if save == null or save.lab_data == null:
		return {}
	var lab = save.lab_data
	var key := season_key()
	if str(lab.get("arena_season_key", "")) == key:
		return {}
	# 1) вычислить место ЗА прошедший сезон: сезонные волны vs соперники
	#    того сезона (если поля нет — первый запуск, без письма)
	var prev_key := str(lab.get("arena_season_key", ""))
	lab.set("arena_season_key", key)
	# сброс сезонных коллекций
	lab.arena_medals_claimed = {}
	lab.arena_season_tasks_claimed = {}
	lab.arena_wins_challenge = 0
	lab.arena_wins_defense = 0
	if prev_key == "":
		save.save_to_active_slot()
		return {}
	# 2) письмо: место по сезонным волнам против соперников прошлого сезона
	var season_waves: int = int(lab.get("arena_season_waves", 0))
	var rivals := rivals(season_idx_from_key(prev_key))
	var my_wave: int = mini(season_waves, top_wave_of(rivals) + 5)
	var place: int = 1
	for r in rivals:
		if int(r["wave"]) > my_wave:
			place += 1
	var reward := place_reward(place)
	# 3) письмо в ящик
	var mail: Dictionary = save.get("guild_state", {}).get("mail", {})
	if save.get("guild_state") != null:
		var g: Dictionary = save.guild_state
		var box: Array = g.get("mail", [])
		box.insert(0, {
			"from": "АРЕНА «ВЫБРОС I»",
			"title_ru": "ИТОГИ СЕЗОНА: %d МЕСТО" % place,
			"title_en": "SEASON RESULT: PLACE %d" % place,
			"body_ru": "Сезон закрыт с %d волнами лучшей обороны. Награда за место — в приложении." % my_wave,
			"body_en": "The season closed with %d waves of your best defense. The placement reward is attached." % my_wave,
			"reward": reward, "claimed": false,
		})
		g["mail"] = box.slice(0, 30)
		lab.set("arena_season_waves", 0)   # сезонные волны — с нуля
	save.save_to_active_slot()
	return {"place": place, "reward": reward}


static func season_idx_from_key(key: String) -> int:
	var digits := ""
	for c in key:
		if c >= "0" and c <= "9":
			digits += c
	return int(digits) if digits != "" else season_info()["idx"]


static func top_wave_of(rivals: Array) -> int:
	var top := 10
	for r in rivals:
		top = maxi(top, int(r["wave"]))
	return top


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


## Отметить сезонные волны (зывается из учёта забегов выживания/обороны)
static func note_season_wave(save, waves: int) -> void:
	if save == null or save.lab_data == null:
		return
	var best: int = int(save.lab_data.get("arena_season_waves", 0))
	if waves > best:
		save.lab_data.set("arena_season_waves", waves)
