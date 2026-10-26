extends SceneTree
## Растеризация карточек в PNG для визуальной проверки (инструмент пака, игрой не используется).

const OUT_DIR := 'C:/tmp/card_previews'
const NAMES := [
	'mut_pseudodog', 'mut_alpha_pseudodog', 'mut_ten_pseudodog', 'mut_lutiy_pseudodog',
	'mut_dog_mutant', 'mut_dvoroviy_pes', 'mut_besheniy_pes',
	'mut_flesh', 'mut_tuhlaya_plot', 'mut_tolstaya_plot',
	'mut_zombie', 'mut_gniloy_zombie',
	'mut_snork_mutant', 'mut_ash_snork', 'mut_brodyashiy_snork', 'mut_krovaviy_snork',
	'mut_controller_mutant', 'mut_obsidian_controller', 'mut_psi_controller',
	'mut_poltergeist', 'mut_mercayushiy_poltergeist',
	'mut_bloodsucker', 'mut_nochnoy_krovosos',
	'mut_chimera', 'mut_crimson_chimera',
	'mut_pseudogiant', 'mut_obsidian_titan',
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var ok := 0
	for n in NAMES:
		var tex: Texture2D = load('res://ui/cards/%s.svg' % n)
		if tex == null:
			push_error('нет текстуры ' + n)
			continue
		var img := tex.get_image()
		if img == null:
			push_error('нет картинки ' + n)
			continue
		img.save_png('%s/%s.png' % [OUT_DIR, n])
		ok += 1
	print('растеризовано: ', ok, '/', NAMES.size())
	quit(0)
