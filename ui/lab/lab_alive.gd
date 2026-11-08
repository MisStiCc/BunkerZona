# ui/lab/lab_alive.gd
extends Node
class_name LabAlive

## D29 «ЗОНА ЖИВЁТ»: idle-жизнь лаборатории. Фоновые события-декорации:
## дальний гром + мигание ламп, тень сталкера по карте пути, дозиметр.
## Ноль влияния на механику. Мобилка: только звуки (без миганий).
## Спека design_inbox/_done/lab_alive.

const AMBIENT_PERIOD_MIN := 30.0
const AMBIENT_PERIOD_MAX := 90.0
const SHADOW_RUN_LEN := 8.0

var _timer: Timer = null
var _last_event: String = ""
var _desktop: bool = true


func _ready() -> void:
	_desktop = not DisplayServer.is_touchscreen_available()
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_fire_event)
	add_child(_timer)
	_arm()


func _exit_tree() -> void:
	# эмбиент лабы гасим при выходе (в забеге свой набор)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("stop_ambient"):
		sm.stop_ambient()


func _arm() -> void:
	_timer.start(randf_range(AMBIENT_PERIOD_MIN, AMBIENT_PERIOD_MAX))


func _fire_event() -> void:
	var hour: int = Time.get_datetime_dict_from_system().get("hour", 12)
	var night: bool = hour >= 22 or hour < 6
	# ночной набор: насекомые вместо дневного ветра (эмбиент лабы)
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_ambient"):
		sm.play_ambient("night_insects_01" if night else "wind_open_01", 0.6)

	var pool: Array = ["thunder"]
	if _desktop:
		pool.append("shadow")
	if night:
		pool.append("thunder")   # ночью гром чаще в пуле, тень реже
	var ev: String = str(pool[randi() % pool.size()])
	if ev == _last_event and pool.size() > 1:
		ev = str(pool[randi() % pool.size()])
	_last_event = ev
	match ev:
		"thunder":
			_event_thunder()
		"shadow":
			_event_shadow_run()
	_arm()


## Дальний гром + короткое мигание ламп (только десктоп)
func _event_thunder() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("thunder_far_01", randf_range(0.3, 0.5))
	if not _desktop:
		return
	var lab := get_tree().get_first_node_in_group("lab")
	if lab == null:
		return
	var tw := create_tween()
	tw.tween_property(lab, "modulate:a", 0.82, 0.08)
	tw.tween_property(lab, "modulate:a", 1.0, 0.14)


## Тень сталкера пробегает по карте пути (8 с), силуэт из коллекции
func _event_shadow_run() -> void:
	var map: Node = get_tree().get_first_node_in_group("lab").find_child("JourneyMap", true, false) \
		if get_tree().get_first_node_in_group("lab") else null
	if map == null:
		return
	var gm = get_tree().get_first_node_in_group("game_manager")
	var lab_data = gm.get_lab_data() if gm and gm.has_method("get_lab_data") else null
	if lab_data == null or lab_data.unlocked_mutants.is_empty():
		return
	var icon_path: String = GachaData.card_icon_path(
		str(lab_data.unlocked_mutants[randi() % lab_data.unlocked_mutants.size()]), true, false)
	if not ResourceLoader.exists(icon_path):
		return
	var shadow := TextureRect.new()
	shadow.texture = load(icon_path)
	shadow.modulate = Color(0.05, 0.05, 0.07, 0.0)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shadow.custom_minimum_size = Vector2(46, 46)
	shadow.size = Vector2(46, 46)
	map.add_child(shadow)
	var w: float = map.size.x if map is Control else 400.0
	var h: float = map.size.y if map is Control else 240.0
	var y := randf_range(h * 0.3, h * 0.7)
	var tw := create_tween()
	tw.tween_property(shadow, "modulate:a", 0.55, 1.0)
	tw.parallel().tween_property(shadow, "position", Vector2(-60.0, y), 0.1)
	tw.tween_property(shadow, "position:x", w + 60.0, SHADOW_RUN_LEN)
	tw.parallel().tween_property(shadow, "modulate:a", 0.0, 1.2)
	tw.tween_callback(shadow.queue_free)
