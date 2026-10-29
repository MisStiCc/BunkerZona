# data/mutant_roles_data.gd
extends RefCounted
class_name MutantRoles

## Роли мутантов, ауры поддержки и 8 новых видов (спека D20).
## Новые виды = re-колор базовой модели + ПАССИВНАЯ аура/эффект.

enum Role { DMG, TANK, HEAL, BUFF, CONTROL }

## Роли существующих видов (тег для карточек/кодекса)
const ROLES := {
	"zombie": Role.DMG, "dog_mutant": Role.DMG, "flesh": Role.TANK,
	"snork_mutant": Role.DMG, "pseudodog": Role.DMG, "poltergeist": Role.CONTROL,
	"controller_mutant": Role.CONTROL, "bloodsucker": Role.DMG,
	"chimera": Role.DMG, "pseudogiant": Role.TANK,
	"gniloy_zombie": Role.DMG, "besheniy_pes": Role.DMG,
	"tuhlaya_plot": Role.TANK, "tolstaya_plot": Role.TANK,
	"brodyashiy_snork": Role.DMG, "dvoroviy_pes": Role.DMG,
	"alpha_pseudodog": Role.DMG, "ash_snork": Role.DMG,
	"obsidian_controller": Role.CONTROL, "ten_pseudodog": Role.DMG,
	"lutiy_pseudodog": Role.DMG, "nochnoy_krovosos": Role.DMG,
	"psi_controller": Role.CONTROL, "krovaviy_snork": Role.DMG,
	"mercayushiy_poltergeist": Role.CONTROL, "crimson_chimera": Role.DMG,
	"obsidian_titan": Role.TANK,
	# Новые виды (D20)
	"mohovik": Role.HEAL, "tsveten": Role.HEAL, "zhivitsa": Role.HEAL,
	"zaveden": Role.BUFF, "vikhor": Role.BUFF, "shorokh": Role.BUFF,
	"leden": Role.CONTROL, "guden": Role.CONTROL,
}

## Ауры/эффекты новых видов (исполнитель - components/aura_component.gd)
const AURAS := {
	"mohovik": {"radius": 8.0, "heal_pct": 0.03},
	"tsveten": {"radius": 10.0, "pulse": {"heal_pct": 0.12, "targets": 2, "cd": 6.0}},
	"zhivitsa": {"radius": 0.0, "beam": {"heal_pct": 0.25, "cd": 10.0}},
	"zaveden": {"radius": 10.0, "dmg_pct": 0.15},
	"vikhor": {"radius": 10.0, "speed_pct": 0.20},
	"shorokh": {"radius": 10.0, "atk_speed_pct": 0.15},
	"leden": {"freeze": {"cd": 8.0, "t": 1.5, "r": 8.0}},
	"guden": {"fear": {"cd": 8.0, "r": 6.0, "push": 3.0}},
}

## 8 новых видов: база-модель, тинт, гейт кольцами, цена боя, редкость пула
const NEW_SPECIES := {
	"mohovik": {"base": "flesh", "name_ru": "Моховик", "name_en": "Mossback",
		"tint": [0.55, 0.85, 0.45], "rar": "uncommon", "cost": 120.0, "gate": 20,
		"hp": 1.15, "dmg": 0.8, "speed": 0.9},
	"tsveten": {"base": "poltergeist", "name_ru": "Цветень", "name_en": "Bloomwraith",
		"tint": [0.85, 0.65, 1.0], "rar": "rare", "cost": 150.0, "gate": 28,
		"hp": 0.9, "dmg": 0.7, "speed": 1.0},
	"zhivitsa": {"base": "bloodsucker", "name_ru": "Живица", "name_en": "Resiner",
		"tint": [0.5, 0.95, 0.5], "rar": "rare", "cost": 180.0, "gate": 36,
		"hp": 1.0, "dmg": 0.75, "speed": 1.05},
	"zaveden": {"base": "controller_mutant", "name_ru": "Заведень", "name_en": "Kindler",
		"tint": [1.0, 0.8, 0.55], "rar": "uncommon", "cost": 140.0, "gate": 24,
		"hp": 1.0, "dmg": 0.7, "speed": 0.95},
	"vikhor": {"base": "pseudodog", "name_ru": "Вихорь", "name_en": "Gusthound",
		"tint": [0.9, 0.93, 1.0], "rar": "uncommon", "cost": 120.0, "gate": 22,
		"hp": 0.9, "dmg": 0.7, "speed": 1.25},
	"shorokh": {"base": "snork_mutant", "name_ru": "Шорох", "name_en": "Rustler",
		"tint": [0.72, 0.74, 0.7], "rar": "uncommon", "cost": 130.0, "gate": 30,
		"hp": 1.0, "dmg": 0.85, "speed": 1.1},
	"leden": {"base": "dog_mutant", "name_ru": "Ледень", "name_en": "Frostbite",
		"tint": [0.6, 0.85, 1.0], "rar": "uncommon", "cost": 100.0, "gate": 18,
		"hp": 0.95, "dmg": 0.9, "speed": 1.1},
	"guden": {"base": "zombie", "name_ru": "Гудень", "name_en": "Droner",
		"tint": [0.35, 0.38, 0.55], "rar": "rare", "cost": 160.0, "gate": 34,
		"hp": 1.2, "dmg": 0.6, "speed": 0.85},
}


static func role_of(type: String) -> int:
	return int(ROLES.get(type, Role.DMG))


static func role_tag(type: String) -> String:
	match role_of(type):
		Role.HEAL: return "ЛЕЧ"
		Role.BUFF: return "БАФ"
		Role.CONTROL: return "КОНТР"
		Role.TANK: return "ТАНК"
		_: return "УРОН"


static func is_new_species(type: String) -> bool:
	return NEW_SPECIES.has(type)


static func species_of(type: String) -> Dictionary:
	return NEW_SPECIES.get(type, {})


## Базовый вид для карточки-арта (у новых видов арт базы)
static func card_base_of(type: String) -> String:
	if NEW_SPECIES.has(type):
		return str(NEW_SPECIES[type]["base"])
	return type

# ==================== ПАЧКИ ====================

const PACK_SIZE: int = 9
const PACK_UNLOCK_CYCLES: Array[int] = [3, 5, 7]   # циклы NG+, открывающие пачки 2/3/4
const AURA_STACK_CAP: int = 2


## Сколько пачек открыто (1 базовая + по циклам NG+)
static func packs_open(cycle: int) -> int:
	var n := 1
	for c in PACK_UNLOCK_CYCLES:
		if cycle >= int(c):
			n += 1
	return n
