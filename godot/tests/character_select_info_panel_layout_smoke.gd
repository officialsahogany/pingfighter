extends SceneTree

const CharacterSelectData := preload("res://scripts/ui/character_select_data.gd")
const CharacterSelectScreen := preload("res://scripts/ui/character_select_screen.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

var _failures: Array[String] = []
var _language_settings_snapshot: Dictionary = {}


func _init() -> void:
	_language_settings_snapshot = _snapshot_settings_file(LanguageSettings.SETTINGS_PATH)
	LanguageSettings.set_language(LanguageSettings.LANGUAGE_KOREAN)

	var screen: Control = CharacterSelectScreen.new()
	screen.size = Vector2(1920.0, 1080.0)
	var characters: Array = CharacterSelectData.get_characters()
	var font := ThemeDB.fallback_font

	var hangul := RegEx.new()
	hangul.compile("[가-힣]")

	# 1) Desktop info panel: the full-body rect stays inside the panel and the
	# lore microstat rows resolve for every roster character.
	var desktop_panel := Rect2(Vector2.ZERO, Vector2(690.0, 1360.0))
	for character_value in characters:
		if not character_value is Dictionary:
			continue
		var character: Dictionary = character_value
		var character_id := str(character.get("id", ""))
		var layout: Dictionary = screen.call("_build_info_panel_layout", desktop_panel, character, font)
		var full_body: Rect2 = layout.get("full_body_rect", Rect2())
		_expect(full_body.has_area(), "desktop panel should keep the full-body rect for %s" % character_id)
		_expect(desktop_panel.encloses(full_body), "full-body rect must stay inside the info panel for %s" % character_id)
		var rows: Array = screen.call("_full_body_microstat_rows", character)
		_expect(rows.size() == 3, "HEIGHT/WEIGHT/AFFILIATION microstat rows should resolve for %s" % character_id)
		var latin := str(character.get("name_latin", ""))
		_expect(latin != "" and hangul.search(latin) == null, "name_latin should be a Latin editorial pairing for %s" % character_id)

	# 2) Cramped (mobile-height) panel: the full-body rect must yield (drop)
	# instead of escaping below the panel onto the card column.
	var cramped_panel := Rect2(Vector2(34.0, 432.0), Vector2(832.0, 250.0))
	var first_character: Dictionary = characters[0]
	var cramped_layout: Dictionary = screen.call("_build_info_panel_layout", cramped_panel, first_character, font)
	var cramped_full_body: Rect2 = cramped_layout.get("full_body_rect", Rect2())
	_expect(not cramped_full_body.has_area(), "cramped info panel must drop the full-body rect instead of escaping the panel")

	# 2b) Row budget: blocks that would overflow a cramped panel must report
	# not-visible, while the desktop panel keeps every block.
	var desktop_layout: Dictionary = screen.call("_build_info_panel_layout", desktop_panel, first_character, font)
	var desktop_blocks: Dictionary = screen.call("_info_panel_visible_blocks", desktop_panel, desktop_layout, true)
	for block_key_value in ["name", "tagline", "description", "difficulty", "skills"]:
		var block_key := str(block_key_value)
		_expect(bool(desktop_blocks.get(block_key, false)), "desktop info panel should show the %s block" % block_key)
	var tight_panel := Rect2(Vector2(34.0, 304.0), Vector2(832.0, 82.0))
	var tight_layout: Dictionary = screen.call("_build_info_panel_layout", tight_panel, first_character, font)
	var tight_blocks: Dictionary = screen.call("_info_panel_visible_blocks", tight_panel, tight_layout, true)
	_expect(not bool(tight_blocks.get("skills", true)), "82px info panel must drop the skills row instead of overflowing")
	_expect(not bool(tight_blocks.get("description", true)), "82px info panel must drop the description block instead of overflowing")

	# 3) Missing lore fields -> rows omitted entirely (no placeholder rows).
	var bare_rows: Array = screen.call("_full_body_microstat_rows", {"id": "bare"})
	_expect(bare_rows.is_empty(), "characters without lore fields must not emit microstat rows")

	# 4) Mobile stacked layout: preview / info / action-bar row / card column
	# must never overlap pairwise (Slice A pixel-QA findings (b)/(c)).
	for mobile_size_value in [Vector2(900.0, 700.0), Vector2(900.0, 1200.0), Vector2(560.0, 900.0), Vector2(420.0, 800.0), Vector2(560.0, 700.0), Vector2(420.0, 700.0), Vector2(420.0, 600.0)]:
		var mobile_size: Vector2 = mobile_size_value
		screen.size = mobile_size
		var size_tag := "%dx%d" % [int(mobile_size.x), int(mobile_size.y)]
		var preview: Rect2 = screen.call("_preview_rect", mobile_size)
		var info: Rect2 = screen.call("_info_panel_rect", mobile_size, preview)
		var column: Rect2 = screen.call("_card_column_rect", mobile_size)
		var bar: Dictionary = screen.call("_action_bar_layout", mobile_size)
		var confirm: Rect2 = bar.get("confirm", Rect2())
		var junior: Rect2 = bar.get("junior", Rect2())
		var mythic: Rect2 = bar.get("mythic", Rect2())
		_expect(not preview.intersects(info), "preview must not overlap the info panel at %s" % size_tag)
		_expect(not preview.intersects(confirm), "preview must not overlap the confirm button at %s" % size_tag)
		_expect(not preview.intersects(junior) and not preview.intersects(mythic), "preview must not overlap the league tabs at %s" % size_tag)
		_expect(not info.intersects(column), "info panel must not overlap the card column at %s" % size_tag)
		_expect(not confirm.intersects(column), "confirm button must not overlap the card column at %s" % size_tag)
		_expect(not confirm.intersects(info), "confirm button must not overlap the info panel at %s" % size_tag)
		_expect(not confirm.intersects(mythic), "confirm button must not overlap the mythic league tab at %s" % size_tag)
		_expect(not confirm.intersects(junior), "confirm button must not overlap the junior league tab at %s" % size_tag)
		_expect(not junior.intersects(column) and not mythic.intersects(column), "league tabs must not overlap the card column at %s" % size_tag)
		_expect(confirm.position.x >= 0.0 and confirm.end.x <= mobile_size.x, "confirm button must stay inside the view at %s" % size_tag)

	# 5) Lore fields must localize in every non-Korean language map — the
	# character map override is a whitelist, so a missing entry leaks Korean.
	var languages := [
		LanguageSettings.LANGUAGE_ENGLISH,
		LanguageSettings.LANGUAGE_CHINESE,
		LanguageSettings.LANGUAGE_JAPANESE,
		LanguageSettings.LANGUAGE_SPANISH,
		LanguageSettings.LANGUAGE_PORTUGUESE_BRAZIL,
		LanguageSettings.LANGUAGE_RUSSIAN,
	]
	for language_value in languages:
		var language := str(language_value)
		LanguageSettings.set_language(language)
		var localized: Array = LanguageSettings.localize_character_list(CharacterSelectData.get_characters())
		for character_value in localized:
			if not character_value is Dictionary:
				continue
			var character: Dictionary = character_value
			for lore_key_value in ["lore_height", "lore_weight", "lore_affiliation"]:
				var lore_key := str(lore_key_value)
				var lore_text := str(character.get(lore_key, ""))
				_expect(
					hangul.search(lore_text) == null,
					"%s should not leak Korean in %s for %s" % [lore_key, language, str(character.get("id", ""))]
				)

	# 5b) D7 개정: restored full-body rail — visible and non-overlapping on a
	# wide desktop, yielding entirely on a narrow desktop (hero keeps 560px).
	screen.size = Vector2(1920.0, 1080.0)
	var wide := Vector2(1920.0, 1080.0)
	var rail_wide: Rect2 = screen.call("_full_body_rail_rect", wide)
	var preview_wide: Rect2 = screen.call("_preview_rect", wide)
	_expect(rail_wide.has_area(), "full-body rail should be visible on a wide desktop")
	_expect(not rail_wide.intersects(preview_wide), "full-body rail must not overlap the hero preview")
	_expect(rail_wide.end.x <= wide.x, "full-body rail must stay inside the view")
	var narrow_desktop := Vector2(1000.0, 900.0)
	var rail_narrow: Rect2 = screen.call("_full_body_rail_rect", narrow_desktop)
	_expect(not rail_narrow.has_area(), "full-body rail should yield on a narrow desktop so the hero keeps its minimum width")

	# 6) v2 roster card (Slice H tall-card geometry): every localized role tag
	# must fit the card text area at the minimum desktop column width WITHOUT
	# ellipsizing (Codex G1 review memo). 90px = min card width (230) minus the
	# half-panel portrait (101), text inset (17), glyph (14), and margin (8).
	var role_tag_budget := 90.0
	for language_value in languages + [LanguageSettings.LANGUAGE_KOREAN]:
		var language := str(language_value)
		LanguageSettings.set_language(language)
		for character_value in LanguageSettings.localize_character_list(CharacterSelectData.get_characters()):
			if not character_value is Dictionary:
				continue
			var character: Dictionary = character_value
			var role_text := str(character.get("role", ""))
			if role_text.strip_edges() == "":
				continue
			var tag_spec: Dictionary = screen.call("_role_tag_draw_spec", role_text, role_tag_budget)
			_expect(
				str(tag_spec.get("text", "")) == role_text.strip_edges(),
				"role tag should fit without ellipsis at min column width for %s/%s" % [language, str(character.get("id", ""))]
			)

	screen.free()
	_restore_language_settings_snapshot()

	if _failures.is_empty():
		print("character_select_info_panel_layout_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _snapshot_settings_file(path: String) -> Dictionary:
	var had_original := FileAccess.file_exists(path)
	var original_bytes := PackedByteArray()
	if had_original:
		original_bytes = FileAccess.get_file_as_bytes(path)
	return {
		"had": had_original,
		"bytes": original_bytes,
	}


func _restore_language_settings_snapshot() -> void:
	if _language_settings_snapshot.is_empty():
		return
	if bool(_language_settings_snapshot.get("had", false)):
		var file := FileAccess.open(LanguageSettings.SETTINGS_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(_language_settings_snapshot.get("bytes", PackedByteArray()))
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LanguageSettings.SETTINGS_PATH))
	LanguageSettings.reset_cache_for_tests()
	LanguageSettings.apply_saved_language()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
