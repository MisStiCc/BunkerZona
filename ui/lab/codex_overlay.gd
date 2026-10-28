# ui/lab/codex_overlay.gd
extends CanvasLayer
class_name CodexOverlay

## КОДЕКС ЗОНЫ (спека zona_codex): 5 статичных страниц-справок в стиле
## панелей лаборатории. Тексты - ключи codex.* в Loc; данные страниц -
## статический контент здесь (это текст, не баланс). Слой 9 - поверх
## панелей лабы; работает и в меню без лаборатории.

const COL_GOLD := Color("ffd94d")
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)

var _root: Control = null
var _tabs_box: HBoxContainer = null
var _scroll: ScrollContainer = null
var _text: Label = null
var _page: int = 0
var _tab_group: ButtonGroup = null

# [ключ вкладки, [ключи абзацев]]
const PAGES := [
	["codex.tab_res", ["codex.res.energy", "codex.res.bio", "codex.res.rolls", "codex.res.sp"]],
	["codex.tab_anom", ["codex.anom.place", "codex.anom.unlock", "codex.anom.sets", "codex.anom.trophy"]],
	["codex.tab_mut", ["codex.mut.cost", "codex.mut.stars", "codex.mut.recycle"]],
	["codex.tab_rad", ["codex.rad.blow", "codex.rad.zone"]],
	["codex.tab_modes", ["codex.modes.campaign", "codex.modes.tower", "codex.modes.survival", "codex.modes.season"]],
]


func _ready() -> void:
	layer = 9
	_build()


func open() -> void:
	if _root == null:
		_build()
	_page = 0
	_refresh()
	_root.visible = true


func _build() -> void:
	_root = Control.new()
	_root.name = "CodexRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			close())
	_root.add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var vp := get_viewport().get_visible_rect().size
	var w: float = clampf(vp.x * 0.55, 340.0, 640.0)
	if vp.x < 900.0:
		w = vp.x * 0.94   # узкий экран: во всю ширину
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -vp.y * 0.35
	panel.offset_bottom = vp.y * 0.35
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.GREEN
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 22
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = Loc.t("codex.title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", BunkerUI.GREEN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	v.add_child(_tabs_box)
	_tab_group = ButtonGroup.new()

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(_scroll, false))

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_override("font", BunkerUI.font_body())
	_text.add_theme_font_size_override("font_size", 13)
	_text.add_theme_color_override("font_color", COL_TEXT)
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_text)

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.custom_minimum_size = Vector2(200, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BunkerUI.style_button(close_btn, "steel", 15)
	close_btn.pressed.connect(close)
	v.add_child(close_btn)


func _refresh() -> void:
	for c in _tabs_box.get_children():
		c.queue_free()
	for i in range(PAGES.size()):
		var b := Button.new()
		b.text = Loc.t(str(PAGES[i][0]))
		b.toggle_mode = true
		b.button_group = _tab_group
		b.button_pressed = i == _page
		b.custom_minimum_size = Vector2(0, 40)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 12)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_tab.bind(i))
		_tabs_box.add_child(b)

	var paras: Array = PAGES[_page][1]
	var parts: Array = []
	for k in paras:
		parts.append(str(Loc.t(str(k))))
	_text.text = "  \n\n".join(parts)
	if _scroll:
		_scroll.scroll_vertical = 0


func _on_tab(i: int) -> void:
	_play_click()
	_page = i
	_refresh()


func close() -> void:
	if _root:
		_root.visible = false


func _play_click() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)
