extends Node

## Локализация RU/EN. Все надписи UI берутся через Loc.t("ключ").
## Язык хранится в user://settings.cfg [ui] lang, переключение - кнопкой
## или Loc.set_lang()/toggle(); сигнал changed переприменяет тексты.

signal changed

var lang: String = "ru"

const LANGS := ["ru", "en"]

# Ключ -> перевод. {имя} подставляется словарём аргументов.
const STRINGS := {
	# ==== Главное меню ====
	"menu.title": {"ru": "S.T.A.L.K.E.R. REVERT", "en": "S.T.A.L.K.E.R. REVERT"},
	"menu.subtitle": {"ru": "Ты - Зона. Останови сталкеров.", "en": "You are the Zone. Stop the stalkers."},
	"menu.new_game": {"ru": "НОВАЯ ИГРА", "en": "NEW GAME"},
	"menu.continue": {"ru": "ПРОДОЛЖИТЬ", "en": "CONTINUE"},
	"menu.load": {"ru": "ЗАГРУЗИТЬ", "en": "LOAD"},
	"menu.settings": {"ru": "НАСТРОЙКИ", "en": "SETTINGS"},
	"menu.back": {"ru": "НАЗАД", "en": "BACK"},
	"menu.quit": {"ru": "ВЫХОД", "en": "QUIT"},
	"menu.language": {"ru": "ЯЗЫК: РУССКИЙ", "en": "LANGUAGE: ENGLISH"},
	"menu.music": {"ru": "Музыка", "en": "Music"},
	"menu.sound": {"ru": "Звук", "en": "Sound"},
	"menu.empty_slot": {"ru": "СЛОТ {n} | ПУСТО", "en": "SLOT {n} | EMPTY"},
	"menu.slot_delete": {"ru": "УДАЛИТЬ", "en": "DELETE"},
	"menu.slot_info": {"ru": "СЛОТ {n} | Забег #{run} | Биомасса: {bio} | Побед: {wins}", "en": "SLOT {n} | Run #{run} | Biomass: {bio} | Wins: {wins}"},

	# ==== Лаборатория ====
	"lab.title": {"ru": "ЛАБОРАТОРНЫЙ КОМПЛЕКС", "en": "LABORATORY COMPLEX"},
	"lab.info_header": {"ru": "ИНФОРМАЦИЯ О ЗАБЕГЕ", "en": "RUN INFORMATION"},
	"lab.biomass_prefix": {"ru": "Биомасса: ", "en": "Biomass: "},
	"lab.start_run": {"ru": "НАЧАТЬ НОВЫЙ ЗАБЕГ", "en": "START NEW RUN"},
	"lab.day": {"ru": "День {n}", "en": "Day {n}"},
	"lab.anomalies": {"ru": "АНОМАЛИИ", "en": "ANOMALIES"},
	"lab.mutants": {"ru": "МУТАНТЫ", "en": "MUTANTS"},
	"lab.monolith": {"ru": "МОНОЛИТ", "en": "MONOLITH"},
	"lab.menu": {"ru": "ГЛАВНОЕ МЕНЮ", "en": "MAIN MENU"},
	"lab.settings": {"ru": "НАСТРОЙКИ", "en": "SETTINGS"},
	"lab.shop": {"ru": "МАГАЗИН", "en": "SHOP"},
	"lab.farm": {"ru": "ФЕРМА", "en": "FARM"},
	"lab.gallery": {"ru": "ГАЛЕРЕЯ", "en": "GALLERY"},
	"lab.save": {"ru": "СОХРАНИТЬ", "en": "SAVE"},
	"lab.storage": {"ru": "ХРАНИЛИЩЕ АРТЕФАКТОВ", "en": "ARTIFACT STORAGE"},
	"lab.storage_open": {"ru": "ОТКРЫТЬ ХРАНИЛИЩЕ", "en": "OPEN STORAGE"},
	"lab.back": {"ru": "НАЗАД", "en": "BACK"},
	"lab.result_title": {"ru": "ИТОГИ ЗАБЕГА", "en": "RUN RESULTS"},
	"lab.result_reward": {"ru": "Получено биомассы: {n}", "en": "Biomass earned: {n}"},
	"lab.result_continue": {"ru": "ПРОДОЛЖИТЬ", "en": "CONTINUE"},
	"lab.settings_music": {"ru": "Музыка", "en": "Music"},
	"lab.settings_sfx": {"ru": "Звуки", "en": "Sounds"},
	"lab.storage_counts": {"ru": "Common: {c}   Rare: {r}   Legendary: {l}", "en": "Common: {c}   Rare: {r}   Legendary: {l}"},
	"lab.stats": {"ru": "Всего забегов: {runs}   Побед: {wins}   Поражений: {loss}\nСталкеров убито: {kills}   Артефактов украдено: {stolen}\nРекорд выживания: {waves} волн", "en": "Total runs: {runs}   Wins: {wins}   Losses: {loss}\nStalkers killed: {kills}   Artifacts stolen: {stolen}\nSurvival record: {waves} waves"},
	"lab.campaign": {"ru": "Кампания", "en": "Campaign"},
	"lab.survival": {"ru": "Выживание", "en": "Survival"},
	"lab.level_of": {"ru": "Уровень {cur}/100 - {title}", "en": "Level {cur}/100 - {title}"},
	"lab.caravan_of": {"ru": "КАРАВАН {cur}/100: «{title}»", "en": "CARAVAN {cur}/100: \"{title}\""},
	"lab.completed": {"ru": " (пройден)", "en": " (completed)"},
	"lab.campaign_done": {"ru": "КАМПАНИЯ ПРОЙДЕНА! Финальный уровень: 100/100", "en": "CAMPAIGN COMPLETE! Final level: 100/100"},
	"lab.survival_line": {"ru": "ВЫЖИВАНИЕ - волны без предела, награда за каждую (рекорд: {rec})", "en": "SURVIVAL - endless waves, reward for each (record: {rec})"},
	"lab.level_short": {"ru": "Ур.{n}", "en": "Lv.{n}"},
	"lab.difficulty": {"ru": "Сложность: {mode}", "en": "Difficulty: {mode}"},
	"lab.saved_msg": {"ru": "Игра сохранена", "en": "Game saved"},
	"lab.upgrade_bought": {"ru": "Улучшение приобретено!", "en": "Upgrade purchased!"},
	"lab.artifact_exchanged": {"ru": "Артефакт обменян", "en": "Artifact exchanged"},

	# ==== Магазин ====
	"shop.title": {"ru": "МАГАЗИН ЗОНЫ - припасы для забега", "en": "ZONE SHOP - supplies for the run"},
	"shop.biomass": {"ru": "Биомасса лаборатории: {n}", "en": "Lab biomass: {n}"},
	"shop.mutants_header": {"ru": "МУТАНТЫ (вступят в бой в начале забега)", "en": "MUTANTS (join the fight at run start)"},
	"shop.artifacts_header": {"ru": "АРТЕФАКТЫ (приманка у монолита в забеге)", "en": "ARTIFACTS (bait at the Monolith in the run)"},
	"shop.locked": {"ru": "🔒 уровень {n}", "en": "🔒 level {n}"},
	"shop.not_enough": {"ru": "Недостаточно биомассы в лаборатории", "en": "Not enough lab biomass"},
	"shop.stars": {"ru": "★ ЗВЁЗДЫ", "en": "★ STARS"},

	# ==== Звёзды ====
	"stars.title": {"ru": "ПРОКАЧКА ЗВЁЗД - дубли гачи дают звезду, звёзды дают статы", "en": "STAR UPGRADES - gacha dupes grant stars, stars grant stats"},
	"stars.biomass_line": {"ru": "Биомасса лаборатории: {n}   (цена звезды: 500 → 1000 → 2000 → 4000)", "en": "Lab biomass: {n}   (star cost: 500 → 1000 → 2000 → 4000)"},
	"stars.mutants_header": {"ru": "МУТАНТЫ (+20% HP и урона за звезду)", "en": "MUTANTS (+20% HP and damage per star)"},
	"stars.artifacts_header": {"ru": "АРТЕФАКТЫ (+20% награды за звезду)", "en": "ARTIFACTS (+20% reward per star)"},
	"stars.artifacts_only": {"ru": "Артефактов пока нет - выигрывайте их в аномалийной гаче\nи за серьёзные достижения (30-й уровень, 30 волн).\nМутанты качаются на ФЕРМЕ: копии x звезда + корм той же звёздности.", "en": "No artifacts yet - win them in the anomaly gacha\nand for major milestones (level 30, wave 30).\nMutants are upgraded at the FARM: copies x star + same-star fodder."},
	"stars.max": {"ru": "МАКС", "en": "MAX"},
	"stars.mult_tip": {"ru": "Множитель статов: x{n}", "en": "Stat multiplier: x{n}"},
	"stars.empty": {"ru": "Коллекция пуста.\nВыигрывайте мутантов и артефакты в гаче и за вехи волн:\nдубликат уже имеющегося даёт +1 звезду автоматически.", "en": "Collection is empty.\nWin mutants and artifacts from gacha and wave milestones:\na duplicate grants +1 star automatically."},
	"stars.fail_msg": {"ru": "Недостаточно биомассы или звёзды максимальны", "en": "Not enough biomass or stars are maxed"},

	# ==== Ферма ====
	"farm.title": {"ru": "ФЕРМА МУТАНТОВ - копии и корм для звёзд", "en": "MUTANT FARM - copies and fodder for stars"},
	"farm.copies": {"ru": "копий: {n}", "en": "copies: {n}"},
	"farm.no_copies": {"ru": "копий нет", "en": "no copies"},
	"farm.star_btn": {"ru": "+★", "en": "+★"},
	"farm.feed_btn": {"ru": "🍽 кормить", "en": "🍽 feed"},
	"farm.pick_target": {"ru": "Кого кормим? Корм: {fodder} (+{points} очков)", "en": "Feed whom? Fodder: {fodder} (+{points} points)"},
	"farm.progress": {"ru": "прогресс {cur}/{need}", "en": "progress {cur}/{need}"},
	"farm.empty": {"ru": "На ферме нет копий.\nДубликаты из гачи и вех отправляются сюда:\nкопия того же типа = +1★, копии других типов = корм.", "en": "No copies on the farm.\nGacha and milestone duplicates come here:\nsame-type copy = +1★, other-type copies = fodder."},
	"farm.value_tip": {"ru": "Ценность корма: {points} очков", "en": "Fodder value: {points} points"},

	# ==== HUD ====
	"hud.energy": {"ru": "⚡ Энергия:", "en": "⚡ Energy:"},
	"hud.biomass": {"ru": "🧬 Биомасса:", "en": "🧬 Biomass:"},
	"hud.wave": {"ru": "🌊 Волна: {n}", "en": "🌊 Wave: {n}"},
	"hud.stalkers": {"ru": "👥 Сталкеров: {n}", "en": "👥 Stalkers: {n}"},
	"hud.emission": {"ru": "🔥 ВЫБРОС ⚡1000", "en": "🔥 EMISSION ⚡1000"},
	"hud.start": {"ru": "▶ СТАРТ", "en": "▶ START"},
	"hud.anomalies": {"ru": "АНОМАЛИИ", "en": "ANOMALIES"},
	"hud.mutants": {"ru": "МУТАНТЫ", "en": "MUTANTS"},
	"hud.locked_tip": {"ru": "Не разблокирован: откройте кампанией или гачей", "en": "Locked: unlock via campaign or gacha"},
	"hud.break_line": {"ru": "⏳ Пауза {sec}с - волна {n}", "en": "⏳ Break {sec}s - wave {n}"},
	"hud.emission_note": {"ru": "ВЫБРОС! Все сталкеры на поле погибнут, аномалии перемешаются", "en": "EMISSION! All stalkers on the field will die, anomalies reshuffle"},
	"hud.no_energy": {"ru": "Нужно 1000 энергии (полная шкала)!", "en": "1000 energy needed (full bar)!"},
	"hud.emission_running": {"ru": "Выброс уже идёт!", "en": "Emission already running!"},
	"hud.emission_active": {"ru": "⚠️ ВЫБРОС! ⚠️", "en": "⚠️ EMISSION! ⚠️"},
	"hud.break_countdown": {"ru": "⏳ Волна {cur}/{max} через {sec}с", "en": "⏳ Wave {cur}/{max} in {sec}s"},
	"hud.wave_announce": {"ru": "🌊 ВОЛНА {cur}/{max}", "en": "🌊 WAVE {cur}/{max}"},
	"hud.anomaly_locked": {"ru": "Аномалия закрыта - нужен артефакт: {artifact}", "en": "Anomaly locked - artifact needed: {artifact}"},
	"hud.anomaly_locked_tip": {"ru": "Получи артефакт: {artifact}", "en": "Obtain the artifact: {artifact}"},
	"hud.reward_note": {"ru": "🎁 НАГРАДА: {text}", "en": "🎁 REWARD: {text}"},
	"reward.anomaly_rolls": {"ru": "Аномалийные крутки: +{n}", "en": "Anomaly rolls: +{n}"},
	"hud.anomaly_rolls_note": {"ru": "🌀 +{n} аномалийных круток!", "en": "🌀 +{n} anomaly rolls!"},
	"farm.recipe": {"ru": "Рецепт звезды: копии x новая звезда + корм + корм той же звёздности", "en": "Star recipe: copies x new star + fodder + same-star fodder"},
	"farm.copies_need": {"ru": "копий {have}/{need}", "en": "copies {have}/{need}"},
	"farm.points_need": {"ru": "корм {have}/{need}", "en": "fodder {have}/{need}"},
	"farm.upgrade_btn": {"ru": "↑ до {n}★", "en": "↑ to {n}★"},
	"farm.fodder_star_rule": {"ru": "Кого кормим? Корм: {fodder} (+{points}) - только с {stars}★", "en": "Feed whom? Fodder: {fodder} (+{points}) - {stars}★ only"},
	"farm.no_matching_fodder": {"ru": "Нет корма с {n}★ - сначала прокачайте звёзды другим мутантам", "en": "No {n}★ fodder - upgrade other mutants' stars first"},
	"farm.need_copies": {"ru": "Нужно копий: {have}/{need}", "en": "Need copies: {have}/{need}"},
	"farm.need_points": {"ru": "Нужно корма: {have}/{need}", "en": "Need fodder: {have}/{need}"},
	"farm.target_max": {"ru": "Звёзды уже максимальны", "en": "Stars already maxed"},
	"reward.gacha_rolls": {"ru": "Крутки гачи: +{n}", "en": "Gacha rolls: +{n}"},
	"hud.rolls_note": {"ru": "🎟 +{n} круток гачи", "en": "🎟 +{n} gacha rolls"},
	"reward.gacha_mutant": {"ru": "Мутант: {name}", "en": "Mutant: {name}"},
	"reward.gacha_artifact": {"ru": "Артефакт: {name}", "en": "Artifact: {name}"},
	"gacha.title": {"ru": "ГАЧА ЗОНЫ - два рукава удачи", "en": "ZONE GACHA - two arms of luck"},
	"gacha.rolls": {"ru": "Круток: {n}", "en": "Rolls: {n}"},
	"gacha.mutants_header": {"ru": "МУТАНТЫ (новый - в коллекцию, дубль - копия на ферму)", "en": "MUTANTS (new - to collection, dup - farm copy)"},
	"gacha.artifacts_header": {"ru": "АРТЕФАКТЫ (новый - в коллекцию, дубль - +1 звезда)", "en": "ARTIFACTS (new - to collection, dup - +1 star)"},
	"gacha.level_used": {"ru": "Шансы по уровню кампании: {n}", "en": "Odds by campaign level: {n}"},
	"gacha.stats": {"ru": "{n} круток | обычные {cp}% | необычные {up}% | редкие {rp}% | легендарки {lp}%", "en": "{n} rolls | common {cp}% | uncommon {up}% | rare {rp}% | legendary {lp}%"},
	"gacha.stats_short": {"ru": "{n} круток | обычные {cp}% | редкие {rp}% | легендарки {lp}%", "en": "{n} rolls | common {cp}% | rare {rp}% | legendary {lp}%"},
	"gacha.last_drops": {"ru": "Последние дропы:", "en": "Latest drops:"},
	"gacha.no_rolls": {"ru": "Крутки закончились!", "en": "Out of rolls!"},
	"rarity.common": {"ru": "обычный", "en": "common"},
	"rarity.uncommon": {"ru": "необычный", "en": "uncommon"},
	"rarity.rare": {"ru": "РЕДКИЙ", "en": "RARE"},
	"rarity.legendary": {"ru": "ЛЕГЕНДАРНЫЙ", "en": "LEGENDARY"},
	"gacha.new_mark": {"ru": "НОВЫЙ!", "en": "NEW!"},
	"gacha.dup_mark": {"ru": "копия", "en": "copy"},
	"gacha.star_mark": {"ru": "+1★", "en": "+1★"},
	"gallery.title": {"ru": "ГАЛЕРЕЯ ЗОНЫ - открытые светятся, закрытые ждут", "en": "ZONE GALLERY - unlocked shine, locked wait"},
	"gallery.locked_tip": {"ru": "Не открыто: уровень кампании {n} или гача", "en": "Locked: campaign level {n} or gacha"},
	"gallery.unlocked_tip": {"ru": "Открыто", "en": "Unlocked"},
	"desc.zombie": {"ru": "Бывший сталкер, переваренный Зоной. Медлителен и почти не чувствует боли. Дёшев и страшен толпой.", "en": "A former stalker digested by the Zone. Slow and nearly painless. Cheap and terrifying in numbers."},
	"desc.dog_mutant": {"ru": "Псы Зоны сбиваются в стаи и не знают страха. Быстрые, злые, расходный материал.", "en": "Zone dogs pack up and know no fear. Fast, vicious, expendable."},
	"desc.flesh": {"ru": "Живой ком плоти, рождённый аномалиями. Медленный таран, который просто не остановить.", "en": "A living lump of flesh born from anomalies. A slow ram that simply won't stop."},
	"desc.snork_mutant": {"ru": "В противогазе из другого времени. Прыгает на сталкеров издалека и рвёт всё, что дышит.", "en": "Wearing a gas mask from another era. Leaps at stalkers from afar and tears into anything that breathes."},
	"desc.pseudodog": {"ru": "Искажает реальность вокруг: клевки из ниоткуда, иллюзорные фантомы, ложные следы.", "en": "Bends reality around itself: bites from nowhere, illusory phantoms, false trails."},
	"desc.poltergeist": {"ru": "Сгусток аномальной энергии без тела. Швыряет предметы и растворяется в воздухе.", "en": "A bodiless clot of anomaly energy. Hurls objects and dissolves into thin air."},
	"desc.controller_mutant": {"ru": "Мозг, ставший хищником. Подминает разум сталкеров и выжигает их изнутри.", "en": "A brain turned predator. Dominates stalkers' minds and burns them from within."},
	"desc.bloodsucker": {"ru": "Полупрозрачный охотник со щупальцами вместо лица. Невидим до последнего шага.", "en": "A translucent hunter with tentacles for a face. Invisible until the final step."},
	"desc.pseudogiant": {"ru": "Гора мышц и ярости. Топот сносит целые отряды - стены не спасают.", "en": "A mountain of muscle and fury. Its stomp flattens whole squads - walls won't save you."},
	"desc.chimera": {"ru": "Кошмар Зоны. Быстрее пули на коротких дистанциях, прыгает на жертв без разбега.", "en": "The Zone's nightmare. Faster than a bullet at close range, leaps at prey without a run-up."},
	"desc.common_artifact": {"ru": "Безымянный камень с Зоны. Аномалию не открывает, но всегда можно обменять на припасы.", "en": "A nameless stone from the Zone. Opens no anomaly, but can always be traded for supplies."},
	"desc.battery_artifact": {"ru": "Портативная батарея, заряженная аномалией во время выброса.", "en": "A portable battery charged by an anomaly during the emission."},
	"desc.glowstick_artifact": {"ru": "Мягкое зелёное сияние, не дающее тени.", "en": "A soft green glow that casts no shadow."},
	"desc.slime_artifact": {"ru": "Сгусток живой слизи: тёплый, шевелится в руках.", "en": "A clot of living slime: warm, it stirs in your hands."},
	"desc.spark_artifact": {"ru": "Застывшая искра молнии. Жужжит, если поднести к металлу.", "en": "A frozen spark of lightning. Buzzes when brought near metal."},
	"desc.gas_bottle_artifact": {"ru": "Баллон с чем-то шипучим. Не открывайте.", "en": "A canister of something hissing. Do not open."},
	"desc.rare_artifact": {"ru": "Редкий кристалл чистой аномальной энергии. Высоко ценится коллекционерами.", "en": "A rare crystal of pure anomaly energy. Prized by collectors."},
	"desc.energy_artifact": {"ru": "Сгусток чистой силы. Кажется, что он тяжелее, чем выглядит.", "en": "A clot of pure power. It feels heavier than it looks."},
	"desc.clock_artifact": {"ru": "Время в кармане: стрелки идут вспять рядом с аномалиями.", "en": "Time in your pocket: the hands run backwards near anomalies."},
	"desc.hourglass_artifact": {"ru": "Песок в них течёт сам по себе - и никогда вниз.", "en": "Its sand flows by itself - and never downward."},
	"desc.graviton_artifact": {"ru": "Кусок искривлённого пространства. Свет вокруг него врёт.", "en": "A shard of bent space. Light lies around it."},
	"desc.fireball_artifact": {"ru": "Вечное пламя в кристалле. Не обжигает хозяина - пока он спокоен.", "en": "Eternal flame in a crystal. It won't burn its owner - as long as they stay calm."},
	"desc.jumper_artifact": {"ru": "Пружина без опоры, которая прыгает сама.", "en": "A spring with no support that jumps by itself."},
	"desc.flesh_artifact": {"ru": "Янтарь с косточкой внутри. Кость иногда стучит.", "en": "Amber with a bone inside. The bone sometimes knocks."},
	"desc.void_artifact": {"ru": "Кусочек пустоты между мирами. Смотреть дольше трёх секунд не рекомендуется.", "en": "A piece of the void between worlds. Looking for over three seconds is not advised."},
	"desc.heart_artifact": {"ru": "Сердце Озера - легенда Зоны. Тепло бьётся в ладони.", "en": "The Heart of the Lake - a Zone legend. It beats warmly in your palm."},
	"desc.storm_artifact": {"ru": "Гроза, пойманная в капкан. Гремит, когда злится.", "en": "A thunderstorm caught in a trap. It thunders when angry."},
	"desc.uranium_artifact": {"ru": "Тёплый на ощупь. Не спрашивайте, откуда он.", "en": "Warm to the touch. Don't ask where it came from."},
	"card.opens_anomaly": {"ru": "Открывает аномалию: {n}", "en": "Unlocks anomaly: {n}"},
	"card.locked": {"ru": "Ещё не добыт - кампания или гача", "en": "Not yet obtained - campaign or gacha"},
	"card.rarity": {"ru": "Редкость: {r}", "en": "Rarity: {r}"},
	"farm.star_feed": {"ru": "звёздный корм {have}/{need}", "en": "star feed {have}/{need}"},
	"farm.simple_feed": {"ru": "простой корм {have}/{need}", "en": "simple feed {have}/{need}"},
	"farm.star_feed_mark": {"ru": "звёздный", "en": "star"},
	"farm.simple_feed_mark": {"ru": "простой", "en": "simple"},
	"farm.feed_hint": {"ru": "Кого кормим? Корм той же звёздности идёт в звёздный бак, остальное в простой", "en": "Feed whom? Same-star fodder fills the star bucket, rest fills the simple one"},
	"up.title": {"ru": "ПОВЫШЕНИЕ: {name} -> {n}★", "en": "UPGRADE: {name} -> {n}★"},
	"up.copies_slot": {"ru": "Копии цели: {have}/{need}", "en": "Target copies: {have}/{need}"},
	"up.star_slot": {"ru": "Звёздный корм ({n}★): ", "en": "Star feed ({n}★): "},
	"up.star_filled": {"ru": "уже заполнен", "en": "already filled"},
	"up.simple_slot": {"ru": "Простой корм: {have}/{need}", "en": "Simple feed: {have}/{need}"},
	"up.pick_star": {"ru": "Звёздный корм - мутант с {n}★:", "en": "Star feed - a {n}★ mutant:"},
	"up.pick_simple": {"ru": "Выберите корм и количество:", "en": "Pick fodder and quantity:"},
	"up.ok": {"ru": "★ ПОВЫСИТЬ", "en": "★ UPGRADE"},
	"up.copies_btn": {"ru": "+{n}", "en": "+{n}"},
	"up.reset": {"ru": "СБРОС", "en": "RESET"},
	"up.not_ready": {"ru": "Заполните все слоты", "en": "Fill all slots first"},
	"up.qty_max": {"ru": "МАКС", "en": "MAX"},
	"up.done_mark": {"ru": "готово", "en": "done"},
	"up.self_mark": {"ru": "(цель)", "en": "(target)"},
	"farm.recycle_btn": {"ru": "♻ УТИЛИЗАЦИЯ КОПИЙ", "en": "♻ RECYCLE COPIES"},
	"farm.recycle_title": {"ru": "Утилизация: очки по редкости (1/2/3/5), 10 очков = 1 крутка артефактов", "en": "Recycle: points by rarity (1/2/3/5), 10 points = 1 artifact roll"},
	"farm.recycle_progress": {"ru": "Сдано: {points}/10 очков ({consumed} копий) | в запасе: {left}", "en": "Given: {points}/10 points ({consumed} copies) | stored: {left}"},
	"farm.recycle_confirm": {"ru": "ОБМЕНЯТЬ НА {n} КРУТКИ", "en": "EXCHANGE FOR {n} ROLLS"},
	"farm.recycle_nothing": {"ru": "Нечего сдавать - на ферме нет копий", "en": "Nothing to recycle - no copies on the farm"},
	"farm.recycle_done": {"ru": "Утилизация: +{n} круток артефактов за {c} копий", "en": "Recycled: +{n} artifact rolls for {c} copies"},
	"farm.recycle_zero": {"ru": "Мало очков - сдавайте ещё", "en": "Not enough points - recycle more"},
	"up.auto": {"ru": "АВТО - собрать из слабых и многочисленных", "en": "AUTO - gather from weak and plentiful"},
	"result.artifacts": {"ru": "Собрано артефактов:", "en": "Artifacts collected:"},
	"result.gacha_header": {"ru": "НАГРАДЫ ЗАБЕГА:", "en": "RUN REWARDS:"},
	"hud.event_incoming": {"ru": "⚠ СОБЫТИЕ: {title}", "en": "⚠ EVENT: {title}"},
	"hud.event_desc": {"ru": "{desc} - враг сильнее, награда щедрее!", "en": "{desc} - tougher enemies, richer rewards!"},

	# ==== Аномалии (кнопки HUD) ====
	"an.heat": {"ru": "Жарка", "en": "Burner"},
	"an.electric": {"ru": "Электра", "en": "Electra"},
	"an.acid": {"ru": "Кислота", "en": "Acid"},
	"an.vortex": {"ru": "Воронка", "en": "Vortex"},
	"an.lift": {"ru": "Лифт", "en": "Lift"},
	"an.whirlwind": {"ru": "Карусель", "en": "Carousel"},
	"an.steam": {"ru": "Пар", "en": "Steam"},
	"an.comet": {"ru": "Комета", "en": "Comet"},
	"an.jelly": {"ru": "Холодец", "en": "Jelly"},
	"an.gas": {"ru": "Газировка", "en": "Soda"},
	"an.acid_cloud": {"ru": "Кисель", "en": "Acid cloud"},
	"an.radiation": {"ru": "Радиация", "en": "Radiation"},
	"an.time": {"ru": "Время", "en": "Time"},
	"an.teleport": {"ru": "Телепорт", "en": "Teleport"},
	"an.tesla": {"ru": "Тесла", "en": "Tesla"},
	"an.fluff": {"ru": "Жг.пух", "en": "Burn fluff"},

	# ==== Мутанты (кнопки HUD) ====
	"mu.dog": {"ru": "Собака", "en": "Dog"},
	"mu.flesh": {"ru": "Плоть", "en": "Flesh"},
	"mu.snork": {"ru": "Снорк", "en": "Snork"},
	"mu.pseudodog": {"ru": "Псевдопёс", "en": "Pseudo-dog"},
	"mu.controller": {"ru": "Контролёр", "en": "Controller"},
	"mu.poltergeist": {"ru": "Полтергейст", "en": "Poltergeist"},
	"mu.bloodsucker": {"ru": "Кровосос", "en": "Bloodsucker"},
	"mu.pseudogiant": {"ru": "Псевдогигант", "en": "Pseudo-giant"},
	"mu.chimera": {"ru": "Химера", "en": "Chimera"},
	"mu.zombie": {"ru": "Зомби", "en": "Zombie"},

	# ==== Итоги забега ====
	"result.victory": {"ru": "ПОБЕДА", "en": "VICTORY"},
	"result.defeat": {"ru": "ПОРАЖЕНИЕ", "en": "DEFEAT"},
	"result.to_lab": {"ru": "В ЛАБОРАТОРИЮ", "en": "TO THE LAB"},

	# ==== Церемония башни (ui/hud/ceremony_overlay.gd) ====
	"tower_ceremony.cleared": {"ru": "ЭТАЖ ПРОЙДЕН", "en": "FLOOR CLEARED"},
	"tower_ceremony.floor_up": {"ru": "ЭТАЖ {n}: ПОДЪЁМ", "en": "FLOOR {n}: ASCEND"},
	"tower_ceremony.next_floor": {"ru": "ЭТАЖ {n}", "en": "FLOOR {n}"},
	"tower_ceremony.tier_up": {"ru": "ЯРУС: {name}", "en": "TIER: {name}"},
	"tower_ceremony.break_tag": {"ru": "ПРОРЫВ — награда ×1.5", "en": "BREAKTHROUGH — reward ×1.5"},
	"tower_ceremony.keeper_down": {"ru": "ХРАНИТЕЛЬ ПОВЕРЖЕН: {name}", "en": "KEEPER SLAIN: {name}"},
	"tower_ceremony.tower_done": {"ru": "БАШНЯ ПОКОРЕНА", "en": "TOWER CONQUERED"},
	"tower_ceremony.tower_done_list": {"ru": "Корни → Трубы → Свалка → Тёмная долина → Ржавый лес → Буерак → Саркофаг → Полигон → Рубеж → Сердце Зоны", "en": "Roots → Pipes → Dump → Dark Valley → Rusty Forest → Ravine → Sarcophagus → Proving Ground → Frontier → Heart of the Zone"},
	"tower_ceremony.rewards_line": {"ru": "+{b} биомассы · +{m} круток мутантов · +{a} аномалийных", "en": "+{b} biomass · +{m} mutant rolls · +{a} anomaly rolls"},
	"tower_ceremony.consolation": {"ru": "+{b} биомассы (утешение)", "en": "+{b} biomass (consolation)"},
	"tower_ceremony.record_note": {"ru": "Рекорд этажа: {n}★", "en": "Floor best: {n}★"},
	"tower_ceremony.skip_hint": {"ru": "нажмите, чтобы продолжить", "en": "click to continue"},
}

# Имена типов коллекции: ru - из GachaData.DISPLAY_NAMES, en - из DISPLAY_NAMES_EN
const DISPLAY_NAMES_EN := {
	"zombie": "Zombie", "dog_mutant": "Dog", "flesh": "Flesh",
	"snork_mutant": "Snork", "pseudodog": "Pseudo-dog", "poltergeist": "Poltergeist",
	"controller_mutant": "Controller", "bloodsucker": "Bloodsucker",
	"pseudogiant": "Pseudo-giant", "chimera": "Chimera",
	"common_artifact": "Common artifact", "battery_artifact": "Battery",
	"glowstick_artifact": "Glowstick", "slime_artifact": "Slime",
	"spark_artifact": "Spark", "gas_bottle_artifact": "Gas bottle",
	"rare_artifact": "Rare artifact", "energy_artifact": "Energy cell",
	"clock_artifact": "Clock", "hourglass_artifact": "Hourglass",
	"graviton_artifact": "Graviton", "fireball_artifact": "Fireball",
	"jumper_artifact": "Jumper", "flesh_artifact": "Living flesh",
	"void_artifact": "Void", "heart_artifact": "Heart of the Lake",
	"storm_artifact": "Storm", "uranium_artifact": "Uranium",
}


func _ready():
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		var l: String = str(cfg.get_value("ui", "lang", "ru"))
		if l in LANGS:
			lang = l
	# print("Loc: язык интерфейса - ", lang)


## Перевод по ключу; args подставляются в плейсхолдеры {имя}
func t(key: String, args: Dictionary = {}) -> String:
	var entry: Dictionary = STRINGS.get(key, {})
	var text: String = str(entry.get(lang, entry.get("ru", key)))
	for k in args:
		text = text.replace("{%s}" % k, str(args[k]))
	return text


## Имя типа коллекции на текущем языке
func type_name(type: String) -> String:
	if lang == "en":
		return str(DISPLAY_NAMES_EN.get(type, GachaData.display_name(type)))
	return GachaData.display_name(type)


func set_lang(new_lang: String):
	if new_lang in LANGS and new_lang != lang:
		lang = new_lang
		var cfg := ConfigFile.new()
		cfg.load("user://settings.cfg")
		cfg.set_value("ui", "lang", lang)
		cfg.save("user://settings.cfg")
		changed.emit()
		# print("Loc: язык переключён на ", lang)


func toggle():
	set_lang("en" if lang == "ru" else "ru")
