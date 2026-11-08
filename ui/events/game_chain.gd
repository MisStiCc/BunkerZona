# ui/events/game_chain.gd
extends Control
class_name GameChain

## «ЦЕПЬ ЭЛЕКТРЫ» (D24): pipes-головоломка. Вращай трубы (тап = 90°),
## замкни цепь от Теслы к Монолиту до таймера. Уровни процедурные
## (seed = номер уровня — гарантированно решаемые): генерируется решённая
## цепь, повороты перемешиваются. Конденсатор пропускает ток при 2 входах.
## Счёт: уровень ×100 + остаток времени ×5; осколки = счёт/300.

const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const TIMER_START: float = 60.0
const TIMER_MIN: float = 25.0
const LEVELS: int = 40

var _level: int = 1
var _w: int = 5
var _h: int = 4
var _cells: Array = []            # [y][x] -> {mask:int, fixed:bool, cond:bool}
var _powered: Array = []          # [y][x] -> bool
var _solved: bool = false
var _time_left: float = TIMER_START
var _score: int = 0
var _over: bool = false
var _board: Control
var _cell_panels: Array = []
var _info: Label
var _time_bar: ProgressBar
var _event: Dictionary
var _game_manager: Node


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
	shade.color = Color(0.02, 0.02, 0.02)
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

	_time_bar = ProgressBar.new()
	_time_bar.position = Vector2(20, 74)
	_time_bar.size = Vector2(280, 14)
	_time_bar.show_percentage = false
	add_child(_time_bar)

	var quit := Button.new()
	quit.text = "✕"
	quit.position = Vector2(get_viewport().get_visible_rect().size.x - 60, 14)
	quit.custom_minimum_size = Vector2(44, 44)
	BunkerUI.style_button(quit, "steel", 15)
	quit.pressed.connect(_finish)
	add_child(quit)


# ==================== ГЕНЕРАЦИЯ УРОВНЯ ====================

func _load_level(level: int) -> void:
	_level = level
	_w = mini(5 + (level - 1) / 7, 8)
	_h = mini(4 + (level - 1) / 9, 6)
	_time_left = maxf(TIMER_MIN, TIMER_START - float(level) * 0.8)
	_solved = false

	var rng := RandomNumberGenerator.new()
	rng.seed = 777000 + level

	_cells.clear()
	_powered.clear()
	for y in _h:
		var row: Array = []
		var prow: Array = []
		for x in _w:
			row.append({"mask": 0, "fixed": false, "cond": false})
			prow.append(false)
		_cells.append(row)
		_powered.append(prow)

	# Источник слева, сток справа
	var src := Vector2i(0, rng.randi_range(0, _h - 1))
	var dst := Vector2i(_w - 1, rng.randi_range(0, _h - 1))
	_cells[src.y][src.x] = {"mask": 2, "fixed": true, "cond": false}    # Tesla -> E
	_cells[dst.y][dst.x] = {"mask": 8, "fixed": true, "cond": false}    # Monolith <- W

	# Главный путь: монотонный блуждание вправо
	var path: Array = [src]
	var cur := src
	while cur.x < dst.x or cur.y != dst.y:
		var step: Vector2i
		if cur.x < dst.x and (cur.y == dst.y or rng.randf() < 0.6):
			step = Vector2i(1, 0)
		else:
			step = Vector2i(0, signi(dst.y - cur.y))
		cur += step
		path.append(cur)

	# Маски главного пути (связь к предыдущему и следующему);
	# Тесла/Монолит - fixed, но СМОТРЯТ на фактический шаг пути
	for i in range(1, path.size() - 1):
		var p: Vector2i = path[i]
		if _cells[p.y][p.x]["fixed"]:
			continue
		var m := _dir_to(path[i - 1], p) | _dir_to(path[i + 1], p)
		_cells[p.y][p.x]["mask"] = m
	_cells[src.y][src.x]["mask"] = _dir_to(src, path[1])
	_cells[dst.y][dst.x]["mask"] = _dir_to(dst, path[path.size() - 2])

	# Ветки-декойи (2-4 шага в свободные клетки)
	var branches := mini(1 + level / 12, 3)
	for b in branches:
		var start: Vector2i = path[rng.randi_range(1, path.size() - 2)]
		cur = start
		for step_n in rng.randi_range(2, 4):
			var free: Array = []
			for d in DIRS:
				var nxt: Vector2i = cur + d
				if nxt.x >= 0 and nxt.x < _w and nxt.y >= 0 and nxt.y < _h \
						and _cells[nxt.y][nxt.x]["mask"] == 0:
					free.append(nxt)
			if free.is_empty():
				break
			var nxt: Vector2i = free[rng.randi_range(0, free.size() - 1)]
			var d := nxt - cur
			_cells[cur.y][cur.x]["mask"] |= _dir_mask(d)
			_cells[nxt.y][nxt.x]["mask"] = _dir_mask(-d)
			cur = nxt

	# Конденсатор (ур. 10+): на главном пути; вторая ветка к нему от источника
	if level >= 10:
		var mid_i: int = path.size() / 2
		var mid: Vector2i = path[mid_i]
		_cells[mid.y][mid.x]["cond"] = true
		# вторая ветка: шагаем влево по пустым клеткам, пока не упрёмся
		# в уже подключённую клетку сети (тогда 2-й вход гарантирован)
		var back: Vector2i = mid
		var guard := 0
		while guard < _w:
			guard += 1
			var target: Vector2i = Vector2i(back.x - 1, back.y)
			if target.x < 0 or _cells[target.y][target.x]["fixed"]:
				break
			_cells[back.y][back.x]["mask"] |= _dir_to(back, target)
			if _cells[target.y][target.x]["mask"] != 0:
				_cells[target.y][target.x]["mask"] |= _dir_to(target, back)
				break   # упёрлись в сеть - цепь замкнута
			_cells[target.y][target.x]["mask"] = _dir_to(target, back)
			back = target

	# Декой-трубы в пустых клетках
	for y in _h:
		for x in _w:
			if _cells[y][x]["mask"] == 0 and not Vector2i(x, y) in [src, dst]:
				var kinds := [3, 6, 12, 9, 5, 10]   # прямые и углы
				_cells[y][x]["mask"] = kinds[rng.randi_range(0, kinds.size() - 1)]

	# Перемешать повороты (не трогая фиксированные)
	for y in _h:
		for x in _w:
			if not _cells[y][x]["fixed"]:
				var rot := rng.randi_range(0, 3)
				for i in rot:
					_cells[y][x]["mask"] = _rot90(_cells[y][x]["mask"])

	# Гарантия «не решено сразу»
	if _is_solved():
		var x2 := rng.randi_range(1, _w - 2)
		var y2 := rng.randi_range(0, _h - 1)
		if not _cells[y2][x2]["fixed"]:
			_cells[y2][x2]["mask"] = _rot90(_cells[y2][x2]["mask"])

	_propagate_power()
	_draw_board()
	_update_info()


func _dir_to(from: Vector2i, to: Vector2i) -> int:
	var d: Vector2i = to - from
	for i in DIRS.size():
		if DIRS[i] == d:
			return 1 << i
	return 0


func _dir_mask(d: Vector2i) -> int:
	for i in DIRS.size():
		if DIRS[i] == d:
			return 1 << i
	return 0


func _rot90(mask: int) -> int:
	# поворот по часовой: N->E, E->S, S->W, W->N
	return ((mask << 1) & 0b1111) | (mask >> 3)


func _opposite(mask: int) -> int:
	return ((mask << 2) & 0b1111) | (mask >> 2)


## Распространение тока до стабилизации (конденсатор требует 2 входа)
func _propagate_power() -> void:
	for y in _h:
		for x in _w:
			_powered[y][x] = false
	var changed := true
	var guard := 0
	while changed and guard < _w * _h + 4:
		guard += 1
		changed = false
		for y in _h:
			for x in _w:
				if _powered[y][x] or _cells[y][x]["mask"] == 0:
					continue
				var inputs := 0
				for i in DIRS.size():
					if (_cells[y][x]["mask"] & (1 << i)) == 0:
						continue
					var n: Vector2i = Vector2i(x, y) + DIRS[i]
					if n.x < 0 or n.x >= _w or n.y < 0 or n.y >= _h:
						continue
					if _powered[n.y][n.x] and (_cells[n.y][n.x]["mask"] & (1 << ((i + 2) % 4))) != 0:
						inputs += 1
				var need := 2 if _cells[y][x]["cond"] else 1
				if inputs >= need:
					_powered[y][x] = true
					changed = true


func _is_solved() -> bool:
	_propagate_power()
	for y in _h:
		for x in _w:
			if _cells[y][x]["fixed"] and _cells[y][x]["mask"] == 8:
				return _powered[y][x]
	return false


# ==================== ОТОБРАЖЕНИЕ И ВВОД ====================

func _draw_board() -> void:
	if _board:
		_board.queue_free()
	_board = Control.new()
	var vp := get_viewport().get_visible_rect().size
	var cs := minf((vp.x - 60.0) / float(_w), (vp.y - 200.0) / float(_h))
	_board.position = Vector2((vp.x - float(_w) * cs) * 0.5,
		maxf((vp.y - float(_h) * cs) * 0.55, 110.0))
	_board.size = Vector2(float(_w) * cs, float(_h) * cs)
	add_child(_board)
	_cell_panels.clear()

	for y in _h:
		var prow: Array = []
		for x in _w:
			prow.append(_make_pipe_cell(Vector2i(x, y), cs))
		_cell_panels.append(prow)


func _make_pipe_cell(cell: Vector2i, cs: float) -> Control:
	var wrap_box := Control.new()
	wrap_box.position = Vector2(cell.x * cs, cell.y * cs)
	wrap_box.size = Vector2(cs, cs)
	wrap_box.mouse_filter = Control.MOUSE_FILTER_STOP
	wrap_box.gui_input.connect(_on_cell_input.bind(cell))
	_board.add_child(wrap_box)

	var base := ColorRect.new()
	base.position = Vector2(2, 2)
	base.size = Vector2(cs - 4, cs - 4)
	base.color = Color(0.06, 0.09, 0.06)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap_box.add_child(base)

	var c: Dictionary = _cells[cell.y][cell.x]
	var mid := cs * 0.5
	var bar := cs * 0.22
	var powered: bool = _powered[cell.y][cell.x]
	var wire := BunkerUI.HAZARD_BRIGHT if powered else Color(0.35, 0.38, 0.34)
	if c["fixed"]:
		wire = Color(0.55, 0.85, 0.95) if c["mask"] == 2 else BunkerUI.GREEN
	for i in DIRS.size():
		if (int(c["mask"]) & (1 << i)) == 0:
			continue
		var bar_rect := ColorRect.new()
		bar_rect.color = wire
		bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match i:
			0:   # N
				bar_rect.position = Vector2(mid - bar * 0.5, 2)
				bar_rect.size = Vector2(bar, mid - 2)
			1:   # E
				bar_rect.position = Vector2(mid, mid - bar * 0.5)
				bar_rect.size = Vector2(mid - 2, bar)
			2:   # S
				bar_rect.position = Vector2(mid - bar * 0.5, mid)
				bar_rect.size = Vector2(bar, mid - 2)
			3:   # W
				bar_rect.position = Vector2(2, mid - bar * 0.5)
				bar_rect.size = Vector2(mid - 2, bar)
		wrap_box.add_child(bar_rect)

	var glyph := Label.new()
	glyph.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph.text = "⚡" if int(c["mask"]) == 2 else "🏛" if c["fixed"] else "◈" if c["cond"] else ""
	glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph.add_theme_font_size_override("font_size", int(cs * 0.4))
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap_box.add_child(glyph)
	return wrap_box


func _on_cell_input(ev: InputEvent, cell: Vector2i) -> void:
	if _over or _solved:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if _cells[cell.y][cell.x]["fixed"]:
			return
		_cells[cell.y][cell.x]["mask"] = _rot90(int(_cells[cell.y][cell.x]["mask"]))
		_propagate_power()
		var was := _solved
		_solved = _is_solved()
		_redraw_cell(cell)
		if _solved and not was:
			_level_cleared()


func _redraw_cell(cell: Vector2i) -> void:
	var cs := _board.size.x / float(_w)
	var old: Control = _cell_panels[cell.y][cell.x]
	old.queue_free()
	_cell_panels[cell.y][cell.x] = _make_pipe_cell(cell, cs)


func _process(delta: float) -> void:
	if _over:
		return
	if not _solved:
		_time_left -= delta
		if _time_left <= 0.0:
			_time_left = 0.0
			_over = true
			_flash(Loc.t("chain.timeout"))
			_finish()
			return
	_time_bar.max_value = maxf(TIMER_START - float(_level) * 0.8, TIMER_MIN)
	_time_bar.value = _time_left
	_update_info()


func _level_cleared() -> void:
	_score += _level * 100 + int(_time_left) * 5
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("anomaly_electric" if sm.get("anomaly_sounds").has("anomaly_electric") else "electric", 0.7)
	_flash(Loc.t("chain.closed"))
	# короткая пауза и следующий уровень (или финал)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func():
		if _level >= LEVELS:
			_score += 2000
			_finish()
		else:
			_solved = false
			_load_level(_level + 1))


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


func _update_info() -> void:
	_info.text = "%s %d/%d   ·   %s %d" % [
		Loc.t("chain.level"), _level, LEVELS,
		Loc.t("zharva.score"), _score]


func _finish() -> void:
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
	t.text = Loc.t("chain.done")
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
