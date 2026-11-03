extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	print("GM=", gm != null)
	# РЕАЛЬНЫЙ сейв владельца с диска
	var save = load("user://saves/save_0.tres")
	print("SAVE_LOADED=", save != null, " CLASS=", save.get_class() if save else "?")
	if gm and save:
		gm.current_save_data = save
	var hub: Node = load("res://ui/events/event_hub.gd").new()
	add_child(hub)
	print("HUB_BEFORE_OPEN")
	hub.open()
	print("HUB_OPEN_OK")
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()
