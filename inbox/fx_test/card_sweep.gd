extends SceneTree
## Полный свип карточек: все типы игры -> card_icon_path -> загрузка текстуры.

func _init() -> void:
        var G := load('res://data/gacha_data.gd')
        var LR := load('res://data/mutant_roles_data.gd')
        var types_mut: Array = []
        var types_art: Array = []
        for rarity in G.get('MUTANT_POOL'):
                for e in G.get('MUTANT_POOL')[rarity]:
                        types_mut.append(str(e[0]))
        for ex in G.get('EXCLUSIVE_MUTANTS'):
                types_mut.append(str(ex['type']))
        for rarity in G.get('ARTIFACT_POOL'):
                for t in G.get('ARTIFACT_POOL')[rarity]:
                        types_art.append(str(t))
        for ax in G.get('EXCLUSIVE_ANOMALIES'):
                types_art.append(str(ax['type']))
        var ok := 0
        var fail: Array = []
        var small: Array = []
        for t in types_mut:
                var path: String = G.call('card_icon_path', t, true)
                var tex: Texture2D = load(path)
                if tex == null:
                        fail.append(path)
                        continue
                ok += 1
                if tex.get_width() < 400:
                        small.append(path + ' ' + str(tex.get_width()))
        for t in types_art:
                var path: String = G.call('card_icon_path', t, false)
                var tex: Texture2D = load(path)
                if tex == null:
                        fail.append(path)
                        continue
                ok += 1
                if tex.get_width() < 400:
                        small.append(path + ' ' + str(tex.get_width()))
        print('загружено: ', ok, ' | НЕ грузятся: ', fail)
        print('мелкие (<400px = svg/заглушки): ', small)
        quit(0)
