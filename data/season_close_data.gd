# data/season_close_data.gd
extends RefCounted
class_name SeasonCloseData

## Церемония закрытия сезона (спека D13, design_inbox/_done/season_finale).
## Все ручки перебора - здесь.

const REWARD_MUTANT_ROLLS: int = 5     # база за закрытие; сезон залпом не фармят
const REWARD_ANOMALY_ROLLS: int = 3
# Премия за хороший сезон: порог по СП набранного за цикл
const GREAT_SEASON_SP: int = 200
const GREAT_BONUS_ROLLS: int = 3       # +3 к обеим круткам
# Тайминги оверлея (сек)
const TITLE_SLAM: float = 0.5
const ROW_STEP: float = 0.25
const AUTO_HOLD: float = 4.0
