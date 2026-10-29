# ui/hud/hud.gd
extends CanvasLayer
class_name HUD

signal anomaly_requested(anomaly_type: String)
signal mutant_requested(mutant_type: String)
signal emission_requested
signal start_run_requested
signal trader_requested

@onready var energy_value: Label = $Resources/EnergyValue
@onready var biomass_value: Label = $Resources/BiomassValue
@onready var wave_label: Label = $Resources/WaveLabel
@onready var stalker_count_label: Label = $Resources/StalkerCountLabel
@onready var time_label: Label = $Resources/TimeLabel

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
# Перф (v0.23.1): пер-кадровые тексты — только при изменении, статус 4 раза/с
var _status_accum: float = 0.0
var _last_stalkers_text: String = ""
var _last_emission_sec: int = -1
var _last_break_sec: int = -1
var emission_timer: float = 0.0
var is_emission_active: bool = false
var _mutant_buttons: Dictionary = {}
var _mutant_base_costs: Dictionary = {}
var _anomaly_buttons: Dictionary = {}
var _loadout_orig: Dictionary = {} # исходная геометрия кнопок/панелей набора
var _loadout_grid: Dictionary = {} # метрики сетки панели: x0/y0/bw/bh/px/py
# Мобильный режим «тап = ставить»: на таче кнопка включает кисть,
# тап по земле ставит защиту в точку (Signals.ground_tapped -> zone_controller)
var _touch_mode: bool = false
var _pending_item: String = ""
var _pending_button: Button = null
# Панель условий звёзд башни: показывается в бою на этаже башни
var _tower_conditions_panel: Panel = null
var _tower_conditions_label: Label = null
# Центральный баннер объявлений (события/выброс/волны/награды) — стиль БУНКЕР
var _announce_panel: PanelContainer = null
var _announce_title: Label = null
var _announce_desc: Label = null
var _announce_tween: Tween = null
var _announce_seq: int = 0
# Кнопка торговца «Седой» (v0.28.0): видна в подготовке и на передышках
var _trader_button: Button = null
# v0.31.0: живые ресурсы для состояний «дорого», цены аномалий,
# сворачиваемая панель мутантов (тап по заголовку)
var _energy_now: float = 0.0
var _biomass_now: float = 0.0
var _anomaly_base_costs: Dictionary = {}
var _mutants_collapsed: bool = false
var _mut_header_btn: Button = null

# D8 (мобильный UX): аккордеон категорий, автосворачивание в док,
# панель подтверждения постановки, safe-area. Только _touch_mode.
var _touch_anom_cat: String = "heat"
var _touch_mut_cat: String = "squad"
var _anom_collapsed: bool = false
var _touch_tab_buttons: Dictionary = {}   # "anomaly"/"mutant" -> Array[Button]
var _confirm_panel: Panel = null
var _confirm_ok_btn: Button = null
var _confirm_cancel_btn: Button = null
var _last_touch_activity_ms: int = 0

# Стихии боевых видов (v0.31.0): фон/кант/текст кнопки — цвет стихии.
# fire=жар, electric=электрика, chem=химия, gravity=гравитация, rad=радиация, bio=мутанты
const ELEM_COLORS := {
                "fire": {"bg": Color("2a1008"), "bg_hover": Color("3f1a0c"), "edge": Color("e06a3a"), "text": Color("ffd9c4")},
                "electric": {"bg": Color("0e1a2a"), "bg_hover": Color("14263c"), "edge": Color("57b8ff"), "text": Color("d8ecff")},
                "chem": {"bg": Color("0e2408"), "bg_hover": Color("16330e"), "edge": Color("8fe23a"), "text": Color("e2ffd4")},
                "gravity": {"bg": Color("1a0e2a"), "bg_hover": Color("271640"), "edge": Color("b070ff"), "text": Color("eadcff")},
                "rad": {"bg": Color("22200a"), "bg_hover": Color("332e0e"), "edge": Color("ffd23f"), "text": Color("fff3c0")},
                "bio": {"bg": Color("12200c"), "bg_hover": Color("1a3012"), "edge": Color("7dc95e"), "text": Color("e4ffd8")},
}
const COST_SHORT_COLOR := Color("ff8a6a") # цена не по карману (v0.31.0)

# D8: категории аккордеона тач-панелей (ключ -> виды). Порядок кнопок вида
# задаёт порядок в ряду; макс 5 кнопок в ряду (588 px - влезает).
const TOUCH_ANOMALY_CATS := {
	"heat": ["heat_anomaly", "thermal_steam", "thermal_comet", "bio_burning_fluff"],
	"electric": ["electric_anomaly", "electric_tesla"],
	"gravity": ["gravity_vortex", "gravity_lift", "gravity_whirlwind", "time_dilation", "teleport"],
	"chem": ["acid_anomaly", "chemical_jelly", "chemical_gas", "chemical_acid_cloud", "radiation_hotspot"],
}
const TOUCH_MUTANT_CATS := {
	"squad": ["dog_mutant", "flesh", "snork_mutant", "pseudodog", "zombie"],
	"elite": ["controller_mutant", "poltergeist", "bloodsucker", "chimera", "pseudogiant"],
}
const TOUCH_CAT_TITLES := {
	"heat": {"ru": "ТЕПЛО", "en": "HEAT"}, "electric": {"ru": "ЭЛЕКТРО", "en": "ELECTRO"},
	"gravity": {"ru": "ГРАВИ", "en": "GRAVI"}, "chem": {"ru": "ХИМИЯ+ФОН", "en": "CHEM+RAD"},
	"squad": {"ru": "ОТРЯД", "en": "PACK"}, "elite": {"ru": "ЭЛИТА", "en": "ELITE"},
}


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
                _mut_header_btn = get_node_or_null("MutantPanel/Header")
                if _mut_header_btn:
                                _mut_header_btn.pressed.connect(_toggle_mutant_panel)
                                _mut_header_btn.mouse_entered.connect(_play_hover_sound)
                _setup_sounds()
                _load_minimap()
                _apply_language_and_prices()
                Loc.changed.connect(_apply_language_and_prices)
                # Цены с бонусами лаборатории: ZoneController применяет множители в _ready,
                # поэтому после готовности всей сцены перерисовываем ценники
                _apply_language_and_prices.call_deferred()
                # Панель условий звёзд башни: строим отложенно, любые проблемы -
                # панель просто остаётся скрытой, HUD не ломается
                _setup_tower_conditions_panel.call_deferred()
                # Центральный баннер объявлений + крупные панели боя (тач-UX)
                _build_announce_banner.call_deferred()
                _rescale_battle_panels.call_deferred()
                # Полевой набор: автосбор из открытых + визуал (после deferred ценников)
                _loadout_init.call_deferred()
                # Торговец забега: кнопка в свободном окне верха
                _build_trader_button.call_deferred()
                # D8: тач-аккордеон панелей, подтверждение постановки, safe-area
                _setup_touch_ui.call_deferred()

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
                if _trader_button:
                                _trader_button.text = Loc.t("trader.button")
                var anomaly_header: Label = get_node_or_null("AnomalyPanel/Header")
                if anomaly_header:
                                anomaly_header.text = Loc.t("hud.anomalies")
                var mutant_header: Button = get_node_or_null("MutantPanel/Header")
                if mutant_header:
                                _update_mut_header_text()
                # Условия звезды (рецепт v3) - строка над кнопками мутантов
                var recipe_line: Label = mutant_panel.get_node_or_null("StarRecipe")
                if recipe_line == null:
                        recipe_line = Label.new()
                        recipe_line.name = "StarRecipe"
                        recipe_line.add_theme_font_size_override("font_size", 8)
                        recipe_line.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
                        recipe_line.position = Vector2(2, 14)
                        recipe_line.size = Vector2(440, 12)
                        mutant_panel.add_child(recipe_line)
                recipe_line.text = Loc.t("hud.star_recipe")
                _apply_prices()


func _setup_tower_conditions_panel():
                """Панель условий звёзд этажа башни (правый верхний угол), кодом без .tscn.
                mouse_filter = IGNORE: панель не перехватывает тапы на мобильных.
                Любая проблема -> панель остаётся скрытой, HUD не ломается."""
                if is_instance_valid(_tower_conditions_panel):
                        return
                _tower_conditions_panel = Panel.new()
                _tower_conditions_panel.name = "TowerConditionsPanel"
                _tower_conditions_panel.anchor_left = 1.0
                _tower_conditions_panel.anchor_right = 1.0
                _tower_conditions_panel.offset_left = -444.0
                _tower_conditions_panel.offset_right = -8.0
                _tower_conditions_panel.offset_top = 8.0
                _tower_conditions_panel.offset_bottom = 62.0
                _tower_conditions_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _tower_conditions_panel.visible = false
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.1, 0.1, 0.1, 0.85)
                sb.border_color = Color(0.85, 0.68, 0.25)
                sb.set_border_width_all(1)
                sb.set_corner_radius_all(4)
                sb.content_margin_left = 8.0
                sb.content_margin_right = 8.0
                sb.content_margin_top = 4.0
                sb.content_margin_bottom = 4.0
                _tower_conditions_panel.add_theme_stylebox_override("panel", sb)
                _tower_conditions_label = Label.new()
                _tower_conditions_label.name = "ConditionsLabel"
                _tower_conditions_label.add_theme_font_size_override("font_size", 11)
                _tower_conditions_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75))
                _tower_conditions_label.set_anchors_preset(Control.PRESET_FULL_RECT)
                _tower_conditions_panel.add_child(_tower_conditions_label)
                add_child(_tower_conditions_panel)
                _refresh_tower_conditions()


func _refresh_tower_conditions():
                """Условия звёзд текущего этажа: только башня и только после старта забега"""
                if not is_instance_valid(_tower_conditions_panel) or not is_instance_valid(_tower_conditions_label):
                        return
                if not is_instance_valid(start_panel):
                        return
                var rp: Dictionary = {}
                if zone_controller != null:
                        var raw = zone_controller.get("run_params")
                        if raw is Dictionary:
                                rp = raw
                var is_tower: bool = str(rp.get("run_mode", "")) == "tower"
                var started: bool = not start_panel.visible
                var f: int = int(rp.get("tower_floor", 0))
                if not is_tower or not started or f < 1:
                        _tower_conditions_panel.visible = false
                        return
                var conds: Array = TowerData.get_star_conditions(f)
                if conds.size() < 2:
                        _tower_conditions_panel.visible = false
                        return
                var n2: String = str(TowerData.STAR_CONDITIONS.get(conds[0], {}).get("name", ""))
                var n3: String = str(TowerData.STAR_CONDITIONS.get(conds[1], {}).get("name", ""))
                _tower_conditions_label.text = "ЭТАЖ %d - условия звёзд\n★★ %s: %s\n★★★ %s: %s" % [
                                                f, n2, TowerData.condition_text(conds[0], f),
                                                n3, TowerData.condition_text(conds[1], f)]
                _tower_conditions_panel.visible = true


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
                # v0.31.0: тройки [тип, ключ локализации, стихия] — кнопка красится цветом стихии
                var anomalies = {
                                fire_button: ["heat_anomaly", "an.heat", "fire"], electric_button: ["electric_anomaly", "an.electric", "electric"],
                                acid_button: ["acid_anomaly", "an.acid", "chem"], vortex_button: ["gravity_vortex", "an.vortex", "gravity"],
                                lift_button: ["gravity_lift", "an.lift", "gravity"], whirlwind_button: ["gravity_whirlwind", "an.whirlwind", "gravity"],
                                steam_button: ["thermal_steam", "an.steam", "fire"], comet_button: ["thermal_comet", "an.comet", "fire"],
                                jelly_button: ["chemical_jelly", "an.jelly", "chem"], gas_button: ["chemical_gas", "an.gas", "chem"],
                                acid_cloud_button: ["chemical_acid_cloud", "an.acid_cloud", "chem"], radiation_button: ["radiation_hotspot", "an.radiation", "rad"],
                                time_button: ["time_dilation", "an.time", "gravity"], teleport_button: ["teleport", "an.teleport", "gravity"],
                                tesla_button: ["electric_tesla", "an.tesla", "electric"], fluff_button: ["bio_burning_fluff", "an.fluff", "rad"],
                }
                var mutants = {
                                dog_button: ["dog_mutant", "mu.dog", "bio"], flesh_button: ["flesh", "mu.flesh", "bio"], snork_button: ["snork_mutant", "mu.snork", "bio"],
                                pseudodog_button: ["pseudodog", "mu.pseudodog", "bio"], controller_button: ["controller_mutant", "mu.controller", "bio"],
                                poltergeist_button: ["poltergeist", "mu.poltergeist", "bio"], bloodsucker_button: ["bloodsucker", "mu.bloodsucker", "bio"],
                                chimera_button: ["chimera", "mu.chimera", "bio"], zombie_button: ["zombie", "mu.zombie", "bio"],
                                pseudogiant_button: ["pseudogiant", "mu.pseudogiant", "bio"],
                }
                _mutant_buttons = {}
                _anomaly_buttons = {}
                _anomaly_base_costs = {}
                for btn in anomalies:
                                var cost: int = int(am.get_anomaly_cost(anomalies[btn][0])) if am else 0
                                # Имя и цена в ОДНОЙ строке; шрифт 9 - цена влезает в узкую кнопку
                                btn.text = Loc.t(anomalies[btn][1]) + " ⚡" + str(cost)
                                btn.clip_text = true
                                btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                                btn.add_theme_font_size_override("font_size", 9)
                                btn.tooltip_text = Loc.t(anomalies[btn][1]) + " ⚡" + str(cost)
                                _apply_ability_icon(btn, "anomaly", anomalies[btn][0])
                                _anomaly_buttons[btn] = anomalies[btn][0]
                                _anomaly_base_costs[anomalies[btn][0]] = cost
                                _style_el_button(btn, anomalies[btn][2])
                for btn in mutants:
                                var cost: int = int(sm.get_mutant_cost(mutants[btn][0])) if sm else 0
                                btn.text = Loc.t(mutants[btn][1]) + " 🧬" + str(cost)
                                btn.clip_text = true
                                btn.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
                                btn.add_theme_font_size_override("font_size", 9)
                                btn.tooltip_text = Loc.t(mutants[btn][1]) + " 🧬" + str(cost)
                                _apply_ability_icon(btn, "mutant", mutants[btn][0])
                                _mutant_buttons[btn] = mutants[btn][0]
                                _mutant_base_costs[mutants[btn][0]] = cost
                                _style_el_button(btn, mutants[btn][2])
                refresh_mutant_unlocks()
                _update_affordability()


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
                                var ex_t: String = ""
                                if gm and gm.has_method("owned_mutant_exclusive_for"):
                                                ex_t = gm.owned_mutant_exclusive_for(type)
                                var unlocked: bool = true if gm == null else (gm.is_mutant_unlocked(type) or not ex_t.is_empty())
                                btn.disabled = not unlocked
                                if not ex_t.is_empty():
                                                # Эксклюзив Чёрного ящика заменяет базовый вид (v0.21.0)
                                                var ex_label: String = EXCLUSIVE_SHORT.get(ex_t, GachaData.display_name(ex_t))
                                                btn.text = "✦ " + ex_label + "
🧬" + str(int(_mutant_base_costs.get(type, 0)))
                                                btn.tooltip_text = "Эксклюзив Чёрного ящика: %s - Зона ставит усиленную версию" % GachaData.display_name(ex_t)
                                else:
                                                btn.tooltip_text = Loc.t("hud.locked_tip") if not unlocked else ""
                                                if not unlocked and not btn.text.begins_with("🔒"):
                                                                btn.text = "🔒" + btn.text
                _refresh_loadout_ui()


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
                                var _esec := int(emission_timer)
                                if _esec != _last_emission_sec:
                                    _last_emission_sec = _esec
                                    emission_timer_label.text = "⌛ %dс" % _esec
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
                                var _bsec := int(ceil(_break_time_left))
                                if _bsec != _last_break_sec:
                                    _last_break_sec = _bsec
                                    wave_label.text = Loc.t("hud.break_countdown", {"cur": _break_next_wave, "max": _get_max_waves(), "sec": _bsec})

                if zone_controller:
                                # Перф (v0.23.1): статус не чаще 4 раз/с, текст — только при изменении
                                _status_accum += delta
                                if _status_accum >= 0.25:
                                                _status_accum = 0.0
                                                var sc: int = 0
                                                if zone_controller != null and zone_controller.get("spawn_manager") != null:
                                                                sc = zone_controller.spawn_manager.get_stalker_count()
                                                var stxt := "👥 Сталкеров: %d" % sc
                                                if stxt != _last_stalkers_text:
                                                                _last_stalkers_text = stxt
                                                                stalker_count_label.text = stxt

                if _trader_button:
                                var shop_available: bool = (start_panel.visible or _break_time_left > 0.0) and not is_emission_active
                                if _trader_button.visible != shop_available:
                                                _trader_button.visible = shop_available

                # D8: в бою панели сами сворачиваются в док после IDLE_COLLAPSE сек без постановок
                if _touch_mode and not start_panel.visible:
                                var idle_ms: int = Time.get_ticks_msec() - _last_touch_activity_ms
                                if idle_ms > int(HudMobile.IDLE_COLLAPSE * 1000.0) and (not _anom_collapsed or not _mutants_collapsed):
                                                _anom_collapsed = true
                                                _mutants_collapsed = true
                                                _update_mut_header_text()
                                                _refresh_loadout_ui()


func _on_energy_changed(current: float, max_val: float):
                energy_value.text = "%d / %d" % [int(current), int(max_val)]
                _energy_now = current
                _update_affordability()


func _on_biomass_changed(current: float, max_val: float):
                biomass_value.text = "%d" % int(current) if max_val >= 100000.0 else "%d / %d" % [int(current), int(max_val)]
                _biomass_now = current
                _update_affordability()


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

                # Крупное объявление по центру (стиль БУНКЕР)
                _announce("ВОЛНА %d / %d" % [wave_number, _get_max_waves()], "", Color(1.0, 0.85, 0.25), 1.6)


func _on_emission_started(_level: int):
                is_emission_active = true
                emission_button.disabled = true
                emission_label.text = ""
                emission_timer = 0
                emission_timer_label.visible = false
                # ВЫБРОС — крупно по центру, а не мелко над кнопкой
                _announce("ВЫБРОС!", "Зона выгорает — сталкеры гибнут.", Color(1.0, 0.32, 0.22), 2.6)


func _on_emission_ended():
                is_emission_active = false
                emission_label.text = ""
                emission_timer = emission_cooldown


func _on_start_run_pressed():
                _play_click_sound()
                # Старт только с непустым набором: хотя бы один вид в бою (v0.21.0)
                var gm_start = get_tree().get_first_node_in_group("game_manager")
                var lab_start = gm_start.get_lab_data() if gm_start else null
                if lab_start and lab_start.loadout_count("anomaly") + lab_start.loadout_count("mutant") <= 0:
                                show_reward_note("Набор пуст - возьмите в бой хотя бы один вид")
                                return
                start_run_requested.emit()
                # Кнопка одноразовая: до конца забега панель не нужна
                start_panel.visible = false
                # Условия звёзд появляются только после старта забега
                _refresh_tower_conditions()
                # v0.31.0: панель мутантов после старта свёрнута — экран свободнее;
                # развернуть можно тапом по заголовку
                _mutants_collapsed = true
                _update_mut_header_text()
                # После старта набор зафиксирован: невзятые виды недоступны
                _refresh_loadout_ui()
                # D8: отсчёт автосворачивания панелей в бою — с момента старта
                _last_touch_activity_ms = Time.get_ticks_msec()
                # print("HUD: старт забега запрошен")


func _on_emission_pressed():
                _play_click_sound()

                # has_method("start_radiation_pulse") у ZoneController был ВСЕГДА false
                # (метод живёт в EventManager) - кнопка никогда не срабатывала
                if not zone_controller or not zone_controller.can_start_pulse():
                                _show_emission_note(Loc.t("hud.emission_running"))
                                var sm_deny = get_tree().get_first_node_in_group("sound_manager")
                                if sm_deny and sm_deny.has_method("play_sound"):
                                                sm_deny.play_sound("ui_deny", 0.6)
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
                if _loadout_tap("anomaly", "heat_anomaly"):
                                return
                if _touch_mode:
                                _toggle_placement(fire_button, "anomaly:heat_anomaly")
                                return
                anomaly_requested.emit("heat_anomaly")

func _on_electric_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "electric_anomaly"):
                                return
                if _touch_mode:
                                _toggle_placement(electric_button, "anomaly:electric_anomaly")
                                return
                anomaly_requested.emit("electric_anomaly")

func _on_acid_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "acid_anomaly"):
                                return
                if _touch_mode:
                                _toggle_placement(acid_button, "anomaly:acid_anomaly")
                                return
                anomaly_requested.emit("acid_anomaly")

func _on_vortex_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "gravity_vortex"):
                                return
                if _touch_mode:
                                _toggle_placement(vortex_button, "anomaly:gravity_vortex")
                                return
                anomaly_requested.emit("gravity_vortex")

func _on_lift_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "gravity_lift"):
                                return
                if _touch_mode:
                                _toggle_placement(lift_button, "anomaly:gravity_lift")
                                return
                anomaly_requested.emit("gravity_lift")

func _on_whirlwind_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "gravity_whirlwind"):
                                return
                if _touch_mode:
                                _toggle_placement(whirlwind_button, "anomaly:gravity_whirlwind")
                                return
                anomaly_requested.emit("gravity_whirlwind")

func _on_steam_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "thermal_steam"):
                                return
                if _touch_mode:
                                _toggle_placement(steam_button, "anomaly:thermal_steam")
                                return
                anomaly_requested.emit("thermal_steam")

func _on_comet_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "thermal_comet"):
                                return
                if _touch_mode:
                                _toggle_placement(comet_button, "anomaly:thermal_comet")
                                return
                anomaly_requested.emit("thermal_comet")

func _on_jelly_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "chemical_jelly"):
                                return
                if _touch_mode:
                                _toggle_placement(jelly_button, "anomaly:chemical_jelly")
                                return
                anomaly_requested.emit("chemical_jelly")

func _on_gas_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "chemical_gas"):
                                return
                if _touch_mode:
                                _toggle_placement(gas_button, "anomaly:chemical_gas")
                                return
                anomaly_requested.emit("chemical_gas")

func _on_acid_cloud_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "chemical_acid_cloud"):
                                return
                if _touch_mode:
                                _toggle_placement(acid_cloud_button, "anomaly:chemical_acid_cloud")
                                return
                anomaly_requested.emit("chemical_acid_cloud")

func _on_radiation_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "radiation_hotspot"):
                                return
                if _touch_mode:
                                _toggle_placement(radiation_button, "anomaly:radiation_hotspot")
                                return
                anomaly_requested.emit("radiation_hotspot")

func _on_time_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "time_dilation"):
                                return
                if _touch_mode:
                                _toggle_placement(time_button, "anomaly:time_dilation")
                                return
                anomaly_requested.emit("time_dilation")

func _on_teleport_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "teleport"):
                                return
                if _touch_mode:
                                _toggle_placement(teleport_button, "anomaly:teleport")
                                return
                anomaly_requested.emit("teleport")

func _on_tesla_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "electric_tesla"):
                                return
                if _touch_mode:
                                _toggle_placement(tesla_button, "anomaly:electric_tesla")
                                return
                anomaly_requested.emit("electric_tesla")

func _on_fluff_pressed():
                _play_click_sound()
                if _loadout_tap("anomaly", "bio_burning_fluff"):
                                return
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
                _last_touch_activity_ms = Time.get_ticks_msec()
                if zone_controller and zone_controller.has_method("set_pending_placement"):
                                zone_controller.set_pending_placement(item_id)


# ==================== МУТАНТЫ ====================

func _on_dog_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "dog_mutant"):
                                return
                if _touch_mode:
                                _toggle_placement(dog_button, "mutant:dog_mutant")
                                return
                mutant_requested.emit("dog_mutant")

func _on_flesh_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "flesh"):
                                return
                if _touch_mode:
                                _toggle_placement(flesh_button, "mutant:flesh")
                                return
                mutant_requested.emit("flesh")

func _on_snork_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "snork_mutant"):
                                return
                if _touch_mode:
                                _toggle_placement(snork_button, "mutant:snork_mutant")
                                return
                mutant_requested.emit("snork_mutant")

func _on_pseudodog_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "pseudodog"):
                                return
                if _touch_mode:
                                _toggle_placement(pseudodog_button, "mutant:pseudodog")
                                return
                mutant_requested.emit("pseudodog")

func _on_controller_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "controller_mutant"):
                                return
                if _touch_mode:
                                _toggle_placement(controller_button, "mutant:controller_mutant")
                                return
                mutant_requested.emit("controller_mutant")

func _on_poltergeist_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "poltergeist"):
                                return
                if _touch_mode:
                                _toggle_placement(poltergeist_button, "mutant:poltergeist")
                                return
                mutant_requested.emit("poltergeist")

func _on_bloodsucker_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "bloodsucker"):
                                return
                if _touch_mode:
                                _toggle_placement(bloodsucker_button, "mutant:bloodsucker")
                                return
                mutant_requested.emit("bloodsucker")

func _on_chimera_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "chimera"):
                                return
                if _touch_mode:
                                _toggle_placement(chimera_button, "mutant:chimera")
                                return
                mutant_requested.emit("chimera")

func _on_zombie_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "zombie"):
                                return
                if _touch_mode:
                                _toggle_placement(zombie_button, "mutant:zombie")
                                return
                mutant_requested.emit("zombie")


func _on_pseudogiant_pressed():
                _play_click_sound()
                if _loadout_tap("mutant", "pseudogiant"):
                                return
                if _touch_mode:
                                _toggle_placement(pseudogiant_button, "mutant:pseudogiant")
                                return
                mutant_requested.emit("pseudogiant")


func show_anomaly_panel(shown: bool):
                anomaly_panel.visible = shown


func show_mutant_panel(shown: bool):
                mutant_panel.visible = shown


## Событие выживания: крупный баннер по центру (заголовок + описание)
func show_event_note(event: Dictionary):
                var title: String = str(event.get("title_ru" if Loc.lang == "ru" else "title_en", ""))
                var desc: String = str(event.get("desc_ru" if Loc.lang == "ru" else "desc_en", ""))
                _announce("СОБЫТИЕ ЗОНЫ: %s" % title, desc, Color(1.0, 0.6, 0.1), 4.6)


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


## Золотое объявление награды (гача/вехи/события) — крупно по центру
func show_reward_note(text: String):
                _announce("НАГРАДА", text, Color(1.0, 0.85, 0.2), 2.6)


# ==================== ВРАТА ПРИПЯТИ (D9, выживание) ====================

## Жёлтые треугольники активных врат на миникарте (передышка; гаснут на волне)
func show_wave_gates(points: Array) -> void:
                var dots := get_node_or_null("Minimap/Dots")
                if dots and dots.has_method("set_gates"):
                                dots.set_gates(points)


func clear_wave_gates() -> void:
                var dots := get_node_or_null("Minimap/Dots")
                if dots and dots.has_method("clear_gates"):
                                dots.clear_gates()


## Честное предупреждение в передышке: откуда придёт волна
func show_gate_warning(wave: int, dirs: Array) -> void:
                var names: Array = []
                for d in dirs:
                                names.append(str(d.get("ru" if Loc.lang == "ru" else "en", "")))
                if names.is_empty():
                                return
                var title: String = "ВОЛНА %d" % wave if Loc.lang == "ru" else "WAVE %d" % wave
                var desc: String = ("Сталкеры придут с: " + ", ".join(names)) if Loc.lang == "ru" else ("Stalkers incoming from: " + ", ".join(names))
                _announce(title, desc, Color(1.0, 0.85, 0.25), 2.4)

## Часы суток (v0.29.0): строка в панели ресурсов, цвет и иконка по фазе
func update_daynight(text: String, icon: String, color: Color) -> void:
                if time_label:
                                time_label.text = icon + " " + text
                                time_label.add_theme_color_override("font_color", color)

## Радиационный фон Припяти (RadiationData, D3): строка «☢ N мкЗв/ч» под
## часами, цвет и тултип - по зоне. Вызывает ZoneController только на Припяти.
var radiation_label: Label

func show_radiation(zone_id: String) -> void:
                var info: Dictionary = RadiationData.get_zone_info(zone_id)
                if radiation_label == null:
                                radiation_label = Label.new()
                                radiation_label.name = "RadiationLabel"
                                radiation_label.position = Vector2(6, 76)
                                radiation_label.add_theme_font_size_override("font_size", 10)
                                var res := get_node_or_null("Resources")
                                if res:
                                                res.add_child(radiation_label)
                                else:
                                                add_child(radiation_label)
                radiation_label.text = "☢ %.0f мкЗв/ч" % float(info["bg"])
                radiation_label.tooltip_text = str(info["title_ru" if Loc.lang == "ru" else "title_en"])
                radiation_label.add_theme_color_override("font_color",
                                RadiationData.HUD_COLORS.get(zone_id, Color.WHITE))

# ==================== ТОРГОВЕЦ ЗАБЕГА (v0.28.0) ====================

func _build_trader_button() -> void:
                if is_instance_valid(_trader_button):
                                return
                _trader_button = Button.new()
                _trader_button.name = "TraderButton"
                _trader_button.text = Loc.t("trader.button")
                # Свободное окно верха: после панелей аномалий (до x=864), до баннера (x=1118)
                _trader_button.position = Vector2(926, 10)
                _trader_button.size = Vector2(180, 46)
                _trader_button.focus_mode = Control.FOCUS_NONE
                _trader_button.add_theme_font_override("font", BunkerUI.font_title())
                _trader_button.add_theme_font_size_override("font_size", 16)
                _trader_button.add_theme_color_override("font_color", Color("ffd94d"))
                _trader_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.09, 0.085, 0.06)
                sb.border_color = Color("ffd94d")
                sb.set_border_width_all(2)
                sb.set_corner_radius_all(8)
                _trader_button.add_theme_stylebox_override("normal", sb)
                var sbh := sb.duplicate()
                sbh.bg_color = Color(0.16, 0.14, 0.07)
                _trader_button.add_theme_stylebox_override("hover", sbh)
                _trader_button.add_theme_stylebox_override("pressed", sbh)
                _trader_button.pressed.connect(func():
                                _play_click_sound()
                                trader_requested.emit())
                add_child(_trader_button)
                _trader_button.visible = false


# ==================== ЦЕНТРАЛЬНЫЙ БАННЕР ОБЪЯВЛЕНИЙ (стиль БУНКЕР) ====================

func _build_announce_banner() -> void:
                if is_instance_valid(_announce_panel):
                                return
                var holder := Control.new()
                holder.name = "AnnounceHolder"
                holder.set_anchors_preset(Control.PRESET_FULL_RECT)
                holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
                _announce_panel = PanelContainer.new()
                _announce_panel.name = "AnnounceBanner"
                _announce_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.045, 0.036, 0.014, 0.93)
                sb.border_color = Color("ffd94d")
                sb.set_border_width_all(3)
                sb.set_corner_radius_all(10)
                sb.shadow_color = Color(0, 0, 0, 0.55)
                sb.shadow_size = 20
                sb.content_margin_left = 30.0
                sb.content_margin_right = 30.0
                sb.content_margin_top = 20.0
                sb.content_margin_bottom = 20.0
                _announce_panel.add_theme_stylebox_override("panel", sb)
                var v := VBoxContainer.new()
                v.mouse_filter = Control.MOUSE_FILTER_IGNORE
                v.add_theme_constant_override("separation", 8)
                _announce_title = Label.new()
                _announce_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                _announce_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                _announce_title.custom_minimum_size = Vector2(420, 0)
                _announce_title.add_theme_font_override("font", BunkerUI.font_title())
                _announce_title.add_theme_font_size_override("font_size", 54)
                _announce_title.add_theme_color_override("font_color", Color("ffd94d"))
                _announce_desc = Label.new()
                _announce_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                _announce_desc.add_theme_font_override("font", BunkerUI.font_body())
                _announce_desc.add_theme_font_size_override("font_size", 22)
                _announce_desc.add_theme_color_override("font_color", Color(0.92, 0.9, 0.8))
                _announce_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
                _announce_desc.custom_minimum_size = Vector2(420, 0)
                v.add_child(_announce_title)
                v.add_child(_announce_desc)
                _announce_panel.add_child(v)
                holder.add_child(_announce_panel)
                add_child(holder)
                # Позиция: ПУСТОЕ МЕСТО СВЕРХУ ПО ЦЕНТРУ — окно между StartPanel (x<=716)
                # и правыми панелями (Мутанты от x=1374, Условия башни от x=1476).
                # Ниже y=66 панель аномалий доходит до x=864, поэтому центр окна = 1116,
                # а ширина баннера ограничена (~486 с полями) — ничего не перекрывает.
                _announce_panel.anchor_left = 0.0
                _announce_panel.anchor_right = 0.0
                _announce_panel.anchor_top = 0.0
                _announce_panel.anchor_bottom = 0.0
                _announce_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
                _announce_panel.grow_vertical = Control.GROW_DIRECTION_END
                _announce_panel.offset_left = 1118.0
                _announce_panel.offset_right = 1118.0
                _announce_panel.offset_top = 8.0
                _announce_panel.visible = false


func _announce(title: String, desc: String = "", title_color: Color = Color("ffd94d"), hold: float = 2.2) -> void:
                """Крупное объявление по центру: заголовок + описание, появление/затухание.
                Последующее объявление перебивает предыдущее (seq-guard)."""
                if not is_instance_valid(_announce_panel):
                                _build_announce_banner()
                _announce_seq += 1
                var seq := _announce_seq
                _announce_title.text = title
                _announce_title.add_theme_color_override("font_color", title_color)
                _announce_desc.text = desc
                _announce_desc.visible = not desc.is_empty()
                _announce_panel.reset_size()
                _announce_panel.pivot_offset = _announce_panel.size / 2.0
                _announce_panel.visible = true
                _announce_panel.modulate = Color(1, 1, 1, 0)
                _announce_panel.scale = Vector2(1.03, 1.03)
                if _announce_tween and _announce_tween.is_valid():
                                _announce_tween.kill()
                _announce_tween = create_tween()
                _announce_tween.set_parallel(true)
                _announce_tween.tween_property(_announce_panel, "modulate:a", 1.0, 0.18)
                _announce_tween.tween_property(_announce_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
                _announce_tween.set_parallel(false)
                _announce_tween.tween_interval(hold)
                _announce_tween.tween_property(_announce_panel, "modulate:a", 0.0, 0.35)
                _announce_tween.tween_callback(func():
                                if seq == _announce_seq and is_instance_valid(_announce_panel):
                                                _announce_panel.visible = false)


# ==================== СТИХИИ/СОСТОЯНИЯ КНОПОК (v0.31.0) ====================

## Задача 23: иконка способности на кнопку забега (assets/ui/abilities).
## Нет файла - кнопка без иконки, как раньше. Иконка слева от текста
## (имя + цена), 30 px - читаемость сохраняется.
func _apply_ability_icon(btn: Button, kind: String, type: String) -> void:
                var path := "res://assets/ui/abilities/%s/%s.png" % [kind, type]
                if not FileAccess.file_exists(path):
                                return
                btn.icon = load(path)
                btn.expand_icon = true
                btn.add_theme_constant_override("icon_max_width", 30)
                btn.add_theme_constant_override("h_separation", 4)


func _style_el_button(btn: Button, elem: String) -> void:
                """Кнопка боевого вида в цвете стихии: тёмный фон + яркий кант (v0.31.0).
                Состояния: доступно — цвет стихии, дорого — красный текст (_update_affordability),
                закрыто — тусклое (font_disabled_color)."""
                var c: Dictionary = ELEM_COLORS.get(elem, ELEM_COLORS["bio"])
                var edge: Color = c["edge"]
                btn.add_theme_color_override("font_color", c["text"])
                btn.add_theme_color_override("font_hover_color", Color.WHITE)
                btn.add_theme_color_override("font_pressed_color", edge)
                btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.6, 0.52, 0.7))
                btn.set_meta("el_text", c["text"])
                btn.add_theme_stylebox_override("normal", _el_box(c["bg"], edge))
                btn.add_theme_stylebox_override("hover", _el_box(c["bg_hover"], edge.lightened(0.2)))
                var pressed := _el_box(c["bg"].darkened(0.25), edge)
                pressed.content_margin_top = 10.0
                btn.add_theme_stylebox_override("pressed", pressed)
                btn.add_theme_stylebox_override("disabled", _el_box(Color(c["bg"], 0.45), Color(edge, 0.25)))


func _el_box(bg: Color, edge: Color) -> StyleBoxFlat:
                var sb := StyleBoxFlat.new()
                sb.bg_color = bg
                sb.border_color = edge
                sb.set_border_width_all(2)
                sb.set_corner_radius_all(10)
                sb.content_margin_left = 6.0
                sb.content_margin_right = 6.0
                sb.content_margin_top = 4.0
                sb.content_margin_bottom = 4.0
                return sb


func _update_affordability() -> void:
                """Явное состояние «дорого» (v0.31.0): у видов не по карману текст краснеет.
                Доступно — цвет стихии; закрытые (disabled) не трогаем — они тусклые."""
                for btn in _anomaly_buttons:
                                if btn.disabled:
                                                continue
                                var cost: float = float(_anomaly_base_costs.get(_anomaly_buttons[btn], 0))
                                var txt: Color = btn.get_meta("el_text", Color.WHITE)
                                btn.add_theme_color_override("font_color",
                                                                COST_SHORT_COLOR if _energy_now < cost else txt)
                for btn in _mutant_buttons:
                                if btn.disabled:
                                                continue
                                var cost_m: float = float(_mutant_base_costs.get(_mutant_buttons[btn], 0))
                                var txt_m: Color = btn.get_meta("el_text", Color.WHITE)
                                btn.add_theme_color_override("font_color",
                                                                COST_SHORT_COLOR if _biomass_now < cost_m else txt_m)


# ==================== ПАНЕЛЬ МУТАНТОВ: СВОРАЧИВАНИЕ (v0.31.0) ====================

func _toggle_mutant_panel() -> void:
                """Тап по заголовку панели мутантов: свернуть/развернуть сетку."""
                _play_click_sound()
                if start_panel.visible:
                                # Режим набора (до старта): панель всегда развёрнута — виды выбираются тапами
                                show_reward_note("Сначала соберите набор и запустите забег")
                                return
                _mutants_collapsed = not _mutants_collapsed
                _last_touch_activity_ms = Time.get_ticks_msec()
                _update_mut_header_text()
                _refresh_loadout_ui()


func _update_mut_header_text() -> void:
                """Заголовок панели мутантов: стрелка состояния (▼ развернуто / ► свернуто)."""
                if not _mut_header_btn:
                                return
                var base: String = Loc.t("hud.mutants")
                if not start_panel or start_panel.visible:
                                _mut_header_btn.text = base
                elif _mutants_collapsed:
                                _mut_header_btn.text = "► " + base
                else:
                                _mut_header_btn.text = "▼ " + base


# ==================== КРУПНЫЕ ПАНЕЛИ БОЯ (тач-UX) ====================

func _rescale_battle_panels() -> void:
                """v0.31.0: аномалии — вертикальный блок 4 колонки слева (HUD не перекрывает),
                мутанты — 5 колонок справа со сворачиваемым заголовком, старт/выброс —
                крупные кнопки внизу по центру. Кнопки в цветах стихий (_style_el_button)."""
                # v0.31.2: подложка панелей боя - плотный тёмный бункер с окантовкой,
                # кнопки читаемы и на светлой Зоне, и ночью за событием Зоны
                var hud_sb := StyleBoxFlat.new()
                hud_sb.bg_color = Color(0.043, 0.055, 0.031, 0.8)
                hud_sb.border_color = Color(0.26, 0.29, 0.21, 0.95)
                hud_sb.set_border_width_all(1)
                hud_sb.set_corner_radius_all(8)
                for pname in ["Resources", "AnomalyPanel", "MutantPanel", "EmissionPanel", "StartPanel"]:
                                var pp: Panel = get_node_or_null(pname)
                                if pp:
                                                pp.add_theme_stylebox_override("panel", hud_sb)
                var bw := 100.0
                var bh := 54.0
                var gx := 6.0
                var gy := 6.0
                var top := 24.0
                for setup in [[anomaly_panel, 4], [mutant_panel, 5]]:
                                var p: Panel = setup[0]
                                var cols: int = setup[1]
                                var col := 0
                                var row := 0
                                for c in p.get_children():
                                                if c is Button and c != _mut_header_btn:
                                                                c.position = Vector2(4.0 + col * (bw + gx), top + row * (bh + gy))
                                                                c.size = Vector2(bw, bh)
                                                                c.add_theme_font_size_override("font_size", 14)
                                                                col += 1
                                                                if col >= cols:
                                                                                col = 0
                                                                                row += 1
                                var rows: int = row + (1 if col > 0 else 0)
                                var w := 8.0 + cols * (bw + gx)
                                if cols == 5:
                                                p.offset_left = p.offset_right - w
                                else:
                                                p.offset_right = p.offset_left + w
                                p.offset_bottom = p.offset_top + top + rows * (bh + gy) + 6.0
                                var hdr: Label = p.get_node_or_null("Title")
                                if hdr:
                                                hdr.add_theme_font_size_override("font_size", 13)
                var mut_hdr: Button = get_node_or_null("MutantPanel/Header")
                if mut_hdr:
                                mut_hdr.position = Vector2(4, 2)
                                mut_hdr.size = Vector2(mutant_panel.offset_right - mutant_panel.offset_left - 8, 20)
                                mut_hdr.add_theme_font_size_override("font_size", 13)
                var res_panel: Panel = get_node_or_null("Resources")
                if res_panel:
                                for c in res_panel.get_children():
                                                if c is Label:
                                                                c.add_theme_font_size_override("font_size", 12)
                var ep: Panel = get_node_or_null("EmissionPanel")
                if ep:
                                emission_button.position = Vector2(6, 20)
                                emission_button.size = Vector2(ep.offset_right - ep.offset_left - 12, 48)
                                emission_label.add_theme_font_size_override("font_size", 12)
                                emission_timer_label.add_theme_font_size_override("font_size", 12)
                var sp: Panel = get_node_or_null("StartPanel")
                if sp:
                                var hint: Label = sp.get_node_or_null("StartHint")
                                if hint:
                                                hint.add_theme_font_size_override("font_size", 11)
                                start_run_button.position = Vector2(6, 20)
                                start_run_button.size = Vector2(sp.offset_right - sp.offset_left - 12, 48)
                # Крупные кнопки внизу по центру — стиль БУНКЕР (зелёная СТАРТ / красная ВЫБРОС)
                BunkerUI.style_button(start_run_button, "primary", 15)
                BunkerUI.style_button(emission_button, "danger", 15)


# ==================== ПОЛЕВОЙ НАБОР (v0.16.1, «ГЕОФИЗИК») ====================
# В бой берётся максимум 9 видов аномалий и 9 видов мутантов. До старта забега
# клик по кнопке панели = взять/снять вид. После старта в панелях остаются
# ТОЛЬКО взятые виды: невзятые исчезают, панели поджимаются под состав набора.

const ANOMALY_ORDER := ["heat_anomaly", "electric_anomaly", "acid_anomaly", "gravity_vortex", "gravity_lift", "gravity_whirlwind", "thermal_steam", "thermal_comet", "chemical_jelly", "chemical_gas", "chemical_acid_cloud", "radiation_hotspot", "time_dilation", "teleport", "electric_tesla", "bio_burning_fluff"]
const MUTANT_ORDER := ["zombie", "dog_mutant", "flesh", "snork_mutant", "pseudodog", "poltergeist", "controller_mutant", "bloodsucker", "chimera", "pseudogiant"]
# Короткие имена эксклюзивов для боевых кнопок (полные - в подсказке и галерее)
const EXCLUSIVE_SHORT := {"alpha_pseudodog": "Альфа-вожак", "ash_snork": "Пепельник", "obsidian_controller": "Обсидиан.пастырь"}


func _loadout_init():
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.has_method("ensure_loadout"):
                                gm.ensure_loadout(ANOMALY_ORDER, MUTANT_ORDER)
                if _loadout_orig.is_empty():
                                for btn in _anomaly_buttons:
                                                _loadout_orig[btn] = Rect2(btn.offset_left, btn.offset_top, btn.offset_right - btn.offset_left, btn.offset_bottom - btn.offset_top)
                                for btn in _mutant_buttons:
                                                _loadout_orig[btn] = Rect2(btn.offset_left, btn.offset_top, btn.offset_right - btn.offset_left, btn.offset_bottom - btn.offset_top)
                                for setup in [["AnomalyPanel", 4], ["MutantPanel", 5]]:
                                                var p = get_node_or_null(setup[0])
                                                if p:
                                                                _loadout_orig[p] = Rect2(p.offset_left, p.offset_top, p.offset_right - p.offset_left, p.offset_bottom - p.offset_top)
                                                                var btns: Array = []
                                                                for c in p.get_children():
                                                                                # v0.31.0: заголовок-кнопка мутантов — не элемент сетки
                                                                                if c is Button and c != _mut_header_btn:
                                                                                                btns.append(c)
                                                                if btns.size() >= 2:
                                                                                var b0: Button = btns[0]
                                                                                var b1: Button = btns[1]
                                                                                var ci: int = int(setup[1])
                                                                                var py: float = 40.0
                                                                                if btns.size() > ci:
                                                                                                py = btns[ci].offset_top - b0.offset_top
                                                                                _loadout_grid[p] = {
                                                                                                "x0": b0.offset_left, "y0": b0.offset_top,
                                                                                                "bw": b0.offset_right - b0.offset_left,
                                                                                                "bh": b0.offset_bottom - b0.offset_top,
                                                                                                "px": b1.offset_left - b0.offset_left,
                                                                                                "py": py,
                                                                                }
                _refresh_loadout_ui()


## Клик по боевой кнопке. До старта - режим набора (клик поглощается),
## после старта невзятый вид ругается подсказкой. False - обычное действие.
func _loadout_tap(kind: String, type: String) -> bool:
                var gm = get_tree().get_first_node_in_group("game_manager")
                var lab = gm.get_lab_data() if gm else null
                if lab == null:
                                return false
                if start_panel.visible:
                                # D16: лимит набора 9/12 (conv_slots12 за флагом)
                                var gm_lim = get_tree().get_first_node_in_group("game_manager")
                                lab.loadout_limit = StoreData.slots_allowed(
                                                gm_lim.current_save_data.owned if gm_lim and gm_lim.current_save_data else {})
                                var res: String = lab.toggle_loadout(kind, type)
                                if res == "full":
                                                show_reward_note("В наборе максимум %d видов - снимите лишний" % lab.loadout_limit)
                                                var sm_den = get_tree().get_first_node_in_group("sound_manager")
                                                if sm_den and sm_den.has_method("play_sound"):
                                                                sm_den.play_sound("ui_deny", 0.6)
                                _refresh_loadout_ui()
                                return true
                if not lab.in_loadout(kind, type):
                                show_reward_note("«%s» не взят в бой - набор выбирается до старта забега" % GachaData.display_name(type))
                                return true
                return false


## Состав панелей и заголовки. До старта — режим набора: все виды на местах,
## невзятые тусклые. После старта остаются ТОЛЬКО взятые: невзятые исчезают,
## панели поджимаются под состав набора (до 9 видов аномалий и 9 мутантов).
func _refresh_loadout_ui():
                var gm = get_tree().get_first_node_in_group("game_manager")
                var lab = gm.get_lab_data() if gm else null
                if lab == null:
                                return
                var started: bool = not start_panel.visible
                var anomaly_title: Label = get_node_or_null("AnomalyPanel/Title")
                var mutant_title: Button = get_node_or_null("MutantPanel/Header")
                if anomaly_title:
                                anomaly_title.text = "АНОМАЛИИ" if started else "АНОМАЛИИ · В НАБОРЕ %d/9 (клик = взять/снять)" % lab.loadout_count("anomaly")
                if mutant_title:
                                if started:
                                                _update_mut_header_text()
                                else:
                                                mutant_title.text = "МУТАНТЫ · В НАБОРЕ %d/9 (клик по виду = взять/снять)" % lab.loadout_count("mutant")
                if gm and gm.has_method("owned_anomaly_exclusive_for"):
                                for btn in _anomaly_buttons:
                                                var ex_t: String = gm.owned_anomaly_exclusive_for(_anomaly_buttons[btn])
                                                if not ex_t.is_empty() and not btn.text.begins_with("✦"):
                                                                btn.text = "✦ " + btn.text
                                                                btn.tooltip_text = "Эксклюзив Чёрного ящика: %s - ставит усиленную версию" % GachaData.display_name(ex_t)
                # Аномалии: в бою только взятые, до боя - всё открытое коллекцией (v0.21.0)
                var taken_anomalies: Array = []
                for btn in _anomaly_buttons:
                                var atype: String = _anomaly_buttons[btn]
                                var taken: bool = lab.in_loadout("anomaly", atype)
                                var aowned: bool = _anomaly_owned(atype)
                                if started:
                                                btn.visible = taken
                                                if taken:
                                                                taken_anomalies.append(btn)
                                else:
                                                btn.visible = aowned
                                                if not aowned:
                                                                continue
                                                taken_anomalies.append(btn)
                                                btn.modulate = Color(1, 1, 1, 1) if taken else Color(0.6, 0.64, 0.58, 0.72)
                if _touch_mode:
                                # D8: аккордеон категорий вместо сплошных сеток; видимость
                                # (владение/набор) уже выставлена выше
                                _touch_layout_panels()
                                return
                _layout_taken(taken_anomalies, get_node_or_null("AnomalyPanel"), 4)
                # Мутанты: в бою только взятые, до боя - вся галерея (v0.21.0).
                # Порядок - по цене биомассы: слева дешёвые, справа супер-мутанты
                var taken_mutants: Array = []
                for btn in _mutant_buttons:
                                var mtype: String = _mutant_buttons[btn]
                                var mtaken: bool = lab.in_loadout("mutant", mtype)
                                var mowned: bool = _mutant_owned(mtype)
                                if started:
                                                btn.visible = mtaken
                                                if mtaken:
                                                                taken_mutants.append(btn)
                                else:
                                                btn.visible = mowned
                                                if not mowned:
                                                                continue
                                                taken_mutants.append(btn)
                                                btn.modulate = Color(1, 1, 1, 1) if mtaken else Color(0.6, 0.64, 0.58, 0.72)
                taken_mutants.sort_custom(_mutant_cost_sort)
                _layout_taken(taken_mutants, get_node_or_null("MutantPanel"), 5)


## Владение видом: разблокирован кампанией/гачей ИЛИ есть заменяющий эксклюзив (v0.21.0)
func _mutant_owned(mtype: String) -> bool:
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm == null:
                                return true
                if gm.is_mutant_unlocked(mtype):
                                return true
                if gm.has_method("owned_mutant_exclusive_for") and not gm.owned_mutant_exclusive_for(mtype).is_empty():
                                return true
                return false


## Владение аномалией: нет привязанного артефакта ИЛИ он выигран (v0.21.0)
func _anomaly_owned(atype: String) -> bool:
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm == null:
                                return true
                var artifact_key: String = GachaData.get_artifact_for_anomaly(atype)
                return artifact_key.is_empty() or gm.is_artifact_unlocked(artifact_key)


## Порядок кнопок мутантов: цена биомассы по возрастанию, при равенстве - MUTANT_ORDER
func _mutant_cost_sort(a: Button, b: Button) -> bool:
                var ta: String = _mutant_buttons.get(a, "")
                var tb: String = _mutant_buttons.get(b, "")
                var ca: float = float(_mutant_base_costs.get(ta, 9999.0))
                var cb: float = float(_mutant_base_costs.get(tb, 9999.0))
                if not is_equal_approx(ca, cb):
                                return ca < cb
                return MUTANT_ORDER.find(ta) < MUTANT_ORDER.find(tb)


## Возврат кнопки на исходное место из сцены (режим набора до старта забега)
func _restore_loadout_rect(btn: Button) -> void:
                if _loadout_orig.has(btn):
                                var r: Rect2 = _loadout_orig[btn]
                                btn.offset_left = r.position.x
                                btn.offset_top = r.position.y
                                btn.offset_right = r.position.x + r.size.x
                                btn.offset_bottom = r.position.y + r.size.y


## Уплотнение кнопок в компактную сетку + поджим панели. В бою вызывается со
## взятыми видами, до старта - со всеми открытыми (галерея). Панель без видов
## скрывается. Метрики сетки сняты с реальной раскладки (_rescale_battle_panels
## либо .tscn) в _loadout_init. Невидимые (закрытые) кнопки не считаются.
func _layout_taken(taken: Array, panel, cols: int) -> void:
                if panel == null:
                                return
                if taken.is_empty():
                                panel.visible = false
                                return
                panel.visible = true
                # v0.31.0: свёрнутая панель мутантов — только заголовок, высота поджимается
                if panel.name == "MutantPanel" and _mutants_collapsed and not start_panel.visible:
                                for c in panel.get_children():
                                                if c is Button and c != _mut_header_btn:
                                                                c.visible = false
                                                elif c is Label:
                                                                c.visible = false  # StarRecipe: в доке не нужен
                                panel.offset_bottom = panel.offset_top + 28.0
                                return
                var met: Dictionary = _loadout_grid.get(panel, {})
                if met.is_empty():
                                met = {"x0": 2.0, "y0": 20.0, "bw": 74.0, "bh": 46.0, "px": 78.0, "py": 58.0} if cols == 4 else {"x0": 2.0, "y0": 32.0, "bw": 90.0, "bh": 46.0, "px": 96.0, "py": 52.0}
                # Кнопки однострочные (имя ⚡цена, шрифт 9): ряды ниже и плотнее
                met["bh"] = 22.0
                met["py"] = 28.0
                var px: float = float(met["px"])
                var py: float = float(met["py"])
                var use_cols: int = mini(cols, taken.size())
                var rows: int = int(ceil(float(taken.size()) / float(cols)))
                var total := 0
                for c in panel.get_children():
                                # v0.31.0: заголовок-кнопка мутантов — не элемент сетки
                                if c is Button and c != _mut_header_btn:
                                                total += 1
                var rows_full: int = maxi(rows, int(ceil(float(total) / float(cols))))
                var pr: Rect2 = Rect2(panel.offset_left, panel.offset_top, panel.offset_right - panel.offset_left, panel.offset_bottom - panel.offset_top)
                if _loadout_orig.has(panel):
                                pr = _loadout_orig[panel]
                var w: float = pr.size.x - float(cols - use_cols) * px
                var h: float = pr.size.y - float(rows_full - rows) * py
                panel.offset_top = pr.position.y
                panel.offset_bottom = pr.position.y + h
                if panel.anchor_left >= 0.5:
                                panel.offset_right = pr.position.x + pr.size.x
                                panel.offset_left = panel.offset_right - w
                else:
                                panel.offset_left = pr.position.x
                                panel.offset_right = panel.offset_left + w
                for i in range(taken.size()):
                                var btn: Button = taken[i]
                                var col: int = i % cols
                                var row: int = int(floor(float(i) / float(cols)))
                                btn.offset_left = float(met["x0"]) + float(col) * px
                                btn.offset_top = float(met["y0"]) + float(row) * py
                                btn.offset_right = btn.offset_left + float(met["bw"])
                                btn.offset_bottom = btn.offset_top + float(met["bh"])
                # Панель поджимается под компактную сетку однострочных рядов
                var grid_bottom: float = float(met["y0"]) + float(rows) * float(met["py"])
                # Строка рецепта ★ (мутанты) - ПОД сеткой, чтобы не спорила с заголовком
                if panel.name == "MutantPanel":
                                var recipe: Label = panel.get_node_or_null("StarRecipe")
                                if recipe:
                                                recipe.position = Vector2(2.0, grid_bottom + 1.0)
                                                panel.offset_bottom = panel.offset_top + grid_bottom + 18.0
                                                return
                panel.offset_bottom = panel.offset_top + grid_bottom + 6.0


# ==================== ТАЧ-UI: АККОРДЕОН, ПОДТВЕРЖДЕНИЕ, SAFE-AREA (D8) ====================
# Спека design_inbox/mobile_ux: крупные кнопки по пальцу (HudMobile), панели
# постановки собираются в категории-аккордеон, в бою сворачиваются в док после
# IDLE_COLLAPSE сек без постановок, установка через призрак + панель подтверждения.

func _setup_touch_ui() -> void:
                """Только тач: табы категорий, панель подтверждения, safe-area,
                крупные СТАРТ/ВЫБРОС. Десктоп не заходит сюда."""
                if not _touch_mode:
                                return
                _touch_anom_cat = HudMobile.last_anomaly_cat
                _touch_mut_cat = HudMobile.last_mutant_cat
                _build_touch_tabs()
                _build_touch_confirm()
                _enlarge_bottom_buttons()
                _apply_safe_area()
                _last_touch_activity_ms = Time.get_ticks_msec()
                _refresh_loadout_ui()


func _build_touch_tabs() -> void:
                _touch_tab_buttons["anomaly"] = _make_tab_row(anomaly_panel, TOUCH_ANOMALY_CATS, "anomaly", 22.0)
                _touch_tab_buttons["mutant"] = _make_tab_row(mutant_panel, TOUCH_MUTANT_CATS, "mutant", 26.0)


func _make_tab_row(panel: Panel, cats: Dictionary, kind: String, tabs_y: float) -> Array:
                var tabs: Array = []
                if panel == null:
                                return tabs
                var keys: Array = cats.keys()
                var panel_w: float = panel.offset_right - panel.offset_left
                var tw: float = panel_w / float(maxi(keys.size(), 1))
                for i in range(keys.size()):
                                var cat: String = str(keys[i])
                                var b := Button.new()
                                b.name = "Tab_" + cat
                                b.text = str(TOUCH_CAT_TITLES.get(cat, {}).get(Loc.lang, cat))
                                b.position = Vector2(4.0 + float(i) * tw, tabs_y)
                                b.size = Vector2(tw - 4.0, HudMobile.TAB_H)
                                b.focus_mode = Control.FOCUS_NONE
                                b.add_theme_font_size_override("font_size", 15)
                                b.mouse_entered.connect(_play_hover_sound)
                                b.pressed.connect(_on_touch_tab.bind(kind, cat))
                                panel.add_child(b)
                                tabs.append(b)
                return tabs


func _on_touch_tab(kind: String, cat: String) -> void:
                _play_click_sound()
                _last_touch_activity_ms = Time.get_ticks_msec()
                if kind == "anomaly":
                                _touch_anom_cat = cat
                                HudMobile.last_anomaly_cat = cat
                                _anom_collapsed = false
                else:
                                _touch_mut_cat = cat
                                HudMobile.last_mutant_cat = cat
                                _mutants_collapsed = false
                                _update_mut_header_text()
                _refresh_loadout_ui()


func _touch_cat_of(kind: String, type: String) -> String:
                var cats: Dictionary = TOUCH_ANOMALY_CATS if kind == "anomaly" else TOUCH_MUTANT_CATS
                for cat in cats:
                                if type in cats[cat]:
                                                return str(cat)
                return str(cats.keys()[0]) if cats.size() > 0 else ""


func _touch_layout_panels() -> void:
                _touch_layout_panel(anomaly_panel, "anomaly", _touch_anom_cat, _anom_collapsed, 22.0)
                _touch_layout_panel(mutant_panel, "mutant", _touch_mut_cat, _mutants_collapsed, 26.0)


func _touch_layout_panel(panel: Panel, kind: String, active_cat: String, collapsed: bool, tabs_y: float) -> void:
                """Сетка одной панели в тач-режиме: табы категорий сверху, под ними
                кнопки активной категории 112x72. Свернутая панель = док (одни табы)."""
                if panel == null:
                                return
                var type_map: Dictionary = _anomaly_buttons if kind == "anomaly" else _mutant_buttons
                var cats: Dictionary = TOUCH_ANOMALY_CATS if kind == "anomaly" else TOUCH_MUTANT_CATS
                var tabs: Array = _touch_tab_buttons.get(kind, [])
                var is_mut: bool = kind == "mutant"
                var gap := 4.0
                var row_gap := 6.0
                var max_row: int = 0
                for cat in cats:
                                max_row = maxi(max_row, cats[cat].size())
                var panel_w: float = 8.0 + float(max_row) * (HudMobile.BTN_W + gap)
                if panel.anchor_left >= 0.5:
                                panel.offset_left = panel.offset_right - panel_w
                else:
                                panel.offset_right = panel.offset_left + panel_w
                # Заголовок мутантов тянется на новую ширину панели
                if is_mut and _mut_header_btn:
                                _mut_header_btn.position = Vector2(4, 2)
                                _mut_header_btn.size = Vector2(panel_w - 8, 20)
                # Табы: активная категория подсвечена золотом
                var tw: float = panel_w / float(maxi(tabs.size(), 1))
                for i in range(tabs.size()):
                                var tb: Button = tabs[i]
                                tb.position = Vector2(4.0 + float(i) * tw, tabs_y)
                                tb.size = Vector2(tw - 4.0, HudMobile.TAB_H)
                                tb.add_theme_font_size_override("font_size", 15)
                                tb.modulate = Color(1.35, 1.2, 0.65) if str(cats.keys()[i]) == active_cat else Color(1, 1, 1, 0.82)
                # Кнопки: оставляем только активную категорию (видимость по владению
                # уже выставлена _refresh_loadout_ui)
                var btns_y: float = tabs_y + HudMobile.TAB_H + row_gap
                var grid: Array = []
                for c in panel.get_children():
                                if c is Button and (not is_mut or c != _mut_header_btn) and not tabs.has(c):
                                                var t: String = str(type_map.get(c, ""))
                                                c.visible = c.visible and _touch_cat_of(kind, t) == active_cat
                                                c.add_theme_font_size_override("font_size", 16)
                                                if c.visible:
                                                                grid.append(c)
                if collapsed and not start_panel.visible:
                                # Док: одни табы, кнопки спрятаны
                                for b in grid:
                                                b.visible = false
                                panel.offset_bottom = panel.offset_top + btns_y + 2.0
                                return
                var cols: int = max_row
                var rows: int = maxi(int(ceil(float(grid.size()) / float(cols))), 1) if grid.size() > 0 else 1
                for i in range(grid.size()):
                                var b: Button = grid[i]
                                var col: int = i % cols
                                var row: int = int(floor(float(i) / float(cols)))
                                b.position = Vector2(4.0 + float(col) * (HudMobile.BTN_W + gap), btns_y + float(row) * (HudMobile.BTN_H + row_gap))
                                b.size = Vector2(HudMobile.BTN_W, HudMobile.BTN_H)
                panel.offset_bottom = panel.offset_top + btns_y + float(rows) * (HudMobile.BTN_H + row_gap) + 4.0


func _enlarge_bottom_buttons() -> void:
                """СТАРТ/ВЫБРОС по пальцу: BIG_H (панели вырастают вверх)"""
                for setup in [[start_run_button, "StartPanel"], [emission_button, "EmissionPanel"]]:
                                var p: Panel = get_node_or_null(setup[1])
                                if p:
                                                p.offset_top -= (HudMobile.BIG_H - 48.0)
                                                var b: Button = setup[0]
                                                b.position = Vector2(6, 20)
                                                b.size = Vector2(p.offset_right - p.offset_left - 12, HudMobile.BIG_H)


func _build_touch_confirm() -> void:
                if is_instance_valid(_confirm_panel):
                                return
                _confirm_panel = Panel.new()
                _confirm_panel.name = "PlacementConfirm"
                _confirm_panel.anchor_left = 1.0
                _confirm_panel.anchor_right = 1.0
                _confirm_panel.anchor_top = 1.0
                _confirm_panel.anchor_bottom = 1.0
                _confirm_panel.offset_left = -320.0
                _confirm_panel.offset_right = -8.0
                _confirm_panel.offset_top = -448.0
                _confirm_panel.offset_bottom = -336.0
                _confirm_panel.visible = false
                var sb := StyleBoxFlat.new()
                sb.bg_color = Color(0.06, 0.07, 0.05, 0.92)
                sb.border_color = Color(0.55, 0.85, 0.45)
                sb.set_border_width_all(2)
                sb.set_corner_radius_all(10)
                _confirm_panel.add_theme_stylebox_override("panel", sb)
                _confirm_ok_btn = Button.new()
                _confirm_ok_btn.name = "ConfirmPlace"
                _confirm_ok_btn.text = "ПОСТАВИТЬ"
                _confirm_ok_btn.position = Vector2(6, 6)
                _confirm_ok_btn.size = Vector2(HudMobile.CONFIRM_W, HudMobile.CONFIRM_H)
                _confirm_ok_btn.pressed.connect(_on_confirm_place)
                BunkerUI.style_button(_confirm_ok_btn, "primary", 14)
                _confirm_panel.add_child(_confirm_ok_btn)
                _confirm_cancel_btn = Button.new()
                _confirm_cancel_btn.name = "ConfirmCancel"
                _confirm_cancel_btn.text = "ОТМЕНА" if Loc.lang == "ru" else "CANCEL"
                _confirm_cancel_btn.position = Vector2(6 + HudMobile.CONFIRM_W + 8, 6)
                _confirm_cancel_btn.size = Vector2(HudMobile.CONFIRM_W, HudMobile.CONFIRM_H)
                _confirm_cancel_btn.pressed.connect(_on_confirm_cancel)
                BunkerUI.style_button(_confirm_cancel_btn, "steel", 14)
                _confirm_panel.add_child(_confirm_cancel_btn)
                add_child(_confirm_panel)


## ZoneController показывает призрак: панель подтверждения с ценой
func show_placement_confirm(item_id: String, cost: int, affordable: bool) -> void:
                if not _touch_mode:
                                return
                if not is_instance_valid(_confirm_panel):
                                _build_touch_confirm()
                if not is_instance_valid(_confirm_panel):
                                return
                var icon: String = "⚡" if item_id.begins_with("anomaly:") else "🧬"
                _confirm_ok_btn.text = ("ПОСТАВИТЬ" if Loc.lang == "ru" else "PLACE") + "\n" + icon + str(cost)
                _confirm_ok_btn.modulate = Color.WHITE if affordable else Color(1.0, 0.55, 0.5)
                _confirm_panel.visible = true


func hide_placement_confirm() -> void:
                if is_instance_valid(_confirm_panel):
                                _confirm_panel.visible = false


## Установка прошла: кисть осталась активной, отсчёт автосворачивания заново
func notify_placement_done() -> void:
                _last_touch_activity_ms = Time.get_ticks_msec()


## Подтверждение на красном призраке: тряска панели, ничего не списано
func placement_failed() -> void:
                if not is_instance_valid(_confirm_panel):
                                return
                var base_x: float = _confirm_panel.offset_left
                var tw := create_tween()
                for off in [-8.0, 8.0, -5.0, 5.0, 0.0]:
                                tw.tween_property(_confirm_panel, "offset_left", base_x + off, 0.045)


func _on_confirm_place() -> void:
                _play_click_sound()
                var zc = get_tree().get_first_node_in_group("zone_controller")
                if zc and zc.has_method("confirm_placement"):
                                zc.confirm_placement()


func _on_confirm_cancel() -> void:
                _play_click_sound()
                # Кисть выключается той же логикой, что и повторный тап по её кнопке
                if _pending_item != "" and _pending_button:
                                _toggle_placement(_pending_button, _pending_item)
                var zc = get_tree().get_first_node_in_group("zone_controller")
                if zc and zc.has_method("cancel_placement"):
                                zc.cancel_placement()


func _apply_safe_area() -> void:
                """D8: сдвиг шапки ресурсов от верхнего выреза и нижних панелей
                (СТАРТ/ВЫБРОС, подтверждение) от нижнего. На обычных экранах 0."""
                if not HudMobile.SAFE_AREA_APPLY:
                                return
                var sa := DisplayServer.get_display_safe_area()
                var win := DisplayServer.window_get_size()
                if sa.size == Vector2i.ZERO or win.y <= 0 or win.x <= 0:
                                return
                # Пиксели окна -> юниты канваса (видимая область в координатах UI)
                var vis := get_viewport().get_visible_rect().size
                var kx: float = vis.x / float(win.x)
                var ky: float = vis.y / float(win.y)
                var top: float = maxf(float(sa.position.y), 0.0) * ky
                var bottom: float = maxf(float(win.y - sa.end.y), 0.0) * ky
                var left: float = maxf(float(sa.position.x), 0.0) * kx
                if top > 4.0:
                                var res: Panel = get_node_or_null("Resources")
                                if res:
                                                res.offset_top += top
                                                res.offset_bottom += top
                if bottom > 4.0:
                                for pname in ["StartPanel", "EmissionPanel"]:
                                                var p: Panel = get_node_or_null(pname)
                                                if p:
                                                                p.offset_top -= bottom
                                                                p.offset_bottom -= bottom
                                if is_instance_valid(_confirm_panel):
                                                _confirm_panel.offset_top -= bottom
                                                _confirm_panel.offset_bottom -= bottom
                if left > 4.0:
                                # sensor_landscape: вырез может оказаться слева
                                if anomaly_panel:
                                                anomaly_panel.offset_left += left
                                                anomaly_panel.offset_right += left
