extends Node3D
## Контроллер эффекта Выброса Зоны.
## start() — запуск (волна, пепел, искры, столбы света); set_intensity(x) 0..1 —
## сила эффекта (небо/волна/столбы), нарастание/спад делает игра; stop() — погасить.
## Кольцо ударной волны едет само по времени от start() до края арены.

@export var wave_time := 2.4          # сек фронта до края арены
@export var echo_delay := 0.55        # задержка второго кольца-эха
@export var pillars_count := 6        # столбов света (5-8)
@export var pillar_radius_min := 45.0
@export var pillar_radius_max := 140.0
@export var pillar_min_height := 55.0
@export var pillar_max_height := 95.0
@export var ash_spread_time := 4.5    # за сколько облако пепла разъедется на всю арену
@export var sky_gain := 1.15          # множитель интенсивности неба

@onready var sky_mat: ShaderMaterial = $SkyDome.material_override
@onready var ring_mat: ShaderMaterial = $Shockwave.material_override
@onready var echo_mat: ShaderMaterial = $ShockwaveEcho.material_override
@onready var pillar_template: MeshInstance3D = $Pillars/PillarTemplate
@onready var pillars_root: Node3D = $Pillars
@onready var ash: GPUParticles3D = $Ash
@onready var sparks: GPUParticles3D = $Sparks
@onready var core_light: OmniLight3D = $CoreLight

var _time := 0.0
var _running := false
var _intensity := 0.0
var _pillar_mats: Array[ShaderMaterial] = []


func start() -> void:
	## Запуск Выброса: волна пошла от Монолита (origin сцены = центр).
	_time = 0.0
	_running = true
	_place_pillars()
	ash.scale = Vector3(0.3, 0.35, 0.3)
	ash.restart()
	sparks.restart()
	_apply_intensity()


func set_intensity(x: float) -> void:
	## Сила эффекта 0..1: небо, кольцо, столбы, свет, пепел. Вызывает игра.
	_intensity = clampf(x, 0.0, 1.0)
	_apply_intensity()


func stop() -> void:
	## Погасить всё и убрать столбы. Волна при следующем start() начнётся заново.
	_running = false
	_intensity = 0.0
	_apply_intensity()
	ash.emitting = false
	sparks.emitting = false
	_clear_pillars()


func _process(delta: float) -> void:
	if not _running:
		return
	_time += delta

	# фронт волны: 0 → 1.0 (край арены), яркость падает с расстоянием
	var pos := clampf(_time / wave_time, 0.0, 1.05)
	ring_mat.set_shader_parameter("ring_pos", pos)
	ring_mat.set_shader_parameter("intensity", _intensity * (1.0 - 0.72 * pow(clampf(pos, 0.0, 1.0), 0.7)))

	# эхо-кольцо: позже, слабее, медленнее
	var e_time := _time - echo_delay
	if e_time > 0.0:
		var e_pos := clampf(e_time / (wave_time * 1.35), 0.0, 1.05)
		echo_mat.set_shader_parameter("ring_pos", e_pos)
		echo_mat.set_shader_parameter("intensity", _intensity * 0.45 * (1.0 - 0.8 * clampf(e_pos, 0.0, 1.0)))
	else:
		echo_mat.set_shader_parameter("ring_pos", 0.0)
		echo_mat.set_shader_parameter("intensity", 0.0)

	# пепел разъезжается наружу от Монолита (масштаб узла при local_coords)
	var spread := clampf(_time / ash_spread_time, 0.0, 1.0)
	var s := lerpf(0.3, 1.0, spread)
	ash.scale = Vector3(s, maxf(0.35, s * 0.5), s)


func _apply_intensity() -> void:
	sky_mat.set_shader_parameter("intensity", _intensity * sky_gain)
	core_light.light_energy = _intensity * 7.0
	for mat in _pillar_mats:
		mat.set_shader_parameter("intensity", _intensity * 1.3)
	ash.emitting = _intensity > 0.02 and _running
	sparks.emitting = _intensity > 0.1 and _running


func _place_pillars() -> void:
	_clear_pillars()
	var base_mat := pillar_template.material_override as ShaderMaterial
	for i in pillars_count:
		var p: MeshInstance3D = pillar_template.duplicate()
		var mat := base_mat.duplicate() as ShaderMaterial
		mat.set_shader_parameter("seed", float(i) * 3.7 + randf() * 2.0)
		mat.set_shader_parameter("intensity", _intensity * 1.3)
		p.material_override = mat
		_pillar_mats.append(mat)
		var ang := TAU * float(i) / float(pillars_count) + randf_range(-0.35, 0.35)
		var radius := randf_range(pillar_radius_min, pillar_radius_max)
		var h := randf_range(pillar_min_height, pillar_max_height)
		p.position = Vector3(cos(ang) * radius, h * 0.5, sin(ang) * radius)
		p.scale = Vector3(randf_range(0.8, 1.5), h, randf_range(0.8, 1.5))
		p.visible = true
		pillars_root.add_child(p)


func _clear_pillars() -> void:
	_pillar_mats.clear()
	for child in pillars_root.get_children():
		if child == pillar_template:
			continue
		child.queue_free()
