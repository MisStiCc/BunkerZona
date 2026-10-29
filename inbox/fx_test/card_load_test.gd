extends SceneTree
## Тест загрузки карточек: какой путь даёт card_icon_path и что реально грузится.

func _init() -> void:
        var G := load('res://data/gacha_data.gd')
        var types := ['chimera', 'pseudodog', 'alpha_pseudodog', 'crimson_chimera', 'ash_tornado', 'battery_artifact']
        for t in types:
                var is_mut: bool = not t.ends_with('_artifact')
                var path: String = G.call('card_icon_path', t, is_mut)
                var tex: Texture2D = load(path)
                var sz := 'FAIL'
                if tex and tex.get_image():
                        sz = str(tex.get_image().get_width()) + 'x' + str(tex.get_image().get_height())
                elif tex:
                        sz = str(tex.get_width()) + 'x' + str(tex.get_height())
                print(t, ' -> ', path, ' | загрузилось: ', sz)
        quit(0)
