extends Node3D
## Съёмка одного эффекта anomaly_fx в PNG. Запуск:
##   godot --path <проект> res://inbox/fx_test/capture.tscn -- <путь_сцены> <путь_png>

@onready var cam: Camera3D = $Camera3D


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path := args[0] if args.size() > 0 else 'res://anomaly_fx/scenes/fx_electra.tscn'
	var out_path := args[1] if args.size() > 1 else 'C:/tmp/fx_shot.png'
	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_error('не грузится сцена: ' + scene_path)
		get_tree().quit(1)
		return
	var fx := packed.instantiate()
	add_child(fx)
	if args.size() > 2:
		fx.scale = Vector3.ONE * float(args[2])
	cam.look_at(Vector3(0, 1.6, 0))
	# дать шейдерам скомпилироваться, партиклам — народиться
	await get_tree().create_timer(1.4).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(out_path)
	print('снято: ', out_path, ' ', img.get_size())
	get_tree().quit(0)
