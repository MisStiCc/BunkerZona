extends BaseAnomaly
class_name GravityLift

@export var lift_radius: float = 4.0
@export var lift_color: Color = Color(0.5, 0, 1, 1)
@export var lift_force: float = 8.0
@export var lift_height: float = 20.0


func _ready():
	anomaly_type = "gravity_lift"
	difficulty_level = 2
	damage_per_second = 8.0
	
	super._ready()
	_update_size()
	_update_color()


func _update_size():
	var collision = $CollisionShape3D
	if collision and collision.shape:
		collision.shape.radius = lift_radius
	
	var mesh = $MeshInstance3D
	if mesh and mesh.mesh:
		mesh.mesh.radius = lift_radius
		mesh.mesh.height = lift_radius * 2


func _update_color():
	var mesh = $MeshInstance3D
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = lift_color
		mesh.material_override.emission = lift_color


func _physics_process(delta):
	# D10: лифт глушит парение летающих мутантов в зоне - их тянет вниз
	for m in get_tree().get_nodes_in_group("mutants"):
		if is_instance_valid(m) and m.has_method("suppress_hover") \
				and m.global_position.distance_to(global_position) <= lift_radius:
			m.suppress_hover(1.0)
	
	for stalker in stalkers_in_zone:
		if is_instance_valid(stalker):
			stalker.global_position.y += lift_force * delta
			if stalker.global_position.y > lift_height:
				stalker.global_position.y = lift_height
