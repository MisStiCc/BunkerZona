# Обучение первого забега (онбординг) — спецификация

Статус: спека под встраивание. Опора: `ui/hud/hud.gd` (имена узлов),
`ui/lab/lab_controller.gd` (панели кодом, start_run_button, GachaButton),
`core/signals.gd` (шира событий — триггеры), `zones/zone_controller.gd`
(фаза подготовки, СТАРТ), `ui/panels/result_panel.gd` (итоги),
`data/save_data.gd` (слоты). Все тайминги — «ручки» в блоке констант §6.

---

## 1. Суть и принципы

Обучение живёт **внутри первого забега кампании** (кольцо 1: 3 волны по 8–9
новичков, статы ×1.0 — забег безопасен для экспериментов) и в лаборатории
до/после него. Никакой отдельной карты, никакого отдельного режима: узел
«наставник» вешается поверх реальной игры и ведёт по шагам.

Принципы:

- **Одно действие за раз.** Подсветили одну кнопку, ждём одно событие.
  Дальше — следующий шаг. Никаких простыней текста.
- **Игра не блокируется.** Пауза НЕ ставится; затемнение вокруг подсветки
  не ловит ввод (кроме плашки). Требующий действия шаг, который игнорируют,
  через таймаут сворачивается в мини-плашку в углу — игра идёт своим
  чередом, обучение продолжится по триггеру следующего шага.
- **Триггеры, не таймеры.** Шаг завершается событием (сигнал) либо кнопкой
  «Дальше» на информационных шагах. Всё слушается через глобальную шину
  `Signals` — игровая логика не меняется вовсе (кроме спавна узла).
- **Одноразовость и повтор.** Флаг в сейве; повтор — кнопкой в настройках.
  Автозапуск только «чистому» новичку: `tutorial_done == false` И
  `statistics.total_runs == 0` И `campaign_level <= 1`. Старый сейв без
  флага, но с наигранными забегами обучение не дёргает.
- **Мобильность.** Плашки — в нижней трети экрана (зона большого пальца,
  по образцу primary-кнопок лаборатории), шрифт крупный, тап = «Дальше»
  на информационных шагах.
- **Всё кодом.** Оверлей строится скриптом (образец star_panel/tower_panel),
  тексты — `Loc.t`, подсветка — по путям узлов HUD/лаборатории.

## 2. Носитель: узел-наставник и состояние

**`ui/tutorial/tutorial.gd`** (class Tutorial, extends CanvasLayer,
layer = `TUTORIAL_LAYER` 20 — над HUD и церемонией башни). Создаётся
контроллером сцены, если обучение активно:

- лаборатория: `lab_controller._ready()` — при `TutorialData.is_active(save)`
  создаёт узел (шаги A и D);
- забег: `zone_controller` в конце `_setup()` — при `run_params.get(
  "tutorial", false)` (шаги B/V/G).

Узел слушает `Signals` (подписки по таблице шагов), рисует затемнение и
плашки, ведёт указатель текущего шага. Состояние — в SaveData:

```gdscript
# data/save_data.gd (новые поля; @export - сериализация ресурса)
@export var tutorial_done: bool = false
@export var tutorial_step: String = ""      # id текущего шага ("" = начало)
@export var tutorial_passive: Dictionary = {}  # ключи показанных пассивных
```

`tutorial_step` пишется при каждом продвижении (без записи сейва — попадёт
в ближайший автосейв; если игрок вышел посреди — продолжим с того же шага).

**Кнопка «Повторить обучение»** — в настройки лаборатории (рядом со слотом):
сбрасывает три поля, подсказка «начните кольцо 1».

## 3. Подсветка (механика «фонарика»)

Без шейдеров — 4 ColorRect (сверху/снизу/слева/справа от прямоугольника
узла), альфа `DIM_ALPHA`, `mouse_filter = IGNORE` — ввод проходит СКВОЗЬ
затемнение к игре. Вокруг узла — рамка `HIGHLIGHT_COLOR` с пульсом
(масштаб/альфа по синусу, `HIGHLIGHT_PULSE_TIME`). Плашка текста —
PanelContainer + Label + (на требующих действия шагах) кнопка «СКОРО».

- Прямоугольник узла: `node.get_global_rect()`; узел скрыт/панель закрыта —
  шаг ждёт (таймаут не тратится — отсчёт только когда цель видима).
- Кнопки, созданные кодом (например `GachaButton`), ищутся по имени после
  постройки панелей (`get_node_or_null` + `call_deferred`).
- Точка «перед камерой» для аномалий НЕ подсвечивается на 3D-сцене — текст
  объясняет, куда встанет аномалия; кольцо 1 маленькое, Монолит в центре
  миникарты — её и подсвечиваем.

## 4. Сценарий шагов

Формат таблицы: **триггер появления → завершение → подсветка**. Полная
таблица с таймингами — в константах §6; здесь — смысл и тексты.

### Этап A — лаборатория (до первого забега)

| # | id | Триггер | Завершение | Подсветка | Суть текста |
|---|---|---|---|---|---|
| A1 | `lab_welcome` | вход в лабораторию (обучение активно) | кнопка «Дальше» | — | «Ты — Зона. Сталкеры идут к Монолиту за артефактами. Не пускай их. Готовь оборону, растить её — в лаборатории между забегами» |
| A2 | `lab_biomass` | после A1 | кнопка | инфострока биомассы | «Биомасса — валюта Зоны. В бою на мутантов, здесь — на улучшения. Первый забег всё расскажет сам» |
| A3 | `lab_start` | после A2 | нажата кнопка забега | `start_run_button` | «Первое кольцо — 3 волны новичков. Поехали» |

### Этап B — фаза подготовки (сцена забега, до СТАРТ)

| # | id | Триггер | Завершение | Подсветка | Суть |
|---|---|---|---|---|---|
| B1 | `run_welcome` | вход в сцену забега | 6 с / тап | `AnomalyPanel` | «До старта волны — время строить. Аномалии — твоя артиллерия, мутанты — пехота» |
| B2 | `first_anomaly` | после B1 | `Signals.anomaly_created` | `AnomalyPanel/FireButton` | «Выбери "Жарку": она встанет точкой перед камерой. На телефоне — сначала кнопка, потом тап по земле» |
| B3 | `first_mutant` | после B2 | `Signals.mutant_spawned` | `MutantPanel/DogButton` | «Пёс стоит 30 биомассы и патрулирует. Мутанты гибнут — половина стоимости вернётся» |
| B4 | `why_before` | после B3 | кнопка | — | «Строй ДО волны: в бою энергия копится медленно, а биомасса, потраченная под давлением, — потрачена впустую» |
| B5 | `press_start` | после B4 | `Signals.wave_started(1)` | `StartPanel/StartRunButton` | «Готов? Пускай волну» |

### Этап В — волна 1 (только информационные шаги)

| # | id | Триггер | Завершение | Подсветка | Суть |
|---|---|---|---|---|---|
| V1 | `wave_look` | `wave_started(1)` | 8 с | `Minimap` | «Новички идут к Монолиту. Красные точки на миникарте — они. Касание Монолита = поражение» |
| V2 | `first_kill` | первый `Signals.stalker_died` | 6 с | `Resources/BiomassValue` | «Убил — получил: за каждого сталкера Зоне возвращается биомасса (сейчас: +N)». N — `biomass_returned` из сигнала |
| V3 | `first_theft` | первый `Signals.stalker_picked_up_artifact`; не случился — показать на `wave_ended(1)` | 6 с | — | «Поднял артефакт — унесёт, получишь минус биомассы. Артефакты — приманка: держи защиту вокруг, а Монолит — неприкосновенен» |

### Этап Г — между волнами

| # | id | Триггер | Завершение | Подсветка | Суть |
|---|---|---|---|---|---|
| G1 | `rest` | `wave_ended(1)` | 8 с | `Resources/EnergyValue` | «Передышка. Энергия капает сама — это топливо аномалий. Дозакладывайся» |
| G2 | `pulse` | `wave_ended(2)` | 8 с | `EmissionPanel/EmissionButton` | «Копи 1000 энергии — и ВЫБРОС сотрёт всех сталкеров разом. В этом кольце не успеешь — но знай козырь» (в кольце 1 выброс недостижим: реген 1/с — честно говорим «про запас») |
| G3 | `win_cond` | `wave_started(3)` | 8 с | — | «Последняя волна. Победа — все волны отбиты или 3 выброса. Поражение — одно касание Монолита» |

### Этап Д — итоги и гача (возврат в лабораторию)

| # | id | Триггер | Завершение | Подсветка | Суть |
|---|---|---|---|---|---|
| D1 | `results` | возврат в лабораторию, панель итогов видима | 8 с / закрытие панели | `ResultPanel` (награда) | «Итоги: боевой доход + бонус кольца. Биомасса осталась в лаборатории» |
| D2 | `gacha` | итоги закрыты | открыта панель гачи / 60 с | `GachaButton` | «За кольцо дали крутки. Крутани — новый мутант в коллекцию, дубль — копия на ферму» |
| D3 | `done` | после D2 | кнопка «Готово» | — | «Обучение закончено. Дальше — Зона сама. ☢» → `tutorial_done = true`, сейв |

Итого полный прогон ≈ 3–4 минуты поверх забега, который и так занимает
5–8 минут. Ни один шаг не длиннее 8 секунд, требующие действия — до 90 с
с мягким отпуском.

## 5. Пассивные подсказки («а если прошёл мимо всего»)

Разовые срабатывания по факту, работают в ЛЮБОМ забеге, пока ключ не стоит
в `tutorial_passive`. Формат — мини-плашка у нижней кромки (как
`show_reward_note` в HUD), 4 с, ввод не ловит.

| Ключ | Триггер | Текст |
|---|---|---|
| `theft_loss` | первый `Signals.stalker_picked_up_artifact` при неактивном обучении | «Артефакт уносят: когда сталкер сбежит с ним — минус биомассы. Погоня мутантом дешевле потери» |
| `energy_full` | первый `energy_changed(current ≥ 1000)` | «Энергия полна: ВЫБРОС сотрёт волну. Кнопка справа» |
| `critical_bio` | первый `critical_biomass_reached` | уже есть системное предупреждение — НЕ дублируем (ключа нет) |

Критическая биомасса и так предупреждает сама; первая волна после
`tutorial_done` — тоже без подсказок (не спамим).

## 6. Константы — `data/tutorial_data.gd` (готовый блок)

```gdscript
# data/tutorial_data.gd
extends RefCounted
class_name TutorialData

## Онбординг первого забега: шаги, тайминги, таймауты.
## Исполнитель - ui/tutorial/tutorial.gd (оверлей-наставник кодом).

# ==================== ВИЗУАЛ ====================
const TUTORIAL_LAYER: int = 20          # над HUD (1) и церемонией (10)
const DIM_ALPHA: float = 0.55           # затемнение вокруг подсветки
const HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.2)
const HIGHLIGHT_WIDTH: float = 3.0      # рамка, px
const HIGHLIGHT_PULSE_TIME: float = 0.8 # период пульса рамки, с
const NOTE_FONT_SIZE: int = 20
const NOTE_MIN_TIME: float = 4.0        # инфо-плашка висит минимум
const NOTE_MAX_TIME: float = 8.0        # ...и сама уходит (если шаг инфо)
const MINI_NOTE_TIME: float = 4.0       # мини-плашка пассивных подсказок

# ==================== ПОВЕДЕНИЕ ====================
const STEP_TIMEOUT_ACTION: float = 90.0   # ждали действие (аномалия/мутант/старт) - отпускаем
const STEP_TIMEOUT_SOFT: float = 12.0     # инфо-шаги с кнопкой
const SKIP_CONFIRM: bool = false          # «СКОРО» - сразу, без подтверждения
# Перебор: обучение назойливое -> STEP_TIMEOUT_ACTION 60 и NOTE_MAX_TIME 6;
# игроки не дочитывают -> наоборот, NOTE_MIN_TIME 5, шрифт 22.

# ==================== ШАГИ ====================
# id -> {trigger, done, highlight, timeout}
#   trigger: сигнал шины Signals / "после <id>" / "lab_enter" / "run_enter"
#   done: сигнал / "button" (кнопка «Дальше») / сек (просто подержать)
#   highlight: путь узла от владельца сцены (HUD или лаборатория), "" = нет
const STEPS := [
	# --- Лаборатория ---
	{"id": "lab_welcome", "trigger": "lab_enter", "done": "button",
		"highlight": "", "text": "tutorial.lab_welcome"},
	{"id": "lab_biomass", "trigger": "после lab_welcome", "done": "button",
		"highlight": "VBox/InfoPanel/HBox/BiomassLabel", "text": "tutorial.lab_biomass"},
	{"id": "lab_start", "trigger": "после lab_biomass", "done": "start_pressed",
		"highlight": "StartRunButton", "timeout": STEP_TIMEOUT_ACTION,
		"text": "tutorial.lab_start"},
	# --- Фаза подготовки ---
	{"id": "run_welcome", "trigger": "run_enter", "done": NOTE_MAX_TIME,
		"highlight": "AnomalyPanel", "text": "tutorial.run_welcome"},
	{"id": "first_anomaly", "trigger": "после run_welcome", "done": "anomaly_created",
		"highlight": "AnomalyPanel/FireButton", "timeout": STEP_TIMEOUT_ACTION,
		"text": "tutorial.first_anomaly"},
	{"id": "first_mutant", "trigger": "после first_anomaly", "done": "mutant_spawned",
		"highlight": "MutantPanel/DogButton", "timeout": STEP_TIMEOUT_ACTION,
		"text": "tutorial.first_mutant"},
	{"id": "why_before", "trigger": "после first_mutant", "done": "button",
		"highlight": "", "text": "tutorial.why_before"},
	{"id": "press_start", "trigger": "после why_before", "done": "wave_started",
		"highlight": "StartPanel/StartRunButton", "timeout": STEP_TIMEOUT_ACTION,
		"text": "tutorial.press_start"},
	# --- Волна 1 ---
	{"id": "wave_look", "trigger": "wave_started", "done": 8.0,
		"highlight": "Minimap", "text": "tutorial.wave_look"},
	{"id": "first_kill", "trigger": "stalker_died", "done": 6.0,
		"highlight": "Resources/BiomassValue", "text": "tutorial.first_kill"},
	{"id": "first_theft", "trigger": "stalker_picked_up_artifact|wave_ended",
		"done": 6.0, "highlight": "", "text": "tutorial.first_theft"},
	# --- Между волнами ---
	{"id": "rest", "trigger": "wave_ended", "done": 8.0,
		"highlight": "Resources/EnergyValue", "text": "tutorial.rest"},
	{"id": "pulse", "trigger": "wave_ended_2", "done": 8.0,
		"highlight": "EmissionPanel/EmissionButton", "text": "tutorial.pulse"},
	{"id": "win_cond", "trigger": "wave_3", "done": 8.0,
		"highlight": "", "text": "tutorial.win_cond"},
	# --- Итоги ---
	{"id": "results", "trigger": "lab_enter_after_run", "done": 8.0,
		"highlight": "ResultPanel", "text": "tutorial.results"},
	{"id": "gacha", "trigger": "после results", "done": "gacha_opened",
		"highlight": "GachaButton", "timeout": 60.0, "text": "tutorial.gacha"},
	{"id": "done", "trigger": "после gacha", "done": "button",
		"highlight": "", "text": "tutorial.done"},
]

## Обучение активно: не завершено, игрок свежий, кольцо доступно
static func is_active(save_data, stats) -> bool:
	if save_data == null or stats == null:
		return false
	return (not save_data.tutorial_done) and stats.total_runs == 0 \
		and save_data.campaign_level <= 1
```

(Пути подсветки сверить по сценам: HUD-узлы — из `ui/hud/hud.gd` @onready;
лаборатория — `VBox/InfoPanel/HBox/BiomassLabel` по образцу `_apply_static_texts`;
`StartRunButton`/`GachaButton` — имена кнопок, созданных сценой/кодом.
Триггеры `wave_ended_2`/`wave_3` — это `wave_ended(2)`/`wave_started(3)`
с фильтром по номеру волны.)

## 7. Тексты Loc (`core/localization.gd`, ru/en)

```gdscript
"tutorial.lab_welcome": {"ru": "Ты — Зона. Сталкеры идут к Монолиту за артефактами — не пускай их. Оборону ставят в бою, а растят её здесь, в лаборатории", "en": "You are the Zone. Stalkers head for the Monolith to loot artifacts - keep them out. Defenses are built in battle and grown here in the lab"},
"tutorial.lab_biomass": {"ru": "Биомасса — валюта Зоны: в бою на мутантов, здесь на улучшения", "en": "Biomass is the Zone's currency: mutants in battle, upgrades here"},
"tutorial.lab_start": {"ru": "Первое кольцо — 3 волны новичков. Начинаем?", "en": "First ring - 3 waves of novices. Shall we?"},
"tutorial.run_welcome": {"ru": "До старта волны — время строить: аномалии это артиллерия, мутанты — пехота", "en": "Before the wave starts - build: anomalies are artillery, mutants are infantry"},
"tutorial.first_anomaly": {"ru": "Выбери «Жарку»: встанет точкой перед камерой. На телефоне — кнопка, потом тап по земле", "en": "Pick the 'Burner': it appears at a point in front of the camera. On phone - button, then tap the ground"},
"tutorial.first_mutant": {"ru": "Пёс за 30 биомассы патрулирует и дерётся. Погибнет — половина стоимости вернётся", "en": "A dog for 30 biomass patrols and fights. If it dies - half the cost returns"},
"tutorial.why_before": {"ru": "Строй до волны: в бою энергия копится медленно", "en": "Build before the wave: energy regenerates slowly in battle"},
"tutorial.press_start": {"ru": "Готов? Пускай волну", "en": "Ready? Start the wave"},
"tutorial.wave_look": {"ru": "Красные точки на миникарте — сталкеры. Касание Монолита = поражение", "en": "Red dots on the minimap are stalkers. Touching the Monolith = defeat"},
"tutorial.first_kill": {"ru": "Убил — получил: +{n} биомассы за сталкера", "en": "Kill and collect: +{n} biomass per stalker"},
"tutorial.first_theft": {"ru": "Поднял артефакт — унесёт: это минус биомассы. Держи защиту вокруг приманки", "en": "Once picked up, it will be carried away: that's minus biomass. Guard the bait"},
"tutorial.rest": {"ru": "Передышка: энергия капает сама — это топливо аномалий", "en": "Break time: energy regenerates - it fuels anomalies"},
"tutorial.pulse": {"ru": "1000 энергии = ВЫБРОС: стирает всех сталкеров. Здесь не успеешь — копи к следующему кольцу", "en": "1000 energy = EMISSION: wipes all stalkers. Won't make it here - save up for the next ring"},
"tutorial.win_cond": {"ru": "Последняя волна! Победа — отбить все волны или 3 выброса", "en": "Final wave! Win - repel all waves or 3 emissions"},
"tutorial.results": {"ru": "Итоги: боевой доход + бонус кольца. Всё в лабораторию", "en": "Results: combat income + ring bonus. All into the lab"},
"tutorial.gacha": {"ru": "За кольцо дали крутки: новый мутант — в коллекцию, дубль — копия на ферму", "en": "The ring paid in rolls: a new mutant joins the collection, a dupe becomes a farm copy"},
"tutorial.done": {"ru": "Обучение закончено. Дальше Зона расскажет всё сама ☢", "en": "Tutorial complete. The Zone will tell you the rest ☢"},
"tutorial.next": {"ru": "Дальше", "en": "Next"},
"tutorial.skip": {"ru": "СКОРО", "en": "SKIP"},
"tutorial.finish": {"ru": "Готово", "en": "Done"},
"tutorial.passive_theft": {"ru": "Артефакт уносят: сбежит с ним — минус биомассы", "en": "They're taking an artifact: if it escapes - minus biomass"},
"tutorial.passive_pulse": {"ru": "Энергия полна: ВЫБРОС сотрёт волну — кнопка справа", "en": "Energy full: EMISSION will wipe the wave - button on the right"},
"tutorial.restart": {"ru": "Повторить обучение (начните кольцо 1)", "en": "Restart tutorial (start ring 1)"},
```

## 8. Точки встраивания

| Что | Где | Правка |
|---|---|---|
| Константы/шаги | `data/tutorial_data.gd` | новый файл, блок §6 |
| Оверлей-наставник | `ui/tutorial/tutorial.gd` | новый файл: слушает Signals, рисует фонарик/плашки |
| Поля сейва | `data/save_data.gd` | +3 `@export` (§2) |
| Запуск в лаборатории | `ui/lab/lab_controller.gd` `_ready()` | `TutorialData.is_active(...)` → создать узел; шаги D по возврату из забега |
| Запуск в забеге | `zones/zone_controller.gd` `_setup()` | при первом забеге создать узел (критерий: `total_runs == 0` / флаг из run_params) |
| Кнопка повтора | настройки лаборатории | сброс трёх полей сейва |
| Локализация | `core/localization.gd` | ключи §7 |
| **Попутный фикс** | `core/signals.gd` | объявить `signal artifact_stolen(artifact, stalker, loss)` — сейчас эмитится в `zone_controller.gd:831` без объявления (ошибка в рантайме на каждой краже) |

Игровая логика (спавн, волны, экономика) не меняется — только слушатели.

## 9. Риски и краевые случаи

- **Таймауты не тратятся вслепую:** если цель подсветки невидима (панель
  закрыта), отсчёт таймаута стоит. Актуально для `GachaButton` (панели
  лаборатории строятся при входе).
- **Смена сцены посреди шага:** узел-наставник умирает со сценой;
  `tutorial_step` в сейве → следующая сцена продолжит с того же места.
  Шаги «внутри забега» при выходе в меню просто перепокажутся по триггеру.
- **Поражение в обучающем забеге:** шаги В/Г пропускаются, этап Д
  (итоги/гача) всё равно играет — поражение в кольце 1 нормально и
  обучает. `tutorial_done` ставится только по `done`-шагу, но после Д2
  независимо от исхода.
- **Повтор обучения на развитом аккаунте:** кольцо 1 перепроходимо всегда
  (реплей), шаги те же; пассивные ключи сбрасываются — подсказки снова
  разовые.
- **Мобилка:** тап по плашке = «Дальше»; плашки не перекрывают нижние
  панели HUD (ставим выше MutantPanel); фонарик на маленьких экранах —
  рамка + текст под ней, не сбоку.
- **Производительность:** 4 ColorRect + Label + один Timer; подписки на
  шину только у активного узла.
- **Не спорить с церемонией башни (D1):** слои разные (тутор 20 выше
  церемонии 10) — но они не встречаются: обучение — кампания кольцо 1.

## 10. Чек-лист приёмки

1. Чистый слот: в лаборатории сразу A1→A3, кнопка забега подсвечена,
   забег стартует только по нажатию игрока.
2. B2: после выбора «Жарки» шаг гаснет при появлении аномалии; если у
   игрока не хватило энергии — текст живёт, таймаут 90 с отпускает.
3. B3 закрывается спавном любого мутанта (не только пса).
4. B5: волна стартует → V1 с миникартой; V2 показывает реальную цифру
   `+{n}` из сигнала `stalker_died`.
5. V3 играет и на «поднял артефакт», и (если не случилось) после волны 1.
6. G2 честно говорит, что выброс в кольце 1 не собрать.
7. Поражение в кольце 1: итоги → D1/D2/D3 играют, `tutorial_done = true`.
8. «СКОРО» гасит всё в один клик, обучение больше не появляется; пассивные
   подсказки после скипа работают (первая кража, первая полная энергия).
9. Выход посреди B2: перезапуск — шаг продолжается, не с начала.
10. Второй слот со старым сейвом (total_runs > 0): автозапуска нет;
    «Повторить обучение» из настроек запускает с A1.
11. Русский/английский переключаются на лету (Loc.changed).
12. На телефоне плашки в нижней трети, тап работает, панели HUD не перекрыты.
