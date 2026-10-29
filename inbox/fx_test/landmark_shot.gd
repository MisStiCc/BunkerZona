extends Node3D
## Съёмка ориентира: авто-обрамление камеры по AABB.

func _ready() -> void:
        var args := OS.get_cmdline_user_args()
        var scene_path := args[0]
        var out := args[1]
        var packed: PackedScene = load(scene_path)
        var node := packed.instantiate()
        add_child(node)
        # AABB по всем мешам
        var aabb := AABB()
        var first := true
        var stack: Array = [node]
        while not stack.is_empty():
                var n: Node = stack.pop_back()
                if n is MeshInstance3D:
                        var ab: AABB = (n as MeshInstance3D).get_aabb()
                        var xf: Transform3D = (n as MeshInstance3D).global_transform
                        if xf.origin == Vector3.ZERO and n.transform == Transform3D.IDENTITY:
                                ab = ab
                        var corners := [
                                ab.position, ab.end,
                                Vector3(ab.position.x, ab.position.y, ab.end.z),
                                Vector3(ab.position.x, ab.end.y, ab.position.z),
                                Vector3(ab.end.x, ab.position.y, ab.position.z),
                                Vector3(ab.end.x, ab.position.y, ab.end.z),
                                Vector3(ab.position.x, ab.end.y, ab.position.z),
                                Vector3(ab.end.x, ab.end.y, ab.position.z)]
                        for c in corners:
                                var wp: Vector3 = xf * c
                                if first:
                                        aabb = AABB(wp, Vector3.ZERO)
                                        first = false
                                else:
                                        aabb = aabb.expand(wp)
                for ch in n.get_children():
                        stack.push_back(ch)
        var cam := Camera3D.new()
        add_child(cam)
        cam.current = true
        var center := aabb.get_center()
        var dist: float = maxf(aabb.size.x, aabb.size.y) * 1.35 + aabb.size.z * 0.5
        cam.position = center + Vector3(dist * 0.5, aabb.size.y * 0.22, dist * 0.85)
        cam.look_at(center)
        cam.far = dist * 8.0 + 500.0
        await get_tree().create_timer(0.8).timeout
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(out)
        print('снято: ', out, ' aabb=', aabb.size)
        get_tree().quit(0)
