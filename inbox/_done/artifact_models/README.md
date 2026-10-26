# 3D-модели артефактов (ЗАДАЧА 13)

## Что это

20 CC0/CC-BY моделей под все типы артефактов из `entities/artifacts/`
(сейчас все — SphereMesh r=0.3, на карте неотличимы). Нормализация как в
pripyat_props, но **origin в геометрическом центре** (артефакты парят и
качаются) и **максимальный габарит 0.5 м** (в масштаб сферы r=0.3).

## Соответствие тип → модель

| Файл (models/) | Тип артефакта | Модель | Автор | Лицензия |
|---|---|---|---|---|
| artifact_common.glb | common | Mineral (кристалл) | Quaternius | CC0 |
| artifact_rare.glb | rare | Gem Blue | Quaternius | CC0 |
| artifact_spark.glb | spark | Gem Green | Quaternius | CC0 |
| artifact_energy.glb | energy | Gem Pink | Quaternius | CC0 |
| artifact_void.glb | void | Crystal | iPoly3D | CC0 |
| artifact_uranium.glb | uranium | Crystal 2 | iPoly3D | CC0 |
| artifact_graviton.glb | graviton | Planet (кольца) | Quaternius | CC0 |
| artifact_battery.glb | battery | Battery | Quaternius | CC0 |
| artifact_clock.glb | clock | Analog clock | Poly by Google | CC-BY |
| artifact_hourglass.glb | hourglass | Hourglass | Poly by Google | CC-BY |
| artifact_heart.glb | heart | Heart | Quaternius | CC0 |
| artifact_storm.glb | storm | Cloud | Quaternius | CC0 |
| artifact_flesh.glb | flesh | Steak | Quaternius | CC0 |
| artifact_acid_drop.glb | acid_drop | Drop water | moriarty | CC-BY |
| artifact_gas_bottle.glb | gas_bottle | Gas Can | Quaternius | CC0 |
| artifact_glowstick.glb | glowstick | Pickup Jar | Quaternius | CC0 |
| artifact_jumper.glb | jumper | Spring | Quaternius | CC0 |
| artifact_weight.glb | weight | Kettlebell | Poly by Google | CC-BY |
| artifact_fireball.glb | fireball | Comet | Poly by Google | CC-BY |
| artifact_slime.glb | slime | Pickup Sphere | Quaternius | CC0 |

Точные ссылки poly.pizza — в CREDITS.md.

## Как встроить (рекомендация, не делал сам)

1. Файлы перенести в `models/artifacts/` (или брать из inbox).
2. В `entities/artifacts/<type>.tscn` заменить меш `MeshInstance3D`
   (SphereMesh) на BoxMesh-заглушку НЕ нужно: проще в `base_artifact.gd`
   грузить `res://models/artifacts/artifact_<type>.glb` по типу и
   подменять `mesh_instance.mesh` у первого узла-инстанса.
3. **Внимание к тонировке**: `base_artifact` красит через
   `material_override` (albedo+emission одним цветом) — на моделях с
   несколькими материалами это зальёт всё одним тоном. Варианты:
   не переопределять материал у моделей (у них свои цвета), красить через
   `modulate`/само-`emission` у ShaderMaterial, или клонировать материал
   и подмешивать цвет. Решение за основным агентом.
4. Тяжелее всех `artifact_fireball.glb` (1.8 МБ, кометная текстура) —
   при нужде ужать до 0.3 МБ заменой текстуры, остальные 9–180 КБ.

## Проверка

Верифицировано скриптом (центр в origin ±0.03, maxdim 0.50 у всех 20);
пять представителей отрендерены реальным Vulkan-рендером (кристалл,
планета, гиря, сердце, часы) — материалы и силуэты на месте.
