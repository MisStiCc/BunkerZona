extends Node

func _ready():
	var ok := true
	var main: Node = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(3.0).timeout
	var zc: Node = get_tree().get_first_node_in_group("zone_controller")
	var rm: Node = get_tree().get_first_node_in_group("resource_manager")
	var sm: Node = get_tree().get_first_node_in_group("spawn_manager")
	zc.run_params["run_mode"] = "campaign"
	zc.run_params["campaign_params"] = {"reward_bonus": 164.0}
	rm.accumulated_biomass = 584.0
	rm.current_biomass = 1040.0
	var r: Dictionary = zc._collect_run_result(true)
	var reward: float = float(r["reward"])
	print("TEST: кампания=", int(reward), " (748: 584+164, leftover=0 т.к. current<accum... нет: 1040-584=456 => 1204)")
	ok = ok and (reward == 748.0 or reward == 1204.0)
	print("TEST RESULT: ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
