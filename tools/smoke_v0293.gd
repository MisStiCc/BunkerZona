# tools/smoke_v0293.gd — смок-тест v0.29.3 «НАГРАДЫ И СВАЙП»
# Запуск: godot --headless -s tools/smoke_v0293.gd  (из корня проекта)
# Проверки:
#   1) ResultPanel: свайп-скролл рядов, кнопка «ПРОДОЛЖИТЬ» на экране при 33 наградах,
#      схлопывание панели, сброс скролла между забегами
#   2) lab_controller: свайп-слои арены/защиты/звёзд/галереи/апгрейда
#   3) gacha_controller: свайп-слои коллекции и выбора
extends SceneTree

var _fails: int = 0

func _check(name: String, cond: bool) -> void:
        if cond:
                print("  [OK]   ", name)
        else:
                _fails += 1
                print("  [FAIL] ", name)

func _initialize() -> void:
        print("=== СМОК v0.29.3 ===")
        await _test_result_panel()
        await _test_swipe_layers()
        print("=== ИТОГ: ", "ALL OK" if _fails == 0 else "ПРОВАЛОВ: %d" % _fails, " ===")
        quit(0 if _fails == 0 else 1)

func _test_result_panel() -> void:
        print("--- ResultPanel ---")
        var scene: PackedScene = load("res://scenes/lab/lab.tscn")
        if scene == null:
                _check("lab.tscn грузится", false)
                return
        var lab: Node = scene.instantiate()
        root.add_child(lab)
        await process_frame
        var rp: Control = lab.get_node_or_null("ResultPanel")
        _check("ResultPanel найден в лабе", rp != null)
        if rp == null:
                return
        # Длинный список: 28 артефактов + 5 круток = 33 строки (как в живом смоке сессии)
        var artifacts: Array = []
        for i in range(28):
                artifacts.append({"type": "common" if i % 3 != 0 else ("legendary" if i == 3 else "rare")})
        var gacha: Array = []
        for i in range(5):
                gacha.append("Крутка #%d: Гравийный колчан" % (i + 1))
        var result := {
                "run_number": 7, "success": true, "reward": 4321,
                "statistics": {"stalkers_killed": 12, "anomalies_created": 8, "mutants_created": 3, "artifacts_stolen": 2},
                "mode": "survival", "waves_survived": 9,
                "artifacts_collected": artifacts, "gacha_rewards": gacha,
        }
        rp.show_result(result)
        await process_frame
        await process_frame
        var scroll: ScrollContainer = rp.get_node_or_null("Panel/Margin/VBox/RowsWrap/RowsScroll")
        _check("скролл RowsScroll создан", scroll != null)
        if scroll:
                var wrap := scroll.get_parent()
                var has_layer := false
                for c in wrap.get_children():
                        if c is SwipeHelper:
                                has_layer = true
                _check("свайп-слой — сиблинг скролла", has_layer)
                _check("ряды внутри скролла: StatsLabel", scroll.find_child("StatsLabel", true, false) != null)
                _check("ряды внутри скролла: ArtifactsLabel", scroll.find_child("ArtifactsLabel", true, false) != null)
        var btn: Button = rp.get_node_or_null("Panel/Margin/VBox/ContinueButton")
        _check("кнопка «ПРОДОЛЖИТЬ» существует", btn != null)
        # Кнопка обязана быть в границах панели (и экрана)
        var vp := rp.get_viewport_rect().size
        var br := btn.get_global_rect()
        var pr: Rect2 = (rp.get_node("Panel") as Control).get_global_rect()
        _check("кнопка в границах панели", pr.encloses(br))
        _check("кнопка на экране", br.position.y + br.size.y <= vp.y + 1.0)
        # Панель схлопнута под контент и не выше 86% экрана
        var ph: float = pr.size.y
        _check("панель <= 86%% экрана (было %d, экран %d)" % [int(ph), int(vp.y)], ph <= vp.y * 0.861)
        _check("панель >= минимума 420", ph >= 419.0)
        _check("панель шире старых 600 (или впритык на узких экранах)", pr.size.x >= 559.0)
        # Прокрутка физически возможна (контент выше окна скролла)
        if scroll:
                _check("контент скроллится (max>0)", scroll.get_v_scroll_bar().max_value > 0.0)
        # Короткий забег: панель схлопывается, скролл сброшен
        var short_res := {"run_number": 8, "success": false, "reward": 10}
        rp.show_result(short_res)
        await process_frame
        await process_frame
        var pr2: Rect2 = (rp.get_node("Panel") as Control).get_global_rect()
        _check("схлопывание: короткий забег ниже длинного", pr2.size.y < ph)
        if scroll:
                _check("скролл сброшен в 0", scroll.scroll_vertical == 0)
        rp.visible = false

func _test_swipe_layers() -> void:
        print("--- Свайп-слои лабы и гачи ---")
        var scene: PackedScene = load("res://scenes/lab/lab.tscn")
        var lab: Node = scene.instantiate()
        root.add_child(lab)
        await process_frame
        await process_frame
        var lc: Node = lab.get_node_or_null("LabController")
        if lc == null:
                # контроллер может быть на корне сцены
                lc = lab if lab.has_method("_make_swipe_overlay") else null
        _check("lab_controller найден", lc != null)
        if lc == null:
                return
        # Арена: список вызовов должен сидеть в обёртке со свайп-слоем
        var foes: VBoxContainer = lc.get("_arena_foes_box")
        _check("_arena_foes_box есть", foes != null)
        if foes:
                var sc := foes.get_parent()          # ScrollContainer
                var ok_chain := false
                if sc is ScrollContainer:
                        var wrap := sc.get_parent()
                        for c in wrap.get_children():
                                if c is SwipeHelper and (c as SwipeHelper).scroll == sc:
                                        ok_chain = true
                _check("арена: цепочка [wrap->[SwipeLayer, scroll]->foes]", ok_chain)
        # Защита
        var def_box: VBoxContainer = lc.get("_defense_list_box")
        if def_box:
                var sc2 := def_box.get_parent()
                var ok2 := false
                if sc2 is ScrollContainer:
                        for c in (sc2.get_parent()).get_children():
                                if c is SwipeHelper:
                                        ok2 = true
                _check("защита: свайп-слой", ok2)
        # Абсолютные панели: звёзды и галерея — слой-сиблинг с тем же rect
        for pair in [["star_list", "звёзды"], ["gallery_list", "галерея"]]:
                var box: Control = lc.get(pair[0])
                if box == null:
                        _check("%s: список найден" % pair[1], false)
                        continue
                var sc3 := box.get_parent()
                if not (sc3 is ScrollContainer):
                        _check("%s: родитель-скролл" % pair[1], false)
                        continue
                var parent_panel: Control = sc3.get_parent()
                var found := false
                for c in parent_panel.get_children():
                        if c is SwipeHelper and (c as SwipeHelper).scroll == sc3:
                                found = true
                _check("%s: слой-сиблинг поверх скролла" % pair[1], found)
        # Апгрейд: диалог строится лениво — строим явно, затем проверяем слой
        if lc.has_method("_build_upgrade_dialog"):
                lc.call("_build_upgrade_dialog")
                await process_frame
        var up_body: Control = lc.get("up_body")
        if up_body:
                var s3 := up_body.get_parent()
                var found3 := false
                if s3 is ScrollContainer:
                        for c in (s3.get_parent()).get_children():
                                if c is SwipeHelper and (c as SwipeHelper).scroll == s3:
                                        found3 = true
                _check("апгрейд: слой-сиблинг поверх скролла", found3)
        else:
                _check("апгрейд: up_body после сборки", false)
        # Гача
        var gsc: PackedScene = load("res://scenes/ui/gacha.tscn")
        _check("gacha.tscn грузится", gsc != null)
        if gsc:
                var g: Node = gsc.instantiate()
                root.add_child(g)
                await process_frame
                var gc: Node = g
                if not g.has_method("_rebuild_gacha_panel"):
                        for c in g.get_children():
                                if c.has_method("_rebuild_gacha_panel"):
                                        gc = c
                                        break
                var coll: GridContainer = gc.get("_coll_box")
                if coll:
                        var s1 := coll.get_parent()
                        var ok1 := s1 is ScrollContainer and s1.get_parent() != null \
                                        and s1.get_parent().get_parent() != null
                        var lay1 := false
                        if s1 is ScrollContainer:
                                for c in s1.get_parent().get_children():
                                        if c is SwipeHelper:
                                                lay1 = true
                        ok1 = lay1
                        _check("гача: свайп коллекции", ok1)
                var ch: GridContainer = gc.get("_choice_box")
                if ch:
                        var lay2 := false
                        var s2 := ch.get_parent()
                        if s2 is ScrollContainer:
                                for c in s2.get_parent().get_children():
                                        if c is SwipeHelper:
                                                lay2 = true
                        _check("гача: свайп выбора", lay2)
                g.queue_free()
        lab.queue_free()
        await process_frame
