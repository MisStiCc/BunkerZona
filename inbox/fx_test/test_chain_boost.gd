extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	# ФРЕШ сейв (не владельческий!). ВНИМАНИЕ: apply/save_to_active_slot
	# перезапишет save_0/1.tres - shell-обёртка бэкапит и восстанавливает их
	gm.current_save_data = load("res://data/save_data.gd").new()
	var lab = gm.get_lab_data()
	# Сценарий владельца: химера 3★ (цель), чужих 3★ НЕТ,
	# но болотник 2★ с копиями -> его можно дорастить до корма
	lab.unlocked_mutants.append("chimera"); lab.mutant_stars["chimera"] = 3; lab.farm_copies["chimera"] = 0
	lab.unlocked_mutants.append("zombie"); lab.mutant_stars["zombie"] = 2; lab.farm_copies["zombie"] = 10
	lab.unlocked_mutants.append("dog_mutant"); lab.mutant_stars["dog_mutant"] = 1; lab.farm_copies["dog_mutant"] = 12
	lab.unlocked_mutants.append("flesh"); lab.mutant_stars["flesh"] = 1; lab.farm_copies["flesh"] = 6
	print("SCAN_BEFORE=", gm.can_auto_boost("chimera"))
	print("PRE: zombie=", lab.get_mutant_stars("zombie"), "x", lab.get_farm_copies("zombie"), " dog=", lab.get_mutant_stars("dog_mutant"), "x", lab.get_farm_copies("dog_mutant"), " chimera_feed_bak=", lab.get_star_feed("chimera"))
	var msg: String = gm.auto_boost("chimera")
	gm.current_save_data = null   # не сейвить свежак в слот владельца
	print("FEED_TRACE msg=", msg)
	print("APPLY=", msg)
	print("CHIMERA_STARS=", lab.get_mutant_stars("chimera"), " (ожидал 4)")
	print("ZOMBIE_STARS=", lab.get_mutant_stars("zombie"), " LEFT=", lab.get_farm_copies("zombie"))
	print("DOG_LEFT=", lab.get_farm_copies("dog_mutant"), " FLESH_LEFT=", lab.get_farm_copies("flesh"))
	var ok: bool = msg.begins_with("ЗВЕЗДА") and lab.get_mutant_stars("chimera") == 4
	print("CHAIN_BOOST_TEST_", "OK" if ok else "FAIL")
	get_tree().quit()
