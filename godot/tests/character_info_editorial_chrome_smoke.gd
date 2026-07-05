extends SceneTree

# Seals the character info overlay editorial chrome pass (pause-menu visual
# language shared into the TAB overlay): shared section chrome at every section
# panel, editorial map backdrop + corner brackets on the main frame, header
# chip/EN motif, and open()-time backdrop prewarm (hot-path lazy-init trap).

const CharacterInfoOverlay := preload("res://scripts/hud/character_info_overlay.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const CharacterInfoOverlayHeaderPresenter := preload("res://scripts/hud/character_info_overlay_header_presenter.gd")
const CharacterInfoOverlayLingpetPresenter := preload("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
const CharacterInfoOverlayLingpetTextureLoader := preload("res://scripts/hud/character_info_overlay_lingpet_texture_loader.gd")
const CharacterInfoOverlayOwnerState := preload("res://scripts/hud/character_info_overlay_owner_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_editorial_chrome()

	if _failures.is_empty():
		print("character_info_editorial_chrome_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_editorial_chrome() -> void:
	var core_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_core.gd")
	var lingpet_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_lingpet_presenter.gd")
	var frame_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_frame_presenter.gd")
	var header_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_header_presenter.gd")
	var drawer_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_texture_drawer.gd")

	_expect(core_source.count("CharacterInfoOverlayTextureDrawer.draw_section_chrome(") >= 6, "every core section panel should draw through the shared editorial section chrome")
	_expect(core_source.find("draw_panel(canvas, rect, SECTION_COLOR, SECTION_BORDER") < 0, "no core section should bypass the editorial chrome with a bare section panel")
	_expect(lingpet_source.find("CharacterInfoOverlayTextureDrawer.draw_section_chrome(") >= 0, "the lingpet section panel should draw through the shared editorial section chrome")
	_expect(drawer_source.find("static func draw_section_chrome(") >= 0, "the shared texture drawer should own the editorial section chrome helper")

	_expect(frame_source.find("_editorial_bg_texture") >= 0 and frame_source.find("draw_cover(") >= 0, "the main frame should draw the cached editorial map backdrop")
	_expect(frame_source.find("PremiumPanelFrame.draw_corner_brackets(") >= 0, "the main frame should draw editorial corner brackets")
	_expect(header_source.find("\"INFO\"") >= 0, "the header should draw the editorial EN motif next to the title")
	_expect(header_source.find("chip_top") < 0, "the header should not draw the retired skewed accent chip")
	_expect(drawer_source.find("chip_top") < 0, "section chrome should not draw the retired skewed accent chip")
	_expect(header_source.find("PremiumPanelFrame.draw_panel(canvas, badge_rect") >= 0, "the header should draw the character name badge capsule")
	_expect(CharacterInfoOverlayHeaderPresenter.subtitle(CharacterInfoOverlayOwnerState.character_display_name("", "viper"), "viper") == "세린  /  바이퍼", "the name badge should read personal name / class (viper = 세린 / 바이퍼)")
	_expect(CharacterInfoOverlayHeaderPresenter.subtitle(CharacterInfoOverlayOwnerState.character_display_name("스매셔", "smasher"), "smasher") == "미카  /  스매셔", "the class label leaking through the owner name field must not override the personal name")
	_expect(CharacterInfoOverlayOwnerState.character_display_name("", "soldier") == "레나" and CharacterInfoOverlayOwnerState.character_display_name("", "blacksmith") == "코하쿠" and CharacterInfoOverlayOwnerState.character_display_name("", "optimus") == "이오", "every class should resolve its personal name")
	_expect(CharacterInfoOverlayFormatter.character_type_label("blacksmith") == "발토르" and CharacterInfoOverlayFormatter.character_type_label("optimus") == "옵티머스", "blacksmith/optimus class labels should not fall back to 스매셔")
	_expect(core_source.find("\"NO PERKS OBTAINED\"") >= 0 and core_source.find("\"NO PASSIVE ITEMS OBTAINED\"") >= 0, "empty states should carry the EN/KR dual labels")
	_expect(core_source.find("LanguageSettings.get_language() != LanguageSettings.LANGUAGE_ENGLISH") >= 0, "the KR empty-state sub label should hide on the English locale")
	_expect(core_source.find("_draw_empty_state_hero(") >= 0, "empty perk/passive states should route through the imagegen hero helper")
	_expect(frame_source.find("empty_ringpet_hero_texture") >= 0 and lingpet_source.find("empty_ring_texture") >= 0, "the lingpet empty state should receive the crystal-egg hero texture")
	_expect(lingpet_source.find("_draw_paw_icon(") >= 0, "the lingpet section title should carry the paw icon")
	_expect(lingpet_source.find("var header_x: float = rect.position.x + 36.0") >= 0 and lingpet_source.find("\"링펫\", rect.position.x + 36.0") >= 0, "slot tabs must anchor at the same x the 링펫 title draws at — drifting anchors made the pet-name tab cover the section label")

	var perk_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_perk_presenter.gd")
	_expect(drawer_source.find("static func draw_hex_cell(") >= 0, "the shared texture drawer should own the hexagonal perk cell helper")
	_expect(perk_source.find("CharacterInfoOverlayTextureDrawer.draw_hex_cell(") >= 0, "perk grid cells should draw as hexagons")
	_expect(perk_source.find("LEVEL_BADGE_FILL") >= 0, "perk grid cells should carry the level badge chip")

	_expect(lingpet_source.find("_draw_aurora_backdrop(") >= 0, "the companion panel should draw the rotating aurora backdrop")
	_expect(lingpet_source.find("art_glow") < 0, "the companion panel should not stack the retired 4-ring circle glow over the aurora")
	_expect(lingpet_source.find("canvas.draw_polygon(_aurora_points, _aurora_colors, AURORA_UVS, texture)") >= 0, "the aurora should rotate via recomputed vertices with normalized UVs (tumble-immune)")
	_expect(FileAccess.file_exists(CharacterInfoOverlayLingpetTextureLoader.PANEL_AURORA_TEXTURE_PATH), "the aurora texture should ship")
	_expect(FileAccess.file_exists(CharacterInfoOverlayLingpetTextureLoader.PANEL_AURORA_TEXTURE_PATH + ".import"), "the aurora texture should ship its export-safe import file")
	var art_prewarm_paths: Array[String] = CharacterInfoOverlayLingpetTextureLoader._build_panel_art_prewarm_paths(["maribo"])
	_expect(art_prewarm_paths.has(CharacterInfoOverlayLingpetTextureLoader.PANEL_AURORA_TEXTURE_PATH), "the aurora texture should join the panel art prewarm set whenever any pet art prewarms")
	_expect(CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d({"state": "companion", "pet_id": "maribo"}), "every companion panel should keep redrawing so the aurora animates (not only live2d pets)")
	_expect(not CharacterInfoOverlayLingpetPresenter.should_redraw_panel_live2d({"state": "egg", "pet_id": ""}), "non-companion lingpet states should not force continuous redraw")

	var support_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_support.gd")
	var skill_slot_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_skill_slot_presenter.gd")
	var active_item_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_active_item_presenter.gd")
	_expect(support_source.find("_human_hologram_texture != null") >= 0, "the equipment silhouette should prefer the holographic human figure texture")
	_expect(support_source.find("_draw_equipment_hologram_part_highlight(") >= 0 and support_source.find("EQUIPMENT_HOLOGRAM_REGIONS") >= 0, "hovering an equipment slot should brighten the matching hologram body part region")
	_expect(drawer_source.find("static func draw_empty_slot_socket(") >= 0, "the shared texture drawer should own the machined empty-slot socket helper")
	_expect(skill_slot_source.find("draw_empty_slot_socket(") >= 0, "empty skill slots should draw the machined socket frame")
	_expect(active_item_source.find("draw_empty_slot_socket(") >= 0, "empty active item slots should draw the machined socket frame")
	_expect(frame_source.find("draw_cover(canvas, mystic_backdrop as Texture2D, panel_rect") >= 0, "the mystic blurred backdrop should stay contained inside the panel rect")
	_expect(frame_source.find("mystic_backdrop as Texture2D, Rect2(Vector2.ZERO, view_size)") < 0, "the mystic backdrop must not cover the full view — the battle stays visible around the panel")

	var overlay: Object = CharacterInfoOverlay.new()
	_expect(FileAccess.file_exists(str(overlay.HUMAN_HOLOGRAM_PATH)) and FileAccess.file_exists(str(overlay.HUMAN_HOLOGRAM_PATH) + ".import"), "the human hologram should ship with its export-safe import file")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_SLOT_SOCKET_PATH)) and FileAccess.file_exists(str(overlay.EMPTY_SLOT_SOCKET_PATH) + ".import"), "the empty slot socket should ship with its export-safe import file")
	_expect(FileAccess.file_exists(str(overlay.MYSTIC_BACKDROP_PATH)) and FileAccess.file_exists(str(overlay.MYSTIC_BACKDROP_PATH) + ".import"), "the mystic backdrop should ship with its export-safe import file")
	_expect(overlay.PANEL_COLOR.a <= 0.35, "the main frame should stay a translucent glass pane (glassmorphism pass)")
	_expect(overlay.SECTION_COLOR.a <= 0.75, "section panels should stay translucent glass wells")
	_expect(FileAccess.file_exists(str(overlay.EDITORIAL_BG_PATH)), "the editorial backdrop PNG should ship with the overlay")
	_expect(FileAccess.file_exists(str(overlay.EDITORIAL_BG_PATH) + ".import"), "the editorial backdrop should ship its export-safe import file")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_HERO_PERK_CRYSTAL_PATH)), "the empty perk crystal hero PNG should ship with the overlay")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_HERO_PERK_CRYSTAL_PATH) + ".import"), "the empty perk crystal hero should ship its export-safe import file")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_HERO_RINGPET_EGG_PATH)), "the empty ringpet crystal egg hero PNG should ship with the overlay")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_HERO_RINGPET_EGG_PATH) + ".import"), "the empty ringpet crystal egg hero should ship its export-safe import file")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_HERO_PASSIVE_CLUSTER_PATH)), "the empty passive cluster hero PNG should ship with the overlay")
	_expect(FileAccess.file_exists(str(overlay.EMPTY_HERO_PASSIVE_CLUSTER_PATH) + ".import"), "the empty passive cluster hero should ship its export-safe import file")
	_expect(overlay._editorial_bg_texture == null, "a fresh overlay should not have loaded the backdrop yet")
	_expect(overlay._empty_perk_hero_texture == null and overlay._empty_ringpet_hero_texture == null and overlay._empty_passive_hero_texture == null, "a fresh overlay should not have loaded empty-state hero art yet")
	_expect(overlay._human_hologram_texture == null and overlay._empty_slot_socket_texture == null and overlay._mystic_backdrop_texture == null, "a fresh overlay should not have loaded scene dressing textures yet")
	overlay.open(null, null)
	_expect(overlay._editorial_bg_texture != null, "opening the character info overlay should prewarm the editorial backdrop off the draw path")
	_expect(overlay._human_hologram_texture != null and overlay._empty_slot_socket_texture != null and overlay._mystic_backdrop_texture != null, "opening the character info overlay should prewarm the scene dressing textures off the draw path")
	_expect(overlay._class_emblem_textures.size() == overlay.CLASS_EMBLEM_PATHS.size(), "opening the character info overlay should prewarm all five class emblems off the draw path")
	for emblem_class_id in overlay.CLASS_EMBLEM_PATHS:
		var emblem_path := str(overlay.CLASS_EMBLEM_PATHS[emblem_class_id])
		_expect(FileAccess.file_exists(emblem_path) and FileAccess.file_exists(emblem_path + ".import"), "class emblem for %s should ship with its export-safe import file" % str(emblem_class_id))
	var drawer_glyph_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_texture_drawer.gd")
	_expect(drawer_glyph_source.find("static func draw_ui_glyph(") >= 0, "the shared texture drawer should own the procedural section/stat glyphs")
	_expect(core_source.count("draw_ui_glyph(") >= 6, "every core section title should carry its matching glyph icon")
	var stats_source := FileAccess.get_file_as_string("res://scripts/hud/character_info_overlay_stats_presenter.gd")
	_expect(stats_source.count(".merged({\"icon\":") >= 9, "every player stat row should declare its icon kind")
	_expect(stats_source.find("draw_ui_glyph(") >= 0, "the stat row drawer should render the row icon left of the label")
	_expect(stats_source.count("\"tooltip_body\":") >= 9, "every player stat row should carry a hover tooltip explanation")
	var player_rows_body := stats_source.substr(stats_source.find("static func draw_cached_player_stat_rows("))
	player_rows_body = player_rows_body.substr(0, player_rows_body.find("static func draw_lingpet_stat_rows("))
	_expect(player_rows_body.find("_fill_hover_data(") >= 0 and player_rows_body.find("hover_row_rects.append(row_rect)") >= 0, "player stat rows should fill hover tooltips and register hover rects for redraw gating")
	_expect(header_source.find("class_emblem: Texture2D") >= 0 and header_source.find("draw_texture_rect(class_emblem") >= 0, "the header should draw the class emblem left of the title")
	_expect(overlay._empty_perk_hero_texture != null, "opening the character info overlay should prewarm the perk crystal hero off the draw path")
	_expect(overlay._empty_ringpet_hero_texture != null, "opening the character info overlay should prewarm the ringpet resonance hero off the draw path")
	_expect(overlay._empty_passive_hero_texture != null, "opening the character info overlay should prewarm the passive cluster hero off the draw path")
	overlay.close()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
