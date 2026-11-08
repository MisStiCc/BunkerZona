extends SceneTree
func _init() -> void:
        for t in [["mut_dog_mutant", true], ["art_spark_artifact", false], ["art_clock_artifact", false], ["mut_flesh", true]]:
                var p: String = GachaData.card_icon_path(t[0], t[1])
                print(t[0], ' -> ', p, ' | exists=', ResourceLoader.exists(p))
        quit(0)
