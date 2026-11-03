extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data == null:
		gm.current_save_data = load("res://data/save_data.gd").new()
	var hub: Node = load("res://ui/events/event_hub.gd").new()
	add_child(hub)
	hub.open()
	await get_tree().create_timer(0.3).timeout
	# Тест-стенд: 6 кнопок с текстом "▶ " в _list
	var found := 0
	var names := []
	for c in hub._list.get_children():
		if c is Button and c.text.begins_with("▶"):
			found += 1
			names.append(c.text)
	print("TEST_STAND_BUTTONS=", found, " ", ", ".join(names))
	print("TEST_STAND_TEST_", "OK" if found == 6 else "FAIL")
	get_tree().quit()
