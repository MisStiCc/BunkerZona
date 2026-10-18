# ui/hud/hud.gd
extends CanvasLayer
class_name HUD

signal anomaly_requested(anomaly_type: String)
signal mutant_requested(mutant_type: String)
signal emission_requested
signal start_run_requested

@onready var energy_value: Label = $Resources/EnergyValue
@onready var biomass_value: Label = $Resources/BiomassValue
@onready var wave_label: Label = $Resources/WaveLabel
@onready var stalker_count_label: Label = $Resources/StalkerCountLabel

@onready var emission_label: Label = $EmissionPanel/EmissionLabel
@onready var emission_timer_label: Label = $EmissionPanel/EmissionTimerLabel
@onready var emission_button: Button = $EmissionPanel/EmissionButton

@onready var anomaly_panel: Panel = $AnomalyPanel
@onready var start_panel: Panel = $StartPanel
@onready var minimap_art: TextureRect = $Minimap/MapArt
@onready var start_run_button: Button = $StartPanel/StartRunButton
@onready var mutant_panel: Panel = $MutantPanel

# Кнопки аномалий
@onready var fire_button: Button = $AnomalyPanel/FireButton
@onready var electric_button: Button = $AnomalyPanel/ElectricButton
@onready var acid_button: Button = $AnomalyPanel/AcidButton
@onready var vortex_button: Button = $AnomalyPanel/VortexButton
@onready var lift_button: Button = $AnomalyPanel/LiftButton
@onready var whirlwind_button: Button = $AnomalyPanel/WhirlwindButton
@onready var steam_button: Button = $AnomalyPanel/SteamButton
@onready var comet_button: Button = $AnomalyPanel/CometButton
@onready var jelly_button: Button = $AnomalyPanel/JellyButton
@onready var gas_button: Button = $AnomalyPanel/GasButton
@onready var acid_cloud_button: Button = $AnomalyPanel/AcidCloudButton
@onready var radiation_button: Button = $AnomalyPanel/RadiationButton
@onready var time_button: Button = $AnomalyPanel/TimeButton
@onready var teleport_button: Button = $AnomalyPanel/TeleportButton
@onready var tesla_button: Button = $AnomalyPanel/TeslaButton
@onready var fluff_button: Button = $AnomalyPanel/FluffButton

# Кнопки мутантов
@onready var dog_button: Button = $MutantPanel/DogButton
@onready var flesh_button: Button = $MutantPanel/FleshButton
@onready var snork_button: Button = $MutantPanel/SnorkButton
@onready var pseudodog_button: Button = $MutantPanel/PseudodogButton
@onready var controller_button: Button = $MutantPanel/ControllerButton
@onready var poltergeist_button: Button = $MutantPanel/PoltergeistButton
@onready var bloodsucker_button: Button = $MutantPanel/BloodsuckerButton
@onready var chimera_button: Button = $MutantPanel/ChimeraButton
@onready var zombie_button: Button = $MutantPanel/ZombieButton
@onready var pseudogiant_button: Button = $MutantPanel/PseudogiantButton

var zone_controller: Node
var emission_cooldown: float = 60.0
var _break_time_left: float = 0.0
var _break_next_wave: int = 0
var emission_timer: float = 0.0
var is_emission_active: bool = false
var _mutant_buttons: Dictionary = {}
var _anomaly_buttons: Dictionary = {}
# Мобильный режим «тап = ставить»: на таче кнопка включает кисть,
# тап по земле ставит защиту в точку (Signals.ground_tapped -> zone_controller)
var _touch_mode: bool = false
var _pending_item: String = ""
var _pending_button: Button = null


func _ready():
		add_to_group("hud")
		_touch_mode = DisplayServer.is_touchscreen_available()
		zone_controller = get_tree().get_first_node_in_group("zone_controller")

		if zone_controller:
				zone_controller.energy_changed.connect(_on_energy_changed)
				zone_controller.biomass_changed.connect(_on_biomass_changed)
				zone_controller.radiation_pulse_started.connect(_on_emission_started)
				zone_controller.radiation_pulse_ended.connect(_on_emission_ended)
				zone_controller.wave_started.connect(_on_wave_started)
				if zone_controller.has_signal("wave_break_started"):
						zone_controller.wave_break_started.connect(_on_break_started)

		_connect_buttons()
		_setup_sounds()
		_load_minimap()
		_apply_language_and_prices()
		Loc.changed.connect(_apply_language_and_prices)
		# Цены с бонусами лаборатории: ZoneController применяет множители в _ready,
		# поэтому после готовности всей сцены перерисовываем ценники
		_apply_language_and_prices.call_deferred()

		# print("HUD инициализирован")


## Локализация кнопок/подписей + ценники поверх них. При смене языка
## тексты переустанавливаются с нуля (цены не должны задваиваться)
func _apply_language_and_prices():
		var energy_label: Label = get_node_or_null("Resources/EnergyLabel")
		var biomass_label: Label = get_node_or_null("Resources/BiomassLabel")
		if energy_label:
				energy_label.text = Loc.t("hud.energy")
		if biomass_label:
				biomass_label.text = Loc.t("hud.biomass")
		stalker_count_label.text = Loc.t("hud.stalkers", {"n": 0})
		wave_label.text = Loc.t("hud.wave", {"n": 0})
		emission_button.text = Loc.t("hud.emission")
		start_run_button.text = Loc.t("hud.start")
		var anomaly_header: Label = get_node_or_null("AnomalyPanel/Header")
		if anomaly_header:
				anomaly_header.text = Loc.t("hud.anomalies")
		var mutant_header: Label = get_node_or_null("MutantPanel/Header")
		if mutant_header:
				mutant_header.text = Loc.t("hud.mutants")
		_apply_prices()


func _load_minimap():
		"""SVG-карта сектора: res://ui/lab/minimap.svg (опционально).
		Нет файла - точки рисуются на голой панели."""
		const MAP_PATH := "res://ui/lab/minimap.svg"
		if ResourceLoader.exists(MAP_PATH):
				minimap_art.texture = load(MAP_PATH)
		else:
				minimap_art.visible = false


func _apply_prices():
		"""Ценники на кнопках из реальных цен менеджеров (со скидками лаборатории).
		Текст устанавливается с нуля: локализованное имя + цена (не append!)"""
		if not zone_controller:
				return
		var am = zone_controller.get("anomaly_manager")
		var sm = zone_controller.get("spawn_manager")
		var anomalies = {
				fire_button: ["heat_anomaly", "an.heat"], electric_button: ["electric_anomaly", "an.electric"],
				acid_button: ["acid_anomaly", "an.acid"], vortex_button: ["gravity_vortex", "an.vortex"],
				lift_button: ["gravity_lift", "an.lift"], whirlwind_button: ["gravity_whirlwind", "an.whirlwind"],
				steam_button: ["thermal_steam", "an.steam"], comet_button: ["thermal_comet", "an.comet"],
				jelly_button: ["chemical_jelly", "an.jelly"], gas_button: ["chemical_gas", "an.gas"],
				acid_cloud_button: ["chemical_acid_cloud", "an.acid_cloud"], radiation_button: ["radiation_hotspot", "an.radiation"],
				time_button: ["time_dilation", "an.time"], teleport_button: ["teleport", "an.teleport"],
				tesla_button: ["electric_tesla", "an.tesla"], fluff_button: ["bio_burning_fluff", "an.fluff"],
		}
		var mutants = {
				dog_button: ["dog_mutant", "mu.dog"], flesh_button: ["flesh", "mu.flesh"], snork_button: ["snork_mutant", "mu.snork"],
				pseudodog_button: ["pseudodog", "mu.pseudodog"], controller_button: ["controller_mutant", "mu.controller"],
				poltergeist_button: ["poltergeist", "mu.poltergeist"], bloodsucker_button: ["bloodsucker", "mu.bloodsucker"],
				chimera_button: ["chimera", "mu.chimera"], zombie_button: ["zombie", "mu.zombie"],
				pseudogiant_button: ["pseudogiant", "mu.pseudogiant"],
		}
		_mutant_buttons = {}
		_anomaly_buttons = {}
		for btn in anomalies:
				var cost: int = int(am.get_anomaly_cost(anomalies[btn][0])) if am else 0
				btn.text = Loc.t(anomalies[btn][1]) + "
⚡" + str(cost)
				_anomaly_buttons[btn] = anomalies[btn][0]
		for btn in mutants:
				var cost: int = int(sm.get_mutant_cost(mutants[btn][0])) if sm else 0
				btn.text = Loc.t(mutants[btn][1]) + "
🧬" + str(cost)
				_mutant_buttons[btn] = mutants[btn][0]
		refresh_mutant_unlocks()


func refresh_mutant_unlocks():
		"""Гейтинг коллекции: без разблокировки мутант/аномалия в бой не применить"""
		var gm = get_tree().get_first_node_in_group("game_manager")
		for btn in _anomaly_buttons:
				var anomaly_type: String = _anomaly_buttons[btn]
				var artifact_key: String = GachaData.get_artifact_for_anomaly(anomaly_type)
				var art_unlocked: bool = artifact_key.is_empty() or (gm.is_artifact_unlocked(artifact_key) if gm else true)
				btn.disabled = not art_unlocked
				btn.tooltip_text = (Loc.t("hud.anomaly_locked_tip", {"artifact": Loc.type_name(artifact_key)})) if not art_unlocked else ""
				if not art_unlocked and not btn.text.begins_with("🔒"):
						btn.text = "🔒" + btn.text
				if art_unlocked and btn.text.begins_with("🔒"):
						btn.text = btn.text.trim_prefix("🔒")
		for btn in _mutant_buttons:
				var type: String = _mutant_buttons[btn]
				var unlocked: bool = gm.is_mutant_unlocked(type) if gm else true
				btn.disabled = not unlocked
				btn.tooltip_text = Loc.t("hud.locked_tip") if not unlocked else ""
				if not unlocked and not btn.text.begins_with("🔒"):
						btn.text = "🔒" + btn.text


func _connect_buttons():
		# Аномалии
		fire_button.pressed.connect(_on_fire_pressed)
		electric_button.pressed.connect(_on_electric_pressed)
		acid_button.pressed.connect(_on_acid_pressed)
		vortex_button.pressed.connect(_on_vortex_pressed)
		lift_button.pressed.connect(_on_lift_pressed)
		whirlwind_button.pressed.connect(_on_whirlwind_pressed)
		steam_button.pressed.connect(_on_steam_pressed)
		comet_button.pressed.connect(_on_comet_pressed)
		jelly_button.pressed.connect(_on_jelly_pressed)
		gas_button.pressed.connect(_on_gas_pressed)
		acid_cloud_button.pressed.connect(_on_acid_cloud_pressed)
		radiation_button.pressed.connect(_on_radiation_pressed)
		time_button.pressed.connect(_on_time_pressed)
		teleport_button.pressed.connect(_on_teleport_pressed)
		tesla_button.pressed.connect(_on_tesla_pressed)
		fluff_button.pressed.connect(_on_fluff_pressed)

		# Мутанты
		dog_button.pressed.connect(_on_dog_pressed)
		flesh_button.pressed.connect(_on_flesh_pressed)
		snork_button.pressed.connect(_on_snork_pressed)
		pseudodog_button.pressed.connect(_on_pseudodog_pressed)
		controller_button.pressed.connect(_on_controller_pressed)
		poltergeist_button.pressed.connect(_on_poltergeist_pressed)
		bloodsucker_button.pressed.connect(_on_bloodsucker_pressed)
		chimera_button.pressed.connect(_on_chimera_pressed)
		zombie_button.pressed.connect(_on_zombie_pressed)
		pseudogiant_button.pressed.connect(_on_pseudogiant_pressed)

		emission_button.pressed.connect(_on_emission_pressed)
		start_run_button.pressed.connect(_on_start_run_pressed)


func _setup_sounds():
		var buttons = [
				fire_button, electric_button, acid_button,
				vortex_button, lift_button, whirlwind_button,
				steam_button, comet_button, jelly_button,
				gas_button, acid_cloud_button, radiation_button,
				time_button, teleport_button, tesla_button, fluff_button,
				dog_button, flesh_button, snork_button, pseudodog_button,
				controller_button, poltergeist_button, bloodsucker_button,
				chimera_button, zombie_button, emission_button
		]

		for btn in buttons:
				if btn:
						btn.mouse_entered.connect(_play_hover_sound)


func _play_hover_sound():
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_sound"):
				sm.play_sound("ui_hover", 0.3)


func _play_click_sound():
		var sm = get_tree().get_first_node_in_group("sound_manager")
		if sm and sm.has_method("play_sound"):
				sm.play_sound("ui_click", 0.6)


func _process(delta):
		if emission_timer > 0:
				emission_timer -= delta
				emission_timer_label.text = "⌛ %dс" % int(emission_timer)
				emission_timer_label.visible = true
		else:
				emission_timer_label.visible = false
				# Кнопка оставалась disabled навсегда после первого выброса
				if not is_emission_active:
						emission_button.disabled = false

		if _break_time_left > 0.0:
				_break_time_left -= delta
				wave_label.visible = true
				wave_label.modulate = Color(1, 0.8, 0.2)
				wave_label.text = Loc.t("hud.break_countdown", {"cur": _break_next_wave, "max": _get_max_waves(), "sec": int(ceil(_break_time_left))})

		if zone_controller:
				var status = zone_controller.get_status()
				stalker_count_label.text = "👥 Сталкеров: %d" % status.get("stalkers", 0)


func _on_energy_changed(current: float, max_val: float):
		energy_value.text = "%d / %d" % [int(current), int(max_val)]


func _on_biomass_changed(current: float, max_val: float):
		biomass_value.text = "%d / %d" % [int(current), int(max_val)]


func _on_break_started(wave_number: int, break_duration: float):
		_break_next_wave = wave_number + 1
		_break_time_left = break_duration


func _get_max_waves() -> int:
		if zone_controller and zone_controller.get("spawn_manager"):
				return zone_controller.spawn_manager.max_waves
		return 3


func _on_wave_started(wave_number: int, _count: int):
		_break_time_left = 0.0
		wave_label.text = Loc.t("hud.wave_announce", {"cur": wave_number, "max": _get_max_waves()})
		wave_label.modulate = Color.YELLOW
		wave_label.visible = true

		var tween = create_tween()
		tween.tween_property(wave_label, "modulate:a", 0.0, 2.0)
		tween.tween_callback(func(): wave_label.visible = false)


func _on_emission_started(_level: int):
		is_emission_active = true
		emission_button.disabled = true
		emission_label.text = Loc.t("hud.emission_active")
		emission_label.modulate = Color.RED
		emission_timer = 0
		emission_timer_label.visible = false


func _on_emission_ended():
		is_emission_active = false
		emission_label.text = ""
		emission_timer = emission_cooldown


func _on_start_run_pressed():
		_play_click_sound()
		start_run_requested.emit()
		# Кнопка одноразовая: до конца забега панель не нужна
		start_panel.visible = false
		# print("HUD: старт забега запрошен")


func _on_emission_pressed():
		_play_click_sound()

		# has_method("start_radiation_pulse") у ZoneController был ВСЕГДА false
		# (метод живёт в EventManager) - кнопка никогда не срабатывала
		if not zone_controller or not zone_controller.can_start_pulse():
				_show_emission_note(Loc.t("hud.emission_running"))
				return

		if zone_controller.spend_energy(1000):
				emission_requested.emit()
				zone_controller.start_radiation_pulse()
		else:
				_show_emission_note(Loc.t("hud.no_energy"))


var _note_timer: SceneTreeTimer = null

func _show_emission_note(text: String):
		emission_label.text = text
		emission_label.modulate = Color(1, 0.5, 0.3)
		_note_timer = get_tree().create_timer(2.0)
		_note_timer.timeout.connect(func():
				if not is_emission_active:
						emission_label.text = ""
						emission_label.modulate = Color.WHITE)


# ==================== АНОМАЛИИ ====================

func _on_fire_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(fire_button, "anomaly:heat_anomaly")
				return
		anomaly_requested.emit("heat_anomaly")

func _on_electric_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(electric_button, "anomaly:electric_anomaly")
				return
		anomaly_requested.emit("electric_anomaly")

func _on_acid_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(acid_button, "anomaly:acid_anomaly")
				return
		anomaly_requested.emit("acid_anomaly")

func _on_vortex_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(vortex_button, "anomaly:gravity_vortex")
				return
		anomaly_requested.emit("gravity_vortex")

func _on_lift_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(lift_button, "anomaly:gravity_lift")
				return
		anomaly_requested.emit("gravity_lift")

func _on_whirlwind_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(whirlwind_button, "anomaly:gravity_whirlwind")
				return
		anomaly_requested.emit("gravity_whirlwind")

func _on_steam_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(steam_button, "anomaly:thermal_steam")
				return
		anomaly_requested.emit("thermal_steam")

func _on_comet_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(comet_button, "anomaly:thermal_comet")
				return
		anomaly_requested.emit("thermal_comet")

func _on_jelly_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(jelly_button, "anomaly:chemical_jelly")
				return
		anomaly_requested.emit("chemical_jelly")

func _on_gas_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(gas_button, "anomaly:chemical_gas")
				return
		anomaly_requested.emit("chemical_gas")

func _on_acid_cloud_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(acid_cloud_button, "anomaly:chemical_acid_cloud")
				return
		anomaly_requested.emit("chemical_acid_cloud")

func _on_radiation_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(radiation_button, "anomaly:radiation_hotspot")
				return
		anomaly_requested.emit("radiation_hotspot")

func _on_time_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(time_button, "anomaly:time_dilation")
				return
		anomaly_requested.emit("time_dilation")

func _on_teleport_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(teleport_button, "anomaly:teleport")
				return
		anomaly_requested.emit("teleport")

func _on_tesla_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(tesla_button, "anomaly:electric_tesla")
				return
		anomaly_requested.emit("electric_tesla")

func _on_fluff_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(fluff_button, "anomaly:bio_burning_fluff")
				return
		anomaly_requested.emit("bio_burning_fluff")


# ==================== РЕЖИМ «ТАП = СТАВИТЬ» (МОБИЛКА) ====================

func _toggle_placement(btn: Button, item_id: String):
		"""Тач: нажатие включает кисть (тап по земле ставит защиту в точку),
		повторное нажатие той же кнопки выключает, другая кнопка переключает кисть"""
		if _pending_item == item_id:
				_pending_item = ""
				_pending_button = null
				btn.modulate = Color.WHITE
				if zone_controller and zone_controller.has_method("set_pending_placement"):
						zone_controller.set_pending_placement("")
				return
		if _pending_button:
				_pending_button.modulate = Color.WHITE
		_pending_item = item_id
		_pending_button = btn
		btn.modulate = Color(1.5, 1.4, 0.6)
		if zone_controller and zone_controller.has_method("set_pending_placement"):
				zone_controller.set_pending_placement(item_id)


# ==================== МУТАНТЫ ====================

func _on_dog_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(dog_button, "mutant:dog_mutant")
				return
		mutant_requested.emit("dog_mutant")

func _on_flesh_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(flesh_button, "mutant:flesh")
				return
		mutant_requested.emit("flesh")

func _on_snork_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(snork_button, "mutant:snork_mutant")
				return
		mutant_requested.emit("snork_mutant")

func _on_pseudodog_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(pseudodog_button, "mutant:pseudodog")
				return
		mutant_requested.emit("pseudodog")

func _on_controller_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(controller_button, "mutant:controller_mutant")
				return
		mutant_requested.emit("controller_mutant")

func _on_poltergeist_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(poltergeist_button, "mutant:poltergeist")
				return
		mutant_requested.emit("poltergeist")

func _on_bloodsucker_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(bloodsucker_button, "mutant:bloodsucker")
				return
		mutant_requested.emit("bloodsucker")

func _on_chimera_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(chimera_button, "mutant:chimera")
				return
		mutant_requested.emit("chimera")

func _on_zombie_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(zombie_button, "mutant:zombie")
				return
		mutant_requested.emit("zombie")


func _on_pseudogiant_pressed():
		_play_click_sound()
		if _touch_mode:
				_toggle_placement(pseudogiant_button, "mutant:pseudogiant")
				return
		mutant_requested.emit("pseudogiant")


func show_anomaly_panel(shown: bool):
		anomaly_panel.visible = shown


func show_mutant_panel(shown: bool):
		mutant_panel.visible = shown


## Нота события выживания: заголовок + описание в панели выброса
func show_event_note(event: Dictionary):
		var title: String = str(event.get("title_ru" if Loc.lang == "ru" else "title_en", ""))
		var desc: String = str(event.get("desc_ru" if Loc.lang == "ru" else "desc_en", ""))
		emission_label.text = Loc.t("hud.event_incoming", {"title": title})
		emission_label.modulate = Color(1.0, 0.6, 0.1)
		if _note_timer:
				_note_timer.timeout.disconnect(_on_note_expired)
		_note_timer = get_tree().create_timer(4.0)
		_note_timer.timeout.connect(_on_note_expired.bind(desc))


func _on_note_expired(desc: String = ""):
		if is_emission_active:
				return
		if not desc.is_empty():
				# Сначала описание, затем очистка
				emission_label.text = Loc.t("hud.event_desc", {"desc": desc})
				_note_timer = get_tree().create_timer(3.0)
				_note_timer.timeout.connect(_on_note_expired)
				return
		emission_label.text = ""
		emission_label.modulate = Color.WHITE


## Золотая нота награды (гача/вехи/события) в панели выброса
func show_reward_note(text: String):
		emission_label.text = Loc.t("hud.reward_note", {"text": text})
		emission_label.modulate = Color(1.0, 0.85, 0.2)
		if _note_timer and _note_timer.timeout.is_connected(_on_note_expired):
				_note_timer.timeout.disconnect(_on_note_expired)
		_note_timer = get_tree().create_timer(3.0)
		_note_timer.timeout.connect(_on_note_expired)


