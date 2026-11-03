extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var path := "user://saves/save_0.tres"
	print("EXISTS=", FileAccess.file_exists(path))
	print("RL_EXISTS=", ResourceLoader.exists(path))
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("_load_encrypted"):
		var r = gm._load_encrypted(path)
		print("GM_LOAD=", r != null, " class=", r.get_class() if r else "-")
		if r:
			var lab = r.get("lab_data")
			print("BIOMASS=", int(lab.biomass) if lab else -1)
	else:
		var r2 = load(path)
		print("RAW_LOAD=", r2 != null)
	get_tree().quit()
