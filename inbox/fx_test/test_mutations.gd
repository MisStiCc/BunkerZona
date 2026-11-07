extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	# активация: цикл 1 чистый, 2+ мутации, детерминизм, антагонисты
	print("CYCLE1=", ZoneMutations.active_for_cycle(1).size())
	var c2 := ZoneMutations.active_for_cycle(2)
	var c2b := ZoneMutations.active_for_cycle(2)
	print("CYCLE2=", c2.size(), " DETERM=", c2 == c2b, " ", ", ".join(c2))
	var c5 := ZoneMutations.active_for_cycle(5)
	print("CYCLE5=", c5.size())
	# антагонисты не вместе
	var bad := false
	for cyc in range(2, 30):
		var acts := ZoneMutations.active_for_cycle(cyc)
		for pair in ZoneMutations.ANTAGONISTS:
			if acts.has(pair[0]) and acts.has(pair[1]):
				bad = true
	print("ANTAGONIST_OK=", not bad)
	# известные id существуют
	var known := true
	for cyc in range(2, 40):
		for m in ZoneMutations.active_for_cycle(cyc):
			if not ZoneMutations.MUTATIONS.has(m):
				known = false
	print("IDS_KNOWN=", known)
	print("MUTATIONS_TEST_", "OK" if (ZoneMutations.active_for_cycle(1).size() == 0 and c2.size() >= 2 and not bad and known) else "FAIL")
	get_tree().quit()
