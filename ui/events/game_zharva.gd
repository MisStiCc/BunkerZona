# ui/events/game_zharva.gd
extends Control
class_name GameZharva

## «ЖАТВА» (D24): match-3 7×9 на иконках аномалий. Свап соседних, каскады
## с комбо, особые тайлы (4-в-ряд = линия, 5 = саркофаг 3×3, L/T = крест),
## выброс-метр (полный = пересборка доски + ярость ×2 на 3 хода), 30 ходов.
## Результат: счёт -> EventManager (осколки/вехи).

const COLS: int = 7
const ROWS: int = 9
const TYPES: int = 6
const CS: float = 54.0     # размер клетки
const GAP: float = 4.0
const MOVES: int = 30
const FRENZY_MULT: int = 2
const FRENZY_MOVES: int = 3
const METER_4RUN: float = 40.0
const METER_5RUN: float = 100.0
const GLYPHS := ["🔥", "⚡", "☣", "🌀", "☢", "⏳"]
const COLORS := [Color("e06040"), Color("e8c840"), Color("70c850"),
	Color("5090e0"), Color("b0e040"), Color("a070e0")]

var _grid: Array = []            # [y][x] -> {t:int, sp:String}
var _cells: Array = []           # [y][x] -> Panel
var _board: Control
var _moves_left: int = MOVES
var _score: int = 0
var _combo: int = 0
var _meter: float = 0.0
var _frenzy: int = 0
var _sel: Vector2i = Vector2i(-1, -1)
var _busy: bool = false
var _meter_bar: ProgressBar
var _info: Label
var _event: Dictionary
var game_manager: Node


func _ready() -> void:
	game_manager = get_tree().get_first_node_in_group("game_manager")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	_build()
	_new_board()
	_update_info()


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.85)
	add_child(shade)

	var board_w := COLS * (CS + GAP) + GAP
	var board_h := ROWS * (CS + GAP) + GAP
	_board = Control.new()
	_board.position = (get_viewport().get_visible_rect().size - Vector2(board_w, board_h + 120.0)) * 0.5
	_board.position.y = maxf(_board.position.y, 130.0)
	_board.size = Vector2(board_w, board_h)
	_board.clip_contents = false
	add_child(_board)

	# Шапка: название, ходы/счёт, метр
	var head := Label.new()
	head.text = Loc.t("evt.banner") % str(_event["title_ru" if Loc.lang == "ru" else "title_en"])
	head.position = Vector2(20, 14)
	head.add_theme_font_override("font", BunkerUI.font_title())
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(head)

	_info = Label.new()
	_info.position = Vector2(20, 50)
	_info.add_theme_font_override("font", BunkerUI.font_mono())
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_color", BunkerUI.TEXT)
	add_child(_info)

	var meter_label := Label.new()
	meter_label.text = Loc.t("zharva.meter")
	meter_label.position = Vector2(20, 78)
	meter_label.add_theme_font_override("font", BunkerUI.font_mono())
	meter_label.add_theme_font_size_override("font_size", 12)
	meter_label.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
	add_child(meter_label)
	_meter_bar = ProgressBar.new()
	_meter_bar.position = Vector2(20, 98)
	_meter_bar.size = Vector2(260, 14)
	_meter_bar.max_value = 100.0
	_meter_bar.show_percentage = false
	add_child(_meter_bar)

	var quit := Button.new()
	quit.text = "✕"
	quit.position = Vector2(get_viewport().get_visible_rect().size.x - 60, 14)
	quit.custom_minimum_size = Vector2(44, 44)
	BunkerUI.style_button(quit, "steel", 15)
	quit.pressed.connect(_on_quit)
	add_child(quit)


func _new_board() -> void:
	_grid.clear()
	for y in ROWS:
		_grid.append([])   # строки сначала — _random_cell смотрит в соседей
	for y in ROWS:
		for x in COLS:
			_grid[y].append(_random_cell(x, y))
	if not _has_moves():
		_new_board()
		return
	_draw_board()


func _random_cell(x: int, y: int) -> Dictionary:
	var t := randi() % TYPES
	# без стартовых матчей: тянем тип, не создающий тройку слева/сверху
	while (x >= 2 and _grid[y][x - 1]["t"] == t and _grid[y][x - 2]["t"] == t) \
			or (y >= 2 and _grid[y - 1][x]["t"] == t and _grid[y - 2][x]["t"] == t):
		t = (t + 1) % TYPES
	return {"t": t, "sp": ""}


func _draw_board() -> void:
	for c in _board.get_children():
		c.queue_free()
	_cells.clear()
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			row.append(_make_cell(x, y))
		_cells.append(row)


func _make_cell(x: int, y: int) -> Panel:
	var cell: Dictionary = _grid[y][x]
	var p := Panel.new()
	p.size = Vector2(CS, CS)
	p.position = Vector2(GAP + x * (CS + GAP), GAP + y * (CS + GAP))
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLORS[cell["t"]].darkened(0.55)
	sb.border_color = COLORS[cell["t"]]
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(9)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(_on_cell_input.bind(Vector2i(x, y)))

	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = GLYPHS[cell["t"]]
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	if str(cell["sp"]) != "":
		var sp_lbl := Label.new()
		sp_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		sp_lbl.text = "✦" if cell["sp"] == "line" else "☢" if cell["sp"] == "bomb" else "✚"
		sp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		sp_lbl.add_theme_font_size_override("font_size", 20)
		sp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(sp_lbl)

	if _sel == Vector2i(x, y):
		sb.border_color = Color.WHITE
		sb.set_border_width_all(4)
	_board.add_child(p)
	return p


func _on_cell_input(ev: InputEvent, pos: Vector2i) -> void:
	if _busy or not (ev is InputEventMouseButton and ev.pressed) \
			or ev.button_index != MOUSE_BUTTON_LEFT:
		return
	if _sel == Vector2i(-1, -1):
		_sel = pos
		_redraw_cell(pos)
		return
	if _sel == pos:
		_redraw_cell(pos)  # снять выделение
		_sel = Vector2i(-1, -1)
		return
	var d: Vector2i = pos - _sel
	if absi(d.x) + absi(d.y) == 1:
		var from := _sel
		_sel = Vector2i(-1, -1)
		_try_swap(from, pos)
		return
	_redraw_cell(_sel)
	_sel = pos
	_redraw_cell(pos)


func _redraw_cell(pos: Vector2i) -> void:
	var old: Panel = _cells[pos.y][pos.x]
	_board.remove_child(old)
	old.queue_free()
	_cells[pos.y][pos.x] = _make_cell(pos.x, pos.y)


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	_busy = true
	_swap_data(a, b)
	_animate_swap(a, b, func():
		var matches := _find_matches(a, b)
		if matches.is_empty():
			_swap_data(a, b)
			_animate_swap(a, b, func():
				_redraw_cell(a)
				_redraw_cell(b)
				_busy = false)
		else:
			_moves_left -= 1
			_frenzy = maxi(0, _frenzy - 1)
			_combo = 0
			_resolve_cascades([a, b]))


func _swap_data(a: Vector2i, b: Vector2i) -> void:
	var tmp: Dictionary = _grid[a.y][a.x]
	_grid[a.y][a.x] = _grid[b.y][b.x]
	_grid[b.y][b.x] = tmp


func _animate_swap(a: Vector2i, b: Vector2i, on_done: Callable) -> void:
	var pa: Panel = _cells[a.y][a.x]
	var pb: Panel = _cells[b.y][b.x]
	var ta := create_tween()
	var tb := create_tween()
	ta.tween_property(pa, "position", _cell_pos(b), 0.12)
	tb.tween_property(pb, "position", _cell_pos(a), 0.12)
	ta.finished.connect(func():
		_cells[a.y][a.x] = pb
		_cells[b.y][b.x] = pa
		on_done.call())


func _cell_pos(p: Vector2i) -> Vector2:
	return Vector2(GAP + p.x * (CS + GAP), GAP + p.y * (CS + GAP))


## Все текущие совпадения: массив ранов [{cells:[Vector2i], horiz:bool}]
func _find_matches(swap_a: Vector2i, swap_b: Vector2i) -> Array:
	var runs: Array = []
	# горизонтальные
	for y in ROWS:
		var x := 0
		while x < COLS:
			var t: int = _grid[y][x]["t"]
			var x2 := x
			while x2 < COLS and _grid[y][x2]["t"] == t:
				x2 += 1
			if x2 - x >= 3:
				var cells: Array = []
				for i in range(x, x2):
					cells.append(Vector2i(i, y))
				runs.append({"cells": cells, "horiz": true})
			x = maxi(x + 1, x2)
	# вертикальные
	for x in COLS:
		var y := 0
		while y < ROWS:
			var t: int = _grid[y][x]["t"]
			var y2 := y
			while y2 < ROWS and _grid[y2][x]["t"] == t:
				y2 += 1
			if y2 - y >= 3:
				var cells: Array = []
				for i in range(y, y2):
					cells.append(Vector2i(x, i))
				runs.append({"cells": cells, "horiz": false})
			y = maxi(y + 1, y2)
	return runs


## Каскады: клир -> создание особых -> гравитация -> долив -> повтор
func _resolve_cascades(swap_cells: Array) -> void:
	_combo += 1
	var mult: int = FRENZY_MULT if _frenzy > 0 else 1
	var runs := _find_matches(Vector2i(-1, -1), Vector2i(-1, -1))
	if runs.is_empty():
		_end_turn()
		return

	# выделить клетки под клир (раны + срабатывающие особые)
	var clear: Dictionary = {}
	var specials: Array = []   # [{pos, sp}]
	var meter_gain := 0.0
	for run in runs:
		var n: int = run["cells"].size()
		meter_gain += METER_4RUN if n == 4 else (METER_5RUN if n >= 5 else 0.0)
		var anchor: Vector2i = run["cells"][0]
		for c in swap_cells:
			if run["cells"].has(c):
				anchor = c
		if n >= 5:
			specials.append({"pos": anchor, "sp": "bomb"})
		elif n == 4:
			specials.append({"pos": anchor, "sp": "line"})
		else:
			# пересечение гор./верт. ранов одного типа = L/T -> крест
			for other in runs:
				if other != run and other["horiz"] != run["horiz"] \
						and _grid[run["cells"][0].y][run["cells"][0].x]["t"] \
						== _grid[other["cells"][0].y][other["cells"][0].x]["t"] \
						and _intersect(run["cells"], other["cells"]):
					specials.append({"pos": _intersect(run["cells"], other["cells"]), "sp": "cross"})
					break
		for c in run["cells"]:
			clear[c] = true
	# особый тайл в клире — добавить его эффект
	for pos in clear.keys():
		var sp: String = str(_grid[pos.y][pos.x]["sp"])
		if sp == "line":
			for x in COLS:
				clear[Vector2i(x, pos.y)] = true
		elif sp == "bomb":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var p := Vector2i(pos.x + dx, pos.y + dy)
					if p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS:
						clear[p] = true
		elif sp == "cross":
			for x in COLS:
				clear[Vector2i(x, pos.y)] = true
			for y in ROWS:
				clear[Vector2i(pos.x, y)] = true

	# счёт и метр
	_score += clear.size() * 10 * _combo * mult
	_meter = minf(_meter + meter_gain, 100.0)

	# убрать клир (анимация схлопывания)
	for pos in clear:
		if pos.y < 0 or pos.y >= ROWS or pos.x < 0 or pos.x >= COLS:
			continue
		var p: Panel = _cells[pos.y][pos.x]
		if p:
			var tw := create_tween()
			tw.tween_property(p, "scale", Vector2(0.1, 0.1), 0.12)
			tw.tween_callback(p.queue_free)
			_cells[pos.y][pos.x] = null
		_grid[pos.y][pos.x] = {"t": -1, "sp": ""}

	# создать новые особые на якорях
	for s in specials:
		_grid[s["pos"].y][s["pos"].x] = {"t": _grid[s["pos"].y][s["pos"].x]["t"]
			if _grid[s["pos"].y][s["pos"].x]["t"] >= 0 else randi() % TYPES, "sp": s["sp"]}

	var tw2 := create_tween()
	tw2.tween_interval(0.16)
	tw2.tween_callback(func(): _gravity_and_refill(specials))


func _intersect(a: Array, b: Array) -> Vector2i:
	for c in a:
		if b.has(c):
			return c
	return Vector2i(-1, -1)


func _gravity_and_refill(specials: Array) -> void:
	# падение: в каждом столбце собрать снизу вверх не-пустые
	for x in COLS:
		var write := ROWS - 1
		for y in range(ROWS - 1, -1, -1):
			if _grid[y][x]["t"] >= 0:
				if y != write:
					_grid[write][x] = _grid[y][x]
					_grid[y][x] = {"t": -1, "sp": ""}
				write -= 1
		# долив сверху
		for y in range(write, -1, -1):
			_grid[y][x] = _random_cell(x, y)
	# перерисовать доску целиком (просто и надёжно)
	_draw_board()
	if _meter >= 100.0:
		_meter = 0.0
		_frenzy = FRENZY_MOVES
		_shake_board()
	# каскад продолжается, пока есть совпадения
	if not _find_matches(Vector2i(-1, -1), Vector2i(-1, -1)).is_empty():
		_resolve_cascades([])
	else:
		if not _has_moves():
			_new_board()
		_end_turn()


func _end_turn() -> void:
	_update_info()
	if _moves_left <= 0:
		_finish()
		return
	_busy = false


func _has_moves() -> bool:
	for y in ROWS:
		for x in COLS:
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var p: Vector2i = Vector2i(x, y) + d
				if p.x >= COLS or p.y >= ROWS:
					continue
				_swap_data(Vector2i(x, y), p)
				var ok := not _find_matches(Vector2i(-1, -1), Vector2i(-1, -1)).is_empty()
				_swap_data(Vector2i(x, y), p)
				if ok:
					return true
	return false


func _shake_board() -> void:
	var base := _board.position
	var tw := create_tween()
	tw.set_loops(4)
	tw.tween_property(_board, "position", base + Vector2(6, 0), 0.04)
	tw.tween_property(_board, "position", base - Vector2(6, 0), 0.04)
	tw.chain().tween_property(_board, "position", base, 0.04)


func _update_info() -> void:
	_meter_bar.value = _meter
	_info.text = "%s %d   ·   %s %d   ·   %s ×%d%s" % [
		Loc.t("zharva.moves"), _moves_left,
		Loc.t("zharva.score"), _score,
		Loc.t("zharva.combo"), _combo if _combo > 0 else 1,
		"  ·  " + Loc.t("zharva.frenzy") if _frenzy > 0 else ""]


func _on_quit() -> void:
	_finish()


func _finish() -> void:
	_busy = true
	var shards := 0
	if game_manager and game_manager.current_save_data:
		shards = EventManager.add_score(game_manager.current_save_data, _event, _score)
		game_manager.save_to_active_slot()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ceremony_win", 0.8)

	var panel := Panel.new()
	var vp := get_viewport().get_visible_rect().size
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
	t.text = Loc.t("zharva.result")
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
