# Вторая восьмёрка мутантов — промпты и план (волна 3)

## Что это

Промпты Шедеврума v3 (`shedevrum_prompts_v3.txt`) + проект блока данных
под пачки. Конвейер тот же, что у волны 2 (задача 43): Шедеврум → Meshy
image-to-3D → подготовщик собирает GLB (риг по классу силуэта, 4 клипа,
карточки, аватарки, HUD-иконки).

## Состав волны (дыры пулов закрыты)

Первая восьмёрка: 3 uncommon / 2 rare / 1 epic / 2 legendary — перекос
в низкие редкости. Волна 3: **1 uncommon / 3 rare / 3 epic / 1 legendary**,
по 2 на роль.

| id | Имя | Роль | Редкость | Силуэт | Класс рига (для сборки) |
|---|---|---|---|---|---|
| vagonchik | Вагончик | ТАНК | epic | бытовка-дом на 4 стальных лапах, окно-глаз, труба | quad (низкий, тяжёлый) |
| zatvor | Затвор | ТАНК | rare | бетонный голем с плитой-щитом | humanoid-block |
| plakun | Плакун | ЛЕЧ | rare | ива-хранитель, светящиеся лозы-капельницы | tree (ствол + крона) |
| nastoinik | Настойник | ЛЕЧ | epic | латунный аптекарь-самовар, пар, кран | pot (кувшин на ножках) |
| plevun | Плевун | УРОН | epic | каменно-изумрудная жаба, гейзер на спине | quad (широкая) |
| poluden | Полуденник | УРОН | legendary | парящая бронзовая маска-линза, копьё-луч | floater (hover) |
| kostrovik | Костровик | БАФ | rare | дух костра на бронзовых козлиных ногах | stalk (конус на ногах) |
| zvonar | Звонарь | БАФ | uncommon | бронзовый колокол на лапах, глаз-язык | bell (купол на лапах) |

## Блок данных (draft, paste-ready при сборке — ключи под схему з.43)

```gdscript
const NEW_ORIGINALS_W3 := [
	{"id": "vagonchik", "name_ru": "Вагончик", "role": "TANK", "rarity": "epic",
		"gate": 38, "hp": 2.2, "dmg": 0.5, "speed": 0.8, "family": "construct"},
	{"id": "zatvor", "name_ru": "Затвор", "role": "TANK", "rarity": "rare",
		"gate": 24, "hp": 1.9, "dmg": 0.7, "speed": 0.9, "family": "construct"},
	{"id": "plakun", "name_ru": "Плакун", "role": "HEAL", "rarity": "rare",
		"gate": 20, "hp": 1.0, "dmg": 0.5, "speed": 0.9, "family": "flora"},
	{"id": "nastoinik", "name_ru": "Настойник", "role": "HEAL", "rarity": "epic",
		"gate": 36, "hp": 1.1, "dmg": 0.55, "speed": 0.9, "family": "construct"},
	{"id": "plevun", "name_ru": "Плевун", "role": "DMG", "rarity": "epic",
		"gate": 32, "hp": 0.95, "dmg": 1.4, "speed": 1.0, "family": "acid"},
	{"id": "poluden", "name_ru": "Полуденник", "role": "DMG", "rarity": "legendary",
		"gate": 48, "hp": 0.85, "dmg": 1.7, "speed": 1.2, "family": "light"},
	{"id": "kostrovik", "name_ru": "Костровик", "role": "BUFF", "rarity": "rare",
		"gate": 28, "hp": 0.95, "dmg": 0.6, "speed": 1.05, "family": "fire"},
	{"id": "zvonar", "name_ru": "Звонарь", "role": "BUFF", "rarity": "uncommon",
		"gate": 14, "hp": 1.05, "dmg": 0.5, "speed": 0.95, "family": "ritual"},
]
```

## Что делаю я после твоей генерации (как в волне 2)

1. Ты генеришь картинки в Шедевруме (1:1, смотри промпты v3; если
   площадка откажет — скажи номер, перепишу конкретный).
2. Meshy image-to-3D по отобранным картинкам, выкладываешь файлы как в
   волне 2: `inbox/new_mutants_wave3/models/<id>/` (fbx + текстуры).
3. Я собираю: нормализация, риг по классу, 4 клипа, GLB + карточки +
   аватарки + HUD-иконки + бейдж роли, Godot-проверка, README.
