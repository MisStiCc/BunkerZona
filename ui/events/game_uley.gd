# ui/events/game_uley.gd
extends Control
class_name GameUley

## «УЛЕЙ» (D24): top-down экшен — ты Химера. 5 комнат: волны сталкеров
## (новички/ветераны/мастера), медики бегут к будке вызова (не дай позвать
## подкрепление), в 5-й — Бункер-командир со щитом. Прыжок-АОЕ по клику,
## ярость на зажатии (3× урон, HP тает). Между комнатами — выбор из двух
## благословений Зоны. HP не восстанавливается. Счёт -> осколки (/150).

const ROOM_W: float = 1080.0
const ROOM_H: float = 640.0
const PLAYER_SPEED: float = 280.0
const PLAYER_HP: float = 600.0
const JUMP_CD: float = 0.9
const JUMP_R: float = 95.0
const JUMP_DMG: float = 60.0
const TOUCH_DMG: float = 14.0
const RAGE_MULT: float = 3.0
const RAGE_COST: float = 5.0
const ROOMS: int = 5
const CALLER_HP: float = 220.0
const BOSS_HP: float = 2200.0
const BOSS_SHIELD: float = 700.0

const ENEMY_DEFS := {
	"novice": {"hp": 80.0, "dmg": 8.0, "speed": 90.0, "r": 16.0, "score": 10, "col": Color("9aa0a6")},
	"veteran": {"hp": 150.0, "dmg": 15.0, "speed": 110.0, "r": 18.0, "score": 20, "col": Color("5090e0")},
	"master": {"hp": 250.0, "dmg": 25.0, "speed": 130.0, "r": 20.0, "score": 35, "col": Color("d05040")},
	"medic": {"hp": 60.0, "dmg": 0.0, "speed": 170.0, "r": 14.0, "score": 15, "col": Color("50c878")},
	"boss": {"hp": 1.0, "dmg": 25.0, "speed": 0.0, "r": 30.0, "score": 150, "col": Color("b040e0")},
}

var _room: int = 1
var _hp: float = PLAYER_HP
var _hp_max: float = PLAYER_HP
var _score: int = 0
var _no_dmg_t: float = 0.0
var _jump_cd: float = 0.0
var _rage: bool = false
var _arena: Control
var _player: Control
var _player_pos: Vector2
var _enemies: Array = []          # [{node, type, hp, pos}]
var _caller: Control = null
var _caller_pos: Vector2
var _caller_hp: float = 0.0
var _event: Dictionary
var _game_manager: Node
var _bless_pool: Array = []
var _bless: Dictionary = {}       # {dmg, regen, jump_r, rage_free, jump_cd, speed}
var _over: bool = false
var _input_point: Vector2 = Vector2.ZERO


func _ready() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	_bless_pool = ["dmg", "regen", "jump_r", "rage_free", "speed"].duplicate()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_setup_room()
	set_process(true)


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.02)
	add_child(shade)

	var vp := get_viewport().get_visible_rect().size
	_arena = Control.new()
	_arena.position = (vp - Vector2(ROOM_W, ROOM_H)) * 0.5
	_arena.position.y = maxf(_arena.position.y, 90.0)
	_arena.size = Vector2(ROOM_W, ROOM_H)
	_arena.clip_contents = true
	add_child(_arena)
	var floor_rect := ColorRect.new()
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_rect.color = Color(0.09, 0.10, 0.08)
	_arena.add_child(floor_rect)

	var head := Label.new()
	head.text = Loc.t("evt.banner") % str(_event["title_" + ("ru" if Loc.lang == "ru" else "en")])
	head.position = Vector2(20, 14)
	head.add_theme_font_override("font", BunkerUI.font_title())
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(head)

	# Игрок — химера (арт карточки), коллизия точкой
	_player = TextureRect.new()
	var tex_path := "res://ui/cards/mut_chimera.png"
	if ResourceLoader.exists(tex_path):
		_player = TextureRect.new()
		(_player as TextureRect).texture = load(tex_path)
		(_player as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		(_player as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player.custom_minimum_size = Vector2(64, 64)
	_player.size = Vector2(64, 64)
	_player.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_pos = Vector2(ROOM_W * 0.5, ROOM_H - 90.0)
	_arena.add_child(_player)

	# тач: кнопка ярости (ПК — правая кнопка мыши)
	if DisplayServer.is_touchscreen_available():
		var rage_btn := Button.new()
		rage_btn.text = Loc.t("uley.rage")
		rage_btn.anchor_left = 1.0
		rage_btn.anchor_right = 1.0
		rage_btn.anchor_top = 1.0
		rage_btn.anchor_bottom = 1.0
		rage_btn.offset_left = -130
		rage_btn.offset_right = -26
		rage_btn.offset_top = -120
		rage_btn.offset_bottom = -30
		rage_btn.toggle_mode = true
		BunkerUI.style_button(rage_btn, "danger", 16)
		rage_btn.toggled.connect(func(on: bool): _rage = on)
		add_child(rage_btn)


func _setup_room() -> void:
	# будка вызова в случайном углу (кроме низа)
	var corners := [Vector2(70, 70), Vector2(ROOM_W - 70, 70), Vector2(70, 140)]
	_caller_pos = corners[randi() % corners.size()]
	_caller_hp = CALLER_HP
	_caller = _make_dot(_caller_pos, 22.0, Color("c99a1e"), "⛏")
	_enemies.clear()
	var defs: Array = []
	match _room:
		1:
			defs = [["novice", 5]]
		2:
			defs = [["novice", 4], ["veteran", 2], ["medic", 1]]
		3:
			defs = [["veteran", 4], ["master", 1], ["medic", 2]]
		4:
			defs = [["veteran", 3], ["master", 3], ["medic", 2]]
		5:
			defs = [["master", 4], ["medic", 2]]
	for pair in defs:
		for i in int(pair[1]):
			_spawn_enemy(str(pair[0]))
	if _room == ROOMS:
		_spawn_boss()
	_update_hud()


func _spawn_enemy(type: String) -> void:
	var def: Dictionary = ENEMY_DEFS[type]
	var pos := _free_spot()
	var node := _make_dot(pos, float(def["r"]), def["col"], _glyph_for(type))
	_enemies.append({"node": node, "type": type, "hp": float(def["hp"]), "pos": pos})


func _spawn_boss() -> void:
	var pos := Vector2(ROOM_W * 0.5, 110.0)
	var node := _make_dot(pos, 30.0, Color("b040e0"), "☠")
	_enemies.append({"node": node, "type": "boss", "hp": BOSS_HP, "pos": pos,
		"shield": BOSS_SHIELD, "shield_t": 0.0})


func _glyph_for(type: String) -> String:
	match type:
		"medic": return "✚"
		"master": return "М"
		"veteran": return "В"
	return "Н"


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
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = glyph
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(r))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(lbl)
	_arena.add_child(wrap)
	return wrap


func _alive_enemies() -> int:
	var n := 0
	for e in _enemies:
		if float(e["hp"]) > 0.0:
			n += 1
	return n


func _free_spot() -> Vector2:
	for i in 40:
		var p := Vector2(randf_range(60, ROOM_W - 60), randf_range(60, ROOM_H * 0.55))
		if p.distance_to(_player_pos) > 220.0:
			return p
	return Vector2(randf_range(60, ROOM_W - 60), 120.0)


func _process(delta: float) -> void:
	if _over:
		return
	_no_dmg_t += delta
	_jump_cd = maxf(0.0, _jump_cd - delta)
	var speed := PLAYER_SPEED * (1.25 if _bless.has("speed") else 1.0)

	# движение: WASD + тап-цель
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir.x += 1
	if dir != Vector2.ZERO:
		_player_pos += dir.normalized() * speed * delta
	elif _input_point != Vector2.ZERO:
		var to := _input_point - _player_pos
		if to.length() > 6.0:
			_player_pos += to.normalized() * speed * delta
	_player_pos.x = clampf(_player_pos.x, 34.0, ROOM_W - 34.0)
	_player_pos.y = clampf(_player_pos.y, 34.0, ROOM_H - 34.0)
	_player.position = _player_pos - _player.size * 0.5

	# ярость
	if _rage:
		if not _bless.has("rage_free"):
			_hp -= RAGE_COST * delta
		if _hp <= 0.0:
			_finish(false)
			return

	# враги
	var dmg_mult: float = RAGE_MULT if _rage else 1.0
	if _bless.has("dmg"):
		dmg_mult *= 1.25
	for e in _enemies.duplicate():
		if float(e["hp"]) <= 0.0:
			continue
		var def: Dictionary = ENEMY_DEFS.get(e["type"], {})
		var epos: Vector2 = e["pos"]
		var to_player := _player_pos - epos
		# босс: щит по кулдауну
		if e["type"] == "boss":
			e["shield_t"] = float(e["shield_t"]) - delta
			if e["shield_t"] <= 0.0:
				e["shield"] = BOSS_SHIELD
				e["shield_t"] = 6.0
		if e["type"] == "medic":
			# медик бежит к будке; добежал — зовёт подкрепление и отходит
			# (кулдаун, чтобы поток новичков не был бесконечным)
			e["call_cd"] = float(e.get("call_cd", 0.0)) - delta
			var to_call: Vector2 = _caller_pos - epos
			if _caller_hp <= 0.0:
				pass   # будка разбита — медики мечутся (стоят на месте)
			elif to_call.length() > 14.0:
				epos += to_call.normalized() * float(def["speed"]) * delta
			elif float(e.get("call_cd", 0.0)) <= 0.0 and _alive_enemies() < 12:
				_spawn_enemy("novice")
				e["call_cd"] = 10.0
				epos -= to_call.normalized() * 60.0   # отходит от будки
		else:
			if to_player.length() > float(def.get("r", 16.0)) + 24.0:
				epos += to_player.normalized() * float(def["speed"]) * delta
			else:
				# кусает химеру
				_no_dmg_t = 0.0
				_hp -= float(def["dmg"]) * delta * 2.0
		e["pos"] = epos
		e["node"].position = epos - e["node"].size * 0.5

	# автоукус химеры по касанию
	for e in _enemies:
		if float(e["hp"]) <= 0.0:
			continue
		var def: Dictionary = ENEMY_DEFS.get(e["type"], {})
		if e["pos"].distance_to(_player_pos) < float(def.get("r", 16.0)) + 30.0:
			var dps: float = 40.0 * dmg_mult
			if e["type"] == "boss" and float(e.get("shield", 0.0)) > 0.0:
				e["shield"] = float(e["shield"]) - dps * delta
			else:
				e["hp"] = float(e["hp"]) - dps * delta
	# химера грызёт будку вплотную
	if _caller_hp > 0.0 and _player_pos.distance_to(_caller_pos) < 60.0:
		_caller_hp -= 40.0 * delta
		if _caller_hp <= 0.0:
			_caller.visible = false
			_score += 100
	_kill_check()
	_update_hud()
	if _hp <= 0.0:
		_finish(false)


func _gui_input(ev: InputEvent) -> void:
	if _over:
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		_input_point = _arena_pos(ev.position)
		if _jump_cd <= 0.0:
			_do_jump()
	elif ev is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_input_point = _arena_pos(ev.position)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		_rage = false
	elif ev is InputEventScreenTouch:
		if ev.pressed:
			_input_point = _arena_pos(ev.position)
			if _jump_cd <= 0.0:
				_do_jump()
		else:
			_rage = false


func _arena_pos(screen_pos: Vector2) -> Vector2:
	return screen_pos - _arena.position


func _unhandled_input(event: InputEvent) -> void:
	# ярость: зажатие на игроке (ПК) / длинный тап
	if _over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rage = event.pressed


func _do_jump() -> void:
	_jump_cd = JUMP_CD * (0.6 if _bless.has("jump_cd") else 1.0)
	var target := _input_point
	var radius: float = JUMP_R * (1.4 if _bless.has("jump_r") else 1.0)
	var dmg_mult: float = (RAGE_MULT if _rage else 1.0) * (1.25 if _bless.has("dmg") else 1.0)
	# анимация прыжка к точке (ограничение дальности 260)
	var delta := target - _player_pos
	if delta.length() > 260.0:
		target = _player_pos + delta.normalized() * 260.0
	var tw := create_tween()
	tw.tween_property(_player, "position", target - _player.size * 0.5, 0.14)
	tw.tween_callback(func():
		_player_pos = target
		# кольцо АОЕ
		var ring := _make_dot(target - Vector2(radius, radius), radius,
			Color(1.0, 0.62, 0.1, 0.85), "")
		var tw2 := create_tween()
		tw2.tween_property(ring, "modulate:a", 0.0, 0.3)
		tw2.tween_callback(ring.queue_free)
		if _caller_hp > 0.0 and target.distance_to(_caller_pos) <= radius + 22.0:
			_caller_hp -= JUMP_DMG * dmg_mult
			if _caller_hp <= 0.0:
				_caller.visible = false
				_score += 100
		for e in _enemies:
			if float(e["hp"]) <= 0.0:
				continue
			if e["pos"].distance_to(target) <= radius:
				var dmg: float = JUMP_DMG * dmg_mult
				if e["type"] == "boss" and float(e.get("shield", 0.0)) > 0.0:
					e["shield"] = float(e["shield"]) - dmg
				else:
					e["hp"] = float(e["hp"]) - dmg
		_kill_check())


func _kill_check() -> void:
	var alive := 0
	for e in _enemies:
		if float(e["hp"]) <= 0.0 and e["node"].visible:
			e["node"].visible = false
			var def: Dictionary = ENEMY_DEFS.get(e["type"], {})
			var mult := 2.0 if _no_dmg_t > 8.0 else 1.0
			_score += int(def.get("score", 10)) * int(mult)
		if float(e["hp"]) > 0.0:
			alive += 1
	if alive == 0:
		_room_cleared()


func _room_cleared() -> void:
	_score += int(200.0 / maxf(1.0, float(_room)))   # бонус за быстроту комнаты
	if _room >= ROOMS:
		_finish(true)
		return
	_room += 1
	_offer_blessings()


func _offer_blessings() -> void:
	_over = true
	var pick_a: String = _bless_pool[randi() % _bless_pool.size()]
	var pool2 := _bless_pool.duplicate()
	pool2.erase(pick_a)
	var pick_b: String = pool2[randi() % pool2.size()]
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -160
	panel.offset_bottom = 160
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = Loc.t("uley.blessing")
	t.add_theme_font_override("font", BunkerUI.font_title())
	t.add_theme_font_size_override("font_size", 20)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	for pick in [pick_a, pick_b]:
		var b := Button.new()
		b.text = Loc.t("uley.bless_" + pick)
		b.custom_minimum_size = Vector2(0, 54)
		BunkerUI.style_button(b, "steel", 15)
		b.pressed.connect(func():
			_bless[pick] = true
			panel.queue_free()
			_over = false
			_setup_room()
			_update_hud())
		v.add_child(b)


var _hud_lbl: Label = null
var _hud2_lbl: Label = null


func _update_hud() -> void:
	if _hud_lbl == null:
		_hud_lbl = Label.new()
		_hud_lbl.position = Vector2(20, 46)
		_hud_lbl.add_theme_font_override("font", BunkerUI.font_mono())
		_hud_lbl.add_theme_font_size_override("font_size", 14)
		_hud_lbl.add_theme_color_override("font_color", BunkerUI.TEXT)
		add_child(_hud_lbl)
	if _hud2_lbl == null:
		_hud2_lbl = Label.new()
		_hud2_lbl.position = Vector2(20, 66)
		_hud2_lbl.add_theme_font_override("font", BunkerUI.font_mono())
		_hud2_lbl.add_theme_font_size_override("font_size", 13)
		_hud2_lbl.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
		add_child(_hud2_lbl)
	var lang := "ru" if Loc.lang == "ru" else "en"
	_hud_lbl.text = "%s %d/%d   ·   HP %.0f   ·   %s %d" % [
		Loc.t("uley.room"), _room, ROOMS, maxf(_hp, 0.0), Loc.t("zharva.score"), _score]
	var enemy_alive := 0
	for e in _enemies:
		if float(e["hp"]) > 0.0:
			enemy_alive += 1
	_hud2_lbl.text = "%s %d   ·   ⛏ %s: %.0f" % [
		Loc.t("uley.enemies"), enemy_alive,
		Loc.t("uley.caller"), maxf(_caller_hp, 0.0) if _caller_hp > 0.0 else 0.0]
	_hud2_lbl.text += "   ·   ⚡ %s" % Loc.t("uley.rage_on") if _rage else ""


func _finish(win: bool) -> void:
	if _over and not win:
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
	t.text = Loc.t("uley.win") if win else Loc.t("uley.dead")
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
