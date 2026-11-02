extends SceneTree

func _init() -> void:
        var ps: PackedScene = load('res://inbox/fx_test/chimera_rig_anim.glb')
        if ps == null:
                print('FAIL')
                quit(1)
                return
        var node := ps.instantiate()
        print('сцена ок: ', node.name)
        var found: Array = []
        var stack: Array = [node]
        while not stack.is_empty():
                var n: Node = stack.pop_back()
                if n is AnimationPlayer:
                        found = (n as AnimationPlayer).get_animation_list()
                for c in n.get_children():
                        stack.push_back(c)
        print('клипы (', found.size(), '): ', ', '.join(found))
        node.free()
        quit(0)
