extends Node
func _ready() -> void:
	await get_tree().create_timer(1.2).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	gm.current_save_data = load("res://data/save_data.gd").new()
	var g: Node = load("res://scenes/lab/lab.tscn").instantiate()
	add_child(g)
	await get_tree().create_timer(2.0).timeout
	# вкладка МАГАЗИН гильдии
	g._on_guild_pressed()
	await get_tree().create_timer(0.4).timeout
	var overlay: Node = g._guild_overlay
	print("OVERLAY=", overlay != null)
	if overlay == null:
		get_tree().quit(); return
	overlay._page = 3  # МАГАЗИН
	overlay._refresh()
	await get_tree().create_timer(0.4).timeout
	# во вкладке: фон + баннер + карточки с рамкой
	var found_bg := false
	var found_banner := false
	for ch in overlay._root.find_children("*", "TextureRect", true, false):
		if ch.texture and str(ch.texture.resource_path).find("guild_shop_bg") >= 0:
			found_bg = true
		if ch.texture and str(ch.texture.resource_path).find("guild_shop_banner") >= 0:
			found_banner = true
	print("SHOP_BG=", found_bg, " BANNER=", found_banner)
	print("GUILD_SHOP_TEST_OK")
	gm.current_save_data = null
	get_tree().quit()
