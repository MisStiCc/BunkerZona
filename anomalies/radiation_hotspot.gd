extends BaseAnomaly
class_name RadiationHotspot

@export var radiation_radius: float = 6.0
@export var radiation_color: Color = Color(0.3, 1, 0.3, 1)
@export var radiation_damage: float = 14.0


func _ready():
	anomaly_type = "radiation_hotspot"
	difficulty_level = 2
	damage_per_second = radiation_damage

	super._ready()
	_update_size()
	_update_color()
	_setup_geiger()


## Позиционный треск дозиметра (задача 15, недостроенный звук эмбиента):
## слышен при приближении к аномалии, громкость и радиус слышимости по зоне
func _setup_geiger():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	var stream: AudioStream = sm.ambient_sounds.get("geiger_loop") if sm else null
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var p := AudioStreamPlayer3D.new()
	p.name = "Geiger"
	p.stream = stream
	p.unit_size = 14.0
	p.max_db = -6.0
	p.volume_db = -10.0
	p.autoplay = true
	add_child(p)


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = radiation_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = radiation_radius
		mesh.mesh.height = radiation_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = radiation_color
		mesh.material_override.emission = radiation_color
