# ui/panels/result_panel.gd
extends BasePanel
class_name ResultPanel

## Панель результатов забега (v0.29.3 «НАГРАДЫ И СВАЙП»):
##  - длинные списки наград (артефакты + крутки) едут в свайп-скролле
##    (единый SwipeHelper, как во всей лабе);
##  - кнопка «ПРОДОЛЖИТЬ» всегда остаётся на экране;
##  - панель схлопывается под контент и растёт не дальше 86% экрана.
##
## Причина старого бага: панель была жёстко 600x520, а MarginContainer при
## переполнении центрирует излишек (grow=BOTH) — VBox торчал из панели вверх
## и вниз, список наград рисовался поверх всего экрана, кнопка уезжала за него.

@onready var title_label: Label = $Panel/Margin/VBox/Title
@onready var result_label: Label = $Panel/Margin/VBox/ResultLabel
@onready var reward_label: Label = $Panel/Margin/VBox/RewardLabel
@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var artifacts_label: Label = $Panel/Margin/VBox/ArtifactsLabel
@onready var continue_button: Button = $Panel/Margin/VBox/ContinueButton
@onready var vbox: VBoxContainer = $Panel/Margin/VBox
@onready var panel_box: Panel = $Panel

var run_result: Dictionary = {}

# v0.29.3: скролл рядов наград (создаётся в _ready)
var _rows_scroll: ScrollContainer = null
var _rows_box: VBoxContainer = null

const MARGIN_H := 30.0        # рамка MarginContainer (по tscn)
const SEPARATION := 8.0       # шаг между блоками шапки/кнопкой
const PANEL_MIN_H := 420.0    # ниже не схлопываемся — заголовок дышит
const PANEL_MAX_H_FRAC := 0.86
const PANEL_MAX_W_FRAC := 0.92
const PANEL_MAX_W := 960.0


func _ready():
    panel_name = "ResultPanel"
    continue_button.pressed.connect(_on_continue_pressed)
    _build_rows_scroll()
    _build_banner()


## Шапка-баннер ИТОГОВ (поставка results_pack): над заголовком; файла нет —
## шапка как была
func _build_banner() -> void:
    var p := "res://assets/ui/ceremony/banner_results.png"
    if not ResourceLoader.exists(p):
        return
    var b := TextureRect.new()
    b.texture = load(p)
    b.custom_minimum_size = Vector2(0, 72)
    b.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    b.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vbox.add_child(b)
    vbox.move_child(b, 0)


## Свайп-скролл для рядов: StatsLabel + ArtifactsLabel переезжают внутрь,
## обёртка встаёт в VBox между RewardLabel и ContinueButton ( EXPAND_FILL ),
## поэтому кнопка физически не может уехать за панель.
func _build_rows_scroll() -> void:
    if _rows_scroll != null:
        return
    _rows_scroll = ScrollContainer.new()
    _rows_scroll.name = "RowsScroll"
    _rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    _rows_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
    _rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

    _rows_box = VBoxContainer.new()
    _rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _rows_box.add_theme_constant_override("separation", 6)
    _rows_scroll.add_child(_rows_box)

    var wrap := SwipeHelper.attach(_rows_scroll, false)
    wrap.name = "RowsWrap"
    var idx := stats_label.get_index()          # позиция StatsLabel в VBox
    vbox.add_child(wrap)                        # в конец…
    vbox.move_child(wrap, idx)                  # …на место StatsLabel
    # Godot 4: перенос ноды = явный remove_child, иначе add_child падает
    var old_parent: Node = stats_label.get_parent()
    if old_parent:
            old_parent.remove_child(stats_label)
    old_parent = artifacts_label.get_parent()
    if old_parent:
            old_parent.remove_child(artifacts_label)
    _rows_box.add_child(stats_label)
    _rows_box.add_child(artifacts_label)


## Схлопывание: панель подгоняется под контент (не выше 86% экрана).
## Минимальные размеры меток известны сразу — кадр ждать не нужно.
func _fit_panel() -> void:
    var vp := get_viewport_rect().size
    var head_h := 0.0
    for c in [title_label, result_label, reward_label]:
        head_h += (c as Control).get_combined_minimum_size().y
    var rows_h := 0.0
    for c in [stats_label, artifacts_label]:
        if (c as Control).visible:
            rows_h += (c as Control).get_combined_minimum_size().y
    var btn_h := continue_button.get_combined_minimum_size().y
    # шапка + ряды + кнопка + рамка + запас на разделители VBox
    var desired := head_h + rows_h + btn_h + 2.0 * MARGIN_H + 6.0 * SEPARATION
    var h := clampf(desired, PANEL_MIN_H, vp.y * PANEL_MAX_H_FRAC)
    var w := clampf(vp.x * PANEL_MAX_W_FRAC, 560.0, PANEL_MAX_W)
    if w > vp.x * PANEL_MAX_W_FRAC:
        w = vp.x * PANEL_MAX_W_FRAC
    panel_box.offset_left = -w * 0.5
    panel_box.offset_right = w * 0.5
    panel_box.offset_top = -h * 0.5
    panel_box.offset_bottom = h * 0.5


func show_result(result: Dictionary):
    run_result = result

    # ОХОТА (D19): свой заголовок и статус; остальные режимы - как раньше
    var is_hunt := str(result.get("mode", "")) == "hunt"
    var success: bool = bool(result.get("success", false))

    if is_hunt:
        title_label.text = Loc.t("hunt.result_title")
        if success:
            result_label.text = Loc.t("hunt.result_win")
            result_label.add_theme_color_override("font_color", Color(0, 1, 0))
        else:
            result_label.text = Loc.t("hunt.result_lose")
            result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
    else:
        title_label.text = Loc.t("result.title", {"n": int(result.get("run_number", 1))})
        if success:
            result_label.text = Loc.t("result.victory")
            result_label.add_theme_color_override("font_color", Color(0, 1, 0))
        else:
            result_label.text = Loc.t("result.defeat")
            result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

    var reward = result.get("reward", 0)
    reward_label.text = Loc.t("result.biomass", {"n": int(reward)})

    if is_hunt:
        # Итоги охоты: урон и убийства; жетоны - только для гильд-рейда,
        # обычная охота даёт Искры (оценка) либо биомассу
        var killed: Array = result.get("hunt_killed", [])
        var dmg_dealt: int = int(result.get("boss_dmg_dealt", 0))
        var hunt_lines: Array = [Loc.t("hunt.line_dmg", {"n": dmg_dealt})]
        if not killed.is_empty():
            hunt_lines.append(Loc.t("hunt.line_killed", {"n": killed.size()}))
        if bool(result.get("guild_boss", false)):
            var tokens_est: int = mini(int(float(dmg_dealt) / 500.0), 60)
            if tokens_est > 0:
                hunt_lines.append(Loc.t("hunt.line_tokens", {"n": tokens_est}))
        else:
            var sparks_est: int = killed.size() * 3
            if sparks_est > 0:
                hunt_lines.append(Loc.t("hunt.line_sparks", {"n": sparks_est}))
        reward_label.text += "
" + " · ".join(hunt_lines)
    else:
        # Разбивка награды (v0.31.2): из чего сложилась цифра
        var br: Dictionary = result.get("reward_breakdown", {})
        if not br.is_empty():
            var lines: Array = [Loc.t("result.br_combat", {"n": int(float(br.get("combat", 0.0)))})]
            if float(br.get("leftover", 0.0)) > 0.0:
                lines.append(Loc.t("result.br_leftover", {"n": int(float(br["leftover"]))}))
            if float(br.get("level_bonus", 0.0)) > 0.0:
                lines.append(Loc.t("result.br_bonus", {"n": int(float(br["level_bonus"]))}))
            # Мультипачка (D20): боёв пачек и их множитель
            var packs_won: int = int(result.get("pack_battles_won", 0))
            if packs_won > 0:
                lines.append(Loc.t("result.packs", {"n": packs_won}))
            if float(br.get("pack_mult", 1.0)) > 1.0:
                lines.append(Loc.t("result.pack_mult", {"n": "%.1f" % float(br["pack_mult"])}))
            if float(br.get("cycle_mult", 1.0)) > 1.0:
                lines.append(Loc.t("result.br_cycle", {"m": "%.2f" % float(br["cycle_mult"])}))
            reward_label.text += "
" + " · ".join(lines)

    if result.has("statistics"):
        var stats = result["statistics"]
        stats_label.text = Loc.t("result.stalkers", {"n": int(stats.get("stalkers_killed", 0))}) + "
"             + Loc.t("result.anomalies", {"n": int(stats.get("anomalies_created", 0))}) + "
"             + Loc.t("result.mutants", {"n": int(stats.get("mutants_created", 0))}) + "
"             + Loc.t("result.stolen", {"n": int(stats.get("artifacts_stolen", 0))})
        var kr: Dictionary = result.get("kills_by_rank", {})
        if not kr.is_empty():
            stats_label.text += "
" + Loc.t("result.by_rank",
                {"n": int(kr.get("novice", 0)), "v": int(kr.get("veteran", 0)), "m": int(kr.get("master", 0))})
    else:
        stats_label.text = ""

    if result.get("mode", "") == "survival":
        stats_label.text += "
" + Loc.t("result.waves", {"n": int(result.get("waves_survived", 0))})
        var vreason := str(result.get("victory_reason", ""))
        var atarget := int(result.get("arena_target_wave", 0))
        if success and vreason == "arena_target":
            stats_label.text += "
" + Loc.t("result.challenge_won", {"n": atarget})
        elif success and vreason == "waves30":
            stats_label.text += "
" + Loc.t("result.legend30")
        elif atarget > 0:
            stats_label.text += "
" + Loc.t("result.challenge_goal", {"n": atarget})
    stats_label.visible = not stats_label.text.is_empty()

func _on_continue_pressed():
    close()

    # Автозагрузки не зарегистрированы как Engine-синглтоны -
    # GameManager ищем через группу (Engine.get_singleton здесь всегда падал)
    var gm = get_tree().get_first_node_in_group("game_manager")
    if gm and gm.has_method("change_scene"):
        gm.change_scene("lab")
