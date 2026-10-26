# ui/hud/hud_mobile.gd
extends RefCounted
class_name HudMobile

## Тач-адаптация HUD забега (спека D8, design_inbox/mobile_ux).
## Десктоп эти ручки не читает (только _touch_mode).

# Размерная сетка (виртуальные px при базе 1080; scale на телефоне ~1).
# Подушка пальца 8-9 мм на 400-420 dpi = 126-142 px: кнопка 72 + slop 18
# делает промах редким.
const BTN_W: int = 112             # кнопка вида; тесно в категории -> 104
const BTN_H: int = 72              # минимум по пальцу
const TAB_H: int = 64              # таб категории
const BIG_H: int = 88              # СТАРТ/ВЫБРОС
const CONFIRM_W: int = 146         # ✓/✗ подтверждения постановки
const CONFIRM_H: int = 96
const PANEL_W: int = 588           # развёрнутая панель (5 кнопок в ряду)

# Сворачивание в бою
const IDLE_COLLAPSE: float = 6.0   # сек без постановок -> панель в док; 4.0 - агрессивно

# Призрак-превью постановки
const GHOST_RING_ANOMALY: float = 2.5   # радиус кольца, м
const GHOST_RING_MUTANT: float = 1.5
const GHOST_CONFIRM_BY_TAP: bool = true # тап по своему призраку = поставить

# Пороги тапа (читает game_camera)
const TOUCH_SLOP: float = 18.0     # px: меньше - тап, больше - пан
const TAP_MAX_TIME: float = 0.42   # сек: дольше - это пан

# Safe-area
const SAFE_AREA_APPLY: bool = true # false - игнорировать вырезы (отладка)

# Последние категории аккордеона: помнятся между забегами (в рамках сессии)
static var last_anomaly_cat: String = "heat"
static var last_mutant_cat: String = "squad"
