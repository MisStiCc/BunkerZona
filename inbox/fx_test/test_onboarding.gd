extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	gm.current_save_data = load("res://data/save_data.gd").new()
	gm.current_save_data.onboarding_done = false
	var onb: CanvasLayer = load("res://ui/lab/onboarding_overlay.gd").new()
	add_child(onb)
	await get_tree().create_timer(0.2).timeout
	print("ONB_SHOWN=", onb._root.visible, " STEP=", onb._step)
	onb._advance()
	onb._advance()
	print("ONB_STEP2=", onb._step)
	onb._advance()
	print("ONB_DONE_FLAG=", gm.current_save_data.onboarding_done)
	print("ONB_TEST_", "OK" if gm.current_save_data.onboarding_done else "FAIL")
	gm.current_save_data = null
	get_tree().quit()
