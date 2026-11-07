# ui/lab/onboarding_overlay.gd
extends CanvasLayer
class_name OnboardingOverlay

## D26 ОНБОРДИНГ НОВИЧКА (компакт): один раз при первом запуске Голос Зоны
## объясняет цикл (забег -> аномалии/мутанты до старта -> выброс), пульс
## подсвечивает большую зелёную кнопку забега. Флаг onboarding_done в сейве.
## ESC/клик - закрыть, обучалка больше не покажется.

const LINES_RU := [
	"Оператор. Лаборатория твой бункер. Отсюда ведёшь Зону.",
	"Жми НАЧАТЬ НОВЫЙ ЗАБЕГ. До старта ставь аномалии и мутантов - они встретят сталкеров.",
	"Энергия - аномалии. Биомасса - мутанты. Выброс - козырь, когда сталкеры дожали. Погнали.",
]
const LINES_EN := [
	"Operator. The lab is your bunker. You lead the Zone from here.",
	"Press START NEW RUN. Before it starts, place anomalies and mutants - they will greet the stalkers.",
	"Energy buys anomalies. Biomass buys mutants. The Blowout is your trump card. Go.",
]

var _root: Control = null
var _step: int = 0
var _text: Label = null
var _pulse: Control = null


func _ready() -> void:
	layer = 30
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_advance())
	_root.add_child(dim)

	var vp := get_viewport().get_visible_rect().size
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 1.0
	panel.anchor_right = 0.5
	panel.anchor_bottom = 1.0
	panel.offset_left = -minf(vp.x * 0.46, 430.0)
	panel.offset_right = minf(vp.x * 0.46, 430.0)
	panel.offset_top = -300.0
	panel.offset_bottom = -120.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.97)
	sb.border_color = BunkerUI.GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var who := Label.new()
	who.text = Loc.t("onb.who")
	who.add_theme_font_override("font", BunkerUI.font_title())
	who.add_theme_font_size_override("font_size", 15)
	who.add_theme_color_override("font_color", BunkerUI.GREEN)
	v.add_child(who)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 14)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_text)

	var next := Button.new()
	next.text = Loc.t("onb.next")
	next.custom_minimum_size = Vector2(0, 42)
	BunkerUI.style_button(next, "primary", 15)
	next.pressed.connect(_advance)
	v.add_child(next)
	_set_line(0)


func _set_line(i: int) -> void:
	_step = i
	var lines: Array = LINES_RU if Loc.lang == "ru" else LINES_EN
	_text.text = str(lines[mini(i, lines.size() - 1)])


func _advance() -> void:
	_play_click()
	var lines: Array = LINES_RU if Loc.lang == "ru" else LINES_EN
	if _step + 1 < lines.size():
		_set_line(_step + 1)
		if _step == 1:
			_pulse_start_button()
		return
	_finish()


## Пульс на большой зелёной кнопке забега (подсказка "сюда")
func _pulse_start_button() -> void:
	if _pulse != null:
		return
	var lab := get_tree().get_first_node_in_group("lab")
	if lab == null:
		return
	var target: Control = null
	for b in lab.find_children("*", "Button", true, false):
		if b is Button and b.text.contains(Loc.t("lab.start_run")) and b.visible:
			target = b
			break
	if target == null:
		return
	_pulse = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0)
	sb.border_color = Color(0.55, 1.0, 0.45, 0.9)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	_pulse.add_theme_stylebox_override("panel", sb)
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_parent().add_child(_pulse)
	var r := target.get_global_rect()
	var my := get_parent() as Control
	if my == null:
		return
	var local := (my.get_global_transform().affine_inverse() as Transform2D) * r.position
	_pulse.position = local - Vector2(8, 8)
	_pulse.size = r.size + Vector2(16, 16)
	var tw := create_tween().set_loops(4)
	tw.tween_property(_pulse, "modulate:a", 0.25, 0.5)
	tw.tween_property(_pulse, "modulate:a", 1.0, 0.5)
	tw.tween_callback(func():
		if _pulse != null and is_instance_valid(_pulse):
			_pulse.queue_free()
			_pulse = null)


func _finish() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data != null:
		gm.current_save_data.onboarding_done = true
		gm.save_to_active_slot()
	queue_free()


func _play_click() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)
