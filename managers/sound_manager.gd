# managers/sound_manager.gd
extends Node
class_name SoundManager

## Менеджер звуков - управляет аудио

signal music_changed(track_name: String)
signal sound_played(sound_name: String)

@export var master_volume: float = 1.0
@export var music_volume: float = 0.7
@export var sfx_volume: float = 0.8

# Музыкальные треки (загружаются извне)
var music_tracks: Dictionary = {}
var ambient_sounds: Dictionary = {}
var anomaly_sounds: Dictionary = {}
var mutant_sounds: Dictionary = {}
var footstep_sounds: Dictionary = {}

# Плееры
var _music_player: AudioStreamPlayer
var _ambient_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []

# Состояние
var _current_music_track: String = ""
var _target_music: AudioStream = null
var _music_fade_timer: float = 0.0
var _music_fade_duration: float = 1.0
var _is_music_playing: bool = false


func _ready():
    _setup_players()
    _register_dummy_sounds()  # Сначала заглушки - как фолбэк на отсутствующие файлы
    _register_real_sounds()   # Затем реальный пак (перезаписывает, где файлы есть)
    add_to_group("sound_manager")
    pass # print("SoundManager инициализирован", "SoundManager")


# Варианты шагов по поверхностям: поверхность -> массив клипов
var footstep_variants: Dictionary = {}


func _register_real_sounds():
    ## Пак из assets/audio (CC0, подготовлен агентом-подготовщиком).
    ## Имя файла = ключ: sfx/<ключ>.ogg, music/<трек>.ogg
    var keys := {
        "footstep_sounds": ["ui_hover", "ui_click", "upgrade", "exchange", "pulse_warning"],
        "anomaly_sounds": ["electric", "thermal", "gravity", "chemical", "radiation"],
        "mutant_sounds": ["bloodsucker", "flesh", "snork", "pseudodog", "controller",
            "poltergeist", "chimera", "zombie"],
    }
    for dict_name in keys:
        var dict: Dictionary = get(dict_name)
        for key in keys[dict_name]:
            var path := "res://assets/audio/sfx/%s.ogg" % key
            if ResourceLoader.exists(path):
                dict[key] = load(path)

    # Шаги: surface -> step_<surface>_NN.ogg, до 6 вариантов на поверхность
    for surface in ["grass", "sand", "stone", "water"]:
        var variants: Array = []
        for i in range(1, 7):
            var path := "res://assets/audio/sfx/step_%s_%02d.ogg" % [surface, i]
            if ResourceLoader.exists(path):
                variants.append(load(path))
        if not variants.is_empty():
            footstep_sounds[surface] = variants[0]
            footstep_variants[surface] = variants

    # Музыка: menu / lab / run
    for track in ["menu", "lab", "run"]:
        var path := "res://assets/audio/music/music_%s.ogg" % track
        if ResourceLoader.exists(path):
            music_tracks[track] = load(path)

    # Пак подготовщика (задачи 15/17/18): эмбиент Зоны, Выброс, церемония гачи.
    # Имя файла = ключ; эмбиент-лупы играются через play_ambient,
    # остальные ключи доступны обычному play_sound.
    var extra := ["wind_open_01", "wind_forest_01", "geiger_loop", "night_insects_01",
        "howl_distant_01", "rain_medium_01", "thunder_far_01",
        "emission_burst", "emission_rumble",
        "ceremony_win", "ceremony_star", "portal_woosh", "stalker_death_01", "stalker_death_02", "stalker_death_03", "anomaly_hit", "wave_horn", "record_new", "gates_open", "keeper_awake", "card_whoosh", "card_flip", "reveal_common", "reveal_rare",
        "reveal_epic", "reveal_legendary", "ribbon_pop", "burst_sparks"]
    for key in extra:
        var extra_path := "res://assets/audio/sfx/%s.ogg" % key
        if ResourceLoader.exists(extra_path):
            ambient_sounds[key] = load(extra_path)

    # Задачи 22-24: боевые/UI-звуки и стингеры событий (дозарегистрировать
    # ключи, добавленные после первого пака)
    for key in ["stalker_death_01", "stalker_death_02", "stalker_death_03",
            "anomaly_hit", "wave_horn", "record_new", "gates_open", "keeper_awake",
            "ui_deny", "ui_build", "ui_research", "gacha_spin"]:
        var p2 := "res://assets/audio/sfx/%s.ogg" % key
        if ResourceLoader.exists(p2):
            ambient_sounds[key] = load(p2)

    # Задача 22: музыкальные лупы босс-боёв (с upkeep лупа)
    for track_key in ["keeper_loop", "monolith_finale"]:
        var mp := "res://assets/audio/sfx/%s.ogg" % track_key
        if ResourceLoader.exists(mp):
            var stream = load(mp)
            if stream is AudioStreamOggVorbis:
                stream.loop = true
            music_tracks[track_key] = stream


func _setup_players():
    # Музыка
    _music_player = AudioStreamPlayer.new()
    _music_player.name = "MusicPlayer"
    _music_player.bus = "Music"
    _music_player.volume_db = linear_to_db(music_volume)
    add_child(_music_player)
    
    # Окружение
    _ambient_player = AudioStreamPlayer.new()
    _ambient_player.name = "AmbientPlayer"
    _ambient_player.bus = "Ambient"
    _ambient_player.volume_db = linear_to_db(sfx_volume * 0.5)
    add_child(_ambient_player)
    
    # Пулы SFX игроков
    for i in range(5):
        var player = AudioStreamPlayer.new()
        player.name = "SFXPlayer_" + str(i)
        player.bus = "SFX"
        player.volume_db = linear_to_db(sfx_volume)
        add_child(player)
        _sfx_players.append(player)
    
    pass # print("Аудиоплееры созданы: 1 музыка, 1 окружение, 5 SFX", "SoundManager")


func _register_dummy_sounds():
    # Создаем заглушки для UI звуков
    var dummy_stream = AudioStreamWAV.new()
    dummy_stream.data = []  # Пустой WAV файл
    dummy_stream.format = AudioStreamWAV.FORMAT_16_BITS
    dummy_stream.mix_rate = 44100
    dummy_stream.stereo = false
    
    # Регистрируем все необходимые звуки
    footstep_sounds["ui_hover"] = dummy_stream
    footstep_sounds["ui_click"] = dummy_stream
    footstep_sounds["upgrade"] = dummy_stream
    footstep_sounds["exchange"] = dummy_stream
    footstep_sounds["pulse_warning"] = dummy_stream
    
    # Базовые звуки для аномалий
    anomaly_sounds["electric"] = dummy_stream
    anomaly_sounds["thermal"] = dummy_stream
    anomaly_sounds["gravity"] = dummy_stream
    anomaly_sounds["chemical"] = dummy_stream
    anomaly_sounds["radiation"] = dummy_stream
    
    # Звуки мутантов
    mutant_sounds["bloodsucker"] = dummy_stream
    mutant_sounds["flesh"] = dummy_stream
    mutant_sounds["snork"] = dummy_stream
    mutant_sounds["pseudodog"] = dummy_stream
    mutant_sounds["controller"] = dummy_stream
    mutant_sounds["poltergeist"] = dummy_stream
    mutant_sounds["chimera"] = dummy_stream
    mutant_sounds["zombie"] = dummy_stream
    
    # Звуки шагов
    footstep_sounds["grass"] = dummy_stream
    footstep_sounds["sand"] = dummy_stream
    footstep_sounds["stone"] = dummy_stream
    footstep_sounds["water"] = dummy_stream
    
    pass # print("Заглушки звуков созданы", "SoundManager")


# ==================== МУЗЫКА ====================

func play_music(track_name: String, fade_time: float = 1.0):
    if not music_tracks.has(track_name):
        pass # print("Неизвестный трек: " + track_name, "SoundManager")
        return
    
    var track = music_tracks[track_name]
    if not track:
        return
    
    if _current_music_track == track_name and _is_music_playing:
        return
    
    _target_music = track
    _music_fade_duration = fade_time
    _music_fade_timer = fade_time
    _current_music_track = track_name
    
    music_changed.emit(track_name)
    pass # print("Смена музыки на: " + track_name, "SoundManager")


func stop_music(fade_time: float = 1.0):
    _music_fade_duration = fade_time
    _music_fade_timer = fade_time
    _target_music = null
    _current_music_track = ""
    pass # print("Музыка останавливается", "SoundManager")


func _process(delta):
    # Плавное затухание/нарастание музыки
    if _music_fade_timer > 0:
        _music_fade_timer -= delta
        var t = 1.0 - (_music_fade_timer / _music_fade_duration)
        
        if _target_music:
            # Нарастание
            if not _is_music_playing:
                _music_player.stream = _target_music
                _music_player.play()
                _is_music_playing = true
            
            _music_player.volume_db = linear_to_db(music_volume * ease(t, 0.5))
        else:
            # Затухание
            _music_player.volume_db = linear_to_db(music_volume * (1.0 - ease(t, 0.5)))
            
            if _music_fade_timer <= 0:
                _music_player.stop()
                _is_music_playing = false


# ==================== ЗВУКИ ====================

func play_sound(sound_name: String, volume_mod: float = 1.0, pitch_mod: float = 1.0):
    var sound = _find_sound(sound_name)
    if not sound:
        # Вместо ошибки просто возвращаемся - заглушки уже есть
        return
    
    var player = _get_free_sfx_player()
    if not player:
        return
    
    player.stream = sound
    player.volume_db = linear_to_db(sfx_volume * volume_mod)
    player.pitch_scale = pitch_mod
    player.play()
    
    sound_played.emit(sound_name)
    # Убираем лишний лог для часто вызываемых звуков
    if not sound_name.begins_with("ui_"):
        pass # print("Звук воспроизведен: " + sound_name, "SoundManager")


func _find_sound(sound_name: String) -> AudioStream:
    if footstep_sounds.has(sound_name):
        return footstep_sounds[sound_name]
    if ambient_sounds.has(sound_name):
        return ambient_sounds[sound_name]
    if anomaly_sounds.has(sound_name):
        return anomaly_sounds[sound_name]
    if mutant_sounds.has(sound_name):
        return mutant_sounds[sound_name]
    
    return null


## Досрочная остановка длинного звука (гул Выброса при раннем гашении)
func stop_sound(sound_name: String, fade: float = 0.3) -> void:
    var stream := _find_sound(sound_name)
    if stream == null:
        return
    for player in _sfx_players:
        if player.playing and player.stream == stream:
            if fade > 0.0:
                var tw := create_tween()
                tw.tween_property(player, "volume_db", -40.0, fade)
                tw.tween_callback(player.stop)
            else:
                player.stop()


# ==================== ЭМБИЕНТ ====================

var _current_ambient: String = ""


## Луп окружения (задача 15): ветер/ночь/дождь. Повтор того же ключа не
## перезапускает; смена — коротким кроссфейдом. volume_mod приглушает.
func play_ambient(key: String, fade: float = 1.0, volume_mod: float = 1.0) -> void:
    var stream: AudioStream = ambient_sounds.get(key)
    if stream == null or _ambient_player == null:
        return
    if _current_ambient == key and _ambient_player.playing:
        return
    if stream is AudioStreamOggVorbis:
        stream.loop = true
    var target_db := linear_to_db(sfx_volume * master_volume * 0.5 * volume_mod)
    _current_ambient = key
    if _ambient_player.playing and fade > 0.0:
        var tw := create_tween()
        tw.tween_property(_ambient_player, "volume_db", -40.0, fade)
        tw.tween_callback(func():
            _ambient_player.stream = stream
            _ambient_player.volume_db = target_db
            _ambient_player.play())
    else:
        _ambient_player.stream = stream
        _ambient_player.volume_db = target_db
        _ambient_player.play()


func stop_ambient(fade: float = 0.8) -> void:
    _current_ambient = ""
    if _ambient_player and _ambient_player.playing:
        if fade > 0.0:
            var tw := create_tween()
            tw.tween_property(_ambient_player, "volume_db", -40.0, fade)
            tw.tween_callback(_ambient_player.stop)
        else:
            _ambient_player.stop()


func _get_free_sfx_player() -> AudioStreamPlayer:
    for player in _sfx_players:
        if not player.playing:
            return player
    return _sfx_players[0]


# ==================== СПЕЦИФИЧЕСКИЕ ЗВУКИ ====================

func play_footstep(terrain_type: String):
    # Варианты шагов: случайный клип + случайный питч, чтобы не тикало метрономом
    if footstep_variants.has(terrain_type):
        var variants: Array = footstep_variants[terrain_type]
        var sound: AudioStream = variants[randi() % variants.size()]
        var player = _get_free_sfx_player()
        if player and sound:
            player.stream = sound
            player.volume_db = linear_to_db(sfx_volume * 0.5)
            player.pitch_scale = randf_range(0.9, 1.1)
            player.play()
        return
    play_sound(terrain_type, 0.5, randf_range(0.9, 1.1))


## Случайный вариант шага для позиционного плеера сущности (3D-звук)
func get_footstep_stream(surface: String) -> AudioStream:
    if footstep_variants.has(surface):
        var variants: Array = footstep_variants[surface]
        return variants[randi() % variants.size()]
    if footstep_sounds.has(surface):
        return footstep_sounds[surface]
    return null


## Рык мутанта: ключи пака; пёс падает на сумеречника
func play_mutant_spawn_sound(mutant_type: String):
    var key := mutant_type
    if key == "dog_mutant":
        key = "pseudodog"
    play_mutant_sound(key)


func play_anomaly_sound(anomaly_type: String):
    var sound_key = ""
    match anomaly_type:
        "electric_anomaly", "electric_tesla", "electric":
            sound_key = "electric"
        "heat_anomaly", "thermal_steam", "thermal_comet", "heat":
            sound_key = "thermal"
        "gravity_vortex", "gravity_lift", "gravity_whirlwind", "gravity":
            sound_key = "gravity"
        "chemical_gas", "chemical_acid_cloud", "chemical_jelly", "chemical":
            sound_key = "chemical"
        "radiation_hotspot", "radiation":
            sound_key = "radiation"
    
    if sound_key and anomaly_sounds.has(sound_key):
        play_sound(sound_key, 0.7)


func play_mutant_sound(mutant_type: String):
    if mutant_sounds.has(mutant_type):
        play_sound(mutant_type, 0.8, randf_range(0.9, 1.1))


func play_ui_click():
    play_sound("ui_click", 0.6)


func play_pulse_warning():
    play_sound("pulse_warning", 1.0)


# ==================== НАСТРОЙКИ ====================

func set_master_volume(value: float):
    master_volume = clamp(value, 0.0, 1.0)
    _update_volumes()
    pass # print("Громкость master: " + str(value), "SoundManager")


func set_music_volume(value: float):
    music_volume = clamp(value, 0.0, 1.0)
    _music_player.volume_db = linear_to_db(music_volume)


func set_sfx_volume(value: float):
    sfx_volume = clamp(value, 0.0, 1.0)
    _update_volumes()


func _update_volumes():
    _music_player.volume_db = linear_to_db(music_volume * master_volume)
    _ambient_player.volume_db = linear_to_db(sfx_volume * master_volume * 0.5)
    for player in _sfx_players:
        player.volume_db = linear_to_db(sfx_volume * master_volume)


func get_current_music() -> String:
    return _current_music_track


func is_playing() -> bool:
    return _is_music_playing
