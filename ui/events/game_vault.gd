# ui/events/game_vault.gd
extends Control
class_name GameVault

## «ВЗЛОМ КОТЕЛКА» (D24): Mastermind-сейфы. Код из 4 аномалий (6 видов,
## повторы есть) — выставляй комбинацию, «Электра» показывает: ⚡ стоит на
## месте, ○ есть не на месте. 8 попыток на сейф, 5 сейфов (+6-й «сейф
## Котелка» с кодом из 5). Счёт: сейф ×500 − попытки ×40 (≤3 попыток ×2);
## осколки = счёт / 40.

const CODE_LEN: int = 4
const CODE_LEN_FINAL: int = 5
const TRIES: int = 8
const SAFES: int = 5
const SAFE_SCORE: int = 500
const TRY_PENALTY: int = 40
const GLYPHS := ["🔥", "⚡", "☣", "🌀", "☢", "⏳"]
const COLORS := [Color("e06040"), Color("e8c840"), Color("70c850"),
	Color("5090e0"), Color("b0e040"), Color("a070e0")]

var _code: Array = []             # скрытый код [int]
var _guess: Array = []            # текущая комбинация
var _tries_left: int = TRIES
var _safes_done: int = 0
var _score: int = 0
var _over: bool = false
var _history: VBoxContainer
var _slots_row: HBoxContainer
var _slot_btns: Array = []
var _head: Label
var _event: Dictionary
var _game_manager: Node


func _ready() -> void:
	_game_manager = get_tree().get_first_node_in_group("game_manager")
	_event = EventsData.current_event(int(Time.get_unix_time_from_system()))
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_new_safe()


func _build() -> void:
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.02)
	add_child(shade)

	var head := Label.new()
	head.text = Loc.t("evt.banner") % str(_event["title_" + ("ru" if Loc.lang == "ru" else "en")])
	head.position = Vector2(20, 14)
	head.add_theme_font_override("font", BunkerUI.font_title())
	head.add_theme_font_size_override("font_size", 20)
	head.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(head)

	var vp := get_viewport().get_visible_rect().size
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = -320
	panel.offset_bottom = 320
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.HAZARD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
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

	_head = Label.new()
	_head.add_theme_font_override("font", BunkerUI.font_title())
	_head.add_theme_font_size_override("font_size", 17)
	_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_head.add_theme_color_override("font_color", BunkerUI.TEXT_BRIGHT)
	v.add_child(_head)

	var hint := Label.new()
	hint.text = Loc.t("vault.hint")
	hint.add_theme_font_override("font", BunkerUI.font_body())
	hint.add_theme_font_size_override("font_size", 12)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", BunkerUI.TEXT_DIM)
	v.add_child(hint)

	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 10)
	v.add_child(_slots_row)

	var submit := Button.new()
	submit.text = Loc.t("vault.submit")
	submit.custom_minimum_size = Vector2(0, 52)
	BunkerUI.style_button(submit, "primary", 18, true)
	submit.pressed.connect(_on_submit)
	v.add_child(submit)

	_history = VBoxContainer.new()
	_history.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_history.add_theme_constant_override("separation", 3)
	v.add_child(_history)


func _new_safe() -> void:
	var code_len: int = CODE_LEN_FINAL if _safes_done >= SAFES else CODE_LEN
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_code.clear()
	for i in code_len:
		_code.append(rng.randi_range(0, GLYPHS.size() - 1))
	_guess.clear()
	for i in code_len:
		_guess.append(0)
	_tries_left = TRIES
	_slots_row.queue_free()
	_slots_row = HBoxContainer.new()
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slots_row.add_theme_constant_override("separation", 10)
	# вставить слоты сразу после head (история должна остаться внизу)
	var v: VBoxContainer = _history.get_parent()
	v.add_child(_slots_row)
	v.move_child(_slots_row, 2)
	_slot_btns.clear()
	for i in code_len:
		var b := Button.new()
		b.custom_minimum_size = Vector2(64, 64)
		b.add_theme_font_size_override("font_size", 26)
		BunkerUI.style_button(b, "steel", 16)
		b.pressed.connect(_on_slot.bind(i))
		_slots_row.add_child(b)
		_slot_btns.append(b)
	_style_slots()
	_head.text = "%s %d/%d%s   ·   %s %d" % [
		Loc.t("vault.safe"), _safes_done + 1,
		CODE_LEN_FINAL if _safes_done >= SAFES else SAFES,
		" · " + Loc.t("vault.kotelok") if _safes_done >= SAFES else "",
		Loc.t("vault.tries"), _tries_left]


func _style_slots() -> void:
	for i in _slot_btns.size():
		var b: Button = _slot_btns[i]
		b.text = GLYPHS[_guess[i]]
		var sb := StyleBoxFlat.new()
		sb.bg_color = COLORS[_guess[i]].darkened(0.6)
		sb.border_color = COLORS[_guess[i]]
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)


func _on_slot(i: int) -> void:
	if _over:
		return
	_play_click()
	_guess[i] = (_guess[i] + 1) % GLYPHS.size()
	_style_slots()


func _on_submit() -> void:
	if _over:
		return
	_tries_left -= 1
	# фидбек Mastermind
	var exact := 0
	var partial := 0
	var code_left: Dictionary = {}
	var guess_left: Dictionary = {}
	for i in _code.size():
		if _guess[i] == _code[i]:
			exact += 1
		else:
			code_left[_code[i]] = int(code_left.get(_code[i], 0)) + 1
			guess_left[_guess[i]] = int(guess_left.get(_guess[i], 0)) + 1
	for k in guess_left:
		partial += mini(int(guess_left[k]), int(code_left.get(k, 0)))

	var row := Label.new()
	var pips := ""
	for i in exact:
		pips += "⚡"
	for i in partial:
		pips += "○"
	for i in _code.size() - exact - partial:
		pips += "✕"
	var guess_str := ""
	for g in _guess:
		guess_str += GLYPHS[g]
	row.text = "%s  %s" % [guess_str, pips]
	row.add_theme_font_override("font", BunkerUI.font_body())
	row.add_theme_font_size_override("font_size", 15)
	row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_theme_color_override("font_color",
		BunkerUI.TEXT_BRIGHT if exact == _code.size() else BunkerUI.TEXT_DIM)
	_history.add_child(row)

	if exact == _code.size():
		_safe_cracked()
	elif _tries_left <= 0:
		_flash(Loc.t("vault.failed"))
		_next_safe()
	else:
		_head.text = "%s %d   ·   %s %d" % [
			Loc.t("vault.safe"), _safes_done + 1, Loc.t("vault.tries"), _tries_left]


func _safe_cracked() -> void:
	var bonus := 2 if _tries_left >= TRIES - 3 else 1
	_score += maxi(0, SAFE_SCORE - (TRIES - _tries_left) * TRY_PENALTY) * bonus
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("vault_open" if sm.get("ambient_sounds").has("vault_open") else "upgrade", 0.8)
	_flash(Loc.t("vault.cracked"))
	_next_safe()


func _next_safe() -> void:
	_safes_done += 1
	if _safes_done >= SAFES + 1:
		_finish()
		return
	# небольшая пауза перед следующим сейфом
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(_new_safe)


func _flash(text: String) -> void:
	var note := Label.new()
	note.text = text
	note.anchor_left = 0.5
	note.anchor_right = 0.5
	note.anchor_top = 1.0
	note.anchor_bottom = 1.0
	note.offset_left = -240
	note.offset_right = 240
	note.offset_top = -92
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_override("font", BunkerUI.font_body())
	note.add_theme_font_size_override("font_size", 14)
	note.add_theme_color_override("font_color", BunkerUI.HAZARD_BRIGHT)
	add_child(note)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(note, "modulate:a", 0.0, 0.3)
	tw.tween_callback(note.queue_free)


func _finish() -> void:
	_over = true
	var shards := 0
	if _game_manager and _game_manager.current_save_data:
		shards = EventOps.add_score(_game_manager.current_save_data, _event, _score)
		_game_manager.save_to_active_slot()
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ceremony_win", 0.8)
	var panel := Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -240
	panel.offset_right = 240
	panel.offset_top = -140
	panel.offset_bottom = 140
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.031, 0.045, 0.026, 0.99)
	sb.border_color = BunkerUI.HAZARD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 16
	v.offset_right = -16
	v.offset_top = 14
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var t := Label.new()
	t.text = Loc.t("vault.done")
	t.add_theme_font_override("font", BunkerUI.font_title())
	t.add_theme_font_size_override("font_size", 22)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Label.new()
	s.text = "%s %d\n%s %d" % [Loc.t("zharva.score"), _score,
		Loc.t("evt.shards_line"), shards]
	s.add_theme_font_override("font", BunkerUI.font_mono())
	s.add_theme_font_size_override("font_size", 15)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var ok := Button.new()
	ok.text = Loc.t("evt.back_hub")
	ok.custom_minimum_size = Vector2(0, 48)
	BunkerUI.style_button(ok, "primary", 18, true)
	ok.pressed.connect(func():
		queue_free()
		var hub := EventHub.new()
		get_tree().current_scene.add_child(hub)
		hub.open())
	v.add_child(ok)


func _play_click() -> void:
	var sm = get_tree().get_first_node_in_group("sound_manager")
	if sm and sm.has_method("play_sound"):
		sm.play_sound("ui_click", 0.5)
