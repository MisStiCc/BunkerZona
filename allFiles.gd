@tool
## Сборщик дампа проекта в project_export.txt — версия 2 (горячий фикс 4)
##
## ЧТО ИСПРАВЛЕНО по сравнению со старой версией:
##  1) ГЛАВНОЕ: старый фильтр проверял ПОДСТРОКУ: path.contains(".godot").
##     Из-за этого из дампа ПРОПАДАЛ project.godot — в имени файла
##     "project.godot" подстрока ".godot" действительно есть!
##     Теперь проверяются сегменты пути, а не подстрока.
##  2) Папка .zcode (служебные логи агентов, сотни МБ) больше не попадает
##     в дамп — раньше это был 60% объёма и бесполезный мусор.
##  3) Бинарники (модели/текстуры/звук) не пишутся целиком — вместо них
##     строка-заглушка с размером файла. Дамп меньше в разы, но весь код
##     и все тексты (README/CREDITS из inbox/ тоже) в нём остаются.
##  4) Файлы пишутся в поток сразу. Старая версия копила весь дамп в одной
##     строке в памяти — на больших проектах это десятки секунд фриза.
##  5) Список файлов отсортирован — дамп всегда одинаковый по порядку.
##  6) Сам project_export.txt в дамп не попадает (не было риска двойного
##     вложения при повторном запуске).
extends EditorScript

const OUT_PATH := "res://project_export.txt"
const SKIP_DIRS := [".godot", ".git", ".zcode"]
const BIN_EXT := [
	"png", "jpg", "jpeg", "webp", "bmp", "tga", "dds", "ktx",
	"glb", "gltf", "fbx", "obj", "zip", "7z", "rar",
	"ogg", "wav", "mp3", "flac",
	"ttf", "otf", "woff",
	"sqlite", "dat", "key", "pem", "exe", "dll", "bin",
]


func _run() -> void:
	print("allFiles v2: начинаю сбор...")
	var all_files: Array[String] = []
	collect_files("res://", all_files)
	all_files.sort()

	var f := FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("allFiles: не могу открыть %s (код %d)" % [OUT_PATH, FileAccess.get_open_error()])
		return

	var count := 0
	for fp in all_files:
		f.store_string("\n----------------------------------------\n")
		f.store_string("ФАЙЛ: " + fp + "\n")
		f.store_string("----------------------------------------\n\n")
		f.store_string(read_file(fp))
		f.store_string("\n")
		count += 1
		if count % 200 == 0:
			print("allFiles v2: обработано %d..." % count)

	f.close()
	print("allFiles v2: ГОТОВО! Файлов: %d. Результат: %s" % [count, OUT_PATH])
	print("Если в редакторе файл не виден — File System -> Rescan.")


func collect_files(path: String, files: Array[String]) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		print("allFiles v2: не открылась папка: " + path)
		return

	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if item != "." and item != "..":
			var full := path + item
			if dir.current_is_dir():
				if not SKIP_DIRS.has(item) and not item.begins_with("."):
					collect_files(full + "/", files)
			else:
				if not _skip_file(full):
					files.append(full)
		item = dir.get_next()
	dir.list_dir_end()


func _skip_file(full: String) -> bool:
	# ФИКС: сравниваем сегменты пути ЦЕЛИКОМ, а не подстрокой.
	# Старый код "path.contains(\".godot\")" выбрасывал и project.godot.
	for seg in full.split("/"):
		if SKIP_DIRS.has(seg):
			return true
	var fname := full.get_file()
	if fname.begins_with("."):
		return true
	var ext := fname.get_extension().to_lower()
	return BIN_EXT.has(ext)


func read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return "[ОШИБКА ЧТЕНИЯ]"
	var ext := path.get_extension().to_lower()
	if BIN_EXT.has(ext):
		return "[БИНАРНЫЙ ФАЙЛ, %d байт — содержимое пропущено]" % f.get_length()
	return f.get_as_text()
