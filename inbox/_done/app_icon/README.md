# Иконка приложения и лаунчер-набор Android (ЗАДАЧА 25)

## Что это

Фирменная иконка «Бункер: Зона» вместо дефолтного робота Godot: тёмный
графит, золотой трефойл радиации, болотное кольцо, мягкое свечение.
Процедурная графика, CC0 (CREDITS.md).

## Файлы

| Файл | Куда |
|---|---|
| `icon_256.png` | `config/icon` в project.godot (сейчас `res://icon.svg`) |
| `main_192x192.png` | export_presets.cfg → Android → `launcher_icons/main_192x192` |
| `adaptive_foreground_432x432.png` | → `launcher_icons/adaptive_foreground_432x432` (глиф в безопасной зоне 66%, прозрачный фон — лаунчер сам наложит маску) |
| `adaptive_background_432x432.png` | → `launcher_icons/adaptive_background_432x432` (тёмная текстура с болотным кольцом) |

## Как применить (рекомендация, не делал сам)

1. Файлы перенести в `assets/ui/` (или в корень).
2. project.godot: `config/icon="res://assets/ui/icon_256.png"`.
3. export_presets.cfg (пресет Android): в разделе `application/launcher_icons`
   прописать пути к трём файлам выше (сейчас там uid дефолтных заглушек).
4. Спрятать/удалить `icon.svg` не обязательно — просто перестанет
   использоваться.
5. Проверка: собрать APK, посмотреть иконку на рабочем столе Android
   (круглая/квадратная маска — адаптивные слои подгонятся сами).

Генератор: `gen_app_icon.py` (PIL/numpy, детерминированный).
