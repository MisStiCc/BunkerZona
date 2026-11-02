extends Node
func _ready() -> void:
	await get_tree().create_timer(0.8).timeout
	var chim: Node = load("res://entities/mutants/chimera.tscn").instantiate()
	add_child(chim)
	await get_tree().create_timer(0.6).timeout
	var model: Node = chim.get_node_or_null("Model")
	var players := model.find_children("*", "AnimationPlayer", true, false) if model else []
	print("ANIM_PLAYERS=", players.size())
	if players.size() > 0:
		var ap: AnimationPlayer = players[0]
		var names := ap.get_animation_list()
		print("CLIPS=", ", ".join(names))
		print("HAS_WALK=", ap.has_animation("walk"), " HAS_GALLOP=", ap.has_animation("gallop"))
	print("PROC_SKELETON_NULL=", chim.get("_skeleton") == null)
	get_tree().quit()
