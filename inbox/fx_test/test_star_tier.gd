extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm.current_save_data == null:
		gm.current_save_data = load("res://data/save_data.gd").new()
	var lab = gm.get_lab_data()
	# Сценарий: цель 2★, своих копий 0, но чужие 2★ есть
	lab.unlocked_mutants.append("chimera")
	lab.mutant_stars["chimera"] = 2
	lab.farm_copies["chimera"] = 0
	lab.unlocked_mutants.append("zombie")
	lab.mutant_stars["zombie"] = 2
	lab.farm_copies["zombie"] = 3   # чужие той же ★
	lab.unlocked_mutants.append("dog_mutant")
	lab.mutant_stars["dog_mutant"] = 1
	lab.farm_copies["dog_mutant"] = 10  # простой корм 1★
	lab.unlocked_mutants.append("flesh")
	lab.mutant_stars["flesh"] = 2
	lab.farm_copies["flesh"] = 1   # звёздный корм 2★
	var req: Dictionary = gm.get_star_requirements("chimera")
	print("TIER_POOL=", req.get("tier_copies_have"), " NEED=", req.get("copies_need"), " READY=", req.get("ready"))
	# Простой корм до потребности (2★ = 4 по 2/4/6/8)
	while lab.get_star_progress("chimera") < 4:
		lab.consume_farm_copy("dog_mutant")
		lab.add_star_progress("chimera", 1)
	# Рецепт: 0 своих копий + 2 чужих (zombie), звёздный корм - zombie (2★)
	var msg: String = gm.apply_star_recipe("chimera", 0, "flesh", {}, {"zombie": 3})
	print("APPLY=", msg)
	print("CHIMERA_STARS=", lab.get_mutant_stars("chimera"))
	print("ZOMBIE_LEFT=", lab.get_farm_copies("zombie"))
	var ok: bool = lab.get_mutant_stars("chimera") == 3 and lab.get_farm_copies("zombie") == 0 and lab.get_farm_copies("flesh") == 0 and lab.get_farm_copies("chimera") == 0
	print("STAR_TIER_TEST_", "OK" if ok else "FAIL")
	get_tree().quit()
