# ui/lab/hunt_calendar.gd
extends CanvasLayer
class_name HuntCalendar

## КАЛЕНДАРЬ ОХОТЫ (D22, спека design_inbox/hunt_calendar): неделя боссов
## Пн..Вс с портретами, статами и скиллами словами; сегодняшний день -
## зелёная рамка + плашка СЕГОДНЯ, прошедшие затемнены. Слой 9 (как кодекс),
## работает и в лабе. Данные: BossHuntData.get_week_days() + BOSSES.

const COL_GOLD := Color("ffd94d")
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)
const COL_GREEN := Color(0.55, 1.0, 0.45)

var _root: Control = null
var lab: Node = null   # lab_controller: для «В ОХОТУ» (уровень кампании, тост)

# глифы скиллов: id -> emoji
const SKILL_GLYPH := {
	"quake": "⚒", "blink": "💨", "dot_zone": "☁", "summon": "🩸",
	"stun_nearest": "💫", "vampiric": "🧛", "dash": "🏹", "shield": "🛡",
	"regen": "🌿", "backstab": "🔪", "hop_regen": "🌾", "mark": "🎯",
}


func _ready() -> void:
	layer = 9
	_build()


func open() -> void:
	if _root == null:
		_build()
	_refresh()
	_root.visible = true


func close() -> void:
	if _root:
		_root.visible = false


## Портрет босса одним контролом (календарь/гильдия/баннер); нет файла -
## заглушка с первой буквой имени (паттерн карт гачи)
static func portrait(boss_id: String, size: float) -> Control:
	var path := "res://ui/cards/bosses/%s.png" % boss_id
	if ResourceLoader.exists(path):
		var tr := TextureRect.new()
		tr.texture = load(path)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(size, size)
		return tr
	var ph := Panel.new()
	ph.custom_minimum_size = Vector2(size, size)
	var nm: String = str(BossHuntData.BOSSES.get(boss_id, {}).get("name_ru", boss_id))
	var l := Label.new()
	l.text = nm.substr(0, 1)
	l.add_theme_font_override("font", BunkerUI.font_title())
	l.add_theme_font_size_override("font_size", int(size * 0.5))
	l.add_theme_color_override("font_color", COL_DIM)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_child(l)
	return ph


func _build() -> void:
	_root = Control.new()
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
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var vp := get_viewport().get_visible_rect().size
	var w: float = clampf(vp.x * 0.6, 380.0, 560.0)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -vp.y * 0.42
	panel.offset_bottom = vp.y * 0.42
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var title := Label.new()
	title.text = Loc.t("huntcal.title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	var x := Button.new()
	x.text = "✕"
	x.custom_minimum_size = Vector2(40, 40)
	x.focus_mode = Control.FOCUS_NONE
	BunkerUI.style_button(x, "steel", 15)
	x.pressed.connect(close)
	head.add_child(x)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	var days_box := VBoxContainer.new()
	days_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	days_box.add_theme_constant_override("separation", 6)
	scroll.add_child(days_box)
	days_box.name = "Days"

	var go := Button.new()
	go.text = Loc.t("huntcal.go")
	go.custom_minimum_size = Vector2(240, 52)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.focus_mode = Control.FOCUS_NONE
	BunkerUI.style_button(go, "primary", 17)
	go.pressed.connect(_on_go_pressed)
	v.add_child(go)


func _refresh() -> void:
	var days_box: VBoxContainer = _root.find_child("Days", true, false)
	for c in days_box.get_children():
		c.queue_free()
	var today_ids: Array = BossHuntData.get_today_bosses()
	for day in BossHuntData.get_week_days():
		days_box.add_child(_make_day_row(day, today_ids))


func _make_day_row(day: Dictionary, today_ids: Array) -> Control:
	var day_v := VBoxContainer.new()
	day_v.add_theme_constant_override("separation", 4)
	# прошедшие дни недели приглушаем (строго раньше сегодняшнего)
	var dimmed: bool = _day_before_today(day)
	var head := Label.new()
	head.text = Loc.t("huntcal.day_%d" % int(day.get("weekday", 0)))
	head.add_theme_font_override("font", BunkerUI.font_title())
	head.add_theme_font_size_override("font_size", 13)
	head.add_theme_color_override("font_color", COL_GREEN if bool(day.get("today")) else COL_DIM)
	if dimmed:
		head.modulate = Color(1, 1, 1, 0.55)
	day_v.add_child(head)

	var ids: Array = day.get("ids", [])
	for id in ids:
		var row := _make_boss_row(str(id), bool(day.get("today")), dimmed)
		day_v.add_child(row)
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "—"
		empty.add_theme_font_size_override("font_size", 12)
		empty.add_theme_color_override("font_color", COL_DIM)
		day_v.add_child(empty)
	if dimmed:
		day_v.modulate = Color(1, 1, 1, 0.55)
	return day_v


## День строго раньше сегодняшнего (для затемнения прошедших)
func _day_before_today(day: Dictionary) -> bool:
	var dt := Time.get_date_dict_from_system()
	var today_idx: int = (int(dt.get("weekday", 1)) + 6) % 7
	return int(day.get("weekday", 0)) < today_idx


func _make_boss_row(boss_id: String, is_today: bool, dimmed: bool) -> Control:
	var b: Dictionary = BossHuntData.BOSSES.get(boss_id, {})
	var row := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.06, 0.95)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	if is_today:
		sb.border_color = COL_GREEN
		sb.set_border_width_all(3)
	else:
		sb.border_color = Color(0.26, 0.29, 0.21, 0.6)
		sb.set_border_width_all(1)
	row.add_theme_stylebox_override("panel", sb)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)

	h.add_child(portrait(boss_id, 96.0))

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	h.add_child(info)

	var name_row := HBoxContainer.new()
	info.add_child(name_row)
	var nm := Label.new()
	nm.text = str(b.get("name_ru", boss_id))
	nm.add_theme_font_override("font", BunkerUI.font_title())
	nm.add_theme_font_size_override("font_size", 16)
	nm.add_theme_color_override("font_color", COL_GOLD)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(nm)
	if is_today:
		var badge := Label.new()
		badge.text = Loc.t("huntcal.today")
		badge.add_theme_font_override("font", BunkerUI.font_title())
		badge.add_theme_font_size_override("font_size", 12)
		badge.add_theme_color_override("font_color", COL_GREEN)
		name_row.add_child(badge)

	var speed: float = float(b.get("speed", 2.0))
	var stats := Label.new()
	stats.text = "%s  ·  %s  ·  %s" % [
		Loc.t("huntcal.hp", {"n": int(float(b.get("hp_x", 20.0)))}),
		Loc.t("huntcal.speed_slow") if speed <= 0.01 else Loc.t("huntcal.speed_n", {"n": "%.1f" % speed}),
		Loc.t("huntcal.sparks", {"n": int(b.get("sparks", 3))}),
	]
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", COL_TEXT)
	info.add_child(stats)

	var skills: Array = b.get("skills", [])
	var parts: Array = []
	for sk in skills:
		var sid := str(sk.get("id", ""))
		var glyph: String = str(SKILL_GLYPH.get(sid, "•"))
		parts.append("%s %s" % [glyph, Loc.t("huntcal.skill_" + sid)])
	if not parts.is_empty():
		var sk_label := Label.new()
		sk_label.text = "   ".join(parts)
		sk_label.add_theme_font_size_override("font_size", 12)
		sk_label.add_theme_color_override("font_color", COL_DIM)
		sk_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(sk_label)
	if dimmed:
		row.modulate = Color(1, 1, 1, 0.55)
	return row


func _on_go_pressed() -> void:
	# Старт сегодняшней охоты - тот же поток, что кнопка ОХОТА в лабе
	close()
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		return
	if lab:
		gm.selected_campaign_level = lab._campaign_level
		lab._show_message(Loc.t("hunt.today", {"n": ", ".join(BossHuntData.today_names())}))
		await get_tree().create_timer(1.6).timeout
		if not is_instance_valid(gm):
			return
	gm.change_scene("run", {"hunt": true})


func _input(event: InputEvent) -> void:
	if _root == null or not _root.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
