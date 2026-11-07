# ui/lab/mail_overlay.gd
extends Control
class_name MailOverlay

## ПОЧТА (D25): письма с наградами (итоги сезона арены, будущие начисления).
## Письмо: от кого / заголовок / тело / [ЗАБРАТЬ] или ✓ ПОЛУЧЕНО. Забор —
## через EventOps._grant_payload-совместимый payload. Пустой ящик — весточка
## от Проводника. Rollover сезона арены — В АРХИВАХ ArenaSeason (канон),
## оверлей только дёргает его при открытии и рисует ящик.

var _root: Control
var _list: VBoxContainer
var _badge: Panel = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


## Запись сезонных волн (зовёт zone_controller из забегов выживания).
## Делегирует канону в core — сам UI ничего не считает.
static func note_season_wave(save, waves: int) -> void:
	ArenaSeason.note_season_wave(save, waves)


func open() -> void:
	# rollover сезона арены: единая точка в ArenaSeason.ensure_season
	# (ключ сезона "S<N>" один на весь проект — вторых схем быть не должно);
	# сейв — здесь, у канона методов сохранения нет (паттерн GuildSys)
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data != null:
		if not ArenaSeason.ensure_season(gm.current_save_data).is_empty():
			gm.save_to_active_slot()
	_refresh()
	visible = true   # сам оверлей тоже (раньше: _root видим, окно - нет)
	_root.visible = true


func close() -> void:
	_root.visible = false
	visible = false   # и сам оверлей


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

	# Баннер ящика (поставка mail_pack): под шапкой; файла нет — без него
	if ResourceLoader.exists("res://assets/ui/mail/mail_banner.png"):
		var m_banner := TextureRect.new()
		m_banner.texture = load("res://assets/ui/mail/mail_banner.png")
		m_banner.custom_minimum_size = Vector2(0, 72)
		m_banner.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		m_banner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		m_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(m_banner)

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
		# снимаем СРАЗУ: голый queue_free отложен — при повторном открытии
		# карточки наслаивались (урок hunt_calendar, сообщение подготовщика)
		_list.remove_child(c)
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

	# строка «от кого»: конверт-иконка (поставка mail_pack), нет файла — глиф
	var from_row := HBoxContainer.new()
	from_row.add_theme_constant_override("separation", 5)
	v.add_child(from_row)
	var env_path := "res://assets/ui/mail/mail_envelope.png"
	if ResourceLoader.exists(env_path):
		var env := TextureRect.new()
		env.texture = load(env_path)
		env.custom_minimum_size = Vector2(16, 16)
		env.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		env.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		env.mouse_filter = Control.MOUSE_FILTER_IGNORE
		from_row.add_child(env)
		var from := Label.new()
		from.text = str(m.get("from", "Зона"))
		_style_from_label(from)
		from_row.add_child(from)
	else:
		var from := Label.new()
		from.text = "✉ %s" % str(m.get("from", "Зона"))
		_style_from_label(from)
		from_row.add_child(from)

	# заголовок + красный бейдж «!» у непрочитанного с вложением
	var t_row := HBoxContainer.new()
	t_row.add_theme_constant_override("separation", 6)
	v.add_child(t_row)
	var reward0: Dictionary = m.get("reward", {})
	var unread: bool = not reward0.is_empty() and not bool(m.get("claimed", false))
	if unread and ResourceLoader.exists("res://assets/ui/mail/mail_unread_badge.png"):
		var badge := TextureRect.new()
		badge.texture = load("res://assets/ui/mail/mail_unread_badge.png")
		badge.custom_minimum_size = Vector2(18, 18)
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t_row.add_child(badge)
	var t := Label.new()
	t.text = str(m.get("title_" + lang, m.get("title_ru", "")))
	t.add_theme_font_override("font", BunkerUI.font_title())
	t.add_theme_font_size_override("font_size", 15)
	t.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_row.add_child(t)

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
		# ряд иконок вложений по ключам награды (поставка mail_pack);
		# файла иконки нет — слот не рисуется
		var attach := HBoxContainer.new()
		attach.add_theme_constant_override("separation", 10)
		var attach_map := {
			"rolls_mut": ["attach_rolls_mut", "%d" % int(reward.get("rolls_mut", 0))],
			"rolls_art": ["attach_rolls_art", "%d" % int(reward.get("rolls_art", 0))],
			"sparks": ["attach_sparks", "%d" % int(reward.get("sparks", 0))],
			"bio": ["attach_bio", "%dк" % int(float(reward.get("bio", 0.0)) / 1000.0)],
		}
		for akey in attach_map:
			if not reward.has(akey):
				continue
			var ap := "res://assets/ui/mail/%s.png" % str(attach_map[akey][0])
			if not ResourceLoader.exists(ap):
				continue
			var slot := HBoxContainer.new()
			slot.add_theme_constant_override("separation", 3)
			var ic := TextureRect.new()
			ic.texture = load(ap)
			ic.custom_minimum_size = Vector2(26, 26)
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ic)
			var amt := Label.new()
			amt.text = str(attach_map[akey][1])
			amt.add_theme_font_override("font", BunkerUI.font_mono())
			amt.add_theme_font_size_override("font_size", 11)
			amt.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
			slot.add_child(amt)
			attach.add_child(slot)
		for cos_key in ["cos_frame", "cos_avatar", "cos_title", "cos_set"]:
			if reward.has(cos_key) and ResourceLoader.exists("res://assets/ui/mail/attach_cosmetic.png"):
				var ci := TextureRect.new()
				ci.texture = load("res://assets/ui/mail/attach_cosmetic.png")
				ci.custom_minimum_size = Vector2(26, 26)
				ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				ci.mouse_filter = Control.MOUSE_FILTER_IGNORE
				attach.add_child(ci)
				break
		if attach.get_child_count() > 0:
			v.add_child(attach)
		var btn := Button.new()
		btn.text = Loc.t("mail.claim")
		btn.custom_minimum_size = Vector2(0, 44)
		BunkerUI.style_button(btn, "primary", 16, true)
		btn.pressed.connect(_on_claim.bind(idx))
		v.add_child(btn)
	return card


## Общий стиль строки «от кого» (иконка и глиф-фолбэк выглядят одинаково)
func _style_from_label(l: Label) -> void:
	l.add_theme_font_override("font", BunkerUI.font_mono())
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)


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
