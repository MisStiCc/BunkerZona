extends Node
var lab: Node = null
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	# фреш сейв (владельческий перезапишется - shell-бэкап вокруг прогона)
	gm.current_save_data = load("res://data/save_data.gd").new()
	gm.current_save_data.onboarding_done = false
	lab = load("res://scenes/lab/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().create_timer(2.0).timeout
	var onb: Node = null
	for ch in lab.get_children():
		if ch is OnboardingOverlay:
			onb = ch
	print("SPAWNED=", onb != null, " STEP=", onb._step_id if onb else "-")
	if onb == null:
		get_tree().quit(); return
	print("FRAME_BARS=", onb._frame.size())
	# welcome завершается стартом забега -> saved=anomaly
	lab._on_start_run_pressed()
	await get_tree().create_timer(0.2).timeout
	print("SAVED_AFTER_START=", str(gm.current_save_data.onboarding_step))
	# чужой хост в лабе не каскадит: saved остаётся anomaly
	await get_tree().create_timer(0.3).timeout
	print("SAVED_STABLE=", str(gm.current_save_data.onboarding_step))
	print("ONB_LAB_TEST_OK")
	gm.current_save_data = null
	get_tree().quit()
