extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	gm.current_save_data = load("res://data/save_data.gd").new()
	# PAR-кривая: очки PAR дают PAR_SHARDS у каждой игры
	var games := {"zharva": 5000, "uley": 1500, "labyrinth": 1800, "chain": 600, "vault": 2000, "bolts": 1400}
	var ok := true
	for g in games:
		var sh: int = EventsData.shards_for(str(g), int(games[g]))
		print("PAR ", g, " -> ", sh, " shards")
		if sh != 12:
			ok = false
	# дневной кап: 3 партии Жатвы по 5000 = 36+36+36... кап 120 достигается за ~10
	var save = gm.current_save_data
	var ev: Dictionary = {"id": "zharva", "base": "zharva", "mult": 1.0}
	var total := 0
	for i in range(12):
		total += EventOps.add_score(save, ev, 5000)
	var es: Dictionary = EventOps.state(save)
	print("DAILY_TOTAL=", total, " CAP=", EventsData.DAILY_SHARD_CAP, " TODAY=", es.get("shards_today"))
	print("PAR_TEST_", "OK" if ok else "FAIL")
	gm.current_save_data = null
	get_tree().quit()
