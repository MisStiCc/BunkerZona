# ui/lab/guild_overlay.gd
extends CanvasLayer
class_name GuildOverlay

## ГИЛЬДИЯ (D21 офлайн): Обзор (состав/казна) · Босс (рейд) · Чат · Магазин.
## Слой 9, поверх панелей лабы. Боты детерминированы, чат - дневник событий.

const COL_GOLD := Color("ffd94d")
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)
const COL_PURPLE := Color(0.70, 0.40, 1.00)
const COL_GREEN := Color("a8ff7a")

var _root: Control = null
var _tabs_box: HBoxContainer = null
var _body: Control = null
var _page: int = 0
var _save = null
var _chat_log: VBoxContainer = null
var _quick_row: HBoxContainer = null


func _ready() -> void:
	layer = 9


func open(save) -> void:
	_save = save
	if _root == null:
		_build()
	GuildSys.ensure(_save)
	_refresh()
	_root.visible = true
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("guild_banner", 0.7)


func close() -> void:
	if _root:
		_root.visible = false


func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()


func _build() -> void:
	_root = Control.new()
	_root.name = "GuildRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_root.add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -430.0
	panel.offset_right = 430.0
	panel.offset_top = -370.0
	panel.offset_bottom = 370.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = COL_PURPLE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = Loc.t("guild.title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_PURPLE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	v.add_child(_tabs_box)

	_body = Control.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.clip_contents = true
	v.add_child(_body)


func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	for c in _tabs_box.get_children():
		c.queue_free()
	var tabs := [
		[Loc.t("guild.tab_overview"), 0],
		[Loc.t("guild.tab_boss"), 1],
		[Loc.t("guild.tab_chat"), 2],
		[Loc.t("guild.tab_shop"), 3],
	]
	for i in range(tabs.size()):
		var b := Button.new()
		b.text = str(tabs[i][0])
		b.toggle_mode = true
		b.button_pressed = i == _page
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func(): _play_click(); _page = i; _refresh())
		_tabs_box.add_child(b)
	# тело рендерит выбранная страница (все чистятся выше)
	match _page:
		0: _page_overview(_body)
		1: _page_boss(_body)
		2: _page_chat(_body)
		3: _page_shop(_body)


func _page_overview(body: Control) -> void:
	var g: Dictionary = GuildSys.ensure(_save)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	# Шапка гильдии: эмблема + имя/уровень + казна-полоса
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	var emblem := TextureRect.new()
	# Эмблема гильдии (щит с трефойлом, помощник); нет файла - лого стека
	var emblem_path := "res://assets/ui/guild/guild_emblem_256.png"
	if ResourceLoader.exists(emblem_path):
			emblem.texture = load(emblem_path)
	elif ResourceLoader.exists("res://assets/ui/brand/logo_stack.png"):
			emblem.texture = load("res://assets/ui/brand/logo_stack.png")
	emblem.custom_minimum_size = Vector2(96, 78)
	emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(emblem)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 2)
	head.add_child(hv)
	var hl := Label.new()
	hl.text = "%s  ·  ур. %d" % [str(g.get("name", "")), GuildSys.guild_level(g)]
	hl.add_theme_font_override("font", BunkerUI.font_title())
	hl.add_theme_font_size_override("font_size", 19)
	hl.add_theme_color_override("font_color", COL_PURPLE)
	hv.add_child(hl)
	var xp_bar := ProgressBar.new()
	xp_bar.max_value = GuildData.TREASURY_XP_PER
	xp_bar.value = int(g.get("xp", 0)) % GuildData.TREASURY_XP_PER
	xp_bar.show_percentage = false
	xp_bar.custom_minimum_size = Vector2(0, 8)
	hv.add_child(xp_bar)
	var kl := Label.new()
	kl.text = Loc.t("guild.treasury", {"n": int(g.get("treasury", 0))})
	kl.add_theme_font_size_override("font_size", 12)
	kl.add_theme_color_override("font_color", COL_DIM)
	hv.add_child(kl)
	_note(v, Loc.t("guild.perk", {"p": int(GuildSys.perk_hp_bonus(g) * 100)}))
	# D23: флаг войны в шапке + свежие баннеры (объявление/итог) со звуком
	var war: Dictionary = g.get("war", {})
	if not war.is_empty():
		var flag := Label.new()
		if str(war.get("state", "open")) == "open":
			flag.text = Loc.t("guild.war_flag", {"name": str(war.get("enemy", "")),
				"a": int(war.get("my_score", 0)), "b": int(war.get("enemy_score", 0))})
			flag.add_theme_color_override("font_color",
				COL_GOLD if int(war.get("my_score", 0)) >= int(war.get("enemy_score", 0)) else COL_DIM)
		else:
			flag.text = Loc.t("guild.war_flag_won") if str(war.get("state", "")) == "won" else Loc.t("guild.war_flag_lost")
			flag.add_theme_color_override("font_color", COL_GOLD if str(war.get("state", "")) == "won" else COL_DIM)
		flag.add_theme_font_override("font", BunkerUI.font_title())
		flag.add_theme_font_size_override("font_size", 13)
		v.add_child(flag)
		if bool(war.get("fresh", false)):
			war["fresh"] = false
			g["war"] = war
			_gm_save()
			_play_guild_war_sound()
			_note(v, Loc.t("guild.war_banner_new", {"name": str(war.get("enemy", "")), "n": GuildData.WAR_ATTEMPTS}))
		elif bool(war.get("result_fresh", false)):
			war["result_fresh"] = false
			g["war"] = war
			_gm_save()
			_play_guild_war_sound()
			if str(war.get("state", "")) == "won":
				_note(v, Loc.t("guild.war_banner_win", {"a": int(war.get("my_score", 0)),
					"b": int(war.get("enemy_score", 0)), "t": int(war.get("treasury_gain", 0))}))
			else:
				_note(v, Loc.t("guild.war_banner_lose", {"a": int(war.get("my_score", 0)),
					"b": int(war.get("enemy_score", 0)), "n": GuildData.WAR_LOSE_PERSONAL}))
	# Блок войны: соперник / счёт / попытки / В БОЙ
	if not war.is_empty() and str(war.get("state", "open")) == "open":
		v.add_child(_war_block(war))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	# Состав карточками: GridContainer 5 в ряд
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var icon_pool: Array = ["dog_mutant", "flesh", "snork_mutant", "pseudodog", "bloodsucker", "chimera", "zombie", "controller_mutant", "poltergeist", "pseudogiant", "leden", "vikhor", "mohovik", "guden", "tsveten", "zhivitsa", "zaveden", "shorokh"]
	var mi := 0
	for m in GuildSys.members(g):
		grid.add_child(_member_card(m, str(icon_pool[mi % icon_pool.size()]), mi == 0))
		mi += 1


func _page_boss(body: Control) -> void:
	var g: Dictionary = GuildSys.ensure(_save)
	GuildSys.ensure_week(_save, g)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	body.add_child(v)

	var boss_id: String = GuildSys.boss_id()
	var bdata: Dictionary = BossHuntData.BOSSES.get(boss_id, {})
	var pool: float = GuildSys.boss_pool(g)
	var dmg: int = int(g.get("boss_dmg", 0))
	var left: float = GuildSys.boss_hp_left(g)

	_head_line(v, Loc.t("hunt.guild_boss_name", {"name": str(bdata.get("name_ru", boss_id))}))
	# Портрет босса недели (общий хелпер D22; нет файла - заглушка-буква)
	var prow := HBoxContainer.new()
	prow.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(prow)
	prow.add_child(HuntCalendar.portrait(boss_id, 96.0))
	var bar := ProgressBar.new()
	bar.max_value = pool
	bar.value = dmg
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	v.add_child(bar)
	var pr := Label.new()
	pr.text = "Нанесено: %d / %d  ·  осталось %d" % [dmg, int(pool), int(left)]
	pr.add_theme_font_size_override("font_size", 13)
	pr.add_theme_color_override("font_color", COL_TEXT)
	v.add_child(pr)
	_note(v, Loc.t("guild.boss_note"))

	var raids_left: int = GuildSys.raids_left_today(g)
	var atk := Button.new()
	atk.custom_minimum_size = Vector2(0, 56)
	atk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if raids_left > 0:
		atk.text = Loc.t("guild.attack") + "  (" + str(raids_left) + ")"
		BunkerUI.style_button(atk, "primary", 17)
	else:
		atk.text = Loc.t("guild.attack_extra", {"n": GuildData.EXTRA_RAID_SPARKS})
		BunkerUI.style_button(atk, "hazard", 15)
	atk.pressed.connect(func():
		_play_click()
		var gm2 = get_tree().get_first_node_in_group("game_manager")
		var lab2 = gm2.get_lab_data() if gm2 else null
		var left2: int = GuildSys.raids_left_today(GuildSys.ensure(_save))
		if left2 <= 0:
				# Докупить за Искры Пробуждения
				if lab2 and lab2.spend_sparks(GuildData.EXTRA_RAID_SPARKS):
						if gm2:
								gm2.save_to_active_slot()
				else:
						_toast(Loc.t("guild.need_sparks", {"n": GuildData.EXTRA_RAID_SPARKS}))
						return
		close()
		gm_run_raid())
	v.add_child(atk)

	var help := Button.new()
	help.text = Loc.t("guild.call_help")
	help.custom_minimum_size = Vector2(0, 44)
	help.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BunkerUI.style_button(help, "hazard", 14)
	help.pressed.connect(func():
		_play_click()
		var res: String = GuildSys.call_help(_save, GuildSys.ensure(_save))
		if res != "":
			_toast(res)
		else:
			_toast(Loc.t("guild.help_done"))
		_refresh())
	v.add_child(help)


func _page_chat(body: Control) -> void:
	var g: Dictionary = GuildSys.ensure(_save)
	GuildSys.bot_daily(_save, g)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	_chat_log = VBoxContainer.new()
	_chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_log.add_theme_constant_override("separation", 3)
	scroll.add_child(_chat_log)
	for msg in g.get("chat", []):
		var row := Label.new()
		row.text = "%s: %s" % [str(msg.get("who", "")), str(msg.get("text", ""))]
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", COL_TEXT)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_chat_log.add_child(row)
	_quick_row = HBoxContainer.new()
	_quick_row.add_theme_constant_override("separation", 6)
	v.add_child(_quick_row)
	for phrase_key in ["guild.q1", "guild.q2", "guild.q3"]:
		var qb := Button.new()
		qb.text = Loc.t(phrase_key)
		qb.custom_minimum_size = Vector2(0, 40)
		qb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		qb.add_theme_font_size_override("font_size", 12)
		qb.pressed.connect(func():
			_play_click()
			var r: String = GuildSys.bot_reply(g, Loc.t(phrase_key))
			_refresh())
		_quick_row.add_child(qb)


func _page_shop(body: Control) -> void:
	var g: Dictionary = GuildSys.ensure(_save)
	# Фон витрины (пак guild_shop_art): тёмно-фиолетовый градиент + Монолит
	if ResourceLoader.exists("res://assets/ui/guild/guild_shop_bg.png"):
		var bg := TextureRect.new()
		bg.texture = load("res://assets/ui/guild/guild_shop_bg.png")
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(bg)
		body.move_child(bg, 0)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	# Баннер-шапка витрины (без текста - Label поверх не нужен, жетоны ниже)
	if ResourceLoader.exists("res://assets/ui/guild/guild_shop_banner.png"):
		var bn := TextureRect.new()
		bn.texture = load("res://assets/ui/guild/guild_shop_banner.png")
		bn.custom_minimum_size = Vector2(0, 120)
		bn.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bn.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(bn)
	var tokens := int(g.get("tokens", 0))
	# 13 карточек в панель не влезают - товары в скролл (как чат/обзор)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)
	# жетон-иконка (поставка results_pack): в ряд с числом, нет файла — текст
	var tk_row := HBoxContainer.new()
	tk_row.add_theme_constant_override("separation", 6)
	tk_row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(tk_row)
	var tk_icon_path := "res://assets/ui/currency/icon_tokens.png"
	if ResourceLoader.exists(tk_icon_path):
		var tk_icon := TextureRect.new()
		tk_icon.texture = load(tk_icon_path)
		tk_icon.custom_minimum_size = Vector2(24, 24)
		tk_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tk_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tk_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tk_row.add_child(tk_icon)
	var tk := Label.new()
	tk.text = Loc.t("guild.tokens", {"n": tokens})
	tk.add_theme_font_override("font", BunkerUI.font_title())
	tk.add_theme_font_size_override("font_size", 18)
	tk.add_theme_color_override("font_color", COL_GOLD)
	tk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tk_row.add_child(tk)
	# Оформление: карточки товаров с иконкой, ценой в жетонах, кнопкой.
	# ВНИМАНИЕ: card_icon_path ждёт ТИП без префикса ("dog_mutant" ->
	# mut_dog_mutant.png); готовое имя файла с префиксом даёт мёртвый путь
	# и пустую иконку - старые 4 позиции так и не рисовались.
	var icon_types := {
		"rolls_mut_3": ["dog_mutant", true], "rolls_mut_5": ["snork_mutant", true],
		"rolls_mut_12": ["chimera", true], "rolls_art_3": ["spark_artifact", false],
		"rolls_art_5": ["graviton_artifact", false], "rolls_art_12": ["void_artifact", false],
		"bio_50k": ["flesh", true], "bio_100k": ["zombie", true],
		"bio_500k": ["pseudogiant", true], "star_feed_1": ["clock_artifact", false],
		"star_feed_3": ["hourglass_artifact", false], "star_feed_5": ["energy_artifact", false],
		"excl_choice": ["controller_mutant", true],
	}
	for sku in GuildData.SHOP:
		var info: Dictionary = GuildData.SHOP[sku]
		var card := PanelContainer.new()
		# D-добивка: золотая 9-патч рамка вместо плоского StyleBox
		if ResourceLoader.exists("res://assets/ui/guild/guild_card_frame.png"):
			var csb := StyleBoxTexture.new()
			csb.texture = load("res://assets/ui/guild/guild_card_frame.png")
			csb.texture_margin_left = 16.0
			csb.texture_margin_right = 16.0
			csb.texture_margin_top = 16.0
			csb.texture_margin_bottom = 14.0
			csb.set_content_margin_all(10)
			card.add_theme_stylebox_override("panel", csb)
		else:
			var csb := StyleBoxFlat.new()
			csb.bg_color = Color(0.07, 0.06, 0.1, 0.95)
			csb.border_color = COL_PURPLE
			csb.set_border_width_all(1)
			csb.set_corner_radius_all(8)
			csb.set_content_margin_all(8)
			card.add_theme_stylebox_override("panel", csb)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var icon_pair: Array = icon_types.get(str(sku), ["mut_dog_mutant", true])
		var av := TextureRect.new()
		var ap: String = GachaData.card_icon_path(str(icon_pair[0]), bool(icon_pair[1]))
		if ResourceLoader.exists(ap):
				av.texture = load(ap)
		av.custom_minimum_size = Vector2(56, 56)
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(av)
		var nm := Label.new()
		nm.text = Loc.t("guild.shop_" + str(sku))
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", COL_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(nm)
		var price := Label.new()
		price.text = str(int(info.get("price", 0))) + " Ж"
		price.add_theme_font_override("font", BunkerUI.font_title())
		price.add_theme_font_size_override("font_size", 16)
		price.add_theme_color_override("font_color", COL_GOLD)
		row.add_child(price)
		var buy := Button.new()
		buy.text = Loc.t("store.buy")
		buy.custom_minimum_size = Vector2(120, 40)
		buy.disabled = int(g.get("tokens", 0)) < int(info.get("price", 0))
		buy.pressed.connect(_buy.bind(str(sku)))
		row.add_child(buy)
		list.add_child(card)
	_note(list, Loc.t("guild.shop_note"))


func _buy(sku: String) -> void:
	_play_click()
	var g: Dictionary = GuildSys.ensure(_save)
	var info: Dictionary = GuildData.SHOP.get(sku, {})
	var price: int = int(info.get("price", 0))
	if int(g.get("tokens", 0)) < price:
		_toast(Loc.t("guild.no_tokens"))
		return
	g["tokens"] = tokens_less(g, price)
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		if int(info.get("rolls_mut", 0)) > 0:
			gm.grant_mutant_rolls(int(info["rolls_mut"]), "гильдия")
		if int(info.get("rolls_art", 0)) > 0:
			gm.grant_anomaly_rolls(int(info["rolls_art"]), "гильдия")
		if float(info.get("bio", 0.0)) > 0.0 and gm.get_lab_data():
			gm.get_lab_data().biomass += float(info["bio"])
		if int(info.get("star_feed", 0)) > 0 and gm.get_lab_data():
			gm.get_lab_data().awaken_sparks += int(info["star_feed"])
		if int(info.get("excl", 0)) > 0 and gm.get_lab_data():
			# Сундук эксклюзива кладётся на СКЛАД (тот же товар, что в
			# магазине за деньги): открывается там с НАСТОЯЩИМ выбором,
			# повтор = корм на ферму
			var lab = gm.get_lab_data()
			lab.storage["excl_choice"] = int(lab.storage.get("excl_choice", 0)) + 1
	gm.save_to_active_slot()
	var sm_b = get_tree().get_first_node_in_group("sound_manager")
	if sm_b and sm_b.has_method("play_sound"):
		sm_b.play_sound("guild_buy", 0.7)
	_toast(Loc.t("guild.bought"))
	_refresh()


func tokens_less(g: Dictionary, price: int) -> int:
	g["tokens"] = int(g.get("tokens", 0)) - price
	return int(g["tokens"])


func gm_run_raid() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.change_scene("run", {"hunt": true, "guild_boss": true})


## Карточка члена гильдии: аватар (иконка мутанта), имя, сила/вклад
func _member_card(m: Dictionary, icon_type: String, is_me: bool) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.06, 0.1, 0.95)
	sb.border_color = COL_GOLD if is_me else (COL_PURPLE if bool(m["online"]) else Color(0.3, 0.28, 0.36))
	sb.set_border_width_all(2 if is_me else 1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", sb)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	var av := TextureRect.new()
	var ap: String = GachaData.card_icon_path(icon_type, true, not bool(m["online"]))
	if ResourceLoader.exists(ap):
			av.texture = load(ap)
	av.custom_minimum_size = Vector2(0, 64)
	av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	vb.add_child(av)
	var nm := Label.new()
	nm.text = str(m["name"])
	nm.add_theme_font_size_override("font_size", 11)
	nm.add_theme_color_override("font_color", COL_GOLD if is_me else COL_TEXT)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(nm)
	var pw := Label.new()
	pw.text = "сила %d" % int(m["power"])
	pw.add_theme_font_size_override("font_size", 10)
	pw.add_theme_color_override("font_color", COL_DIM)
	pw.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(pw)
	var ct := Label.new()
	ct.text = Loc.t("guild.contrib", {"n": int(m["contribution"])})
	ct.add_theme_font_size_override("font_size", 10)
	ct.add_theme_color_override("font_color", COL_DIM)
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(ct)
	return panel


func _head_line(v: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", BunkerUI.font_title())
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", COL_TEXT)
	v.add_child(l)


func _note(v: VBoxContainer, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", COL_DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)


## D23: звук войны (баннеры объявления/итога)
func _play_guild_war_sound() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("guild_war", 0.8)


## Сохранить активный слот (гашение fresh-флагов войны)
func _gm_save() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("save_to_active_slot"):
		gm.save_to_active_slot()


## D23: карточка войны в Обзоре - соперник, счёт, попытки, В БОЙ
func _war_block(war: Dictionary) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.05, 0.03, 0.95)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	panel.add_child(h)
	# Багровое знамя войны (глиф-молния)
	var banner := TextureRect.new()
	if ResourceLoader.exists("res://assets/ui/guild/guild_banner_crimson.png"):
			banner.texture = load("res://assets/ui/guild/guild_banner_crimson.png")
			banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			banner.custom_minimum_size = Vector2(64, 64)
			h.add_child(banner)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	h.add_child(v)
	var title := Label.new()
	title.text = Loc.t("guild.war_block_title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COL_GOLD)
	v.add_child(title)
	var info := Label.new()
	info.text = "%s\n%s · %s" % [str(war.get("enemy", "")),
		Loc.t("guild.war_score", {"a": int(war.get("my_score", 0)), "b": int(war.get("enemy_score", 0))}),
		Loc.t("guild.war_enemy_power", {"n": int(war.get("power", 0))})]
	info.add_theme_font_size_override("font_size", 12)
	info.add_theme_color_override("font_color", COL_TEXT)
	v.add_child(info)
	var left: int = maxi(GuildData.WAR_ATTEMPTS - int(war.get("attempts", 0)), 0)
	var att := Label.new()
	att.text = Loc.t("guild.war_attempts_left", {"n": left})
	att.add_theme_font_size_override("font_size", 12)
	att.add_theme_color_override("font_color", COL_DIM)
	v.add_child(att)
	var fight := Button.new()
	fight.text = Loc.t("guild.war_fight")
	fight.custom_minimum_size = Vector2(0, 48)
	fight.focus_mode = Control.FOCUS_NONE
	BunkerUI.style_button(fight, "hazard" if left <= 1 else "primary", 15)
	fight.pressed.connect(_on_war_fight)
	v.add_child(fight)
	return panel


## «В БОЙ»: оборона Бункера обычным выживанием с флагом войны.
## Баг-фикс: раньше ставился только флаг — забег не стартовал (и тост
## уходил в несуществующий HUD лабы). Теперь старт через лабу, как у
## обороны арены: war_defense_run + survival + _on_start_run_pressed.
func _on_war_fight() -> void:
	_play_click()
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		return
	var lab = gm.get_lab_data() if gm.has_method("get_lab_data") else null
	if lab == null or lab.arena_defense_squad.is_empty():
		_panel_note(Loc.t("guild.war_no_squad"))
		return
	gm.war_defense_run = true
	gm.arena_run_kind = ""   # война не двигает СП и счётчики арены
	gm.set_selected_run_mode("survival")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_on_start_run_pressed"):
		close()
		scene._on_start_run_pressed()
	else:
		_panel_note(Loc.t("guild.war_no_start"))


## Заметка внутри панели оверлея (в лабе HUD-группы нет — _toast молчал)
func _panel_note(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.anchor_left = 0.5
	note.anchor_right = 0.5
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = -300
	note.offset_right = 300
	note.offset_top = -84
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_override("font", BunkerUI.font_body())
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	_root.add_child(note)
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(note, "modulate:a", 0.0, 0.3)
	tw.tween_callback(note.queue_free)


func _toast(text: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_reward_note"):
		hud.show_reward_note(text)


func _play_click() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)


func _head_line_unused() -> void:
	pass
