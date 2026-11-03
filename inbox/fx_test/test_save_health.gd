extends Node
func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	for slot in [0, 1, 2]:
		var path := "user://saves/save_%d.tres" % slot
		if not FileAccess.file_exists(path):
			print("SLOT ", slot, ": missing")
			continue
		var s = load(path)
		if s == null:
			print("SLOT ", slot, ": CORRUPT (load null)")
			continue
		var lab = s.get("lab_data")
		var ok := lab != null
		print("SLOT ", slot, ": OK class=", s.get_class(), " lab=", ok, " biomass=", int(lab.biomass) if ok else -1)
	get_tree().quit()
