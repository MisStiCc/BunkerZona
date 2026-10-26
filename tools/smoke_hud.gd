# tools/smoke_hud.gd
extends SceneTree

## Смоук-тест боевого HUD v0.31.0: раскладка, стили стихий, состояния,
## сворачивание панели мутантов. Запуск:
##   godot --headless --path . -s res://tools/smoke_hud.gd

var _fails: int = 0


func _check(name: String, ok: bool, extra: String = "") -> void:
        if ok:
                print("OK   ", name)
        else:
                _fails += 1
                print("FAIL ", name, " ", extra)


class FakeAM extends RefCounted:
        func get_anomaly_cost(_t: String) -> int:
                return 100


class FakeSM extends RefCounted:
        func get_mutant_cost(_t: String) -> int:
                return 50

        func get_stalker_count() -> int:
                return 0


class FakeZone extends Node:
        signal energy_changed(current: float, max_val: float)
        signal biomass_changed(current: float, max_val: float)
        signal radiation_pulse_started(level: int)
        signal radiation_pulse_ended()
        signal wave_started(wave_number: int, count: int)
        signal wave_break_started(wave_number: int, break_duration: float)

        var anomaly_manager = null
        var spawn_manager = null

        func _init() -> void:
                anomaly_manager = FakeAM.new()
                spawn_manager = FakeSM.new()

        func can_start_pulse() -> bool:
                return false

        func spend_energy(_x: float) -> bool:
                return false

        func start_radiation_pulse() -> void:
                pass


func _initialize() -> void:
        _run()


func _run() -> void:
        # Fake-окружение ДО инстанцирования HUD
        var zone := FakeZone.new()
        zone.add_to_group("zone_controller")
        get_root().add_child(zone)

        var ps: PackedScene = load("res://ui/hud/hud.tscn")
        _check("hud.tscn загружена", ps != null)
        if ps == null:
                quit(1)
                return
        var hud = ps.instantiate()
        get_root().add_child(hud)
        await process_frame
        await process_frame
        await process_frame

        # --- Раскладка после _rescale_battle_panels ---
        var ap: Panel = hud.get_node("AnomalyPanel")
        var mp: Panel = hud.get_node("MutantPanel")
        var sp: Panel = hud.get_node("StartPanel")
        var ep: Panel = hud.get_node("EmissionPanel")
        var mm: Panel = hud.get_node("Minimap")
        print("DBG ap rect=", Rect2(ap.offset_left, ap.offset_top, ap.offset_right - ap.offset_left, ap.offset_bottom - ap.offset_top), " anchors=", ap.anchor_left, ",", ap.anchor_right, " orig=", hud._loadout_orig.get(ap, Rect2()))
        # taken=3 (тестовый сейв) → поджим под 3 колонки: right = 8+432-106 = 334
        _check("аномалии: поджим под taken (3 колонки)", absf(ap.offset_right - 334.0) < 2.0,
                "offset_right=%f" % ap.offset_right)
        _check("аномалии: вертикальный блок ниже ресурсов (top=84)", absf(ap.offset_top - 84.0) < 0.5)
        # taken=3 → w = 538-2*106 = 326, панель прижата вправо
        _check("мутанты: справа, поджим под taken", absf((mp.offset_right - mp.offset_left) - 326.0) < 2.0
                and absf(mp.offset_right + 8.0) < 2.0,
                "w=%f" % (mp.offset_right - mp.offset_left))
        _check("старт-панель: внизу по центру (anchor 0.5)", absf(sp.anchor_left - 0.5) < 0.01
                and absf(sp.anchor_top - 1.0) < 0.01)
        _check("выброс-панель: внизу по центру (anchor 0.5)", absf(ep.anchor_left - 0.5) < 0.01)
        _check("миникарта выше кнопок низа", mm.offset_bottom <= sp.offset_top)

        # --- Стили стихий ---
        var fb: Button = hud.get_node("AnomalyPanel/FireButton")
        var tb: Button = hud.get_node("AnomalyPanel/TeslaButton")
        var zb: Button = hud.get_node("MutantPanel/ZombieButton")
        _check("стили применены (meta el_text)", fb.has_meta("el_text") and tb.has_meta("el_text") and zb.has_meta("el_text"))
        var fb_sb: StyleBox = fb.get_theme_stylebox("normal")
        _check("кнопка Жарки — тёплый фон", fb_sb is StyleBoxFlat and (fb_sb as StyleBoxFlat).bg_color.r > (fb_sb as StyleBoxFlat).bg_color.b)
        _check("кнопки старт/выброс стилизованы БУНКЕР", hud.get_node("StartPanel/StartRunButton").get_theme_stylebox("normal") is StyleBoxFlat)

        # --- Цены/база ---
        _check("базовые цены аномалий сняты", hud._anomaly_base_costs.get("heat_anomaly", 0) == 100)

        # --- Состояние «дорого»: энергии 0 < 100 → красный текст ---
        var red := Color("ff8a6a")
        fb.disabled = false  # принудительно «открыта»: в смоке автолоад GameManager закрывает артефактами
        hud._update_affordability()
        var fc: Color = fb.get_theme_color("font_color")
        print("DBG font_color=", fc, " red=", red, " energy=", hud._energy_now)
        _check("нет ресурса → красная цена", fc.is_equal_approx(red))

        # --- Достаточно ресурса → цвет стихии ---
        hud._energy_now = 500.0
        hud._biomass_now = 500.0
        hud._update_affordability()
        _check("ресурс есть → цвет стихии", fb.get_theme_color("font_color") == fb.get_meta("el_text"))

        # --- Сворачивание панели мутантов: до старта запрещено ---
        hud._toggle_mutant_panel()
        _check("до старта панель не сворачивается", not hud._mutants_collapsed)

        # --- Сворачивание после старта ---
        sp.visible = false
        hud._toggle_mutant_panel()
        await process_frame
        _check("после старта свернулась", hud._mutants_collapsed)
        _check("свёрнута: высота ~28", absf(mp.offset_bottom - (mp.offset_top + 28.0)) < 2.0,
                "bottom=%f" % mp.offset_bottom)
        var dog: Button = hud.get_node("MutantPanel/DogButton")
        _check("свёрнута: кнопки скрыты", not dog.visible)
        _check("стрелка ► в заголовке", hud._mut_header_btn.text.begins_with("►"))
        hud._toggle_mutant_panel()
        await process_frame
        _check("разворот обратно: высота панели вернулась", absf((mp.offset_bottom - mp.offset_top) - 90.0) < 2.0,
                "h=%f" % (mp.offset_bottom - mp.offset_top))
        _check("стрелка ▼ в заголовке", hud._mut_header_btn.text.begins_with("▼"))

        print("SMOKE HUD: %s (%d fails)" % ["ALL OK" if _fails == 0 else "FAILED", _fails])
        quit(0 if _fails == 0 else 1)
