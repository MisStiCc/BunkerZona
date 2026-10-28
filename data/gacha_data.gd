# data/gacha_data.gd
extends RefCounted
class_name GachaData

## Гача Зоны: два рукава - артефакты и мутанты.
## Дроп зависит от уровня кампании: чем выше уровень, тем жирнее редкость.
## Химера - джекпот гачи (маленький вес всегда), либо гарантия на середине
## кампании (уровень CHIMERA_GUARANTEE_LEVEL).

const CHIMERA_GUARANTEE_LEVEL: int = 50

# СУПЕР-ГАЧА: каждые 60 обычных круток (мутанты + артефакты в сумме) дают
# 1 супер-крутку. Супер-призыв бьёт ТОЛЬКО по эксклюзивам Чёрных ящиков -
# тем, которых в обычной гаче не достать. Пока собраны не все - гарантия нового.
const SUPER_PITY := 60

# ПРИЗ НА ВЫБОР: каждые 20 супер-призывов игрок сам называет эксклюзив
# Чёрного ящика (любой мутант или аномалия из пула) - без рандома.
const SUPER_CHOICE_PITY := 20

# ГЕЙТИНГ КОЛЛЕКЦИИ: пока тип не разблокирован, применить его в бою нельзя.
# На старте доступны только слабейшие; кампания открывает остальных на 1 звезду.
# Химера вне таблицы - джекпот гачи с гарантией на уровне 50.
const DEFAULT_UNLOCKED_MUTANTS := ["zombie", "dog_mutant", "flesh"]
# Дефолтные арты открывают стартовые аномалии: Электра, Кислота, Тесла
const DEFAULT_UNLOCKED_ARTIFACTS := ["spark_artifact", "slime_artifact", "battery_artifact"]

# КАЖДЫЙ АРТ СООТВЕТСТВУЕТ СВОЕЙ АНОМАЛИИ: пока арт не получен (гача/веха/
# магазин), аномалию в бою применить нельзя. Убитая аномалия роняет свой арт.
const ANOMALY_ARTIFACT_MAP := {
		"heat_anomaly": "fireball_artifact",
		"electric_anomaly": "spark_artifact",
		"acid_anomaly": "slime_artifact",
		"gravity_vortex": "graviton_artifact",
		"gravity_lift": "jumper_artifact",
		"gravity_whirlwind": "hourglass_artifact",
		"thermal_steam": "gas_bottle_artifact",
		"thermal_comet": "storm_artifact",
		"chemical_jelly": "flesh_artifact",
		"chemical_gas": "void_artifact",
		"chemical_acid_cloud": "uranium_artifact",
		"radiation_hotspot": "glowstick_artifact",
		"time_dilation": "clock_artifact",
		"teleport": "energy_artifact",
		"electric_tesla": "battery_artifact",
		"bio_burning_fluff": "heart_artifact",
}


static func get_artifact_for_anomaly(anomaly_type: String) -> String:
		return ANOMALY_ARTIFACT_MAP.get(anomaly_type, "")


## Какую аномалию открывает артефакт (пусто - никакую)
static func get_anomaly_for_artifact(artifact_type: String) -> String:
		for anomaly in ANOMALY_ARTIFACT_MAP:
				if ANOMALY_ARTIFACT_MAP[anomaly] == artifact_type:
						return str(anomaly)
		return ""


## Награда крутками за пройденный уровень кампании:
## каждый 5-й уровень +3, каждый 10-й +5 (10-й перекрывает пятёрку), остальные 0
static func campaign_roll_reward(completed_level: int) -> int:
		var level := int(completed_level)
		if level > 0 and level % 10 == 0:
				return 5
		if level > 0 and level % 5 == 0:
				return 3
		return 0


## Награда крутками за волну выживания: каждая 10-я +3
static func survival_roll_reward(completed_wave: int) -> int:
		return 3 if int(completed_wave) > 0 and int(completed_wave) % 10 == 0 else 0


## Крутки АНОМАЛИЙНОЙ гачи (артефакты): только за серьёзное -
## каждый 30-й уровень кампании +10 (30/60/90)
static func campaign_anomaly_roll_reward(completed_level: int) -> int:
		return 10 if int(completed_level) > 0 and int(completed_level) % 30 == 0 else 0


## Крутки аномалийной гачи за выживание: каждая 30-я волна +10
static func survival_anomaly_roll_reward(completed_wave: int) -> int:
		return 10 if int(completed_wave) > 0 and int(completed_wave) % 30 == 0 else 0

# Уровень кампании -> что открывается (мутанты по силе, арты по редкости)
const UNLOCK_TABLE := {
		3: {"artifacts": ["slime_artifact", "spark_artifact"]},
		5: {"mutants": ["snork_mutant"], "artifacts": ["gas_bottle_artifact"]},
		8: {"mutants": ["pseudodog"]},
		10: {"artifacts": ["rare_artifact", "energy_artifact"]},
		15: {"mutants": ["poltergeist"]},
		20: {"mutants": ["controller_mutant"], "artifacts": ["clock_artifact"]},
		25: {"mutants": ["bloodsucker"], "artifacts": ["hourglass_artifact"]},
		30: {"artifacts": ["graviton_artifact"]},
		35: {"artifacts": ["fireball_artifact"]},
		40: {"artifacts": ["jumper_artifact", "flesh_artifact"]},
		45: {"mutants": ["pseudogiant"]},
		# v0.30.0 «ЗОНА МУТИРУЕТ»: вариации по уровням кампании
		12: {"mutants": ["dvoroviy_pes", "tuhlaya_plot"]},
		18: {"mutants": ["gniloy_zombie", "brodyashiy_snork"]},
		24: {"mutants": ["besheniy_pes", "tolstaya_plot"]},
		28: {"mutants": ["lutiy_pseudodog", "mercayushiy_poltergeist"]},
		33: {"mutants": ["nochnoy_krovosos", "psi_controller"]},
		38: {"mutants": ["krovaviy_snork", "ten_pseudodog"]},
		60: {"artifacts": ["void_artifact"]},
		70: {"artifacts": ["heart_artifact"]},
		80: {"artifacts": ["storm_artifact"]},
		90: {"artifacts": ["uranium_artifact"]},
}

# Пул мутантов: редкость -> [тип, вес]
# Химера - джекпот: исключена из пула до 30 уровня кампании, дальше её вес растёт
const MUTANT_POOL := {
		"common": [["zombie", 30.0], ["dog_mutant", 25.0], ["flesh", 25.0]],
		"uncommon": [["snork_mutant", 12.0], ["pseudodog", 10.0], ["poltergeist", 8.0]],
		"rare": [["controller_mutant", 6.0], ["bloodsucker", 5.0]],
		"legendary": [["pseudogiant", 4.0], ["chimera", 0.0]],
}

# Пул артефактов по редкости (сцены из entities/artifacts)
const ARTIFACT_POOL := {
		"common": ["common_artifact", "battery_artifact", "glowstick_artifact", "slime_artifact", "spark_artifact", "gas_bottle_artifact"],
		"rare": ["rare_artifact", "energy_artifact", "clock_artifact", "hourglass_artifact", "graviton_artifact", "fireball_artifact", "jumper_artifact", "flesh_artifact"],
		"legendary": ["void_artifact", "heart_artifact", "storm_artifact", "uranium_artifact"],
}

# Награда артефактом: ресурсный бонус по редкости (энергия / биомасса)
const ARTIFACT_BONUS := {
		"common": [300.0, 100.0],
		"rare": [600.0, 250.0],
		"legendary": [1200.0, 500.0],
}

# ЭКСКЛЮЗИВНЫЕ МУТАНТЫ: только из Чёрных ящиков трека наград (ступени 10/20/30).
# Варианты существующих боевых сцен: окрас + статы поверх базы. Когда появятся
# отдельные модели художника - заменить сцену по ключу base в spawn_manager.
# tint - множитель albedo материалов модели, hp/dmg/speed - множители статов.
## rarity: "ex" (стандартные эксклюзивы ящика, фиолет) | "legendary" (золото,
## только 30-я ступень трека + базар). family — для синергий (см. SynergyData).
const EXCLUSIVE_MUTANTS := [
		{
				"type": "alpha_pseudodog", "name": "Альфа-вожак", "base": "pseudodog",
				"label": "🐺 АЛЬФА-ВОЖАК", "accent": "e8eae6", "tint": [1.9, 1.85, 1.8],
				"hp": 1.4, "dmg": 1.0, "speed": 1.15,
				"desc": "Белая масть, вожак стаи",
				"rarity": "ex", "family": "dog",
		},
		{
				"type": "ash_snork", "name": "Пепельник", "base": "snork_mutant",
				"label": "🌫 ПЕПЕЛЬНИК", "accent": "b9b4a8", "tint": [0.56, 0.55, 0.52],
				"hp": 1.0, "dmg": 1.15, "speed": 1.3,
				"desc": "Серый камуфляж, быстрый и злой",
				"rarity": "ex", "family": "predator",
		},
		{
				"type": "obsidian_controller", "name": "Обсидиановый пастырь", "base": "controller_mutant",
				"label": "👁 ОБСИДИАНОВЫЙ ПАСТЫРЬ", "accent": "b48cff", "tint": [0.5, 0.44, 0.6],
				"hp": 1.25, "dmg": 1.3, "speed": 1.0,
				"desc": "Ночной окрас, психика жёстче",
				"rarity": "ex", "family": "psy",
		},

		# ================== v0.30.0 «ЗОНА МУТИРУЕТ» ==================
		# Обычные (кампания + базар)
		{
				"type": "dvoroviy_pes", "name": "Дворовый пёс", "base": "dog_mutant",
				"label": "🐕 ДВОРОВЫЙ ПЁС", "accent": "e8eae6", "tint": [0.7, 0.68, 0.66],
				"hp": 1.15, "dmg": 1.0, "speed": 1.0,
				"desc": "Дворняга Зоны: живучий и злой",
				"rarity": "common", "family": "dog",
		},
		{
				"type": "tuhlaya_plot", "name": "Тухлая плоть", "base": "flesh",
				"label": "🥩 ТУХЛАЯ ПЛОТЬ", "accent": "b9d18f", "tint": [0.72, 0.85, 0.6],
				"hp": 1.2, "dmg": 1.05, "speed": 0.95,
				"desc": "Пропахшая аномалиями туша",
				"rarity": "common", "family": "undead",
		},
		{
				"type": "gniloy_zombie", "name": "Гнилой зомби", "base": "zombie",
				"label": "🧟 ГНИЛОЙ ЗОМБИ", "accent": "a8c2a0", "tint": [0.62, 0.72, 0.58],
				"hp": 1.1, "dmg": 1.1, "speed": 0.9,
				"desc": "Разваливается, но упрямо прёт",
				"rarity": "common", "family": "undead",
		},
		{
				"type": "brodyashiy_snork", "name": "Бродень", "base": "snork_mutant",
				"label": "🐾 БРОДЕНЬ", "accent": "d8c09a", "tint": [0.75, 0.65, 0.5],
				"hp": 1.1, "dmg": 1.0, "speed": 1.1,
				"desc": "Ушёл из лагеря, бродит по Зоне",
				"rarity": "common", "family": "predator",
		},
		# Зелёные (кампания + базар)
		{
				"type": "besheniy_pes", "name": "Бешеный пёс", "base": "dog_mutant",
				"label": "🔥 БЕШЕНЫЙ ПЁС", "accent": "ff8a75", "tint": [0.8, 0.5, 0.45],
				"hp": 0.95, "dmg": 1.15, "speed": 1.25,
				"desc": "Пена у пасти, рвётся в бой",
				"rarity": "uncommon", "family": "dog",
		},
		{
				"type": "tolstaya_plot", "name": "Толстая плоть", "base": "flesh",
				"label": "🎈 ТОЛСТАЯ ПЛОТЬ", "accent": "ffc9d2", "tint": [1.05, 0.85, 0.85],
				"hp": 1.35, "dmg": 0.95, "speed": 0.85,
				"desc": "Раздулась от мутаций, танк",
				"rarity": "uncommon", "family": "undead",
		},
		{
				"type": "lutiy_pseudodog", "name": "Лютень", "base": "pseudodog",
				"label": "🐺 ЛЮТЕНЬ", "accent": "ff9a8a", "tint": [0.85, 0.55, 0.5],
				"hp": 1.0, "dmg": 1.25, "speed": 1.1,
				"desc": "Кусает наотмашь, злее вожака",
				"rarity": "uncommon", "family": "dog",
		},
		{
				"type": "mercayushiy_poltergeist", "name": "Мерцающий полтергейст", "base": "poltergeist",
				"label": "⚡ МЕРЦАЮЩИЙ ПОЛТЕРГЕЙСТ", "accent": "9fe8ff", "tint": [0.6, 0.9, 0.95],
				"hp": 1.0, "dmg": 1.2, "speed": 1.0,
				"desc": "Искрит от энергии Зоны",
				"rarity": "uncommon", "family": "psy",
		},
		# Фиолетовые (кампания + базар)
		{
				"type": "nochnoy_krovosos", "name": "Ночень", "base": "bloodsucker",
				"label": "🌑 НОЧЕНЬ", "accent": "aebbdd", "tint": [0.45, 0.5, 0.6],
				"hp": 1.15, "dmg": 1.15, "speed": 1.15,
				"desc": "Охотится только в темноте",
				"rarity": "rare", "family": "predator",
		},
		{
				"type": "psi_controller", "name": "Одурник", "base": "controller_mutant",
				"label": "👁 ОДУРНИК", "accent": "c9a8ff", "tint": [0.7, 0.55, 0.95],
				"hp": 1.1, "dmg": 1.25, "speed": 1.0,
				"desc": "Ломает разум одним взглядом",
				"rarity": "rare", "family": "psy",
		},
		{
				"type": "krovaviy_snork", "name": "Кровник", "base": "snork_mutant",
				"label": "🩸 КРОВНИК", "accent": "ff8080", "tint": [0.9, 0.4, 0.4],
				"hp": 1.05, "dmg": 1.3, "speed": 1.15,
				"desc": "Противогаз в бурой корке",
				"rarity": "rare", "family": "predator",
		},
		{
				"type": "ten_pseudodog", "name": "Мгларь", "base": "pseudodog",
				"label": "👣 МГЛАРЬ", "accent": "8a8a99", "tint": [0.4, 0.4, 0.45],
				"hp": 0.95, "dmg": 1.1, "speed": 1.3,
				"desc": "Не отбрасывает тени — сама тень",
				"rarity": "rare", "family": "dog",
		},
		# ЛЕГЕНДАРКИ ЧЁРНОГО ЯЩИКА (30-я ступень трека + базар за 500 СП)
		{
				"type": "crimson_chimera", "name": "Багровая химера", "base": "chimera",
				"label": "👑 БАГРОВАЯ ХИМЕРА", "accent": "ffc23d", "tint": [1.15, 0.35, 0.3],
				"hp": 1.5, "dmg": 1.35, "speed": 1.1,
				"desc": "Легенда Зоны: два сердца горят кровавым огнём",
				"rarity": "legendary", "family": "titan",
		},
		{
				"type": "obsidian_titan", "name": "Обсидиановый титан", "base": "pseudogiant",
				"label": "🗿 ОБСИДИАНОВЫЙ ТИТАН", "accent": "ffc23d", "tint": [0.35, 0.32, 0.38],
				"hp": 1.6, "dmg": 1.25, "speed": 0.95,
				"desc": "Легенда Зоны: чёрный камень, шаги вершат выброс",
				"rarity": "legendary", "family": "titan",
		},
]


# ЭКСКЛЮЗИВНЫЕ АНОМАЛИИ: только из Чёрных ящиков трека наград (ступени 10/20/30),
# парой к эксклюзивным мутантам. Варианты существующих сцен: целевой цвет + усиленные
# статы поверх базы. color - целевой цвет аномалии (перекрывает цвет базы),
# dmg/rad - множители урона и радиуса, props - прямые поля сцены (если есть).
const EXCLUSIVE_ANOMALIES := [
		{
				"type": "ash_tornado", "name": "Пепельный вихрь", "base": "gravity_whirlwind",
				"label": "ПЕПЕЛЬНЫЙ ВИХРЬ", "accent": "cfc9ba", "color": [0.66, 0.63, 0.56],
				"dmg": 1.3, "rad": 1.4, "props": {"centrifugal_force": 5.5},
				"desc": "Серая мгла: на 40% шире и на 30% злее обычного вихря",
		},
		{
				"type": "crimson_heat", "name": "Багровая жара", "base": "heat_anomaly",
				"label": "БАГРОВАЯ ЖАРА", "accent": "ff6a4d", "color": [0.85, 0.2, 0.12],
				"dmg": 1.5, "rad": 1.2, "props": {},
				"desc": "Кровавый жар: +50% урона, +20% радиуса",
		},
		{
				"type": "void_loop", "name": "Пустотная петля", "base": "time_dilation",
				"label": "ПУСТОТНАЯ ПЕТЛЯ", "accent": "b48cff", "color": [0.36, 0.14, 0.62],
				"dmg": 1.2, "rad": 1.5, "props": {"time_scale": 0.2},
				"desc": "Провал во времени: +50% радиуса, время течёт вязче",
		},
]


static func get_exclusive_anomaly(type: String) -> Dictionary:
		for ax in EXCLUSIVE_ANOMALIES:
				if str(ax["type"]) == type:
						return ax
		return {}


static func is_exclusive_anomaly(type: String) -> bool:
		return not get_exclusive_anomaly(type).is_empty()


## Эксклюзивная аномалия милстоуна: ротация сдвинута на 1 против мутантской,
## чтобы один Чёрный ящик давал пару разных эксклюзивов (мутант != индекс аномалии)
static func exclusive_anomaly_for_milestone(cycle: int, milestone: int) -> Dictionary:
		if EXCLUSIVE_ANOMALIES.is_empty():
				return {}
		var idx := (maxi(int(cycle), 1) + maxi(int(milestone), 1)) % EXCLUSIVE_ANOMALIES.size()
		return EXCLUSIVE_ANOMALIES[idx]


static func get_exclusive(type: String) -> Dictionary:
		for ex in EXCLUSIVE_MUTANTS:
				if str(ex["type"]) == type:
						return ex
		return {}

## База эксклюзивного мутанта (v0.21.0): ash_snork -> snork_mutant. Не эксклюзив - пусто.
static func exclusive_base_of(type: String) -> String:
		for ex in EXCLUSIVE_MUTANTS:
				if str(ex["type"]) == type:
						return str(ex["base"])
		return ""


static func is_exclusive(type: String) -> bool:
		return not get_exclusive(type).is_empty()


## Эксклюзив милстоуна: ступени 10/20 — стандартная ротация (3 эксклюзива),
## ступень 30 (m=3) — ЛЕГЕНДАРНЫЙ тир (ротация по циклам), v0.30.0.
static func exclusive_for_milestone(cycle: int, milestone: int) -> Dictionary:
		if EXCLUSIVE_MUTANTS.is_empty():
				return {}
		var standard: Array = []
		var legendaries: Array = []
		for ex in EXCLUSIVE_MUTANTS:
				if str(ex.get("rarity", "ex")) == "legendary":
						legendaries.append(ex)
				else:
						standard.append(ex)
		if maxi(int(milestone), 1) >= 3 and not legendaries.is_empty():
				return legendaries[(maxi(int(cycle), 1) - 1) % legendaries.size()]
		if standard.is_empty():
				return {}
		return standard[(maxi(int(cycle), 1) - 1 + maxi(int(milestone), 1) - 1) % standard.size()]


## Полный размер коллекции: пулы гачи + эксклюзивы Чёрных ящиков (мутанты и аномалии).
static func total_collection_size() -> int:
		var n := EXCLUSIVE_MUTANTS.size() + EXCLUSIVE_ANOMALIES.size()
		for rarity in MUTANT_POOL:
				n += MUTANT_POOL[rarity].size()
		for rarity in ARTIFACT_POOL:
				n += ARTIFACT_POOL[rarity].size()
		return n


# Круглые волны выживания: сбалансированные награды

# МАГАЗИН: покупка НЕтоповых мутантов и артефактов за биомассу лаборатории.
# Купленный мутант бесплатно вступит в бой в начале следующего забега,
# артефакт - заспавнится у монолита как приманка для сталкеров.
# Химеры, Кряжа и легендарных артефактов в магазине нет - только гача и вехи.
const SHOP_MUTANTS := [
		["zombie", "Зомби", 30], ["dog_mutant", "Собака", 45], ["flesh", "Плоть", 45],
		["snork_mutant", "Болотник", 75], ["pseudodog", "Сумеречник", 75],
		["poltergeist", "Полтергейст", 120], ["controller_mutant", "Сновод", 120],
		["bloodsucker", "Пиявец", 150],
]
const SHOP_ARTIFACTS := [
		["battery_artifact", "Батарейка", 150],
		["energy_artifact", "Энергетик", 350],
		["clock_artifact", "Часы", 350],
		["rare_artifact", "Редкий артефакт", 600],
]

# МАГАЗИН СЕЗОНА (v0.19.0 «БАЗАР»): товары за очки сезона (СП). СП дают
# победы арены (+5 вызов / +10 оборона), сезонные задачи и медали, пережитые
# выбросы (+3). Эксклюзивы Чёрных ящиков впервые можно КУПИТЬ - СП решают всё.
# kind: ex_mut | ex_anom | rolls_mut | rolls_art | biomass | copy
const SEASON_SHOP := [
		["ex_mut", "alpha_pseudodog", "Альфа-вожак", 250],
		["ex_mut", "ash_snork", "Пепельник", 250],
		["ex_mut", "obsidian_controller", "Обсидиановый пастырь", 250],
		# v0.30.0 «ЗОНА МУТИРУЕТ»: вариации и легендарки в базаре
		["ex_mut", "dvoroviy_pes", "Дворовый пёс", 60],
		["ex_mut", "tuhlaya_plot", "Тухлая плоть", 60],
		["ex_mut", "gniloy_zombie", "Гнилой зомби", 60],
		["ex_mut", "brodyashiy_snork", "Бродень", 60],
		["ex_mut", "besheniy_pes", "Бешеный пёс", 120],
		["ex_mut", "tolstaya_plot", "Толстая плоть", 120],
		["ex_mut", "lutiy_pseudodog", "Лютень", 120],
		["ex_mut", "mercayushiy_poltergeist", "Мерцающий полтергейст", 120],
		["ex_mut", "nochnoy_krovosos", "Ночень", 200],
		["ex_mut", "psi_controller", "Одурник", 200],
		["ex_mut", "krovaviy_snork", "Кровник", 200],
		["ex_mut", "ten_pseudodog", "Мгларь", 200],
		["ex_mut", "crimson_chimera", "Багровая химера", 500],
		["ex_mut", "obsidian_titan", "Обсидиановый титан", 500],
		["ex_anom", "ash_tornado", "Пепельный вихрь", 250],
		["ex_anom", "crimson_heat", "Багровая жара", 250],
		["ex_anom", "void_loop", "Пустотная петля", 250],
		# ВЕСЬ МАГАЗИН (v0.22.0 «ПОЛНЫЙ БАЗАР»): топы гачи в коллекцию и весь
		# артефактный пул за СП - кампания/гача больше не единственный путь.
		# mut: новый -> коллекция, дубликат -> копия на ферму (как эксклюзивы).
		# art: аномалия открывается, артефакт приходит в бой (как магазин за биомассу).
		["mut", "pseudogiant", "Кряж", 180],
		["mut", "chimera", "Химера", 240],
		["art", "common_artifact", "Обычный артефакт", 8],
		["art", "battery_artifact", "Батарейка", 8],
		["art", "glowstick_artifact", "Светляк", 8],
		["art", "slime_artifact", "Слизь", 8],
		["art", "spark_artifact", "Искра", 8],
		["art", "gas_bottle_artifact", "Газовый баллон", 8],
		["art", "rare_artifact", "Редкий артефакт", 25],
		["art", "energy_artifact", "Энергетик", 25],
		["art", "clock_artifact", "Часы", 25],
		["art", "hourglass_artifact", "Песочные часы", 25],
		["art", "graviton_artifact", "Гравитон", 25],
		["art", "fireball_artifact", "Огненный шар", 25],
		["art", "jumper_artifact", "Прыгун", 25],
		["art", "flesh_artifact", "Живая плоть", 25],
		["art", "void_artifact", "Пустота", 60],
		["art", "heart_artifact", "Сердце Озера", 60],
		["art", "storm_artifact", "Гроза", 60],
		["art", "uranium_artifact", "Уран", 60],
		["rolls_mut", "", "Крутки мутантов x10", 45],
		["rolls_art", "", "Крутки артефактов x10", 45],
		["biomass", "", "Биомасса 100 000", 40],
		["copy", "pseudogiant", "Копия: Кряж", 120],
		["copy", "chimera", "Копия: Химера", 120],
]

# ОБМЕННИК: артефакты, поднятые на выбросах и в забегах, и биомасса -> СП.
const EXCHANGE_ARTIFACT_SP := {"common": 1, "rare": 3, "legendary": 10}
const EXCHANGE_BIOMASS_STEP := 50000
const EXCHANGE_BIOMASS_SP := 5
const EXCHANGE_COPY_SP := 2


# КОРМ ЗВЁЗД: дубликат того же типа даёт звезду сразу; слабые типы можно
# ПОЖЕРТВОВАТЬ - они покидают коллекцию, давая очки корма цели.
# Ценность корма по редкости и очковая цена следующей звезды (текущие звёзды -> очков).
const FODDER_VALUE := {"common": 1, "uncommon": 2, "rare": 3, "legendary": 5}
const STAR_FEED_COST := {1: 2, 2: 4, 3: 6, 4: 8}

# Русские имена всех типов коллекции (панель звёзд, логи)
const DISPLAY_NAMES := {
		"zombie": "Зомби", "dog_mutant": "Собака", "flesh": "Плоть",
		"snork_mutant": "Болотник", "pseudodog": "Сумеречник", "poltergeist": "Полтергейст",
		"controller_mutant": "Сновод", "bloodsucker": "Пиявец",
		"pseudogiant": "Кряж", "chimera": "Химера",
		"alpha_pseudodog": "Альфа-вожак", "ash_snork": "Пепельник",
		"obsidian_controller": "Обсидиановый пастырь",
		"dvoroviy_pes": "Дворовый пёс", "tuhlaya_plot": "Тухлая плоть",
		"gniloy_zombie": "Гнилой зомби", "brodyashiy_snork": "Бродень",
		"besheniy_pes": "Бешеный пёс", "tolstaya_plot": "Толстая плоть",
		"lutiy_pseudodog": "Лютень", "mercayushiy_poltergeist": "Мерцающий полтергейст",
		"nochnoy_krovosos": "Ночень", "psi_controller": "Одурник",
		"krovaviy_snork": "Кровник", "ten_pseudodog": "Мгларь",
		"crimson_chimera": "Багровая химера", "obsidian_titan": "Обсидиановый титан",
		"ash_tornado": "Пепельный вихрь", "crimson_heat": "Багровая жара",
		"void_loop": "Пустотная петля",
		"common_artifact": "Обычный артефакт", "battery_artifact": "Батарейка",
		"glowstick_artifact": "Светляк", "slime_artifact": "Слизь",
		"spark_artifact": "Искра", "gas_bottle_artifact": "Газовый баллон",
		"rare_artifact": "Редкий артефакт", "energy_artifact": "Энергетик",
		"clock_artifact": "Часы", "hourglass_artifact": "Песочные часы",
		"graviton_artifact": "Гравитон", "fireball_artifact": "Огненный шар",
		"jumper_artifact": "Прыгун", "flesh_artifact": "Живая плоть",
		"void_artifact": "Пустота", "heart_artifact": "Сердце Озера",
		"storm_artifact": "Гроза", "uranium_artifact": "Уран",
}


static func display_name(type: String) -> String:
		return DISPLAY_NAMES.get(type, type)


# Цвета редкости для текста дропов
const RARITY_COLORS := {
		"common": Color(0.75, 0.75, 0.78),
		"uncommon": Color(0.45, 0.85, 0.5),
		"rare": Color(0.45, 0.65, 1.0),
		"legendary": Color(1.0, 0.72, 0.25),
}


static func rarity_color(rarity: String) -> Color:
		# D14: дальтоник-режим перекрашивает шкалу (вне режима - как было)
		return Accessibility.rarity_color(rarity, RARITY_COLORS.get(rarity, Color.WHITE))


## Путь к карточке-иконке. PNG художника в приоритете, SVG - фоллбек.
## gray=true - закрытая (серые версии в ui/cards/gray/)
## PNG проверяется по факту наличия файла: битые/отсутствующие бинарники
## не ломают иконку - молча берётся SVG-версия.
static func card_icon_path(type: String, is_mutant: bool, gray: bool = false) -> String:
		var dir := "gray/" if gray else ""
		var base := "%s%s_%s" % [dir, "mut" if is_mutant else "art", type]
		var png := "res://ui/cards/%s.png" % base
		if FileAccess.file_exists(png):
				return png
		return "res://ui/cards/%s.svg" % base


static func get_default_unlocked_mutants() -> Array:
		return DEFAULT_UNLOCKED_MUTANTS.duplicate()


static func get_default_unlocked_artifacts() -> Array:
		return DEFAULT_UNLOCKED_ARTIFACTS.duplicate()


static func get_unlocks_at(campaign_level: int) -> Dictionary:
		return UNLOCK_TABLE.get(int(campaign_level), {})


## Уровень кампании, на котором открывается тип. 0 = доступен с самого начала.
static func get_unlock_campaign_level(type: String) -> int:
		for level in UNLOCK_TABLE:
				var entry: Dictionary = UNLOCK_TABLE[level]
				if entry.get("mutants", []).has(type) or entry.get("artifacts", []).has(type):
						return int(level)
		return 0


static func get_mutant_rarity(type: String) -> String:
		for rarity in MUTANT_POOL:
				for e in MUTANT_POOL[rarity]:
						if e[0] == type:
								return rarity
		# v0.30.0: варианты берут редкость из таблицы эксклюзивов/вариаций
		# (легендарки ящика — gold, остальные варианты — фиолет rare-рамки)
		var ex := get_exclusive(type)
		if not ex.is_empty():
				return "legendary" if str(ex.get("rarity", "ex")) == "legendary" else "rare"
		return "common"


static func get_artifact_rarity(type: String) -> String:
		for rarity in ARTIFACT_POOL:
				if ARTIFACT_POOL[rarity].has(type):
						return rarity
		return "common"


## Очки корма за пожертвованный тип
static func get_fodder_value(type: String, is_mutant: bool) -> int:
		if is_mutant and is_exclusive(type):
				return int(FODDER_VALUE.get("legendary", 5))
		var rarity: String = get_mutant_rarity(type) if is_mutant else get_artifact_rarity(type)
		return int(FODDER_VALUE.get(rarity, 1))


## Очков корма до следующей звезды при текущих звёздах
static func get_star_feed_cost(current_stars: int) -> int:
		return int(STAR_FEED_COST.get(maxi(current_stars, 1), 8))


static func get_shop_mutants() -> Array:
		return SHOP_MUTANTS


static func get_shop_artifacts() -> Array:
		return SHOP_ARTIFACTS


static func rarity_weights(level: int) -> Dictionary:
		# Легендарки: ~4% на старте, до 12% к концу кампании.
		# Необычный тир обязателен - без него болотник/сумеречник/полтергейст
		# не выпадают из гачи вовсе (баг, найденный прогоном 10000 круток)
		var legendary := minf(4.0 + float(level) * 0.06, 12.0)
		var rare := minf(20.0 + float(level) * 0.1, 35.0)
		var uncommon := minf(15.0 + float(level) * 0.1, 25.0)
		return {
				"common": 100.0 - legendary - rare - uncommon,
				"uncommon": uncommon,
				"rare": rare,
				"legendary": legendary,
		}


static func _pick_weighted(pool: Array) -> String:
		var total := 0.0
		for e in pool:
				total += e[1]
		var r := randf() * total
		for e in pool:
				r -= e[1]
				if r <= 0.0:
						return e[0]
		return pool[0][0]


static func roll_rarity(level: int) -> String:
		var w := rarity_weights(level)
		var pool := []
		for key in w:
				pool.append([key, w[key]])
		return _pick_weighted(pool)


static func roll_mutant_gacha(level: int) -> Dictionary:
		var rarity := roll_rarity(level)
		var pool: Array = MUTANT_POOL[rarity].duplicate(true)
		# Химера - джекпот: до 30 уровня исключена, дальше её вес растёт с уровнем
		if level >= 30:
				for e in pool:
						if e[0] == "chimera":
								e[1] = float(level) / 10.0
		var type := _pick_weighted(pool)
		return {"type": type, "rarity": rarity}


static func roll_artifact_gacha(level: int) -> Dictionary:
		var w := rarity_weights(level)
		# У артефактов нет необычного тира: его доля уходит редким
		var rarity := _pick_weighted([["common", w["common"]], ["rare", w["rare"] + w["uncommon"]], ["legendary", w["legendary"]]])
		var types: Array = ARTIFACT_POOL[rarity]
		var type: String = types[randi() % types.size()]
		var bonus: Array = ARTIFACT_BONUS[rarity]
		return {"type": type, "rarity": rarity, "energy": bonus[0], "biomass": bonus[1]}


## СУПЕР-ПРИЗЫВ: случайный эксклюзив Чёрного ящика (мутант или аномалия).
## Пока в коллекции есть неполученные - гарантированно НОВЫЙ; когда все шесть
## собраны - случайный дубль (мутант -> копия на ферму, аномалия -> биомасса).
static func roll_super_gacha(owned_mutants: Array, owned_anomalies: Array) -> Dictionary:
		var entries: Array = []
		for ex in EXCLUSIVE_MUTANTS:
				entries.append({"kind": "mut", "type": str(ex["type"]), "owned": owned_mutants.has(str(ex["type"]))})
		for ax in EXCLUSIVE_ANOMALIES:
				entries.append({"kind": "art", "type": str(ax["type"]), "owned": owned_anomalies.has(str(ax["type"]))})
		var fresh: Array = []
		for e in entries:
				if not bool(e["owned"]):
						fresh.append(e)
		var pool: Array = fresh if not fresh.is_empty() else entries
		var pick: Dictionary = pool[randi() % pool.size()]
		return {"kind": str(pick["kind"]), "type": str(pick["type"]), "rarity": "legendary"}


static func milestone_wave_reward(waves: int) -> Dictionary:
		# Круглые волны выживания: сбалансированные награды (мутант + артефакт)
		if waves >= 30:
				return {"mutant": "pseudogiant", "artifact": "rare_artifact", "label": "30 волн"}
		if waves >= 20:
				return {"mutant": "bloodsucker", "artifact": "energy_artifact", "label": "20 волн"}
		if waves >= 10:
				return {"mutant": "snork_mutant", "artifact": "battery_artifact", "label": "10 волн"}
		return {}
