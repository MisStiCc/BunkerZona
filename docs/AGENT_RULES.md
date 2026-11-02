# ПРАВИЛА И ПРОТОКОЛЫ АГЕНТА (выработано сессиями 27.10–02.11.2026)

Прочитай ПЕРВЫМ после загрузки проекта. Это дополнение к AGENTS.md —
концентрат граблей и протоколов, оплаченных реальными поломками.
Носители контекста: STATUS.md (статус/очередь), FEATURES.md (как
устроено), COMMANDS.md (очередь помощнику-ассетчику), DESIGN_COMMANDS.md
(очередь архитектору-дизайнеру), docs/ (спеки).

## 1. ПРОТОКОЛ СБОРКИ (критично: дерево общее с ТРЕМЯ машинами)

Дерево проекта НИКОГДА не бывает чистым — вторая машина пишет по живому.
Билд «в лоб» запекает их недописанный код (дважды уезжало в релизы
сломанным: main_menu `_menu_plates`, lab_controller `ArenaSeason`).

```
git stash push -u -m "WIP machines"
godot --headless --path . --import            # если были новые ассеты
# --check-only ключевых скриптов (см. §2)
godot --headless --path . --export-release "Windows Desktop" ../Relese/BunkerZona_v0.32.0-dev.exe
godot --headless --path . --export-release "Android" ../Relese/BunkerZona_v0.32.0-dev.apk
grep лог экспорта на "SCRIPT ERROR" и "Невозможно переименовать"
git stash pop                                  # вернуть WIP машинам
python: zipfile перекатать exe в bunker-zona-pc-v0.32.0-dev.zip
```
- «Невозможно переименовать .tmp» = exe запущен у владельца. Не ретрайть
  вечно — сообщи, пересоберёшь после закрытия.
- Godot: `C:\Users\VB\Desktop\Godot_v4.6.1-stable_win64.exe`.
- GitHub Releases НЕ обновлять без явной команды («залей в Releases»).
- git push — только по явной команде.

## 2. ПАРС-ГЕЙТ (перед каждым экспортом и после каждого патча кода)

```
godot --headless --path . --check-only --script <файл>.gd
```
- Ложные срабатывания (НЕ ошибки): `Identifier not found: Signals/Loc`
  (check-only не грузит автозагрузки); UNUSED_*.
- Настоящие: `Parse Error`, `Expected ...`, `Invalid argument ... should
  be "Node" but is "X"` = почти всегда ДУБЛЬ class_name.
- Экспорт завершается «DONE» даже с битыми скриптами — не верь статусу,
  верь grep'у лога.
- Новые class_name резолвятся только после `--import` (кэш классов).

## 3. ЖЕЛЕЗНЫЕ ПРАВИЛА GDScript (продуктовые поломки)

- `class_name` ГЛОБАЛЕН. Перед созданием файла — grep имени. Священные
  имена: `EventManager` = боевой менеджер Выбросов
  (managers/event_manager.gd); liveops-статика = `EventOps`
  (core/event_manager.gd). Дубль EventManager положил весь забег.
- Сейв — **Resource** (SaveData, @export-поля), НЕ словарь:
  `save.get(KEY)` (1 аргумент!) + проверка `es_val is Dictionary`;
  `save.set(KEY, val)` — можно. Паттерн статик-хелперов — GuildSys.
- Кортежей НЕТ: `(a, b)` — синтаксическая ошибка, пиши `[a, b]`.
- Булевы `True/False` с большой буквы — из python-патчей; в GDScript
  только `true/false`. После python-мультипатчей grep'нуть.
- `:=` не выводит тип из `load(...).new()` и из элементов нетипизированных
  Array — типизируй явно (`var x: Node = ...`).
- `wrap` — встроенная функция (Callable): локальную переменную так не
  звать. `ready` тоже тень.
- Мультипатч падает на assert В СЕРЕДИНЕ = до падения применено, после
  нет. После каждого патча — grep-верификация КАЖДОЙ замены по диску.
- Edit в CRLF-файле может склеить строки (func X(): var y) — после
  правок парс-гейт обязателен.
- Новые вкладки/кнопки, добавляемые кодом в HUD-панели, СРАЗУ исключать
  из сеточных циклов `_rescale_battle_panels`/`_touch_layout_panel` и
  позиционировать явно.
- В UI-цифрах ЗАПРЕЩЕНЫ тильды/значки перед числом («~17» читают как
  «-17» — трижды наступали).
- `Loc.t(key) != key` — приём «есть ли ключ»; динамические ключи
  (prefix + id) сверять скриптом со списком ключей localization.gd.

## 4. КОМАНДНЫЙ КОНВЕЙЕР (3 машины)

- Основной агент (я): код, интеграция, билды, пуш.
- Помощник: ассеты по COMMANDS.md → кладёт в `inbox/<задание>/` c
  README+CREDITS. Blender 4.5 headless освоен (процедурные модели
  boss_kit-фреймворком, клипы именами из base_mutant._match_clip:
  idle/walk/attack/death; химера/боссы ОХОТЫ — эталон). Проверка
  deliveries: README/CREDITS/размеры/визуальный монтаж PIL-сеткой +
  Read; потребителя ассета искать по ФИНАЛЬНОМУ пути (assets/ui/...),
  не по имени inbox-папки.
- Архитектор: спеки по DESIGN_COMMANDS.md → `design_inbox/<имя>/`.
  Код он НЕ пишет; аудиты-документы трогают только документы.
- Вторая машина: пишет код НАПРЯМУЮ в дерево без коммитов. Перед
  своими правками перечитывать файлы; их WIP не коммитить без метки,
  перед сборкой — stash (§1). Пометка `> БЛОК:` в файлах команд —
  разобраться и помочь разблокировать.
- После встраивания поставки: перенос в `inbox/_done/` (или
  design_inbox/_done/), STATUS.md+FEATURES.md, коммит сразу.

## 5. HEADLESS-ТЕСТЫ (без запуска игры руками)

- Тест-сцена в `inbox/fx_test/test_<имя>.tscn` (+gd extends Node):
  await 1с (автозагрузки встают) → инстанс цели → действие → print
  маркеров → quit. Запуск: `godot --headless --path .
  res://inbox/fx_test/test_X.tscn > файл 2>&1 &` + `sleep N` +
  `taskkill //IM Godot... //F`. Вывод ТОЛЬКО в файл (пайп буферизуется).
- Эталонные тесты: test_event_hub (state() на живом SaveData + open),
  test_lab_event (живая лаба: кнопка найдена → обработчик → хаб
  visible), test_chimera (клипы + процедурник заглушен).
- Логи владельца: `%APPDATA%/Godot/app_userdata/Бункер- Зона/logs/`
  (пробел вместо двоеточия!) и сейвы `saves/save_N.tres` — читать
  ПЕРВЫМ делом при «сломано».

## 6. РЕЛИЗНЫЕ ХВОСТЫ (актуально на 02.11.2026)

- Не встроено: Хранитель в бой (42, модель в inbox/_done/keeper_model —
  zone_controller замаран WIP D25), интеграция 5 liveops-игр после ЖАТВЫ
  (спека liveops_events), П0-фиксы security_audit (EMULATE_PURCHASES →
  OS.is_debug_build() + FORCE_EMULATE ручка), D25 ежедневки/D26 онбординг
  (спеки архитектора в DESIGN_COMMANDS.md), гекс-рамки профиля
  (помощник ждёт «делай» от владельца), RU-локаль динамических подписей
  арены, main.svg — мёртв (удалить только по явному разрешению).
- Вторая машина готовит v0.33.0 (VERSION/VERSIONING/checklist в дереве).
- Сейв-миграция: пользовательские сейвы в
  `%APPDATA%/Godot/app_userdata/Бункер- Зona/saves/save_N.tres`.
