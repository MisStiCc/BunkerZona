# 8 новых ОРИГИНАЛЬНЫХ мутантов (ЗАДАЧА 43)

## Что это

Восемь новых базовых мутантов под роли пачек (ТАНК/ЛЕЧ/УРОН/БАФ), по 2 на
роль, 2 легендарных хедлайнера. У каждого: анимированная модель (риг + 4
клипа idle/walk/attack/death), карточка-портрет 620px (рендер самой модели
— арт совпадает с 3D один-в-один), готовый блок данных. Всё процедурное
Blender + PIL, CC0.

## Доставлено

- `models/<id>.glb` (8 шт) — **уже в `ui/cards/` как карточки** + серые
  версии в `ui/cards/gray/`. И игрока-модель (в `models/`) главному.
- Godot 4.6.1: все 8 грузятся, AnimationPlayer видит 4 клипа (проверено).

| id | Имя | Роль | Редкость | Силуэт | Клипы (характер) |
|---|---|---|---|---|---|
| kremen | Кремень | ТАНК | uncommon | каменный купол-панцирь, таран, 4 лапы | тяжёлый таран |
| rzhavnik | Ржавник | ТАНК | rare | ржавый краб-сборщик, клешни-ковши, линза | крабовый шаг |
| sporonosets | Спороносец | ЛЕЧ | uncommon | гриб-страж, светящиеся споры, гифы | выброс спор |
| chrevo | Чрево | ЛЕЧ | epic | пульсирующая плоть, чрево-свет, пуповины | удар пуповинами |
| iskropluy | Искроплюй | УРОН | rare | парящий электрический угорь, разрядники | изгиб-разряд |
| kosar | Косарь | УРОН | LEGENDARY | трёхметровый жнец, руки-лезвия, безглазая маска | двойной взмах |
| mayak | Маяк | БАФ | uncommon | мутант-маяк, вращающийся прожектор-голова | ослепляющая вспышка |
| horovod | Хоровод | БАФ | LEGENDARY | кольцо трёх сросшихся фигур | вихревой разгон |

## Блок данных для main (paste-ready, формат species)

```gdscript
# добавить в BASE_STATS + пул редкостей + MutantRoles.ROLES + карточки/модели
const NEW_ORIGINALS := [
	{"id": "kremen", "name_ru": "Кремень", "role": "TANK", "rarity": "uncommon",
		"gate": 12, "hp": 2.0, "dmg": 0.6, "speed": 0.85, "family": "construct"},
	{"id": "rzhavnik", "name_ru": "Ржавник", "role": "TANK", "rarity": "rare",
		"gate": 26, "hp": 1.8, "dmg": 0.8, "speed": 0.95, "family": "construct"},
	{"id": "sporonosets", "name_ru": "Спороносец", "role": "HEAL", "rarity": "uncommon",
		"gate": 16, "hp": 1.0, "dmg": 0.5, "speed": 0.95, "family": "spore"},
	{"id": "chrevo", "name_ru": "Чрево", "role": "HEAL", "rarity": "epic",
		"gate": 34, "hp": 1.2, "dmg": 0.6, "speed": 0.85, "family": "spore"},
	{"id": "iskropluy", "name_ru": "Искроплюй", "role": "DMG", "rarity": "rare",
		"gate": 22, "hp": 0.85, "dmg": 1.45, "speed": 1.1, "family": "electric"},
	{"id": "kosar", "name_ru": "Косарь", "role": "DMG", "rarity": "legendary",
		"gate": 46, "hp": 0.9, "dmg": 1.6, "speed": 1.15, "family": "reaper"},
	{"id": "mayak", "name_ru": "Маяк", "role": "BUFF", "rarity": "uncommon",
		"gate": 14, "hp": 1.0, "dmg": 0.55, "speed": 0.9, "family": "beacon"},
	{"id": "horovod", "name_ru": "Хоровод", "role": "BUFF", "rarity": "legendary",
		"gate": 44, "hp": 1.1, "dmg": 0.7, "speed": 1.0, "family": "ritual"},
]
```

Точные ключи ролей/редкостей — под схему `mutant_roles_data.gd`/`gacha_data.gd`
(значения подобраны под баланс species D20: танки толстые и медленные,
лекари-бафы слабые, ДД быстрые и злые; gate — уровень кампании открытия).

## Проверка

Godot 4.6.1: 8/8 сцен грузятся, 4 клипа у каждого. Blender-рендеры —
силуэты различаются, палитры ролей читаются. Контрольный лист карточек —
в `_review.png`.
