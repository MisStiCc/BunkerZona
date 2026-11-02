extends Node

## Тест D25: ПОЧТА + сезоны арены (эталон — test_event_hub.gd).
## Проверяет: rollover прошлого сезона (сброс полей + письмо), отсутствие
## повторного rollover в том же сезоне, ОТСУТСТВИЕ пинг-понга ключей при
## MailOverlay.open() (старый баг: две схемы "S2"/"S9"), забор письма,
## note_season_wave. Сейв владельца снапшотится и ВОССТАНАВЛИВАЕТСЯ.
## Маркеры: MAIL_ROLLOVER / MAIL_LETTER / MAIL_NO_DUP / MAIL_OVERLAY /
## MAIL_CLAIM / MAIL_WAVES / MAIL_TEST_PASS|FAIL.

func _ready() -> void:
	await get_tree().create_timer(1.0).timeout
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm == null:
		print("MAIL_TEST_FAIL: нет game_manager")
		get_tree().quit()
		return
	var had_save: bool = gm.current_save_data != null
	if gm.current_save_data == null:
		gm.current_save_data = load("res://data/save_data.gd").new()
	var sd = gm.current_save_data
	if sd.lab_data == null:
		sd.lab_data = load("res://data/lab_data.gd").new()

	# --- снапшот затрагиваемых полей (гранты пишут сейв — вернём как было)
	var snap := {
		"key": sd.lab_data.arena_season_key,
		"waves": sd.lab_data.arena_season_waves,
		"medals": sd.lab_data.arena_medals_claimed.duplicate(),
		"tasks": sd.lab_data.arena_season_tasks_claimed.duplicate(),
		"wc": sd.lab_data.arena_wins_challenge,
		"wd": sd.lab_data.arena_wins_defense,
		"mail": sd.guild_state.get("mail", []).duplicate(true),
		"rolls_mut": sd.lab_data.gacha_rolls_mutants,
		"rolls_art": sd.lab_data.gacha_rolls_artifacts,
		"sparks": sd.lab_data.awaken_sparks,
		"biomass": sd.lab_data.biomass,
		"owned": sd.owned.duplicate(true),
	}
	var ok := true

	# --- 0) чистые проверки БЕЗ мутаций сейва (первыми: если упадут —
	#     рестор ниже не нужен, сейв нетронут): титул недели финала —
	#     календарь слот 25 + форс-гейт показывают «ПОЛУГОДИЕ ЗОНЫ»,
	#     механика = база zharva (fix SCHEDULE out-of-bounds тоже здесь)
	var fin: Dictionary = EventsData._calendar_event(25 * 604800)
	ok = ok and str(fin.get("id", "")) == "finale"
	ok = ok and str(fin.get("base", "")) == "zharva"
	ok = ok and str(fin.get("title_ru", "")) == "ПОЛУГОДИЕ ЗОНЫ"
	var mid: Dictionary = EventsData._calendar_event(29 * 604800)
	ok = ok and str(mid.get("id", "")) == "uley"    # неделя 29: слот 3 -> пара 1
	print("MAIL_FINALE title=", fin.get("title_ru", ""), " base=", fin.get("base", ""))

	# --- 1) rollover: имитируем прошлый сезон (топ-волны, медали закрыты);
	# волны 60+3*idx гарантированно бьют топ таблицы лиг при любой дате
	var idx: int = ArenaSeason.season_info()["idx"]
	sd.lab_data.arena_season_key = "S%d" % (idx - 1)
	sd.lab_data.arena_season_waves = 60 + 3 * idx
	sd.lab_data.arena_medals_claimed = {0: true, 3: true}
	sd.lab_data.arena_season_tasks_claimed = {1: true}
	sd.lab_data.arena_wins_challenge = 4
	sd.lab_data.arena_wins_defense = 2
	var res: Dictionary = ArenaSeason.ensure_season(sd)
	ok = ok and not res.is_empty()
	var place: int = int(res.get("place", -1))
	ok = ok and place == 1
	print("MAIL_ROLLOVER place=", place, " reward=", JSON.stringify(res.get("reward", {})))
	var key_now: String = ArenaSeason.season_key()
	ok = ok and sd.lab_data.arena_season_key == key_now
	ok = ok and sd.lab_data.arena_season_waves == 0
	ok = ok and sd.lab_data.arena_medals_claimed.is_empty()
	ok = ok and sd.lab_data.arena_season_tasks_claimed.is_empty()
	ok = ok and sd.lab_data.arena_wins_challenge == 0 and sd.lab_data.arena_wins_defense == 0
	var mail: Array = sd.guild_state.get("mail", [])
	ok = ok and mail.size() == snap["mail"].size() + 1
	var letter: Dictionary = mail[0] if mail.size() > 0 else {}
	ok = ok and str(letter.get("title_ru", "")).begins_with("ИТОГИ СЕЗОНА")
	ok = ok and not bool(letter.get("claimed", true))
	print("MAIL_LETTER title=", letter.get("title_ru", ""), " ok=", ok)

	# --- 2) повторный rollover в том же сезоне — пустой, письмо одно
	var res2: Dictionary = ArenaSeason.ensure_season(sd)
	ok = ok and res2.is_empty()
	ok = ok and sd.guild_state.get("mail", []).size() == mail.size()
	print("MAIL_NO_DUP ok=", ok)

	# --- 3) MailOverlay.open() НЕ делает второй rollover (пинг-понг S2/S9)
	var overlay: Control = load("res://ui/lab/mail_overlay.gd").new()
	add_child(overlay)
	overlay.open()
	await get_tree().create_timer(0.3).timeout
	ok = ok and sd.lab_data.arena_season_key == key_now
	ok = ok and sd.guild_state.get("mail", []).size() == mail.size()
	var cards: int = overlay._list.get_children().size()
	ok = ok and cards == mail.size()
	print("MAIL_OVERLAY cards=", cards, " key=", sd.lab_data.arena_season_key)

	# --- 4) забор письма: кнопку жать некому — зовём обработчик напрямую
	var rew: Dictionary = letter.get("reward", {})
	var rolls_before: int = sd.lab_data.gacha_rolls_mutants
	var art_before: int = sd.lab_data.gacha_rolls_artifacts
	overlay._on_claim(0)
	var letter2: Dictionary = sd.guild_state.get("mail", [])[0]
	ok = ok and bool(letter2.get("claimed", false))
	ok = ok and sd.lab_data.gacha_rolls_mutants == rolls_before + int(rew.get("rolls_mut", 0))
	ok = ok and sd.lab_data.gacha_rolls_artifacts == art_before + int(rew.get("rolls_art", 0))
	print("MAIL_CLAIM rolls+=", sd.lab_data.gacha_rolls_mutants - rolls_before,
		" art+=", sd.lab_data.gacha_rolls_artifacts - art_before)

	# --- 5) note_season_wave: хранится только лучшая оборона сезона
	ArenaSeason.note_season_wave(sd, 18)
	ArenaSeason.note_season_wave(sd, 6)
	ok = ok and sd.lab_data.arena_season_waves == 18
	print("MAIL_WAVES=", sd.lab_data.arena_season_waves)

	# --- 6) форс-гейт финала (титул «ПОЛУГОДИЕ ЗОНЫ» и там)
	var force_prev: String = EventsData.FORCE_EVENT
	EventsData.FORCE_EVENT = "finale"
	var forced: Dictionary = EventsData.current_event(int(Time.get_unix_time_from_system()))
	EventsData.FORCE_EVENT = force_prev
	ok = ok and str(forced.get("title_ru", "")) == "ПОЛУГОДИЕ ЗОНЫ"
	ok = ok and str(forced.get("base", "")) == "zharva"

	# --- восстановление сейва владельца (гранты успели сохранить — перезапишем)
	sd.lab_data.arena_season_key = snap["key"]
	sd.lab_data.arena_season_waves = snap["waves"]
	sd.lab_data.arena_medals_claimed = snap["medals"]
	sd.lab_data.arena_season_tasks_claimed = snap["tasks"]
	sd.lab_data.arena_wins_challenge = snap["wc"]
	sd.lab_data.arena_wins_defense = snap["wd"]
	sd.guild_state["mail"] = snap["mail"]
	sd.lab_data.gacha_rolls_mutants = snap["rolls_mut"]
	sd.lab_data.gacha_rolls_artifacts = snap["rolls_art"]
	sd.lab_data.awaken_sparks = snap["sparks"]
	sd.lab_data.biomass = snap["biomass"]
	sd.owned = snap["owned"]
	if had_save:
		gm.save_to_active_slot()
	print("MAIL_TEST_", "PASS" if ok else "FAIL")
	get_tree().quit()
