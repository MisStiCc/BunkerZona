extends SceneTree

func _init() -> void:
        var path := 'res://inbox/fx_test/kostolom_anim.glb'
        var args := OS.get_cmdline_user_args()
        if args.size() > 0:
                path = args[0]
        var ps: PackedScene = load(path)
        if ps == null:
                print('FAIL ', path)
                quit(1)
                return
        var node := ps.instantiate()
        var found: Array = []
        var stack: Array = [node]
        while not stack.is_empty():
                var n: Node = stack.pop_back()
                if n is AnimationPlayer:
                        found = (n as AnimationPlayer).get_animation_list()
                for c in n.get_children():
                        stack.push_back(c)
        print(path.get_file(), ' -> клипов ', found.size(), ': ', ', '.join(found))
        node.free()
        quit(0)
