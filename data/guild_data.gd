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
const FREE_RAIDS_DAILY: int = 2             # бесплатные рейды в день
const EXTRA_RAID_SPARKS: int = 10           # доп. рейд за Искры Пробуждения
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
# Экономика: 1 Ж / 500 урона, кап 60 Ж за рейд, 2 рейда/день, +100 Ж за слейн
# (~120-220 Ж/день). Ярусы: пачка выгоднее мелкой; эксклюзив - долгосрочная
# цель (~1.5 дня фарма всех рейдов). Граница торга как в StoreData.FORBIDDEN:
# энергии/побед/уровней здесь НЕ продаём.
const SHOP := {
	"rolls_mut_3": {"price": 18, "rolls_mut": 3},
	"rolls_mut_5": {"price": 30, "rolls_mut": 5},
	"rolls_mut_12": {"price": 60, "rolls_mut": 12},
	"rolls_art_3": {"price": 18, "rolls_art": 3},
	"rolls_art_5": {"price": 30, "rolls_art": 5},
	"rolls_art_12": {"price": 60, "rolls_art": 12},
	"bio_50k": {"price": 10, "bio": 50000.0},
	"bio_100k": {"price": 20, "bio": 100000.0},
	"bio_500k": {"price": 80, "bio": 500000.0},
	"star_feed_1": {"price": 10, "star_feed": 1},
	"star_feed_3": {"price": 27, "star_feed": 3},
	"star_feed_5": {"price": 45, "star_feed": 5},
	"excl_choice": {"price": 250, "excl": 1},
}

# Боты-соседи: имена детерминированы индексом
const BOT_NAMES := [
	"Старина Крот", "Ржавый Фёдор", "Тихон", "Варяг", "Слюда", "Кочегар",
	"Полынь", "Штырь", "Гайка", "Метель", "Чабан", "Отсек", "Кремень",
	"Торк", "Стелая", "Хруст", "Шип", "Адек", "Флажок", "Смаль",
	"Гробовик", "Кисель", "Резак", "Люмен", "Штиль", "Валах", "Циклон",
	"Отсвет", "Муляж",
]

# ==================== ВОЙНА ГИЛЬДИЙ (D23, офлайн-эмуляция) ====================
const WAR_ATTEMPTS: int = 2             # попытки обороны за неделю
const WAR_POWER_SPREAD: float = 0.45    # сила соперника = наша x (1.25 - rand x 0.45) = 0.8..1.25
const WAR_ENEMY_FIGHT: float = 0.92     # соперник дотягивает до 92% твоей лучшей
const WAR_WIN_TOKENS: int = 100         # в казну за победу (+WAR_WIN_PER_LEVEL x уровень)
const WAR_WIN_PER_LEVEL: int = 20
const WAR_WIN_PERSONAL: int = 30        # лично победителю
const WAR_LOSE_PERSONAL: int = 30       # утешение
# Генератор имён ботов-гильдий (seed недели)
const WAR_ENEMY_ADJ := ["Стальной", "Чёрный", "Багровый", "Ночной", "Кислотный",
	"Последний", "Железный", "Тихий", "Ржавый", "Слепой"]
const WAR_ENEMY_NOUN := ["Клык", "Ковчег", "Легион", "Ворон", "Шторм",
	"Курган", "Пепел", "Бастион", "Молот", "Рубеж"]
