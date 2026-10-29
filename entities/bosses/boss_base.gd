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
var _exit_point: Vector3 = Vector3.ZERO
var _skills: Array = []                 # [{id, cd, dmg, r, ...}]
var _skill_cd: Dictionary = {}          # id -> готовность (msec)
var _attack_cd: float = 0.0
var _hp_label: Label3D = null
var _vampiric := false

const AUTO_ATTACK_DMG := 26.0
const AUTO_ATTACK_RANGE := 4.0
const AUTO_ATTACK_CD := 1.2
const EXIT_REACH := 6.0
const ENGAGE_RADIUS := 16.0   # мутанты ближе - босс стоит и дерётся


func setup(id: String, data: Dictionary, stat_mult: float, from: Vector3, to: Vector3) -> void:
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

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.4
	cap.height = 4.0
	col.shape = cap
	col.position.y = 2.0
	add_child(col)

	var model_id := str(data.get("model", "flesh"))
	var model_path := "res://models/animals/%s_anim.glb" % model_id
	if ResourceLoader.exists(model_path):
		var model: Node3D = load(model_path).instantiate()
		var s := float(data.get("scale", 1.8))
		model.scale = Vector3(s, s, s)
		add_child(model)

	_hp_label = Label3D.new()
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.font_size = 52
	_hp_label.pixel_size = 0.01
	_hp_label.modulate = Color(1.0, 0.35, 0.3)
	_hp_label.outline_size = 10
	_hp_label.position.y = 6.0
	_hp_label.text = boss_name
	add_child(_hp_label)

	for s in _skills:
		_skill_cd[str(s.get("id", "")) + str(s.get("cd", 0.0))] = 0


func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_attack_cd -= delta
	_tick_skills()
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
	# Ход к краю (стоячие боссы speed 0 - не двигаются).
	# Втягивание в бой: мутанты рядом (ENGAGE_RADIUS) - босс останавливается
	# воевать, иначе доходит до выхода слишком быстро.
	if move_speed > 0.01:
		var dir := (_exit_point - global_position)
		dir.y = 0.0
		var dist := dir.length()
		if dist < EXIT_REACH:
			escaped.emit(boss_id)
			queue_free()
			return
		var engaged := not _mutants_in(ENGAGE_RADIUS).is_empty()
		if engaged:
			velocity = Vector3.ZERO
		else:
			velocity = dir.normalized() * move_speed
			move_and_slide()
		if get_slide_collision_count() > 0 and velocity.length() < 0.5:
			# проталкивание мимо препятствия (прямой ход без навмеша)
			global_position += (global_transform.basis.z * 0.5 + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))).normalized() * 2.0
	_update_label()


func _update_label() -> void:
	if _hp_label:
		var pct := int(100.0 * hp / maxf(max_hp, 1.0))
		_hp_label.text = "%s %d%%" % [boss_name, pct]


func AUTO_ATTACK_DAMAGE() -> float:
	return 26.0 * maxf(1.0, max_hp / (BossHuntData.BOSS_BASE_HP * 20.0))


func take_damage(amount: float, _source = null) -> void:
	if hp <= 0.0:
		return
	var dmg := float(amount)
	if shield > 0.0:
		var absorbed: float = minf(shield, dmg)
		shield -= absorbed
		dmg -= absorbed
	hp -= dmg
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
			var dir := (_exit_point - global_position).normalized()
			global_position += dir * 12.0
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
