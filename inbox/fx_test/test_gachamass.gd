extends Node
func _ready() -> void:
	await get_tree().create_timer(1.2).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	gm.current_save_data = load("res://data/save_data.gd").new()
	var gacha: Node = load("res://scenes/ui/gacha.tscn").instantiate()
	add_child(gacha)
	await get_tree().create_timer(0.5).timeout
	var ctrl: Node = gacha
	# контроллер на корне сцены
	if ctrl.get_script() == null or str(ctrl.get_script().resource_path).find("gacha_controller") < 0:
		for ch in gacha.get_children():
			if ch.get_script() and str(ch.get_script().resource_path).find("gacha_controller") >= 0:
				ctrl = ch
				break
	print("CTRL_FOUND=", ctrl != null)
	var lab = gm.get_lab_data()
	for arm in ["mutants", "artifacts", "super"]:
		ctrl._arm = arm
		var before_rolls: int = lab.gacha_rolls_mutants if arm == "mutants" else (lab.gacha_rolls_artifacts if arm == "artifacts" else lab.super_pulls)
		ctrl._on_mass_spin()
		await get_tree().create_timer(0.2).timeout
		var after: int = lab.gacha_rolls_mutants if arm == "mutants" else (lab.gacha_rolls_artifacts if arm == "artifacts" else lab.super_pulls)
		print("MASS ", arm, " rolls_before=", before_rolls, " after=", after)
	print("GACHA_MASS_TEST_OK")
	gm.current_save_data = null
	get_tree().quit()
