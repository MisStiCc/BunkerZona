extends Node

## Смоук дисклеймера v0.31.1. Полный запуск (автолоады на месте):
##   godot --headless --path . res://tools/smoke_disclaimer.tscn

var _fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		print("OK   ", name)
	else:
		_fails += 1
		print("FAIL ", name, " ", extra)


func _ready() -> void:
	_run()


func _run() -> void:
	# След прошлых прогонов убираем
	DirAccess.remove_absolute("user://disclaimer.cfg")

	var ps: PackedScene = load("res://scenes/ui/main_menu.tscn")
	_check("main_menu.tscn загружена", ps != null)
	if ps == null:
		get_tree().quit(1)
		return

	var menu: Node = ps.instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var ov: Control = menu.get_node_or_null("DisclaimerOverlay")
	_check("дисклеймер показан при первом запуске", ov != null)
	if ov == null:
		_finish()
		return

	var labels := ov.find_children("*", "Label", true, false)
	var buttons := ov.find_children("*", "Button", true, false)
	_check("тексты на месте (badge/заголовок/текст)", labels.size() >= 3, "labels=" + str(labels.size()))
	_check("кнопка «Понятно» на месте", buttons.size() >= 1)
	if buttons.size() >= 1:
		var ok_btn: Button = buttons[0]
		_check("кнопка локализована", ok_btn.text != "" and ok_btn.text != "disclaim.ok", ok_btn.text)
	_check("оверлей блокирует ввод", ov.mouse_filter == Control.MOUSE_FILTER_STOP)

	# Имитируем нажатие
	menu._on_disclaimer_ack()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("оверлей скрыт после ack", menu.get_node_or_null("DisclaimerOverlay") == null)
	_check("user://disclaimer.cfg записан", FileAccess.file_exists("user://disclaimer.cfg"))

	# Второй инстанс меню: дисклеймер показаться не должен
	menu.queue_free()
	await get_tree().process_frame
	var menu2: Node = ps.instantiate()
	add_child(menu2)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("повторный запуск: дисклеймера нет", menu2.get_node_or_null("DisclaimerOverlay") == null)

	# Чистим cfg, чтобы не влиять на другие тесты
	DirAccess.remove_absolute("user://disclaimer.cfg")
	_finish()


func _finish() -> void:
	if _fails == 0:
		print("SMOKE DISCLAIMER: ALL OK")
		get_tree().quit(0)
	else:
		print("SMOKE DISCLAIMER: FAILED (", _fails, " fails)")
		get_tree().quit(1)
