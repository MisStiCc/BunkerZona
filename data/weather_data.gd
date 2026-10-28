# data/weather_data.gd
extends RefCounted
class_name WeatherData

## Погода Припяти (v0.31.2 «РАДИОАКТИВНЫЙ ДОЖДЬ»): атмосферное событие
## между волнами. Все ручки - здесь; процедурная Зона без погоды.

const RAIN_CHANCE: float = 0.3          # шанс на каждой передышке
const DURATION_MIN: float = 50.0        # сек
const DURATION_MAX: float = 90.0
const THUNDER_MIN_DELAY: float = 7.0    # сек между раскатами
const THUNDER_MAX_DELAY: float = 16.0
const RAIN_VOLUME_DB: float = -8.0
const REGEN_BONUS: float = 1.25         # дождь питает Зону: реген энергии +25%
