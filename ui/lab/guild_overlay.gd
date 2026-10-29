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
	_head_line(v, "%s · ур. %d · казна %d" % [str(g.get("name", "")), GuildSys.guild_level(g), int(g.get("treasury", 0))])
	_note(v, Loc.t("guild.perk", {"p": int(GuildSys.perk_hp_bonus(g) * 100)}))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	for m in GuildSys.members(g):
		var row := Label.new()
		row.text = "%s%s  ·  сила %d  ·  вклад %d" % [m["name"], " · " + Loc.t("guild.online") if bool(m["online"]) else "", int(m["power"]), int(m["contribution"])]
		row.add_theme_font_size_override("font_size", 13)
		row.add_theme_color_override("font_color", COL_TEXT if bool(m["online"]) else COL_DIM)
		list.add_child(row)


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

	_head_line(v, "%s - %s" % [Loc.t("guild.boss"), str(bdata.get("name_ru", boss_id))])
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

	var atk := Button.new()
	atk.text = Loc.t("guild.attack")
	atk.custom_minimum_size = Vector2(0, 56)
	atk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BunkerUI.style_button(atk, "primary", 17)
	atk.pressed.connect(func():
		_play_click()
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
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 6)
	body.add_child(v)
	var tokens := int(g.get("tokens", 0))
	var tk := Label.new()
	tk.text = Loc.t("guild.tokens", {"n": tokens})
	tk.add_theme_font_override("font", BunkerUI.font_title())
	tk.add_theme_font_size_override("font_size", 18)
	tk.add_theme_color_override("font_color", COL_GOLD)
	tk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tk)
	for sku in GuildData.SHOP:
		var info: Dictionary = GuildData.SHOP[sku]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var nm := Label.new()
		nm.text = Loc.t("guild.shop_" + str(sku)) + "  (%d)" % int(info.get("price", 0))
		nm.add_theme_font_size_override("font_size", 14)
		nm.add_theme_color_override("font_color", COL_TEXT)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nm)
		var buy := Button.new()
		buy.text = Loc.t("store.buy")
		buy.custom_minimum_size = Vector2(120, 36)
		buy.disabled = tokens < int(info.get("price", 0))
		buy.pressed.connect(_buy.bind(str(sku)))
		row.add_child(buy)
		v.add_child(row)
	_note(v, Loc.t("guild.shop_note"))


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
	gm.save_to_active_slot()
	_toast(Loc.t("guild.bought"))
	_refresh()


func tokens_less(g: Dictionary, price: int) -> int:
	g["tokens"] = int(g.get("tokens", 0)) - price
	return int(g["tokens"])


func gm_run_raid() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.change_scene("run", {"hunt": true, "guild_boss": true})


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
