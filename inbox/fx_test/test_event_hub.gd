extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	# Реальный gm с настоящим сейвом - как в лаборатории
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		if gm.current_save_data == null:
			gm.current_save_data = load("res://data/save_data.gd").new()
		if gm.has_method("get_lab_data") and gm.get_lab_data() == null:
			pass
		print("GM_SAVE_OK=", gm.current_save_data != null)
	var hub: Node = load("res://ui/events/event_hub.gd").new()
	add_child(hub)
	hub.open()
	print("EVENT_HUB_OPEN_OK")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
