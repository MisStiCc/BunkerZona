extends Node
var lab: Node = null
func _ready() -> void:
	await get_tree().create_timer(1.2).timeout
	lab = load("res://scenes/lab/lab.tscn").instantiate()
	add_child(lab)
	await get_tree().create_timer(2.0).timeout
	var btn: Button = lab.find_child("EventButton", true, false)
	print("BTN_FOUND=", btn != null)
	if btn == null:
		get_tree().quit(); return
	print("BTN_POS=", btn.get_global_rect())
	lab._on_event_pressed()
	await get_tree().create_timer(0.6).timeout
	var hub = lab.get("_event_hub")
	print("HANDLER_FIRED=", hub != null)
	if hub:
		print("HUB_VISIBLE=", hub._root.visible)
	get_tree().quit()
