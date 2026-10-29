# ui/lab/tier_gates.gd
extends Control
class_name TierGates

## ВРАТА ЯРУСОВ БАШНИ — дизайн «Монолит» (макет пользователя, 28.10.2026).
## 10 врат = 10 ярусов башни. Показываются три стелы: предыдущая/выбранная/следующая.
## Всё рисуется кодом (_draw): парящие плиты со сканлайнами, рунное кольцо над
## выбранной (вращается), символы награды над каждой плитой (звёзды/Хранитель/
## этажи — видно, что внутри, ещё до клика), восходящие пылинки, полоса звёзд.
## Клик по стеле — выбрать ярус (signal selection_changed). Свайп — соседний ярус.

signal selection_changed(tier_idx: int)   # 0..9

const COL_BG_GLOW := Color(1.0, 0.72, 0.25)
const COL_SLAB_TOP := Color("1f2618")
const COL_SLAB_BOT := Color("10140b")
const COL_SLAB_EDGE := Color("2c3422")
const COL_INNER := Color(0.016, 0.022, 0.012, 0.97)
const COL_GOLD := Color("e8b339")
const COL_GOLD_HI := Color("ffd061")
const COL_PLATE := Color("141810")
const COL_PLATE_EDGE := Color("3a4230")
const COL_NAME := Color("e8e0c8")
const COL_NAME_ON := Color("ffd061")
const COL_SUB := Color("93987f")
const COL_FAINT := Color("6b705f")
const COL_SCAN := Color(0.55, 0.67, 0.47, 0.028)
const COL_RING := Color("6d7a58")

var frontier_floor: int = 1            # открытый рубеж (лучший прогресс)
var tier_names: Array = []             # 10 имён ярусов
var tier_stars: Array = []             # 10 сумм звёзд яруса
var tier_bosses: Array = []            # 10 имён Хранителей
var selected_tier: int = 0             # выбранный ярус (0-based)

var _t: float = 0.0
var _slots: Array = []                 # Rect2 стел текущего кадра (хит-тест)
var _slot_tiers: Array = []            # параллельно _slots: какой ЯРУС в каждом слоте
var _press_pos: Vector2 = Vector2.ZERO # точка нажатия (для свайпа)
var _press_active: bool = false
var _swiped: bool = false              # свайп в этом нажатии уже сработал
var _nudge: float = 0.0                # анимация упругого кивка (0..1)
var _nudge_dir: float = 0.0            # направление кивка (+1 вправо / -1 влево)
var _dust: Array = []                  # восходящие пылинки {x(0..1), y, sp, ph}

const SWIPE_THRESHOLD := 80.0          # пикселей (дизайн-координаты) для срабатывания жеста
const DUST_COUNT := 16


func _ready() -> void:
        mouse_filter = Control.MOUSE_FILTER_STOP
        for i in range(DUST_COUNT):
                _dust.append({
                        "x": randf(),
                        "y": randf(),
                        "sp": randf_range(0.045, 0.11),
                        "ph": randf() * TAU,
                })


func _process(delta: float) -> void:
        _t += delta
        if _nudge > 0.0:
                _nudge = maxf(_nudge - delta * 4.5, 0.0)
        for d in _dust:
                d["y"] -= d["sp"] * delta
                if d["y"] < -0.02:
                        d["y"] = 1.02
                        d["x"] = randf()
        if visible:
                queue_redraw()


func setup(frontier: int, names: Array, stars: Array, bosses: Array, sel: int = -1) -> void:
        frontier_floor = clampi(frontier, 1, 100)
        tier_names = names
        tier_stars = stars
        tier_bosses = bosses
        if sel >= 0:
                selected_tier = sel
        elif frontier_floor >= 100:
                selected_tier = 9
        else:
                selected_tier = clampi((frontier_floor - 1) / 10, 0, 9)
        queue_redraw()


func _gui_input(event: InputEvent) -> void:
        # Тач на Android приходит как мышь (emulate_mouse_from_touch = true по умолчанию),
        # поэтому обрабатываем ТОЛЬКО mouse-семейство — иначе жест задвоится.
        if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
                if event.pressed:
                        _press_pos = event.position
                        _press_active = true
                        _swiped = false
                else:
                        _press_active = false
                        if not _swiped:
                                _select_gate_at(event.position)
                accept_event()
        elif event is InputEventMouseMotion and _press_active:
                var dx: float = event.position.x - _press_pos.x
                if absf(dx) >= SWIPE_THRESHOLD:
                        _swiped = true
                        _step_tier(1 if dx < 0.0 else -1)   # свайп влево = следующий ярус
                        _press_pos = event.position          # можно продолжить — ещё шаг
                accept_event()


## Клик по стеле — выбрать ярус НА ЭТОМ СЛОТЕ (слот ≠ номер яруса!)
func _select_gate_at(pos: Vector2) -> void:
        for i in range(_slots.size()):
                if (_slots[i] as Rect2).has_point(pos):
                        var tier: int = int(_slot_tiers[i]) if i < _slot_tiers.size() else i
                        if selected_tier != tier:
                                selected_tier = tier
                                selection_changed.emit(tier)
                                queue_redraw()
                        return


## Шаг на соседний ярус жестом (или упор в край с упругим кивком)
func _step_tier(dir: int) -> void:
        var nxt: int = clampi(selected_tier + dir, 0, 9)
        _nudge = 1.0
        _nudge_dir = float(dir)
        if nxt != selected_tier:
                selected_tier = nxt
                selection_changed.emit(nxt)
        queue_redraw()


func _tier_unlocked(idx: int) -> bool:
        return frontier_floor > idx * 10


func _draw() -> void:
        var w := size.x
        var h := size.y
        if w < 300.0 or h < 300.0:
                return

        # Тёмная подложка (контрол самодостаточен по фону)
        draw_rect(Rect2(0, 0, w, h), Color(0.027, 0.022, 0.014))

        # Водяной знак БАШНЯ
        draw_string(BunkerUI.font_title(), Vector2(w * 0.5 - 560, h * 0.40), "БАШНЯ",
                HORIZONTAL_ALIGNMENT_CENTER, 1120, 210, Color(1.0, 0.7, 0.24, 0.04))

        # Световой луч из верхнего центра (над выбранной стелой)
        _draw_beam(Vector2(w * 0.5, 0.0), minf(w * 0.34, 420.0), h * 0.30)

        _slots.clear()
        _slot_tiers.clear()
        # Три стелы: окно из трёх ярусов, зажатое в 0..9 (выбранный в центре)
        var idxs: Array = []
        if selected_tier == 0:
                idxs = [0, 1, 2]
        elif selected_tier == 9:
                idxs = [7, 8, 9]
        else:
                idxs = [selected_tier - 1, selected_tier, selected_tier + 1]

        var slab_w: float = minf(500.0, w / 3.3)
        var gap: float = (w - float(idxs.size()) * slab_w) / float(idxs.size() + 1)
        var base_y: float = h - 78.0
        # Упругий кивок окна при свайпе/упоре в край (затухает в _process)
        var slide: float = _nudge_dir * sin(_nudge * PI) * 16.0

        var centers: Array = []
        for k in range(idxs.size()):
                var gx: float = gap + float(k) * (slab_w + gap)
                # Слот БЕЗ сдвига — хит-тест клика стабильный; визуально кивает
                _slots.append(Rect2(gx, base_y - h * 0.66, slab_w, h * 0.66))
                _slot_tiers.append(int(idxs[k]))
                centers.append(Vector2(gx + slab_w * 0.5 + slide, base_y))
                _draw_slab(Rect2(gx + slide, base_y - h * 0.66, slab_w, h * 0.66), int(idxs[k]), base_y)

        # Энергосвязь между основаниями стел
        for c in range(centers.size() - 1):
                _draw_energy(centers[c], centers[c + 1])

        # Восходящие пылинки (поверх всего, в пределах зоны стел)
        var zone := Rect2(0, h * 0.16, w, h * 0.84)
        for d in _dust:
                var px: float = zone.position.x + (d["x"] as float) * zone.size.x
                var py: float = zone.position.y + (d["y"] as float) * zone.size.y
                var tw: float = 0.45 + 0.55 * absf(sin(_t * 2.0 + (d["ph"] as float)))
                draw_circle(Vector2(px, py), 1.6, Color(COL_GOLD, 0.20 * tw))


func _draw_beam(pos: Vector2, width: float, height: float) -> void:
        """Мягкий световой конус из верхнего центра (над выбранной стелой)."""
        for i in range(4):
                var k: float = 1.0 - float(i) * 0.22
                draw_set_transform(pos + Vector2(0, -10.0), 0.0, Vector2(1.0 + i * 0.45, 0.34 + i * 0.05))
                draw_circle(Vector2(0, height * 0.5), width * 0.5, Color(COL_GOLD, 0.028 * k))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_slab(rect: Rect2, tier_idx: int, base_y: float) -> void:
        var cx: float = rect.get_center().x
        var is_sel: bool = tier_idx == selected_tier
        var unlocked: bool = _tier_unlocked(tier_idx)
        var glow: float = 0.6 + 0.4 * sin(_t * 2.2)

        var slab_w: float = rect.size.x * 0.74
        var slab_h: float = rect.size.y * 0.52
        var slab_top: float = base_y - 96.0 - slab_h
        var slab := Rect2(cx - slab_w * 0.5, slab_top, slab_w, slab_h)

        # ----- Пол: отражение и свечение под стелой -----
        draw_set_transform(Vector2(cx, base_y - 4.0), 0.0, Vector2(1.0, 0.22))
        if unlocked and is_sel:
                draw_circle(Vector2(0, 0), slab_w * 0.62, Color(COL_GOLD, 0.10 + 0.05 * glow))
        else:
                draw_circle(Vector2(0, 0), slab_w * 0.5, Color(0.35, 0.42, 0.28, 0.06))
        draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

        # ----- Плита -----
        var body := StyleBoxFlat.new()
        body.bg_color = COL_SLAB_TOP if not (unlocked and is_sel) else COL_SLAB_TOP.lightened(0.05)
        body.set_corner_radius_all(8)
        body.border_width_bottom = 0
        if unlocked and is_sel:
                body.border_width_left = 2
                body.border_width_right = 2
                body.border_width_top = 2
                body.border_color = COL_GOLD
                body.shadow_color = Color(COL_GOLD, 0.22)
                body.shadow_size = 22
        else:
                body.border_width_left = 1
                body.border_width_right = 1
                body.border_width_top = 1
                body.border_color = COL_SLAB_EDGE
        draw_style_box(body, slab)

        # Сканлайны на плите
        var scan_y: float = slab.position.y + 6.0
        while scan_y < slab.end.y - 4.0:
                draw_line(Vector2(slab.position.x + 5, scan_y), Vector2(slab.end.x - 5, scan_y), COL_SCAN, 1.0)
                scan_y += 5.0

        # ----- Сигил (руна яруса) в центре плиты -----
        var sigil_col: Color
        if is_sel and unlocked:
                sigil_col = Color(COL_GOLD, 0.85 + 0.15 * glow)
        elif unlocked:
                sigil_col = Color("7a8465")
        else:
                sigil_col = Color("39412f")
        _draw_sigil(Vector2(cx, slab.get_center().y - 6.0), tier_idx, sigil_col, slab_w * 0.16)

        # ----- Полоса звёзд внизу плиты -----
        var stars: int = int(tier_stars[tier_idx]) if tier_idx < tier_stars.size() else 0
        var bar := Rect2(cx - slab_w * 0.34, slab.end.y - 22.0, slab_w * 0.68, 4.0)
        draw_rect(bar, Color("1a1f14"))
        var frac: float = clampf(float(stars) / 30.0, 0.0, 1.0)
        if frac > 0.0:
                var fill := Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y))
                draw_rect(fill, COL_GOLD if is_sel else Color("8a9a6d"))
                if is_sel:
                        draw_circle(Vector2(bar.position.x + bar.size.x * frac, bar.get_center().y),
                                4.0, Color(COL_GOLD_HI, 0.8))

        # ----- Рунное кольцо над стелой -----
        var ring_c := Vector2(cx, slab_top - 44.0)
        var ring_r: float = 26.0
        var ring_col := COL_GOLD if (is_sel and unlocked) else (COL_RING if unlocked else Color("424a38"))
        var segs := 12
        for i in range(segs):
                var a0: float = float(i) * TAU / segs
                if is_sel:
                        a0 += _t * 1.1          # кольцо выбранной стелы вращается
                draw_arc(ring_c, ring_r, a0, a0 + TAU / segs * 0.55, 6, ring_col, 2.0)
        var num: String = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"][tier_idx]
        draw_string(BunkerUI.font_title(), Vector2(ring_c.x - ring_r, ring_c.y + 8),
                num, HORIZONTAL_ALIGNMENT_CENTER, ring_r * 2.0, 16,
                COL_GOLD_HI if (is_sel and unlocked) else (COL_NAME if unlocked else COL_FAINT))

        # ----- Символы награды над плитой (Hades-стиль: что внутри до клика) -----
        var boss: String = str(tier_bosses[tier_idx]) if tier_idx < tier_bosses.size() else "—"
        var chip_y: float = ring_c.y - ring_r - 34.0 - 27.0 * 3.0
        var chips := [
                "★ ×%d /30" % (stars if unlocked else 0),
                boss,
                "этажи %d–%d" % [tier_idx * 10 + 1, tier_idx * 10 + 10],
        ]
        var chip_w: float = slab_w * 0.86
        for ci in range(chips.size()):
                var crect := Rect2(cx - chip_w * 0.5, chip_y, chip_w, 24.0)
                draw_rect(crect, COL_PLATE)
                draw_rect(crect, COL_PLATE_EDGE, false, 1.0)
                draw_string(BunkerUI.font_mono(), crect.position + Vector2(0, 16), chips[ci],
                        HORIZONTAL_ALIGNMENT_CENTER, chip_w, 12,
                        COL_GOLD_HI if (ci == 0 and is_sel and unlocked) else COL_SUB)
                chip_y += 27.0

        # ----- Имя и статус под стелой -----
        var tname: String = str(tier_names[tier_idx]) if tier_idx < tier_names.size() else ""
        var title := "ЯРУС %d · «%s»" % [tier_idx + 1, tname] if is_sel else "ЯРУС %d · %s" % [tier_idx + 1, tname]
        draw_string(BunkerUI.font_title(), Vector2(cx - slab_w, base_y - 44.0), title,
                HORIZONTAL_ALIGNMENT_CENTER, slab_w * 2.0, 18,
                COL_NAME_ON if is_sel else COL_NAME)
        var status: String
        var status_col: Color
        if is_sel:
                status = "ВЫБРАНО · ЭТАЖ %d" % (tier_idx * 10 + 1)
                status_col = COL_GOLD
        elif unlocked:
                status = "ОТКРЫТ"
                status_col = COL_FAINT
        else:
                status = "ЗАПЕРТО · ЭТАЖ %d" % (tier_idx * 10 + 1)
                status_col = COL_FAINT
        draw_string(BunkerUI.font_mono(), Vector2(cx - slab_w, base_y - 22.0), status,
                HORIZONTAL_ALIGNMENT_CENTER, slab_w * 2.0, 12, status_col)


func _draw_sigil(c: Vector2, tier_idx: int, col: Color, r: float) -> void:
        """Руна яруса: детерминированный узор из лучей и дуг."""
        var rays := 3 + (tier_idx % 5)
        draw_arc(c, r, 0, TAU, 40, Color(col, 0.5), 1.5)
        for i in range(rays):
                var a: float = TAU * float(i) / float(rays) + float(tier_idx) * 0.7
                var p0: Vector2 = c + Vector2(cos(a), sin(a)) * r * 0.34
                var p1: Vector2 = c + Vector2(cos(a), sin(a)) * r * 0.92
                draw_line(p0, p1, col, 2.0)
                draw_circle(p1, 2.4, col)
        draw_circle(c, r * 0.16, col)


func _draw_energy(a: Vector2, b: Vector2) -> void:
        """Энергосвязь между основаниями стел: тусклая линия + бегущие искры."""
        draw_line(a, b, Color(COL_GOLD, 0.10), 2.0)
        var n := 5
        for i in range(n):
                var ph: float = fmod(_t * 0.35 + float(i) / float(n), 1.0)
                var p: Vector2 = a.lerp(b, ph)
                draw_circle(p, 2.0, Color(COL_GOLD, 0.35 * (1.0 - absf(ph - 0.5) * 1.2)))
