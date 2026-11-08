# ui/events/game_bolts.gd
extends Control
class_name GameBolts

## «БОЛТЫ ГРАВИТОНА» (D24): физика-слэнгшот. Тяни рогатку, отпускай —
## болт летит по параболе; гравитационные карманы искривляют полёт
## (воронка — тянет внутрь, лифт — подкидывает, время — замедляет).
## Порази все мишени за отведённые болты. 30 уровней, счёт: уровень ×150
## + экономия бросков ×50 (+100 «золотой болт» за дугу через 2+ кармана);
## осколки = счёт / 200.

const LEVELS: int = 30
const G: float = 600.0
const LAUNCH_K: float = 3.2
const MAX_SPEED: float = 1300.0
const BOLT_R: float = 10.0
const TARGET_R: float = 26.0

var _level: int = 1
var _score: int = 0
var _over: bool = false
var _board: Control
var _player: Control          # рогатка/сталкер
var _launcher: Vector2
var _aiming: bool = false
var _aim_start: Vector2 = Vector2.ZERO
var _aim_cur: Vector2 = Vector2.ZERO
var _aim_line: Control = null
var _targets: Array = []      # [{node, base, phase, drift}]
var _zones: Array = []        # [{node, kind, pos, R}]
var _bolts: Array = []        # [{node, pos, vel, slow, pockets}]
var _bolt_budget: int = 0
var _event: Dictionary
var _game_manager: Node
var _info: Label
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_chrome()
	_load_level(_level)


func _build_chrome() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.03)
	add_child(shade)

	var head := Label.new()
	head.text = Loc.t("evt.banner") % str(_event["title_" + ("ru" if Loc.lang == "ru" else "en")])
	head.position = Vector2(20, 14)
	head.add_theme_font_override("font", BunkerUI.font_title())
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(head)

	_info = Label.new()
	_info.position = Vector2(20, 46)
	_info.add_theme_font_override("font", BunkerUI.font_mono())
	_info.add_theme_font_size_override("font_size", 14)
	_info.add_theme_color_override("font_color", BunkerUI.TEXT)
	add_child(_info)

	var quit := Button.new()
	quit.text = "✕"
	quit.position = Vector2(get_viewport().get_visible_rect().size.x - 60, 14)
	quit.custom_minimum_size = Vector2(44, 44)
	BunkerUI.style_button(quit, "steel", 15)
	quit.pressed.connect(_finish)
	add_child(quit)


func _load_level(level: int) -> void:
	_level = level
	if _board:
		_board.queue_free()
	_board = Control.new()
	var vp := get_viewport().get_visible_rect().size
	_board.position = Vector2(0, 100)
	_board.size = Vector2(vp.x, vp.y - 190)
	add_child(_board)

	_rng.seed = 424000 + level
	_targets.clear()
	_zones.clear()
	_bolts.clear()

	# рогатка (сталкер-зевака): точка слева по центру
	_launcher = Vector2(70.0, _board.size.y * 0.5)
	_player = _make_dot(_launcher, 22.0, Color("8fd0e8"), "Σ")

	# мишени: правая половина, часть дрейфует по вертикали
	var count := mini(3 + level / 6, 7)
	for i in count:
		var pos := Vector2(
			_rng.randf_range(_board.size.x * 0.55, _board.size.x - 60.0),
			_rng.randf_range(70.0, _board.size.y - 70.0))
		var t := _make_dot(pos, TARGET_R, Color("ffd94d"), "◎")
		_targets.append({"node": t, "base": pos, "phase": _rng.randf_range(0.0, TAU),
			"drift": 40.0 * _rng.randf_range(0.0, 1.0) if level >= 4 else 0.0})

	# гравитационные карманы: 1-3 по уровню
	var zcount := mini(1 + level / 8, 3)
	var kinds := ["vortex", "lift", "time"]
	for i in zcount:
		var kind: String = kinds[_rng.randi_range(0, kinds.size() - 1)]
		var pos := Vector2(_rng.randf_range(_board.size.x * 0.28, _board.size.x * 0.68),
			_rng.randf_range(90.0, _board.size.y - 90.0))
		var R := _rng.randf_range(90.0, 140.0)
		var glyph := "🌀" if kind == "vortex" else "▲" if kind == "lift" else "⏳"
		var col := Color("5090e0") if kind == "vortex" else Color("50c878") if kind == "lift" else Color("a070e0")
		var z := _make_dot(pos, R, Color(col, 0.25), glyph)
		_zones.append({"node": z, "kind": kind, "pos": pos, "R": R})

	_bolt_budget = count + 2
	_update_info()


func _make_dot(pos: Vector2, r: float, col: Color, glyph: String) -> Control:
	var wrap_box := Control.new()
	wrap_box.position = pos - Vector2(r, r)
	wrap_box.size = Vector2(r * 2, r * 2)
	wrap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Panel.new()
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.35)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(r))
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap_box.add_child(dot)
	if glyph != "":
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.text = glyph
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(r))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap_box.add_child(lbl)
	_board.add_child(wrap_box)
	return wrap_box


func _gui_input(ev: InputEvent) -> void:
	if _over:
		return
	var board_pos: Vector2 = ev.position - _board.position
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed and board_pos.distance_to(_launcher) < 90.0:
			_aiming = true
			_aim_start = _launcher
			_aim_cur = board_pos
		elif not ev.pressed and _aiming:
			_aiming = false
			_launch()
			if _aim_line:
				_aim_line.queue_free()
				_aim_line = null
	elif ev is InputEventMouseMotion and _aiming:
		_aim_cur = board_pos
		_draw_aim()
	elif ev is InputEventScreenTouch:
		if ev.pressed and board_pos.distance_to(_launcher) < 110.0:
			_aiming = true
			_aim_start = _launcher
			_aim_cur = board_pos
		elif not ev.pressed and _aiming:
			_aiming = false
			_launch()


func _draw_aim() -> void:
	if _aim_line:
		_aim_line.queue_free()
	_aim_line = Control.new()
	_board.add_child(_aim_line)
	# траектория-превью: 18 точек симуляции
	var vel := _launch_velocity()
	var pos := _launcher
	for i in 20:
		vel.y += G * 0.05
		pos += vel * 0.05
		for z in _zones:
			var d: Vector2 = pos - z["pos"]
			if d.length() < float(z["R"]):
				if z["kind"] == "vortex":
					vel += -d.normalized() * 900.0 * 0.05
				elif z["kind"] == "lift":
					vel.y -= 1100.0 * 0.05
		var dot := _make_dot(pos, 5.0, Color(1, 1, 1, 0.5), "")
		_aim_line.add_child(dot)


func _launch_velocity() -> Vector2:
	var pull := _aim_start - _aim_cur   # тянем назад — летит вперёд
	var vel := pull * LAUNCH_K
	if vel.length() > MAX_SPEED:
		vel = vel.normalized() * MAX_SPEED
	return vel


func _launch() -> void:
	var vel := _launch_velocity()
	if vel.length() < 120.0:
		return   # слишком слабый бросок — не тратим болт
	_bolt_budget -= 1
	var b := _make_dot(_launcher, BOLT_R, Color("e8f2e4"), "")
	_bolts.append({"node": b, "pos": _launcher, "vel": vel, "slow": 1.0,
		"pockets": {}, "t": 0.0})
	_update_info()


func _process(delta: float) -> void:
	if _over:
		return
	# дрейф мишеней
	for t in _targets:
		if float(t["drift"]) > 0.0:
			t["phase"] += delta * 1.4
			var pos: Vector2 = t["base"] + Vector2(0, sin(float(t["phase"])) * float(t["drift"]))
			t["pos"] = pos
			t["node"].position = pos - t["node"].size * 0.5
	# болты
	for b in _bolts.duplicate():
		b["t"] = float(b["t"]) + delta
		if float(b["t"]) > 12.0:
			_bolts.erase(b)
			b["node"].queue_free()
			if _bolts.is_empty() and _bolt_budget <= 0 and not _targets.is_empty():
				_finish()
			continue
		b["slow"] = 1.0
		var hit_pockets := 0
		for z in _zones:
			var d: Vector2 = b["pos"] - z["pos"]
			if d.length() < float(z["R"]):
				hit_pockets += 1
				if z["kind"] == "vortex":
					b["vel"] += -d.normalized() * 900.0 * delta
				elif z["kind"] == "lift":
					b["vel"].y -= 1100.0 * delta
				elif z["kind"] == "time":
					b["slow"] = 0.45
		b["pockets"] = hit_pockets
		b["vel"].y += G * delta
		b["pos"] += b["vel"] * delta * float(b["slow"])
		b["node"].position = b["pos"] - b["node"].size * 0.5
		# попадания
		for t in _targets.duplicate():
			if b["pos"].distance_to(t.get("pos", t["base"])) <= TARGET_R:
				_target_hit(t, int(b["pockets"]))
		# улетел за поле
		if b["pos"].x > _board.size.x + 60.0 or b["pos"].y > _board.size.y + 60.0 \
				or b["pos"].x < -60.0 or b["pos"].y < -60.0:
			_bolts.erase(b)
			b["node"].queue_free()
			if _bolts.is_empty() and _bolt_budget <= 0 and not _targets.is_empty():
				_finish()
	# уровень пройден?
	if not _over and _targets.is_empty():
		_score += 150 * _level + maxf(0, _bolt_budget) * 50
		if _level >= LEVELS:
			_score += 1000
			_finish()
		else:
			_flash(Loc.t("bolts.cleared") % _level)
			_load_level(_level + 1)


func _target_hit(t: Dictionary, pockets: int) -> void:
	_targets.erase(t)
	t["node"].queue_free()
	_score += 50
	if pockets >= 2:
		_score += 100   # золотой болт
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("anomaly_hit", 0.6, 1.1)
	if _targets.is_empty():
		pass   # обработается в _process


func _update_info() -> void:
	_info.text = "%s %d/%d   ·   %s %d   ·   %s %d" % [
		Loc.t("bolts.level"), _level, LEVELS,
		Loc.t("bolts.bolts"), _bolt_budget,
		Loc.t("zharva.score"), _score]


func _flash(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.anchor_left = 0.5
	note.anchor_right = 0.5
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = -240
	note.offset_right = 240
	note.offset_top = -92
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", BunkerUI.font_body())
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(note)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(note, "modulate:a", 0.0, 0.3)
	tw.tween_callback(note.queue_free)


func _finish() -> void:
	if _over:
		return
	_over = true
	var shards := 0
	if _game_manager and _game_manager.current_save_data:
		shards = EventOps.add_score(_game_manager.current_save_data, _event, _score)
		_game_manager.save_to_active_slot()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ceremony_win", 0.8)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -140
	panel.offset_bottom = 140
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.HAZARD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 14
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = Loc.t("bolts.done")
	t.add_theme_font_override("font", BunkerUI.font_title())
	t.add_theme_font_size_override("font_size", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "%s %d\n%s %d" % [Loc.t("zharva.score"), _score,
		Loc.t("evt.shards_line"), shards]
	s.add_theme_font_override("font", BunkerUI.font_mono())
	s.add_theme_font_size_override("font_size", 15)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var ok := Button.new()
	ok.text = Loc.t("evt.back_hub")
	ok.custom_minimum_size = Vector2(0, 48)
	BunkerUI.style_button(ok, "primary", 18, true)
	ok.pressed.connect(func():
		queue_free()
		var hub := EventHub.new()
		get_tree().current_scene.add_child(hub)
		hub.open())
	v.add_child(ok)
