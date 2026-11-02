extends Node

## Тест П1.5 security_audit: шифрование сейвов
## (game_manager._save_encrypted / _load_encrypted). Полигон — бросовый
## путь user://saves/_ciphertest.tres, реальные слоты владельца НЕ трогаются.
## Проверяет: файл на диске не открытый .tres, расшифровка даёт живой SaveData,
## открытый .tres читается как раньше (миграция), уборка за собой.
## Маркеры: CIPHER_SAVE / CIPHER_LOAD / CIPHER_PLAIN / CIPHER_TEST_PASS|FAIL.

const PATH := "user://saves/_ciphertest.tres"


func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		print("CIPHER_TEST_FAIL: нет game_manager")
		get_tree().quit()
		return
	var ok := true

	# 1) запись: файл на диске НЕ должен быть открытым .tres
	var sd: Resource = load("res://data/save_data.gd").new()
	sd.save_time = "cipher_test_7f"
	var written: bool = gm._save_encrypted(sd, PATH)
	if written:
		var raw := FileAccess.get_file_as_bytes(PATH)
		var plain: bool = raw.size() > 12 \
				and raw.slice(0, 12) == "[gd_resource".to_ascii_buffer()
		print("CIPHER_SAVE ", "PASS" if not plain else "FAIL(plaintext)")
		ok = ok and not plain
	else:
		print("CIPHER_SAVE FAIL(write)")
		ok = false

	# 2) чтение шифрованного: полноценный SaveData с нашими полями
	var back: Resource = gm._load_encrypted(PATH)
	var rt: bool = back != null and back is SaveData \
			and str(back.get("save_time")) == "cipher_test_7f"
	print("CIPHER_LOAD ", "PASS" if rt else "FAIL")
	ok = ok and rt

	# 3) миграция: открытый .tres читается как раньше
	var plain_written: bool = ResourceSaver.save(sd, PATH) == OK
	var back2: Resource = gm._load_encrypted(PATH) if plain_written else null
	var pl: bool = plain_written and back2 != null and back2 is SaveData \
			and str(back2.get("save_time")) == "cipher_test_7f"
	print("CIPHER_PLAIN ", "PASS" if pl else "FAIL")
	ok = ok and pl

	# уборка
	DirAccess.remove_absolute(PATH)
	DirAccess.remove_absolute(PATH.get_basename() + "_cipher.tres")
	print("CIPHER_TEST_", "PASS" if ok else "FAIL")
	get_tree().quit()
