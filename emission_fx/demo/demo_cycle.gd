extends Node3D
## Демо-цикл Выброса: нарастание 1.5 с -> плато -> спад 2 с -> пауза, повтор.
## Ничего из игры не тянет: пол, заглушка Монолита, эффект, камера.

@export var ramp_up := 1.5
@export var hold := 1.6
@export var ramp_down := 2.0
@export var pause := 2.5

@onready var fx: Node3D = $EmissionFX
@onready var cam: Camera3D = $Camera3D

var _phase := 0
var _t := 0.0


func _ready() -> void:
	cam.look_at(Vector3(0, 10, 0))
	fx.start()


func _process(delta: float) -> void:
	_t += delta
	match _phase:
		0:  # нарастание
			fx.set_intensity(clampf(_t / ramp_up, 0.0, 1.0))
			if _t >= ramp_up:
				_next()
		1:  # плато
			fx.set_intensity(1.0)
			if _t >= hold:
				_next()
		2:  # спад
			fx.set_intensity(1.0 - clampf(_t / ramp_down, 0.0, 1.0))
			if _t >= ramp_down:
				fx.stop()
				_next()
		3:  # пауза
			if _t >= pause:
				fx.start()
				_next()


func _next() -> void:
	_phase = (_phase + 1) % 4
	_t = 0.0
