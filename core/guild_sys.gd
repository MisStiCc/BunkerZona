# core/guild_sys.gd
extends RefCounted
class_name GuildSys

## Состояние гильдии (D21 офлайн): боты-соседи, казна, недельный босс,
## чат-дневник. Хранится в save.guild_state (на онлайне заменяется сервером).

# ==================== ИНИЦИАЛИЗАЦИЯ ====================

static func ensure(save) -> Dictionary:
	if save == null:
		return {}
	var g: Dictionary = save.guild_state
	if g.is_empty():
		g = {
			"name": GuildData.GUILD_NAME,
			"xp": 0,
			"treasury": 0,
			"tokens": 0,
			"week": "",
			"boss_dmg": 0,
			"boss_slain": 0,
			"help_date": "",
			"bot_date": "",
			"raids_date": "",
			"raids_today": 0,
			"chat": [],
		}
		save.guild_state = g
	ensure_week(save, g)
	# D23 миграция старых сейвов: неделя уже идёт, а войны нет - объявляем сразу
	if not g.is_empty() and str(g.get("week", "")) == week_key() and g.get("war", {}).is_empty():
		g["war"] = _war_new(g)
		add_chat(g, "Старина Крот", "⚔ ВОЙНА: нас вызвала %s. Оборона Бункера - %d попытки за неделю!" % [
			str(g["war"]["enemy"]), GuildData.WAR_ATTEMPTS])
	return g


static func week_key() -> String:
	# номер недели: дни с эпохи / 7 (достаточно для ротации боссов)
	var days: int = int(Time.get_unix_time_from_system() / 86400.0)
	return "W%02d" % (days % 52)


## Цикл NG+ из сейва (через gm-группу; 1 если недоступно)
static func cycle() -> int:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return 1
	var zc = tree.get_first_node_in_group("game_manager")
	if zc and zc.get("current_save_data") != null and zc.current_save_data != null \
			and "campaign_cycle" in zc.current_save_data:
		return int(zc.current_save_data.campaign_cycle)
	return 1


## Смена недели -> новый босс, свежий пул
static func ensure_week(save, g: Dictionary) -> void:
	var wk := week_key()
	if str(g.get("week", "")) == wk:
		return
	g["week"] = wk
	if g.get("boss_dmg", 0) > 0 or g.has("boss_pool"):
		add_chat(g, "Старина Крот", "Новая неделя - новый Гильд-босс. Готовь отряд.")
	g["boss_dmg"] = 0
	g["boss_pool"] = fresh_pool(int(g.get("boss_slain", 0)))
	# D23 ВОЙНА: прошлая резолвится финально (если не доиграна - по счёту),
	# объявляется новая. Звук/баннер - на UI при открытии гильдии (war.fresh)
	var war: Dictionary = g.get("war", {})
	if not war.is_empty() and str(war.get("week", "")) != wk and str(war.get("state", "open")) == "open":
		_war_resolve(g)
	g["war"] = _war_new(g)
	add_chat(g, "Старина Крот", "⚔ ВОЙНА: нас вызвала %s. Оборона Бункера - %d попытки за неделю!" % [str(g["war"]["enemy"]), GuildData.WAR_ATTEMPTS])


# ==================== ВОЙНА (D23) ====================

## Лаба через gm-группу (для силы оборонного отряда)
static func _lab_data():
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var gm = tree.get_first_node_in_group("game_manager")
	if gm and gm.has_method("get_lab_data"):
		return gm.get_lab_data()
	return null


## Сила обороны: размер отряда + звёзды видов + уровень гильдии
static func _defense_power(g: Dictionary) -> int:
	var squad: Array = []
	var star_sum: int = 0
	var lab = _lab_data()
	if lab:
		squad = lab.arena_defense_squad
		for t in squad:
			star_sum += maxi(lab.get_mutant_stars(str(t)), 1)
	return 400 + 140 * squad.size() + 70 * star_sum + 25 * (guild_level(g) - 1)


## Новая война недели: соперник и его сила детерминированы seed'ом недели
static func _war_new(g: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = week_key().hash()
	var name_w: String = "Гильдия «%s %s»" % [
		GuildData.WAR_ENEMY_ADJ[rng.randi() % GuildData.WAR_ENEMY_ADJ.size()],
		GuildData.WAR_ENEMY_NOUN[rng.randi() % GuildData.WAR_ENEMY_NOUN.size()]]
	var spread: float = 1.25 - rng.randf() * GuildData.WAR_POWER_SPREAD
	return {
		"week": week_key(),
		"enemy": name_w,
		"power": maxi(int(float(_defense_power(g)) * spread), 300),
		"my_score": 0, "enemy_score": 0,
		"attempts": 0,
		"state": "open",
		"fresh": true,
		"result_fresh": false,
	}


## Итог попытки обороны (зовёт gm после забега с флагом war_defense).
## Ничья трактуется как победа «по воле Зоны»
static func report_war_score(g: Dictionary, waves: int) -> Dictionary:
	var war: Dictionary = g.get("war", {})
	if war.is_empty() or str(war.get("state", "open")) != "open":
		return {}
	war["attempts"] = int(war.get("attempts", 0)) + 1
	war["my_score"] = maxi(int(war.get("my_score", 0)), waves)
	# Симуляция соперника: первая попытка - 55% силы; дальше «отзываются»
	# на твою лучшую (92% + 10% силы), чтобы драма решалась второй попыткой
	var power: int = int(war.get("power", 1000))
	if int(war["attempts"]) <= 1:
		war["enemy_score"] = int(power * 0.55)
	else:
		war["enemy_score"] = maxi(int(war.get("enemy_score", 0)),
			int(float(war["my_score"]) * GuildData.WAR_ENEMY_FIGHT + power * 0.10))
	add_chat(g, "Разведка", "Попытка %d: мы держим %d волн, у них %d." % [
		int(war["attempts"]), int(war["my_score"]), int(war["enemy_score"])])
	var res := {"resolved": false, "won": false,
		"my": int(war["my_score"]), "enemy": int(war["enemy_score"])}
	if int(war["attempts"]) >= GuildData.WAR_ATTEMPTS:
		var final := _war_resolve(g)
		res["resolved"] = true
		res["won"] = bool(final.get("won", false))
		res["treasury"] = int(final.get("treasury", 0))
	g["war"] = war
	return res


## Резолюция открытой войны по текущему счёту (попытки кончились или
## неделя сменилась): выплаты, флаги, чат
static func _war_resolve(g: Dictionary) -> Dictionary:
	var war: Dictionary = g.get("war", {})
	if war.is_empty() or str(war.get("state", "open")) != "open":
		return war
	var won: bool = int(war.get("my_score", 0)) >= int(war.get("enemy_score", 0))
	war["state"] = "won" if won else "lost"
	war["result_fresh"] = true
	var my: int = int(war.get("my_score", 0))
	var en: int = int(war.get("enemy_score", 0))
	if won:
		var gain: int = GuildData.WAR_WIN_TOKENS + GuildData.WAR_WIN_PER_LEVEL * (guild_level(g) - 1)
		g["treasury"] = int(g.get("treasury", 0)) + gain
		g["tokens"] = int(g.get("tokens", 0)) + GuildData.WAR_WIN_PERSONAL
		g["war_wins"] = int(g.get("war_wins", 0)) + 1
		g["war_streak"] = int(g.get("war_streak", 0)) + 1
		war["treasury_gain"] = gain
		add_chat(g, "Старина Крот", "⚔ ПОБЕДА %d-%d! В казну +%d жетонов, каждому по %d." % [
			my, en, gain, GuildData.WAR_WIN_PERSONAL])
	else:
		g["tokens"] = int(g.get("tokens", 0)) + GuildData.WAR_LOSE_PERSONAL
		g["war_streak"] = 0
		var rng := RandomNumberGenerator.new()
		rng.seed = str(war.get("week", "")).hash()
		var mocks := [
			"Ваш Бункер скрипит. Мы постучим ещё.",
			"Слабо. Догоняйте к следующей неделе.",
			"Зона смеётся над вашей обороной.",
			"Забирайте утешение и растите.",
		]
		add_chat(g, str(war.get("enemy", "Соперник")), mocks[rng.randi() % mocks.size()])
		add_chat(g, "Старина Крот", "Проиграли %d-%d. Собрать отряд и вернуть долг." % [my, en])
	g["war"] = war
	return war


## Целевой пул HP босса на неделю (растёт со сленами и циклом NG+)
static func boss_pool(g: Dictionary) -> float:
	var slain: int = int(g.get("boss_slain", 0))
	var cycle_v: int = cycle()
	return GuildData.BOSS_POOL_BASE * pow(GuildData.BOSS_POOL_CYCLE_MULT, float(slain)) \
		* (1.0 + 0.15 * float(maxi(cycle_v, 1) - 1))

static func fresh_pool(slain: int) -> float:
	return GuildData.BOSS_POOL_BASE * pow(GuildData.BOSS_POOL_CYCLE_MULT, float(maxi(slain, 0))) \
		* (1.0 + 0.15 * float(maxi(cycle(), 1) - 1))


## Остаток HP босса на этой неделе
static func boss_hp_left(g: Dictionary) -> float:
	return maxf(boss_pool(g) - float(g.get("boss_dmg", 0)), 0.0)


static func boss_id() -> String:
	var ids: Array = BossHuntData.BOSSES.keys()
	return str(ids[week_key().hash() % ids.size()])


# ==================== БОТЫ ====================

## Состав: ты + 29 ботов (детерминированные по индексу)
static func members(g: Dictionary) -> Array:
	var out: Array = []
	out.append({"name": "Комендант (ты)", "power": _player_power(g), "bot": false,
		"contribution": int(g.get("boss_dmg", 0)), "online": true})
	var seed_n := 0
	for bot_name in GuildData.BOT_NAMES:
		seed_n += 1
		var pw: int = 600 + (seed_n * 137) % 2400
		var contrib: Dictionary = g.get("bot_contrib", {})
		var contrib_n: int = int(contrib.get(str(bot_name), 0))
		out.append({"name": str(bot_name), "power": pw, "bot": true,
			"contribution": contrib_n, "online": (seed_n + int(g.get("day_n", 0))) % 3 != 0})
	return out


static func _player_power(g: Dictionary) -> int:
	return 800 + int(g.get("boss_dmg", 0)) % 3000


## Суточный тик ботов (первое открытие гильдии за день)
static func bot_daily(save, g: Dictionary) -> Array:
	var today: String = Time.get_date_string_from_system()
	if str(g.get("bot_date", "")) == today:
		return []
	g["bot_date"] = today
	g["day_n"] = int(g.get("day_n", 0)) + 1
	var pool: float = boss_pool(g)
	var bot_dmg: int = int(pool * GuildData.BOT_DAILY_DMG_FRACTION * randf_range(0.7, 1.3))
	g["boss_dmg"] = int(g.get("boss_dmg", 0)) + bot_dmg
	g["treasury"] = int(g.get("treasury", 0)) + GuildData.BOT_TREASURY_DAILY
	var contrib: Dictionary = g.get("bot_contrib", {})
	for bot_name in GuildData.BOT_NAMES:
		contrib[bot_name] = int(contrib.get(bot_name, 0)) + int(bot_dmg / float(GuildData.BOT_NAMES.size()))
	g["bot_contrib"] = contrib
	var msgs: Array = []
	msgs.append({"who": GuildData.BOT_NAMES[int(g.get("day_n", 0)) % GuildData.BOT_NAMES.size()],
		"text": "Внес %d урона по боссу за сегодня." % bot_dmg})
	msgs.append({"who": "Старина Крот", "text": _idle_line()})
	for m in msgs:
		add_chat_dict(g, m)
	_check_slain(save, g)
	return msgs


static func _idle_line() -> String:
	var lines := [
		"Кто на босса сегодня? Набираю отряд.",
		"Казна растёт - уровень вот-вот поднимем.",
		"Слышал, сталкеры у периметра шуруют. Не наш вопрос.",
		"Мутанты откормленные ходят - видно, хозяйство ведёшь.",
		"Эхо держится? Рубежи - это святое.",
	]
	return lines[randi() % lines.size()]


## Реакция ботов после рейда игрока
static func after_raid(g: Dictionary, dmg: int) -> void:
	if dmg > 8000:
		add_chat(g, "Ржавый Фёдор", "Ну и жару ты навёл: %d за заход!" % dmg)
	elif dmg > 2000:
		add_chat(g, "Тихон", "Добротный заход, %d урона." % dmg)
	else:
		add_chat(g, "Гайка", "%d урона... Досягнем пул, не переживай." % dmg)


# ==================== БОСС: урон/слен/жетоны ====================

## Засчитать урон игрока по боссу. Возвращает {tokens, slain}
static func raid_damage(save, g: Dictionary, dmg: int) -> Dictionary:
	g["boss_dmg"] = int(g.get("boss_dmg", 0)) + dmg
	var tokens: int = mini(int(float(dmg) * GuildData.TOKENS_PER_DAMAGE), GuildData.RAID_TOKEN_CAP)
	g["tokens"] = int(g.get("tokens", 0)) + tokens
	var res := {"tokens": tokens, "slain": false}
	_check_slain(save, g)
	res["slain"] = float(g.get("boss_dmg", 0)) >= boss_pool(g)
	return res


static func _check_slain(save, g: Dictionary) -> void:
	if float(g.get("boss_dmg", 0)) >= boss_pool(g):
		g["boss_slain"] = int(g.get("boss_slain", 0)) + 1
		g["tokens"] = int(g.get("tokens", 0)) + 100
		g["boss_dmg"] = 0
		add_chat(g, "Старина Крот", "БОСС ПОВЕРЖЕН! Жетоны и +10 круток всем, кто вносил.")


# ==================== ПОМОЩЬ БОТОВ (раз в день) ====================

static func call_help(save, g: Dictionary) -> String:
	var today: String = Time.get_date_string_from_system()
	if str(g.get("help_date", "")) == today:
		return "Боты уже помогали сегодня"
	g["help_date"] = today
	var dmg: int = int(boss_pool(g) * GuildData.CALL_HELP_DAILY_FRACTION * randf_range(0.8, 1.2))
	g["boss_dmg"] = int(g.get("boss_dmg", 0)) + dmg
	add_chat(g, "Варяг", "Откликнулись на зов: +%d урона по боссу." % dmg)
	_check_slain(save, g)
	return ""


# ==================== ЧАТ ====================

## Осталось бесплатных рейдов сегодня
static func raids_left_today(g: Dictionary) -> int:
	var today := Time.get_date_string_from_system()
	var used: int = int(g.get("raids_today", 0)) if str(g.get("raids_date", "")) == today else 0
	return maxi(GuildData.FREE_RAIDS_DAILY - used, 0)

## Отметить рейд (вызывает gm после зачёта урона)
static func note_raid(g: Dictionary) -> void:
	var today := Time.get_date_string_from_system()
	if str(g.get("raids_date", "")) == today:
		g["raids_today"] = int(g.get("raids_today", 0)) + 1
	else:
		g["raids_date"] = today
		g["raids_today"] = 1

static func add_chat(g: Dictionary, who: String, text: String) -> void:
	add_chat_dict(g, {"who": who, "text": text})


static func add_chat_dict(g: Dictionary, msg: Dictionary) -> void:
	var chat: Array = g.get("chat", [])
	chat.append({"who": str(msg.get("who", "")), "text": str(msg.get("text", "")),
		"d": Time.get_date_string_from_system()})
	while chat.size() > GuildData.CHAT_MAX:
		chat.pop_front()
	g["chat"] = chat


## Ответ бота на реплику игрока
static func bot_reply(g: Dictionary, player_text: String) -> String:
	var replies := [
		"Принято, командир.",
		"Понял, работаем.",
		"Босс тоже так думает... недолго.",
		"Казна не резиновая, но поддержим.",
		"К обеду подгребу с отрядом.",
	]
	var who: String = str(GuildData.BOT_NAMES[randi() % GuildData.BOT_NAMES.size()])
	add_chat(g, who, player_text)
	var r: String = replies[randi() % replies.size()]
	add_chat(g, who, r)
	return r


# ==================== КАЗНА/УРОВЕНЬ/МАГАЗИН ====================

static func contribute_treasury(g: Dictionary, sp: int) -> void:
	g["treasury"] = int(g.get("treasury", 0)) + sp
	g["xp"] = int(g.get("xp", 0)) + int(sp / float(GuildData.TREASURY_XP_PER))


static func guild_level(g: Dictionary) -> int:
	return 1 + int(int(g.get("xp", 0)) / float(GuildData.TREASURY_XP_PER))


## Перк гильдии: +1% HP мутантов за уровень (кап +10%)
static func perk_hp_bonus(g: Dictionary) -> float:
	return minf(float(guild_level(g) - 1) * GuildData.PERK_HP_PER_LEVEL, GuildData.PERK_HP_CAP)
