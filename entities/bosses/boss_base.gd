# entities/bosses/boss_base.gd
extends CharacterBody3D
class_name BossBase

## Ежедневный босс (спека D19): идёт к краю Зоны («уходит»), автоатака по
## ближайшему мутанту, generic-скиллы по кулдаунам. Мутанты бьют его сами
## (группа "stalkers" - их FSM видит цель). Смерть -> died(id, sparks).

signal died(boss_id: String, sparks: int)
signal escaped(boss_id: String)

var boss_id: String = ""
var boss_name: String = ""
var sparks: int = 3
var max_hp: float = 1000.0
var hp: float = 1000.0
var move_speed: float = 2.0
var shield: float = 0.0
var damage_total: float = 0.0   # весь полученный урон (вклад рейда)
var _exit_point: Vector3 = Vector3.ZERO
var _skills: Array = []                 # [{id, cd, dmg, r, ...}]
var _skill_cd: Dictionary = {}          # id -> готовность (msec)
var _attack_cd: float = 0.0
var _hp_label: Label3D = null
var _hp_bar_fg: MeshInstance3D = null   # заливка полосы HP (шейдер-дискайрд по ratio)
var _hp_bar_mat: ShaderMaterial = null  # её материал - сюда пишется ratio/цвет
var _bar_w: float = 3.0
var _bar_h: float = 0.35
static var _bar_shader: Shader = null   # общий шейдер полос всех боссов
var _vampiric := false

const AUTO_ATTACK_DMG := 26.0
const AUTO_ATTACK_RANGE := 4.0
const AUTO_ATTACK_CD := 1.2
const EXIT_REACH := 6.0
const ENGAGE_RADIUS := 16.0   # мутанты ближе - босс стоит и дерётся
const AGGRO_RADIUS := 40.0    # мутанты дальше - босс идёт к ним сам
var _side_step_time: float = 0.0
var _blink_cd: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var dash_time: float = 0.0
var _aggro: bool = false


func setup(id: String, data: Dictionary, stat_mult: float, from: Vector3, to: Vector3,
		display_name: String = "", tint: Color = Color(0, 0, 0, 0)) -> void:
	boss_id = id
	boss_name = str(data.get("name_ru", id))
	sparks = int(data.get("sparks", 3))
	move_speed = float(data.get("speed", 2.0))
	max_hp = BossHuntData.BOSS_BASE_HP * float(data.get("hp_x", 20.0)) * stat_mult
	hp = max_hp
	_exit_point = to
	_skills = data.get("skills", [])
	global_position = from
	add_to_group("stalkers")
	add_to_group("bosses")
	add_to_group("enemies")

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.4
	cap.height = 4.0
	col.shape = cap
	col.position.y = 2.0
	add_child(col)

	var model_id := str(data.get("model", "flesh"))
	var model_path := "res://models/animals/%s_anim.glb" % model_id
	var model_scale := float(data.get("scale", 1.8))
	if ResourceLoader.exists(model_path):
		var model: Node3D = load(model_path).instantiate()
		model.scale = Vector3(model_scale, model_scale, model_scale)
		add_child(model)

	boss_name = display_name if display_name != "" else boss_name
	_hp_label = Label3D.new()
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.font_size = 52
	_hp_label.pixel_size = 0.01
	_hp_label.modulate = Color(1.0, 0.35, 0.3)
	_hp_label.outline_size = 10
	_hp_label.position.y = 2.0 + model_scale * 2.2
	_hp_label.text = boss_name
	add_child(_hp_label)
	# Полоса HP: фон + заливка (шейдер отбрасывает UV.x > ratio), билборд
	# вручную в vertex - позиционных офсетов нет, depletion всегда слева
	_bar_w = 1.6 * model_scale + 1.2
	_bar_h = clampf(0.18 * model_scale, 0.3, 0.6)
	var bar_y := 2.0 + model_scale * 1.55
	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(_bar_w, _bar_h)
	bg.mesh = bg_mesh
	bg.material_override = _make_bar_material(Color(0.05, 0.03, 0.03, 0.85), 1.0, 0)
	bg.position.y = bar_y
	add_child(bg)
	_hp_bar_fg = MeshInstance3D.new()
	var fg_mesh := QuadMesh.new()
	fg_mesh.size = Vector2(_bar_w, _bar_h)
	_hp_bar_fg.mesh = fg_mesh
	_hp_bar_mat = _make_bar_material(Color(0.9, 0.25, 0.15, 0.95), 1.0, 1)
	_hp_bar_fg.material_override = _hp_bar_mat
	_hp_bar_fg.position.y = bar_y
	add_child(_hp_bar_fg)
	# Пробуждённый окрас (гильд-босс): аддитивное свечение поверх текстур
	if tint.a > 0.0:
		var overlays: Array = []
		_collect_meshes(self, overlays)
		for mesh in overlays:
			mesh.material_overlay = _make_glow(tint)

	for s in _skills:
		_skill_cd[str(s.get("id", "")) + str(s.get("cd", 0.0))] = 0


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_attack_cd -= delta
	_blink_cd = maxf(_blink_cd - delta, 0.0)
	_tick_skills()
	# Полоса/% обновляются каждый кадр: ветки ниже выходят ранними return
	_update_label()
	var mutants := _mutants_in(10000.0)
	# Автоатака по ближайшему
	if _attack_cd <= 0.0 and not mutants.is_empty():
		var nearest: Node = mutants[0]
		for m in mutants:
			if m.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position):
				nearest = m
		if global_position.distance_to(nearest.global_position) <= AUTO_ATTACK_RANGE:
			if nearest.has_method("take_damage"):
				nearest.take_damage(AUTO_ATTACK_DAMAGE(), self)
			_attack_cd = AUTO_ATTACK_CD
	# Ход к краю (стоячие боссы speed 0 не двигаются). Без телепорт-рывков:
	# только velocity + move_and_slide, стрейф при столкновении.
	if dash_time > 0.0:
		dash_time -= delta
		velocity = dash_dir * 48.0
		move_and_slide()
		return
	# Стоячий босс (speed 0): если бой далеко - мигает к ближайшему мутанту,
	# чтобы не простаивать весь рейд (раз в 6с, Туманница/Столп)
	if move_speed <= 0.01:
		var far_all := _mutants_in(10000.0)
		if not far_all.is_empty():
			var nearest: Node = far_all[0]
			for m in far_all:
				if m.global_position.distance_to(global_position) < nearest.global_position.distance_to(global_position):
					nearest = m
			if nearest.global_position.distance_to(global_position) > 25.0 and _blink_cd <= 0:
				_blink_cd = 6.0
				var dir_b: Vector3 = (nearest.global_position - global_position)
				dir_b.y = 0.0
				global_position += dir_b.normalized() * (nearest.global_position.distance_to(global_position) - 18.0)
		return
	if move_speed > 0.01:
		var walk_target := Vector3.ZERO
		var near := _mutants_in(ENGAGE_RADIUS)
		var far := _mutants_in(AGGRO_RADIUS)
		if not near.is_empty():
			# Втягивание: дерётся с теми, кто рядом
			velocity = Vector3.ZERO
		elif not far.is_empty():
			# Агрессия: идёт К ближайшему мутанту в радиусе агро
			var tgt: Node = far[0]
			for m in far:
				if m.global_position.distance_to(global_position) < tgt.global_position.distance_to(global_position):
					tgt = m
			walk_target = tgt.global_position
		else:
			# Патруль к краю Зоны
			walk_target = _exit_point
		var dir := walk_target - global_position
		dir.y = 0.0
		if dir.length() > 2.0:
			dir = dir.normalized()
			velocity = dir * move_speed
			move_and_slide()
			# Стрейф при столкновении: перпендикуляр, сторона меняется раз в 2с
			if get_slide_collision_count() > 0:
				_side_step_time += delta
				var side: float = 1.0 if fmod(_side_step_time, 4.0) < 2.0 else -1.0
				var perp: Vector3 = dir.cross(Vector3.UP) * side
				velocity = perp * move_speed
				move_and_slide()
			else:
				_side_step_time = 0.0
		else:
			velocity = Vector3.ZERO


func _make_bar_material(col: Color, ratio: float, priority: int) -> ShaderMaterial:
	if _bar_shader == null:
		_bar_shader = Shader.new()
		# Билборд вручную (матрица из осей камеры) - работает с любого угла
		_bar_shader.code = """
shader_type spatial;
render_mode unshaded, depth_test_disabled;

uniform float ratio : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.9, 0.25, 0.15, 0.95);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	if (UV.x > ratio) {
		discard;
	}
	ALBEDO = fill_color.rgb;
	ALPHA = fill_color.a;
}
"""
	var m := ShaderMaterial.new()
	m.shader = _bar_shader
	m.render_priority = priority
	m.set_shader_parameter("ratio", ratio)
	m.set_shader_parameter("fill_color", col)
	return m


func _update_label() -> void:
	if _hp_label:
		var pct := int(100.0 * hp / maxf(max_hp, 1.0))
		_hp_label.text = "%s %d%%" % [boss_name, pct]
	if _hp_bar_mat:
		var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		_hp_bar_mat.set_shader_parameter("ratio", ratio)
		# зелёный -> жёлтый -> красный по остатку
		var col: Color
		if ratio > 0.5:
			col = Color(0.95, 0.75, 0.15).lerp(Color(0.35, 0.85, 0.25), (ratio - 0.5) * 2.0)
		else:
			col = Color(0.9, 0.2, 0.12).lerp(Color(0.95, 0.75, 0.15), ratio * 2.0)
		col.a = 0.95
		_hp_bar_mat.set_shader_parameter("fill_color", col)


func AUTO_ATTACK_DAMAGE() -> float:
	return 26.0 * maxf(1.0, max_hp / (BossHuntData.BOSS_BASE_HP * 20.0))


## Для Выброса и прицеливания: босс жив?
func is_alive() -> bool:
	return hp > 0.0


func take_damage(amount: float, _source = null) -> void:
	if hp <= 0.0:
		return
	var dmg := float(amount)
	# Выброс выжигает сталкеров 999999 - босса только ранит (10% макс HP + 200)
	if dmg > max_hp * 0.3:
		dmg = max_hp * 0.10 + 200.0
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	hp -= dmg
	damage_total += dmg
	if hp <= 0.0:
		hp = 0.0
		died.emit(boss_id, sparks)
		queue_free()


# ==================== СКИЛЛЫ (generic) ====================

func _tick_skills() -> void:
	var now := Time.get_ticks_msec()
	for s in _skills:
		var key := str(s.get("id", "")) + str(s.get("cd", 0.0))
		var cd_ms: int = int(float(s.get("cd", 0.0)) * 1000.0)
		if cd_ms <= 0:
			_passive(s)
			continue
		if now < int(_skill_cd.get(key, 0)):
			continue
		_skill_cd[key] = now + cd_ms
		_cast(s)


func _mutants_in(r: float) -> Array:
	var out: Array = []
	for m in get_tree().get_nodes_in_group("mutants"):
		if is_instance_valid(m) and m.global_position.distance_to(global_position) <= r:
			out.append(m)
	return out


func _cast(s: Dictionary) -> void:
	match str(s.get("id", "")):
		"quake":
			for m in _mutants_in(float(s.get("r", 8.0))):
				if m.has_method("take_damage"):
					m.take_damage(float(s.get("dmg", 25.0)), self)
		"snipe":
			var targets := _mutants_in(30.0)
			var best: Node = null
			for m in targets:
				if best == null or _hp_of(m) > _hp_of(best):
					best = m
			if best and best.has_method("take_damage"):
				best.take_damage(float(s.get("dmg", 40.0)), self)
		"blink":
			var mutants := _mutants_in(20.0)
			var away := global_position
			if not mutants.is_empty():
				var centroid := Vector3.ZERO
				for m in mutants:
					centroid += m.global_position
				centroid /= mutants.size()
				away = global_position + (global_position - centroid).normalized() * 12.0
			global_position = Vector3(away.x, global_position.y, away.z)
		"dot_zone":
			_spawn_dot(global_position, float(s.get("r", 4.0)), float(s.get("dmg", 8.0)), float(s.get("t", 6.0)))
		"summon":
			for i in range(int(s.get("n", 2))):
				_spawn_minion(float(s.get("hp_frac", 0.25)))
		"stun_nearest":
			var mutants2 := _mutants_in(6.0)
			if not mutants2.is_empty():
				var m = mutants2[randi() % mutants2.size()]
				m.set_meta("hunt_stun_until", Time.get_ticks_msec() + int(float(s.get("t", 3.0)) * 1000.0))
				if m.has_method("take_damage"):
					m.take_damage(15.0, self)
		"dash":
			dash_dir = (_exit_point - global_position).normalized()
			dash_time = 0.25   # рывок растянут на 0.25с - без телепорта
		"shield":
			shield = float(s.get("amount", 800.0))
		"regen":
			hp = minf(hp + max_hp * float(s.get("frac", 0.05)), max_hp)
		"vampiric":
			_vampiric = true
	# Пассив вампиризма тикает всегда
	if _vampiric:
		var near := _mutants_in(8.0)
		if not near.is_empty():
			hp = minf(hp + max_hp * 0.02 * near.size() * get_physics_process_delta_time(), max_hp)


func _passive(_s: Dictionary) -> void:
	pass


func _hp_of(m) -> float:
	return float(m.get("hp")) if "hp" in m else 100.0


func _collect_meshes(node: Node, out: Array) -> void:
	for ch in node.get_children():
		_collect_meshes(ch, out)
	if node is MeshInstance3D:
		out.append(node)


func _make_glow(tint: Color) -> StandardMaterial3D:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(tint.r, tint.g, tint.b, 0.35)
	return glow


func _spawn_dot(pos: Vector3, r: float, dps: float, t: float) -> void:
	var zone := Area3D.new()
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = r
	col.shape = sph
	zone.add_child(col)
	zone.global_position = pos
	add_child(zone)
	var tick := Timer.new()
	tick.wait_time = 0.5
	tick.autostart = true
	zone.add_child(tick)
	tick.timeout.connect(func():
		for m in get_tree().get_nodes_in_group("mutants"):
			if is_instance_valid(m) and m.global_position.distance_to(pos) <= r and m.has_method("take_damage"):
				m.take_damage(dps * 0.5, self))
	var life := get_tree().create_timer(t)
	life.timeout.connect(func(): zone.queue_free())


func _spawn_minion(hp_frac: float) -> void:
	var mini := CharacterBody3D.new()
	mini.add_to_group("mutants")
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.8
	cap.height = 2.2
	col.shape = cap
	col.position.y = 1.1
	mini.add_child(col)
	var mini_script := GDScript.new()
	mini_script.source_code = '''
extends CharacterBody3D
var hp := 100.0
func _physics_process(_d):
	for m in get_tree().get_nodes_in_group("mutants"):
		pass
'''
	# v1: мелочь - просто тело с HP, мутанты бьют её как цель группы "bosses_minions"
	mini.add_to_group("stalkers")
	mini.set_meta("minion", true)
	mini.set_script(null)
	get_parent().add_child(mini)
	mini.global_position = global_position + Vector3(randf_range(-3, 3), 0.5, randf_range(-3, 3))
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.text = "🩸"
	lbl.position.y = 2.6
	mini.add_child(lbl)
