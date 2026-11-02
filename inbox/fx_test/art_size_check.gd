extends SceneTree

func _init() -> void:
        for key in ['clock', 'weight', 'hourglass', 'gas_bottle', 'common', 'chrevo']:
                var path := 'res://models/artifacts/artifact_%s.glb' % key
                var ps: PackedScene = load(path)
                if ps == null:
                        print(key, ' FAIL')
                        continue
                var node := ps.instantiate()
                var mn := Vector3(1e9, 1e9, 1e9)
                var mx := Vector3(-1e9, -1e9, -1e9)
                var stack: Array = [node]
                while not stack.is_empty():
                        var n: Node = stack.pop_back()
                        if n is MeshInstance3D:
                                var ab: AABB = (n as MeshInstance3D).global_transform * (n as MeshInstance3D).get_aabb()
                                mn = mn.min(ab.position)
                                mx = mx.max(ab.end)
                        for c in n.get_children():
                                stack.push_back(c)
                print(key, ': ', (mx - mn))
                node.free()
        quit(0)
