# ui/lab/store_panel.gd
extends Control
class_name StorePanel

## Витрина монетизации (D16). Строится ТОЛЬКО при StoreData.ENABLED -
## lab_controller не зовёт build() иначе. Цены - из стора, фолбэк из
## таблицы StoreData.PRODUCTS (офлайн-UI). Покупки через BillingManager.

const COL_GOLD := Color("ffd94d")
const COL_TEXT := Color(0.92, 0.9, 0.8)
const COL_DIM := Color(0.72, 0.7, 0.58)

var _billing: BillingManager = null
var _grid: GridContainer = null
var _note: Label = null
var _prices: Dictionary = {}   # sku -> цена из стора (пусто = фолбэк таблицы)


func build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			visible = false)
	add_child(dim)

	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	var vp := get_viewport().get_visible_rect().size
	var w: float = clampf(vp.x * 0.7, 480.0, 900.0)
	panel.offset_left = -w * 0.5
	panel.offset_right = w * 0.5
	panel.offset_top = -vp.y * 0.4
	panel.offset_bottom = vp.y * 0.4
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = COL_GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 12
	v.offset_bottom = -12
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)

	var title := Label.new()
	title.text = Loc.t("store.title")
	title.add_theme_font_override("font", BunkerUI.font_title())
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COL_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)

	_note = Label.new()
	_note.text = Loc.t("store.note_power")
	_note.add_theme_font_size_override("font_size", 12)
	_note.add_theme_color_override("font_color", COL_DIM)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_note)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(SwipeHelper.attach(scroll, false))
	_grid = GridContainer.new()
	_grid.columns = 2
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)

	var close := Button.new()
	close.text = Loc.t("lab.back")
	close.custom_minimum_size = Vector2(220, 50)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	BunkerUI.style_button(close, "steel", 16)
	close.pressed.connect(func(): visible = false)
	v.add_child(close)

	_fill()


func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	# Первый экран: пропуск, стартовый пак, топ-паки, эксклюзив, слоты
	var show_order := ["pass_s1", "offer_first", "rolls_mut_10", "rolls_mut_10p",
		"rolls_art_15", "excl_choice", "conv_slots12", "conv_autofill"]
	for sku in show_order:
		if StoreData.PRODUCTS.has(sku):
			_grid.add_child(_make_card(sku))
	# Остальное - по вкладкам позже (косметика/биомасса)
	for sku in StoreData.PRODUCTS:
		if sku in show_order:
			continue
		_grid.add_child(_make_card(str(sku)))


func _make_card(sku: String) -> Control:
	var info: Dictionary = StoreData.PRODUCTS[sku]
	var price: String = str(_prices.get(sku, str(info.get("price_rub", 0)) + " ₽"))
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.065, 0.045, 0.98)
	sb.border_color = COL_GOLD if sku.begins_with("pass") else Color(0.5, 0.46, 0.3)
	sb.set_border_width_all(2 if not sku.begins_with("pass") else 3)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	pc.add_theme_stylebox_override("panel", sb)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)

	var name_l := Label.new()
	name_l.text = Loc.t("store.sku_" + sku) if _has_key("store.sku_" + sku) else sku
	name_l.add_theme_font_override("font", BunkerUI.font_title())
	name_l.add_theme_font_size_override("font_size", 19)
	name_l.add_theme_color_override("font_color", COL_GOLD)
	v.add_child(name_l)

	var buy := Button.new()
	buy.custom_minimum_size = Vector2(0, 48)
	BunkerUI.style_button(buy, "primary", 16)
	buy.pressed.connect(_on_buy.bind(sku))
	v.add_child(buy)

	if not is_instance_valid(_billing) or not _billing.store_available():
		buy.disabled = true
		buy.text = Loc.t("store.unavailable")
		buy.modulate = Color(1, 1, 1, 0.7)
	else:
		buy.text = Loc.t("store.buy") + "  " + price
	return pc


func _on_buy(sku: String) -> void:
	if not is_instance_valid(_billing) or not _billing.store_available():
		return
	_billing.purchase(sku)


func _has_key(key: String) -> bool:
	# Loc.t вернёт сам ключ при отсутствии - различаем по совпадению
	return Loc.t(key) != key


func open() -> void:
	if _billing == null:
		_billing = BillingManager.new()
		add_child(_billing)
		_billing.products_loaded.connect(func(prices: Dictionary):
			_prices = prices
			_fill())
		_billing.start()
	visible = true
	_fill()
