extends SceneTree
## Проверка: анимированный glb из Blender грузится в Godot.

func _init() -> void:
        var ps: PackedScene = load('res://inbox/fx_test/echo_crystal.glb')
        if ps == null:
                print('FAIL: сцена не загрузилась')
                quit(1)
                return
        var node := ps.instantiate()
        print('сцена ок: ', node.name, ' | детей: ', node.get_child_count())
        _walk(node, 0)
        quit(0)


func _walk(n: Node, depth: int) -> void:
        print('  '.repeat(depth), n.name, ' (', n.get_class(), ')')
        if n is AnimationPlayer:
                var ap := n as AnimationPlayer
                print('  '.repeat(depth), '  анимации: ', ap.get_animation_list())
        for c in n.get_children():
                _walk(c, depth + 1)
