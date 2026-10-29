# data/guild_data.gd
extends RefCounted
class_name GuildData

## Гильдия (D21, офлайн-эмуляция): боты-соседи, чат, недельный Гильд-босс,
## жетонный магазин. Все ручки здесь.

const GUILD_NAME := "Бункер-1"
const MEMBERS_TOTAL := 30            # ты + 29 ботов
const CHAT_MAX: int = 30             # строк в логе

# Недельный Гильд-босс: целевой пул HP и рост по циклам NG+
const BOSS_POOL_BASE: float = 80000.0
const BOSS_POOL_CYCLE_MULT: float = 1.15
const BOSS_SPEED: float = 0.0        # босс стоит и дерётся (уходит = D19)
const RAID_TIME: float = 180.0
const TOKENS_PER_DAMAGE: float = 1.0 / 500.0   # 1 жетон за 500 урона
const RAID_TOKEN_CAP: int = 60

# Помощь ботов на боссу: раз в день, каждый онлайн-бот вносит долю пула
const CALL_HELP_DAILY_FRACTION: float = 0.04   # 4% пула за раз

# Пассив ботов: суточный вклад в урон босса (доля пула, детерминированно)
const BOT_DAILY_DMG_FRACTION: float = 0.06
const BOT_TREASURY_DAILY: int = 120            # СП-подобный вклад в казну

# Казна/уровень: вклад 1000 казны = 1 XP гильдии, перк +1% HP/уровень (кап 10)
const TREASURY_XP_PER: int = 1000
const PERK_HP_PER_LEVEL: float = 0.01
const PERK_HP_CAP: float = 0.10

# Жетонный магазин: id -> {цена жетонов, payload}
const SHOP := {
	"rolls_mut_5": {"price": 30, "rolls_mut": 5},
	"rolls_art_5": {"price": 30, "rolls_art": 5},
	"bio_100k": {"price": 20, "bio": 100000.0},
	"star_feed_1": {"price": 10, "star_feed": 1},
}

# Боты-соседи: имена детерминированы индексом
const BOT_NAMES := [
	"Старина Крот", "Ржавый Фёдор", "Тихон", "Варяг", "Слюда", "Кочегар",
	"Полынь", "Штырь", "Гайка", "Метель", "Чабан", "Отсек", "Кремень",
	"Торк", "Стелая", "Хруст", "Шип", "Адек", "Флажок", "Смаль",
	"Гробовик", "Кисель", "Резак", "Люмен", "Штиль", "Валах", "Циклон",
	"Отсвет", "Муляж",
]
