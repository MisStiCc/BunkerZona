# tools/check_all_scripts.gd
extends SceneTree

## Полный синтакс-чек всех GDScript-файлов проекта (v0.31.0).
## Загружает каждый .gd — при parse-ошибке вернёт null и напечатает путь.
## Запуск: godot --headless --path . -s res://tools/check_all_scripts.gd

func _initialize() -> void:
        var errors: PackedStringArray = []
        var count := 0
        for path in _list_gd("res://"):
                if path.contains("/addons/") or path.contains("/skills/") or path.contains("/media/") \
                                or path.contains("/android/build/") or path.contains("/game_src/") \
                                or path.contains("/download/") or path.contains("/upload/"):
                        continue
                count += 1
                var res = load(path)
                if res == null:
                        errors.append(path)
        print("CHECKED=%d ERRORS=%d" % [count, errors.size()])
        for e in errors:
                print("ERR: ", e)
        quit(0 if errors.is_empty() else 1)


func _list_gd(dir_path: String) -> PackedStringArray:
        var out: PackedStringArray = []
        var dir := DirAccess.open(dir_path)
        if dir == null:
                return out
        dir.list_dir_begin()
        var f := dir.get_next()
        while f != "":
                var full := dir_path.path_join(f)
                if dir.current_is_dir():
                        if not f.begins_with("."):
                                out.append_array(_list_gd(full))
                elif f.ends_with(".gd"):
                        out.append(full)
                f = dir.get_next()
        dir.list_dir_end()
        return out
