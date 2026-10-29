# zones/zone_controller.gd
extends Node
class_name ZoneController

## Единый контроллер зоны - оркестрирует все менеджеры

# Сигналы (прокси для менеджеров)
signal energy_changed(current: float, max_value: float)
signal biomass_changed(current: float, max_value: float)
signal radiation_pulse_started(level: int)
signal radiation_pulse_ended
signal wave_started(wave_number: int, count: int)
signal wave_ended(wave_number: int, survivors: int)
signal wave_break_started(wave_number: int, break_duration: float)
signal game_over
signal game_won(run_number: int, reward: float)

# Сигналы от HUD
# Менеджеры
var resource_manager: ResourceManager
var anomaly_manager: AnomalyManager
var spawn_manager: SpawnManager
var event_manager: EventManager
var progression_manager: ProgressionManager

# Визуальные менеджеры
var fog_manager: FogManager
var particle_manager: ParticleManager
var sound_manager: SoundManager

# Конфигурация (загружается из сцены)
@export var anomaly_scenes: Dictionary = {}
@export var anomaly_artifact_map: Dictionary = {}
@export var artifact_values: Dictionary = {}
@export var difficulty_to_rarity: Dictionary = {}

@export var novice_stalker_scene: PackedScene
@export var veteran_stalker_scene: PackedScene
@export var master_stalker_scene: PackedScene
@export var mutant_scenes: Dictionary = {}

@export var max_energy: float = 1000.0
@export var max_biomass: float = 999999.0  # капа дохода НЕТ (решение владельца);
                                           # инфляцию сдерживают стоки (магазин/обменник/базар), не потолок
@export var critical_biomass_threshold: float = 0.4
@export var pulse_duration: float = 5.0
# Победа: 3 выброса (от кнопки или от переполнения биомассы) ИЛИ отбить все волны
@export var pulses_to_win: int = 3

# Параметры забега
var run_params: Dictionary = {}
var is_initialized: bool = false
# Забег уже завершается (одноразовый finish_run)
var is_run_finished: bool = false
# Купленные в магазине артефакты: спавн у монолита на старте забега
var _shop_artifacts_pending: Array[String] = []
# Награды гачи/вех/событий за забег (для панели итогов)
var _gacha_rewards_log: Array[String] = []
# Фаза подготовки: сталкеры не спавнятся, пока игрок не нажмёт СТАРТ
var is_prep_phase: bool = true
# Мобильный режим «тап = ставить»: "" | "anomaly:<type>" | "mutant:<type>"
# Включается/выключается из HUD (кнопки аномалий/мутантов на тач-устройствах),
# тап по земле (Signals.ground_tapped) ставит выбранное в точку
var _pending_placement: String = ""

# Итоги забега (v0.31.2): киллы по рангам сталкеров для панели итогов
var _kills_by_rank: Dictionary = {"novice": 0, "veteran": 0, "master": 0}

# Погода Припяти (v0.31.2): радиоактивный дождь между волнами
var _weather: PripyatWeather = null

# Поп-апы забега (события Зоны / торговец) - канвас-слой над HUD
var run_popups: RunPopups

# Цикл дня и ночи (v0.29.0 «СВЕТ И ТЕНЬ»): часы суток, покраска света, бонус ночной добычи
var day_night_manager: DayNightManager

# Эффект Выброса Зоны (emission_fx/, пак подготовщика): инстанс у Монолита,
# кривую интенсивности ведёт _play_emission_fx() по сигналам пульса
var _emission_fx: Node3D = null
var _emission_tween: Tween = null
# Задача 22: играет ли сейчас босс-луп (Хранитель/финал) - для возврата на run
var _boss_music_active: bool = false

# D19 ОХОТА: активна ли, очередь боссов, таймер, убитые
var _hunt_active: bool = false
var _hunt_time_left: float = 0.0
var _hunt_queue: Array = []
var _hunt_killed: Array = []
var _hunt_boss_node: Node = null

# Радиационный фон Припяти (RadiationData): зона по расстоянию
# Монолит -> Саркофаг; "" = процедурная карта, фона нет
var radiation_zone: String = ""
var _base_energy_regen: float = -1.0
var _rad_tick_time: float = 0.0


func _exit_tree():
                # Ушли из забега (лаборатория/меню): эмбиент ветра/ночи не должен
                # звучать за пределами зоны
                var sm_ex = get_tree().get_first_node_in_group("sound_manager")
                if sm_ex and sm_ex.has_method("stop_ambient"):
                                sm_ex.stop_ambient()


func _ready():
                pass # print("ZoneController: инициализация...")
                add_to_group("zone_controller")
                # Мобильный режим «тап = ставить»: камера шлёт тапы по земле
                Signals.ground_tapped.connect(_on_ground_tapped)
                # D8: движение пальца при активной кисти - призрак следует за пальцем
                Signals.ground_hovered.connect(_on_ground_hovered)

                # Загружаем параметры забега из GameManager
                if get_tree().root.has_meta("run_params"):
                                run_params = get_tree().root.get_meta("run_params")
                                get_tree().root.remove_meta("run_params")
                                pass # print("Параметры забега загружены: " + str(run_params))

                _setup_managers()
                _connect_managers()

                # Ждём появления TerrainGenerator
                await _wait_for_terrain_generator()

                # Принудительно загружаем чанки вокруг монолита
                await _force_initial_chunk_load()

                # Инициализируем забег
                _initialize_run()

                # Подключаемся к HUD
                await _connect_to_hud()

                # Постэффект «мрачная зона»: Припять мрачнее, процедурная Зона мягче
                add_child(GrimPostfxLayer.new(1.25 if str(run_params.get("map", "procedural")) == "pripyat" else 1.0))

                # Боевая музыка
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_music"):
                                sm.play_music("run")
                # Эмбиент забега (задача 15): ветер - лесной на Припяти, степной в Зоне
                if sm and sm.has_method("play_ambient"):
                                sm.play_ambient("wind_forest_01" if str(run_params.get("map", "procedural")) == "pripyat" else "wind_open_01")
                # Погода Припяти (v0.31.2): радиоактивный дождь на передышках
                if str(run_params.get("map", "procedural")) == "pripyat" and spawn_manager:
                                _weather = PripyatWeather.new()
                                add_child(_weather)
                                spawn_manager.break_started.connect(func(_w: int, _d: float): _weather.roll_break())
                if day_night_manager:
                                day_night_manager.phase_changed.connect(_on_day_phase_changed)

                is_initialized = true

                # Поп-апы забега (события Зоны / торговец) - канвас-слой над HUD
                run_popups = RunPopups.new()
                add_child(run_popups)
                run_popups.modal_closed.connect(_on_run_popup_closed)
                pass # print("ZoneController: готов!")


func _wait_for_terrain_generator():
                """Ждёт появления TerrainGenerator"""
                pass # print("ZoneController: ожидание TerrainGenerator...")
                var attempts = 0
                var max_attempts = 30

                while not get_tree().get_first_node_in_group("terrain_generator") and attempts < max_attempts:
                                await get_tree().process_frame
                                attempts += 1

                if get_tree().get_first_node_in_group("terrain_generator"):
                                pass # print("ZoneController: TerrainGenerator НАЙДЕН!")
                else:
                                pass # print("ZoneController: TerrainGenerator НЕ НАЙДЕН после ", max_attempts, " попыток!")


func _force_initial_chunk_load():
                """Принудительно загружает чанки вокруг монолита при старте"""
                var terrain = get_tree().get_first_node_in_group("terrain_generator")
                if not terrain:
                                pass # print("ZoneController: TerrainGenerator не найден, пропускаем загрузку чанков")
                                return

                var monolith_node = get_tree().get_first_node_in_group("monolith")
                if not monolith_node:
                                pass # print("ZoneController: Монолит не найден!")
                                return

                pass # print("ZoneController: принудительная загрузка чанков вокруг монолита...")

                # Сохраняем позицию камеры
                var camera = get_viewport().get_camera_3d()
                var original_pos = camera.global_position if camera else Vector3.ZERO

                # Временно перемещаем камеру к монолиту
                if camera:
                                camera.global_position = monolith_node.global_position + Vector3(0, 50, 0)
                                await get_tree().process_frame
                                await get_tree().process_frame

                # Принудительно обновляем чанки несколько раз
                for i in range(3):
                                if terrain.has_method("_update_chunks"):
                                                terrain._update_chunks()
                                await get_tree().process_frame

                # Принудительно перестраиваем навигацию
                if terrain.has_method("force_rebuild_navigation"):
                                terrain.force_rebuild_navigation()

                # Возвращаем камеру на место
                if camera and original_pos != Vector3.ZERO:
                                camera.global_position = original_pos

                pass # print("ZoneController: начальная загрузка чанков завершена. Загружено чанков: ", 
                                # terrain.get_loaded_chunks_count() if terrain.has_method("get_loaded_chunks_count") else 0)


func start_run():
                """Запускает спавн сталкеров после фазы подготовки"""
                if not is_prep_phase:
                                return
                is_prep_phase = false
                if str(run_params.get("run_mode", "")) == "hunt":
                                _hunt_begin()
                                return
                pass # print("ZoneController: СТАРТ - сталкеры пошли!")
                spawn_manager.start_spawning()


# ==================== ОХОТА (D19) ====================

func _hunt_begin():
                """Старт охоты: спавн боссов дня у края, таймер, объявление"""
                _hunt_active = true
                _hunt_time_left = float(run_params.get("hunt_time", BossHuntData.HUNT_TIME))
                _hunt_queue = (run_params.get("hunt_bosses", []) as Array).duplicate()
                _hunt_killed = []
                _hunt_spawn_next()
                var hud0 = get_tree().get_first_node_in_group("hud")
                if hud0 and hud0.has_method("show_hunt_time"):
                                hud0.show_hunt_time(int(_hunt_time_left))
                if hud0 and hud0.has_method("show_event_note"):
                                hud0.show_event_note({
                                                "title_ru": "ОХОТА",
                                                "title_en": "THE HUNT",
                                                "desc_ru": "Босс уйдёт из Зоны - не дай. %d сек." % int(_hunt_time_left),
                                                "desc_en": "The boss will leave the Zone - stop it. %d sec." % int(_hunt_time_left),
                                })


func _hunt_spawn_next():
                """Спавн следующего босса очереди (с противоположной стороны карты)"""
                if _hunt_queue.is_empty():
                                return
                var id: String = str(_hunt_queue.pop_front())
                var data: Dictionary = BossHuntData.BOSSES.get(id, {})
                if data.is_empty():
                                _hunt_spawn_next()
                                return
                var cycle: int = 1
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.current_save_data and "campaign_cycle" in gm.current_save_data:
                                cycle = int(gm.current_save_data.campaign_cycle)
                var ang := randf() * TAU
                var from := Vector3(cos(ang), 0.0, sin(ang)) * 140.0
                var to := Vector3(-cos(ang), 0.0, -sin(ang)) * 30.0
                var pm := get_tree().get_first_node_in_group("terrain_generator")
                if pm and pm.has_method("get_terrain_height"):
                                from.y = pm.get_terrain_height(from.x, from.z)
                                to.y = pm.get_terrain_height(to.x, to.z)
                var boss := BossBase.new()
                add_child(boss)
                boss.setup(id, data, BossHuntData.boss_stat_mult(cycle), from, to)
                boss.died.connect(_on_hunt_boss_died)
                boss.escaped.connect(_on_hunt_boss_escaped)
                _hunt_boss_node = boss


func _hunt_process(delta: float) -> void:
                if not _hunt_active:
                                return
                _hunt_time_left -= delta
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("show_hunt_time"):
                                hud.show_hunt_time(maxi(int(ceil(_hunt_time_left)), 0))
                if _hunt_time_left <= 0.0:
                                _hunt_active = false
                                _hunt_finish(false, "таймер вышел - босс ушёл")


func _on_hunt_boss_died(boss_id: String, sparks: int) -> void:
                _hunt_killed.append(boss_id)
                # Награда: Искры - первый килл босса за день; повтор - биомасса
                var gm = get_tree().get_first_node_in_group("game_manager")
                var today: String = Time.get_date_string_from_system()
                var first_time: bool = true
                if gm and gm.current_save_data:
                                var claimed: Dictionary = gm.current_save_data.hunt_claimed
                                var todays: Array = claimed.get(today, [])
                                if boss_id in todays:
                                                first_time = false
                                if first_time:
                                                var bonus: int = BossHuntData.SUNDAY_BONUS_SPARK if Time.get_date_dict_from_system().get("weekday", 1) == 0 else 0
                                                if gm.current_save_data.lab_data:
                                                                gm.current_save_data.lab_data.add_sparks(sparks + bonus)
                                                todays.append(boss_id)
                                                claimed[today] = todays
                                                gm.save_to_active_slot()
                                                var hud = get_tree().get_first_node_in_group("hud")
                                                if hud and hud.has_method("show_reward_note"):
                                                                hud.show_reward_note("+%d Искры Пробуждения" % (sparks + bonus))
                                elif gm.current_save_data.lab_data:
                                                gm.current_save_data.lab_data.biomass += BossHuntData.REPEAT_REWARD_BIO
                # Следующий босс очереди или победа
                if _hunt_queue.is_empty():
                                _hunt_active = false
                                _hunt_finish(true, "")


func _on_hunt_boss_escaped(boss_id: String) -> void:
                _hunt_active = false
                _hunt_finish(false, "босс ушёл из Зоны")


func _hunt_finish(victory: bool, reason: String) -> void:
                if is_run_finished:
                                return
                var hud = get_tree().get_first_node_in_group("hud")
                if hud:
                                hud.wave_label.text = ("ОХОТА: ПОБЕДА" if victory else "ОХОТА: БОСС УШЁЛ") + "  ·  " + reason
                                hud.wave_label.visible = true
                finish_run(victory)


func _hunt_active_check() -> bool:
                return _hunt_active


func _on_wave_break_started(wave_number: int, break_duration: float):
                wave_break_started.emit(wave_number, break_duration)
                _maybe_trigger_run_event(wave_number, break_duration)
                # D9: выживание на Припяти - честное предупреждение, откуда придёт волна
                if spawn_manager and spawn_manager.gate_mode and not spawn_manager.gate_points.is_empty():
                                var next_wave: int = wave_number + 1
                                var hud_break = get_tree().get_first_node_in_group("hud")
                                if hud_break:
                                                hud_break.show_wave_gates(_active_gate_points(next_wave))
                                                if hud_break.has_method("show_gate_warning"):
                                                                hud_break.show_gate_warning(next_wave, SurvivalData.gate_directions(next_wave))


## Мировые координаты спавн-врат Припяти (D9): lat/lon -> мир + высота рельефа
func _compute_gate_points() -> Array[Vector3]:
                var points: Array[Vector3] = []
                var pm = get_tree().get_first_node_in_group("terrain_generator")
                if pm == null or not pm.has_method("latlon_to_world"):
                                return points
                for gate in SurvivalData.SPAWN_GATES:
                                var w: Vector2 = pm.latlon_to_world(float(gate["lat"]), float(gate["lon"]))
                                var h: float = pm.get_terrain_height(w.x, w.y) if pm.has_method("get_terrain_height") else 0.0
                                points.append(Vector3(w.x, h, w.y))
                return points


## Точки активных врат будущей волны (для миникарты в передышке)
func _active_gate_points(wave: int) -> Array:
                var points: Array = []
                var all_points: Array[Vector3] = spawn_manager.gate_points
                if all_points.is_empty():
                                return points
                var n: int = mini(SurvivalData.gates_for_wave(wave), all_points.size())
                var start: int = SurvivalData.gates_start_index(wave) % all_points.size()
                for i in range(n):
                                points.append(all_points[(start + i) % all_points.size()])
                return points


func _on_all_waves_cleared():
                """Все 3 волны отбиты, сталкеров не осталось - победа"""
                if is_run_finished:
                                return
                pass # print("ПОБЕДА: все волны отбиты!")
                finish_run(true)


func _connect_to_hud():
                """Подключается к HUD после его создания"""
                var hud = get_tree().get_first_node_in_group("hud")
                var attempts = 0
                var max_attempts = 10

                while not hud and attempts < max_attempts:
                                await get_tree().create_timer(0.5).timeout
                                hud = get_tree().get_first_node_in_group("hud")
                                attempts += 1

                if hud:
                                hud.anomaly_requested.connect(_on_hud_anomaly_requested)
                                hud.mutant_requested.connect(_on_hud_mutant_requested)
                                if hud.has_signal("start_run_requested"):
                                                hud.start_run_requested.connect(start_run)
                                if hud.has_signal("trader_requested"):
                                                hud.trader_requested.connect(_open_trader)
                                if spawn_manager and spawn_manager.has_signal("synergy_activated"):
                                                spawn_manager.synergy_activated.connect(_on_synergy_activated)
                                pass # print("ZoneController: HUD подключен")
                else:
                                pass # print("ZoneController: HUD не найден после ", max_attempts, " попыток")


func _setup_managers():
                # ResourceManager
                resource_manager = ResourceManager.new()
                resource_manager.max_energy = max_energy
                resource_manager.max_biomass = max_biomass
                resource_manager.critical_threshold = critical_biomass_threshold
                add_child(resource_manager)
                pass # print("ResourceManager создан")

                # AnomalyManager
                anomaly_manager = AnomalyManager.new()
                anomaly_manager.anomaly_scenes = anomaly_scenes
                anomaly_manager.anomaly_artifact_map = anomaly_artifact_map if not anomaly_artifact_map.is_empty() else GachaData.ANOMALY_ARTIFACT_MAP
                anomaly_manager.artifact_values = artifact_values
                anomaly_manager.difficulty_to_rarity = difficulty_to_rarity
                add_child(anomaly_manager)
                pass # print("AnomalyManager создан")

                # SpawnManager
                spawn_manager = SpawnManager.new()
                spawn_manager.stalker_scenes = {
                                "novice": novice_stalker_scene,
                                "veteran": veteran_stalker_scene,
                                "master": master_stalker_scene
                }
                spawn_manager.mutant_scenes = mutant_scenes
                add_child(spawn_manager)
                pass # print("SpawnManager создан")

                # EventManager
                event_manager = EventManager.new()
                event_manager.pulse_duration = pulse_duration
                add_child(event_manager)
                pass # print("EventManager создан")

                # ProgressionManager
                progression_manager = ProgressionManager.new()
                add_child(progression_manager)
                pass # print("ProgressionManager создан")

                # FogManager
                fog_manager = FogManager.new()
                fog_manager.enabled = true
                add_child(fog_manager)
                pass # print("FogManager создан")

                # Цикл дня и ночи (v0.29.0): свет/фон/туман по часам суток
                day_night_manager = DayNightManager.new()
                add_child(day_night_manager)
                pass # print("DayNightManager создан")

                # ParticleManager
                particle_manager = ParticleManager.new()
                add_child(particle_manager)
                pass # print("ParticleManager создан")

                # SoundManager
                sound_manager = SoundManager.new()
                add_child(sound_manager)
                pass # print("SoundManager создан")


func _connect_managers():
                # ResourceManager
                resource_manager.energy_changed.connect(_on_energy_changed)
                resource_manager.biomass_changed.connect(_on_biomass_changed)
                resource_manager.critical_biomass_reached.connect(_on_critical_biomass)

                # EventManager
                event_manager.radiation_pulse_started.connect(_on_radiation_pulse_started)
                event_manager.radiation_pulse_ended.connect(_on_radiation_pulse_ended)
                event_manager.game_over.connect(_on_game_over)
                event_manager.game_won.connect(_on_game_won)

                # SpawnManager
                spawn_manager.wave_started.connect(_on_wave_started)
                spawn_manager.wave_ended.connect(_on_wave_ended)
                spawn_manager.break_started.connect(_on_wave_break_started)
                spawn_manager.all_waves_cleared.connect(_on_all_waves_cleared)
                spawn_manager.stalker_died.connect(_on_stalker_died)
                spawn_manager.mutant_spawned.connect(_on_mutant_spawned)

                # AnomalyManager
                anomaly_manager.anomaly_created.connect(_on_anomaly_created)
                anomaly_manager.anomaly_destroyed.connect(_on_anomaly_destroyed)
                anomaly_manager.artifact_created.connect(_on_artifact_created)
                anomaly_manager.artifact_stolen.connect(_on_artifact_stolen)

                # Прокси сигналы в глобальные
                anomaly_manager.anomaly_created.connect(func(a, t, d): Signals.anomaly_created.emit(a, t, a.global_position, d))
                anomaly_manager.artifact_created.connect(func(a, t, p): Signals.artifact_created.emit(a, t, p, a.get_value() if a.has_method("get_value") else 0))
                spawn_manager.stalker_spawned.connect(func(s, t): Signals.stalker_spawned.emit(s, t, s.global_position))
                spawn_manager.mutant_spawned.connect(func(m, t): Signals.mutant_spawned.emit(m, t, m.global_position, spawn_manager.get_mutant_cost(t)))

                # Цикл дня и ночи: анонс наступления ночи
                day_night_manager.phase_changed.connect(_on_daynight_phase_changed)


func _initialize_run():
                var run_data = progression_manager.start_new_run()
                var run_number: int = run_data.run_number
                var run_difficulty: float = run_data.difficulty
                var pulses: int = pulses_to_win

                # Кампания: параметры уровня перекрывают дефолтную прогрессию забегов
                if run_params.has("campaign_params"):
                                var campaign: Dictionary = run_params["campaign_params"]
                                run_number = int(run_params.get("campaign_level", run_data.run_number))
                                run_difficulty = float(campaign.get("hp_mult", 1.0))
                                pulses = int(campaign.get("pulses_to_win", pulses_to_win))

                                progression_manager.current_run = run_number
                                progression_manager.current_difficulty = run_difficulty

                                spawn_manager.max_waves = int(campaign.get("waves", spawn_manager.max_waves))
                                spawn_manager.min_stalkers_per_wave = int(campaign.get("count_min", spawn_manager.min_stalkers_per_wave))
                                spawn_manager.max_stalkers_per_wave = int(campaign.get("count_max", spawn_manager.max_stalkers_per_wave))
                                spawn_manager.wave_break = float(campaign.get("wave_break", spawn_manager.wave_break))
                                # Количество сталкеров задаёт уровень кампании, а не множитель сложности
                                spawn_manager.set_difficulty(1.0)
                                spawn_manager.set_rank_weights(campaign.get("mix", [90, 10, 0]))
                                spawn_manager.set_campaign_scaling(
                                                float(campaign.get("hp_mult", 1.0)),
                                                float(campaign.get("damage_mult", 1.0)),
                                                float(campaign.get("speed_mult", 1.0)))

                                # Стражи башни (25/50/75/100): доля элиты в волнах
                                spawn_manager.set_elite_share(float(campaign.get("elite_pct", 0.0)))

                                # Припять: Монолит перемещается по маршруту ярусов
                                # (центр города -> Саркофаг), точка - от уровня/этажа
                                if str(run_params.get("map", "procedural")) == "pripyat":
                                                var pm := get_tree().get_first_node_in_group("terrain_generator")
                                                var mono := get_tree().get_first_node_in_group("monolith")
                                                if pm and pm.has_method("monolith_position_for_level") and mono:
                                                                mono.global_position = pm.monolith_position_for_level(
                                                                                int(campaign.get("level", 1)))
                elif run_params.get("run_mode", "campaign") == "survival":
                                # Выживание: волны бесконечны, победы нет; эскалацию считает SurvivalData
                                var survival: Dictionary = run_params.get("survival_params", {})

                                progression_manager.current_run = run_data.run_number
                                progression_manager.current_difficulty = float(survival.get("hp_mult", 1.0))

                                spawn_manager.endless_mode = true
                                spawn_manager.set_difficulty(1.0)
                                _apply_survival_wave(survival)

                                # Сброс состояния фазы легенды на новом забеге
                                _next_wave_modifier = {}
                                _wave_modifier = {}
                                _harvest_mult = 1.0
                                _phase_announced = {}

                                # Припять: Монолит выживания - старт маршрута (центр Припяти),
                                # а не мировое (0,0) района
                                if str(run_params.get("map", "procedural")) == "pripyat":
                                                var pm_s := get_tree().get_first_node_in_group("terrain_generator")
                                                var mono_s := get_tree().get_first_node_in_group("monolith")
                                                if pm_s and pm_s.has_method("monolith_position_for_level") and mono_s:
                                                                mono_s.global_position = pm_s.monolith_position_for_level(1)
                                                # Врата Припяти (D9): сталкеры приходят из районов города
                                                spawn_manager.gate_mode = true
                                                spawn_manager.gate_points = _compute_gate_points()
                                                var hud_first = get_tree().get_first_node_in_group("hud")
                                                if hud_first and hud_first.has_method("show_event_note"):
                                                                hud_first.show_event_note({
                                                                                "title_ru": "ГОРОД ЖИВЁТ СВОЕЙ ЖИЗНЬЮ",
                                                                                "title_en": "THE CITY LIVES ITS OWN LIFE",
                                                                                "desc_ru": "Сталкеры придут с улиц: активные врата видны на миникарте в передышке.",
                                                                                "desc_en": "Stalkers will come through the streets: active gates are shown on the minimap between waves.",
                                                                })

                                event_manager.endless_mode = true
                                pulses = 0

                # D19 ОХОТА: Монолит не участвует - прячем и выключаем
                if str(run_params.get("run_mode", "")) == "hunt":
                                var mono_h := get_tree().get_first_node_in_group("monolith")
                                if mono_h:
                                                mono_h.visible = false
                                                mono_h.process_mode = Node.PROCESS_MODE_DISABLED
                                                if mono_h is CollisionObject3D:
                                                                mono_h.collision_layer = 0

                event_manager.set_pulses_to_win(pulses)
                event_manager.set_run_number(run_number)
                event_manager.set_difficulty(run_difficulty)

                # Применяем бонусы из лаборатории
                _apply_lab_bonuses()

                # Звёздность коллекции: спавнящиеся мутанты получают свои звёзды
                if spawn_manager and run_params.has("mutant_stars"):
                                spawn_manager.set_mutant_stars(run_params["mutant_stars"])

                # Стартовая биомасса забега (остаток лаборатории + 300)
                resource_manager.current_biomass = clamp(
                                run_params.get("start_biomass", 300.0), 0.0, max_biomass)

                # Покупки магазина: наградные мутанты в очередь, артефакты у монолита
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.has_method("consume_shop_purchases"):
                                var shop: Dictionary = gm.consume_shop_purchases()
                                for t in shop.get("mutants", []):
                                                spawn_manager.queue_reward_mutant(t)
                                for a in shop.get("artifacts", []):
                                                _shop_artifacts_pending.append(a)

                # Эксклюзивы Чёрного ящика: питомцы коллекции каждый забег у монолита
                if gm and gm.has_method("get_owned_exclusives"):
                                # v0.30.0: вариантов стало много — стартовый отряд у монолита
                                # ограничен 6, приоритет легендаркам, затем по таблице.
                                var start_squad: Array = gm.get_owned_exclusives()
                                var legendaries: Array = []
                                var others: Array = []
                                for t in start_squad:
                                                if GachaData.get_mutant_rarity(str(t)) == "legendary":
                                                                legendaries.append(t)
                                                else:
                                                                others.append(t)
                                start_squad = legendaries + others
                                for i in mini(start_squad.size(), 6):
                                                spawn_manager.queue_reward_mutant(str(start_squad[i]))

                # Артефакты из магазина - приманка у монолита
                for a in _shop_artifacts_pending:
                                if anomaly_manager:
                                                anomaly_manager.create_artifact(a, Vector3(8.0, 1.8, 8.0), "common", 0.0)
                                                pass # print("Магазин: артефакт ", a, " размещён у монолита")
                _shop_artifacts_pending.clear()

                _gacha_rewards_log.clear()
                _kills_by_rank = {"novice": 0, "veteran": 0, "master": 0}
                _trophy_artifacts.clear()
                _trader_sold.clear()
                _event_reward_mult = 1.0
                _event_biomass_flat = 0.0
                _event_harvest_mult = 1.0
                _event_regen_saved = -1.0
                _break_index = 0
                _last_event_id = ""
                if spawn_manager:
                                spawn_manager.crowd_bonus = 0
                # Фаза подготовки: спавн сталкеров начнётся по кнопке СТАРТ в HUD
                # (лог отключён)
                if run_params.has("campaign_params"):
                                pass # (лог отключён)
                elif run_params.get("run_mode", "") == "survival":
                                pass # (лог отключён)
                # Штандарт Башни у Монолита: флаг окрашен в цвет яруса этажа
                if run_params.get("run_mode", "") == "tower":
                                _spawn_tower_banner()

                # Эффект Выброса (обе карты): инстанс на позиции Монолита
                _setup_emission_fx()

                # Радиационный фон Припяти: после lab-бонусов, множитель поверх прокачки
                _setup_radiation_zone()

                Signals.run_started.emit(run_number, run_difficulty, pulses)
                pass # print(run_label + " в фазе подготовки (множитель врагов: " + str(run_difficulty) + "). Расставьте защиты и нажмите СТАРТ.")


## Штандарт Башни у Монолита (models/tower/banner_pole.glb): флаг -
## отдельный меш "flag" с нейтральным материалом, красим в цвет яруса
## этажа (TowerData.TIER_COLORS). Нет модели или Монолита - тихо пропускаем.
func _spawn_tower_banner():
                const PATH := "res://models/tower/banner_pole.glb"
                if not ResourceLoader.exists(PATH):
                                return
                var monolith := get_tree().get_first_node_in_group("monolith") as Node3D
                if monolith == null:
                                return
                var scene := load(PATH) as PackedScene
                if scene == null:
                                return
                var pole := scene.instantiate() as Node3D
                get_tree().current_scene.add_child(pole)

                # Сбоку от Монолита, лицом к стартовой камере
                var cam := get_viewport().get_camera_3d()
                var dir := Vector3(1, 0, 1).normalized()
                if cam:
                                var to_cam := cam.global_position - monolith.global_position
                                to_cam.y = 0.0
                                if to_cam.length() > 0.5:
                                                dir = to_cam.normalized()
                pole.global_position = monolith.global_position + dir * 4.0
                if cam:
                                pole.look_at(cam.global_position, Vector3.UP)

                var floor_num: int = int(run_params.get("tower_floor", 1))
                var idx: int = clampi((floor_num - 1) / 10, 0, TowerData.TIER_COLORS.size() - 1)
                var flag_mat := StandardMaterial3D.new()
                flag_mat.albedo_color = TowerData.TIER_COLORS[idx]
                flag_mat.roughness = 0.9
                var flag := pole.find_child("flag", true, false) as MeshInstance3D
                if flag:
                                flag.material_override = flag_mat


## Эффект Выброса Зоны (emission_fx/): багровое небо, ударная волна от
## Монолита, пепел и столбы света. Нет пака/Монолита - тихий пропуск,
## выброс работает как раньше (частицы particle_manager + звук).
func _setup_emission_fx():
                const PATH := "res://emission_fx/scenes/emission_fx.tscn"
                if not ResourceLoader.exists(PATH):
                                return
                var monolith := get_tree().get_first_node_in_group("monolith") as Node3D
                if monolith == null:
                                return
                var scene := load(PATH) as PackedScene
                if scene == null:
                                return
                _emission_fx = scene.instantiate() as Node3D
                get_tree().current_scene.add_child(_emission_fx)
                # Origin сцены = центр волны, y = уровень земли (Монолит на земле)
                _emission_fx.global_position = monolith.global_position


## Смена фазы суток (v0.29.0): на ночь эмбиент меняется на стрекот,
## редкий дальний вой; на день - ветер обратно
func _on_day_phase_changed(phase: String) -> void:
                var sm_dn = get_tree().get_first_node_in_group("sound_manager")
                if sm_dn == null or not sm_dn.has_method("play_ambient"):
                                return
                if phase == "night":
                                sm_dn.play_ambient("night_insects_01")
                                if randf() < 0.5:
                                                sm_dn.play_sound("howl_distant_01", 0.5)
                else:
                                sm_dn.play_ambient("wind_forest_01" if str(run_params.get("map", "procedural")) == "pripyat" else "wind_open_01")


## Кривая интенсивности по длительности пульса: рост -> плато -> спад.
## Волна/эхо едут сами от start(), интенсивность - отдельная ось эффекта.
func _play_emission_fx():
                if _emission_fx == null or not is_instance_valid(_emission_fx):
                                return
                if _emission_tween and _emission_tween.is_valid():
                                _emission_tween.kill()
                var total: float = maxf(pulse_duration, 4.0)
                var rise := minf(1.5, total * 0.3)
                var fall := minf(2.0, total * 0.4)
                _emission_fx.start()
                # Звук катастрофы (задача 17): удар волны + гул; огибающая гула
                # совпадает с кривой (рост 1.5/плато/спад 2) - громкость не ведём
                var sm_fx = get_tree().get_first_node_in_group("sound_manager")
                if sm_fx:
                                sm_fx.play_sound("emission_burst", 0.9)
                                sm_fx.play_sound("emission_rumble", 1.0)
                _emission_tween = create_tween()
                _emission_tween.tween_method(
                                func(v: float): _emission_fx.set_intensity(v), 0.0, 1.0, rise) \
                                .set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
                _emission_tween.tween_interval(maxf(0.0, total - rise - fall))
                _emission_tween.tween_method(
                                func(v: float): _emission_fx.set_intensity(v), 1.0, 0.0, fall) \
                                .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
                _emission_tween.tween_callback(_emission_fx.stop)


## Досрочная страховка: погасить эффект, даже если твин ещё жив
func _stop_emission_fx():
                if _emission_tween and _emission_tween.is_valid():
                                _emission_tween.kill()
                _emission_tween = null
                if _emission_fx and is_instance_valid(_emission_fx):
                                _emission_fx.set_intensity(0.0)
                                _emission_fx.stop()
                var sm_st = get_tree().get_first_node_in_group("sound_manager")
                if sm_st and sm_st.has_method("stop_sound"):
                                sm_st.stop_sound("emission_rumble", 0.3)


## Радиационный фон Припяти (спека pripyat_radiation): зона по расстоянию
## Монолит -> Саркофаг. Реген/цены/дрейф HP/премия/постэффект - из
## RadiationData. Процедурная карта и выживание (ярус 1 = clean) - мимо.
func _setup_radiation_zone():
                if str(run_params.get("map", "procedural")) != "pripyat":
                                return
                var pm := get_tree().get_first_node_in_group("terrain_generator")
                var mono := get_tree().get_first_node_in_group("monolith") as Node3D
                if pm == null or mono == null or not pm.has_method("monolith_position_for_level"):
                                return
                var dist: float = mono.global_position.distance_to(
                                pm.monolith_position_for_level(100))
                radiation_zone = RadiationData.get_zone_by_distance(dist)
                var fx := RadiationData.get_effects(radiation_zone)
                var info := RadiationData.get_zone_info(radiation_zone)

                # Реген: множитель ПОВЕРХ прокачки лаборатории, базу сохраняем
                # один раз (защита от повторного умножения при перезаходе)
                if resource_manager:
                                if _base_energy_regen < 0.0:
                                                _base_energy_regen = resource_manager.energy_regen_rate
                                resource_manager.energy_regen_rate = maxf(
                                                _base_energy_regen * float(fx["regen_mult"]),
                                                _base_energy_regen * RadiationData.MAX_TOTAL_REGEN_MULT)

                # Свет и подпись Монолита зеленеют по зоне
                if mono is Monolith:
                                mono.apply_radiation_zone(
                                                RadiationData.LIGHT_COLORS.get(radiation_zone, Color.WHITE),
                                                "%s\n☢ %.0f мкЗв/ч" % [info["title_ru"], float(info["bg"])])

                # HUD-индикатор (на процедурной карте не показывается вовсе)
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("show_radiation"):
                                hud.show_radiation(radiation_zone)

                # Плашка на старте (зона != clean): честный расклад ДО первого клика
                if radiation_zone != "clean":
                                _note_hud({
                                                "title_ru": "☢ " + String(info["title_ru"]),
                                                "title_en": "☢ " + String(info["title_en"]),
                                                "desc_ru": "реген ×%.2f · аномалии +%d%% · сталкеры тают · награда ×%.2f" % [
                                                                float(fx["regen_mult"]),
                                                                roundi((float(fx["anomaly_cost_mult"]) - 1.0) * 100.0),
                                                                float(fx["reward_mult"])],
                                                "desc_en": "regen ×%.2f · anomalies +%d%% · stalkers decay · reward ×%.2f" % [
                                                                float(fx["regen_mult"]),
                                                                roundi((float(fx["anomaly_cost_mult"]) - 1.0) * 100.0),
                                                                float(fx["reward_mult"])],
                                })

                # Постэффект: множитель зоны поверх базового (кап общий)
                _update_postfx_strength(1.0)


## Тик радиационного дрейфа HP: новичок/ветеран/мастер платят по таблице
## зоны; мутанты и артефакты-приманки иммунны. Смерть от фона не платит
## биомассу (метка rad_death до смертельного тика, см. on_stalker_died).
func _process(delta: float):
                # D19: тик таймера охоты
                if _hunt_active:
                                _hunt_process(delta)
                if radiation_zone == "" or radiation_zone == "clean" or is_run_finished:
                                return
                if spawn_manager == null:
                                return
                _rad_tick_time += delta
                if _rad_tick_time < RadiationData.RAD_TICK_INTERVAL:
                                return
                _rad_tick_time = 0.0
                var fx := RadiationData.get_effects(radiation_zone)
                if float(fx["drain_hp"]) <= 0.0:
                                return
                for s in spawn_manager.get_active_stalkers():
                                if not is_instance_valid(s) or not s.get("health_component"):
                                                continue
                                var hc = s.health_component
                                if not hc.is_alive:
                                                continue
                                var is_master := false
                                if s.has_method("get_stalker_type"):
                                                is_master = s.get_stalker_type() == "master"
                                var rate: float = float(fx["drain_hp_master"] if is_master else fx["drain_hp"])
                                if rate <= 0.0:
                                                continue
                                if hc.current_health - rate <= 0.0:
                                                s.set_meta("rad_death", true)
                                hc.take_damage(rate, null)


func _apply_lab_bonuses():
                if not run_params.has("bonuses"):
                                return

                var bonuses = run_params["bonuses"]

                # Применяем бонусы к менеджерам
                if bonuses.has("anomaly_damage_mult") and anomaly_manager:
                                anomaly_manager.damage_multiplier = bonuses["anomaly_damage_mult"]

                if bonuses.has("anomaly_radius_mult") and anomaly_manager:
                                anomaly_manager.radius_multiplier = bonuses["anomaly_radius_mult"]

                if bonuses.has("mutant_health_mult") and spawn_manager:
                                spawn_manager.health_multiplier = bonuses["mutant_health_mult"]

                if bonuses.has("mutant_damage_mult") and spawn_manager:
                                spawn_manager.damage_multiplier = bonuses["mutant_damage_mult"]

                if bonuses.has("mutant_cost_mult") and spawn_manager:
                                spawn_manager.cost_multiplier = bonuses["mutant_cost_mult"]
                                # Ценники HUD рисуются до применения бонусов - перерисовать
                                var hud_prices = get_tree().get_first_node_in_group("hud")
                                if hud_prices and hud_prices.has_method("_apply_prices"):
                                                hud_prices._apply_prices.call_deferred()

                pass # print("Бонусы лаборатории применены: " + str(bonuses))


## Параметры волны выживания: тот же формат, что у уровня кампании
# ==================== ФАЗА ЛЕГЕНДЫ: СОСТОЯНИЕ ВОЛНЫ ====================
var _next_wave_modifier: Dictionary = {}   # модификатор СЛЕДУЮЩЕЙ волны (анонс)
var _wave_modifier: Dictionary = {}        # модификатор ТЕКУЩЕЙ волны
var _saved_regen: float = -1.0             # базовый реген до осадки ЭМ-туманом
var _saved_fog_density: float = -1.0       # базовая плотность тумана до Ночи
var _harvest_mult: float = 1.0             # ЖАТВА: множитель добычи за килл
var _phase_announced: Dictionary = {}      # анонсированные фазы (30/40/50)

func _apply_survival_wave(params: Dictionary):
                spawn_manager.min_stalkers_per_wave = int(params.get("count_min", 8))
                spawn_manager.max_stalkers_per_wave = int(params.get("count_max", 10))
                spawn_manager.wave_break = float(params.get("wave_break", 45.0))
                spawn_manager.set_rank_weights(params.get("mix", [100, 0, 0]))
                spawn_manager.set_campaign_scaling(
                                float(params.get("hp_mult", 1.0)),
                                float(params.get("damage_mult", 1.0)),
                                float(params.get("speed_mult", 1.0)))
                pass # print("Волна выживания %d: сталкеров %d-%d, состав н/в/м %s, множитель x%.2f" % [
                                # int(params.get("wave", 1)),
                                # int(params.get("count_min", 8)),
                                # int(params.get("count_max", 10)),
                                # str(params.get("mix", [])),
                                # float(params.get("hp_mult", 1.0))])

## Применить модификатор текущей волны (осадка/ночь/жатва)
func _apply_wave_modifier(mod: Dictionary):
                _harvest_mult = float(mod.get("kill_reward_mult", 1.0))
                if mod.has("regen_mult") and resource_manager:
                                if _saved_regen < 0.0:
                                                _saved_regen = resource_manager.energy_regen_rate
                                resource_manager.energy_regen_rate = _saved_regen * float(mod["regen_mult"])
                if mod.has("vision_mult"):
                                var vm: float = float(mod["vision_mult"])
                                for s in spawn_manager.get_active_stalkers():
                                                if is_instance_valid(s) and s.get("memory_component"):
                                                                s.memory_component.set_vision_range(s.detection_radius * vm)
                if mod.has("fog_mult"):
                                var fm = get_tree().get_first_node_in_group("fog_manager")
                                if fm != null:
                                                if _saved_fog_density < 0.0:
                                                                _saved_fog_density = fm.max_density
                                                fm.max_density = _saved_fog_density * float(mod["fog_mult"])
                _update_postfx_strength(float(mod.get("postfx_mult", 1.0)))
                if not mod.is_empty():
                                _note_hud(mod)


## Снять модификатор завершившейся волны
func _clear_wave_modifier():
                _harvest_mult = 1.0
                if _saved_regen >= 0.0 and resource_manager:
                                resource_manager.energy_regen_rate = _saved_regen
                _saved_regen = -1.0
                for s in spawn_manager.get_active_stalkers():
                                if is_instance_valid(s) and s.get("memory_component"):
                                                s.memory_component.set_vision_range(s.detection_radius)
                if _saved_fog_density >= 0.0:
                                var fm = get_tree().get_first_node_in_group("fog_manager")
                                if fm != null:
                                                fm.max_density = _saved_fog_density
                _saved_fog_density = -1.0
                _update_postfx_strength(1.0)


## Сила постэффекта: база карты x ночь x ступень фазы x радиационный фон,
## общий кап (ночь + фон делят один, см. RadiationData.POSTFX_TOTAL_CAP)
func _update_postfx_strength(night_mult: float = 1.0):
                var base: float = 1.25 if str(run_params.get("map", "procedural")) == "pripyat" else 1.0
                var phase_mult: float = pow(SurvivalData.PHASE_POSTFX_STEP, SurvivalData.phase_index(spawn_manager.current_wave))
                var rad_mult: float = 1.0
                if radiation_zone != "":
                                rad_mult = RadiationData.get_effects(radiation_zone)["postfx_mult"]
                var strength: float = clampf(base * night_mult * phase_mult * rad_mult, 0.5,
                                RadiationData.POSTFX_TOTAL_CAP)
                for child in get_children():
                                if child is GrimPostfxLayer:
                                                child.set_strength(strength)


## Бесплатный выброс на волнах 33/43/53: таймер 75 с + два гудка
func _start_blowout_countdown():
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_pulse_warning"):
                                sm.play_pulse_warning()
                await get_tree().create_timer(SurvivalData.BLOWOUT_DELAY - SurvivalData.BLOWOUT_FINAL_WARNING).timeout
                if is_run_finished or not is_inside_tree():
                                return
                if sm and sm.has_method("play_pulse_warning"):
                                sm.play_pulse_warning()
                await get_tree().create_timer(SurvivalData.BLOWOUT_FINAL_WARNING).timeout
                if is_run_finished or not is_inside_tree() or not event_manager:
                                return
                event_manager.start_radiation_pulse()


## Нота в HUD (события/модификаторы/фазы)
func _note_hud(note: Dictionary):
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("show_event_note"):
                                hud.show_event_note(note)


## Анонс особенностей следующей волны в передышке
func _preview_survival_wave(next_wave: int):
                var note := SurvivalData.wave_preview(next_wave)
                if not note.is_empty():
                                _note_hud(note)


# ==================== ОБРАБОТЧИКИ HUD ====================

func _on_hud_anomaly_requested(anomaly_type: String):
                # Закрытая аномалия: гвард в create_anomaly, здесь подсказка игроку
                var artifact_key: String = GachaData.get_artifact_for_anomaly(anomaly_type)
                var gm_hint = get_tree().get_first_node_in_group("game_manager")
                if gm_hint and not artifact_key.is_empty() and not gm_hint.is_artifact_unlocked(artifact_key):
                                var hud_locked = get_tree().get_first_node_in_group("hud")
                                if hud_locked and hud_locked.has_method("show_reward_note"):
                                                hud_locked.show_reward_note(Loc.t("hud.anomaly_locked", {"artifact": Loc.type_name(artifact_key)}))
                pass # print("Запрос аномалии: " + anomaly_type)
                var pos = _get_spawn_position_from_camera()
                var anomaly = create_anomaly(anomaly_type, pos, 1)
                if anomaly:
                                pass # print("Аномалия создана: " + anomaly_type)
                else:
                                pass # print("Не удалось создать аномалию: " + anomaly_type)


func _on_hud_mutant_requested(mutant_type: String):
                pass # print("Запрос мутанта: " + mutant_type)
                var pos = _get_spawn_position_from_camera() + Vector3.UP * 1.0
                var mutant = spawn_mutant(mutant_type, pos)
                if mutant:
                                pass # print("Мутант создан: " + mutant_type)
                else:
                                pass # print("Не удалось создать мутанта: " + mutant_type)


## Синергия впервые стала активной — баннер через штатное событие Зоны (v0.30.0)
func _on_synergy_activated(s: Dictionary) -> void:
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("show_event_note"):
                                hud.show_event_note({
                                                "title_ru": "СИНЕРГИЯ: %s" % str(s.get("name_ru", "")),
                                                "title_en": "SYNERGY: %s" % str(s.get("name_en", "")),
                                                "desc_ru": str(s.get("desc_ru", "")),
                                                "desc_en": str(s.get("desc_en", "")),
                                })


# ==================== РЕЖИМ «ТАП = СТАВИТЬ» (МОБИЛКА, D8) ====================

## HUD включает/выключает режим кисти: item_id = "anomaly:X" / "mutant:X" / ""
## Тач-флоу (D8): тап по земле показывает ПРИЗРАК (кольцо + цена, зелёный/красный),
## палец едет - призрак едет (Signals.ground_hovered), установка - тап по призраку
## или кнопка ПОСТАВИТЬ на HUD. Ничего не списывается до подтверждения.
## Кисть после установки сохраняется (цепочки постановок). Десктоп ставит сразу.
var _ghost: Node3D = null
var _ghost_ring: MeshInstance3D = null
var _ghost_label: Label3D = null
var _ghost_item: String = ""

const GHOST_OK_COLOR := Color(0.35, 1.0, 0.45, 0.85)
const GHOST_FAIL_COLOR := Color(1.0, 0.3, 0.25, 0.9)


func set_pending_placement(item_id: String):
                _pending_placement = item_id
                if item_id.is_empty():
                                _hide_ghost()


func _ensure_ghost() -> void:
                if _ghost:
                                return
                _ghost = Node3D.new()
                _ghost.name = "PlacementGhost"
                _ghost_ring = MeshInstance3D.new()
                var cyl := CylinderMesh.new()
                cyl.top_radius = HudMobile.GHOST_RING_ANOMALY
                cyl.bottom_radius = HudMobile.GHOST_RING_ANOMALY
                cyl.height = 0.08
                cyl.radial_segments = 32
                _ghost_ring.mesh = cyl
                var mat := StandardMaterial3D.new()
                mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
                mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                mat.albedo_color = GHOST_OK_COLOR
                _ghost_ring.material_override = mat
                _ghost.add_child(_ghost_ring)
                _ghost_label = Label3D.new()
                _ghost_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
                _ghost_label.no_depth_test = true
                _ghost_label.pixel_size = 0.02
                _ghost_label.font_size = 44
                _ghost_label.outline_size = 12
                _ghost_label.position = Vector3(0.0, 2.2, 0.0)
                _ghost.add_child(_ghost_label)
                _ghost.visible = false
                add_child(_ghost)


## Цена постановки кисти: аномалия - энергия (с надбавкой радиации Припяти),
## мутант - биомасса. Те же формулы, что в create_anomaly/spawn_mutant.
func _placement_cost(item_id: String) -> int:
                if item_id.begins_with("anomaly:"):
                                var anomaly_type: String = item_id.substr(len("anomaly:"))
                                var cost: float = float(anomaly_manager.get_anomaly_cost(anomaly_type)) if anomaly_manager else 0.0
                                if radiation_zone != "" and radiation_zone != "clean":
                                                cost *= RadiationData.get_effects(radiation_zone)["anomaly_cost_mult"]
                                return int(cost)
                if item_id.begins_with("mutant:"):
                                var mutant_type: String = item_id.substr(len("mutant:"))
                                return int(spawn_manager.get_mutant_cost(mutant_type)) if spawn_manager else 0
                return 0


func _ghost_affordable(cost: int) -> bool:
                if _ghost_item.begins_with("anomaly:"):
                                return can_afford(float(cost), 0.0)
                return can_afford(0.0, float(cost))


func _show_ghost_at(item_id: String, world_position: Vector3) -> void:
                _ensure_ghost()
                _ghost_item = item_id
                var pos: Vector3 = world_position
                pos.x = clampf(pos.x, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
                pos.z = clampf(pos.z, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
                _ghost.global_position = pos + Vector3.UP * 0.05
                var is_anomaly: bool = item_id.begins_with("anomaly:")
                var type: String = item_id.substr(len("anomaly:") if is_anomaly else len("mutant:"))
                var icon: String = "⚡" if is_anomaly else "🧬"
                var cost: int = _placement_cost(item_id)
                var ok: bool = _ghost_affordable(cost)
                _ghost_ring.scale = Vector3.ONE * (1.0 if is_anomaly else HudMobile.GHOST_RING_MUTANT / HudMobile.GHOST_RING_ANOMALY)
                var mat: StandardMaterial3D = _ghost_ring.material_override
                mat.albedo_color = GHOST_OK_COLOR if ok else GHOST_FAIL_COLOR
                _ghost_label.text = "%s · %s%d" % [GachaData.display_name(type), icon, cost]
                _ghost_label.modulate = Color(0.85, 1.0, 0.85) if ok else Color(1.0, 0.6, 0.55)
                _ghost.visible = true
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("show_placement_confirm"):
                                hud.show_placement_confirm(item_id, cost, ok)


func _hide_ghost() -> void:
                _ghost_item = ""
                if _ghost:
                                _ghost.visible = false
                var hud = get_tree().get_first_node_in_group("hud")
                if hud and hud.has_method("hide_placement_confirm"):
                                hud.hide_placement_confirm()


## Тап по земле из мобильной камеры
func _on_ground_tapped(world_position: Vector3):
                if _pending_placement.is_empty():
                                return
                if DisplayServer.is_touchscreen_available():
                                # Тап по своему призраку = подтверждение (быстрый флоу, D8)
                                if _ghost and _ghost.visible and HudMobile.GHOST_CONFIRM_BY_TAP:
                                                if world_position.distance_to(_ghost.global_position) <= HudMobile.GHOST_RING_ANOMALY * 1.6:
                                                                confirm_placement()
                                                                return
                                _show_ghost_at(_pending_placement, world_position)
                                return
                # Десктоп (страховка): мгновенная установка, как раньше
                _place_now(_pending_placement, world_position)


## Палец едет по земле при активной кисти: призрак следует за пальцем
func _on_ground_hovered(world_position: Vector3):
                if _pending_placement.is_empty():
                                return
                _show_ghost_at(_pending_placement, world_position)


## Мгновенная установка (прежний флоу без призрака)
func _place_now(item_id: String, world_position: Vector3):
                if item_id.begins_with("anomaly:"):
                                var anomaly_type: String = item_id.substr(len("anomaly:"))
                                create_anomaly(anomaly_type, world_position, 1)
                elif item_id.begins_with("mutant:"):
                                var mutant_type: String = item_id.substr(len("mutant:"))
                                spawn_mutant(mutant_type, world_position + Vector3.UP * 1.0)


## Установка в точку призрака (кнопка ПОСТАВИТЬ / тап по призраку).
## False - не хватило ресурса: тряска панели HUD, призрак остаётся красным.
func confirm_placement() -> bool:
                if _pending_placement.is_empty() or not _ghost or not _ghost.visible:
                                return false
                var item_id: String = _pending_placement
                var pos: Vector3 = _ghost.global_position
                var placed: Node = null
                if item_id.begins_with("anomaly:"):
                                var anomaly_type: String = item_id.substr(len("anomaly:"))
                                placed = create_anomaly(anomaly_type, pos, 1)
                elif item_id.begins_with("mutant:"):
                                var mutant_type: String = item_id.substr(len("mutant:"))
                                placed = spawn_mutant(mutant_type, pos + Vector3.UP * 1.0)
                if placed:
                                _hide_ghost()
                                var hud_ok = get_tree().get_first_node_in_group("hud")
                                if hud_ok and hud_ok.has_method("notify_placement_done"):
                                                hud_ok.notify_placement_done()
                                return true
                _ghost_flash_fail()
                var hud_fail = get_tree().get_first_node_in_group("hud")
                if hud_fail and hud_fail.has_method("placement_failed"):
                                hud_fail.placement_failed()
                return false


## Отмена кисти (кнопка ОТМЕНА на HUD): призрак и панель подтверждения убираются
func cancel_placement() -> void:
                _pending_placement = ""
                _hide_ghost()


func _ghost_flash_fail() -> void:
                if not _ghost_ring:
                                return
                var mat: StandardMaterial3D = _ghost_ring.material_override
                mat.albedo_color = GHOST_FAIL_COLOR
                var tw := create_tween()
                tw.tween_property(_ghost, "scale", Vector3(1.12, 1.12, 1.12), 0.07)
                tw.tween_property(_ghost, "scale", Vector3.ONE, 0.09)


func _get_spawn_position_from_camera() -> Vector3:
                var camera = get_viewport().get_camera_3d()
                if not camera:
                                return Vector3.ZERO

                # Берём точку перед камерой и проецируем её лучом вниз на рельеф:
                # на какой бы высоте ни висела камера, аномалия ставится на землю
                var point = camera.global_position + camera.global_transform.basis.z * -10.0

                var space = get_viewport().get_world_3d().direct_space_state
                var query = PhysicsRayQueryParameters3D.new()
                query.from = Vector3(point.x, point.y + 50.0, point.z)
                query.to = Vector3(point.x, point.y - 200.0, point.z)
                query.collision_mask = 1
                var result = space.intersect_ray(query)
                if result:
                                point = result.position
                else:
                                point.y = 0.0

                # Не размещаем за периметром Зоны
                point.x = clampf(point.x, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
                point.z = clampf(point.z, -Helpers.WORLD_LIMIT, Helpers.WORLD_LIMIT)
                return point


# ==================== ОБРАБОТЧИКИ МЕНЕДЖЕРОВ ====================

func _on_energy_changed(current: float, max_val: float):
                energy_changed.emit(current, max_val)
                Signals.energy_changed.emit(current, max_val, current / max_val if max_val > 0 else 0.0)


func _on_biomass_changed(current: float, max_val: float):
                biomass_changed.emit(current, max_val)
                Signals.biomass_changed.emit(current, max_val, current / max_val if max_val > 0 else 0.0)


func can_start_pulse() -> bool:
                return event_manager.can_start_pulse() if event_manager else false


func start_radiation_pulse() -> bool:
                return event_manager.start_radiation_pulse() if event_manager else false


func _on_critical_biomass(_percent: float):
                # Аргумент обязателен: сигнал critical_biomass_reached передаёт процент,
                # и вызов без параметра отклонялся Godot - выброс никогда не запускался
                # Канон: выброс запускается ТОЛЬКО кнопкой за 1000 энергии
                pass # print("Критический уровень биомассы! (Выброс - только за 1000 энергии)")


func _on_radiation_pulse_started(level: int):
                # В кампании эскалация живёт на уровнях кампании, выброс сложность не крутит
                if not run_params.has("campaign_params"):
                                progression_manager.increase_difficulty()
                                event_manager.set_difficulty(progression_manager.get_current_difficulty())

                radiation_pulse_started.emit(level)
                Signals.radiation_pulse_started.emit(level, pulse_duration)

                # Визуальные/звуковые эффекты
                if particle_manager:
                                particle_manager.spawn_pulse_effect()
                if sound_manager:
                                sound_manager.play_pulse_warning()
                _play_emission_fx()

                pass # print("ВЫБРОС начался! Уровень: " + str(level))


func _on_radiation_pulse_ended():
                # БАГ "биомасса ебанулась после выброса": здесь было
                # current_biomass = max_biomass * 0.3. При max_biomass=999999 это
                # ~300К: счётчик после КАЖДОГО выброса скакал до ~300К, а при победе
                # (выбросы - условие победы) "неизрасходованный остаток"
                # (current - accumulated) в _collect_run_result вливал те же ~300К
                # в награду - баланс раздувался дважды. Накачка убрана: биомасса за
                # сжигённых выбросом сталкеров честно приходит через biomass_return
                # во время импульса. Защёлка критического уровня снимается сама,
                # когда баланс ниже порога (40% max) - отдельный сброс не нужен.
                radiation_pulse_ended.emit()
                Signals.radiation_pulse_ended.emit()
                _stop_emission_fx()
                pass # print("Выброс закончился")


func _on_wave_started(wave_number: int, count: int):
                wave_started.emit(wave_number, count)
                Signals.wave_started.emit(wave_number, count, progression_manager.get_current_difficulty())
                # Задача 21: зловещий рог на старте волны
                var sm_wave = get_tree().get_first_node_in_group("sound_manager")
                if sm_wave and sm_wave.has_method("play_sound"):
                                sm_wave.play_sound("wave_horn", 0.7)
                # Задача 22: обычный этаж после босс-лупа - вернуть боевую музыку
                if _boss_music_active:
                                var intro_type := ""
                                if run_params.get("run_mode", "") == "tower":
                                                intro_type = TowerData.get_floor_type(int(run_params.get("tower_floor", 1)))
                                if intro_type != "keeper" and int(run_params.get("tower_floor", 1)) < 91:
                                                _boss_music_active = false
                                                if sm_wave and sm_wave.has_method("play_music"):
                                                                sm_wave.play_music("run", 1.0)

                pass # print("Волна " + str(wave_number) + " началась, сталкеров: " + str(count))

                # Интро-баннер особого этажа Башни (Приложение Б спеки церемонии):
                # Прорыв/Хранитель на старте 1-й волны, слэм + рык, скип мгновенный
                if wave_number == 1 and run_params.get("run_mode", "") == "tower":
                                var intro_type := TowerData.get_floor_type(int(run_params.get("tower_floor", 1)))
                                if intro_type == "break" or intro_type == "keeper":
                                                _show_floor_intro_banner(intro_type)

                # D9: волна пошла - врата на миникарте гаснут
                if spawn_manager and spawn_manager.gate_mode:
                                var hud_wave = get_tree().get_first_node_in_group("hud")
                                if hud_wave and hud_wave.has_method("clear_wave_gates"):
                                                hud_wave.clear_wave_gates()

                # Анонс события выживания (волна уже усилена в _on_wave_ended прошлой волны)
                if run_params.get("run_mode", "") == "survival" and _pending_event:
                                var hud = get_tree().get_first_node_in_group("hud")
                                if hud and hud.has_method("show_event_note"):
                                                hud.show_event_note(_pending_event)
                # Фаза легенды: активация модификатора волны / выбросной таймер / вход в фазу
                if run_params.get("run_mode", "") == "survival":
                                _wave_modifier = _next_wave_modifier
                                _apply_wave_modifier(_wave_modifier)
                                if SurvivalData.is_blowout_wave(wave_number):
                                                _start_blowout_countdown()
                                var phase_note := SurvivalData.get_phase_note(wave_number)
                                if not phase_note.is_empty() and not _phase_announced.has(wave_number):
                                                _phase_announced[wave_number] = true
                                                _note_hud(phase_note)
                                                _update_postfx_strength()


## Интро-баннер этажа Башни (Приложение Б церемонии): слэм без затемнения,
## рык на Хранителе; скип любым кликом/Enter. Арт из CeremonyData, нет файла -
## текстовая заглушка в цвет акцента.
func _show_floor_intro_banner(floor_type: String):
                var layer := CanvasLayer.new()
                layer.layer = 9  # церемония - 10, HUD выше
                add_child(layer)

                var vp := get_viewport().get_visible_rect().size
                var root := Control.new()
                root.set_anchors_preset(Control.PRESET_FULL_RECT)
                root.mouse_filter = Control.MOUSE_FILTER_STOP
                layer.add_child(root)

                var banner := Control.new()
                banner.position = Vector2(vp.x * 0.04, vp.y * 0.06)
                banner.size = Vector2(vp.x * 0.92, vp.y * 0.19)
                banner.pivot_offset = banner.size * 0.5
                root.add_child(banner)

                var art_key := "banner_keeper" if floor_type == "keeper" else "banner_break"
                var accent := Color(0.62, 0.16, 0.12) if floor_type == "keeper" else Color(0.8, 0.5, 0.15)
                var art: Texture2D = null
                var art_path := CeremonyData.ART_DIR + String(CeremonyData.ART.get(art_key, ""))
                if art_path != CeremonyData.ART_DIR and ResourceLoader.exists(art_path):
                                art = load(art_path) as Texture2D
                if art:
                                var tex_rect := TextureRect.new()
                                tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
                                tex_rect.texture = art
                                tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
                                tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
                                banner.add_child(tex_rect)
                else:
                                var panel := Panel.new()
                                panel.set_anchors_preset(Control.PRESET_FULL_RECT)
                                var sb := StyleBoxFlat.new()
                                sb.bg_color = Color(0.05, 0.07, 0.06, 0.88)
                                sb.border_color = accent
                                sb.set_border_width_all(4)
                                sb.set_corner_radius_all(10)
                                panel.add_theme_stylebox_override("panel", sb)
                                banner.add_child(panel)

                var title := Label.new()
                title.set_anchors_preset(Control.PRESET_FULL_RECT)
                title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
                title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
                title.add_theme_font_size_override("font_size", clampi(vp.y * 0.05, 36, 60))
                title.add_theme_color_override("font_color", Color(0.93, 0.9, 0.78))
                if floor_type == "keeper":
                                var tier: Dictionary = TowerData.get_tier(int(run_params.get("tower_floor", 1)))
                                title.text = Loc.t("tower_ceremony.keeper_intro",
                                                {"name": String(tier.get("boss", ""))})
                else:
                                title.text = Loc.t("tower_ceremony.break_tag")
                banner.add_child(title)

                # Звук: пробуждение Хранителя (зад.24), слэм Прорыва, врата яруса (старт x10+1)
                var floor_num := int(run_params.get("tower_floor", 1))
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_sound"):
                                if floor_type == "keeper":
                                                sm.play_sound("keeper_awake", 0.8)
                                                sm.play_sound("chimera", 0.5, 0.7)
                                elif floor_num > 1 and floor_num % 10 == 1:
                                                sm.play_sound("gates_open", 0.8)
                                else:
                                                sm.play_sound("exchange", 0.9, 1.1)
                # Задача 22: музыка босс-боёв (лупы на Хранителе и финальном ярусе)
                if sm and sm.has_method("play_music"):
                                if floor_type == "keeper":
                                                sm.play_music("keeper_loop", 1.0)
                                                _boss_music_active = true
                                elif floor_num >= 91:
                                                sm.play_music("monolith_finale", 1.0)
                                                _boss_music_active = true

                # Слэм сверху + панч масштаба; держим 1.6 с, уходим, слой сгорает
                banner.scale = Vector2(1.15, 1.15)
                banner.position.y = -banner.size.y - 60.0
                var base_y := vp.y * 0.06
                var tw := create_tween()
                tw.tween_property(banner, "position:y", base_y, 0.35) \
                                .set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
                tw.parallel().tween_property(banner, "scale", Vector2.ONE, 0.35) \
                                .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
                tw.tween_interval(1.6)
                tw.tween_property(banner, "modulate:a", 0.0, 0.25)
                tw.tween_callback(layer.queue_free)


func _on_wave_ended(wave_number: int, survivors: int):
                wave_ended.emit(wave_number, survivors)
                Signals.wave_ended.emit(wave_number, survivors, spawn_manager.get_stalker_count())

                # Одноразовые бонусы событий Зоны действуют до конца волны
                _event_harvest_mult = 1.0
                if _event_regen_saved >= 0.0 and resource_manager:
                                resource_manager.energy_regen_rate = _event_regen_saved
                                _event_regen_saved = -1.0

                pass # print("Волна " + str(wave_number) + " закончилась, выжило: " + str(survivors))

                # Фаза легенды: снять модификатор завершившейся волны
                if run_params.get("run_mode", "") == "survival":
                                _clear_wave_modifier()

                                # Следующая волна: параметры + стат её модификатора + анонс в передышке
                                var next_wave := wave_number + 1
                                var next_params := SurvivalData.get_wave_params(
                                                next_wave, run_params.get("campaign_mode", CampaignData.MODE_NORMAL),
                                                spawn_manager.gate_mode)
                                _next_wave_modifier = SurvivalData.get_wave_modifier(next_wave)
                                if _next_wave_modifier.has("stat_mult"):
                                                var stat_m: float = float(_next_wave_modifier["stat_mult"])
                                                next_params["hp_mult"] = float(next_params["hp_mult"]) * stat_m
                                                next_params["damage_mult"] = float(next_params["damage_mult"]) * stat_m
                                _apply_survival_wave(next_params)
                                _preview_survival_wave(next_wave)

                                _grant_wave_milestone(wave_number)
                                _grant_survival_rolls(wave_number)
                                _grant_survival_event_reward(wave_number)
                                _prepare_survival_event(wave_number + 1)


## Крутки за пройденный уровень кампании: 5-й +3, 10-й +5
func _grant_campaign_rolls():
                if not run_params.has("campaign_params"):
                                return
                var completed: int = int(run_params.get("campaign_level", 0))
                var gm_rolls = get_tree().get_first_node_in_group("game_manager")
                if not gm_rolls:
                                return
                var rolls: int = GachaData.campaign_roll_reward(completed)
                if rolls > 0:
                                gm_rolls.grant_mutant_rolls(rolls, "кампания: уровень " + str(completed))
                                _gacha_rewards_log.append(Loc.t("reward.gacha_rolls", {"n": rolls}))
                var anomaly_rolls: int = GachaData.campaign_anomaly_roll_reward(completed)
                if anomaly_rolls > 0:
                                gm_rolls.grant_anomaly_rolls(anomaly_rolls, "кампания: уровень " + str(completed))
                                _gacha_rewards_log.append(Loc.t("reward.anomaly_rolls", {"n": anomaly_rolls}))


## Крутки за каждые 10 волн выживания (видимо в HUD сразу)
func _grant_survival_rolls(wave_number: int):
                var gm_rolls = get_tree().get_first_node_in_group("game_manager")
                if not gm_rolls:
                                return
                var hud_rolls = get_tree().get_first_node_in_group("hud")
                var rolls: int = GachaData.survival_roll_reward(wave_number)
                if rolls > 0:
                                gm_rolls.grant_mutant_rolls(rolls, "выживание: волна " + str(wave_number))
                                _gacha_rewards_log.append(Loc.t("reward.gacha_rolls", {"n": rolls}))
                                if hud_rolls and hud_rolls.has_method("show_reward_note"):
                                                hud_rolls.show_reward_note(Loc.t("hud.rolls_note", {"n": rolls}))
                var anomaly_rolls: int = GachaData.survival_anomaly_roll_reward(wave_number)
                if anomaly_rolls > 0:
                                gm_rolls.grant_anomaly_rolls(anomaly_rolls, "выживание: волна " + str(wave_number))
                                _gacha_rewards_log.append(Loc.t("reward.anomaly_rolls", {"n": anomaly_rolls}))
                                if hud_rolls and hud_rolls.has_method("show_reward_note"):
                                                hud_rolls.show_reward_note(Loc.t("hud.anomaly_rolls_note", {"n": anomaly_rolls}))


# ==================== СОБЫТИЯ ВЫЖИВАНИЯ ====================

var _pending_event: Dictionary = {}


## Волна-событие отбита: усиленная награда (биомасса x множитель + жирная гача)
func _grant_survival_event_reward(wave_number: int):
                if is_run_finished or not ZoneEvents.is_event_wave(wave_number):
                                return
                var event: Dictionary = ZoneEvents.get_event(wave_number)
                var reward: float = 150.0 * float(event.get("reward_mult", 1.0))
                if resource_manager:
                                resource_manager.add_biomass(reward)
                pass # print("=== СОБЫТИЕ ОТБИТО: ", event.get("title_ru", ""), " - награда ", reward, " биомассы ===")
                # Гача события с бонусом уровня: выше волна - жирнее дроп
                var gacha_level: int = 1
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm:
                                gacha_level = gm.get_campaign_level()
                _grant_gacha_rewards(clampi(gacha_level + int(event.get("gacha_bonus", 0)), 1, 100))


## Следующая волна - событие: усиливаем состав и статы поверх эскалации выживания
func _prepare_survival_event(next_wave: int):
                if not ZoneEvents.is_event_wave(next_wave):
                                return
                var event: Dictionary = ZoneEvents.get_event(next_wave)
                spawn_manager.set_rank_weights(event.get("mix", [50, 50, 0]))
                spawn_manager.min_stalkers_per_wave = int(float(spawn_manager.min_stalkers_per_wave) * float(event.get("count_mult", 1.0)))
                spawn_manager.max_stalkers_per_wave = int(float(spawn_manager.max_stalkers_per_wave) * float(event.get("count_mult", 1.0)))
                spawn_manager.set_campaign_scaling(
                                spawn_manager.campaign_hp_mult * float(event.get("hp_mult", 1.0)),
                                spawn_manager.campaign_damage_mult * float(event.get("dmg_mult", 1.0)),
                                spawn_manager.campaign_speed_mult)
                _pending_event = event
                pass # print("=== СОБЫТИЕ (волна ", next_wave, "): ", event.get("title_ru", ""), " - враг сильнее, награда щедрее ===")


func _grant_wave_milestone(waves: int):
                """Вехи выживания (10/20/30/40/50, цикл 60+): SurvivalData.get_milestone.
                Замена крана GachaData.milestone_wave_reward (там >=30 капало ежеволнно)."""
                var reward: Dictionary = SurvivalData.get_milestone(waves)
                if reward.is_empty() or is_run_finished:
                                return
                pass # print("=== ВЕХА ВЫЖИВАНИЯ: ", reward.get("label", ""), " ===")
                if reward.has("mutant"):
                                spawn_manager.queue_reward_mutant(reward["mutant"])
                                # Мутант мог открыться впервые - обновляем замки в HUD
                                var hud = get_tree().get_first_node_in_group("hud")
                                if hud and hud.has_method("refresh_mutant_unlocks"):
                                                hud.refresh_mutant_unlocks()
                if reward.has("artifact"):
                                _grant_artifact_reward(reward["artifact"], reward.get("label", ""))
                var gm_milestone = get_tree().get_first_node_in_group("game_manager")
                if reward.has("rolls") and gm_milestone and gm_milestone.has_method("grant_mutant_rolls"):
                                gm_milestone.grant_mutant_rolls(int(reward["rolls"]), "выживание: веха " + str(waves))
                if reward.has("anomaly_rolls") and gm_milestone and gm_milestone.has_method("grant_anomaly_rolls"):
                                gm_milestone.grant_anomaly_rolls(int(reward["anomaly_rolls"]), "выживание: веха " + str(waves))
                if reward.has("biomass") and resource_manager:
                                resource_manager.add_biomass(float(reward["biomass"]))
                var reward_hud = get_tree().get_first_node_in_group("hud")
                if reward_hud and reward_hud.has_method("show_reward_note"):
                                reward_hud.show_reward_note("ВЕХА: %s" % reward.get("label", str(waves)))


func _grant_artifact_reward(artifact_type: String, _source_label: String):
                """Артефакт-награда: спавнится у монолита как реликвия + ресурсный бонус.
                Звёзды типа умножают бонус и ценность реликвии"""
                var rarity := "common"
                for r in ["legendary", "rare"]:
                                if GachaData.ARTIFACT_POOL[r].has(artifact_type):
                                                rarity = r
                                                break
                # Звёзды артефакта читаем живьём из коллекции (дубли в гаче качают звёзды mid-run)
                var stars := 1
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.get_lab_data():
                                stars = gm.get_lab_data().get_artifact_stars(artifact_type)
                var star_mult := LabData.get_star_stat_mult(stars)
                var bonus: Array = GachaData.ARTIFACT_BONUS[rarity].duplicate()
                bonus[0] = bonus[0] * star_mult
                bonus[1] = bonus[1] * star_mult
                if resource_manager:
                                resource_manager.add_energy(bonus[0])
                                resource_manager.add_biomass(bonus[1])
                var monolith = get_tree().get_first_node_in_group("monolith")
                var drop_pos: Vector3 = monolith.global_position + Vector3(6.0, 0.0, 6.0) if monolith else Vector3(6.0, 0.0, 6.0)
                pass # print("=== НАГРАДА (", source_label, "): артефакт ", artifact_type, " (", rarity, ", ", stars, "★) +", bonus[0], " энергии, +", bonus[1], " биомассы ===")
                _gacha_rewards_log.append(Loc.t("reward.gacha_artifact", {"name": Loc.type_name(artifact_type)}))
                # Новый арт открывает свою аномалию - обновляем замки HUD
                var hud_unlock = get_tree().get_first_node_in_group("hud")
                if hud_unlock and hud_unlock.has_method("refresh_mutant_unlocks"):
                                hud_unlock.refresh_mutant_unlocks()
                var reward_value: float = 10.0 if rarity == "common" else (30.0 if rarity == "rare" else 80.0)
                anomaly_manager.create_artifact(artifact_type, drop_pos, rarity, reward_value * star_mult)


func _grant_gacha_rewards(level: int):
                """Гача за пройденный уровень кампании: мутант + артефакт по уровню"""
                var gm = get_tree().get_first_node_in_group("game_manager")
                var mutant_roll: Dictionary = GachaData.roll_mutant_gacha(level)
                var artifact_roll: Dictionary = GachaData.roll_artifact_gacha(level)

                # Химера - гарантия середины кампании (уровень 50), если не выпала из гачи
                if level >= GachaData.CHIMERA_GUARANTEE_LEVEL and gm and not gm.has_chimera_unlocked():
                                mutant_roll = {"type": "chimera", "rarity": "legendary", "guaranteed": true}

                var _unlocked_msg := ""
                if gm:
                                pass # (лог отключён)
                                # Дубль качнул звёзды - спавнящиеся мутанты должны узнать об этом сразу
                                if spawn_manager and gm.get_lab_data():
                                                spawn_manager.set_mutant_stars(gm.get_lab_data().mutant_stars)
                spawn_manager.queue_reward_mutant(mutant_roll["type"])
                pass # print("=== ГАЧА МУТАНТОВ (ур. ", level, "): ", mutant_roll["type"], " [", mutant_roll["rarity"], "] ", unlocked_msg, " ===")
                _gacha_rewards_log.append(Loc.t("reward.gacha_mutant", {"name": Loc.type_name(mutant_roll["type"])}))

                _grant_artifact_reward(artifact_roll["type"], "гача ур. " + str(level))
                if gm:
                                gm.grant_artifact_reward(artifact_roll["type"])
                # Видимая награда: нота в HUD
                var hud_reward = get_tree().get_first_node_in_group("hud")
                if hud_reward and hud_reward.has_method("show_reward_note"):
                                hud_reward.show_reward_note(Loc.t("hud.reward_note", {
                                                "text": Loc.type_name(mutant_roll["type"]) + " + " + Loc.type_name(artifact_roll["type"])}))


# Трофеи: артефакты с убитых сталкеров-носителей идут в хранилище
var _trophy_artifacts: Array = []


func _on_stalker_died(stalker: Node, biomass_returned: float):
                if stalker and stalker.has_method("has_artifact") and stalker.has_artifact():
                                var rarity: String = stalker.get_artifact_rarity() if stalker.has_method("get_artifact_rarity") else "common"
                                var value: int = int(stalker.get_artifact_value()) if stalker.has_method("get_artifact_value") else 10
                                if rarity == "":
                                                rarity = "common"
                                _trophy_artifacts.append({"type": rarity, "value": value})
                                pass # print("Трофей: артефакт (", rarity, ", ", value, ") убитого сталкера - в хранилище")
                # Биомассу начисляет ТОЛЬКО BaseStalker._on_died -> on_stalker_died:
                # здесь был второй счёт (плюс третий в SpawnManager) - доход завышался втрое
                progression_manager.record_stalker_killed()

                var stalker_type = "unknown"
                if stalker.has_method("get_stalker_type"):
                                stalker_type = stalker.get_stalker_type()
                if _kills_by_rank.has(stalker_type):
                                _kills_by_rank[stalker_type] += 1
                # Задача 21: крик смерти - случайный вариант из трёх
                var sm_death = get_tree().get_first_node_in_group("sound_manager")
                if sm_death and sm_death.has_method("play_sound"):
                                sm_death.play_sound("stalker_death_0%d" % (randi() % 3 + 1), 0.65)

                Signals.stalker_died.emit(stalker, stalker_type, stalker.global_position, biomass_returned)
                # (лог отключён)


func _on_mutant_spawned(_mutant: Node, _mutant_type: String):
                progression_manager.record_mutant_spawned()
                # Рык нового мутанта (пак CC0: bloodsucker/chimera/controller/flesh/
                # poltergeist/pseudodog/snork/zombie; пёс озвучен псевдопсом)
                var sm = get_tree().get_first_node_in_group("sound_manager")
                if sm and sm.has_method("play_mutant_spawn_sound"):
                                sm.play_mutant_spawn_sound(_mutant_type)
                pass # print("Мутант заспавнен: " + mutant_type)


func _on_anomaly_created(anomaly: Node, anomaly_type: String, _difficulty: int):
                if particle_manager:
                                particle_manager.spawn_anomaly_effects(anomaly.global_position, anomaly_type)
                if sound_manager:
                                sound_manager.play_anomaly_sound(anomaly_type)

                progression_manager.record_anomaly_created()
                pass # print("Аномалия создана: " + anomaly_type)


func _on_anomaly_destroyed(anomaly_type: String, position: Vector3, difficulty: int):
                # Создаем артефакт
                var artifact_type = anomaly_artifact_map.get(anomaly_type, "common")
                var rarity = difficulty_to_rarity.get(difficulty, "common")
                var values = artifact_values.get(rarity, [10])
                var value = values[randi() % values.size()]

                create_artifact(artifact_type, position, rarity, value)

                if particle_manager:
                                particle_manager.spawn_particles_at(position, "spark", 1.0)

                pass # print("Аномалия уничтожена, создан артефакт: " + artifact_type)


func _on_artifact_created(_artifact: Node, _artifact_type: String, position: Vector3):
                if particle_manager:
                                particle_manager.spawn_particles_at(position, "spark", 0.5)

                pass # print("Артефакт создан: " + artifact_type)


func _on_artifact_stolen(artifact: Node, stalker: Node):
                var loss = 10.0
                if artifact.has_method("get_value"):
                                loss = artifact.get_value()

                resource_manager.spend_biomass(loss)
                progression_manager.record_artifact_stolen()

                Signals.artifact_stolen.emit(artifact, stalker, loss)
                pass # print("Артефакт украден! Потеряно биомассы: " + str(loss))


func _on_game_over():
                game_over.emit()
                Signals.game_over.emit(false, progression_manager.get_current_run(), 0)

                pass # print("GAME OVER")
                finish_run(false)


func _on_game_won(run_number: int, reward: float):
                # В кампании награда считается в _collect_run_result (боевой доход + бонус уровня);
                # дефолтная формула event_manager (100 x забег x сложность) в кампанию не течёт
                if not run_params.has("campaign_params"):
                                resource_manager.add_biomass(reward)
                game_won.emit(run_number, reward)
                Signals.game_won.emit(run_number, reward)

                pass # print("ПОБЕДА! Забег #" + str(run_number) + " награда: " + str(reward))
                # Гача по уровню КАМПАНИИ, а не по номеру забега
                var gacha_level := run_number
                if run_params.has("campaign_params"):
                                gacha_level = int(run_params.get("campaign_level", run_number))
                _grant_gacha_rewards(clampi(gacha_level, 1, 100))
                _grant_campaign_rolls()
                finish_run(true)


# ==================== ПУБЛИЧНОЕ API ====================

# Ресурсы
func get_energy() -> float: 
                return resource_manager.get_energy() if resource_manager else 0.0

func get_biomass() -> float: 
                return resource_manager.get_biomass() if resource_manager else 0.0

func add_energy(amount: float): 
                if resource_manager: resource_manager.add_energy(amount)

func add_biomass(amount: float): 
                if resource_manager: resource_manager.add_biomass(amount)

func spend_energy(amount: float) -> bool: 
                return resource_manager.spend_energy(amount) if resource_manager else false

func spend_biomass(amount: float) -> bool: 
                return resource_manager.spend_biomass(amount) if resource_manager else false

func can_afford(energy: float, biomass: float) -> bool: 
                return resource_manager.can_afford(energy, biomass) if resource_manager else false

# Аномалии
func create_anomaly(type: String, position: Vector3, difficulty: int = 1) -> Node:
                if not anomaly_manager:
                                return null

                # Гейтинг: каждый арт открывает свою аномалию, пока арта нет - в бой нельзя
                var artifact_key: String = GachaData.get_artifact_for_anomaly(type)
                var gm_guard = get_tree().get_first_node_in_group("game_manager")
                if gm_guard and not artifact_key.is_empty() and not gm_guard.is_artifact_unlocked(artifact_key):
                                pass # print("Зона: аномалия закрыта - нужен её артефакт (", artifact_key, ")")
                                return null

                var cost = anomaly_manager.get_anomaly_cost(type)
                # Радиационный фон Припяти: аномалии дороже ближе к Саркофагу (D3)
                if radiation_zone != "" and radiation_zone != "clean":
                                cost = float(cost) * RadiationData.get_effects(radiation_zone)["anomaly_cost_mult"]
                if not resource_manager.spend_energy(cost):
                                pass # print("Недостаточно энергии для " + type + " (нужно: " + str(cost) + ")")
                                return null

                var anomaly = anomaly_manager.create_anomaly(type, position, difficulty, cost)
                if anomaly and gm_guard:
                                # Эксклюзив Чёрного ящика: полученная аномалия ставит усиленную версию
                                var ex_type: String = gm_guard.owned_anomaly_exclusive_for(type)
                                if not ex_type.is_empty():
                                                anomaly.apply_exclusive_anomaly(GachaData.get_exclusive_anomaly(ex_type))
                return anomaly

# Артефакты
func create_artifact(artifact_type: String, position: Vector3, rarity: String = "common", value: float = 10.0) -> Node:
                if not anomaly_manager:
                                return null
                return anomaly_manager.create_artifact(artifact_type, position, rarity, value)

# Мутанты
func spawn_mutant(mutant_type: String, position: Vector3) -> Node:
                if not spawn_manager:
                                return null

                # Гейтинг коллекции: не разблокирован кампанией/гачей - в бой не применить.
                # Наградные мутанты идут мимо (spawn_manager напрямую) - они уже разблокированы.
                # Эксклюзив Чёрного ящика заменяет базу: владеешь Пепельником -
                # кнопка болотника ставит его (v0.21.0)
                var gm = get_tree().get_first_node_in_group("game_manager")
                var ex_type: String = ""
                if gm:
                                if gm.has_method("owned_mutant_exclusive_for"):
                                                ex_type = gm.owned_mutant_exclusive_for(mutant_type)
                                if not gm.is_mutant_unlocked(mutant_type) and ex_type.is_empty():
                                                pass # print("Зона: мутант не разблокирован - откройте его кампанией или гачей: " + mutant_type)
                                                return null

                var cost = spawn_manager.get_mutant_cost(mutant_type)
                if not resource_manager.spend_biomass(cost):
                                pass # print("Недостаточно биомассы для " + mutant_type + " (нужно: " + str(cost) + ")")
                                return null

                var spawn_type: String = ex_type if not ex_type.is_empty() else mutant_type
                # Звёзды прокачки хранятся по базовому виду - передаём базу отдельно
                return spawn_manager.spawn_mutant(spawn_type, position, cost, mutant_type)

# Регистрация
func register_stalker(_stalker: Node):
                # В spawn_manager.active_stalkers сталкера уже добавил SpawnManager при спавне:
                # повторный append давал двойной счётчик и «вечных» призраков после смерти
                pass

# Прямой метод для добавления биомассы при смерти сталкера
func on_stalker_died(stalker: Node, biomass_returned: float):
                # Смерть от радиационного фона не платит биомассу за килл (D3):
                # метку ставит тик дрейфа до смертельного урона
                if stalker and stalker.has_meta("rad_death"):
                                biomass_returned = 0.0
                if resource_manager:
                                # ЖАТВА: множитель добычи за убийство (волна легенд x события Зоны)
                                # Ночь (v0.29.0): сталкеры хуже видят - добыча +25%
                                var night_mult := 1.0
                                if day_night_manager and day_night_manager.is_night():
                                                night_mult = DayNightData.NIGHT_HARVEST_MULT
                                resource_manager.add_biomass(biomass_returned * _harvest_mult * _event_harvest_mult * night_mult)
                                # (лог отключён)

                progression_manager.record_stalker_killed()

                var stalker_type = "unknown"
                if stalker.has_method("get_stalker_type"):
                                stalker_type = stalker.get_stalker_type()

                Signals.stalker_died.emit(stalker, stalker_type, stalker.global_position, biomass_returned)

# Информация
func get_difficulty() -> float: 
                return progression_manager.get_current_difficulty() if progression_manager else 1.0

func get_run_number() -> int: 
                return progression_manager.get_current_run() if progression_manager else 1

func get_pulse_count() -> int: 
                return event_manager.get_pulse_count() if event_manager else 0

func get_pulses_remaining() -> int: 
                return event_manager.get_pulses_remaining() if event_manager else pulses_to_win

func is_radiating() -> bool: 
                return event_manager.is_pulse_active() if event_manager else false

func has_won() -> bool: 
                return event_manager.has_won() if event_manager else false

func get_status() -> Dictionary:
                return {
                                "energy": get_energy(),
                                "max_energy": max_energy,
                                "biomass": get_biomass(),
                                "max_biomass": max_biomass,
                                "difficulty": get_difficulty(),
                                "run_number": get_run_number(),
                                "pulse_count": get_pulse_count(),
                                "pulses_remaining": get_pulses_remaining(),
                                "radiating": is_radiating(),
                                "stalkers": spawn_manager.get_stalker_count() if spawn_manager else 0,
                                "mutants": spawn_manager.get_mutant_count() if spawn_manager else 0,
                                "anomalies": anomaly_manager.get_anomaly_count() if anomaly_manager else 0,
                                "artifacts": anomaly_manager.get_artifact_count() if anomaly_manager else 0
                }


# ==================== СОБЫТИЯ ЗОНЫ И ТОРГОВЕЦ (v0.28.0) ====================

var _break_index: int = 0
var _last_event_id: String = ""
var _event_reward_mult: float = 1.0
var _event_biomass_flat: float = 0.0
var _event_harvest_mult: float = 1.0
var _event_regen_saved: float = -1.0
var _trader_sold: Dictionary = {}
var _run_popup_busy: bool = false


func _on_run_popup_closed():
                _run_popup_busy = false


## Передышка: иногда прерываем событием Зоны (выбор 1 из 2)
func _maybe_trigger_run_event(wave_number: int, break_duration: float) -> void:
                if is_run_finished or run_popups == null:
                                return
                if break_duration < 6.0:
                                return
                # Перед волной-событием выживания не выступаем: у фракций свой сценарий
                if ZoneEvents.is_event_wave(wave_number + 1):
                                return
                _break_index += 1
                var due: bool = _break_index == 2 or (_break_index > 2 and (_break_index - 2) % 3 == 0)
                if not due and randf() > 0.2:
                                return
                await get_tree().create_timer(1.2).timeout
                if is_run_finished or not is_inside_tree() or _run_popup_busy:
                                return
                var ev: Dictionary = RunEventsData.pick_event(_last_event_id)
                if ev.is_empty():
                                return
                _last_event_id = str(ev.get("id", ""))
                _run_popup_busy = true
                run_popups.show_event(ev, _make_event_choice_cb(ev))


func _make_event_choice_cb(ev: Dictionary) -> Callable:
                return func(option_index: int) -> String:
                                return _apply_run_event(ev, int(option_index))


func _apply_run_event(ev: Dictionary, option_index: int) -> String:
                var options: Array = ev.get("options", [])
                if option_index < 0 or option_index >= options.size():
                                return ""
                var opt: Dictionary = options[option_index]
                var res_key := "result_ru" if Loc.lang == "ru" else "result_en"
                var res: String = str(opt.get(res_key, ""))
                _apply_run_effect(opt.get("effect", {}))
                return res


## Применение словаря эффектов (события Зоны и товары торговца)
func _apply_run_effect(effect: Dictionary) -> void:
                if effect.is_empty():
                                return
                if effect.has("biomass_now"):
                                add_biomass(float(effect["biomass_now"]))
                if effect.has("energy_now"):
                                add_energy(float(effect["energy_now"]))
                if effect.has("reward_mult"):
                                _event_reward_mult *= float(effect["reward_mult"])
                if effect.has("bonus_flat"):
                                _event_biomass_flat += float(effect["bonus_flat"])
                if effect.has("crowd_next") and spawn_manager:
                                spawn_manager.crowd_bonus += int(effect["crowd_next"])
                if effect.has("harvest_next"):
                                _event_harvest_mult = float(effect["harvest_next"])
                if effect.has("regen_next") and resource_manager:
                                _event_regen_saved = resource_manager.energy_regen_rate
                                resource_manager.energy_regen_rate = _event_regen_saved * float(effect["regen_next"])
                if effect.has("heal_all") and spawn_manager:
                                for m in spawn_manager.get_active_mutants():
                                                if is_instance_valid(m) and m.get("health_component"):
                                                                m.health_component.heal(m.health_component.get_max_health())
                if effect.has("hp_buff") and spawn_manager:
                                spawn_manager.set_campaign_scaling(
                                                spawn_manager.campaign_hp_mult * float(effect["hp_buff"]),
                                                spawn_manager.campaign_damage_mult,
                                                spawn_manager.campaign_speed_mult)
                if effect.has("dmg_buff") and spawn_manager:
                                spawn_manager.set_campaign_scaling(
                                                spawn_manager.campaign_hp_mult,
                                                spawn_manager.campaign_damage_mult * float(effect["dmg_buff"]),
                                                spawn_manager.campaign_speed_mult)
                if effect.has("cost_mult") and spawn_manager:
                                spawn_manager.set_cost_multiplier(spawn_manager.cost_multiplier * float(effect["cost_mult"]))
                if effect.has("reward_mutant") and spawn_manager:
                                spawn_manager.queue_reward_mutant(str(effect["reward_mutant"]))
                if effect.has("artifact"):
                                _grant_event_artifact(str(effect["artifact"]))
                if effect.has("rolls") or effect.has("anomaly_rolls"):
                                var gm = get_tree().get_first_node_in_group("game_manager")
                                if gm:
                                                if effect.has("rolls"):
                                                                gm.grant_mutant_rolls(int(effect["rolls"]), "событие Зоны")
                                                if effect.has("anomaly_rolls"):
                                                                gm.grant_anomaly_rolls(int(effect["anomaly_rolls"]), "событие Зоны")
                if effect.has("storm_free"):
                                _spawn_storm_anomalies(int(effect["storm_free"]))


## Случайный артефакт события/торговца: спавн у Монолита + коллекция
func _grant_event_artifact(kind: String) -> void:
                var pool: Array = GachaData.ARTIFACT_POOL.get("common", [])
                if randf() < 0.3:
                                var rare: Array = GachaData.ARTIFACT_POOL.get("rare", [])
                                if not rare.is_empty():
                                                pool = rare
                if pool.is_empty():
                                return
                var atype: String = str(pool[randi() % pool.size()])
                _grant_artifact_reward(atype, "событие Зоны")
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.has_method("grant_artifact_reward"):
                                gm.grant_artifact_reward(atype)


## Шторм: N бесплатных аномалий возле Монолита
func _spawn_storm_anomalies(count: int) -> void:
                if not anomaly_manager:
                                return
                var mono = get_tree().get_first_node_in_group("monolith")
                var base: Vector3 = mono.global_position if mono else Vector3.ZERO
                var types: Array = []
                for t in RunEventsData.STORM_TYPES:
                                if anomaly_manager.anomaly_scenes.has(t):
                                                types.append(t)
                if types.is_empty():
                                return
                for i in range(maxi(count, 1)):
                                var ang: float = randf() * TAU
                                var dist: float = randf_range(6.0, 15.0)
                                var pos: Vector3 = base + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
                                anomaly_manager.create_anomaly(str(types[randi() % types.size()]), pos, 2, 0.0)


# ==================== ТОРГОВЕЦ «СЕДОЙ» ====================

func _open_trader() -> void:
                if is_run_finished or run_popups == null or _run_popup_busy:
                                return
                _run_popup_busy = true
                run_popups.show_shop(_trader_stock(), _trader_buy, get_biomass, _trader_stock)


## Текущий товар Седого с ценами за текущую волну
func _trader_stock() -> Array:
                var wave: int = spawn_manager.current_wave if spawn_manager else 1
                var ru: bool = Loc.lang == "ru"
                var stock: Array = []
                for item in RunEventsData.TRADER_ITEMS:
                                var id: String = str(item.get("id", ""))
                                var limit: int = int(item.get("stock", 1))
                                stock.append({
                                                "id": id,
                                                "name": str(item.get("name_ru", "") if ru else item.get("name_en", "")),
                                                "desc": str(item.get("desc_ru", "") if ru else item.get("desc_en", "")),
                                                "cost": RunEventsData.trader_cost(item, wave),
                                                "sold": int(_trader_sold.get(id, 0)) >= limit,
                                })
                return stock


## Покупка: "" = отказ (не хватает/продано), иначе текст для вспышки
func _trader_buy(item_id: String) -> String:
                var item: Dictionary = {}
                for it in RunEventsData.TRADER_ITEMS:
                                if str(it.get("id", "")) == item_id:
                                                item = it
                                                break
                if item.is_empty():
                                return ""
                var id: String = str(item.get("id", ""))
                var limit: int = int(item.get("stock", 1))
                if int(_trader_sold.get(id, 0)) >= limit:
                                return ""
                var wave: int = spawn_manager.current_wave if spawn_manager else 1
                var cost: float = float(RunEventsData.trader_cost(item, wave))
                if not spend_biomass(cost):
                                return ""
                _trader_sold[id] = int(_trader_sold.get(id, 0)) + 1
                _apply_run_effect(item.get("effect", {}))
                var ru: bool = Loc.lang == "ru"
                return Loc.t("trader.bought", {"name": str(item.get("name_ru", "") if ru else item.get("name_en", "")), "cost": int(cost)})


# ==================== ЦИКЛ ДНЯ И НОЧИ (v0.29.0) ====================

## Наступление ночи: раз в цикл объявляем бонус добычи
func _on_daynight_phase_changed(phase: String):
                if phase == "night" and not is_run_finished:
                                _note_hud(DayNightData.NIGHT_NOTE)


# ==================== ЗАВЕРШЕНИЕ ЗАБЕГА ====================

func finish_run(success: bool):
                # Защита от повторного вызова (несколько сталкеров у монолита / game_over)
                if is_run_finished:
                                return
                is_run_finished = true

                pass # print("Завершение забега. Успех: " + str(success))

                # Останавливаем спавн
                if spawn_manager:
                                spawn_manager.stop_spawning()

                # Собираем результаты
                var result = _collect_run_result(success)

                # Передаем в GameManager
                var gm = get_tree().get_first_node_in_group("game_manager")
                if gm and gm.has_method("process_run_result"):
                                gm.process_run_result(result)

                # NG+ (D12): победа на 100-м кольце - церемония «ЗОНА ПОКОРЕНА»
                # (цикл уже инкрементился в process_run_result, закрытый = текущий - 1)
                if run_params.get("run_mode", "") == "campaign" and success \
                                                and int(run_params.get("campaign_level", 0)) >= CampaignData.TOTAL_LEVELS:
                                result["campaign_victory"] = true
                                result["campaign_cycle_done"] = maxi(int(gm.get_campaign_cycle()) - 1, 1) if gm else 1

                # Выброс: плавно гасим эффект (забег закрыт - не обрываем кадром)
                _fade_out_emission_fx(0.6)

                # Церемония финала для ВСЕХ режимов (баннер/итог/титр/конфетти);
                # вернёт false, если для режима церемонии нет - тогда прежняя пауза
                var ceremony := CeremonyOverlay.new()
                add_child(ceremony)
                var played: bool = await ceremony.play(result)
                ceremony.queue_free()
                if not played:
                                await get_tree().create_timer(3.0).timeout
                get_tree().change_scene_to_file("res://scenes/lab/lab.tscn")


## Мягкое гашение эффекта Выброса при закрытии забега (вместо обрыва)
func _fade_out_emission_fx(duration: float):
                if _emission_tween and _emission_tween.is_valid():
                                _emission_tween.kill()
                _emission_tween = null
                if _emission_fx == null or not is_instance_valid(_emission_fx):
                                return
                var cur: float = clampf(float(_emission_fx.get("_intensity")), 0.0, 1.0)
                if cur <= 0.01:
                                _stop_emission_fx()
                                return
                var tw := create_tween()
                tw.tween_method(
                                func(v: float): _emission_fx.set_intensity(v), cur, 0.0,
                                maxf(0.1, duration * cur))
                tw.tween_callback(_emission_fx.stop)


func _collect_run_result(success: bool) -> Dictionary:
                var run_number = progression_manager.get_current_run() if progression_manager else 1
                # Боевой доход ограничен потолком биомассы (accumulated не клампился)
                var combat_income: float = minf(resource_manager.accumulated_biomass, resource_manager.max_biomass) if resource_manager else 0.0
                var reward = combat_income
                # Разбивка награды для панели итогов (v0.31.2)
                var breakdown := {"combat": combat_income, "leftover": 0.0, "level_bonus": 0.0, "cycle_mult": 1.0}
                # Неизрасходованный стартовый капитал (остаток лаборатории + 300 базы)
                # возвращается в награду: иначе он сгорает и награда меньше накопленного в бою
                if resource_manager:
                                var leftover: float = resource_manager.current_biomass - resource_manager.accumulated_biomass
                                if leftover > 0.0:
                                                reward += leftover

                # Кампания: бонус за уровень поверх боевого дохода; реплей пройденного - 30% бонуса
                var leftover_paid: float = 0.0
                if resource_manager:
                                var leftover2: float = resource_manager.current_biomass - resource_manager.accumulated_biomass
                                if leftover2 > 0.0:
                                                leftover_paid = leftover2
                                                breakdown["leftover"] = leftover2
                if success and run_params.has("campaign_params"):
                                var campaign: Dictionary = run_params["campaign_params"]
                                var bonus: float = float(campaign.get("reward_bonus", 0.0))
                                if bool(run_params.get("campaign_replay", false)):
                                                bonus *= CampaignData.REPLAY_REWARD_FACTOR
                                reward += bonus
                                breakdown["level_bonus"] = bonus
                                # NG+ (D12): множитель цикла к боевому доходу и бонусу;
                                # стартовый капитал (возврат своих припасов) не множится.
                                # Реплей x0.3 поверх цикла - фарм по любви остаётся выгодным
                                var cyc: int = int(run_params.get("campaign_cycle", 1))
                                if cyc > 1:
                                                reward = leftover_paid + (reward - leftover_paid) * CampaignData.cycle_reward_mult(cyc)
                                                breakdown["cycle_mult"] = CampaignData.cycle_reward_mult(cyc)

                # События Зоны: плоский бонус и множитель итоговой награды
                if _event_biomass_flat > 0.0:
                                reward += _event_biomass_flat
                if _event_reward_mult != 1.0:
                                reward *= _event_reward_mult

                # Припять: премия радиационного фона к награде забега целиком
                # (после всех надбавок; процедурная карта - radiation_zone == "")
                if radiation_zone != "" and radiation_zone != "clean":
                                reward *= RadiationData.get_effects(radiation_zone)["reward_mult"]

                # ОХОТА (D19): биомасса за убитых боссов, волн нет
                if str(run_params.get("run_mode", "")) == "hunt":
                                reward = _hunt_killed.size() * BossHuntData.VICTORY_BIO_PER_BOSS

                # Выживание: награда за пройденные волны платится при любом исходе -
                # смерть здесь ожидаемый конец забега, а не провал
                var waves_survived := 0
                var final_success := success
                var victory_reason := ""
                var arena_target := 0
                if run_params.get("run_mode", "") == "survival":
                                waves_survived = maxi(0, (spawn_manager.current_wave if spawn_manager else 1) - 1)
                                reward += SurvivalData.wave_bonus(waves_survived)
                                # Логика победы (v0.21.0 «ЛИГА ВОЛН»):
                                # 1) арена-вызов: волна вызванного превзойдена - ПОБЕДА
                                var gm_node = get_tree().get_first_node_in_group("game_manager")
                                if gm_node != null:
                                                var t = gm_node.get("arena_target_wave")
                                                if t != null:
                                                                arena_target = int(t)
                                if arena_target > 0 and waves_survived > arena_target:
                                                final_success = true
                                                victory_reason = "arena_target"
                                # 2) пережил 30+ волн - ПОБЕДА независимо от волны гибели
                                elif waves_survived >= SurvivalData.VICTORY_WAVE:
                                                final_success = true
                                                victory_reason = "waves30"

                var stats = {
                                "stalkers_killed": progression_manager.get_stalkers_killed() if progression_manager else 0,
                                "anomalies_created": progression_manager.get_anomalies_created() if progression_manager else 0,
                                "mutants_created": progression_manager.get_mutants_spawned() if progression_manager else 0,
                                "artifacts_stolen": progression_manager.get_artifacts_stolen() if progression_manager else 0,
                                "biomass_earned": resource_manager.accumulated_biomass if resource_manager else 0.0,
                                "biomass_spent": 0
                }

                return {
                                "success": final_success,
                                "run_number": run_number,
                                "mode": str(run_params.get("run_mode", "campaign")),
                                # Карта нужна гача-итогам башни: премия радиации Припяти (D3)
                                "map": str(run_params.get("map", "procedural")),
                        "tower_floor": int(run_params.get("tower_floor", 0)),
                        "stalkers_total": (spawn_manager.get_stalkers_killed() if spawn_manager else 0) + (spawn_manager.get_stalker_count() if spawn_manager else 0),
                        "stalkers_killed_sm": spawn_manager.get_stalkers_killed() if spawn_manager else 0,
                        "pulses_used": event_manager.get_pulse_count() if event_manager else 0,
                                "campaign_level": int(run_params.get("campaign_level", 0)),
                                "waves_survived": waves_survived,
                                "victory_reason": victory_reason,
                                "arena_target_wave": arena_target,
                                "reward": reward,
                                "hunt_killed": _hunt_killed.duplicate(),
                                "reward_breakdown": breakdown,
                                "kills_by_rank": _kills_by_rank.duplicate(),
                                "statistics": stats,
                                "gacha_rewards": _gacha_rewards_log.duplicate(),
                                "artifacts_collected": _collect_artifacts() + _trophy_artifacts
                }


func _collect_artifacts() -> Array:
                var artifacts = []
                var nodes = get_tree().get_nodes_in_group("artifacts")

                for a in nodes:
                                if is_instance_valid(a) and a.has_method("get_rarity_name") and a.has_method("get_value"):
                                                artifacts.append({
                                                                "type": a.get_rarity_name(),
                                                                "value": a.get_value()
                                                })

                return artifacts
