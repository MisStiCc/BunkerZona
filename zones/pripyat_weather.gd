# zones/pripyat_weather.gd
extends Node
class_name PripyatWeather

## Погода Припяти (v0.31.2): радиоактивный дождь между волнами.
## Частицы следуют за камерой, гром - редкие раскатa, луп дождя на шине
## Ambient, реген энергии +25% пока льёт (дождь питает Зону). Ставится
## ZoneController только на карте pripyat;_roll на каждой передышке.

var _rain: GPUParticles3D = null
var _rain_player: AudioStreamPlayer = null
var _thunder_timer: Timer = null
var _stop_timer: Timer = null
var _regen_saved: float = -1.0
var _resource: Node = null
var _hud_notified: bool = false


func _ready() -> void:
	_thunder_timer = Timer.new()
	_thunder_timer.one_shot = true
	_thunder_timer.timeout.connect(_on_thunder)
	add_child(_thunder_timer)
	_stop_timer = Timer.new()
	_stop_timer.one_shot = true
	_stop_timer.timeout.connect(stop)
	add_child(_stop_timer)


## Зона зовёт на каждой передышке: бросок кубика на дождь
func roll_break() -> void:
	if _rain != null and _rain.emitting:
		return   # уже льёт
	if randf() < WeatherData.RAIN_CHANCE:
		start(lerpf(WeatherData.DURATION_MIN, WeatherData.DURATION_MAX, randf()))


func start(duration: float) -> void:
	if _rain != null and _rain.emitting:
		return
	_ensure_rain()
	_rain.emitting = true
	if not _hud_notified:
		_hud_notified = true
		_announce()
	# Звук: луп дождя на шине Ambient (отдельным плеером - эмбиент-ветер
	# занимает штатный AmbientPlayer)
	if _rain_player == null:
		var sm = get_tree().get_first_node_in_group("sound_manager")
		var stream: AudioStream = sm.ambient_sounds.get("rain_medium_01") if sm else null
		if stream != null:
			if stream is AudioStreamOggVorbis:
				stream.loop = true
			_rain_player = AudioStreamPlayer.new()
			_rain_player.stream = stream
			_rain_player.bus = "Ambient"
			_rain_player.volume_db = WeatherData.RAIN_VOLUME_DB
			add_child(_rain_player)
	if _rain_player:
		_rain_player.play()
	# Дождь питает Зону: реген энергии +25% (сохраняем прежнее значение)
	var zc = get_tree().get_first_node_in_group("zone_controller")
	_resource = zc.resource_manager if zc and zc.get("resource_manager") != null else get_tree().get_first_node_in_group("resource_manager")
	if _resource and "energy_regen_rate" in _resource and _regen_saved < 0.0:
		_regen_saved = _resource.energy_regen_rate
		_resource.energy_regen_rate = _regen_saved * WeatherData.REGEN_BONUS
	# Гром и таймер конца
	_on_thunder()
	_stop_timer.start(duration)


func stop() -> void:
	if _rain:
		_rain.emitting = false
	if _rain_player and _rain_player.playing:
		var tw := create_tween()
		tw.tween_property(_rain_player, "volume_db", -40.0, 2.0)
		tw.tween_callback(_rain_player.stop)
	_thunder_timer.stop()
	if _resource and _regen_saved >= 0.0:
		_resource.energy_regen_rate = _regen_saved
		_regen_saved = -1.0
		_resource = null


func _exit_tree() -> void:
	# Забег закрыт во время дождя - вернуть реген немедленно
	if _resource and _regen_saved >= 0.0:
		_resource.energy_regen_rate = _regen_saved
		_regen_saved = -1.0


func _on_thunder() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("thunder_far_01", randf_range(0.5, 0.8), randf_range(0.9, 1.1))
	_thunder_timer.start(randf_range(WeatherData.THUNDER_MIN_DELAY, WeatherData.THUNDER_MAX_DELAY))


func _announce() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_event_note"):
		hud.show_event_note({
			"title_ru": "РАДИОАКТИВНЫЙ ДОЖДЬ",
			"title_en": "RADIOACTIVE RAIN",
			"desc_ru": "Дождь питает Зону: реген энергии +25%, пока льёт.",
			"desc_en": "The rain feeds the Zone: +25% energy regen while it lasts.",
		})


func _ensure_rain() -> void:
	if _rain:
		return
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = 900
	_rain.lifetime = 1.1
	_rain.preprocess = 1.0
	var mat := ParticleProcessMaterial.new()
	# Короб над камерой: покрывает экран и на максимальном зуме
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(90, 4, 90)
	mat.gravity = Vector3(0, -26, 0)
	mat.initial_velocity_min = 2.0
	mat.initial_velocity_max = 5.0
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 2.0
	_rain.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.55)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.65, 0.8, 0.75, 0.35)
	quad.material = m
	_rain.draw_pass_1 = quad
	add_child(_rain)
	set_process(true)


func _process(_delta: float) -> void:
	if _rain == null or not _rain.emitting:
		return
	var cam := get_viewport().get_camera_3d()
	if cam:
		_rain.global_position = cam.global_position + Vector3(0, 26, 0)
