# ui/events/game_uley.gd
extends Control
class_name GameUley

## «УЛЕЙ» (D24): top-down экшен — ты Химера. 5 комнат: волны сталкеров
## (новички/ветераны/мастера), медики бегут к будке вызова (не дай позвать
## подкрепление), в 5-й — Бункер-командир со щитом. Прыжок-АОЕ по клику,
## ярость на зажатии ПКМ (3× урон, HP тает). Между комнатами — выбор из
## двух благословений Зоны. HP не восстанавливается. Счёт -> осколки (/150).
##
## ВАЖНО (баг-фикс ввода): _arena.mouse_filter = IGNORE — иначе Control
## арены съедает клики, и прыжок/ярость не работают на ПК.

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
var _arena_base: Vector2 = Vector2.ZERO
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
var _hp_bar: ProgressBar = null
var _hint: Label = null
var _rig_container: Control = null
var _rig: Node3D = null
var _anim: AnimationPlayer = null
var _rig_state: String = "idle"
var _jumping: bool = false
var _face_sign: float = 1.0
var _rage_btn: Button = null


func _ready() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	_bless_pool = ["dmg", "regen", "jump_r", "rage_free", "speed", "jump_cd"].duplicate()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	# Адаптивный масштаб: на больших экранах арена 1080x640 тонула в чёрных
	# полях (баг-отчёт владельца 07.11); телефоны в ландшафте выигрывают так же
	var ascale: float = clampf(minf(vp.x / float(ROOM_W), vp.y / float(ROOM_H)) * 0.94, 0.5, 1.7)
	_arena.scale = Vector2(ascale, ascale)
	_arena.position = (vp - Vector2(ROOM_W, ROOM_H) * ascale) * 0.5
	_arena.position.y = maxf(_arena.position.y, 110.0)
	_arena_base = _arena.position
	_arena.size = Vector2(ROOM_W, ROOM_H)
	_arena.clip_contents = true
	# ИНПУТ-ФИКС: без IGNORE арена съедает клики — прыжок/ярость мертвы на ПК
	_arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_arena)
	var floor_rect := ColorRect.new()
	floor_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	floor_rect.color = Color(0.09, 0.10, 0.08)
	floor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	_make_rig_player()

	# HP-бар химеры
	_hp_bar = ProgressBar.new()
	_hp_bar.position = Vector2(20, 74)
	_hp_bar.size = Vector2(280, 16)
	_hp_bar.max_value = _hp_max
	_hp_bar.show_percentage = false
	add_child(_hp_bar)

	# подсказка управления (видна в первой комнате); автоперенос — текст
	# для тача длинный, без него уезжал за экран
	_hint = Label.new()
	_hint.text = Loc.t("uley.hint")
	_hint.position = Vector2(20, 96)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.size = Vector2(vp.x - 40.0, 60.0)
	_hint.add_theme_font_override("font", BunkerUI.font_body())
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
	add_child(_hint)

	# тач: кнопка ярости (ПК — правая кнопка мыши)
	if DisplayServer.is_touchscreen_available():
		_rage_btn = Button.new()
		_rage_btn.text = Loc.t("uley.rage")
		_rage_btn.anchor_left = 1.0
		_rage_btn.anchor_right = 1.0
		_rage_btn.anchor_top = 1.0
		_rage_btn.anchor_bottom = 1.0
		_rage_btn.offset_left = -130
		_rage_btn.offset_right = -26
		_rage_btn.offset_top = -120
		_rage_btn.offset_bottom = -30
		_rage_btn.toggle_mode = true
		BunkerUI.style_button(_rage_btn, "danger", 16)
		_rage_btn.toggled.connect(func(on: bool): _rage = on)
		add_child(_rage_btn)


## Живая Химера: 3D-риг в SubViewport-окошке поверх точки игрока
## (models/animals/chimera_rig_bonus.glb — 7 клипов, pounce/rage из задачи 45).
## Нет GLB/AnimationPlayer - остаётся арт карточки (фолбэк).
func _make_rig_player() -> void:
	const RIG_PATH := "res://models/animals/chimera_rig_bonus.glb"
	if not ResourceLoader.exists(RIG_PATH):
		return
	var ps := load(RIG_PATH) as PackedScene
	if ps == null:
		return
	var rig := ps.instantiate() as Node3D
	if rig == null:
		return
	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.size = Vector2(150, 120)
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sv := SubViewport.new()
	sv.transparent_bg = true
	sv.own_world_3d = true
	sv.handle_input_locally = false
	svc.add_child(sv)
	sv.add_child(rig)
	var cam := Camera3D.new()
	cam.position = Vector3(0.6, 4.4, 5.0)
	cam.look_at_from_position(cam.position, Vector3(0, 1.0, 0), Vector3.UP)
	sv.add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-52, 28, 0)
	light.light_energy = 1.15
	sv.add_child(light)
	# масштаб рига по высоте AABB (цель ~2.4 м в кадре)
	var aabb := _merged_aabb(rig)
	if aabb.size.y > 0.01:
		var s := 2.4 / aabb.size.y
		rig.scale = Vector3(s, s, s)
	rig.rotation.y = PI
	svc.position = _player_pos - svc.size * 0.5
	_arena.add_child(svc)
	_player.visible = false   # карточка-фолбэк прячется, живёт риг
	_rig_container = svc
	_rig = rig
	var aps := rig.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty():
		_anim = aps[0] as AnimationPlayer
		for looped in ["idle", "walk", "gallop", "rage"]:
			if _anim.has_animation(looped):
				_anim.get_animation(looped).loop_mode = Animation.LOOP_LINEAR
		_anim.animation_finished.connect(_on_rig_anim_finished)
		_anim.play("idle")
		_rig_state = "idle"


func _merged_aabb(node: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var ab: AABB = (mi as MeshInstance3D).get_aabb()
		var xf: Transform3D = (mi as MeshInstance3D).transform
		var parent = mi.get_parent()
		while parent != null and parent != node:
			xf = (parent as Node3D).transform * xf
			parent = parent.get_parent()
		var t: AABB = xf * ab
		out = t if first else out.merge(t)
		first = false
	return out


func _rig_set(state: String) -> void:
	if _anim == null or _rig_state == state:
		return
	if not _anim.has_animation(state):
		return
	_anim.play(state)
	_rig_state = state


func _on_rig_anim_finished(name: StringName) -> void:
	# одноразовые клипы возвращают в цикл движения
	if str(name) in ["pounce", "attack", "death"]:
		_jumping = false
		_rig_set("gallop" if _moving() else "idle")


func _moving() -> bool:
	var moving := false
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP) 			or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN) 			or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) 			or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		moving = true
	elif _input_point != Vector2.ZERO and _player_pos.distance_to(_input_point) > 8.0:
		moving = true
	return moving


func _update_rig(delta: float) -> void:
	if _rig_container == null or not is_instance_valid(_rig_container):
		return
	_rig_container.position = _player_pos - _rig_container.size * 0.5 + Vector2(0, -10)
	var want := "idle"
	if _rage:
		want = "rage"
	elif _jumping:
		want = "pounce"
	elif _moving():
		want = "gallop"
	_rig_set(want)
	# разворот в сторону движения (мягкий)
	var dir_sign := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		dir_sign = 1.0
	elif Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		dir_sign = -1.0
	elif _input_point.x < _player_pos.x - 4.0:
		dir_sign = 1.0
	elif _input_point.x > _player_pos.x + 4.0:
		dir_sign = -1.0
	if dir_sign != 0.0:
		_face_sign = dir_sign
	var target_yaw := PI + 0.55 * _face_sign
	_rig.rotation.y = lerp_angle(_rig.rotation.y, target_yaw, 6.0 * delta)


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
	if _hint:
		_hint.visible = _room == 1
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
	var wrap_box := Control.new()
	wrap_box.position = pos - Vector2(r, r)
	wrap_box.size = Vector2(r * 2, r * 2)
	wrap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Panel.new()
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = col.darkened(0.4)
	sb.border_color = col
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(int(r))
	dot.add_theme_stylebox_override("panel", sb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap_box.add_child(dot)
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.text = glyph
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", int(r))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap_box.add_child(lbl)
	_arena.add_child(wrap_box)
	return wrap_box


## Всплывающая цифра/текст над точкой (урон, награда за килл)
func _popup(pos: Vector2, text: String, col: Color) -> void:
	if _skipped_or_gone():
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos + Vector2(randf_range(-14.0, 14.0), -34.0)
	lbl.add_theme_font_override("font", BunkerUI.font_mono())
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena.add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 40.0, 0.55)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.55).set_delay(0.1)
	tw.chain().tween_callback(lbl.queue_free)


func _skipped_or_gone() -> bool:
	return _over or not is_instance_valid(_arena)


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
	_update_rig(delta)

	# благословение-реген (1% max HP/с)
	if _bless.has("regen") and _hp > 0.0:
		_hp = minf(_hp + _hp_max * 0.01 * delta, _hp_max)

	# ярость: визуал + цена
	_player.modulate = Color(1.6, 0.55, 0.55) if _rage else Color.WHITE
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

	# расталкивание: враги не стекуются в одну точку у химеры (баг-отчёт
	# владельца 07.11 — «почему друг на друге все»); O(n²) при ≤13 тел — копейки
	for i in _enemies.size():
		var ea: Dictionary = _enemies[i]
		if float(ea["hp"]) <= 0.0:
			continue
		for j in range(i + 1, _enemies.size()):
			var eb: Dictionary = _enemies[j]
			if float(eb["hp"]) <= 0.0:
				continue
			var dvec: Vector2 = eb["pos"] - ea["pos"]
			var mind: float = float(ENEMY_DEFS.get(ea["type"], {}).get("r", 16.0)) \
					+ float(ENEMY_DEFS.get(eb["type"], {}).get("r", 16.0))
			var dl: float = dvec.length()
			if dl > 0.001 and dl < mind:
				var push: Vector2 = dvec / dl * (mind - dl) * 0.5
				ea["pos"] = ea["pos"] - push
				eb["pos"] = eb["pos"] + push
				ea["node"].position = ea["pos"] - ea["node"].size * 0.5
				eb["node"].position = eb["pos"] - eb["node"].size * 0.5

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
			_popup(_caller_pos, "+100", Color("ffd94d"))
	_kill_check()
	_update_hud()
	if _hp <= 0.0:
		_finish(false)


func _gui_input(ev: InputEvent) -> void:
	if _over:
		return
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			_input_point = _arena_pos(ev.position)
			if _jump_cd <= 0.0:
				_do_jump()
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			_rage = ev.pressed   # ярость: зажатие ПКМ (над ареной — теперь доходит)
		elif ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
			# на таче эмулированный LMB-release от пальца движения ярость
			# (кнопку) не трогает; на ПК сброс оставлен как был
			if not DisplayServer.is_touchscreen_available() \
					and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				_rage = false
	elif ev is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_input_point = _arena_pos(ev.position)


## Тач-ввод ЧЕРЕЗ _input, минуя GUI-роутинг: на Android события до _gui_input
## не доезжали (баг-отчёт владельца 07.11 — «химера всё ещё не управляема»).
## _input получает ВСЁ до Control-фильтров, от mouse_filter не зависит.
## ПК (мышь) остаётся в _gui_input; на таче ярость — только кнопка ЯРОСТЬ,
## её тапы отсекаются по прямоугольнику и до игрока не доходят.
func _input(event: InputEvent) -> void:
	if _over or not DisplayServer.is_touchscreen_available():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if _over_ui(event.position):
				return
			_input_point = _arena_pos(event.position)
			if _jump_cd <= 0.0:
				_do_jump()
		# отпускание ярость НЕ гасит — она в кнопке
	elif event is InputEventScreenDrag:
		if not _over_ui(event.position):
			_input_point = _arena_pos(event.position)


## Тап пришёл на кнопку ЯРОСТЬ (или другой UI) — движению не отдаём
func _over_ui(screen_pos: Vector2) -> bool:
	if _rage_btn != null and is_instance_valid(_rage_btn) \
			and _rage_btn.get_global_rect().has_point(screen_pos):
		return true
	return false


func _arena_pos(screen_pos: Vector2) -> Vector2:
	# арена может быть масштабирована под экран (адаптив ниже)
	return (screen_pos - _arena.position) / _arena.scale.x


func _unhandled_input(event: InputEvent) -> void:
	# страховка: ярость ПКМ, если событие ушло мимо GUI
	if _over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rage = event.pressed


func _do_jump() -> void:
	_jump_cd = JUMP_CD * (0.6 if _bless.has("jump_cd") else 1.0)
	_jumping = true
	_rig_set("pounce")
	var target := _input_point
	var radius: float = JUMP_R * (1.4 if _bless.has("jump_r") else 1.0)
	var dmg_mult: float = (RAGE_MULT if _rage else 1.0) * (1.25 if _bless.has("dmg") else 1.0)
	# анимация прыжка к точке (ограничение дальности 260)
	var delta := target - _player_pos
	if delta.length() > 260.0:
		target = _player_pos + delta.normalized() * 260.0
	var tw := create_tween()
	# дуга: подпрыг (масштаб вверх) + перемещение
	_player.scale = Vector2(1.3, 1.3)
	tw.set_parallel(true)
	tw.tween_property(_player, "position", target - _player.size * 0.5, 0.16)
	tw.tween_property(_player, "scale", Vector2.ONE, 0.16)
	tw.chain().tween_callback(func():
		_player_pos = target
		# расширяющееся кольцо АОЕ
		var ring := _make_dot(target, radius, Color(1.0, 0.62, 0.1, 0.85), "")
		var tw2 := create_tween()
		tw2.set_parallel(true)
		tw2.tween_property(ring, "scale", Vector2(1.0, 1.0), 0.22) \
			.from(Vector2(0.25, 0.25))
		tw2.tween_property(ring, "modulate:a", 0.0, 0.26)
		tw2.chain().tween_callback(ring.queue_free)
		_shake_arena(4.0)
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_sound"):
			sm.play_sound("anomaly_hit", 0.5, randf_range(0.9, 1.1))
		if _caller_hp > 0.0 and target.distance_to(_caller_pos) <= radius + 22.0:
			_caller_hp -= JUMP_DMG * dmg_mult
			if _caller_hp <= 0.0:
				_caller.visible = false
				_score += 100
				_popup(_caller_pos, "+100", Color("ffd94d"))
		var hit_any := false
		for e in _enemies:
			if float(e["hp"]) <= 0.0:
				continue
			if e["pos"].distance_to(target) <= radius:
				hit_any = true
				var dmg: float = JUMP_DMG * dmg_mult
				if e["type"] == "boss" and float(e.get("shield", 0.0)) > 0.0:
					e["shield"] = float(e["shield"]) - dmg
				else:
					e["hp"] = float(e["hp"]) - dmg
				_popup(e["pos"], "%d" % int(dmg), Color(1.0, 0.85, 0.4))
				# вспышка попадания
				if is_instance_valid(e["node"]):
					e["node"].modulate = Color(2.0, 2.0, 2.0)
					var tf := create_tween()
					tf.tween_property(e["node"], "modulate", Color.WHITE, 0.15)
		if hit_any:
			var sm2 = get_tree().get_first_node_in_group("sound_manager")
			if sm2 and sm2.has_method("play_sound"):
				sm2.play_sound("anomaly_hit", 0.4, randf_range(1.0, 1.15))
		_kill_check())


## Тряска арены (возврат в базу гарантирован)
func _shake_arena(px: float) -> void:
	var tw := create_tween()
	tw.set_loops(3)
	tw.tween_property(_arena, "position", _arena_base + Vector2(px, 0), 0.03)
	tw.tween_property(_arena, "position", _arena_base - Vector2(px, 0), 0.03)
	tw.chain().tween_property(_arena, "position", _arena_base, 0.03)


func _kill_check() -> void:
	var alive := 0
	for e in _enemies:
		if float(e["hp"]) <= 0.0 and e["node"].visible:
			e["node"].visible = false
			var def: Dictionary = ENEMY_DEFS.get(e["type"], {})
			var mult := 2.0 if _no_dmg_t > 8.0 else 1.0
			var pts := int(def.get("score", 10)) * int(mult)
			_score += pts
			_popup(e["pos"], "+%d" % pts, Color("ffd94d"))
		if float(e["hp"]) > 0.0:
			alive += 1
	if alive == 0:
		_room_cleared()


func _room_cleared() -> void:
	_score += int(200.0 / maxf(1.0, float(_room)))   # бонус за быстроту комнаты
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("gates_open", 0.7)
	_popup(Vector2(ROOM_W * 0.5, ROOM_H * 0.5),
		Loc.t("uley.room_clear") % _room, BunkerUI.GREEN)
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
	if _hp_bar:
		_hp_bar.value = maxf(_hp, 0.0)
	var lang := "ru" if Loc.lang == "ru" else "en"
	_hud_lbl.text = "%s %d/%d   ·   %s %d" % [
		Loc.t("uley.room"), _room, ROOMS, Loc.t("zharva.score"), _score]
	var enemy_alive := 0
	for e in _enemies:
		if float(e["hp"]) > 0.0:
			enemy_alive += 1
	_hud2_lbl.text = "%s %d   ·   ⛏ %s: %.0f" % [
		Loc.t("uley.enemies"), enemy_alive,
		Loc.t("uley.caller"), maxf(_caller_hp, 0.0) if _caller_hp > 0.0 else 0.0]
	if _rage:
		_hud2_lbl.text += "   ·   ⚡ " + Loc.t("uley.rage_on")


func _finish(win: bool) -> void:
	if _over and not win:
		return
	_over = true
	if not win and _anim != null and _anim.has_animation("death"):
		_anim.play("death")   # оседание рига под панелью итогов
	if win:
		_score += 500
	var shards := 0
	if _game_manager and _game_manager.current_save_data:
		shards = EventOps.add_score(_game_manager.current_save_data, _event, _score)
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
