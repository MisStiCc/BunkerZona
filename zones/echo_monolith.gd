# zones/echo_monolith.gd
extends Node3D
class_name EchoMonolith

## Эхо Монолита (D20): доп. рубеж обороны. Ставится в подготовке кистью ЭХО.
## Узел в группе "monolith" - сталкеры сами выбирают ближайший рубеж и бьют
## его. Пал (HP 0) - исключается из группы, его пачка отступает к соседнему.

signal fallen(echo: EchoMonolith)

var echo_hp: float = 1500.0
var echo_max_hp: float = 1500.0
var _hp_label: Label3D = null
var _body: MeshInstance3D = null
var _fallen: bool = false


func _ready() -> void:
	add_to_group("monolith")
	add_to_group("echo_fronts")
	set_meta("is_echo", true)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.2
	cap.height = 5.0
	col.shape = cap
	col.position.y = 2.5
	add_child(col)

	_body = MeshInstance3D.new()
	var obelisk := CylinderMesh.new()
	obelisk.top_radius = 0.25
	obelisk.bottom_radius = 0.9
	obelisk.height = 5.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.10, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.70, 0.40, 1.00)
	mat.emission_energy_multiplier = 0.8
	_body.mesh = obelisk
	_body.material_override = mat
	_body.position.y = 2.5
	add_child(_body)

	_hp_label = Label3D.new()
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.font_size = 40
	_hp_label.pixel_size = 0.01
	_hp_label.modulate = Color(0.85, 0.6, 1.0)
	_hp_label.outline_size = 8
	_hp_label.position.y = 6.0
	_hp_label.text = "ЭХО"
	add_child(_hp_label)


func setup(cycle: int) -> void:
	echo_max_hp = 1200.0 + 800.0 * float(maxi(cycle, 1) - 1)
	echo_hp = echo_max_hp
	_update_label()


func take_damage(amount: float, _source = null) -> void:
	if _fallen:
		return
	echo_hp -= float(amount)
	if echo_hp <= 0.0:
		_fall()
		return
	_update_label()


func _update_label() -> void:
	if _hp_label:
		_hp_label.text = "ЭХО %d%%" % int(100.0 * echo_hp / maxf(echo_max_hp, 1.0))


func _fall() -> void:
	_fallen = true
	remove_from_group("monolith")
	remove_from_group("echo_fronts")
	if _hp_label:
		_hp_label.text = "ЭХО ПАЛО"
	if _body:
		var mat := _body.material_override as StandardMaterial3D
		if mat:
			mat.emission_energy_multiplier = 0.1
			mat.albedo_color = Color(0.1, 0.1, 0.12)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.4, 0.1, 0.4), 0.8).set_trans(Tween.TRANS_QUAD)
	fallen.emit(self)


func is_fallen() -> bool:
	return _fallen
