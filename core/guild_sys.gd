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
			"chat": [],
		}
		save.guild_state = g
	ensure_week(save, g)
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
