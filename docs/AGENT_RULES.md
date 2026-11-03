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
- **Окружение сборки на ОСНОВНОЙ машине (поднято 03.11.2026, «AGENTS.md:
  Godot CLI недоступен» — УСТАРЕЛО):** Godot 4.6.1 =
  `D:\StalkerRevert\Tools\Godot\Godot_v4.6.1-stable_win64_console.exe`
  (та же сборка 14d19694e, что у VB); шаблоны экспорта 4.6.1.stable —
  установлены (android_release.apk докачан RANGE-чанками из tpz GitHub,
  скрипт-прототип в Temp — метод: центральный каталог zip + curl -r,
  полный tpz 1.25 ГБ не нужен); JDK 21 = `F:\Android Studio\jbr`
  (JetBrains, gradle его уже знает); Android SDK =
  `%LOCALAPPDATA%\Android\Sdk` (build-tools 36/37, platforms 35/36.1);
  gradle wrapper проекта хочет 8.11.1 — скачает сам при первом прогоне.
- **Keystore проекта** восстановлен из git-истории (`git show
  29de7ba:keystore/debug.keystore`, вычищен из индекса в 365451b, но
  ОСТАВАЛСЯ на диске): SHA-256 7ce7ddb1... = подпись всех публичных АПК
  (README в «От ВебПомогатора/BUNKER_ZONA_v0.31.1_APK.zip»). Лежит в
  `keystore/debug.keystore` проекта И на `E:...\keystore\` (куда смотрят
  пресеты). Ключ читается ТОЛЬКО JDK 17+ (JDK 11 падает HmacPBESHA256).
- **Грабля Godot 4.6** (из КОМАНДА_01 веб-помогатора, zip «От
  ВебПомогатора», падали трижды): свежий editor_settings-4.6.tres
  создаёт СВОЙ debug-ключ (CN=Godot) и ПУСТОЙ java_sdk_path → чужая
  подпись или «A valid Java SDK path is required». Уже исправлено в
  `%APPDATA%\Godot\editor_settings-4.6.tres` (java=F:/Android Studio/jbr,
  sdk, keystore=проектный, androiddebugkey/android). После ЛЮБОЙ
  регенерации настроек — проверять эти поля.

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

- **ЗАПРЕЩЁН taskkill по ИМЕНИ процесса** (`taskkill //IM Godot...`) —
  игра и редактор владельца запускаются тем же exe: один такой kill
  вырубил владельцу игру посреди забора наград и редактор (инцидент
  03.11.2026). ТОЛЬКО: `inbox/fx_test/run_test.sh <тест>.tscn [сек]
  [лог]` — тест сам зовёт quit + --quit-after 3000 как страховка +
  kill строго по PID запущенного процесса.
- Тест-сцена в `inbox/fx_test/test_<имя>.tscn` (+gd extends Node):
  await 1с (автозагрузки встают) → инстанс цели → действие → print
  маркеров → quit. Вывод ТОЛЬКО в файл (пайп буферизуется).
- ПРОВЕРКА ВИДИМОСТИ UI обязательна: тесты ребят печатали OPEN_OK
  после open(), а окно было 0×0 и скрыто (инцидент ивентов). Канон:
  after open() — assert visible == true и size.x > 1000.
- gm-тесты СЕЙВОВ: подменять current_save_data на fresh SaveData и
  бэкапить/восстанавливать файлы слотов вокруг прогона (тест
  подхватывает загрузившийся сейв владельца и save_to_active_slot
  перезапишет его — инцидент с химерой 4★). Тест здоровья сейва —
  через gm._load_encrypted (сейвы зашифрованы с П0, голый load()
  вернёт null и это НЕ corruption).
- Эталонные тесты: test_event_hub (state() на живом SaveData + open),
  test_lab_event (живая лаба: кнопка найдена → обработчик → хаб
  visible), test_chimera (клипы + процедурник заглушен).
- Логи владельца: `%APPDATA%/Godot/app_userdata/Бункер- Зона/logs/`
  (пробел вместо двоеточия!) и сейвы `saves/save_N.tres` — читать
  ПЕРВЫМ делом при «сломано».

## 6. РЕЛИЗНЫЕ ХВОСТЫ (актуально на 03.11.2026)

- **Гейт D25 СНЯТ (03.11.2026): test_mail ПРОЙДЕН** (MAIL_TEST_PASS на
  живом движке: rollover/нет пинг-понга/забор письма/титул финала).
  Попутно тест поймал out-of-bounds календаря D24 (SCHEDULE[неделя
  13–25] ронял все ивенты во второй половине полугодия, включая финал)
  — починено: индекс = слот/2 (13 ивентов по 2 недели, как в дизайне).
- Не встроено: Хранитель в бой (42, модель в inbox/_done/keeper_model —
  zone_controller замаран WIP D25), П0-фиксы security_audit
  (EMULATE_PURCHASES → OS.is_debug_build() + FORCE_EMULATE ручка),
  D26 онбординг (спека архитектора в DESIGN_COMMANDS.md; D25 ежедневки
  СНЯТА — задачи Зоны v2 + месячный тир в игре), гекс-рамки профиля
  (помощник ждёт «делай» от владельца), RU-локаль динамических подписей
  арены, main.svg — мёртв (удалить только по явному разрешению).
- Live-ops D24: все 6 игр + финал встроены, спека в design_inbox/_done.
- Вторая машина готовит v0.33.0 (VERSION/VERSIONING/checklist в дереве).
- Сейв-миграция: пользовательские сейвы в
  `%APPDATA%/Godot/app_userdata/Бункер- Зona/saves/save_N.tres`.
