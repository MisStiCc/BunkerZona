extends Node
func _ready() -> void:
	await get_tree().create_timer(1.2).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data == null:
		gm.current_save_data = load("res://data/save_data.gd").new()
	var lab: Node = load("res://scenes/lab/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().create_timer(2.0).timeout
	lab._on_lab_storage_pressed()
	await get_tree().create_timer(0.3).timeout
	var sp: Node = lab._storage_panel
	print("STORAGE_SPAWNED=", sp != null)
	print("STORAGE_VISIBLE=", sp._root.visible if sp else false)
	print("STORAGE_HAS_LAYER=", sp.layer == 21 if sp else false)
	print("STORAGE_TEST_OK")
	gm.current_save_data = null
	get_tree().quit()
