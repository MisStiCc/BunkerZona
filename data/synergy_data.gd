class_name SynergyData
extends RefCounted

## ==================== СИНЕРГИИ МУТАНТОВ (v0.30.0 «ЗОНА МУТИРУЕТ») ====================
## Когда на поле стоят одновременно мутанты из пары/группы синергии, все
## участники получают бонус (hp/dmg/speed — множители). Баф навешивается при
## спавне и ретроактивно при активации синергии; снимается только смертью.
##
## family — таксономия видов: участники синергии могут задаваться как
## перечислением типов (types), так и семейством (family) — в семейство входят
## база и все варианты (EXCLUSIVE_MUTANTS) с тем же family.
##
## target: "members" — участникам синергии | "family:<f>" — семейству | "all" — всем.
## Активация: count — сколько РАЗНЫХ видов из набора должно быть на поле
## (2 = классическая пара). Одна синергия на мутанта может стакаться с другой.

const SYNERGIES := [
        {
                "id": "staya", "name_ru": "СТАЯ", "name_en": "PACK",
                "desc_ru": "Псовые вместе: +15% скорость всем псовым",
                "desc_en": "Canines together: +15% speed to all canines",
                "family": "dog", "count": 2,
                "target": "family:dog", "speed": 1.15, "accent": "9fd4ff",
        },
        {
                "id": "psi_set", "name_ru": "ПСИ-СЕТЬ", "name_en": "PSI-NET",
                "desc_ru": "Контролёр + полтергейст: +20% урона обоим",
                "desc_en": "Controller + poltergeist: +20% damage to both",
                "family": "psy", "count": 2,
                "target": "family:psy", "dmg": 1.2, "accent": "c9a8ff",
        },
        {
                "id": "nochnaya_ohota", "name_ru": "НОЧНАЯ ОХОТА", "name_en": "NIGHT HUNT",
                "desc_ru": "Кровосос + снорк: +15% урона обоим",
                "desc_en": "Bloodsucker + snork: +15% damage to both",
                "family": "predator", "count": 2,
                "target": "family:predator", "dmg": 1.15, "accent": "ff8080",
        },
        {
                "id": "padshie", "name_ru": "ПАДШИЕ", "name_en": "FALLEN ONES",
                "desc_ru": "Зомби + плоть: +20% HP обоим",
                "desc_en": "Zombie + flesh: +20% HP to both",
                "family": "undead", "count": 2,
                "target": "family:undead", "hp": 1.2, "accent": "a8c2a0",
        },
        {
                "id": "titany", "name_ru": "ТИТАНЫ", "name_en": "TITANS",
                "desc_ru": "Псевдогигант + химера: +10% HP и урона",
                "desc_en": "Pseudo-giant + chimera: +10% HP and damage",
                "types": ["pseudogiant", "chimera", "crimson_chimera", "obsidian_titan"],
                "count": 2, "target": "members", "hp": 1.1, "dmg": 1.1, "accent": "ffc23d",
        },
        {
                "id": "alpha_pak", "name_ru": "АЛЬФА-ПАК", "name_en": "ALPHA PACK",
                "desc_ru": "Альфа-псевдопёс + псовые: +20% скорость собакам",
                "desc_en": "Alpha pseudo-dog + canines: +20% speed to canines",
                "types": ["alpha_pseudodog"], "with_family": "dog",
                "count": 2, "target": "family:dog", "speed": 1.2, "accent": "e8eae6",
        },
        {
                "id": "obsidian_svyaz", "name_ru": "ОБСИДИАН", "name_en": "OBSIDIAN",
                "desc_ru": "Чёрный контролёр + полтергейст: +25% урона контролёру",
                "desc_en": "Obsidian controller + poltergeist: +25% controller damage",
                "types": ["obsidian_controller"], "with_family": "psy",
                "count": 2, "target": "members", "dmg": 1.25, "accent": "b48cff",
        },
        {
                "id": "venec", "name_ru": "ВЕНЕЦ ЗОНЫ", "name_en": "CROWN OF THE ZONE",
                "desc_ru": "Багровая химера + Обсидиановый титан: +15% ВСЕМ мутантам",
                "desc_en": "Crimson chimera + Obsidian titan: +15% to ALL mutants",
                "types": ["crimson_chimera", "obsidian_titan"],
                "count": 2, "target": "all", "hp": 1.15, "dmg": 1.15, "accent": "ffc23d",
        },
]

# База мутанта -> семейство (варианты берут family из EXCLUSIVE_MUTANTS).
const BASE_FAMILIES := {
        "dog_mutant": "dog", "pseudodog": "dog",
        "controller_mutant": "psy", "poltergeist": "psy",
        "bloodsucker": "predator", "snork_mutant": "predator",
        "zombie": "undead", "flesh": "undead",
        "chimera": "titan", "pseudogiant": "titan",
}


static func _ex(type: String) -> Dictionary:
        for ex in GachaData.EXCLUSIVE_MUTANTS:
                if str(ex["type"]) == type:
                        return ex
        return {}


## Семейство типа: варианты берут family из таблицы, базы — из BASE_FAMILIES.
static func family_of(mutant_type: String) -> String:
        var ex := _ex(mutant_type)
        if not ex.is_empty() and ex.has("family"):
                return str(ex["family"])
        return str(BASE_FAMILIES.get(mutant_type, ""))


## Активные синергии по набору типов на поле. alive_types: тип -> количество.
static func evaluate(alive_types: Dictionary) -> Array:
        var out: Array = []
        for s in SYNERGIES:
                if _is_active(s, alive_types):
                        out.append(s)
        return out


static func _is_active(s: Dictionary, alive_types: Dictionary) -> bool:
        # Множество присутствующих РАЗНЫХ видов (нужны для подсчёта count).
        var present := {}
        for t in alive_types.keys():
                if int(alive_types[t]) > 0:
                        present[str(t)] = true

        # Пара «лидер + семейство»: лидер обязан быть на поле, к нему
        # минимум count-1 ДРУГИХ разных видов семейства (v0.30.0).
        if s.has("with_family"):
                var leader := str(s["types"][0])
                if not present.has(leader):
                        return false
                var others := 0
                for t in _family_members(str(s["with_family"])):
                        if str(t) != leader and present.has(str(t)):
                                others += 1
                return others >= maxi(int(s.get("count", 2)) - 1, 1)

        var group: Array = []
        if s.has("family"):
                group = _family_members(str(s["family"]))
        if s.has("types"):
                group = group + (s["types"] as Array)

        # Сколько разных видов из группы синергии стоит на поле.
        var distinct := 0
        for t in group:
                if present.has(str(t)):
                        distinct += 1
        return distinct >= maxi(int(s.get("count", 2)), 2)


## Все типы (базы + варианты) семейства.
static func _family_members(family: String) -> Array:
        var out: Array = []
        for t in BASE_FAMILIES.keys():
                if str(BASE_FAMILIES[t]) == family:
                        out.append(str(t))
        for ex in GachaData.EXCLUSIVE_MUTANTS:
                if str(ex.get("family", "")) == family:
                        out.append(str(ex["type"]))
        return out


## Суммарные множители синергий для конкретного мутанта при заданных активных.
static func buffs_for(mutant_type: String, active: Array) -> Dictionary:
        var hp := 1.0
        var dmg := 1.0
        var speed := 1.0
        for s in active:
                var t := str(s.get("target", "members"))
                var applies := false
                if t == "all":
                        applies = true
                elif t.begins_with("family:"):
                        applies = family_of(mutant_type) == t.substr(7)
                else: # members
                        if s.has("family"):
                                applies = family_of(mutant_type) == str(s["family"])
                        elif s.has("types"):
                                applies = (s["types"] as Array).has(mutant_type)
                if not applies:
                        continue
                hp *= float(s.get("hp", 1.0))
                dmg *= float(s.get("dmg", 1.0))
                speed *= float(s.get("speed", 1.0))
        return {"hp": hp, "dmg": dmg, "speed": speed}


## Локализованные поля синергии: имя/описание в обоих языках + акцентный цвет.
## Выбор языка — на вызывающей стороне (Loc может быть недоступен в headless).
static func display(s: Dictionary) -> Dictionary:
        return {
                "name_ru": str(s["name_ru"]), "name_en": str(s["name_en"]),
                "desc_ru": str(s["desc_ru"]), "desc_en": str(s["desc_en"]),
                "accent": Color(str(s.get("accent", "ffffff"))),
        }
