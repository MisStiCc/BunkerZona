extends Control
## Съёмка экрана Врата ярусов с тестовыми данными (инструмент пака fx_test).

func _ready() -> void:
        var tg := TierGates.new()
        tg.set_anchors_preset(Control.PRESET_FULL_RECT)
        add_child(tg)
        var names := ['«Корни»', '«Трубы»', '«Свалка»', '«Реактор»', '«Припять»',
                '«Радар»', '«Антенна»', '«Саркофаг»', '«Подвал»', '«Монолит»']
        var bosses := ['Смотритель корней', 'Хозяин труб', 'Король свалки', 'Дитя реактора',
                'Эхо Припяти', 'Голос радара', 'Паук антенны', 'Сердце саркофага',
                'Тот, кто внизу', 'Монолит']
        var stars := [7, 13, 21, 0, 0, 0, 0, 0, 0, 0]
        tg.setup(25, names, stars, bosses, 1)
        var args := OS.get_cmdline_user_args()
        var out := args[0] if args.size() > 0 else 'C:/tmp/fx_shots/tg_test.png'
        await get_tree().create_timer(1.2).timeout
        await RenderingServer.frame_post_draw
        get_viewport().get_texture().get_image().save_png(out)
        print('снято: ', out)
        get_tree().quit(0)
