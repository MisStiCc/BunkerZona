extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.current_save_data == null:
		gm.current_save_data = load("res://data/save_data.gd").new()
	var vp := Vector2(1920, 1080)
	var ok := true
	# 1) хаб: видим + размер
	var hub: Node = load("res://ui/events/event_hub.gd").new()
	add_child(hub)
	hub.open()
	await get_tree().create_timer(0.2).timeout
	var vis: bool = hub.visible
	var sz: Vector2 = hub.size
	print("HUB vis=", vis, " size=", sz)
	ok = ok and vis and sz.x > 1000.0
	hub.close()
	await get_tree().create_timer(0.1).timeout
	print("HUB_REOPEN_CLOSED=", not hub.visible)
	hub.open()
	await get_tree().create_timer(0.1).timeout
	ok = ok and hub.visible
	# 2) почта
	var mail: Node = load("res://ui/lab/mail_overlay.gd").new()
	add_child(mail)
	mail.open()
	await get_tree().create_timer(0.2).timeout
	print("MAIL vis=", mail.visible, " size=", mail.size)
	ok = ok and mail.visible and mail.size.x > 1000.0
	mail.close()
	# 3) 6 мини-игр фуллскрин
	for g in ["game_zharva", "game_uley", "game_labyrinth", "game_chain", "game_vault", "game_bolts"]:
		var game: Node = load("res://ui/events/%s.gd" % g).new()
		add_child(game)
		await get_tree().create_timer(0.15).timeout
		var gv: bool = game.visible
		var gs: Vector2 = game.size
		print("GAME ", g, " vis=", gv, " size=", gs)
		ok = ok and gv and gs.x > 1000.0
		game.queue_free()
		await get_tree().create_timer(0.05).timeout
	# 4) календарь охоты: видим + имеет размер (скрин юзера: текст в кашу)
	var cal: Node = load("res://ui/lab/hunt_calendar.gd").new()
	add_child(cal)
	cal.open()
	await get_tree().create_timer(0.2).timeout
	var cal_root: Control = cal._root
	print("CAL vis=", cal_root.visible, " size=", cal_root.size)
	ok = ok and cal_root.visible and cal_root.size.x > 500.0
	cal.close()
	print("REGRESS_V0331_", "OK" if ok else "FAIL")
	get_tree().quit()

func _check_calendar() -> void:
	pass
