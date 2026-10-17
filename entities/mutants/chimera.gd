# entities/mutants/chimera.gd
extends BaseMutant
class_name ChimeraMutant

@export var is_night_only: bool = false
@export var leap_distance: float = 15.0
@export var leap_damage: float = 50.0
@export var secondary_head_damage: float = 10.0

var can_leap: bool = true
var leap_timer: Timer
var is_leaping: bool = false
var leap_target: Vector3
var leap_time: float = 0.0
var _leap_from: Vector3 = Vector3.ZERO
var _leap_vx: float = 0.0
var _leap_vy: float = 0.0
var _leap_vz: float = 0.0
var _leap_t_total: float = 0.0

func _ready():
	health = 250.0
	max_health = 250.0
	speed = 10.0
	damage = 30.0
	armor = 25.0
	biomass_cost = 200.0
	mutant_type = "chimera"
	
	# Целевая высота модели: нормализация по AABB в base_mutant
	model_target_height = 1.5
	super._ready()
		
	leap_timer = Timer.new()
	leap_timer.one_shot = true
	leap_timer.wait_time = 4.0
	leap_timer.timeout.connect(_on_leap_cooldown_ended)
	add_child(leap_timer)
	
	_setup_label()
	# "Chimera mutant initialized"  # (лог отключён)


func _physics_process(delta):
	if current_state == State.DEAD:
		return
	
	if is_leaping:
		_handle_leap(delta)
		return
	
	super._physics_process(delta)


func _find_new_target():
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	var nearest = null
	var nearest_dist = INF
	
	for s in stalkers:
		if is_instance_valid(s):
			var dist = global_position.distance_to(s.global_position)
			if dist < detection_radius * 2 and dist < nearest_dist:
				nearest_dist = dist
				nearest = s
	
	if nearest:
		target_stalker = nearest
		current_state = State.CHASE


func _patrol(delta):
	_find_new_target()
	super._patrol(delta)


func _chase(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		_find_new_target()
		if not target_stalker:
			current_state = State.PATROL
			return
	
	# Поводок: прыжки за жертвой через всю карту запрещены
	if _spawn_position.distance_to(global_position) > leash_radius:
		target_stalker = null
		current_state = State.PATROL
		# "Химера: добыча увела от территории, возврат"  # (лог отключён)
		return
	
	# Застрял у дома - прыжок прямо через препятствие (кинематика проходит сквозь)
	if can_leap and not is_leaping and _stuck_time > 1.5:
		var stuck_dist: float = global_position.distance_to(target_stalker.global_position)
		if stuck_dist > 3.0 and stuck_dist < 30.0:
			_start_leap()
			return
	
	var direction = (target_stalker.global_position - global_position).normalized()
	velocity = direction * speed
	
	if can_leap and not is_leaping:
		var dist = global_position.distance_to(target_stalker.global_position)
		if dist < leap_distance and dist > 5.0:
			_start_leap()
	
	if global_position.distance_to(target_stalker.global_position) < 2.5:
		current_state = State.ATTACK


func _start_leap():
	if not target_stalker or not is_instance_valid(target_stalker):
		return
	
	# "Chimera: прыгаю!"  # (лог отключён)
	is_leaping = true
	can_leap = false
	leap_target = target_stalker.global_position
	leap_time = 0.0
	
	# КИНЕМАТИЧЕСКИЙ прыжок на попадание: позиция - функция времени.
	# Низкая дуга: T короткий, пик = g*T^2/8; посадка ровно на цель в момент T.
	var to_target = leap_target - global_position
	var flat_dist = Vector2(to_target.x, to_target.z).length()
	_leap_t_total = max(flat_dist / (speed * 2.0), 0.35)
	_leap_from = global_position
	_leap_vx = to_target.x / _leap_t_total
	_leap_vz = to_target.z / _leap_t_total
	_leap_vy = (to_target.y - global_position.y) / _leap_t_total + 0.5 * gravity * _leap_t_total
	velocity = Vector3.ZERO
	
	leap_timer.start()


func _handle_leap(delta):
	leap_time += delta
	var t = min(leap_time, _leap_t_total)
	
	# Кинематика параболы - физика в полёте не участвует,
	# траекторию никто не перезапишет:
	# x(t) = x0 + vx*t; y(t) = y0 + vy0*t - g*t^2/2
	var pos = _leap_from
	pos.x += _leap_vx * t
	pos.z += _leap_vz * t
	pos.y += _leap_vy * t - 0.5 * gravity * t * t
	global_position = pos
	velocity = Vector3.ZERO
	
	# Нос по дуге: вверх на взлёте, вниз на падении
	var model := get_node_or_null("Model")
	if model:
		var vy: float = _leap_vy - gravity * t
		model.rotation.x = clampf(vy * 0.05, -0.35, 0.35)
	
	if leap_time >= _leap_t_total:
		global_position.y = max(global_position.y, leap_target.y)
		_land()


func _land():
	# "Chimera: приземлился!"  # (лог отключён)
	is_leaping = false
	
	var stalkers = get_tree().get_nodes_in_group("stalkers")
	for stalker in stalkers:
		if is_instance_valid(stalker):
			var dist = global_position.distance_to(stalker.global_position)
			if dist < 5.0:
				stalker.take_damage(leap_damage, self)
				attacked_stalker.emit(stalker)
	
	_find_new_target()


func _on_leap_cooldown_ended():
	can_leap = true


func _attack(_delta):
	if not target_stalker or not is_instance_valid(target_stalker):
		current_state = State.PATROL
		return
	
	var dist = global_position.distance_to(target_stalker.global_position)
	if dist > 3.0:
		current_state = State.CHASE
		return
	
	if attack_timer.is_stopped():
		target_stalker.take_damage(damage, self)
		
		await get_tree().create_timer(0.3).timeout
		if is_instance_valid(target_stalker):
			target_stalker.take_damage(secondary_head_damage, self)
			attacked_stalker.emit(target_stalker)
		
		attack_timer.start()
		# "Chimera атакует!"  # (лог отключён)


func _setup_label():
	var label = Label3D.new()
	label.name = "MutantLabel"
	label.position = Vector3(0, 3.5, 0)  # Выше, потому что химера большая
	label.font_size = 28
	label.outline_size = 2
	label.outline_modulate = Color.BLACK
	label.modulate = Color(0.8, 0.2, 0.8)  # фиолетовый
	label.text = "🦎 ХИМЕРА"
	add_child(label)

