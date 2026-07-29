extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const OptimusSkillConfig := preload("res://scripts/characters/optimus_skill_config.gd")
const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const CharacterInfoOverlayFormatter := preload("res://scripts/hud/character_info_overlay_formatter.gd")
const RuntimePerkOverlayRenderer := preload("res://scripts/hud/runtime_perk_overlay_renderer.gd")
const SmasherSkillOrbTooltipRenderer := preload("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const SOUL_SUMMON_SKILL_ICON_PATH := "res://assets/sprites/skills/soul_summon_art_skill_orb_imagegen_v1.png"
const SOUL_SUMMON_SKILL_MANIFEST_PATH := "res://assets/sprites/skills/soul_summon_art_skill_orb_imagegen_v1_manifest.json"
const SOUL_SUMMON_MANUAL_ICON_PATH := "res://assets/sprites/perks/soul_summon_art_manual_icon.png"
const SOUL_SUMMON_MANUAL_MANIFEST_PATH := "res://assets/sprites/perks/soul_summon_art_manual_icon_manifest.json"
const ICON_SIZE := Vector2i(256, 256)

var _failures: Array[String] = []


class FakeRuntimeCatalog:
	extends RefCounted

	func get_perk_data(perk_id: String) -> Dictionary:
		if perk_id == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID:
			return CommonSkillCatalog.get_unlock_perk_data()
		return {}

	func get_slot_cost_for_level(_perk_data: Dictionary, _level: int) -> int:
		return 1


func _init() -> void:
	_verify_single_owner_and_five_config_surfaces()
	_verify_full_slot_swap_and_cancel_noop()
	_verify_full_unlock_budget_keeps_reserved_offer()
	_verify_fixed_level_tooltip_locales_icon_and_fusion_exclusion()
	_verify_character_info_slot_free_contract()
	_verify_removal_preserves_run_owned_state()
	LanguageSettings.set_test_locale_override("")
	if _failures.is_empty():
		print("soul_summon_art_skill_contract_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_single_owner_and_five_config_surfaces() -> void:
	var configs := [
		SmasherSkillConfig.new(),
		ViperSkillConfig.new(),
		CommandoSkillConfig.new(),
		BlacksmithSkillConfig.new(),
		OptimusSkillConfig.new(),
	]
	var paths := [
		"res://scripts/characters/smasher_skill_config.gd",
		"res://scripts/characters/viper_skill_config.gd",
		"res://scripts/characters/commando_skill_config.gd",
		"res://scripts/characters/blacksmith_skill_config.gd",
		"res://scripts/characters/optimus_skill_config.gd",
	]
	var canonical: Dictionary = CommonSkillCatalog.get_skill_data()
	for index in range(configs.size()):
		var config: Object = configs[index]
		var data: Dictionary = config.get_skill_data(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
		_expect(data == canonical, "%s should expose the common catalog definition" % paths[index])
		var source := FileAccess.get_file_as_string(paths[index])
		_expect(source.find("common_skill_catalog.gd") >= 0, "%s should reference the single common owner" % paths[index])
		_expect(source.find("CommonSkillCatalog.get_skill_data()") >= 0, "%s should delegate metadata instead of copying it" % paths[index])


func _verify_full_slot_swap_and_cancel_noop() -> void:
	var flow := RuntimePerkUnlockSwapFlow.new()
	var configs := [
		SmasherSkillConfig.new(),
		ViperSkillConfig.new(),
		CommandoSkillConfig.new(),
		BlacksmithSkillConfig.new(),
		OptimusSkillConfig.new(),
	]
	var character_types := ["smasher", "viper", "soldier", "blacksmith", "optimus"]
	for index in range(configs.size()):
		var config: Object = configs[index]
		_fill_shared_slots(config)
		var capacity := int(config.get_shared_slot_capacity()) if config.has_method("get_shared_slot_capacity") else int(config.get_max_skill_slots())
		var candidates: Array = config.get_shared_slot_swap_candidates(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
		_expect(candidates.size() == capacity, "%s full fixture should expose every occupied slot for swap" % character_types[index])
		_expect(flow.should_start_swap(config, CommonSkillCatalog.SOUL_SUMMON_ART_ID, character_types[index]), "%s should start the shared unlock swap at full budget" % character_types[index])
		var before := candidates.duplicate(true)
		var pending := flow.build_pending_swap({
			"id": CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID,
			"unlocks_skill": CommonSkillCatalog.SOUL_SUMMON_ART_ID,
			"name": "영혼소환술",
		}, config)
		_expect(not pending.is_empty(), "%s should build a non-empty pending swap" % character_types[index])
		flow.build_cancel_state_update()
		_expect(config.get_shared_slot_swap_candidates(CommonSkillCatalog.SOUL_SUMMON_ART_ID) == before, "%s cancel must not mutate equipment" % character_types[index])
	var smasher := SmasherSkillConfig.new()
	_fill_shared_slots(smasher)
	var smasher_equipped: Array = smasher.get("equipped_skills") as Array
	smasher_equipped[0] = CommonSkillCatalog.SOUL_SUMMON_ART_ID
	_expect(smasher.get_shared_slot_swap_candidates("plasma").has(CommonSkillCatalog.SOUL_SUMMON_ART_ID), "a later character unlock must be able to swap the common art out")
	_expect(flow.should_start_swap(smasher, "plasma", "smasher"), "common-art removal must route through the same confirmed swap flow")


func _fill_shared_slots(config: Object) -> void:
	var capacity := int(config.get_shared_slot_capacity()) if config.has_method("get_shared_slot_capacity") else int(config.get_max_skill_slots())
	var field := "equipped_permanent" if config.has_method("get_equipped_permanent") else "equipped_skills"
	var equipped: Array = config.get(field) as Array
	equipped.clear()
	for index in range(capacity):
		equipped.append("fixture_skill_%d" % index)


func _verify_full_unlock_budget_keeps_reserved_offer() -> void:
	var catalog := RuntimePerkCatalog.new()
	var levels := {
		"unlock_magnum_grip": 1,
		"unlock_plasma": 1,
		"unlock_recovery_skill": 1,
	}
	var source := FileAccess.get_file_as_string("res://scripts/characters/runtime_perk_catalog.gd")
	var filter_body := _function_body(source, "func _filter_unlock_slot_budget")
	_expect(filter_body.find("CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID") >= 0, "full character unlock budget must explicitly preserve the common art reservation")
	var choice := CommonSkillCatalog.get_unlock_perk_data()
	choice["id"] = CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	var filtered: Array = catalog._filter_unlock_slot_budget([choice], "smasher", levels)
	_expect(filtered.size() == 1, "Soul Summoning Art must survive a fixture with the Smasher unlock budget completely full")


func _verify_fixed_level_tooltip_locales_icon_and_fusion_exclusion() -> void:
	var languages := ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"]
	var expected_how_to_use := {
		"ko": "Ctrl 또는 R3를 눌러 수호령 소환·수납을 전환합니다.",
		"en": "Press Ctrl or R3 to switch between summoning and stowing the guardian.",
		"zh": "按 Ctrl 或 R3 切换守护灵的召唤与收纳。",
		"ja": "Ctrl または R3 を押して守護霊の召喚・収納を切り替えます。",
		"es": "Pulsa Ctrl o R3 para alternar entre invocar y guardar al guardián.",
		"pt-BR": "Pressione Ctrl ou R3 para alternar entre invocar e guardar o guardião.",
		"ru": "Нажмите Ctrl или R3, чтобы призвать или убрать хранителя.",
	}
	var expected_manual_names := {
		"ko": "영혼소환술 비급",
		"en": "Soul Summoning Art Manual",
		"zh": "灵魂召唤术秘笈",
		"ja": "魂魄召喚術秘伝書",
		"es": "Manual del Arte de Invocación de Almas",
		"pt-BR": "Manual da Arte de Invocação de Almas",
		"ru": "Тайный свиток искусства призыва душ",
	}
	var overlay := RuntimePerkOverlayRenderer.new()
	for language in languages:
		LanguageSettings.set_test_locale_override(language)
		var data := CommonSkillCatalog.get_skill_data()
		var manual_data := CommonSkillCatalog.get_unlock_perk_data()
		_expect(str(data.get("korean", "")).strip_edges() != "", "%s should provide a display name" % language)
		_expect(str(data.get("description", "")).split("\n").size() <= 3, "%s description must stay within three lines" % language)
		var how_to_use := str(data.get("how_to_use", ""))
		_expect(how_to_use == str(expected_how_to_use.get(language, "")), "%s how_to_use must use the synchronized one-sentence copy" % language)
		_expect(not how_to_use.is_empty() and how_to_use.find("\n") < 0, "%s how_to_use must be one non-empty line" % language)
		_expect(not bool(data.get("show_cooldown", true)), "%s tooltip must suppress cooldown" % language)
		_expect(int(data.get("fixed_level", 0)) == 1, "%s should expose fixed level one" % language)
		_expect(not bool(data.get("cooldown_reduction_eligible", true)), "%s must opt out of cooldown reduction" % language)
		_expect(bool(manual_data.get("is_skill_manual", false)), "%s unlock must declare the explicit common-manual classification" % language)
		_expect(str(manual_data.get("name", "")) == str(expected_manual_names.get(language, "")), "%s unlock must use the localized manual title" % language)
		_expect(CharacterInfoOverlayFormatter.perk_level_text(manual_data) == LanguageSettings.translate_text("비급"), "%s TAB entry must classify the common unlock as a manual" % language)
		_expect(str(overlay._level_text(manual_data)) == LanguageSettings.translate_text("비급"), "%s choice card must classify the common unlock as a manual" % language)
	var tooltip_renderer := SmasherSkillOrbTooltipRenderer.new()
	for character_type in ["smasher", "viper", "soldier", "blacksmith", "optimus"]:
		var rows: Array = tooltip_renderer._get_control_rows(CommonSkillCatalog.SOUL_SUMMON_ART_ID, character_type)
		_expect(rows.size() == 1, "%s Soul Summoning Art tooltip must expose one shared control row" % character_type)
		if rows.size() != 1:
			continue
		var row: Array = rows[0] as Array
		_expect(row.size() == 5, "%s shared control row must keep the compact five-token shape" % character_type)
		if row.size() == 5:
			_expect(row[0] == ["key", "Ctrl"], "%s shared control row must begin with the Ctrl keycap" % character_type)
			_expect(row[1] == ["slash", "/"], "%s shared control row must separate keyboard and gamepad inputs" % character_type)
			_expect(row[2] == ["key", "R3"], "%s shared control row must expose the R3 gamepad keycap" % character_type)
			_expect(row[3] == ["text", "소환·수납 전환"], "%s shared control row must state the toggle action" % character_type)
			_expect(row[-1] == ["accent", "발동"], "%s shared control row must end with the activation accent" % character_type)
	var icon_renderer := RuntimePerkIconRenderer.new()
	_expect(icon_renderer.has_icon(CommonSkillCatalog.SOUL_SUMMON_ART_ID), "active orb id must load its dedicated imagegen PNG")
	_expect(icon_renderer.has_icon(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID), "unlock card id must load its dedicated manual PNG")
	var icon_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_icon_renderer.gd")
	_expect(str(RuntimePerkIconRenderer.SKILL_ICON_PATHS.get(CommonSkillCatalog.SOUL_SUMMON_ART_ID, "")) == SOUL_SUMMON_SKILL_ICON_PATH, "active Chosik must route through the canonical imagegen orb registry")
	_expect(str(RuntimePerkIconRenderer.MANUAL_ICON_PATHS.get(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, "")) == SOUL_SUMMON_MANUAL_ICON_PATH, "unlock card must route through the canonical manual PNG registry")
	_expect(str(icon_renderer._get_static_path(CommonSkillCatalog.SOUL_SUMMON_ART_ID)) == SOUL_SUMMON_SKILL_ICON_PATH, "active Chosik PNG must resolve before procedural fallbacks")
	_expect(str(icon_renderer._get_static_path(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID)) == SOUL_SUMMON_MANUAL_ICON_PATH, "manual PNG must resolve before procedural or orb fallbacks")
	_expect(icon_source.find("func _draw_soul_summon_art_icon") < 0, "retired active-orb procedural placeholder must not remain as dead code")
	_expect(icon_source.find("func _draw_soul_summon_art_manual_icon") < 0, "retired procedural placeholder must not remain as dead code")
	var skill_texture: Texture2D = load(SOUL_SUMMON_SKILL_ICON_PATH) as Texture2D
	_expect(skill_texture != null, "Soul Summoning Art Chosik PNG should import as Texture2D")
	if skill_texture != null:
		_expect(Vector2i(skill_texture.get_width(), skill_texture.get_height()) == ICON_SIZE, "Soul Summoning Art Chosik icon should stay 256x256")
		var source: Dictionary = icon_renderer._get_icon_source(CommonSkillCatalog.SOUL_SUMMON_ART_ID)
		var source_texture: Texture2D = source.get("texture", null)
		_expect(source_texture != null and source_texture.resource_path == SOUL_SUMMON_SKILL_ICON_PATH, "active Chosik must resolve the accepted imagegen PNG")
	var manual_texture: Texture2D = load(SOUL_SUMMON_MANUAL_ICON_PATH) as Texture2D
	_expect(manual_texture != null, "Soul Summoning Art manual PNG should import as Texture2D")
	if manual_texture != null:
		_expect(Vector2i(manual_texture.get_width(), manual_texture.get_height()) == ICON_SIZE, "Soul Summoning Art manual icon should stay 256x256")
		var source: Dictionary = icon_renderer._get_icon_source(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID)
		var source_texture: Texture2D = source.get("texture", null)
		_expect(source_texture != null and source_texture.resource_path == SOUL_SUMMON_MANUAL_ICON_PATH, "manual acquisition card must bypass circular orb normalization")
	var manual_image := Image.new()
	_expect(manual_image.load(ProjectSettings.globalize_path(SOUL_SUMMON_MANUAL_ICON_PATH)) == OK, "Soul Summoning Art manual PNG should load for alpha QA")
	if not manual_image.is_empty():
		var used_rect := manual_image.get_used_rect()
		_expect(used_rect.position.x >= 12 and used_rect.position.y >= 12, "manual should keep transparent top-left safety padding")
		_expect(used_rect.end.x <= 248 and used_rect.end.y <= 248, "manual alpha bounds should stay inside the shared safety inset")
		for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			_expect(is_zero_approx(manual_image.get_pixelv(corner).a), "manual corners should remain fully transparent")
	var skill_image := Image.new()
	_expect(skill_image.load(ProjectSettings.globalize_path(SOUL_SUMMON_SKILL_ICON_PATH)) == OK, "Soul Summoning Art Chosik PNG should load for alpha QA")
	if not skill_image.is_empty():
		var used_rect := skill_image.get_used_rect()
		_expect(used_rect.position.x >= 2 and used_rect.position.y >= 2, "Chosik orb should keep transparent top-left safety padding")
		_expect(used_rect.end.x <= 254 and used_rect.end.y <= 254, "Chosik orb alpha bounds should stay off the canvas edge")
		for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			_expect(is_zero_approx(skill_image.get_pixelv(corner).a), "Chosik orb corners should remain fully transparent")
	var skill_manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOUL_SUMMON_SKILL_MANIFEST_PATH))
	_expect(skill_manifest_value is Dictionary, "Soul Summoning Art Chosik manifest should parse")
	if skill_manifest_value is Dictionary:
		var skill_manifest: Dictionary = skill_manifest_value
		_expect(str(skill_manifest.get("skill_id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_ID, "Chosik manifest should preserve the runtime skill id")
		_expect(str(skill_manifest.get("runtime_path", "")) == SOUL_SUMMON_SKILL_ICON_PATH, "Chosik manifest should record the production path")
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOUL_SUMMON_MANUAL_MANIFEST_PATH))
	_expect(manifest_value is Dictionary, "Soul Summoning Art manual manifest should parse")
	if manifest_value is Dictionary:
		var manifest: Dictionary = manifest_value
		_expect(str(manifest.get("perk_id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, "manual manifest should preserve the unlock perk id")
		_expect(str(manifest.get("runtime_path", "")) == SOUL_SUMMON_MANUAL_ICON_PATH, "manual manifest should record the production path")
	var tooltip_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_tooltip_renderer.gd")
	var cooldown_body := _function_body(tooltip_source, "func _draw_cost_and_cooldown_line")
	_expect(cooldown_body.find("show_cooldown") >= 0, "live orb tooltip must honor the common art cooldown-suppression field")
	var classification := PerkFusionCatalog.new().classify_perk(
		CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID,
		FakeRuntimeCatalog.new(),
		1
	)
	_expect(bool(classification.get("fusion_excluded", false)), "unlock perk must be explicitly excluded from fusion")
	_expect(not bool(classification.get("is_candidate_class", true)), "excluded unlock perk must never be a fusion candidate")


func _verify_character_info_slot_free_contract() -> void:
	var catalog := RuntimePerkCatalog.new()
	var soul_data: Dictionary = catalog.get_perk_data(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID)
	_expect(bool(soul_data.get("character_info_slot_free", false)), "common manual must declare the TAB-only slot-free presentation contract")
	_expect(RuntimePerkCatalog.get_slot_cost_for_level(soul_data, 1) == 0, "Soul Summoning Art must consume zero Mugong budget in character info")
	_expect(str(CommonSkillCatalog.get_skill_data().get("slot_occupancy", "")) == "active_orb", "combat Chosik orb must still occupy one of the five battle slots")

	var full_levels := {
		"dash_lightweight": 1,
		"dash_module_control": 1,
		"dash_jump": 1,
		"dash_acceleration": 1,
		"item_luck": 1,
		"common_swiftness": 1,
	}
	var baseline_count := catalog.count_owned_slot_perks(full_levels)
	var with_soul := full_levels.duplicate(true)
	with_soul[CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID] = 1
	with_soul[CommonSkillCatalog.SOUL_SUMMON_ART_ID] = 1
	_expect(baseline_count == RuntimePerkCatalog.BASE_PERK_SLOT_LIMIT, "fixture must fill the entire Mugong budget before adding the common manual")
	_expect(catalog.count_owned_slot_perks(with_soul) == baseline_count, "Soul Summoning Art must leave the full-budget counter unchanged")

	var acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		with_soul,
		catalog,
		null,
		null,
		{},
		[CommonSkillCatalog.SOUL_SUMMON_ART_ID],
		Color(0.3, 0.7, 1.0),
		Color(1.0, 0.8, 0.3)
	)
	var soul_entries := acquired.filter(func(entry: Dictionary) -> bool:
		return str(entry.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	)
	_expect(soul_entries.size() == 1, "equipped common art must remain visible as one TAB collection entry")
	if soul_entries.size() == 1:
		_expect(bool((soul_entries[0] as Dictionary).get("_slot_free_cell", false)), "TAB Soul Summoning Art entry must use the canonical _slot_free_cell marker")
	var grid := CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(acquired, baseline_count)
	_expect(grid.size() == baseline_count + 1, "slot-free common manual must append after six fully occupied paid cells")
	if grid.size() == baseline_count + 1:
		_expect(str((grid[-1] as Dictionary).get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, "slot-free common manual must stay in the right-leading appended lane")

	# The live TAB always receives RuntimePerkState.get_snapshot(), whose
	# display projection is the authoritative branch. Keep this fixture on the
	# real snapshot path so a non-projection-only fix cannot pass silently.
	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels = with_soul.duplicate(true)
	var live_snapshot: Dictionary = runtime_state.get_snapshot()
	var live_projection: Dictionary = live_snapshot.get("perk_fusion_display_projection", {}) as Dictionary
	_expect(not (live_projection.get("entries", []) as Array).is_empty(), "live get_snapshot fixture must enter the projection branch")
	var live_acquired: Array = CharacterInfoOverlayPerkPresenter.build_acquired_perks(
		runtime_state.runtime_skill_levels,
		catalog,
		runtime_state,
		live_snapshot,
		{},
		[CommonSkillCatalog.SOUL_SUMMON_ART_ID],
		Color(0.3, 0.7, 1.0),
		Color(1.0, 0.8, 0.3)
	)
	var live_soul_entries := live_acquired.filter(func(entry: Dictionary) -> bool:
		return str(entry.get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID
	)
	_expect(live_soul_entries.size() == 1, "live projection must retain exactly one Soul Summoning Art manual")
	if live_soul_entries.size() == 1:
		_expect(bool((live_soul_entries[0] as Dictionary).get("_slot_free_cell", false)), "live projection manual must carry the canonical slot-free marker")
	var live_grid := CharacterInfoOverlayPerkPresenter.build_slot_grid_entries(live_acquired, baseline_count)
	_expect(live_grid.size() == baseline_count + 1, "live projection must append the manual outside a full paid-slot budget")
	if live_grid.size() == baseline_count + 1:
		_expect(str((live_grid[-1] as Dictionary).get("id", "")) == CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID, "live projection manual must occupy the appended right-leading cell")


func _verify_removal_preserves_run_owned_state() -> void:
	var runtime := LingpetEggRuntime.new()
	runtime.set_duration_pool_for_tests(37.0, 71.0)
	var before_current := runtime.get_duration_pool_current()
	var before_max := runtime.get_duration_pool_max()
	runtime.on_soul_summon_art_removed(null, null)
	_expect(is_equal_approx(runtime.get_duration_pool_current(), before_current), "removal must preserve shared duration current")
	_expect(is_equal_approx(runtime.get_duration_pool_max(), before_max), "removal must preserve shared duration maximum")
	var source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var body := _function_body(source, "func on_soul_summon_art_removed")
	_expect(body.find("_set_guardian_stowed(true, owner, registry, true)") >= 0, "removal must force stow an active guardian")
	_expect(body.find("reset") < 0 and body.find("buff") < 0, "removal must not reset pets, duration, or enhancement buffs")


func _function_body(source: String, signature: String) -> String:
	var start := source.find(signature)
	if start < 0:
		return ""
	var next := source.find("\nfunc ", start + 1)
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
