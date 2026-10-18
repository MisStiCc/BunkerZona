# ui/lab/lab_controller.gd
extends Control
class_name LabController

## Контроллер лабораторного комплекса

signal run_started
signal upgrade_station_opened(station_type: String)
signal storage_opened
signal settings_opened

# Основная информация
@onready var run_number_label: Label = $VBox/Header/RunNumber
@onready var biomass_label: Label = $VBox/InfoPanel/HBox/BiomassValue
@onready var start_run_button: Button = $VBox/InfoPanel/StartRunButton

# Станции
@onready var anomaly_station: Button = $VBox/Stations/AnomalyStation
@onready var mutant_station: Button = $VBox/Stations/MutantStation
@onready var monolith_station: Button = $VBox/Stations/MonolithStation

# Хранилище
@onready var artifact_storage_button: Button = $VBox/StoragePanel/OpenStorageButton
@onready var artifact_counts_label: Label = $VBox/StoragePanel/HBox/ArtifactCounts

# Статистика
@onready var stats_label: Label = $VBox/StatsPanel/StatsLabel

# Нижние кнопки
@onready var menu_button: Button = $VBox/BottomButtons/MenuButton
@onready var settings_button: Button = $VBox/BottomButtons/SettingsButton
@onready var settings_screen: Control = $SettingsScreen
@onready var settings_music_slider: HSlider = $SettingsScreen/Panel/MusicSlider
@onready var settings_sfx_slider: HSlider = $SettingsScreen/Panel/SfxSlider
@onready var settings_back_button: Button = $SettingsScreen/Panel/BackButton
@onready var shop_button: Button = $VBox/BottomButtons/ShopButton
@onready var shop_panel: Control = $ShopPanel
@onready var shop_close_button: Button = $ShopPanel/Panel/ShopClose
@onready var shop_biomass_label: Label = $ShopPanel/Panel/ShopBiomass
@onready var mutant_grid: GridContainer = $ShopPanel/Panel/MutantGrid
@onready var artifact_grid: GridContainer = $ShopPanel/Panel/ArtifactGrid
@onready var save_button: Button = $VBox/BottomButtons/SaveButton

# Панели
@onready var upgrade_panel: Control = $UpgradePanel
@onready var storage_panel: Control = $StoragePanel
@onready var result_panel: Control = $ResultPanel

# Данные
var lab_data: LabData
var statistics: GameStatistics
var game_manager: Node

# Кампания: выбранный уровень и элементы селектора (строятся кодом в Header)
var _campaign_level: int = 1
var _campaign_prev_button: Button
var _campaign_next_button: Button
var _campaign_mode_button: Button
var _campaign_label: Label
# Переключатель режима забега: кампания / башня / выживание
var _run_mode_button: Button
# Кнопка и панель Башни Монолита (строятся кодом)
var _tower_button: Button
var tower_panel: Control
var _tower_grid: GridContainer
var _tower_info: Label
var _tower_go_button: Button
var _selected_tower_floor: int = 0
# Кнопка выбора карты забега: Зона / Припять
var _map_button: Button


func _ready():
	# print("lab_controller: _ready started")
	
	# Непрозрачные панели: всплывающие окна читаются поверх фона
	theme = UiTheme.build()
	_load_cover_art()
	
	# Ищем GameManager один раз при старте
	game_manager = get_tree().get_first_node_in_group("game_manager")
	
	_load_data()
	_setup_connections()
	_apply_static_texts()
	_refresh_ui()
	_setup_campaign_selector()
	_refresh_campaign_ui()
	_build_star_ui()
	_build_farm_ui()
	_build_gacha_ui()
	_build_gallery_ui()
	_build_language_button()
	Loc.changed.connect(_apply_static_texts)
	# Музыка лаборатории
	var sm := get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_music"):
		sm.play_music("lab")
	_show_last_run_result()

	# print("lab_controller: initialized, GameManager найден: ", game_manager != null)


func _show_last_run_result():
	"""Панель итогов последнего забега (результат кладёт GameManager.process_run_result)"""
	if not get_tree().root.has_meta("last_run_result"):
		return

	var result: Dictionary = get_tree().root.get_meta("last_run_result")
	get_tree().root.remove_meta("last_run_result")
	show_run_result(result)

	# Башня: сводка этажа (звёзды/крутки) поверх стандартных итогов
	if result.has("tower_summary"):
		var s: Dictionary = result["tower_summary"]
		var stats_label = result_panel.get_node_or_null("Panel/Margin/VBox/StatsLabel")
		if stats_label:
			var stars_text := ""
			for i in range(3):
				stars_text += "★" if i < int(s.get("stars", 0)) else "☆"
			stats_label.text += "\n\nБАШНЯ, этаж %d: %s\nБиомасса: %d | Крутки мутантов: +%d | Аномалий: +%d" % [
				int(s.get("floor", 0)), stars_text,
				int(s.get("biomass", 0.0)), int(s.get("mutant_rolls", 0)), int(s.get("anomaly_rolls", 0))]


func _load_cover_art():
	"""Фоновая обложка лаборатории: res://ui/lab/lab_background.svg (опционально).
	Файла нет - остаётся тёмная подложка Background."""
	var cover: TextureRect = get_node_or_null("CoverArt")
	if not cover:
		return
	const COVER_PATH := "res://ui/lab/lab_background.svg"
	if ResourceLoader.exists(COVER_PATH):
		cover.texture = load(COVER_PATH)
		# print("lab_controller: обложка лаборатории загружена")
	else:
		cover.visible = false


func _load_data():
	# print("lab_controller: загрузка данных...")
	
	if game_manager:
		# print("GameManager НАЙДЕН!")
		lab_data = game_manager.get_lab_data()
		statistics = game_manager.get_statistics()
		# Рубеж кампании для проверки разблокировки расширенных тиров
		lab_data.campaign_level_reached = game_manager.get_campaign_level()
	else:
		# print("GameManager НЕ НАЙДЕН! Создаем временные данные")
		lab_data = LabData.new()
		statistics = GameStatistics.new()
	
	# print("lab_controller: данные загружены")


func _setup_connections():
	start_run_button.pressed.connect(_on_start_run_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	settings_back_button.pressed.connect(_on_settings_back_pressed)
	shop_button.pressed.connect(_on_shop_pressed)
	shop_close_button.pressed.connect(_on_shop_close_pressed)
	_setup_settings_sliders()
	_setup_save_slot_selector()
	save_button.pressed.connect(_on_save_pressed)
	artifact_storage_button.pressed.connect(_on_storage_pressed)
	
	anomaly_station.pressed.connect(_on_anomaly_station_pressed)
	mutant_station.pressed.connect(_on_mutant_station_pressed)
	monolith_station.pressed.connect(_on_monolith_station_pressed)
	
	_setup_sounds()


func _setup_sounds():
	var buttons = [
		start_run_button, menu_button, settings_button, 
		save_button, artifact_storage_button,
		anomaly_station, mutant_station, monolith_station
	]
	
	for btn in buttons:
		if btn:
			btn.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_hover", 0.3)


func _apply_static_texts():
	"""Все статические надписи лаборатории по текущему языку (Loc.changed пере apply)"""
	var title: Label = get_node_or_null("VBox/Header/Title")
	if title:
		title.text = Loc.t("lab.title")
	var info: Label = get_node_or_null("VBox/InfoPanel/HBox/InfoLabel")
	if info:
		info.text = Loc.t("lab.info_header")
	var biomass_prefix: Label = get_node_or_null("VBox/InfoPanel/HBox/BiomassLabel")
	if biomass_prefix:
		biomass_prefix.text = Loc.t("lab.biomass_prefix")
	start_run_button.text = Loc.t("lab.start_run")
	menu_button.text = Loc.t("lab.menu")
	settings_button.text = Loc.t("lab.settings")
	shop_button.text = Loc.t("lab.shop")
	save_button.text = Loc.t("lab.save")
	artifact_storage_button.text = Loc.t("lab.storage_open")
	var storage_label: Label = get_node_or_null("VBox/StoragePanel/HBox/StorageLabel")
	if storage_label:
		storage_label.text = Loc.t("lab.storage")
	var settings_title: Label = get_node_or_null("SettingsScreen/Panel/SettingsTitle")
	if settings_title:
		settings_title.text = Loc.t("lab.settings")
	var music_label: Label = get_node_or_null("SettingsScreen/Panel/MusicLabel")
	if music_label:
		music_label.text = Loc.t("lab.settings_music")
	var sfx_label: Label = get_node_or_null("SettingsScreen/Panel/SfxLabel")
	if sfx_label:
		sfx_label.text = Loc.t("lab.settings_sfx")
	var settings_back: Button = get_node_or_null("SettingsScreen/Panel/BackButton")
	if settings_back:
		settings_back.text = Loc.t("lab.back")
	var shop_title: Label = get_node_or_null("ShopPanel/Panel/ShopTitle")
	if shop_title:
		shop_title.text = Loc.t("shop.title")
	var mutants_header: Label = get_node_or_null("ShopPanel/Panel/MutantsHeader")
	if mutants_header:
		mutants_header.text = Loc.t("shop.mutants_header")
	var artifacts_header: Label = get_node_or_null("ShopPanel/Panel/ArtifactsHeader")
	if artifacts_header:
		artifacts_header.text = Loc.t("shop.artifacts_header")
	var shop_close: Button = get_node_or_null("ShopPanel/Panel/ShopClose")
	if shop_close:
		shop_close.text = Loc.t("lab.back")
	# Панели звёзд/фермы (строятся кодом) - перезаполнить
	if star_panel and star_panel.visible:
		_rebuild_star_panel()
	if farm_panel and farm_panel.visible:
		_rebuild_farm_panel()
	# Языковая кнопка показывает текущий язык
	if _lang_button:
		_lang_button.text = Loc.t("menu.language")


func _play_click_sound():
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.6)


func _refresh_ui():
	if not lab_data:
		# print("lab_data отсутствует, создаем новый")
		lab_data = LabData.new()
	
	run_number_label.text = Loc.t("lab.day", {"n": lab_data.run_number})
	biomass_label.text = _format_number(lab_data.biomass)
	
	_update_station_button(anomaly_station, Loc.t("lab.anomalies"), lab_data.get_total_anomaly_levels())
	_update_station_button(mutant_station, Loc.t("lab.mutants"), lab_data.get_total_mutant_levels())
	_update_station_button(monolith_station, Loc.t("lab.monolith"), lab_data.get_total_monolith_levels())
	
	var common = lab_data.get_artifact_count("common")
	var rare = lab_data.get_artifact_count("rare")
	var legendary = lab_data.get_artifact_count("legendary")
	artifact_counts_label.text = Loc.t("lab.storage_counts", {"c": common, "r": rare, "l": legendary})
	
	if statistics:
		stats_label.text = "Всего забегов: %d   Побед: %d   Поражений: %d\nСталкеров убито: %d   Артефактов украдено: %d\nРекорд выживания: %d волн" % [
			statistics.total_runs,
			statistics.wins,
			statistics.losses,
			statistics.stalkers_killed,
			statistics.artifacts_stolen,
			statistics.best_survival_wave
		]


func _update_station_button(station: Button, station_name: String, total_levels: int):
	var name_label = station.get_node_or_null("StationName")
	if name_label and name_label is Label:
		name_label.text = station_name
	
	var level_label = station.get_node_or_null("StationLevel")
	if level_label and level_label is Label:
		level_label.text = Loc.t("lab.level_short", {"n": total_levels})


func _format_number(value: float) -> String:
	var s = str(int(value))
	var result = ""
	var count = 0
	
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = " " + result
		result = s[i] + result
		count += 1
	
	return result


# ==================== КАМПАНИЯ ====================

func _setup_campaign_selector():
	"""Селектор уровня кампании в шапке лаборатории: ◀ уровень ▶ и режим сложности"""
	# По умолчанию стоим на ТЕКУЩЕМ рубеже, а не переигрываем первый уровень
	if game_manager:
		_campaign_level = game_manager.get_campaign_level()
	var header: HBoxContainer = get_node_or_null("VBox/Header")
	if not header:
		# print("lab_controller: Header не найден, селектор кампании не построен")
		return

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)

	_campaign_label = Label.new()
	_campaign_label.add_theme_font_size_override("font_size", 16)
	_campaign_label.clip_text = true
	_campaign_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_map_button = Button.new()
	_map_button.text = "🗺 Зона"
	_tower_button = Button.new()
	_tower_button.text = "🗼 Башня"
	_run_mode_button = Button.new()
	_run_mode_button.text = "Кампания"
	_campaign_prev_button = Button.new()
	_campaign_prev_button.text = "◀"
	_campaign_next_button = Button.new()
	_campaign_next_button.text = "▶"
	_campaign_mode_button = Button.new()

	row.add_child(_map_button)
	row.add_child(_tower_button)
	row.add_child(_run_mode_button)
	row.add_child(_campaign_prev_button)
	row.add_child(_campaign_label)
	row.add_child(_campaign_next_button)
	row.add_child(_campaign_mode_button)
	header.add_child(row)

	_map_button.pressed.connect(_on_map_pressed)
	_tower_button.pressed.connect(_on_tower_pressed)
	_run_mode_button.pressed.connect(_on_run_mode_pressed)
	_campaign_prev_button.pressed.connect(_on_campaign_prev_pressed)
	_campaign_next_button.pressed.connect(_on_campaign_next_pressed)
	_campaign_mode_button.pressed.connect(_on_campaign_mode_pressed)
	for btn in [_map_button, _tower_button, _run_mode_button, _campaign_prev_button, _campaign_next_button, _campaign_mode_button]:
		btn.mouse_entered.connect(_play_hover_sound)
	_refresh_map_button()


func _refresh_map_button():
	if game_manager and _map_button:
		var is_pripyat: bool = game_manager.get_selected_map() == "pripyat"
		_map_button.text = "🗺 Припять" if is_pripyat else "🗺 Зона"


func _on_map_pressed():
	"""Переключение карты забега: процедурная Зона <-> Припять"""
	_play_click_sound()
	if not game_manager:
		return
	var next_map: String = "procedural"
	if game_manager.get_selected_map() == "procedural":
		next_map = "pripyat"
	game_manager.set_selected_map(next_map)
	_refresh_map_button()


func _refresh_campaign_ui():
	if not game_manager or not _campaign_label:
		return

	# Режим забега определяет, что показывает строка
	var run_mode: String = game_manager.get_selected_run_mode()
	_run_mode_button.text = {
		"campaign": "Кампания",
		"tower": "Башня",
		"survival": "Выживание"
	}.get(run_mode, "Кампания")
	# Множитель сложности применяется во всех режимах
	_campaign_mode_button.text = "Сложность: %s" % CampaignData.get_mode_name(game_manager.get_campaign_mode())

	if run_mode == "tower":
		var frontier_floor: int = game_manager.get_tower_floor()
		var params: Dictionary = TowerData.get_floor_params(frontier_floor)
		var floor_text: String = params.get("title", "")
		_campaign_label.text = "БАШНЯ - %s (всего этажей: %d)" % [floor_text, TowerData.TOTAL_FLOORS]
		_campaign_prev_button.disabled = true
		_campaign_next_button.disabled = true
		return

	if run_mode == "survival":
		var record: int = 0
		var stats = game_manager.get_statistics()
		if stats:
			record = stats.best_survival_wave
		_campaign_label.text = "ВЫЖИВАНИЕ - волны без предела, награда за каждую (рекорд: %d)" % record
		_campaign_prev_button.disabled = true
		_campaign_next_button.disabled = true
		return

	var frontier: int = game_manager.get_campaign_level()
	_campaign_level = clampi(_campaign_level, 1, frontier)

	var params: Dictionary = CampaignData.get_level_params(_campaign_level, game_manager.get_campaign_mode())
	var text: String
	if params.get("is_boss", false):
		text = "КАРАВАН %d/100: «%s»" % [_campaign_level, params.get("title", "")]
	else:
		text = "Уровень %d/100 - %s" % [_campaign_level, params.get("chapter_title", "")]
	if _campaign_level < frontier:
		text += " (пройден)"
	if game_manager.is_campaign_completed() and _campaign_level >= CampaignData.TOTAL_LEVELS:
		text = "КАМПАНИЯ ПРОЙДЕНА! Финальный уровень: 100/100"
	_campaign_label.text = text

	_campaign_prev_button.disabled = _campaign_level <= 1
	_campaign_next_button.disabled = _campaign_level >= frontier
	_campaign_mode_button.text = "Сложность: %s" % CampaignData.get_mode_name(game_manager.get_campaign_mode())


func _on_run_mode_pressed():
	"""Переключение режима забега: кампания -> башня -> выживание -> кампания"""
	_play_click_sound()
	if not game_manager:
		return

	var next_mode: String = "tower"
	var current: String = game_manager.get_selected_run_mode()
	if current == "tower":
		next_mode = "survival"
	elif current == "survival":
		next_mode = "campaign"

	game_manager.set_selected_run_mode(next_mode)
	_refresh_campaign_ui()


func _on_campaign_prev_pressed():
	_play_click_sound()
	_campaign_level = maxi(1, _campaign_level - 1)
	_refresh_campaign_ui()


func _on_campaign_next_pressed():
	_play_click_sound()
	var frontier: int = game_manager.get_campaign_level() if game_manager else 1
	_campaign_level = mini(frontier, _campaign_level + 1)
	_refresh_campaign_ui()


func _on_campaign_mode_pressed():
	"""Цикл режимов сложности: Сталкер -> Ветеран -> Легенда"""
	_play_click_sound()
	if not game_manager:
		return

	var current: String = game_manager.get_campaign_mode()
	var next_mode: String = CampaignData.MODE_EASY
	if current == CampaignData.MODE_EASY:
		next_mode = CampaignData.MODE_NORMAL
	elif current == CampaignData.MODE_NORMAL:
		next_mode = CampaignData.MODE_HARD

	game_manager.set_campaign_mode(next_mode)
	_refresh_campaign_ui()


# ==================== ОБРАБОТЧИКИ ====================

func _on_start_run_pressed():
	_play_click_sound()
	run_started.emit()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		# Выбранный в селекторе уровень кампании уходит в параметры забега
		game_manager.selected_campaign_level = _campaign_level
		# print("Запуск забега через GameManager (уровень кампании %d)" % _campaign_level)
		await get_tree().create_timer(0.2).timeout
		game_manager.change_scene("run")
	else:
		pass
		# print("GameManager не найден, не могу начать забег")


func _on_menu_pressed():
	_play_click_sound()
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		await get_tree().create_timer(0.2).timeout
		game_manager.change_scene("main_menu")
	else:
		# print("GameManager не найден, переходим напрямую")
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _setup_settings_sliders():
	"""Слайдеры громкости лаборатории - те же аудиошины Music/SFX,
	что и в главном меню (значения глобальные)"""
	settings_music_slider.value_changed.connect(
		func(v): _set_bus_volume("Music", v))
	settings_sfx_slider.value_changed.connect(
		func(v): _set_bus_volume("SFX", v))
	var music_idx = AudioServer.get_bus_index("Music")
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if music_idx >= 0:
		settings_music_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(music_idx)))
	if sfx_idx >= 0:
		settings_sfx_slider.set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(sfx_idx)))


func _setup_save_slot_selector():
	"""Выбор активного слота сохранения между слайдерами и кнопкой НАЗАД"""
	var panel = get_node_or_null("SettingsScreen/Panel")
	if not panel:
		# print("lab_controller: SettingsScreen/Panel не найден, селектор слота не построен")
		return

	var selector := SaveSlotSelector.new()
	selector.position = Vector2(30, 202)
	selector.size = Vector2(340, 28)
	panel.add_child(selector)


func _set_bus_volume(bus_name: String, value: float):
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(max(value, 0.0001)))
		AudioServer.set_bus_mute(idx, value <= 0.001)


func _on_settings_back_pressed():
	_play_click_sound()
	settings_screen.visible = false


# ==================== МАГАЗИН ====================

func _on_shop_pressed():
	_play_click_sound()
	shop_panel.visible = true
	_rebuild_shop()


func _on_shop_close_pressed():
	_play_click_sound()
	shop_panel.visible = false


func _rebuild_shop():
	"""Кнопки магазина из таблиц GachaData: имя + цена, покупка за биомассу лаборатории"""
	for child in mutant_grid.get_children():
		child.queue_free()
	for child in artifact_grid.get_children():
		child.queue_free()
	var lab_biomass: float = lab_data.biomass if lab_data else 0.0
	shop_biomass_label.text = Loc.t("shop.biomass", {"n": int(lab_biomass)})
	for entry in GachaData.get_shop_mutants():
		var type: String = entry[0]
		var price: float = entry[2]
		var btn := Button.new()
		if lab_data and not lab_data.unlocked_mutants.has(type):
			btn.disabled = true
			btn.text = entry[1] + "
" + Loc.t("shop.locked", {"n": GachaData.get_unlock_campaign_level(type)})
		else:
			btn.text = _shop_item_text(entry[1], type, true) + "
🧬" + str(int(price))
			btn.pressed.connect(_on_shop_buy.bind("mutant", type, price))
		_add_card_icon(btn, type, true)
		btn.custom_minimum_size = Vector2(160, 46)
		mutant_grid.add_child(btn)
	for entry in GachaData.get_shop_artifacts():
		var type: String = entry[0]
		var price: float = entry[2]
		var btn := Button.new()
		if lab_data and not lab_data.won_artifacts.has(type):
			btn.disabled = true
			btn.text = entry[1] + "
" + Loc.t("shop.locked", {"n": GachaData.get_unlock_campaign_level(type)})
		else:
			btn.text = _shop_item_text(entry[1], type, false) + "
🧬" + str(int(price))
			btn.pressed.connect(_on_shop_buy.bind("artifact", type, price))
		_add_card_icon(btn, type, false)
		btn.custom_minimum_size = Vector2(240, 46)
		artifact_grid.add_child(btn)


func _add_card_icon(btn: Button, type: String, is_mutant: bool):
	"""Карточка-иконка слева от текста кнопки (магазин/дропы/ферма)"""
	var path: String = GachaData.card_icon_path(type, is_mutant)
	if ResourceLoader.exists(path):
		btn.icon = load(path)
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 24)


func _make_icon_rect(type: String, is_mutant: bool, icon_size: int = 24) -> TextureRect:
	var rect := TextureRect.new()
	var path: String = GachaData.card_icon_path(type, is_mutant)
	if ResourceLoader.exists(path):
		rect.texture = load(path)
	rect.custom_minimum_size = Vector2(icon_size, icon_size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _shop_item_text(item_name: String, type: String, is_mutant: bool) -> String:
	"""Имя + звёзды, если тип уже в коллекции (в бою получит эти звёзды)"""
	if not lab_data:
		return item_name
	var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
	var owned: bool = lab_data.unlocked_mutants.has(type) if is_mutant else lab_data.won_artifacts.has(type)
	if owned and stars > 1:
		return item_name + " " + "★".repeat(stars)
	if owned:
		return item_name + " ★"
	return item_name


func _on_shop_buy(kind: String, item_type: String, price: float):
	var bought := false
	if kind == "mutant":
		bought = game_manager.buy_shop_mutant(item_type, price)
	else:
		bought = game_manager.buy_shop_artifact(item_type, price)
	if bought:
		_play_click_sound()
		_rebuild_shop()
	else:
		_show_message(Loc.t("shop.not_enough"), 1.5)


# ==================== ЗВЁЗДНОСТЬ ====================

var star_panel: Control
var star_biomass_label: Label
var star_list: VBoxContainer


func _build_star_ui():
	"""Кнопка ★ в магазине + панель прокачки звёзд (строится кодом)"""
	star_panel = Control.new()
	star_panel.name = "StarPanel"
	star_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	star_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	star_panel.visible = false
	add_child(star_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	star_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	star_panel.add_child(panel)

	var title := Label.new()
	title.text = Loc.t("stars.title")
	title.position = Vector2(0, 10)
	title.size = Vector2(560, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	star_biomass_label = Label.new()
	star_biomass_label.position = Vector2(0, 36)
	star_biomass_label.size = Vector2(560, 20)
	star_biomass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(star_biomass_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 64)
	scroll.size = Vector2(520, 288)
	panel.add_child(scroll)

	star_list = VBoxContainer.new()
	star_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_list.add_theme_constant_override("separation", 4)
	scroll.add_child(star_list)

	var close_btn := Button.new()
	close_btn.text = "НАЗАД"
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_stars_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_stars_pressed():
	_play_click_sound()
	shop_panel.visible = false
	farm_panel.visible = false
	star_panel.visible = true
	_rebuild_star_panel()


func _on_stars_close_pressed():
	_play_click_sound()
	star_panel.visible = false


func _rebuild_star_panel():
	"""Строка на каждого питомца коллекции: имя, звёзды, цена следующей звезды"""
	for child in star_list.get_children():
		child.queue_free()
	if not lab_data:
		return
	star_biomass_label.text = Loc.t("stars.biomass_line", {"n": int(lab_data.biomass)})

	var artifacts: Array[String] = []
	for t in lab_data.won_artifacts:
		if not artifacts.has(t):
			artifacts.append(t)

	if artifacts.is_empty():
		var empty := Label.new()
		empty.text = Loc.t("stars.artifacts_only")
		star_list.add_child(empty)
		return

	star_list.add_child(_make_star_section(Loc.t("stars.artifacts_header")))
	for type in artifacts:
		star_list.add_child(_make_star_row("artifact", type))


func _make_star_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_star_row(kind: String, type: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_rect(type, kind == "mutant", 26))
	var stars: int = lab_data.get_mutant_stars(type) if kind == "mutant" else lab_data.get_artifact_stars(type)

	var name_label := Label.new()
	name_label.text = "%s  %s" % [GachaData.display_name(type), LabData.stars_text(stars)]
	name_label.tooltip_text = Loc.t("stars.mult_tip", {"n": "%.1f" % LabData.get_star_stat_mult(stars)})
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	if stars >= LabData.MAX_STARS:
		var max_label := Label.new()
		max_label.text = Loc.t("stars.max")
		row.add_child(max_label)
	else:
		var cost := lab_data.get_star_upgrade_cost(stars)
		var btn := Button.new()
		btn.text = "🧬 " + str(int(cost))
		btn.pressed.connect(_on_star_upgrade.bind(kind, type))
		btn.mouse_entered.connect(_play_hover_sound)
		row.add_child(btn)
	return row


func _on_star_upgrade(kind: String, type: String):
	_play_click_sound()
	var ok := false
	if kind == "mutant":
		ok = game_manager.upgrade_mutant_star(type)
	else:
		ok = game_manager.upgrade_artifact_star(type)
	if ok:
		lab_data = game_manager.get_lab_data()
		_rebuild_star_panel()
		if shop_panel.visible:
			_rebuild_shop()
		_refresh_ui()
	else:
		_show_message(Loc.t("stars.fail_msg"), 1.5)


func _on_settings_pressed():
	_play_click_sound()
	settings_opened.emit()
	settings_screen.visible = true


func _on_save_pressed():
	_play_click_sound()

	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")

	if game_manager and game_manager.has_method("save_to_active_slot"):
		game_manager.save_to_active_slot()
		_show_message("Игра сохранена", 1.0)
	else:
		pass
		# print("GameManager не найден, не могу сохранить")


func _on_storage_pressed():
	_play_click_sound()
	storage_opened.emit()
	_open_storage()


func _on_anomaly_station_pressed():
	_play_click_sound()
	upgrade_station_opened.emit("anomaly")
	_open_upgrade_station("anomaly")


func _on_mutant_station_pressed():
	_play_click_sound()
	upgrade_station_opened.emit("mutant")
	_open_upgrade_station("mutant")


func _on_monolith_station_pressed():
	_play_click_sound()
	upgrade_station_opened.emit("monolith")
	_open_upgrade_station("monolith")


# ==================== ПАНЕЛИ ====================

func _open_upgrade_station(station_type: String):
	if upgrade_panel and upgrade_panel.has_method("setup"):
		upgrade_panel.setup(station_type, lab_data, _on_upgrade_purchased)
		upgrade_panel.visible = true
	else:
		# print("Upgrade panel not found or invalid")
		_show_message("Панель улучшений не найдена", 1.0)


func _on_upgrade_purchased(_upgrade_type: String):
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		lab_data = game_manager.get_lab_data()
	_refresh_ui()
	_show_message("Улучшение приобретено!", 1.0)


func _open_storage():
	if storage_panel and storage_panel.has_method("setup"):
		storage_panel.setup(lab_data, _on_artifact_exchanged)
		storage_panel.visible = true
	else:
		# print("Storage panel not found or invalid")
		_show_message("Хранилище не найдено", 1.0)


func _on_artifact_exchanged():
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		lab_data = game_manager.get_lab_data()
	_refresh_ui()
	_show_message("Артефакт обменян", 1.0)


func show_run_result(result: Dictionary):
	if result_panel and result_panel.has_method("show_result"):
		result_panel.show_result(result)
		result_panel.visible = true
	
	if not game_manager:
		game_manager = get_tree().get_first_node_in_group("game_manager")
	
	if game_manager:
		lab_data = game_manager.get_lab_data()
		statistics = game_manager.get_statistics()
	_refresh_ui()


func _show_message(text: String, duration: float = 2.0):
	var msg_label = Label.new()
	msg_label.text = text
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.add_theme_color_override("font_color", Color.WHITE)
	msg_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	msg_label.add_theme_constant_override("shadow_offset_x", 2)
	msg_label.add_theme_constant_override("shadow_offset_y", 2)
	
	add_child(msg_label)
	msg_label.position = Vector2(size.x / 2 - 100, size.y / 2)
	
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(msg_label):
		msg_label.queue_free()

func _add_primary_action(btn: Button, fallback: Node) -> void:
	"""Большая тач-кнопка (ФЕРМА/ГАЧА/КОДЕКС): высота 84px, шрифт 24.
	Кладём в ряд PrimaryActions над служебным - зона большого пальца.
	Ряда нет (старая сцена) - возвращаемся в BottomButtons, как раньше."""
	var primary: HBoxContainer = get_node_or_null("VBox/PrimaryActions")
	btn.custom_minimum_size = Vector2(0, 84)
	btn.add_theme_font_size_override("font_size", 24)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if primary:
		primary.add_child(btn)
	elif fallback:
		fallback.add_child(btn)


# ==================== ФЕРМА МУТАНТОВ ====================

var farm_panel: Control
var farm_list: VBoxContainer
var farm_title_label: Label
# Режим кормления: [fodder_type] или []
var _feed_fodder: Array = []


func _build_farm_ui():
	"""Кнопка ФЕРМА в нижнем ряду + панель копий и кормления (строится кодом)"""
	var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
	if bottom:
		var farm_btn := Button.new()
		farm_btn.name = "FarmButton"
		farm_btn.text = Loc.t("lab.farm")
		farm_btn.pressed.connect(_on_farm_pressed)
		farm_btn.mouse_entered.connect(_play_hover_sound)
		_add_primary_action(farm_btn, bottom)

	farm_panel = Control.new()
	farm_panel.name = "FarmPanel"
	farm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	farm_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	farm_panel.visible = false
	add_child(farm_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	farm_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	farm_panel.add_child(panel)

	var star_btn := Button.new()
	star_btn.text = Loc.t("shop.stars")
	star_btn.position = Vector2(390, 8)
	star_btn.size = Vector2(150, 30)
	star_btn.pressed.connect(_on_stars_pressed)
	star_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(star_btn)

	farm_title_label = Label.new()
	farm_title_label.position = Vector2(0, 10)
	farm_title_label.size = Vector2(370, 25)
	farm_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(farm_title_label)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 44)
	scroll.size = Vector2(520, 308)
	panel.add_child(scroll)

	farm_list = VBoxContainer.new()
	farm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	farm_list.add_theme_constant_override("separation", 4)
	scroll.add_child(farm_list)

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_farm_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_farm_pressed():
	_play_click_sound()
	shop_panel.visible = false
	star_panel.visible = false
	_feed_fodder.clear()
	farm_panel.visible = true
	_rebuild_farm_panel()


func _on_farm_close_pressed():
	_play_click_sound()
	farm_panel.visible = false


func _rebuild_farm_panel():
	"""Копии на ферме: '+★' (копия того же типа) и 'кормить' (копия другому типу)"""
	for child in farm_list.get_children():
		child.queue_free()
	if not lab_data:
		return
	farm_title_label.text = Loc.t("farm.title")

	# Режим кормления: маршрут бака виден заранее
	if not _feed_fodder.is_empty():
		var fodder_type: String = _feed_fodder[0]
		var fodder_stars: int = lab_data.get_mutant_stars(fodder_type)
		farm_list.add_child(_make_farm_section(Loc.t("farm.feed_hint")))
		var cancel := Button.new()
		cancel.text = Loc.t("lab.back")
		cancel.pressed.connect(_on_feed_cancel)
		farm_list.add_child(cancel)
		var found := false
		for type in lab_data.unlocked_mutants:
			if type == fodder_type or lab_data.get_farm_copies(type) <= 0:
				continue
			found = true
			var t_stars: int = lab_data.get_mutant_stars(type)
			var to_star_bucket: bool = fodder_stars == t_stars and lab_data.get_star_feed(type) < 1
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 6)
			row.add_child(_make_icon_rect(type, true, 26))
			var name_label := Label.new()
			name_label.text = "%s %s (%s) - (%s)" % [
				Loc.type_name(type), LabData.stars_text(t_stars),
				Loc.t("farm.progress", {"cur": lab_data.get_star_progress(type), "need": GachaData.get_star_feed_cost(t_stars)}),
				Loc.t("farm.star_feed_mark") if to_star_bucket else Loc.t("farm.simple_feed_mark")]
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(name_label)
			var btn := Button.new()
			btn.text = Loc.t("farm.feed_btn")
			btn.pressed.connect(_on_feed_confirm.bind(type))
			row.add_child(btn)
			farm_list.add_child(row)
		if not found:
			var none := Label.new()
			none.text = Loc.t("farm.empty")
			farm_list.add_child(none)
		return

	# Режим утилизации
	if _recycle_mode:
		_rebuild_farm_recycle()
		return

	# Обычный режим: строки рецепта v3 (копии + звёздный корм + простой корм)
	var recycle_row := HBoxContainer.new()
	var recycle_btn := Button.new()
	recycle_btn.text = Loc.t("farm.recycle_btn")
	recycle_btn.custom_minimum_size = Vector2(0, 34)
	recycle_btn.pressed.connect(_on_recycle_pressed)
	recycle_row.add_child(recycle_btn)
	farm_list.add_child(recycle_row)
	farm_list.add_child(_make_farm_section(Loc.t("farm.recipe")))
	var any_row := false
	for type in lab_data.unlocked_mutants:
		var req: Dictionary = game_manager.get_star_requirements(type)
		if int(req.get("copies_have")) <= 0 and int(req.get("star_have")) <= 0 and int(req.get("simple_have")) <= 0:
			continue
		any_row = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		row.add_child(_make_icon_rect(type, true, 26))
		var stars: int = int(req.get("stars"))
		var name_label := Label.new()
		name_label.text = "%s %s" % [Loc.type_name(type), LabData.stars_text(stars)]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var req_label := Label.new()
		req_label.text = "%s · %s · %s" % [
			Loc.t("farm.copies_need", {"have": int(req.get("copies_have")), "need": int(req.get("copies_need"))}),
			Loc.t("farm.star_feed", {"have": int(req.get("star_have")), "need": int(req.get("star_need"))}),
			Loc.t("farm.simple_feed", {"have": int(req.get("simple_have")), "need": int(req.get("simple_need"))})]
		req_label.add_theme_font_size_override("font_size", 9)
		req_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(req_label)
		if bool(req.get("max")):
			var max_label := Label.new()
			max_label.text = Loc.t("stars.max")
			row.add_child(max_label)
		else:
			var up_btn := Button.new()
			up_btn.text = "↑%d★" % (stars + 1)
			up_btn.tooltip_text = Loc.t("farm.upgrade_btn", {"n": stars + 1})
			up_btn.custom_minimum_size = Vector2(52, 0)
			up_btn.pressed.connect(_on_farm_upgrade.bind(type))
			row.add_child(up_btn)
			if lab_data.get_farm_copies(type) > 0:
				var feed_btn := Button.new()
				feed_btn.text = "🍽"
				feed_btn.tooltip_text = Loc.t("farm.feed_btn")
				feed_btn.custom_minimum_size = Vector2(36, 0)
				feed_btn.pressed.connect(_on_farm_feed_pressed.bind(type))
				row.add_child(feed_btn)
		farm_list.add_child(row)

	if not any_row:
		var empty := Label.new()
		empty.text = Loc.t("farm.empty")
		farm_list.add_child(empty)


func _make_farm_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label



func _on_farm_feed_pressed(type: String):
	_play_click_sound()
	_feed_fodder = [type]
	_rebuild_farm_panel()


func _on_feed_cancel():
	_play_click_sound()
	_feed_fodder.clear()
	_rebuild_farm_panel()


func _on_feed_confirm(target_type: String):
	_play_click_sound()
	var msg: String = game_manager.feed_fodder(_feed_fodder[0], target_type)
	_show_message(msg, 2.0)
	_feed_fodder.clear()
	_rebuild_farm_panel()
	_refresh_ui()


# ==================== ЯЗЫК ====================

var _lang_button: Button = null


func _build_language_button():
	"""Кнопка RU/EN в настройках лаборатории"""
	var panel = get_node_or_null("SettingsScreen/Panel")
	if not panel:
		return
	_lang_button = Button.new()
	_lang_button.text = Loc.t("menu.language")
	_lang_button.position = Vector2(30, 262)
	_lang_button.size = Vector2(340, 34)
	_lang_button.pressed.connect(_on_language_pressed)
	_lang_button.mouse_entered.connect(_play_hover_sound)
	panel.add_child(_lang_button)


func _on_language_pressed():
	_play_click_sound()
	Loc.toggle()


# ==================== ГАЧА ====================

var gacha_panel: Control
var gacha_list: VBoxContainer
# Сессионная статистика шансов: [всего, common, uncommon, rare, legendary]
var _mutant_spin_stats: Array = [0, 0, 0, 0, 0]
var _artifact_spin_stats: Array = [0, 0, 0, 0, 0]
# Последние дропы для показа
var _mutant_last_drops: Array = []
var _artifact_last_drops: Array = []


func _build_gacha_ui():
	"""Кнопка ГАЧА в нижнем ряду + панель круток со статистикой шансов"""
	var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
	if bottom:
		var gacha_btn := Button.new()
		gacha_btn.name = "GachaButton"
		gacha_btn.text = "ГАЧА"
		gacha_btn.pressed.connect(_on_gacha_pressed)
		gacha_btn.mouse_entered.connect(_play_hover_sound)
		_add_primary_action(gacha_btn, bottom)

	gacha_panel = Control.new()
	gacha_panel.name = "GachaPanel"
	gacha_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	gacha_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	gacha_panel.visible = false
	add_child(gacha_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	gacha_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	gacha_panel.add_child(panel)

	var title := Label.new()
	title.text = Loc.t("gacha.title")
	title.position = Vector2(0, 10)
	title.size = Vector2(560, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 44)
	scroll.size = Vector2(520, 308)
	panel.add_child(scroll)

	gacha_list = VBoxContainer.new()
	gacha_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gacha_list.add_theme_constant_override("separation", 4)
	scroll.add_child(gacha_list)

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_gacha_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_gacha_pressed():
	_play_click_sound()
	shop_panel.visible = false
	farm_panel.visible = false
	star_panel.visible = false
	gacha_panel.visible = true
	_rebuild_gacha_panel()


func _on_gacha_close_pressed():
	_play_click_sound()
	gacha_panel.visible = false


func _gacha_spin_buttons(kind: String) -> Control:
	"""Ряд кнопок круток x1/x10/x100/x1000"""
	var row := HBoxContainer.new()
	for times in [1, 10, 100, 1000]:
		var btn := Button.new()
		btn.text = "x%d" % times
		btn.custom_minimum_size = Vector2(70, 30)
		btn.pressed.connect(_on_gacha_spin.bind(kind, times))
		btn.mouse_entered.connect(_play_hover_sound)
		row.add_child(btn)
	return row


func _on_gacha_spin(kind: String, times: int):
	_play_click_sound()
	var results: Array = []
	if kind == "mutants":
		results = game_manager.spin_mutant_gacha(times)
		for r in results:
			_mutant_spin_stats[0] += 1
			var idx: int = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}.get(str(r.get("rarity")), 1)
			_mutant_spin_stats[idx] += 1
			_mutant_last_drops.push_front(r)
			while _mutant_last_drops.size() > 8:
				_mutant_last_drops.pop_back()
	else:
		results = game_manager.spin_artifact_gacha(times)
		for r in results:
			_artifact_spin_stats[0] += 1
			var idx: int = {"common": 1, "uncommon": 2, "rare": 3, "legendary": 4}.get(str(r.get("rarity")), 1)
			_artifact_spin_stats[idx] += 1
			_artifact_last_drops.push_front(r)
			while _artifact_last_drops.size() > 8:
				_artifact_last_drops.pop_back()
	if results.is_empty():
		_show_message(Loc.t("gacha.no_rolls"), 1.5)
	_rebuild_gacha_panel()
	_refresh_ui()


func _make_drop_row(r: Dictionary, is_mutant: bool) -> Control:
	"""Строка дропа гачи: карточка-иконка + имя, окрашенное по редкости"""
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.add_child(_make_icon_rect(str(r.get("type", "")), is_mutant, 24))
	var label := Label.new()
	label.text = _format_drop(r)
	label.add_theme_color_override("font_color", GachaData.rarity_color(str(r.get("rarity", "common"))))
	return row


func _format_drop(r: Dictionary) -> String:
	var rarity: String = str(r.get("rarity", "common"))
	var line: String = "[%s] %s" % [Loc.t("rarity." + rarity), Loc.type_name(str(r.get("type")))]
	match str(r.get("status", "")):
		"new":
			line += " - " + Loc.t("gacha.new_mark")
		"dup":
			line += " - " + Loc.t("gacha.dup_mark")
		"star":
			line += " - " + Loc.t("gacha.star_mark")
	return line


func _gacha_stats_line(stats: Array, has_uncommon: bool) -> String:
	var total: int = stats[0]
	if total <= 0:
		return ""
	var pct := func(n: int) -> String:
		return "%.1f" % (100.0 * float(n) / float(total))
	if has_uncommon:
		return Loc.t("gacha.stats", {"n": total, "cp": pct.call(stats[1]), "up": pct.call(stats[2]), "rp": pct.call(stats[3]), "lp": pct.call(stats[4])})
	return Loc.t("gacha.stats_short", {"n": total, "cp": pct.call(stats[1]), "rp": pct.call(stats[3]), "lp": pct.call(stats[4])})


func _rebuild_gacha_panel():
	"""Два рукава гачи: крутки, кнопки, статистика шансов, последние дропы"""
	for child in gacha_list.get_children():
		child.queue_free()
	if not lab_data or not game_manager:
		return

	var level_line := Label.new()
	level_line.text = Loc.t("gacha.level_used", {"n": game_manager.get_campaign_level()})
	gacha_list.add_child(level_line)

	# === МУТАНТЫ ===
	gacha_list.add_child(_make_star_section(Loc.t("gacha.mutants_header")))
	var mut_rolls := Label.new()
	mut_rolls.text = Loc.t("gacha.rolls", {"n": lab_data.gacha_rolls_mutants})
	gacha_list.add_child(mut_rolls)
	gacha_list.add_child(_gacha_spin_buttons("mutants"))
	var mut_stats := Label.new()
	mut_stats.text = _gacha_stats_line(_mutant_spin_stats, true)
	if not mut_stats.text.is_empty():
		gacha_list.add_child(mut_stats)
	if not _mutant_last_drops.is_empty():
		gacha_list.add_child(_make_star_section(Loc.t("gacha.last_drops")))
		for r in _mutant_last_drops:
			gacha_list.add_child(_make_drop_row(r, true))

	# === АРТЕФАКТЫ ===
	gacha_list.add_child(_make_star_section(Loc.t("gacha.artifacts_header")))
	var art_rolls := Label.new()
	art_rolls.text = Loc.t("gacha.rolls", {"n": lab_data.gacha_rolls_artifacts})
	gacha_list.add_child(art_rolls)
	gacha_list.add_child(_gacha_spin_buttons("artifacts"))
	var art_stats := Label.new()
	art_stats.text = _gacha_stats_line(_artifact_spin_stats, false)
	if not art_stats.text.is_empty():
		gacha_list.add_child(art_stats)
	if not _artifact_last_drops.is_empty():
		gacha_list.add_child(_make_star_section(Loc.t("gacha.last_drops")))
		for r in _artifact_last_drops:
			gacha_list.add_child(_make_drop_row(r, false))


# ==================== ГАЛЕРЕЯ ====================

var gallery_panel: Control
var gallery_list: VBoxContainer


func _build_gallery_ui():
	"""Кнопка ГАЛЕРЕЯ + панель коллекции: открытые цветные, закрытые серые"""
	var bottom: HBoxContainer = get_node_or_null("VBox/BottomButtons")
	if bottom:
		var gal_btn := Button.new()
		gal_btn.name = "GalleryButton"
		gal_btn.text = Loc.t("lab.gallery")
		gal_btn.pressed.connect(_on_gallery_pressed)
		gal_btn.mouse_entered.connect(_play_hover_sound)
		_add_primary_action(gal_btn, bottom)

	gallery_panel = Control.new()
	gallery_panel.name = "GalleryPanel"
	gallery_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	gallery_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	gallery_panel.visible = false
	add_child(gallery_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	gallery_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -280.0
	panel.offset_top = -210.0
	panel.offset_right = 280.0
	panel.offset_bottom = 210.0
	gallery_panel.add_child(panel)

	var title := Label.new()
	title.text = Loc.t("gallery.title")
	title.position = Vector2(0, 10)
	title.size = Vector2(560, 25)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 44)
	scroll.size = Vector2(520, 308)
	panel.add_child(scroll)

	gallery_list = VBoxContainer.new()
	gallery_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gallery_list.add_theme_constant_override("separation", 6)
	scroll.add_child(gallery_list)

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.position = Vector2(200, 362)
	close_btn.size = Vector2(160, 35)
	close_btn.pressed.connect(_on_gallery_close_pressed)
	close_btn.mouse_entered.connect(_play_hover_sound)
	panel.add_child(close_btn)


func _on_gallery_pressed():
	_play_click_sound()
	shop_panel.visible = false
	farm_panel.visible = false
	star_panel.visible = false
	gacha_panel.visible = false
	gallery_panel.visible = true
	_rebuild_gallery_panel()


func _on_gallery_close_pressed():
	_play_click_sound()
	gallery_panel.visible = false


func _gallery_tile(type: String, is_mutant: bool) -> Control:
	"""Плитка карточки: цветная если открыто, серая если нет"""
	var unlocked: bool = lab_data.unlocked_mutants.has(type) if is_mutant else lab_data.won_artifacts.has(type)
	var tile := VBoxContainer.new()
	tile.custom_minimum_size = Vector2(82, 0)
	tile.add_theme_constant_override("separation", 2)
	tile.alignment = BoxContainer.ALIGNMENT_BEGIN

	var rect := TextureRect.new()
	rect.texture = load(GachaData.card_icon_path(type, is_mutant, not unlocked))
	rect.custom_minimum_size = Vector2(72, 72)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		rect.modulate = Color(0.85, 0.85, 0.9, 0.9)
	tile.add_child(rect)

	var name_label := Label.new()
	name_label.text = Loc.type_name(type)
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.custom_minimum_size = Vector2(82, 0)
	name_label.add_theme_color_override("font_color", GachaData.rarity_color(GachaData.get_artifact_rarity(type) if not is_mutant else GachaData.get_mutant_rarity(type)) if unlocked else Color(0.5, 0.5, 0.55))
	tile.add_child(name_label)

	var stars_label := Label.new()
	var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
	stars_label.text = LabData.stars_text(stars) if unlocked else "🔒"
	stars_label.add_theme_font_size_override("font_size", 9)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stars_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25) if unlocked else Color(0.5, 0.5, 0.55))
	tile.add_child(stars_label)

	var unlock_level: int = GachaData.get_unlock_campaign_level(type)
	tile.tooltip_text = Loc.t("gallery.unlocked_tip") if unlocked else Loc.t("gallery.locked_tip", {"n": unlock_level})
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.gui_input.connect(_on_gallery_tile_input.bind(type, is_mutant, unlocked))
	return tile


func _on_gallery_tile_input(event: InputEvent, type: String, is_mutant: bool, unlocked: bool):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_play_click_sound()
		_show_card_detail(type, is_mutant, unlocked)


# ==================== КАРТОЧКА-ПРОСМОТР ====================

var detail_panel: Control
var detail_image: TextureRect
var detail_name: Label
var detail_meta: Label
var detail_desc: Label


func _build_card_detail():
	"""Большая карточка: арт художника (PNG) + описание. Открывается кликом по плитке"""
	detail_panel = Control.new()
	detail_panel.name = "CardDetail"
	detail_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	detail_panel.visible = false
	add_child(detail_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.7)
	shade.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			detail_panel.visible = false)
	detail_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -230.0
	panel.offset_top = -230.0
	panel.offset_right = 230.0
	panel.offset_bottom = 230.0
	detail_panel.add_child(panel)

	detail_image = TextureRect.new()
	detail_image.position = Vector2(110, 16)
	detail_image.size = Vector2(240, 240)
	detail_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	detail_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.add_child(detail_image)

	detail_name = Label.new()
	detail_name.position = Vector2(20, 262)
	detail_name.size = Vector2(420, 26)
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_name.add_theme_font_size_override("font_size", 17)
	panel.add_child(detail_name)

	detail_meta = Label.new()
	detail_meta.position = Vector2(20, 290)
	detail_meta.size = Vector2(420, 20)
	detail_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_meta.add_theme_font_size_override("font_size", 11)
	panel.add_child(detail_meta)

	detail_desc = Label.new()
	detail_desc.position = Vector2(30, 318)
	detail_desc.size = Vector2(400, 90)
	detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	detail_desc.add_theme_font_size_override("font_size", 11)
	detail_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(detail_desc)

	var close := Button.new()
	close.text = Loc.t("lab.back")
	close.position = Vector2(150, 412)
	close.size = Vector2(160, 34)
	close.pressed.connect(func(): _play_click_sound(); detail_panel.visible = false)
	panel.add_child(close)


func _show_card_detail(type: String, is_mutant: bool, unlocked: bool):
	"""Заполнить карточку: большой арт (PNG художника или SVG), имя, редкость,
	звёзды, описание, открываемая аномалия"""
	if not detail_panel:
		_build_card_detail()
	var rarity: String = GachaData.get_mutant_rarity(type) if is_mutant else GachaData.get_artifact_rarity(type)
	var rarity_color: Color = GachaData.rarity_color(rarity)

	detail_image.texture = load(GachaData.card_icon_path(type, is_mutant, not unlocked))
	detail_image.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.85, 0.85, 0.9, 0.9)

	detail_name.text = Loc.type_name(type)
	detail_name.add_theme_color_override("font_color", rarity_color if unlocked else Color(0.6, 0.6, 0.65))

	var meta_parts: Array[String] = [Loc.t("card.rarity", {"r": Loc.t("rarity." + rarity)})]
	if unlocked:
		var stars: int = lab_data.get_mutant_stars(type) if is_mutant else lab_data.get_artifact_stars(type)
		meta_parts.append("%s %s" % [LabData.stars_text(stars), Loc.t("stars.mult_tip", {"n": "%.1f" % LabData.get_star_stat_mult(stars)})])
	else:
		meta_parts.append(Loc.t("card.locked"))
	if not is_mutant:
		var anomaly: String = GachaData.get_anomaly_for_artifact(type)
		if not anomaly.is_empty():
			meta_parts.append(Loc.t("card.opens_anomaly", {"n": Loc.t("an." + _anomaly_loc_key(anomaly))}))
	detail_meta.text = "   ".join(meta_parts)
	detail_meta.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))

	detail_desc.text = Loc.t("desc." + type)
	detail_panel.visible = true


## anomaly_type "heat_anomaly" -> ключ локализации "heat"
func _anomaly_loc_key(anomaly_type: String) -> String:
	var key: String = anomaly_type
	for suf in ["gravity_", "thermal_", "chemical_", "electric_", "bio_"]:
		key = key.trim_prefix(suf)
	key = key.trim_suffix("_anomaly")
	match key:
		"radiation_hotspot":
			key = "radiation"
		"time_dilation":
			key = "time"
		"teleport":
			key = "teleport"
		"acid_cloud":
			key = "acid_cloud"
	return key


func _rebuild_gallery_panel():
	"""Все мутанты и арты: открытые цветные, закрытые серые силуэты"""
	for child in gallery_list.get_children():
		child.queue_free()
	if not lab_data:
		return

	gallery_list.add_child(_make_farm_section(Loc.t("lab.mutants")))
	var mut_grid := GridContainer.new()
	mut_grid.columns = 6
	mut_grid.add_theme_constant_override("h_separation", 4)
	mut_grid.add_theme_constant_override("v_separation", 4)
	gallery_list.add_child(mut_grid)
	for entry in GachaData.MUTANT_POOL.values():
		for e in entry:
			mut_grid.add_child(_gallery_tile(str(e[0]), true))

	gallery_list.add_child(_gallery_section(" "))
	gallery_list.add_child(_gallery_section(Loc.t("shop.artifacts_header").split(" (")[0]))
	var art_grid := GridContainer.new()
	art_grid.columns = 6
	art_grid.add_theme_constant_override("h_separation", 4)
	art_grid.add_theme_constant_override("v_separation", 4)
	gallery_list.add_child(art_grid)
	for rarity in GachaData.ARTIFACT_POOL.values():
		for type in rarity:
			art_grid.add_child(_gallery_tile(str(type), false))


func _gallery_section(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


# ==================== ДИАЛОГ ПОВЫШЕНИЯ ЗВЕЗДЫ ====================

var up_panel: Control
var up_title: Label
var up_body: VBoxContainer
# Состояние сбора рецепта
var _up_target: String = ""
var _up_copies: int = 0
var _up_star_feed: String = ""
var _up_simple: Dictionary = {}
var _up_chooser: String = ""  # "" | "star" | "simple"


func _build_upgrade_dialog():
	"""Окно повышения: слоты копий/звёздного/простого корма с '+', ОК применяет"""
	up_panel = Control.new()
	up_panel.name = "UpgradeStarDialog"
	up_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	up_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	up_panel.visible = false
	add_child(up_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.7)
	shade.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			_close_upgrade_dialog())
	up_panel.add_child(shade)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240.0
	panel.offset_top = -210.0
	panel.offset_right = 240.0
	panel.offset_bottom = 210.0
	up_panel.add_child(panel)

	up_title = Label.new()
	up_title.position = Vector2(20, 12)
	up_title.size = Vector2(440, 24)
	up_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	up_title.add_theme_font_size_override("font_size", 14)
	panel.add_child(up_title)

	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 44)
	scroll.size = Vector2(440, 300)
	panel.add_child(scroll)

	up_body = VBoxContainer.new()
	up_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	up_body.add_theme_constant_override("separation", 6)
	scroll.add_child(up_body)

	var back := Button.new()
	back.text = Loc.t("lab.back")
	back.position = Vector2(160, 356)
	back.size = Vector2(160, 34)
	back.pressed.connect(_close_upgrade_dialog)
	panel.add_child(back)


func _on_farm_upgrade(type: String):
	"""↑N★ - открыть окно сбора рецепта по этому мутанту"""
	_play_click_sound()
	_up_target = type
	_up_copies = 0
	_up_star_feed = ""
	_up_simple.clear()
	_up_chooser = ""
	if not up_panel:
		_build_upgrade_dialog()
	farm_panel.visible = false
	up_panel.visible = true
	_rebuild_upgrade_dialog()


func _close_upgrade_dialog():
	up_panel.visible = false
	_up_target = ""
	_up_chooser = ""


func _up_remaining_simple() -> int:
	var req: Dictionary = game_manager.get_star_requirements(_up_target)
	return maxi(0, int(req.get("simple_need")) - int(req.get("simple_have")))


func _up_pending_simple_total() -> int:
	var total := 0
	for t in _up_simple:
		total += int(_up_simple[t])
	return total


func _rebuild_upgrade_dialog():
	for child in up_body.get_children():
		child.queue_free()
	if _up_target.is_empty():
		return
	var lab = get_tree().get_first_node_in_group("game_manager").get_lab_data()
	var stars: int = lab.get_mutant_stars(_up_target)
	var req: Dictionary = game_manager.get_star_requirements(_up_target)
	up_title.text = Loc.t("up.title", {"name": Loc.type_name(_up_target), "n": stars + 1})

	# Режим выбора корма
	if _up_chooser != "":
		_rebuild_upgrade_chooser()
		return

	# --- Слот 1: копии цели ---
	var copies_row := HBoxContainer.new()
	copies_row.add_theme_constant_override("separation", 6)
	var copies_label := Label.new()
	var copies_have: int = int(req.get("copies_have"))
	copies_label.text = Loc.t("up.copies_slot", {"have": _up_copies, "need": copies_have})
	copies_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copies_row.add_child(copies_label)
	if _up_copies < stars + 1:
		var add_copies := Button.new()
		add_copies.text = Loc.t("up.copies_btn", {"n": stars + 1})
		add_copies.tooltip_text = Loc.t("up.copies_slot", {"have": copies_have, "need": stars + 1})
		add_copies.pressed.connect(_on_up_add_copies.bind(stars + 1))
		copies_row.add_child(add_copies)
	elif _up_copies > 0:
		var done1 := Label.new()
		done1.text = Loc.t("up.done_mark")
		copies_row.add_child(done1)
	up_body.add_child(copies_row)

	# --- Слот 2: звёздный корм ---
	var star_row := HBoxContainer.new()
	star_row.add_theme_constant_override("separation", 6)
	var star_label := Label.new()
	var star_text: String = Loc.t("up.star_slot", {"n": stars})
	if int(req.get("star_have")) >= 1:
		star_text += Loc.t("up.star_filled")
	elif not _up_star_feed.is_empty():
		star_text += Loc.type_name(_up_star_feed)
	star_label.text = star_text
	star_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	star_row.add_child(star_label)
	if int(req.get("star_have")) < 1:
		var add_star := Button.new()
		add_star.text = Loc.t("farm.star_btn")
		add_star.pressed.connect(_on_up_pick_star)
		star_row.add_child(add_star)
	up_body.add_child(star_row)

	# --- Слот 3: простой корм ---
	var simple_row := HBoxContainer.new()
	simple_row.add_theme_constant_override("separation", 6)
	var simple_label := Label.new()
	var simple_total: int = int(req.get("simple_have")) + _up_pending_simple_total()
	var simple_text: String = Loc.t("up.simple_slot", {"have": simple_total, "need": int(req.get("simple_need"))})
	var parts := []
	for t in _up_simple:
		parts.append("%s x%d" % [Loc.type_name(str(t)), int(_up_simple[t])])
	if not parts.is_empty():
		simple_text += "   " + " · ".join(parts)
	simple_label.text = simple_text
	simple_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	simple_row.add_child(simple_label)
	var add_simple := Button.new()
	add_simple.text = Loc.t("farm.star_btn")
	add_simple.pressed.connect(_on_up_pick_simple)
	simple_row.add_child(add_simple)
	if not _up_simple.is_empty():
		var reset_btn := Button.new()
		reset_btn.text = Loc.t("up.reset")
		reset_btn.pressed.connect(_on_up_reset_simple)
		simple_row.add_child(reset_btn)
	up_body.add_child(simple_row)

	# --- АВТО: заполнить всё из слабых и многочисленных ---
	var auto_btn := Button.new()
	auto_btn.text = Loc.t("up.auto")
	auto_btn.custom_minimum_size = Vector2(0, 34)
	auto_btn.pressed.connect(_on_up_auto)
	up_body.add_child(auto_btn)

	# --- ОК ---
	var ok_btn := Button.new()
	ok_btn.text = Loc.t("up.ok")
	ok_btn.custom_minimum_size = Vector2(0, 40)
	var copies_need: int = stars + 1
	var has_enough: bool = _up_copies >= copies_need and (int(req.get("star_have")) >= 1 or not _up_star_feed.is_empty()) and simple_total >= int(req.get("simple_need"))
	ok_btn.disabled = not has_enough
	ok_btn.pressed.connect(_on_up_confirm)
	up_body.add_child(ok_btn)
	if not ready:
		var hint := Label.new()
		hint.text = Loc.t("up.not_ready")
		hint.add_theme_font_size_override("font_size", 9)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		up_body.add_child(hint)


func _on_up_add_copies(max_copies: int):
	_play_click_sound()
	# Кламп к потребности рецепта: лишние копии не сжигаем
	var stars: int = game_manager.get_lab_data().get_mutant_stars(_up_target)
	_up_copies = mini(max_copies, stars + 1)
	_rebuild_upgrade_dialog()


func _on_up_pick_star():
	_play_click_sound()
	_up_chooser = "star"
	_rebuild_upgrade_dialog()


func _on_up_pick_simple():
	_play_click_sound()
	_up_chooser = "simple"
	_rebuild_upgrade_dialog()


func _on_up_reset_simple():
	_play_click_sound()
	_up_simple.clear()
	_rebuild_upgrade_dialog()


func _on_up_confirm():
	_play_click_sound()
	var msg: String = game_manager.apply_star_recipe(_up_target, _up_copies, _up_star_feed, _up_simple)
	_show_message(msg, 2.0)
	_close_upgrade_dialog()
	_rebuild_farm_panel()
	_refresh_ui()


func _rebuild_upgrade_chooser():
	var lab = get_tree().get_first_node_in_group("game_manager").get_lab_data()
	var target_stars: int = lab.get_mutant_stars(_up_target)
	var header := Label.new()
	if _up_chooser == "star":
		header.text = Loc.t("up.pick_star", {"n": target_stars})
	else:
		header.text = Loc.t("up.pick_simple")
	up_body.add_child(header)

	var found := false
	for type in lab.unlocked_mutants:
		if type == _up_target or lab.get_farm_copies(type) <= 0:
			continue
		var t_stars: int = lab.get_mutant_stars(type)
		if _up_chooser == "star" and t_stars != target_stars:
			continue
		found = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_make_icon_rect(type, true, 26))
		var name_label := Label.new()
		name_label.text = "%s %s - %s" % [Loc.type_name(type), LabData.stars_text(t_stars), Loc.t("farm.copies", {"n": lab.get_farm_copies(type)})]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		if _up_chooser == "star":
			var pick := Button.new()
			pick.text = Loc.t("up.ok").replace("★ ", "")
			pick.pressed.connect(_on_up_choose_star.bind(type))
			row.add_child(pick)
		else:
			var available: int = lab.get_farm_copies(type)
			var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
			for qty in [1, 5]:
				if qty <= available and qty <= remaining:
					var q_btn := Button.new()
					q_btn.text = "+%d" % qty
					q_btn.pressed.connect(_on_up_choose_simple.bind(type, qty))
					row.add_child(q_btn)
			if available > 0 and remaining > 0:
				var max_btn := Button.new()
				max_btn.text = Loc.t("up.qty_max")
				max_btn.pressed.connect(_on_up_choose_simple.bind(type, mini(available, remaining)))
				row.add_child(max_btn)
		up_body.add_child(row)
	# Копии самого мутанта тоже годятся в корм (бюджет проверит ОК)
	var self_copies: int = lab.get_farm_copies(_up_target)
	var self_ok := false
	if self_copies > 0:
		if _up_chooser == "simple":
			self_ok = true
		elif _up_chooser == "star" and target_stars == lab.get_mutant_stars(_up_target):
			self_ok = true  # цель всегда своей звёздности
	if self_ok:
		var srow := HBoxContainer.new()
		srow.add_theme_constant_override("separation", 6)
		srow.add_child(_make_icon_rect(_up_target, true, 26))
		var slabel := Label.new()
		slabel.text = "%s %s - %s %s" % [Loc.type_name(_up_target), LabData.stars_text(lab.get_mutant_stars(_up_target)), Loc.t("farm.copies", {"n": self_copies}), Loc.t("up.self_mark")]
		slabel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		srow.add_child(slabel)
		if _up_chooser == "star":
			var pick := Button.new()
			pick.text = Loc.t("up.ok").replace("★ ", "")
			pick.pressed.connect(_on_up_choose_star.bind(_up_target))
			srow.add_child(pick)
		else:
			var available: int = lab.get_farm_copies(_up_target)
			var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
			for qty in [1, 5]:
				if qty <= available and qty <= remaining:
					var q_btn := Button.new()
					q_btn.text = "+%d" % qty
					q_btn.pressed.connect(_on_up_choose_simple.bind(_up_target, qty))
					srow.add_child(q_btn)
			if available > 0 and remaining > 0:
				var max_btn := Button.new()
				max_btn.text = Loc.t("up.qty_max")
				max_btn.pressed.connect(_on_up_choose_simple.bind(_up_target, mini(available, remaining)))
				srow.add_child(max_btn)
		up_body.add_child(srow)
		found = true
	if not found:
		var none := Label.new()
		none.text = Loc.t("farm.empty")
		up_body.add_child(none)

	var cancel := Button.new()
	cancel.text = Loc.t("lab.back")
	cancel.pressed.connect(_on_up_cancel_chooser)
	up_body.add_child(cancel)


func _on_up_choose_star(type: String):
	_play_click_sound()
	_up_star_feed = type
	_up_chooser = ""
	_rebuild_upgrade_dialog()


func _on_up_choose_simple(type: String, qty: int):
	_play_click_sound()
	_up_simple[type] = int(_up_simple.get(type, 0)) + qty
	# Если больше нечего выбирать - вернуться к слотам
	var lab = get_tree().get_first_node_in_group("game_manager").get_lab_data()
	var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
	var any_left := false
	for t in lab.unlocked_mutants:
		if t != _up_target and lab.get_farm_copies(t) > 0:
			any_left = true
			break
	if remaining <= 0 or not any_left:
		_up_chooser = ""
	_rebuild_upgrade_dialog()


func _on_up_cancel_chooser():
	_play_click_sound()
	_up_chooser = ""
	_rebuild_upgrade_dialog()


## АВТО: копии цели + слабейший звёздный корм + простой корм из 1★ по запасам
func _on_up_auto():
	_play_click_sound()
	var lab = game_manager.get_lab_data()
	if _up_target.is_empty():
		return
	var stars: int = lab.get_mutant_stars(_up_target)
	var req: Dictionary = game_manager.get_star_requirements(_up_target)

	# 1. Копии цели - ровно потребность (не больше, лишние копии не сжигаем)
	_up_copies = mini(int(req.get("copies_have")), stars + 1)

	# 2. Звёздный корм: чужие той же звёздности; если их нет - копии самого типа
	if int(req.get("star_have")) < 1:
		var cands: Array[String] = []
		for t in lab.unlocked_mutants:
			if t != _up_target and lab.get_mutant_stars(t) == stars and lab.get_farm_copies(t) > 0:
				cands.append(str(t))
		cands.sort_custom(func(a, b):
			var ca: int = lab.get_farm_copies(a)
			var cb: int = lab.get_farm_copies(b)
			if ca != cb:
				return ca > cb
			return GachaData.get_fodder_value(a, true) < GachaData.get_fodder_value(b, true))
		if not cands.is_empty():
			_up_star_feed = cands[0]
		elif lab.get_farm_copies(_up_target) > _up_copies:
			_up_star_feed = _up_target  # свои копии в звёздный бак

	# 3. Простой корм: сначала 1★-кормовые по запасам, затем прочие не-звёздные
	var remaining: int = _up_remaining_simple() - _up_pending_simple_total()
	var simple_cands: Array[String] = []
	var other_cands: Array[String] = []
	for t in lab.unlocked_mutants:
		if t == _up_target or t == _up_star_feed or lab.get_farm_copies(t) <= 0:
			continue
		if lab.get_mutant_stars(t) == 1:
			simple_cands.append(str(t))
		elif lab.get_mutant_stars(t) != stars:
			other_cands.append(str(t))
	simple_cands.sort_custom(func(a, b):
		var ca: int = lab.get_farm_copies(a)
		var cb: int = lab.get_farm_copies(b)
		if ca != cb:
			return ca > cb
		return GachaData.get_fodder_value(a, true) < GachaData.get_fodder_value(b, true))
	other_cands.sort_custom(func(a, b):
		var ca: int = lab.get_farm_copies(a)
		var cb: int = lab.get_farm_copies(b)
		if ca != cb:
			return ca > cb
		return GachaData.get_fodder_value(a, true) < GachaData.get_fodder_value(b, true))
	for t in simple_cands + other_cands:
		if remaining <= 0:
			break
		var take: int = mini(lab.get_farm_copies(t), remaining)
		if take > 0:
			_up_simple[t] = int(_up_simple.get(t, 0)) + take
			remaining -= take
	# Резерв: копии самого мутанта (не занятые слотом копий и звёздным)
	if remaining > 0:
		var self_used: int = int(_up_simple.get(_up_target, 0))
		if _up_star_feed == _up_target:
			self_used += 1
		var spare: int = lab.get_farm_copies(_up_target) - _up_copies - self_used
		if spare > 0:
			_up_simple[_up_target] = int(_up_simple.get(_up_target, 0)) + mini(spare, remaining)

	_rebuild_upgrade_dialog()


# ==================== УТИЛИЗАЦИЯ КОПИЙ ====================

var _recycle_mode: bool = false
var _recycle_batch: Dictionary = {}


func _on_recycle_pressed():
	_play_click_sound()
	_recycle_mode = true
	_recycle_batch.clear()
	_rebuild_farm_panel()


func _on_recycle_cancel():
	_play_click_sound()
	_recycle_mode = false
	_recycle_batch.clear()
	_rebuild_farm_panel()


func _recycle_pending_points() -> int:
	var points: int = 0
	for t in _recycle_batch:
		points += GachaData.get_fodder_value(str(t), true) * int(_recycle_batch[t])
	return points


func _rebuild_farm_recycle():
	"""Сдача копий: очки по редкости, 10 очков = 1 крутка артефактов"""
	for child in farm_list.get_children():
		child.queue_free()
	if not lab_data:
		return

	var pending: int = _recycle_pending_points()
	var total: int = lab_data.recycle_points + pending
	var header := Label.new()
	header.text = Loc.t("farm.recycle_title")
	farm_list.add_child(header)
	var progress := Label.new()
	progress.text = Loc.t("farm.recycle_progress", {"points": total % 10 if total < 10 else 10, "consumed": pending, "left": lab_data.recycle_points})
	progress.add_theme_font_size_override("font_size", 10)
	farm_list.add_child(progress)
	# Прогресс полосой
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 10
	bar.value = total % 10
	bar.custom_minimum_size = Vector2(0, 16)
	farm_list.add_child(bar)
	# Уже гарантированные крутки из партии
	var ready_rolls := int(total / 10.0)
	if ready_rolls > 0:
		var ready_label := Label.new()
		ready_label.text = Loc.t("farm.recycle_confirm", {"n": ready_rolls})
		ready_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
		farm_list.add_child(ready_label)

	var found := false
	for type in lab_data.unlocked_mutants:
		var copies: int = lab_data.get_farm_copies(type)
		if copies <= 0:
			continue
		found = true
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_make_icon_rect(type, true, 26))
		var name_label := Label.new()
		var value: int = GachaData.get_fodder_value(type, true)
		name_label.text = "%s - %s (+%d)" % [Loc.type_name(type), Loc.t("farm.copies", {"n": copies}), value]
		name_label.tooltip_text = Loc.t("farm.value_tip", {"points": value})
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var pending_n: int = int(_recycle_batch.get(type, 0))
		if pending_n > 0:
			var mark := Label.new()
			mark.text = "x%d" % pending_n
			mark.add_theme_color_override("font_color", Color(1.0, 0.72, 0.25))
			row.add_child(mark)
		for qty in [1, 5, 10]:
			if qty <= copies:
				var q_btn := Button.new()
				q_btn.text = "+%d" % qty
				q_btn.pressed.connect(_on_recycle_add.bind(type, qty))
				row.add_child(q_btn)
		if pending_n > 0:
			var sub_btn := Button.new()
			sub_btn.text = "-%d" % pending_n
			sub_btn.pressed.connect(_on_recycle_remove.bind(type))
			row.add_child(sub_btn)
		farm_list.add_child(row)
	if not found:
		var none := Label.new()
		none.text = Loc.t("farm.recycle_nothing")
		farm_list.add_child(none)

	var confirm := Button.new()
	confirm.text = Loc.t("farm.recycle_confirm", {"n": ready_rolls})
	confirm.disabled = ready_rolls <= 0
	confirm.custom_minimum_size = Vector2(0, 36)
	confirm.pressed.connect(_on_recycle_confirm)
	farm_list.add_child(confirm)

	var cancel := Button.new()
	cancel.text = Loc.t("lab.back")
	cancel.pressed.connect(_on_recycle_cancel)
	farm_list.add_child(cancel)


func _on_recycle_add(type: String, qty: int):
	_play_click_sound()
	_recycle_batch[type] = int(_recycle_batch.get(type, 0)) + qty
	_rebuild_farm_panel()


func _on_recycle_remove(type: String):
	_play_click_sound()
	_recycle_batch.erase(type)
	_rebuild_farm_panel()


func _on_recycle_confirm():
	_play_click_sound()
	var result: Dictionary = game_manager.recycle_copies(_recycle_batch)
	if int(result.get("rolls", 0)) > 0:
		_show_message(Loc.t("farm.recycle_done", {"n": int(result.get("rolls", 0)), "c": int(result.get("consumed", 0))}), 2.5)
	else:
		_show_message(Loc.t("farm.recycle_zero"), 1.5)
	_recycle_batch.clear()
	_rebuild_farm_panel()
	_refresh_ui()




# ==================== БАШНЯ МОНОЛИТА ====================

func _on_tower_pressed():
	_play_click_sound()
	if tower_panel == null:
		_build_tower_panel()
	_selected_tower_floor = game_manager.get_tower_floor() if game_manager else 1
	_rebuild_tower_grid()
	tower_panel.visible = true


func _build_tower_panel():
	tower_panel = Control.new()
	tower_panel.name = "TowerPanel"
	tower_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	tower_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	tower_panel.visible = false
	add_child(tower_panel)

	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.72)
	tower_panel.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	tower_panel.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(980, 640)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "БАШНЯ МОНОЛИТА"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Сетка этажей 10x10 в прокручиваемом контейнере
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_tower_grid = GridContainer.new()
	_tower_grid.columns = 10
	_tower_grid.add_theme_constant_override("h_separation", 6)
	_tower_grid.add_theme_constant_override("v_separation", 6)
	_tower_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tower_grid)

	_tower_info = Label.new()
	_tower_info.add_theme_font_size_override("font_size", 15)
	_tower_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tower_info.custom_minimum_size = Vector2(0, 70)
	vbox.add_child(_tower_info)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	vbox.add_child(buttons)

	_tower_go_button = Button.new()
	_tower_go_button.text = "ИДТИ НА ЭТАЖ"
	_tower_go_button.custom_minimum_size = Vector2(220, 46)
	_tower_go_button.pressed.connect(_on_tower_go_pressed)
	buttons.add_child(_tower_go_button)

	var close_btn := Button.new()
	close_btn.text = "НАЗАД"
	close_btn.custom_minimum_size = Vector2(140, 46)
	close_btn.pressed.connect(_on_tower_close_pressed)
	buttons.add_child(close_btn)

	_tower_go_button.mouse_entered.connect(_play_hover_sound)
	close_btn.mouse_entered.connect(_play_hover_sound)


func _rebuild_tower_grid():
	if tower_panel == null or not game_manager:
		return

	for child in _tower_grid.get_children():
		child.queue_free()

	var frontier: int = game_manager.get_tower_floor()
	for f in range(1, TowerData.TOTAL_FLOORS + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(84, 52)
		var stars: int = game_manager.get_tower_stars(f)
		var star_text := ""
		for i in range(3):
			star_text += "★" if i < stars else "·"

		var floor_type: String = TowerData.get_floor_type(f)
		var label_text := str(f)
		if floor_type == "keeper":
			label_text = "☠" + str(f)
		elif floor_type == "break":
			label_text = "▲" + str(f)

		btn.text = label_text + "\n" + star_text

		if f > frontier:
			btn.disabled = true
			btn.tooltip_text = "Этаж закрыт - пройдите предыдущий"
		else:
			btn.tooltip_text = _tower_floor_tooltip(f)
		btn.pressed.connect(_on_tower_floor_selected.bind(f))

		# Цвета: Хранитель - красный, Прорыв - оранжевый, 3 звезды - зелёный,
		# рубеж - белый фон подсвечен
		match floor_type:
			"keeper":
				btn.modulate = Color(1.0, 0.55, 0.55)
			"break":
				btn.modulate = Color(1.0, 0.8, 0.55)
			_:
				btn.modulate = Color(0.6, 1.0, 0.6) if stars >= 3 else Color.WHITE
		if f == frontier:
			btn.self_modulate = Color(1, 1, 1, 1)
			btn.tooltip_text += "\nТЕКУЩИЙ РУБЕЖ"

		_tower_grid.add_child(btn)

	_tower_info.text = _tower_floor_info(_selected_tower_floor)


func _tower_floor_tooltip(f: int) -> String:
	var params: Dictionary = TowerData.get_floor_params(f)
	var rewards: Dictionary = TowerData.get_floor_rewards(f)
	var conds: Array = TowerData.get_star_conditions(f)
	var c2: Dictionary = TowerData.STAR_CONDITIONS[conds[0]]
	var c3: Dictionary = TowerData.STAR_CONDITIONS[conds[1]]
	return "%s\nВолн: %d | Сталкеров: %d-%d | Выбросов до победы: %d\n★★ %s - %s\n★★★ %s - %s\nНаграда: %d биомассы, +%d круток мутантов, +%d аномалий" % [
		params.get("title", ""),
		int(params.get("waves", 0)), int(params.get("count_min", 0)), int(params.get("count_max", 0)),
		int(params.get("pulses_to_win", 0)),
		c2.get("name", ""), c2.get("desc", ""),
		c3.get("name", ""), c3.get("desc", ""),
		int(rewards.get("biomass", 0.0)), int(rewards.get("mutant_rolls", 0)), int(rewards.get("anomaly_rolls", 0))]


func _tower_floor_info(f: int) -> String:
	if f <= 0:
		return "Выберите этаж"
	var params: Dictionary = TowerData.get_floor_params(f)
	var rewards: Dictionary = TowerData.get_floor_rewards(f)
	var conds: Array = TowerData.get_star_conditions(f)
	var c2: Dictionary = TowerData.STAR_CONDITIONS[conds[0]]
	var c3: Dictionary = TowerData.STAR_CONDITIONS[conds[1]]
	var stars: int = game_manager.get_tower_stars(f) if game_manager else 0
	var star_text := ""
	for i in range(3):
		star_text += "★" if i < stars else "☆"
	return "%s  %s\n★★ %s: %s\n★★★ %s: %s\nНаграда: %d биомассы | +%d круток мутантов | +%d аномалийных круток" % [
		params.get("title", ""), star_text,
		c2.get("name", ""), c2.get("desc", ""),
		c3.get("name", ""), c3.get("desc", ""),
		int(rewards.get("biomass", 0.0)), int(rewards.get("mutant_rolls", 0)), int(rewards.get("anomaly_rolls", 0))]


func _on_tower_floor_selected(f: int):
	_play_click_sound()
	_selected_tower_floor = f
	_tower_info.text = _tower_floor_info(f)


func _on_tower_go_pressed():
	"""Запуск забега на выбранный этаж башни"""
	_play_click_sound()
	if not game_manager or _selected_tower_floor <= 0:
		return

	# Выбранный этаж может быть не выше рубежа
	_selected_tower_floor = mini(_selected_tower_floor, game_manager.get_tower_floor())
	game_manager.selected_tower_floor = _selected_tower_floor
	game_manager.set_selected_run_mode("tower")
	tower_panel.visible = false

	await get_tree().create_timer(0.2).timeout
	game_manager.change_scene("run")


func _on_tower_close_pressed():
	_play_click_sound()
	tower_panel.visible = false
