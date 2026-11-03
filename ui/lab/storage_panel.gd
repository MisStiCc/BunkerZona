# ui/lab/storage_panel.gd
extends CanvasLayer
class_name LabStoragePanel

## СКЛАД (задача владельца): сундуки и расходники магазина ложатся сюда,
## открываются отсюда же. Сундук «Эксклюзив на выбор»: окно выбора -
## новый эксклюзив открывается, повтор идёт кормом на ферму.

const COL_GOLD := Color("ffd94d")
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)

var _root: Control = null
var _list: VBoxContainer = null
var _choice_box: VBoxContainer = null

func build() -> void:
	layer = 21
	if _root == null:
		_root = Control.new()
		add_child(_root)
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var w: float = clampf(vp.x * 0.6, 380.0, 640.0)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -vp.y * 0.38
	panel.offset_bottom = vp.y * 0.38
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	_root.add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = Loc.t("stor.title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	_list = box
	_choice_box = null

	var close_btn := Button.new()
	close_btn.text = Loc.t("lab.back")
	close_btn.custom_minimum_size = Vector2(200, 48)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BunkerUI.style_button(close_btn, "steel", 15)
	close_btn.pressed.connect(close)
	v.add_child(close_btn)


func open() -> void:
	if _root == null:
		build()
	_refresh()
	_root.visible = true


func close() -> void:
	if _root:
		_root.visible = false


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null or gm.current_save_data == null:
		return
	var lab = gm.get_lab_data()
	var any := false
	for key in lab.storage:
		var n: int = int(lab.storage[key])
		if n <= 0:
			continue
		any = true
		_list.add_child(_make_item_row(str(key), n))
	if not any:
		var empty := Label.new()
		empty.text = Loc.t("stor.empty")
		empty.add_theme_color_override("font_color", COL_DIM)
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_list.add_child(empty)


func _make_item_row(key: String, n: int) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.06, 0.95)
	sb.border_color = Color(0.26, 0.29, 0.21, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(8)
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var name_l := Label.new()
	name_l.text = "%s x%d" % [Loc.t("stor.item_" + key), n]
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", COL_TEXT)
	h.add_child(name_l)
	var use := Button.new()
	use.text = Loc.t("stor.open")
	use.custom_minimum_size = Vector2(140, 44)
	BunkerUI.style_button(use, "primary", 14)
	use.pressed.connect(_on_open_item.bind(key))
	h.add_child(use)
	return row


func _on_open_item(key: String) -> void:
	_play_click()
	if key == "excl_choice":
		_show_exclusive_choice()
	else:
		_toast(Loc.t("stor.unknown"))


## Сундук эксклюзива: окно ВЫБОРА (новый - открыть, повтор - корм на ферму)
func _show_exclusive_choice() -> void:
	# Заменяем список на выбор
	for c in _list.get_children():
		c.queue_free()
	_choice_box = _list
	var gm = get_tree().get_first_node_in_group("game_manager")
	var lab = gm.get_lab_data() if gm else null
	if lab == null:
		return
	var header := Label.new()
	header.text = Loc.t("stor.excl_pick")
	header.add_theme_font_override("font", BunkerUI.font_title())
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", COL_GOLD)
	_list.add_child(header)
	for ex in GachaData.EXCLUSIVE_MUTANTS:
		var t := str(ex["type"])
		var owned: bool = lab.unlocked_mutants.has(t)
		_list.add_child(_make_excl_row(t, true, owned))
	for ax in GachaData.EXCLUSIVE_ANOMALIES:
		var t2 := str(ax["type"])
		var owned2: bool = lab.exclusive_anomalies.has(t2)
		_list.add_child(_make_excl_row(t2, false, owned2))


func _make_excl_row(type: String, is_mutant: bool, owned: bool) -> Control:
	var row := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.09, 0.06, 0.95)
	sb.border_color = COL_GOLD if not owned else Color(0.26, 0.29, 0.21, 0.8)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(6)
	row.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	row.add_child(h)
	var icon := TextureRect.new()
	icon.texture = load(GachaData.card_icon_path(type, is_mutant, false))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	h.add_child(icon)
	var name_l := Label.new()
	name_l.text = Loc.type_name(type) + ("   ·  " + Loc.t("stor.excl_owned") if owned else "")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.add_theme_color_override("font_color", COL_TEXT if not owned else COL_DIM)
	h.add_child(name_l)
	var take := Button.new()
	take.text = Loc.t("stor.excl_take")
	take.custom_minimum_size = Vector2(150, 40)
	BunkerUI.style_button(take, "primary" if not owned else "steel", 13)
	take.pressed.connect(_on_take_exclusive.bind(type, is_mutant))
	h.add_child(take)
	return row


func _on_take_exclusive(type: String, is_mutant: bool) -> void:
	_play_click()
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		return
	# Списываем сундук
	var lab = gm.get_lab_data()
	lab.storage["excl_choice"] = int(lab.storage.get("excl_choice", 0)) - 1
	if int(lab.storage.get("excl_choice", 0)) <= 0:
		lab.storage.erase("excl_choice")
	# Выдача: новый - разблокировка, повтор - копия на ферму (корм!) / +400 био
	var status := "new"
	if is_mutant:
		var res: Dictionary = gm.grant_exclusive_mutant(type)
		status = str(res.get("status", "new"))
	else:
		status = gm.grant_exclusive_anomaly(type)
	gm.save_to_active_slot()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("guild_coin", 0.8)
	if is_mutant and status == "dup":
		_toast(Loc.t("stor.excl_dup_fodder", {"name": Loc.type_name(type)}))
	elif not is_mutant and status == "dup":
		_toast(Loc.t("stor.excl_dup_bio"))
	else:
		_toast(Loc.t("stor.excl_new", {"name": Loc.type_name(type)}))
	_refresh()


func _toast(text: String) -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)
	# плашка поверх списка
	var note := Label.new()
	note.text = text
	note.add_theme_color_override("font_color", Color("a8ff7a"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_list.add_child(note)


func _play_click() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)
