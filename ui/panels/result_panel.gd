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

    title_label.text = "ИТОГИ ЗАБЕГА #%d" % result.get("run_number", 1)

    var success = result.get("success", false)
    if success:
        result_label.text = "ПОБЕДА"
        result_label.add_theme_color_override("font_color", Color(0, 1, 0))
    else:
        result_label.text = "ПОРАЖЕНИЕ"
        result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

    var reward = result.get("reward", 0)
    reward_label.text = "Получено биомассы: %d" % reward

    if result.has("statistics"):
        var stats = result["statistics"]
        stats_label.text = "Сталкеров убито: %d\nАномалий создано: %d\nМутантов создано: %d\nАртефактов украдено: %d" % [
            stats.get("stalkers_killed", 0),
            stats.get("anomalies_created", 0),
            stats.get("mutants_created", 0),
            stats.get("artifacts_stolen", 0)
        ]
    else:
        stats_label.text = ""

    if result.get("mode", "") == "survival":
        stats_label.text += "\nВолн пройдено: %d" % int(result.get("waves_survived", 0))
        # Логика победы v0.21.0: причина исхода выживания
        var vreason := str(result.get("victory_reason", ""))
        var atarget := int(result.get("arena_target_wave", 0))
        if success and vreason == "arena_target":
            stats_label.text += "\nВЫЗОВ ВЫИГРАН: волна %d превзойдена!" % atarget
        elif success and vreason == "waves30":
            stats_label.text += "\nЛЕГЕНДА: 30+ волн пережито - ПОБЕДА!"
        elif atarget > 0:
            stats_label.text += "\nЦель вызова: волна %d (не превзойдена)" % atarget
    stats_label.visible = not stats_label.text.is_empty()

    if result.has("artifacts_collected"):
        var common = 0
        var rare = 0
        var legendary = 0

        for a in result["artifacts_collected"]:
            match a.get("type", "common"):
                "common": common += 1
                "rare": rare += 1
                "legendary": legendary += 1

        artifacts_label.text = Loc.t("result.artifacts") + "\nCommon: %d   Rare: %d   Legendary: %d" % [common, rare, legendary]
        artifacts_label.visible = true
    else:
        artifacts_label.text = ""
        artifacts_label.visible = false

    var gacha: Array = result.get("gacha_rewards", [])
    if not gacha.is_empty():
        if artifacts_label.text.is_empty():
            artifacts_label.text = Loc.t("result.gacha_header")
        else:
            artifacts_label.text += "\n" + Loc.t("result.gacha_header")
        artifacts_label.text += "\n" + "\n".join(gacha)
        artifacts_label.visible = true

    # v0.29.3: свайп к началу списка у каждого нового забега
    if _rows_scroll != null:
        _rows_scroll.scroll_vertical = 0
    _fit_panel()
    open()


func _on_continue_pressed():
    close()

    # Автозагрузки не зарегистрированы как Engine-синглтоны -
    # GameManager ищем через группу (Engine.get_singleton здесь всегда падал)
    var gm = get_tree().get_first_node_in_group("game_manager")
    if gm and gm.has_method("change_scene"):
        gm.change_scene("lab")
