# tools/smoke_v0300.gd — смок-тест v0.30.0 «ЗОНА МУТИРУЕТ»
# Запуск: godot --headless -s tools/smoke_v0300.gd  (из корня проекта)
# Проверки:
#   1) Данные: 17 вариантов в EXCLUSIVE_MUTANTS, все поля на месте, базы существуют,
#      2 легендарки, family у всех, имена RU+EN полны
#   2) Ротация ящика: ступени 10/20 — стандарт, ступень 30 — ТОЛЬКО легендарки
#   3) SynergyData: семейства, активация пар, таргетинг бафов, АЛЬФА/ОБСИДИАН/ВЕНЕЦ
#   4) Редкость: варианты не «common», легендарки золотые
#   5) Спавн-маппинг: каждый вариант маппится на сцену базы, цены заданы
#   6) apply_synergy_buff_live: живой баф статов
extends SceneTree

var _fails: int = 0

func _check(name: String, cond: bool) -> void:
        if cond:
                print("  [OK]   ", name)
        else:
                _fails += 1
                print("  [FAIL] ", name)

func _initialize() -> void:
        print("=== СМОК v0.30.0 «ЗОНА МУТИРУЕТ» ===")
        _test_data()
        _test_milestone_rotation()
        _test_synergy_logic()
        _test_rarity()
        _test_spawn_mapping()
        await _test_live_buff()
        print("=== ИТОГ: ", "ALL OK" if _fails == 0 else "ПРОВАЛОВ: %d" % _fails, " ===")
        quit(0 if _fails == 0 else 1)

func _test_data() -> void:
        print("--- Данные EXCLUSIVE_MUTANTS ---")
        var ex_list: Array = GachaData.EXCLUSIVE_MUTANTS
        _check("всего вариантов 17 (3 старых + 12 ростера + 2 легендарки)", ex_list.size() == 17)
        var legendaries := 0
        var types := {}
        for ex in ex_list:
                var t := str(ex.get("type", ""))
                types[t] = true
                if str(ex.get("rarity", "")) == "legendary":
                        legendaries += 1
                if str(ex.get("type", "")).is_empty() or str(ex.get("base", "")).is_empty():
                        _check("запись без type/base: " + t, false)
                if not ex.has("family"):
                        _check("вариант без family: " + t, false)
                if not ex.has("rarity"):
                        _check("вариант без rarity: " + t, false)
        _check("легендарок ровно 2", legendaries == 2)
        _check("легендарки — crimson_chimera и obsidian_titan", types.has("crimson_chimera") and types.has("obsidian_titan"))
        for ex in ex_list:
                var base := str(ex["base"])
                var path := "res://entities/mutants/%s.tscn" % base
                _check("сцена базы есть: " + base, ResourceLoader.exists(path))
        # Локализация: RU из DISPLAY_NAMES, EN из DISPLAY_NAMES_EN
        var loc = load("res://core/localization.gd")
        var en: Dictionary = loc.DISPLAY_NAMES_EN
        var ru: Dictionary = GachaData.DISPLAY_NAMES
        for ex in ex_list:
                var t := str(ex["type"])
                _check("RU имя: " + t, ru.has(t))
                _check("EN имя: " + t, en.has(t))
        # Базар: 17 ex_mut-позиций, легендарки по 500
        var season: Array = GachaData.SEASON_SHOP
        var ex_mut_count := 0
        var chimera_price := 0
        for item in season:
                if str(item[0]) == "ex_mut":
                        ex_mut_count += 1
                        if str(item[1]) == "crimson_chimera":
                                chimera_price = int(item[3])
        _check("в базаре 17 вариантов ex_mut", ex_mut_count == 17)
        _check("Багровая химера в базаре за 500 СП", chimera_price == 500)

func _test_milestone_rotation() -> void:
        print("--- Ротация Чёрного ящика ---")
        for cycle in [1, 2, 3, 4]:
                var m1 := GachaData.exclusive_for_milestone(cycle, 1)
                var m2 := GachaData.exclusive_for_milestone(cycle, 2)
                var m3 := GachaData.exclusive_for_milestone(cycle, 3)
                _check("цикл %d, ст.10 — не легендарка" % cycle, str(m1.get("rarity", "")) != "legendary")
                _check("цикл %d, ст.20 — не легендарка" % cycle, str(m2.get("rarity", "")) != "legendary")
                _check("цикл %d, ст.30 — ЛЕГЕНДАРКА" % cycle, str(m3.get("rarity", "")) == "legendary")
        # Ротация легендарок меняется по циклам
        var c1 := GachaData.exclusive_for_milestone(1, 3)
        var c2 := GachaData.exclusive_for_milestone(2, 3)
        _check("легендарки револьвятся по циклам", str(c1["type"]) != str(c2["type"]))

func _test_synergy_logic() -> void:
        print("--- SynergyData ---")
        _check("8 синергий в таблице", SynergyData.SYNERGIES.size() == 8)
        # СТАЯ: пёс + псевдопёс на поле
        var act := SynergyData.evaluate({"dog_mutant": 1, "pseudodog": 1})
        _check("СТАЯ активна (пёс+псевдопёс)", _has_id(act, "staya"))
        _check("СТАЯ не активна с одним псом", not _has_id(SynergyData.evaluate({"dog_mutant": 3}), "staya"))
        # Вариант собаки тоже в семействе
        var act2 := SynergyData.evaluate({"dog_mutant": 1, "besheniy_pes": 1})
        _check("СТАЯ активна (пёс+Бешеный пёс)", _has_id(act2, "staya"))
        # ПСИ-СЕТЬ
        var act3 := SynergyData.evaluate({"controller_mutant": 1, "poltergeist": 1})
        _check("ПСИ-СЕТЬ активна", _has_id(act3, "psi_set"))
        # Таргетинг: пёс ловит СТАЮ, контролёр — нет
        var buffs_dog: Dictionary = SynergyData.buffs_for("dog_mutant", act)
        var buffs_ctrl: Dictionary = SynergyData.buffs_for("controller_mutant", act)
        _check("пёс получает +15% скорости от СТАИ", absf(float(buffs_dog["speed"]) - 1.15) < 0.001)
        _check("контролёр не ловит СТАЮ", is_equal_approx(float(buffs_ctrl["speed"]), 1.0))
        # ТИТАНЫ: явный список
        var act4 := SynergyData.evaluate({"pseudogiant": 1, "chimera": 1})
        _check("ТИТАНЫ активны", _has_id(act4, "titany"))
        _check("ТИТАНЫ не активны без пары", not _has_id(SynergyData.evaluate({"pseudogiant": 2}), "titany"))
        # АЛЬФА-ПАК: лидер + псовые
        var act5 := SynergyData.evaluate({"alpha_pseudodog": 1, "dog_mutant": 1})
        _check("АЛЬФА-ПАК активен", _has_id(act5, "alpha_pak"))
        _check("АЛЬФА-ПАК не активен без альфы", not _has_id(SynergyData.evaluate({"dog_mutant": 1, "ten_pseudodog": 1}), "alpha_pak"))
        # ОБСИДИАН: лидер + psy
        var act6 := SynergyData.evaluate({"obsidian_controller": 1, "poltergeist": 1})
        _check("ОБСИДИАН активен", _has_id(act6, "obsidian_svyaz"))
        # Стак по дизайну: Чёрный контролёр + полтергейст = ПСИ-СЕТЬ (1.2) × ОБСИДИАН (1.25) = 1.5
        var buffs_obs: Dictionary = SynergyData.buffs_for("obsidian_controller", act6)
        _check("ОБСИДИАН+ПСИ-СЕТЬ стакаются: контролёру ×1.5", absf(float(buffs_obs["dmg"]) - 1.5) < 0.001)
        var buffs_polt: Dictionary = SynergyData.buffs_for("poltergeist", act6)
        _check("полтергейсту только ПСИ-СЕТЬ ×1.2", absf(float(buffs_polt["dmg"]) - 1.2) < 0.001)
        # ВЕНЕЦ ЗОНЫ: легендарная пара — баф ВСЕМ
        var act7 := SynergyData.evaluate({"crimson_chimera": 1, "obsidian_titan": 1})
        _check("ВЕНЕЦ активен", _has_id(act7, "venec"))
        var buffs_zombie: Dictionary = SynergyData.buffs_for("zombie", act7)
        _check("ВЕНЕЦ: даже зомби получает +15% HP", absf(float(buffs_zombie["hp"]) - 1.15) < 0.001)
        # Стак: пёс+псевдопёс+альфа — СТАЯ и АЛЬФА-ПАК разом
        var act8 := SynergyData.evaluate({"dog_mutant": 1, "pseudodog": 1, "alpha_pseudodog": 1})
        _check("СТАЯ+АЛЬФА стакаются", _has_id(act8, "staya") and _has_id(act8, "alpha_pak"))
        var buffs_stak: Dictionary = SynergyData.buffs_for("dog_mutant", act8)
        _check("стак скорости 1.15*1.2=1.38", absf(float(buffs_stak["speed"]) - 1.38) < 0.001)

func _has_id(active: Array, id: String) -> bool:
        for s in active:
                if str(s["id"]) == id:
                        return true
        return false

func _test_rarity() -> void:
        print("--- Редкость вариантов ---")
        _check("Бешеный пёс — uncommon→rare рамка... точнее не common", GachaData.get_mutant_rarity("besheniy_pes") != "common")
        _check("кровосос в пуле — rare как раньше", GachaData.get_mutant_rarity("bloodsucker") == "rare")
        _check("Чёрный контролёр — rare (фиолет)", GachaData.get_mutant_rarity("obsidian_controller") == "rare")
        _check("Багровая химера — legendary (золото)", GachaData.get_mutant_rarity("crimson_chimera") == "legendary")
        _check("Обсидиановый титан — legendary (золото)", GachaData.get_mutant_rarity("obsidian_titan") == "legendary")
        _check("уровень анлока Дворового пса — 12", GachaData.get_unlock_campaign_level("dvoroviy_pes") == 12)
        _check("уровень анлока Тени псевдопса — 38", GachaData.get_unlock_campaign_level("ten_pseudodog") == 38)

func _test_spawn_mapping() -> void:
        print("--- Цены вариантов ---")
        var sm = load("res://managers/spawn_manager.gd").new()
        for ex in GachaData.EXCLUSIVE_MUTANTS:
                var t := str(ex["type"])
                _check("цена задана: " + t, sm.mutant_costs.has(t))
        sm.free()

func _test_live_buff() -> void:
        print("--- apply_synergy_buff_live ---")
        var bm = load("res://entities/mutants/base_mutant.gd").new()
        bm.max_health = 100.0
        bm.health = 50.0
        bm.damage = 10.0
        bm.speed = 5.0
        bm.apply_synergy_buff_live(1.2, 1.5, 1.1)
        _check("HP max 100→120", is_equal_approx(float(bm.max_health), 120.0))
        _check("HP тек 50→60", is_equal_approx(float(bm.health), 60.0))
        _check("урон 10→15", is_equal_approx(float(bm.damage), 15.0))
        _check("скорость 5→5.5", is_equal_approx(float(bm.speed), 5.5))
        bm.free()
