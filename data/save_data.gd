# data/save_data.gd
extends Resource
class_name SaveData

## Сохранённые данные игры

@export var save_time: String = ""
@export var lab_data: LabData
@export var statistics: GameStatistics

# Кампания: самый высокий ОТКРЫТЫЙ уровень (1-100)
@export var campaign_level: int = 1
@export var campaign_completed: bool = false
# NG+ (D12): цикл кампании после 100 колец; campaign_cycle_100 - за какой
# цикл 100-е кольцо уже закрыто (инкремент цикла только за ПЕРВУЮ победу
# на 100-м в рамках цикла). У старых сейвов поля отсутствуют -> дефолты
# (цикл 1, миграция не нужна)
@export var campaign_cycle: int = 1
@export var campaign_cycle_100: int = 0
# D16 монетизация (за флагом StoreData.ENABLED): владение nc-покупками
# и наградами пропуска {sku/cos_id: true|token}; pass_cycle - цикл,
# на котором куплен последний пропуск (0 = не покупал). Старые сейвы - пусто.
@export var owned: Dictionary = {}
@export var pass_cycle: int = 0
# Режим сложности кампании: easy / normal / hard (CampaignData)
@export var campaign_mode: String = "normal"

# Башня Монолита: высший открытый этаж, звёзды по этажам {этаж: 1-3}
@export var tower_floor: int = 1
@export var tower_stars: Dictionary = {}

# Профиль «Сканер личности»: выбранные аватар/рамка/титул и закреплённый
# статус (id из ProfileData). Разблокировки НЕ хранятся - считаются от
# прогресса; пустой profile_status = авто-статус по действиям в Зоне.
@export var profile_avatar: String = "zombie"
@export var profile_frame: String = "steel"
@export var profile_title: String = "green"
@export var profile_status: String = ""
# Кастомное имя сталкера; пусто = автоматом «СТАЛКЕР-XX» по номеру забега
@export var profile_name: String = ""



# Прогрессия: уровень/опыт, задачи, трек сундуков, онбординг (Prog)
@export var prog_profile: Dictionary = {}
@export var prog_quests: Dictionary = {}
@export var prog_track: Dictionary = {}
@export var prog_onboard: Dictionary = {}

# Календарь входа (Prog): {"last": "YYYY-MM-DD", "claimed": 0..7, "cycles": 0, "popup": ""}
@export var prog_calendar: Dictionary = {}
# Медали Зоны: {"claimed": {id: true}}
@export var prog_medals: Dictionary = {}
# Пожизненные счётчики медалей: {"runs": N, "wins": N, ...}
@export var prog_counts: Dictionary = {}


func _init():
    lab_data = LabData.new()
    statistics = GameStatistics.new()
