# ui/lab/accessibility_controls.gd
extends VBoxContainer
class_name AccessibilityControls

## Блок настроек доступности (D14): масштаб UI, дальтоник, тряска, мерцание.
## Живёт в settings.cfg [ui]; вставляется в настройки меню и лаборатории.
## Масштаб применяется к корню текущей сцены (HUD боя не масштабируется).

var _cb_values: Array = ["off", "protan", "deutan"]


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	custom_minimum_size = Vector2(340, 158)
	_add_slider(Loc.t("access.scale"), Accessibility.ui_scale(), 0.8, 1.3, 0.05,
		func(v: float):
			Accessibility.set_value("scale", v)
			_apply_scale())
	_add_slider(Loc.t("access.shake"), Accessibility.shake_mult(), 0.0, 1.0, 0.1,
		func(v: float): Accessibility.set_value("shake", v))
	_add_slider(Loc.t("access.flicker"), Accessibility.flicker_mult(), 0.0, 1.0, 0.1,
		func(v: float): Accessibility.set_value("flicker", v))
	_add_colorblind_button()
	_apply_scale()


func _add_slider(text: String, value: float, mn: float, mx: float, step: float, on_change: Callable) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(0, 18)
	s.value_changed.connect(on_change)
	add_child(s)


func _add_colorblind_button() -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 30)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		var nxt: int = (Accessibility.colorblind() + 1) % 3
		Accessibility.set_value("cb", nxt)
		_update_cb_text(b))
	_update_cb_text(b)
	add_child(b)


func _update_cb_text(b: Button) -> void:
	var names: Array = [Loc.t("access.cb_off"), Loc.t("access.cb_protan"), Loc.t("access.cb_deutan")]
	b.text = Loc.t("access.cb") + ": " + str(names[Accessibility.colorblind()])


func _apply_scale() -> void:
	var scene := get_tree().current_scene
	if scene is Control:
		Accessibility.apply_ui_scale(scene)
