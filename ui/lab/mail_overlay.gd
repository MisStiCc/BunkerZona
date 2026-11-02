# ui/lab/mail_overlay.gd
extends Control
class_name MailOverlay

## ПОЧТА (D25): письма с наградами (итоги сезона арены, будущие начисления).
## Письмо: от кого / заголовок / тело / [ЗАБРАТЬ] или ✓ ПОЛУЧЕНО. Забор —
## через EventOps._grant_payload-совместимый payload. Пустой ящик — весточка
## от Проводника. Rollover сезона арены выполняется при открытии.

var _root: Control
var _list: VBoxContainer
var _badge: Panel = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## Запись сезонных волн (зовёт zone_controller из забегов выживания).
## Статик: не требует инстанса оверлея.
static func note_season_wave(save, waves: int) -> void:
	if save == null or save.lab_data == null:
		return
	var best: int = int(save.lab_data.get("arena_season_waves", 0))
	if waves > best:
		save.lab_data.set("arena_season_waves", waves)


## Сезон = ISO-неделя с базой 19.10.2026. Смена сезона -> сброс сезонных
## полей + письмо с наградой за место (место = сезонные волны vs соперники).
static func _ensure_season(save) -> void:
	if save == null or save.lab_data == null:
		return
	var base: int = int(Time.get_unix_time_from_datetime_dict(
		{"year": 2026, "month": 10, "day": 19, "hour": 0, "minute": 0, "second": 0}))
	var now := int(Time.get_unix_time_from_system())
	var idx: int = int(floor(maxf(0.0, now - base) / 604800.0))
	var key := "S%d" % (7 + idx)
	if str(save.lab_data.get("arena_season_key", "")) == key:
		return
	var prev_key: String = str(save.lab_data.get("arena_season_key", ""))
	save.lab_data.set("arena_season_key", key)

	# сброс сезонных полей (заявки/медали/счётчики побед)
	save.lab_data.arena_medals_claimed = {}
	save.lab_data.arena_season_tasks_claimed = {}
	save.lab_data.arena_wins_challenge = 0
	save.lab_data.arena_wins_defense = 0

	# первый запуск (нет прошлого ключа) — без письма
	if prev_key == "":
		save.save_to_active_slot()
		return

	# письмо: место = сезонные волны против соперников прошлого сезона
	var s_waves: int = int(save.lab_data.get("arena_season_waves", 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 91000 + idx - 1
	var defs := [
		["МЕЧЕНЫЙ", 50], ["СТРЕЛОК", 44], ["ВОЛК", 38], ["ПРИЗРАК", 32],
		["ЛУЧНИК", 26], ["КЛЫК", 21], ["ДЕГТЯРЁВ", 16], ["БАРМЕН", 12],
		["ШТЫРЬ", 8], ["КРОТ", 4],
	]
	var place: int = 1
	for d in defs:
		var rival_wave: int = int(d[1]) + rng.randi_range(-2, 2) + (idx - 7) * 3
		if rival_wave >= s_waves:
			place += 1
	var reward := _place_reward(place)
	var mail: Array = save.guild_state.get("mail", []) if save.guild_state != null else []
	mail.insert(0, {
		"from": "АРЕНА «ВЫБРОС I»",
		"title_ru": "ИТОГИ СЕЗОНА: %d МЕСТО" % place,
		"title_en": "SEASON RESULT: PLACE %d" % place,
		"body_ru": "Лучшая оборона сезона: %d волн. Награда за место — в приложении." % s_waves,
		"body_en": "Best defense of the season: %d waves. The placement reward is attached." % s_waves,
		"reward": reward, "claimed": false,
	})
	save.guild_state["mail"] = mail.slice(0, 30)
	save.lab_data.set("arena_season_waves", 0)
	save.save_to_active_slot()


## Награда за место (1-3 жирные, дальше — утешительные)
static func _place_reward(place: int) -> Dictionary:
	match place:
		1: return {"rolls_mut": 20, "sparks": 10, "cos_frame": "frame_champion"}
		2: return {"rolls_mut": 12, "sparks": 6, "cos_frame": "frame_vice"}
		3: return {"rolls_mut": 8, "sparks": 4}
		_:
			if place <= 5:
				return {"rolls_mut": 5, "rolls_art": 2}
			return {"rolls_art": 1, "bio": 20000.0}


func open() -> void:
	# rollover сезона арены: смена недели -> сброс сезонных полей +
	# письмо с наградой за место (вся логика здесь, D25)
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data != null:
		_ensure_season(gm.current_save_data)
	_refresh()
	_root.visible = true


func close() -> void:
	_root.visible = false


func _build() -> void:
	_root = Control.new()
	_root.name = "MailRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.68)
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
	var w: float = clampf(vp.x * 0.6, 380.0, 620.0)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -vp.y * 0.38
	panel.offset_bottom = vp.y * 0.38
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
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
	var title := Label.new()
	title.text = Loc.t("mail.title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", BunkerUI.GREEN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x_btn := Button.new()
	x_btn.text = "✕"
	x_btn.custom_minimum_size = Vector2(40, 40)
	BunkerUI.style_button(x_btn, "steel", 15)
	x_btn.pressed.connect(close)
	head.add_child(x_btn)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)


func open_badge(badge: Panel) -> void:
	_badge = badge
	open()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var gm = get_tree().get_first_node_in_group("game_manager")
	var mail: Array = []
	if gm and gm.current_save_data != null and gm.current_save_data.guild_state != null:
		mail = gm.current_save_data.guild_state.get("mail", [])
	if mail.is_empty():
		var empty := Label.new()
		empty.text = Loc.t("mail.empty")
		empty.add_theme_font_override("font", BunkerUI.font_body())
		empty.add_theme_font_size_override("font_size", 14)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)
		return
	for i in mail.size():
		var m: Dictionary = mail[i]
		_list.add_child(_make_mail_card(i, m))


func _make_mail_card(idx: int, m: Dictionary) -> Control:
	var lang := "ru" if Loc.lang == "ru" else "en"
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.08, 0.05, 0.98)
	sb.border_color = Color(BunkerUI.GREEN, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var from := Label.new()
	from.text = "✉ %s" % str(m.get("from", "Зона"))
	from.add_theme_font_override("font", BunkerUI.font_mono())
	from.add_theme_font_size_override("font_size", 11)
	from.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
	v.add_child(from)

	var t := Label.new()
	t.text = str(m.get("title_" + lang, m.get("title_ru", "")))
	t.add_theme_font_override("font", BunkerUI.font_title())
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)

	var b := Label.new()
	b.text = str(m.get("body_" + lang, m.get("body_ru", "")))
	b.add_theme_font_override("font", BunkerUI.font_body())
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_color_override("font_color", BunkerUI.TEXT)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)

	var reward: Dictionary = m.get("reward", {})
	var claimed: bool = bool(m.get("claimed", false))
	if reward.is_empty() or claimed:
		var done := Label.new()
		done.text = Loc.t("mail.claimed") if claimed or not reward.is_empty() else ""
		done.add_theme_font_override("font", BunkerUI.font_mono())
		done.add_theme_font_size_override("font_size", 11)
		done.add_theme_color_override("font_color", BunkerUI.TEXT_FAINT)
		v.add_child(done)
	else:
		var btn := Button.new()
		btn.text = Loc.t("mail.claim")
		btn.custom_minimum_size = Vector2(0, 44)
		BunkerUI.style_button(btn, "primary", 16, true)
		btn.pressed.connect(_on_claim.bind(idx))
		v.add_child(btn)
	return card


func _on_claim(idx: int) -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null or gm.current_save_data == null or gm.current_save_data.guild_state == null:
		return
	var mail: Array = gm.current_save_data.guild_state.get("mail", [])
	if idx < 0 or idx >= mail.size():
		return
	var m: Dictionary = mail[idx]
	if bool(m.get("claimed", false)):
		return
	var reward: Dictionary = m.get("reward", {})
	# начисление тем же пейлоадом, что у событий (гача одна — правило)
	var gm2 = gm
	if int(reward.get("rolls_mut", 0)) > 0:
		gm2.grant_mutant_rolls(int(reward["rolls_mut"]), "почта")
	if int(reward.get("rolls_art", 0)) > 0:
		gm2.grant_anomaly_rolls(int(reward["rolls_art"]), "почта")
	if float(reward.get("bio", 0.0)) > 0.0 and gm2.get_lab_data():
		gm2.get_lab_data().biomass += float(reward["bio"])
	var sparks := int(reward.get("sparks", 0))
	if sparks > 0 and gm2.get_lab_data():
		gm2.get_lab_data().awaken_sparks = int(gm2.get_lab_data().awaken_sparks) + sparks
	for cos_key in ["cos_frame", "cos_avatar", "cos_title", "cos_set"]:
		if reward.has(cos_key):
			gm2.current_save_data.owned["cos_" + str(reward[cos_key])] = true
	m["claimed"] = true
	gm.save_to_active_slot()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("upgrade", 0.9)
	if _badge:
		_badge.queue_free()
		_badge = null
	_refresh()
