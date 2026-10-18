# ui/main_menu/main_menu.gd
extends Control

## Главное меню игры

signal new_game_pressed
signal load_pressed
signal settings_pressed
signal quit_pressed

@onready var new_game_button: Button = $VBox/Buttons/NewGameButton
@onready var load_button: Button = $VBox/Buttons/LoadButton
@onready var settings_button: Button = $VBox/Buttons/SettingsButton
@onready var quit_button: Button = $VBox/Buttons/QuitButton

@onready var load_screen: Control = $LoadScreen
@onready var settings_screen: Control = $SettingsScreen
@onready var save_slots_container: VBoxContainer = $LoadScreen/Panel/VBox/SaveSlots
@onready var title_label: Label = $VBox/Title
@onready var cover_art: TextureRect = $CoverArt
@onready var back_button: Button = $SettingsScreen/Panel/BackButton
@onready var load_back_button: Button = $LoadScreen/Panel/VBox/BackButton
@onready var music_slider: HSlider = $SettingsScreen/Panel/MusicSlider
@onready var sfx_slider: HSlider = $SettingsScreen/Panel/SfxSlider

var game_manager: Node


func _ready():
	# Непрозрачные панели настроек/загрузки
	theme = UiTheme.build()
	_setup_buttons()
	_setup_sounds()
	_setup_settings()
	_setup_save_slot_selector()
	# Музыка меню (SoundManager ищется один раз ниже)
	var _sm := get_tree().get_first_node_in_group("sound_manager")
	if _sm and _sm.has_method("play_music"):
		_sm.play_music("menu")
	_setup_attribution()
	_load_cover_art()
	_load_cover_art()
	
	load_screen.visible = false
	settings_screen.visible = false
	
	# Ищем GameManager один раз при старте
	game_manager = get_tree().get_first_node_in_group("game_manager")
	# print("MainMenu: инициализирован, GameManager найден: ", game_manager != null)


	_apply_static_texts()
	Loc.changed.connect(_apply_static_texts)
	_build_language_button()

func _load_cover_art():
	"""Фон меню - тот же арт, что и в лаборатории: res://ui/lab/lab_background.svg.
	В арте уже есть заголовок игры, поэтому текстовый Title прячем."""
	const COVER_PATH := "res://ui/main_menu/main_menu.svg"
	if ResourceLoader.exists(COVER_PATH):
		cover_art.texture = load(COVER_PATH)
		title_label.visible = false
		# print("MainMenu: фон-обложка загружена")


func _setup_buttons():
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	back_button.pressed.connect(_on_back_pressed)
	load_back_button.pressed.connect(_on_back_pressed)


func _setup_settings():
	"""Слайдеры громкости управляют аудиошинами Music и SFX"""
	music_slider.value_changed.connect(_on_music_volume_changed)
	sfx_slider.value_changed.connect(_on_sfx_volume_changed)
	
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if music_idx >= 0:
		music_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(music_idx)))
	if sfx_idx >= 0:
		sfx_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)))


func _on_music_volume_changed(value: float):
	_set_bus_volume("Music", value)


func _setup_save_slot_selector():
	"""Выбор активного слота сохранения между слайдерами и кнопкой НАЗАД"""
	var panel = get_node_or_null("SettingsScreen/Panel")
	if not panel:
		# print("MainMenu: SettingsScreen/Panel не найден, селектор слота не построен")
		return

	var selector := SaveSlotSelector.new()
	selector.position = Vector2(30, 202)
	selector.size = Vector2(340, 28)
	panel.add_child(selector)


func _on_sfx_volume_changed(value: float):
	_set_bus_volume("SFX", value)


func _set_bus_volume(bus_name: String, value: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.0001)))
		AudioServer.set_bus_mute(idx, value <= 0.001)


func _setup_sounds():
	new_game_button.mouse_entered.connect(_play_hover_sound)
	load_button.mouse_entered.connect(_play_hover_sound)
	settings_button.mouse_entered.connect(_play_hover_sound)
	quit_button.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_hover", 0.3)


func _play_click_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.6)


func _on_new_game_pressed():
	_play_click_sound()
	new_game_pressed.emit()
	
	if game_manager:
		# print("GameManager найден! Запускаем новую игру")
		game_manager.start_new_game()
	else:
		# print("GameManager НЕ НАЙДЕН! Ищем снова...")
		game_manager = get_tree().get_first_node_in_group("game_manager")
		if game_manager:
			game_manager.start_new_game()
		else:
			# print("GameManager не найден, переходим напрямую в ЛК")
			get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")


func _on_load_pressed():
	_play_click_sound()
	load_pressed.emit()
	load_screen.visible = true
	_refresh_save_slots()


func _on_settings_pressed():
	_play_click_sound()
	settings_pressed.emit()
	settings_screen.visible = true


func _on_quit_pressed():
	_play_click_sound()
	quit_pressed.emit()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _refresh_save_slots():
	# Очищаем старые кнопки
	for child in save_slots_container.get_children():
		child.queue_free()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if not game_manager:
		# print("GameManager не найден, не могу загрузить сохранения")
		# Показываем пустые слоты
		for i in range(3):
			var slot_container = HBoxContainer.new()
			var info_label = Label.new()
			info_label.text = Loc.t("menu.empty_slot", {"n": i + 1})
			slot_container.add_child(info_label)
			
			var load_btn = Button.new()
			load_btn.text = Loc.t("menu.load")
			load_btn.disabled = true
			slot_container.add_child(load_btn)
			
			var delete_btn = Button.new()
			delete_btn.text = Loc.t("menu.slot_delete")
			delete_btn.disabled = true
			slot_container.add_child(delete_btn)
			
			save_slots_container.add_child(slot_container)
		return
	
	var saves_info = game_manager.get_all_saves_info()

	# get_all_saves_info возвращает ручные слоты 1..3 (автосейв - отдельный механизм)
	for save_info in saves_info:
		var slot_number = int(save_info.get("slot", 1))
		var slot_container = HBoxContainer.new()

		var info_label = Label.new()
		if save_info.get("exists", false):
			info_label.text = Loc.t("menu.slot_info", {"n": slot_number, "run": save_info.get("run_number", 1), "bio": save_info.get("biomass", 0), "wins": save_info.get("wins", 0)})
		else:
			info_label.text = Loc.t("menu.empty_slot", {"n": slot_number})

		slot_container.add_child(info_label)

		var load_btn = Button.new()
		load_btn.text = Loc.t("menu.load")
		load_btn.disabled = not save_info.get("exists", false)
		load_btn.pressed.connect(_load_slot.bind(slot_number))
		slot_container.add_child(load_btn)

		var delete_btn = Button.new()
		delete_btn.text = Loc.t("menu.slot_delete")
		delete_btn.disabled = not save_info.get("exists", false)
		delete_btn.pressed.connect(_delete_slot.bind(slot_number))
		slot_container.add_child(delete_btn)

		save_slots_container.add_child(slot_container)


func _load_slot(slot: int):
	_play_click_sound()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager and game_manager.load_game(slot):
		await get_tree().create_timer(0.2).timeout
		game_manager.change_scene("lab")
	else:
		pass
		# print("Не удалось загрузить слот ", slot)


func _delete_slot(slot: int):
	_play_click_sound()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		game_manager.delete_save(slot)
	_refresh_save_slots()


func _on_back_pressed():
	_play_click_sound()
	load_screen.visible = false
	settings_screen.visible = false


func _apply_static_texts():
	"""Локализация статических надписей меню (Loc.changed пере apply)"""
	var title: Label = get_node_or_null("VBox/Title")
	if title:
		title.text = Loc.t("menu.title")
	var new_btn: Button = get_node_or_null("VBox/Buttons/NewGameButton")
	if new_btn:
		new_btn.text = Loc.t("menu.new_game")
	var load_btn: Button = get_node_or_null("VBox/Buttons/LoadButton")
	if load_btn:
		load_btn.text = Loc.t("menu.load")
	var settings_btn: Button = get_node_or_null("VBox/Buttons/SettingsButton")
	if settings_btn:
		settings_btn.text = Loc.t("menu.settings")
	var quit_btn: Button = get_node_or_null("VBox/Buttons/QuitButton")
	if quit_btn:
		quit_btn.text = Loc.t("menu.quit")
	var load_title: Label = get_node_or_null("LoadScreen/Panel/VBox/Title")
	if load_title:
		load_title.text = Loc.t("menu.load")
	var load_back: Button = get_node_or_null("LoadScreen/Panel/VBox/BackButton")
	if load_back:
		load_back.text = Loc.t("menu.back")
	var settings_title: Label = get_node_or_null("SettingsScreen/Panel/SettingsTitle")
	if settings_title:
		settings_title.text = Loc.t("menu.settings")
	var music_label: Label = get_node_or_null("SettingsScreen/Panel/MusicLabel")
	if music_label:
		music_label.text = Loc.t("menu.music")
	var sfx_label: Label = get_node_or_null("SettingsScreen/Panel/SfxLabel")
	if sfx_label:
		sfx_label.text = Loc.t("menu.sound")
	var settings_back: Button = get_node_or_null("SettingsScreen/Panel/BackButton")
	if settings_back:
		settings_back.text = Loc.t("menu.back")
	if _lang_button:
		_lang_button.text = Loc.t("menu.language")
	_refresh_load_screen_texts()


func _refresh_load_screen_texts():
	"""Перезаполнить строки слотов на текущем языке (переиспользует существующий rebuild)"""
	_refresh_save_slots()


var _lang_button: Button = null


func _build_language_button():
	"""Кнопка RU/EN в настройках меню"""
	var panel = get_node_or_null("SettingsScreen/Panel")
	if not panel:
		return
	_lang_button = Button.new()
	_lang_button.text = Loc.t("menu.language")
	_lang_button.position = Vector2(30, 240)
	_lang_button.size = Vector2(340, 36)
	_lang_button.pressed.connect(_on_language_pressed)
	panel.add_child(_lang_button)


func _on_language_pressed():
	Loc.toggle()


func _setup_attribution():
	"""Атрибуция OSM ODbL + CC-BY: обязательна по лицензиям ассетов"""
	var label := Label.new()
	label.text = "Карта: © OpenStreetMap contributors (ODbL) · Высоты: SRTM/AWS Terrain Tiles\n" + \
		"Bus, Swing set, Tumbleweed, Dead Tree by Poly by Google (CC-BY 4.0) · Dead Tree Trunk, Bus Stop by Zsky (CC-BY 4.0)"
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.position = Vector2(10, -44)
	label.size = Vector2(900, 40)
	add_child(label)
