# ui/events/event_hub.gd
extends Control
class_name EventHub

## Хаб циклических событий (D24): баннер, счёт и осколки, вехи (10),
## магазин ивента, кнопка «ИГРАТЬ». Строится кодом; стиль BunkerUI.
## Игра инстансится как сцена мини-игры (game_zharva и др.).

const ART_DIR := "res://assets/ui/events/"

var _root: Control
var _title: Label
var _desc: Label
var _time: Label
var _score: Label
var _shards: Label
var _list: VBoxContainer
var _shop_list: VBoxContainer
var _play_btn: Button
var _event: Dictionary = {}
var game_manager: Node


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func open() -> void:
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	if game_manager and game_manager.current_save_data:
		EventManager.state(game_manager.current_save_data)
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.name = "HubRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.66)
	shade.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_root.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var vp := get_viewport().get_visible_rect().size
	var w: float = clampf(vp.x * 0.6, 380.0, 660.0)
	if vp.x < 900.0:
		w = vp.x * 0.94
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -vp.y * 0.4
	panel.offset_bottom = vp.y * 0.4
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.HAZARD
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

	var head := HBoxContainer.new()
	v.add_child(head)
	_title = Label.new()
	_title.add_theme_font_override("font", BunkerUI.font_title())
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(40, 40)
	BunkerUI.style_button(x_btn, "steel", 15)
	x_btn.pressed.connect(close)
	head.add_child(x_btn)

	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_override("font", BunkerUI.font_body())
	_desc.add_theme_font_size_override("font_size", 13)
	_desc.add_theme_color_override("font_color", BunkerUI.TEXT)
	v.add_child(_desc)

	_time = Label.new()
	_time.add_theme_font_override("font", BunkerUI.font_mono())
	_time.add_theme_font_size_override("font_size", 13)
	_time.add_theme_color_override("font_color", BunkerUI.HAZARD)
	v.add_child(_time)

	_score = Label.new()
	_score.add_theme_font_override("font", BunkerUI.font_mono())
	_score.add_theme_font_size_override("font_size", 14)
	_score.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
	v.add_child(_score)

	_shards = Label.new()
	_shards.add_theme_font_override("font", BunkerUI.font_mono())
	_shards.add_theme_font_size_override("font_size", 14)
	_shards.add_theme_color_override("font_color", Color(0.55, 0.85, 0.95))
	v.add_child(_shards)

	_play_btn = Button.new()
	_play_btn.text = Loc.t("evt.play")
	_play_btn.custom_minimum_size = Vector2(0, 56)
	BunkerUI.style_button(_play_btn, "primary", 20, true)
	_play_btn.pressed.connect(_on_play)
	v.add_child(_play_btn)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	var mile_tab := Button.new()
	mile_tab.text = Loc.t("evt.milestones")
	mile_tab.toggle_mode = true
	mile_tab.button_pressed = true
	mile_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BunkerUI.style_button(mile_tab, "steel", 12)
	tabs.add_child(mile_tab)
	var shop_tab := Button.new()
	shop_tab.text = Loc.t("evt.shop")
	shop_tab.toggle_mode = true
	shop_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BunkerUI.style_button(shop_tab, "steel", 12)
	tabs.add_child(shop_tab)

	var pages := Control.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(pages)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	pages.add_child(_list)

	_shop_list = VBoxContainer.new()
	_shop_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shop_list.add_theme_constant_override("separation", 4)
	_shop_list.visible = false
	pages.add_child(_shop_list)

	var toggle := func(on: Button, page: Control):
		for p in [_list, _shop_list]:
			p.visible = p == page
		for b in [mile_tab, shop_tab]:
			b.set_pressed_no_signal(b == on)
	mile_tab.pressed.connect(func(): toggle.call(mile_tab, _list))
	shop_tab.pressed.connect(func(): toggle.call(shop_tab, _shop_list))


func _refresh() -> void:
	var lang := "ru" if Loc.lang == "ru" else "en"
	_title.text = Loc.t("evt.banner") % str(_event["title_" + lang])
	_desc.text = str(_event["desc_" + lang])
	_time.text = Loc.t("evt.time_left") % int(_event["days_left"])
	var es := EventManager.state(game_manager.current_save_data) \
		if game_manager and game_manager.current_save_data else {}
	_score.text = Loc.t("evt.score_line") % [int(es.get("score", 0)), int(es.get("best", 0))]
	_shards.text = Loc.t("evt.shards_line") % int(es.get("shards", 0))
	_play_btn.visible = str(_event["id"]) != "finale"
	_fill_finale_games(es)
	_fill_milestones(es)
	_fill_shop()


## Финал полугодия: все шесть игр открыты одновременно
func _fill_finale_games(_es: Dictionary) -> void:
	for c in _list.get_children():
		pass   # вехи ниже; игры добавим отдельным блоком сверху
	var games := [["zharva", "evt.g_zharva"], ["uley", "evt.g_uley"],
		["labyrinth", "evt.g_labyrinth"], ["chain", "evt.g_chain"],
		["vault", "evt.g_vault"], ["bolts", "evt.g_bolts"]]
	var built := ["zharva", "uley", "labyrinth", "chain", "vault", "bolts"]
	for g in games:
		var b := Button.new()
		b.text = Loc.t(str(g[1])) + ("  ▶" if g[0] in built else "  ·  " + Loc.t("evt.soon"))
		b.custom_minimum_size = Vector2(0, 44)
		b.add_theme_font_size_override("font_size", 14)
		BunkerUI.style_button(b, "steel", 13)
		b.disabled = not (g[0] in built)
		if g[0] in built:
			b.pressed.connect(_on_finale_play.bind(g[0]))
		_list.add_child(b)


func _on_finale_play(base: String) -> void:
	_play_click()
	close()
	var script_map := {
		"zharva": preload("res://ui/events/game_zharva.gd"),
		"uley": preload("res://ui/events/game_uley.gd"),
		"labyrinth": preload("res://ui/events/game_labyrinth.gd"),
		"chain": preload("res://ui/events/game_chain.gd"),
		"vault": preload("res://ui/events/game_vault.gd"),
		"bolts": preload("res://ui/events/game_bolts.gd"),
	}
	var game: Control = script_map[base].new()
	get_tree().current_scene.add_child(game)


func _play_click() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)


func _fill_milestones(es: Dictionary) -> void:
	for c in _list.get_children():
		c.queue_free()
	var mult: float = float(_event["mult"]) \
		if str(es.get("event_id", "")) == str(_event["id"]) else 1.0
	for i in EventsData.MILESTONE_SCORES.size():
		var goal := int(float(EventsData.MILESTONE_SCORES[i]) / mult)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_list.add_child(row)
		var lbl := Label.new()
		lbl.add_theme_font_override("font", BunkerUI.font_body())
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.clip_text = true
		row.add_child(lbl)
		var claimed: bool = int(es.get("claimed", []).find(i)) != -1
		var ready: bool = EventManager.milestone_ready(es, i)
		var score_now := int(es.get("score", 0)) if str(es.get("event_id", "")) == str(_event["id"]) else 0
		if claimed:
				lbl.text = "✓  %d — %s" % [goal, _milestone_text(i)]
				lbl.add_theme_color_override("font_color", BunkerUI.TEXT_FAINT)
		elif ready:
				lbl.text = "✦  %d — %s" % [goal, _milestone_text(i)]
				lbl.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
				var claim := Button.new()
				claim.text = Loc.t("evt.claim")
				claim.custom_minimum_size = Vector2(120, 32)
				BunkerUI.style_button(claim, "hazard", 12)
				claim.pressed.connect(_on_claim.bind(i))
				row.add_child(claim)
		else:
				lbl.text = "%d — %s   (%d/%d)" % [goal, _milestone_text(i),
						score_now, goal]
				lbl.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)


func _milestone_text(idx: int) -> String:
	var prem: Dictionary = EventsData.MILESTONE_REWARDS[idx]
	var parts: Array[String] = []
	if int(prem.get("rolls_mut", 0)) > 0:
		parts.append(Loc.t("evt.r_mut") % int(prem["rolls_mut"]))
	if int(prem.get("rolls_art", 0)) > 0:
		parts.append(Loc.t("evt.r_art") % int(prem["rolls_art"]))
	if float(prem.get("bio", 0.0)) > 0.0:
		parts.append(Loc.t("evt.r_bio") % int(float(prem["bio"]) / 1000.0))
	if int(prem.get("sparks", 0)) > 0:
		parts.append(Loc.t("evt.r_sparks") % int(prem["sparks"]))
	if prem.has("cos_frame"):
		parts.append(Loc.t("evt.r_frame"))
	if prem.has("cos_title"):
		parts.append(Loc.t("evt.r_title"))
	return " + ".join(parts)


func _fill_shop() -> void:
	for c in _shop_list.get_children():
		c.queue_free()
	var es := EventManager.state(game_manager.current_save_data) \
		if game_manager and game_manager.current_save_data else {}
	for shop_id in EventsData.SHOP:
		var item: Dictionary = EventsData.SHOP[shop_id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_shop_list.add_child(row)
		var name_key := "name_ru" if Loc.lang == "ru" else "name_en"
		var lbl := Label.new()
		lbl.text = "%s — ◆%d" % [str(item[name_key]), int(item["shards"])]
		lbl.add_theme_font_override("font", BunkerUI.font_body())
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.add_theme_color_override("font_color", BunkerUI.TEXT)
		row.add_child(lbl)
		var bought: bool = es.get("bought", {}).has(shop_id)
		var is_cos := item.has("cos_frame")
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(140, 32)
		btn.add_theme_font_size_override("font_size", 12)
		BunkerUI.style_button(btn, "steel", 12)
		if bought and is_cos:
				btn.text = Loc.t("evt.owned")
				btn.disabled = true
		else:
				btn.text = Loc.t("evt.buy")
				btn.pressed.connect(_on_buy.bind(shop_id))
		row.add_child(btn)


func _on_claim(idx: int) -> void:
	if game_manager == null or game_manager.current_save_data == null:
		return
	var prem := EventManager.claim_milestone(game_manager.current_save_data, idx)
	if not prem.is_empty():
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_sound"):
			sm.play_sound("upgrade", 0.9, 1.0)
	_refresh()


func _on_buy(shop_id: String) -> void:
	if game_manager == null or game_manager.current_save_data == null:
		return
	var payload := EventManager.shop_buy(game_manager.current_save_data, shop_id)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("exchange" if not payload.is_empty() else "ui_hover", 0.7)
	_refresh()


func _on_play() -> void:
	close()
	# роутинг по базовому ивенту; не встроенные — «скоро»
	var game_script: GDScript = null
	match str(_event["base"]):
		"zharva":
			game_script = preload("res://ui/events/game_zharva.gd")
		"uley":
			game_script = preload("res://ui/events/game_uley.gd")
		"labyrinth":
			game_script = preload("res://ui/events/game_labyrinth.gd")
		"chain":
			game_script = preload("res://ui/events/game_chain.gd")
		"vault":
			game_script = preload("res://ui/events/game_vault.gd")
		"bolts":
			game_script = preload("res://ui/events/game_bolts.gd")
	if game_script != null:
		var game: Control = game_script.new()
		get_tree().current_scene.add_child(game)
	else:
		_root.visible = true
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_sound"):
			sm.play_sound("ui_hover", 0.5)
		_show_message(Loc.t("evt.soon"))


func _show_message(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.anchor_left = 0.5
	note.anchor_right = 0.5
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = -200
	note.offset_right = 200
	note.offset_top = -60
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", BunkerUI.font_body())
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	_root.add_child(note)
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(note, "modulate:a", 0.0, 0.4)
	tw.tween_callback(note.queue_free)
