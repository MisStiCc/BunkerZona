# core/event_manager.gd
extends RefCounted
class_name EventOps

## Циклические события live-ops (D24): текущий ивент по дате, счёт,
## осколки, вехи, магазин. Статика над сейвом (паттерн GuildSys);
## дневник событий — онлайн-этап заменяет только источники лидербордов.

const SAVE_KEY := "event_state"


## Состояние ивента из сейва (с миграцией и сбросом на новом полугодии)
static func state(save) -> Dictionary:
	if save == null:
		return {}
	# сейв - Resource (SaveData): Object.get() принимает ТОЛЬКО имя свойства;
	# свойства нет/пусто -> свежий словарь
	var es_val = save.get(SAVE_KEY)
	var es: Dictionary = es_val if es_val is Dictionary else {}
	var ev := EventsData.current_event(int(Time.get_unix_time_from_system()))
	var season: int = int(ev["season"])
	if es.is_empty() or int(es.get("season", -1)) != season:
		es = {"season": season, "event_id": "", "score": 0, "best": 0,
			"shards": 0, "claimed": [], "bought": {}}
		save.set(SAVE_KEY, es)
	if str(es.get("event_id", "")) != str(ev["id"]):
		# новый ивент: счёт обнуляется, осколки и вехи живут всё полугодие
		es["event_id"] = str(ev["id"])
		es["score"] = 0
		save.set(SAVE_KEY, es)
	return es


## Добавить очки партии (возвращает начисленные осколки)
static func add_score(save, ev: Dictionary, score: int) -> int:
	var es := state(save)
	var same_evt: bool = str(es.get("event_id", "")) == str(ev["id"])
	var mult: float = float(ev["mult"]) if same_evt else 1.0
	var s := int(round(float(score) * mult))
	es["score"] = int(es.get("score", 0)) + s
	es["best"] = maxi(int(es.get("best", 0)), s)
	var shards: int = EventsData.shards_for(str(ev["id"]), s)
	# D27 дневной кап осколков (анти-фарм финала): 120/день
	var today: String = Time.get_date_string_from_system()
	if str(es.get("shard_day", "")) != today:
		es["shard_day"] = today
		es["shards_today"] = 0
	var room: int = maxi(EventsData.DAILY_SHARD_CAP - int(es.get("shards_today", 0)), 0)
	var granted: int = mini(shards, room)
	es["shards_today"] = int(es.get("shards_today", 0)) + granted
	es["shards"] = int(es.get("shards", 0)) + granted
	save.set(SAVE_KEY, es)
	# задачи Зоны: партии и очки ивентов (D25)
	var tree := Engine.get_main_loop() as SceneTree
	var prog = tree.root.get_node_or_null("Prog") if tree else null
	if prog and prog.has_method("bump_task"):
			prog.bump_task("event_games", 1)
			prog.bump_task("event_score", s)
	return granted


## Веха доступна к получению?
static func milestone_ready(es: Dictionary, idx: int) -> bool:
	if idx < 0 or idx >= EventsData.MILESTONE_SCORES.size():
		return false
	if int(es.get("claimed", []).find(idx)) != -1:
		return false
	return int(es.get("score", 0)) >= int(EventsData.MILESTONE_SCORES[idx])


## Забрать веху; возвращает payload или {}
static func claim_milestone(save, idx: int) -> Dictionary:
	var es := state(save)
	if not milestone_ready(es, idx):
		return {}
	es["claimed"] = es.get("claimed", []) + [idx]
	var prem: Dictionary = EventsData.MILESTONE_REWARDS[idx]
	_grant_payload(save, prem)
	save.set(SAVE_KEY, es)
	var tree := Engine.get_main_loop() as SceneTree
	var prog = tree.root.get_node_or_null("Prog") if tree else null
	if prog and prog.has_method("bump_task"):
			prog.bump_task("event_milestones", 1)
	return prem


## Купить позицию магазина; возвращает payload или {} (не хватило осколков)
static func shop_buy(save, shop_id: String) -> Dictionary:
	var es := state(save)
	if es.get("bought", {}).has(shop_id):
		return {}
	var item: Dictionary = EventsData.SHOP.get(shop_id, {})
	if item.is_empty() or int(es.get("shards", 0)) < int(item["shards"]):
		return {}
	es["shards"] = int(es["shards"]) - int(item["shards"])
	es["bought"] = es.get("bought", {})
	es["bought"][shop_id] = true
	var payload := {}
	for key in ["rolls_mut", "rolls_art", "sparks", "bio", "cos_frame"]:
		if item.has(key):
			payload[key] = item[key]
	_grant_payload(save, payload)
	save.set(SAVE_KEY, es)
	return payload


## Начислить payload через существующие системы (гача одна — правило проекта)
static func _grant_payload(save, payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var tree := Engine.get_main_loop() as SceneTree
	var gm = tree.get_first_node_in_group("game_manager") if tree else null
	if gm == null:
		return
	if int(payload.get("rolls_mut", 0)) > 0:
		gm.grant_mutant_rolls(int(payload["rolls_mut"]), "ивент")
	if int(payload.get("rolls_art", 0)) > 0:
		gm.grant_anomaly_rolls(int(payload["rolls_art"]), "ивент")
	if float(payload.get("bio", 0.0)) > 0.0 and gm.get_lab_data():
		gm.get_lab_data().biomass += float(payload["bio"])
	for cos_key in ["cos_frame", "cos_avatar", "cos_title", "cos_set"]:
		if payload.has(cos_key) and gm.current_save_data != null:
			gm.current_save_data.owned["cos_" + str(payload[cos_key])] = true
	var sparks := int(payload.get("sparks", 0))
	if sparks > 0 and gm.current_save_data != null:
		var lab = gm.get_lab_data()
		if lab:
			lab.awaken_sparks = int(lab.get("awaken_sparks", 0)) + sparks
	gm.save_to_active_slot()
