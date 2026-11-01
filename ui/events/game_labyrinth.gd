# ui/events/game_labyrinth.gd
extends Control
class_name GameLabyrinth

## «ЛАБИРИНТ ВЫБРОСА» (D24): maze-TD. Лабиринт 13×9 генерируется по дню
## (все игроки — один и тот же), сталкеры идут от входа к выходу по
## кратчайшему пути; строишь аномалии в клетках за энергию — жги и
## задерживай. 8 волн; 5 прорвавшихся — конец. Счёт -> осколки (/80).

const COLS: int = 13
const ROWS: int = 9
const CS: float = 56.0
const WAVES: int = 8
const ESCAPE_LIMIT: int = 5
const ENERGY_START: float = 500.0
const ENERGY_PER_KILL: float = 12.0

# Аномалии постройки: цена / dps / радиус (клеток) / замедление
const BUILDS := {
	"zharva_a": {"cost": 50.0, "dps": 25.0, "radius": 1.0, "slow": 0.0, "glyph": "🔥", "col": Color("e06040")},
	"electra_a": {"cost": 90.0, "dps": 40.0, "radius": 1.5, "slow": 0.0, "glyph": "⚡", "col": Color("e8c840")},
	"vortex_a": {"cost": 120.0, "dps": 10.0, "radius": 2.0, "slow": 0.5, "glyph": "🌀", "col": Color("5090e0")},
	"tesla_a": {"cost": 200.0, "dps": 90.0, "radius": 2.0, "slow": 0.0, "glyph": "☢", "col": Color("a070e0")},
}

var _walls: Array = []            # [y][x] -> true = стена
var _dist: Array = []             # BFS-дистанции до выхода
var _enemies: Array = []          # [{node, hp, speed, cell, next, t, slow_t}]
var _builds: Array = []           # [{node, key, cell, tick}]
var _wave: int = 0
var _spawn_queue: int = 0
var _spawn_t: float = 0.0
var _wave_break: float = 2.0
var _energy: float = ENERGY_START
var _score: int = 0
var _escaped: int = 0
var _over: bool = false
var _selected: String = ""
var _board: Control
var _info: Label
var _dock: HBoxContainer
var _event: Dictionary
var _game_manager: Node
var _tick: float = 0.0


func _ready() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_gen_maze()
	_bfs()
	_start_wave(1)


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.02)
	add_child(shade)

	var board_w := COLS * CS
	var board_h := ROWS * CS
	var vp := get_viewport().get_visible_rect().size
	_board = Control.new()
	_board.position = Vector2((vp.x - board_w) * 0.5, maxf((vp.y - board_h) * 0.42, 110.0))
	_board.size = Vector2(board_w, board_h)
	add_child(_board)

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

	# Док постройки (4 аномалии)
	_dock = HBoxContainer.new()
	_dock.anchor_top = 1.0
	_dock.anchor_bottom = 1.0
	_dock.anchor_left = 0.5
	_dock.anchor_right = 0.5
	_dock.offset_left = -260
	_dock.offset_right = 260
	_dock.offset_top = -78
	_dock.offset_bottom = -14
	_dock.add_theme_constant_override("separation", 8)
	add_child(_dock)
	for key in BUILDS:
		var b: Button = Button.new()
		var def: Dictionary = BUILDS[key]
		b.text = "%s %d" % [str(def["glyph"]), int(def["cost"])]
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 20)
		BunkerUI.style_button(b, "steel", 16)
		b.pressed.connect(_on_build_selected.bind(key))
		b.tooltip_text = "%s dps %d · %s" % [str(def["glyph"]), int(def["dps"]),
			Loc.t("lab.slow") if float(def["slow"]) > 0.0 else ""]
		_dock.add_child(b)

	var quit := Button.new()
	quit.text = "✕"
	quit.position = Vector2(vp.x - 60, 14)
	quit.custom_minimum_size = Vector2(44, 44)
	BunkerUI.style_button(quit, "steel", 15)
	quit.pressed.connect(_finish.bind(false))
	add_child(quit)


func _on_build_selected(key: String) -> void:
	_selected = key
	_flash(Loc.t("labyrinth.selected") % str(BUILDS[key]["glyph"]))


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
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(note)
	var tw := create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(note, "modulate:a", 0.0, 0.3)
	tw.tween_callback(note.queue_free)


# ==================== ЛАБИРИНТ ====================

## Карвинг лабиринта по чётным узлам (классический DFS) + просветы-петли.
## Seed дня: у всех игроков сегодня один и тот же лабиринт.
func _gen_maze() -> void:
	var rng := RandomNumberGenerator.new()
	var day := Time.get_date_dict_from_system()
	rng.seed = int(day["year"]) * 10000 + int(day["month"]) * 100 + int(day["day"])
	_walls.clear()
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			row.append(true)
		_walls.append(row)
	# DFS по узлам (нечётные координаты)
	var stack: Array = [Vector2i(1, 1)]
	_walls[1][1] = false
	while not stack.is_empty():
		var cur: Vector2i = stack.back()
		var dirs: Array = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
		# сидированный Fisher-Yates: лабиринт дня одинаков у всех игроков
		for i in range(dirs.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp_d: Vector2i = dirs[i]
			dirs[i] = dirs[j]
			dirs[j] = tmp_d
		var moved := false
		for d in dirs:
			var nxt: Vector2i = cur + d
			if nxt.x >= 1 and nxt.x < COLS - 1 and nxt.y >= 1 and nxt.y < ROWS - 1 \
					and _walls[nxt.y][nxt.x]:
				_walls[cur.y + (d.y >> 1)][cur.x + (d.x >> 1)] = false
				_walls[nxt.y][nxt.x] = false
				stack.append(nxt)
				moved = true
				break
		if not moved:
			stack.pop_back()
	# петли: прорезаем случайные стены (rng дня)
	var cuts := 0
	var tries := 0
	while cuts < 10 and tries < 200:
		tries += 1
		var x := rng.randi_range(1, COLS - 2)
		var y := rng.randi_range(1, ROWS - 2)
		if not _walls[y][x]:
			continue
		var horiz_open: bool = not _walls[y][x - 1] and not _walls[y][x + 1]
		var vert_open: bool = not _walls[y - 1][x] and not _walls[y + 1][x]
		if horiz_open or vert_open:
			_walls[y][x] = false
			cuts += 1
	# вход/выход
	_walls[1][0] = false
	_walls[ROWS - 2][COLS - 1] = false


## BFS-дистанции до выхода (ROWS-2, COLS-1)
func _bfs() -> void:
	_dist.clear()
	for y in ROWS:
		var row: Array = []
		for x in COLS:
			row.append(-1)
		_dist.append(row)
	var start := Vector2i(COLS - 1, ROWS - 2)
	var q: Array = [start]
	_dist[start.y][start.x] = 0
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= COLS or nxt.y < 0 or nxt.y >= ROWS:
				continue
			if _walls[nxt.y][nxt.x] or _dist[nxt.y][nxt.x] != -1:
				continue
			_dist[nxt.y][nxt.x] = _dist[cur.y][cur.x] + 1
			q.append(nxt)
	# отрисовка пола/стен
	for y in ROWS:
		for x in COLS:
			var cell := ColorRect.new()
			cell.position = Vector2(x * CS, y * CS)
			cell.size = Vector2(CS - 1.0, CS - 1.0)
			if _walls[y][x]:
				cell.color = Color(0.16, 0.18, 0.16)
			elif Vector2i(x, y) == Vector2i(0, 1) or Vector2i(x, y) == Vector2i(COLS - 1, ROWS - 2):
				cell.color = Color(0.45, 0.35, 0.1)   # вход/выход золотом
			else:
				cell.color = Color(0.07, 0.09, 0.07)
			cell.mouse_filter = Control.MOUSE_FILTER_STOP
			if not _walls[y][x]:
				cell.gui_input.connect(_on_cell_input.bind(Vector2i(x, y)))
			_board.add_child(cell)


func _on_cell_input(ev: InputEvent, cell: Vector2i) -> void:
	if _over or _selected == "" or not (ev is InputEventMouseButton and ev.pressed):
		return
	_place_build(cell)


func _place_build(cell: Vector2i) -> void:
	if _walls[cell.y][cell.x] or _dist[cell.y][cell.x] == -1:
		return
	var def: Dictionary = BUILDS[_selected]
	if _energy < float(def["cost"]):
		_flash(Loc.t("labyrinth.no_energy"))
		return
	for b in _builds:
		if b["cell"] == cell:
			return   # клетка занята
	_energy -= float(def["cost"])
	var node := _make_dot(_cell_center(cell), 20.0, def["col"], str(def["glyph"]))
	_builds.append({"node": node, "key": _selected, "cell": cell, "tick": 0.0})
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.6)


func _cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * CS + CS * 0.5, cell.y * CS + CS * 0.5)


# ==================== ВОЛНЫ И ВРАГИ ====================

func _start_wave(n: int) -> void:
	_wave = n
	_spawn_queue = 4 + n * 2
	_spawn_t = 0.0
	_flash(Loc.t("labyrinth.wave") % n)


func _process(delta: float) -> void:
	if _over:
		return
	# спавн волны
	if _spawn_queue > 0:
		_spawn_t -= delta
		if _spawn_t <= 0.0:
			_spawn_t = 1.1
			_spawn_queue -= 1
			_spawn_enemy(_wave)
	elif _enemies.is_empty():
		if _wave_break > 0.0:
			_wave_break -= delta
			if _wave_break <= 0.0:
				_wave_break = 2.0
				if _wave >= WAVES:
					_finish(true)
					return
				_start_wave(_wave + 1)
		elif _spawn_queue == 0 and _enemies.is_empty():
			_wave_break = 2.0

	# башни: тик урона 4 раза/с
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		_towers_tick()

	# враги
	for e in _enemies.duplicate():
		_move_enemy(e, delta)
	_update_info()


func _towers_tick() -> void:
	for b in _builds:
		var def: Dictionary = BUILDS[b["key"]]
		b["tick"] = float(b["tick"]) + 0.25
		if float(b["tick"]) < 0.5:
			continue
		b["tick"] = 0.0
		var center: Vector2 = _cell_center(b["cell"])
		var radius: float = float(def["radius"]) * CS
		var deads: Array = []
		for e in _enemies:
			if float(e["hp"]) <= 0.0:
				continue
			if e["pos"].distance_to(center) <= radius:
				e["hp"] -= float(def["dps"]) * 0.5
				if float(def["slow"]) > 0.0:
					e["slow_t"] = 0.6
					e["slow_f"] = float(def["slow"])
				if float(e["hp"]) <= 0.0:
					deads.append(e)
		for e in deads:
			_on_enemy_dead(e)


func _spawn_enemy(wave: int) -> void:
	var cell := Vector2i(0, 1)
	var hp := 60.0 * (1.0 + 0.35 * float(wave - 1))
	var speed := 70.0 + 6.0 * float(wave)
	var node := _make_dot(_cell_center(cell), 15.0, Color("d0d0d0"), "")
	var path := _descent_path(cell)
	_enemies.append({"node": node, "hp": hp, "max_hp": hp, "speed": speed,
		"path": path, "idx": 0, "pos": _cell_center(cell), "wave": wave,
		"slow_t": 0.0, "slow_f": 0.0})


## Путь спуском по BFS-полю (от входа к выходу)
func _descent_path(from: Vector2i) -> Array:
	var path: Array = [from]
	var cur := from
	var guard := 0
	while _dist[cur.y][cur.x] != 0 and guard < COLS * ROWS:
		guard += 1
		var stepped := false
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= COLS or nxt.y < 0 or nxt.y >= ROWS:
				continue
			if _dist[nxt.y][nxt.x] == _dist[cur.y][cur.x] - 1:
				cur = nxt
				path.append(cur)
				stepped = true
				break
		if not stepped:
			break   # поля консистентны — не бывает, но без вечного цикла
	return path


func _move_enemy(e: Dictionary, delta: float) -> void:
	if float(e["slow_t"]) > 0.0:
		e["slow_t"] = float(e["slow_t"]) - delta
	var slow: float = float(e["slow_f"]) if float(e["slow_t"]) > 0.0 else 0.0
	var speed: float = float(e["speed"]) * (1.0 - slow)
	var path: Array = e["path"]
	var idx: int = int(e["idx"])
	if idx >= path.size():
		_escape(e)
		return
	var target: Vector2 = _cell_center(path[idx])
	var pos: Vector2 = e["pos"]
	var to := target - pos
	if to.length() < 4.0:
		e["idx"] = idx + 1
		return
	e["pos"] = pos + to.normalized() * speed * delta
	e["node"].position = e["pos"] - e["node"].size * 0.5


func _escape(e: Dictionary) -> void:
	_enemies.erase(e)
	e["node"].queue_free()
	_escaped += 1
	_flash(Loc.t("labyrinth.escaped"))
	if _escaped >= ESCAPE_LIMIT:
		_finish(false)


func _on_enemy_dead(e: Dictionary) -> void:
	_enemies.erase(e)
	e["node"].queue_free()
	_energy += ENERGY_PER_KILL
	_score += 10 + 5 * int(e.get("wave", 1))
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("anomaly_hit", 0.5, randf_range(0.9, 1.1))


func _update_info() -> void:
	var pending := _spawn_queue + _enemies.size()
	_info.text = "%s %d/%d   ·   ⚡ %d   ·   %s %d/%d   ·   %s %d" % [
		Loc.t("labyrinth.wave_short"), _wave, WAVES,
		int(_energy),
		Loc.t("labyrinth.escape"), _escaped, ESCAPE_LIMIT,
		Loc.t("zharva.score"), _score]


func _finish(win: bool) -> void:
	if _over:
		return
	_over = true
	if win:
		_score += 500
	var shards := 0
	if _game_manager and _game_manager.current_save_data:
		shards = EventManager.add_score(_game_manager.current_save_data, _event, _score)
		_game_manager.save_to_active_slot()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ceremony_win" if win else "pulse_warning", 0.8,
			1.0 if win else 0.7)
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
	sb.border_color = BunkerUI.HAZARD if win else BunkerUI.DANGER
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
	t.text = Loc.t("labyrinth.win") if win else Loc.t("labyrinth.lost")
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


func _make_dot(pos: Vector2, r: float, col: Color, glyph: String) -> Control:
	var wrap := Control.new()
	wrap.position = pos - Vector2(r, r)
	wrap.size = Vector2(r * 2, r * 2)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Panel.new()
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.4)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(r))
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(dot)
	if glyph != "":
		var lbl := Label.new()
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		lbl.text = glyph
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", int(r))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(lbl)
	_board.add_child(wrap)
	return wrap
