# CREDITS — new_mutants

## Модели (models_anim/*.glb) — v2, Meshy AI

8 моделей сгенерированы ВЛАДЕЛЬЦЕМ проекта в Meshy AI (image-to-3D из
промптов Шедеврума v2 — файл `shedevrum_prompts.txt`, все тексты
оригинальные). Тариф Meshy (бесплатный) — **CC BY 4.0**: атрибуция
«Модели созданы в Meshy AI» должна попасть в `disclaim.credits`
(новый CC-BY = бамп флага acknowledged_N по правилам ребрендинга).

Риг, анимации (idle/walk/attack/death), нормализация масштаба, децимация
и сборка GLB — процедурные, агент-подготовщик, Blender 4.5 bpy, CC0.

## Карточки (cards/*.png, cards/gray/*.png)

Рендеры тех же моделей (Cycles) + композ PIL (градиент роли, свечение,
рамка редкости). Оригинальные ассеты, CC0.

## Прочее

Скрипты конвейера (`build_meshy_batch.py`, `render_meshy_*.py`,
`compose_cards.py`) — оригинальные, CC0. Исходники Meshy (FBX+PBR) —
в `models/<имя>/`, лицензия та же CC BY 4.0 (Meshy).
