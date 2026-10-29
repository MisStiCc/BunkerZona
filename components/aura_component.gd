# components/aura_component.gd
extends Node
class_name AuraComponent

## Аура поддержки (D20): тик 0.5 с - хил-реген/бафы союзникам-мутантам
## в радиусе, хил-пульс/луч по кулдауну, контроль (заморозка/страх).
## Стаки бафов от разных аур капятся (AURA_STACK_CAP).

var aura: Dictionary = {}          # из MutantRoles.AURAS
var owner_mutant: Node = null      # мутант-носитель
var _pulse_cd: float = 0.0
var _beam_cd: float = 0.0
var _freeze_cd: float = 0.0
var _fear_cd: float = 0.0
var _tick: float = 0.0
var _ring: MeshInstance3D = null


func setup(mutant: Node, aura_data: Dictionary) -> void:
	owner_mutant = mutant
	aura = aura_data
	if float(aura.get("radius", 0.0)) > 0.0:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = float(aura["radius"]) - 0.15
		torus.outer_radius = float(aura["radius"])
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.5, 1.0, 0.6, 0.25)
		torus.material = mat
		_ring.mesh = torus
		_ring.position.y = 0.15
		mutant.add_child(_ring)


func _physics_process(delta: float) -> void:
	if owner_mutant == null or not is_instance_valid(owner_mutant) or aura.is_empty():
		return
	if "is_alive" in owner_mutant and not owner_mutant.is_alive():
		return
	_pulse_cd -= delta
	_beam_cd -= delta
	_freeze_cd -= delta
	_fear_cd -= delta
	_tick += delta
	if _tick < 0.5:
		return
	_tick = 0.0

	var r := float(aura.get("radius", 0.0))
	var allies := _allies_in(r) if r > 0.0 else []

	# Реген-аура
	if aura.has("heal_pct") and not allies.is_empty():
		for m in allies:
			_heal(m, float(aura["heal_pct"]))

	# Бафы (кап стаков по meta)
	_apply_buff(allies, "aura_dmg", float(aura.get("dmg_pct", 0.0)))
	_apply_buff(allies, "aura_speed", float(aura.get("speed_pct", 0.0)))
	_apply_buff(allies, "aura_atk", float(aura.get("atk_speed_pct", 0.0)))

	# Хил-пульс
	if aura.has("pulse") and _pulse_cd <= 0.0:
		var p: Dictionary = aura["pulse"]
		var wounded: Array = []
		for m in allies:
			if _hp_frac(m) < 0.95:
				wounded.append(m)
		wounded.sort_custom(func(a, b): return _hp_frac(a) < _hp_frac(b))
		for i in range(mini(int(p.get("targets", 1)), wounded.size())):
			_heal(wounded[i], float(p.get("heal_pct", 0.1)))
		_pulse_cd = float(p.get("cd", 6.0))

	# Луч: самый раненый, большой хил
	if aura.has("beam") and _beam_cd <= 0.0:
		var b: Dictionary = aura["beam"]
		var all_allies := _allies_in(14.0)
		var worst: Node = null
		for m in all_allies:
			if worst == null or _hp_frac(m) < _hp_frac(worst):
				worst = m
		if worst and _hp_frac(worst) < 0.9:
			_heal(worst, float(b.get("heal_pct", 0.2)))
			_beam_cd = float(b.get("cd", 10.0))

	# Контроль: заморозка ближайшего сталкера (Ледень)
	if aura.has("freeze") and _freeze_cd <= 0.0:
		var f: Dictionary = aura["freeze"]
		var st := _nearest_stalker(float(f.get("r", 8.0)))
		if st:
			st.set_meta("frozen_until", Time.get_ticks_msec() + int(float(f.get("t", 1.5)) * 1000.0))
			_freeze_cd = float(f.get("cd", 8.0))

	# Контроль: страх - оттолкнуть ближайшего сталкера (Гудень)
	if aura.has("fear") and _fear_cd <= 0.0:
		var fe: Dictionary = aura["fear"]
		var st2 := _nearest_stalker(float(fe.get("r", 6.0)))
		if st2:
			var push: float = float(fe.get("push", 3.0))
			var dir: Vector3 = (st2.global_position - owner_mutant.global_position)
			dir.y = 0.0
			if dir.length() > 0.1:
				st2.global_position += dir.normalized() * push
			_fear_cd = float(fe.get("cd", 8.0))


func _allies_in(r: float) -> Array:
	var out: Array = []
	for m in get_tree().get_nodes_in_group("mutants"):
		if is_instance_valid(m) and m != owner_mutant and m.global_position.distance_to(owner_mutant.global_position) <= r:
			out.append(m)
	return out


func _nearest_stalker(r: float) -> Node:
	var best: Node = null
	var best_d: float = r
	for s in get_tree().get_nodes_in_group("stalkers"):
		if not is_instance_valid(s):
			continue
		var dd: float = s.global_position.distance_to(owner_mutant.global_position)
		if dd < best_d:
			best_d = dd
			best = s
	return best


func _hp_frac(m) -> float:
	var mx: float = float(m.get("max_health")) if "max_health" in m else 100.0
	var cur: float = float(m.get("health")) if "health" in m else 100.0
	return cur / maxf(mx, 1.0)


func _heal(m, pct: float) -> void:
	if m.has_method("heal_hp"):
		m.heal_hp(float(m.get("max_health", 100.0)) * pct)
	elif "health" in m and "max_health" in m:
		m.health = minf(float(m.health) + float(m.max_health) * pct, float(m.max_health))


func _apply_buff(allies: Array, meta_key: String, pct: float) -> void:
	if pct <= 0.0:
		return
	for m in allies:
		var cur: float = float(m.get_meta(meta_key, 0.0))
		if cur >= pct:
			continue
		var stack_cap := float(MutantRoles.AURA_STACK_CAP)
		if cur + pct > pct * stack_cap:
			continue
		m.set_meta(meta_key, minf(cur + pct, pct * stack_cap))
		# снятие бафа через 1.2 с (тик 0.5 - баф поддерживается постоянно)
		var key := meta_key
		var timer := get_tree().create_timer(1.2)
		timer.timeout.connect(func():
			if is_instance_valid(m) and float(m.get_meta(key, 0.0)) <= pct:
				m.remove_meta(key))
