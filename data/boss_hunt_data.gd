# data/boss_hunt_data.gd
extends RefCounted
class_name BossHuntData

## Ежедневный босс - режим ОХОТА (спека D19). Все ручки здесь.

const HUNT_TIME: float = 180.0            # сек на всю охоту
const HUNT_BUDGET: float = 600.0
const BOSS_SPEED: float = 0.0            # гильд-босс стоит и дерётся          # стартовая биомасса охоты
const SUNDAY_BONUS_SPARK: int = 1         # +1 Искра всем в воскресенье
const BOSS_BASE_HP: float = 250.0         # мастер-сталкер
const REPEAT_REWARD_BIO: float = 300.0    # повтор убитого сегодня босса
const VICTORY_BIO_PER_BOSS: float = 400.0 # боевой доход за босса

## Боссы: hp_x - кратер базового HP; skills - id из SKILLS (generic-исполнитель
## в boss_base.gd); model - визуал из существующих анимированных моделей
const BOSSES := {
	"kostolom": {"name_ru": "Костолом", "name_en": "Bonemaker", "hp_x": 40.0, "speed": 1.1,
		"sparks": 3, "model": "pseudogiant", "scale": 2.2,
		"skills": [{"id": "quake", "cd": 9.0, "dmg": 30.0, "r": 8.0}]},
	"tumannitsa": {"name_ru": "Туманница", "name_en": "Mistress", "hp_x": 22.0, "speed": 0.0,
		"sparks": 3, "model": "poltergeist", "scale": 1.6,
		"skills": [{"id": "blink", "cd": 12.0}, {"id": "dot_zone", "cd": 8.0, "dmg": 8.0, "r": 4.0, "t": 6.0},
			{"id": "summon", "cd": 20.0, "n": 2, "hp_frac": 0.25}]},
	"pozhiratel": {"name_ru": "Пожиратель", "name_en": "Devourer", "hp_x": 34.0, "speed": 1.3,
		"sparks": 4, "model": "chimera", "scale": 1.9,
		"skills": [{"id": "stun_nearest", "cd": 14.0, "t": 3.0}, {"id": "vampiric", "cd": 0.0},
			{"id": "dash", "cd": 10.0}]},
	"stolp": {"name_ru": "Столп Грозы", "name_en": "Storm Pillar", "hp_x": 28.0, "speed": 0.0,
		"sparks": 4, "model": "controller", "scale": 1.7,
		"skills": [{"id": "quake", "cd": 10.0, "dmg": 24.0, "r": 12.0}, {"id": "shield", "cd": 16.0, "amount": 800.0, "t": 5.0}]},
	"hromets": {"name_ru": "Хромец", "name_en": "Limper", "hp_x": 18.0, "speed": 2.4,
		"sparks": 4, "model": "pseudodog", "scale": 1.5,
		"skills": [{"id": "dash", "cd": 8.0}, {"id": "regen", "cd": 12.0, "frac": 0.05, "t": 3.0}]},
	"mat_bolota": {"name_ru": "Мать-в-болоте", "name_en": "Marsh Mother", "hp_x": 30.0, "speed": 0.8,
		"sparks": 5, "model": "flesh", "scale": 2.0,
		"skills": [{"id": "summon", "cd": 16.0, "n": 3, "hp_frac": 0.2}, {"id": "quake", "cd": 12.0, "dmg": 20.0, "r": 10.0}]},
}

## Расписание недели: even/odd - чётность дня месяца
const WEEK_SCHEDULE := {
	"mon": {"even": ["kostolom", "stolp"], "odd": ["tumannitsa", "hromets"]},
	"tue": {"even": ["pozhiratel", "mat_bolota"], "odd": ["kostolom", "tumannitsa"]},
	"wed": {"even": ["stolp", "hromets"], "odd": ["pozhiratel", "mat_bolota"]},
	"thu": {"even": ["tumannitsa", "mat_bolota"], "odd": ["stolp", "kostolom"]},
	"fri": {"any": ["hromets"]},
	"sat": {"any": ["pozhiratel"]},
	"sun": {"any": ["kostolom", "tumannitsa", "pozhiratel", "stolp", "hromets", "mat_bolota"]},
}


## Боссы на дату (Time.get_date_dict_from_system)
static func get_today_bosses(date: Dictionary = {}) -> Array:
	var dt: Dictionary = date if not date.is_empty() else Time.get_date_dict_from_system()
	var day_names := ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
	var key: String = day_names[int(dt.get("weekday", 1))]
	var sched: Dictionary = WEEK_SCHEDULE.get(key, {})
	var parity := "even" if int(dt.get("day", 1)) % 2 == 0 else "odd"
	var ids: Array = sched.get(parity, sched.get("any", []))
	return ids.duplicate()


## Множитель статов босса от цикла NG+
static func boss_stat_mult(cycle: int) -> float:
	return 1.0 + 0.15 * float(maxi(int(cycle), 1) - 1)


## Список боссов с именами для UI («сегодня доступны»)
static func today_names(date: Dictionary = {}) -> Array:
	var out: Array = []
	for id in get_today_bosses(date):
		var b: Dictionary = BOSSES.get(id, {})
		out.append(str(b.get("name_ru", id)))
	return out
