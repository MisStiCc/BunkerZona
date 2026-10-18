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
# Режим сложности кампании: easy / normal / hard (CampaignData)
@export var campaign_mode: String = "normal"

# Башня Монолита: высший открытый этаж, звёзды по этажам {этаж: 1-3}
@export var tower_floor: int = 1
@export var tower_stars: Dictionary = {}


func _init():
    lab_data = LabData.new()
    statistics = GameStatistics.new()