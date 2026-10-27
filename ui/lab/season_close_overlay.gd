# ui/lab/season_close_overlay.gd
extends CanvasLayer
class_name SeasonCloseOverlay

## Церемония закрытия сезона (D13): титр-слэм -> сводка построчно -> награда
## -> ПРОДОЛЖИТЬ. Слой 10 - поверх всех панелей лаборатории. Скип по клику.
## Награду крутками начисляет лаборатория ДО вызова play (числа приходят сюда).

signal closed

const COL_GOLD := Color("ffd94d")
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)
const COL_GREEN := Color("a8ff7a")

var _root: Control = null
var _rows_box: VBoxContainer = null
var _reward_label: Label = null
var _btn: Button = null
var _revealed: bool = false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func play(summary: Dictionary, reward_mut: int, reward_ano: int, great: bool) -> void:
	var next_cycle: int = maxi(int(summary.get("cycle", 1)), 1) + 1
	var title: Label = _root.get_node("Panel/V/Title")
	title.text = Loc.t("season_close.title", {"n": int(summary.get("cycle", 1))})
	title.scale = Vector2(1.6, 1.6)
	title.pivot_offset = title.size / 2.0
	var tw := create_tween()
	tw.tween_property(title, "scale", Vector2.ONE, SeasonCloseData.TITLE_SLAM) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("upgrade", 0.7)

	var rows: Array = [
		Loc.t("season_close.row_sp", {"n": int(summary.get("sp", 0))}),
		Loc.t("season_close.row_arena",
			{"ch": int(summary.get("arena_ch", 0)), "def": int(summary.get("arena_def", 0))}),
		Loc.t("season_close.row_blow", {"n": int(summary.get("blowouts", 0))}),
		Loc.t("season_close.row_exchange", {"n": int(summary.get("exchange", 0))}),
		Loc.t("season_close.row_tasks", {"n": int(summary.get("tasks", 0))}),
	]
	for i in range(rows.size()):
		var row := _make_label(str(rows[i]), 19, COL_TEXT)
		row.modulate.a = 0.0
		_rows_box.add_child(row)
		var rt := create_tween()
		rt.tween_interval(SeasonCloseData.TITLE_SLAM + SeasonCloseData.ROW_STEP * float(i))
		rt.tween_property(row, "modulate:a", 1.0, 0.22)

	_reward_label.text = Loc.t("season_close.reward",
		{"m": reward_mut, "a": reward_ano}) + ("  ·  " + Loc.t("season_close.great") if great else "")
	if great:
		_reward_label.add_theme_color_override("font_color", COL_GOLD)
	var rt2 := create_tween()
	rt2.tween_interval(SeasonCloseData.TITLE_SLAM + SeasonCloseData.ROW_STEP * float(rows.size()) + 0.2)
	rt2.tween_callback(func():
		_reward_label.visible = true
		if sm and sm.has_method("play_sound"):
			sm.play_sound("reveal_legendary", 0.6))
	var bt := create_tween()
	bt.tween_interval(SeasonCloseData.TITLE_SLAM + SeasonCloseData.ROW_STEP * float(rows.size()) + 0.6)
	bt.tween_callback(_reveal_button)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and not _revealed:
			_reveal_all())
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and not _revealed:
			_reveal_all())
	_root.add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -360.0
	panel.offset_top = -270.0
	panel.offset_right = 360.0
	panel.offset_bottom = 270.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 24
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.name = "V"
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 24
	v.offset_right = -24
	v.offset_top = 18
	v.offset_bottom = -18
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)

	var title := Label.new()
	title.name = "Title"
	title.text = ""
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(0, 2)
	line.color = Color(COL_GOLD, 0.5)
	v.add_child(line)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override("separation", 6)
	_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_rows_box)

	_reward_label = _make_label("", 22, COL_GREEN, true)
	_reward_label.visible = false
	v.add_child(_reward_label)

	var next_l := _make_label(Loc.t("season_close.next"), 15, COL_DIM)
	v.add_child(next_l)

	_btn = Button.new()
	_btn.text = Loc.t("season_close.continue")
	_btn.custom_minimum_size = Vector2(280, 56)
	_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BunkerUI.style_button(_btn, "primary", 17)
	_btn.pressed.connect(func():
		closed.emit()
		queue_free())
	v.add_child(_btn)
	_btn.visible = false


func _make_label(text: String, fs: int, col: Color, title_font := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", BunkerUI.font_title() if title_font else BunkerUI.font_body())
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Скип: показать всё сразу и кнопку
func _reveal_all() -> void:
	if _revealed:
		return
	_revealed = true
	for c in _rows_box.get_children():
		c.modulate.a = 1.0
	_reward_label.visible = true
	_reveal_button()


func _reveal_button() -> void:
	if _revealed and _btn.visible:
		return
	_btn.visible = true
	_btn.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_btn, "modulate:a", 1.0, 0.25)
