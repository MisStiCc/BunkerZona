# 8 новых ОРИГИНАЛЬНЫХ мутантов (ЗАДАЧА 43) — v2 НА МОДЕЛЯХ MESHY

## Что это (v2 — замена процедурных моделей)

Восемь базовых мутантов под роли пачек (ТАНК/ЛЕЧ/УРОН/БАФ), по 2 на роль,
2 легендарных хедлайнера. **Владелец сгенерил модели в Meshy** (image-to-3D
по промптам Шедеврума v2 из `shedevrum_prompts.txt`), подготовщик собрал их
в игровые: нормализация масштаба (метры, origin в лапах), децимация до
21–39 тыс. трис, процедурный риг по классу силуэта + авто-веса, 4 клипа.

**Модели и карточки v2 ПОЛНОСТЬЮ заменяют v1** (процедурные примитивы):
- v2-модели: `models_anim/<id>_anim.glb` (8 шт, 2.1–5.6 МБ, текстуры PBR
  внутри, ужаты до 1024)
- v2-карточки: `cards/<id>.png` (620px, рамка редкости) + `cards/gray/`
- старые v1-модели владелец переименовал в `models/<id>_old.glb` —
  на замену в игре не влияют, решит владелец
- Godot 4.6.1 проверен: 8/8 грузятся, AnimationPlayer видит 4 клипа
  (idle/walk/attack/death — имена под `base_mutant._match_clip`)

## Контрольные рендеры

`_review_meshy.png` — 8 моделей (сверху idle, снизу walk);
`_review_cards.png` — итоговые карточки. Превью-кадры: `models_anim/preview/`.

| id | Имя | Роль | Редкость | Силуэт (Meshy) | Вес GLB |
|---|---|---|---|---|---|
| kremen | Кремень | ТАНК | uncommon | базальтовая черепаха-панцирник | 2.4 МБ |
| rzhavnik | Ржавник | ТАНК | rare | ржавый краб-сборщик, клешни-ковши | 2.7 МБ |
| sporonosets | Спороносец | ЛЕЧ | uncommon | гриб-хранитель, светящиеся лозы | 2.3 МБ |
| chrevo | Чрево | ЛЕЧ | epic | багровый организм-курган, щупальца | 3.9 МБ |
| iskropluy | Искроплюй | УРОН | rare | парящий электрический угорь | 2.1 МБ |
| kosar | Косарь | УРОН | legendary | жнец в рваном плаще, клинки-косы | 2.5 МБ |
| mayak | Маяк | БАФ | uncommon | каменный великан-страж, свет в груди | 5.6 МБ |
| horovod | Хоровод | БАФ | legendary | три призрачные фигуры в хороводе | 3.5 МБ |

## Что заменить у main (сводка)

1. `models/<id>_anim.glb` ← `inbox/new_mutants/models_anim/<id>_anim.glb`
   (8 файлов; старые v1-GLB можно удалить или оставить как <id>_old).
2. `ui/cards/<id>.png` и `ui/cards/gray/<id>.png` ← `cards/` (перезапись).
3. Клипы те же 4, код подключения менять не нужно (см. блок данных ниже,
   он не менялся с v1).

## Блок данных для main (paste-ready, формат species) — без изменений с v1

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
(танки толстые и медленные, лекари-бафы слабые, ДД быстрые и злые;
gate — уровень кампании открытия).

## Лицензия

Модели Meshy — CC BY 4.0 (атрибуция «Meshy AI» в `disclaim.credits`,
см. CREDITS.md); риг/анимации/карточки — CC0.

## Проверка

Godot 4.6.1: 8/8 сцен грузятся, 4 клипа у каждого (после сжатия текстур
до 1024 — перепроверено). Масштабы: kremen 1.4 м … kosar 3.1 м, origin в
лапах (Y=0). Клипы walk процедурные — скорость подгоняется на месте через
`speed_scale` (схема из README химеры: игровая 5.0 м/с × speed-стат вида;
начальная прикидка: speed_scale ≈ 1.2–1.8, сверить глазами в бою).
