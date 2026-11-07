# ui/lab/onboarding_overlay.gd
extends CanvasLayer
class_name OnboardingOverlay

## D26 ОНБОРДИНГ НОВИЧКА (полная версия по спеке архитектора, адаптирована
## к реальному флоу: пачка набирается в ПОДГОТОВКЕ забега, не в лабе).
## 6 шагов; состояние в сейве (onboarding_step) - перезапуск продолжает;
## ✕/esc пропускает всё; каждый хост (лаба/забег) спавнит гайд, если жив.

const COL_GOLD := Color("ffd94d")
const COL_GREEN := Color(0.55, 1.0, 0.45)

## Шаги: id; host (лаба/забег); ключ текста; целевые узлы для рамки
## (в лабе ищутся по тексту кнопки, в забеге - имена панелей HUD)
const STEPS := [
	{"id": "welcome", "host": "lab", "text": "ob.welcome", "targets": ["@start_run"]},
	{"id": "anomaly", "host": "run", "text": "ob.anomaly", "targets": ["AnomalyPanel"]},
	{"id": "mutant", "host": "run", "text": "ob.mutant", "targets": ["MutantPanel"]},
	{"id": "start", "host": "run", "text": "ob.start", "targets": ["StartPanel"]},
	{"id": "survive", "host": "run", "text": "ob.survive", "targets": []},
	{"id": "finish", "host": "lab", "text": "ob.finish", "targets": []},
]

var _root: Control = null
var host_kind: String = "lab"   # "lab" | "run" - ставит хост до add_child
var _step_id: String = ""
var _plaque: PanelContainer = null
var _text: Label = null
var _frame: Array[Control] = []
var _pulse_tween: Tween = null


func _ready() -> void:
	layer = 30
	add_to_group("onboarding")
	_build()
	var id := _current_step_id()
	var idx := _step_index(id)
	if str(STEPS[idx]["host"]) != host_kind:
		# сохранённый шаг чужого хоста: в лабе показываем welcome визуально
		# (не сохраняя), в забеге - молча выходим
		if host_kind == "run":
			queue_free()
			return
		_enter_step(str(STEPS[0]["id"]), false)
	else:
		_enter_step(id)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_plaque = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.97)
	sb.border_color = BunkerUI.GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(10)
	_plaque.add_theme_stylebox_override("panel", sb)
	_plaque.custom_minimum_size = Vector2(360, 0)
	_plaque.anchor_left = 0.5
	_plaque.anchor_right = 0.5
	_plaque.anchor_top = 0.0
	_plaque.anchor_bottom = 0.0
	_plaque.offset_left = -210.0
	_plaque.offset_right = 210.0
	_plaque.offset_top = 14.0
	_plaque.offset_bottom = 118.0
	_plaque.mouse_filter = Control.MOUSE_FILTER_STOP
	_plaque.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_complete_current())
	_root.add_child(_plaque)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_plaque.add_child(v)
	var who := Label.new()
	who.text = Loc.t("onb.who")
	who.add_theme_font_override("font", BunkerUI.font_title())
	who.add_theme_font_size_override("font_size", 13)
	who.add_theme_color_override("font_color", BunkerUI.GREEN)
	v.add_child(who)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 13)
	_text.custom_minimum_size = Vector2(0, 48)
	v.add_child(_text)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)
	var next := Button.new()
	next.text = Loc.t("onb.next")
	next.custom_minimum_size = Vector2(0, 36)
	next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	BunkerUI.style_button(next, "primary", 13)
	next.pressed.connect(_complete_current)
	h.add_child(next)
	var skip := Button.new()
	skip.text = Loc.t("onb.skip")
	skip.custom_minimum_size = Vector2(0, 36)
	BunkerUI.style_button(skip, "steel", 13)
	skip.pressed.connect(_skip_all)
	h.add_child(skip)


## Текущий шаг из сейва; пусто = самый первый
func _current_step_id() -> String:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data != null:
		var saved := str(gm.current_save_data.onboarding_step)
		if not saved.is_empty():
			return saved
	return str(STEPS[0]["id"])


func _step_index(id: String) -> int:
	for i in range(STEPS.size()):
		if str(STEPS[i]["id"]) == id:
			return i
	return 0


## Войти в шаг: текст + рамка вокруг целевых узлов
func _enter_step(id: String, persist: bool = true) -> void:
	_step_id = id
	if persist:
		_save_step(id)
	var idx := _step_index(id)
	_text.text = Loc.t(str(STEPS[idx]["text"]))
	_clear_frame()
	var target_host: Node = get_tree().get_first_node_in_group("hud")
	if str(STEPS[idx]["host"]) == "lab":
		target_host = get_tree().get_first_node_in_group("lab")
	var targets: Array = STEPS[idx]["targets"]
	if targets.is_empty():
		return
	for tkey in targets:
		var node: Control = _resolve_target(str(tkey), target_host)
		if node != null:
			_frame_node(node)
	if not targets.is_empty() and _frame.is_empty() and str(STEPS[idx]["host"]) == host_kind:
		# цель не найдена в СВОЁМ хосте (узел скрыт) - шаг завершается сам;
		# чужой хост каскад не запускает (флаг добавлен, урок каскада)
		call_deferred("_complete_current")


## Целевой узел: "@start_run" = кнопка забега по тексту; иначе - узел HUD/лабы
func _resolve_target(tkey: String, host: Node) -> Control:
	if tkey == "@start_run":
		if host == null:
			return null
		for b in host.find_children("*", "Button", true, false):
			if b is Button and b.text.contains(Loc.t("lab.start_run")) and b.visible:
				return b
		return null
	if host == null:
		return null
	var n := host.get_node_or_null(tkey)
	if n is Control:
		return n
	return null


## Рамка из 4 полос вокруг цели + пульс альфы (по спеке: не навязчиво)
func _frame_node(node: Control) -> void:
	node.ready.connect(_reframe.bind(node), CONNECT_ONE_SHOT) if not node.is_node_ready() else null
	_reframe(node)


func _reframe(node: Control) -> void:
	if _root == null or not is_instance_valid(node):
		return
	var r := node.get_global_rect()
	_clear_frame()
	var specs := [
		[Vector2(r.position.x - 6, r.position.y - 6), Vector2(r.size.x + 12, 4)],
		[Vector2(r.position.x - 6, r.end.y + 2), Vector2(r.size.x + 12, 4)],
		[Vector2(r.position.x - 6, r.position.y - 6), Vector2(4, r.size.y + 12)],
		[Vector2(r.end.x + 2, r.position.y - 6), Vector2(4, r.size.y + 12)],
	]
	for spec in specs:
		var bar := ColorRect.new()
		bar.color = COL_GREEN
		bar.position = spec[0]
		bar.size = spec[1]
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(bar)
		_frame.append(bar)
	_pulse_tween = create_tween().set_loops(3)
	_pulse_tween.tween_property(_root, "modulate:a", 0.55, 0.6)
	_pulse_tween.tween_property(_root, "modulate:a", 1.0, 0.6)


func _clear_frame() -> void:
	for bar in _frame:
		if is_instance_valid(bar):
			bar.queue_free()
	_frame.clear()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	_root.modulate.a = 1.0


## Завершить текущий шаг: следующий в списке, либо финиш онбординга
func _complete_current() -> void:
	var idx := _step_index(_step_id)
	if idx + 1 >= STEPS.size():
		_skip_all()
		return
	_enter_step(str(STEPS[idx + 1]["id"]))


func _skip_all() -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data != null:
		gm.current_save_data.onboarding_done = true
		gm.current_save_data.onboarding_step = ""
		gm.save_to_active_slot()
	queue_free()


func _save_step(id: String) -> void:
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data != null:
		gm.current_save_data.onboarding_step = id


## Внешнее завершение шага (зона/лаба зовут по событиям игры)
func complete_step(id: String) -> void:
	if _step_id != id:
		return
	_complete_current()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_skip_all()
		get_viewport().set_input_as_handled()
