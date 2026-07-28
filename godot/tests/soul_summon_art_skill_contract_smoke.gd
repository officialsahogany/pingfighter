extends SceneTree

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const SmasherSkillConfig := preload("res://scripts/characters/smasher_skill_config.gd")
const ViperSkillConfig := preload("res://scripts/characters/viper_skill_config.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const BlacksmithSkillConfig := preload("res://scripts/characters/blacksmith_skill_config.gd")
const OptimusSkillConfig := preload("res://scripts/characters/optimus_skill_config.gd")
const RuntimePerkUnlockSwapFlow := preload("res://scripts/characters/runtime_perk_unlock_swap_flow.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const CharacterInfoOverlayPerkPresenter := preload("res://scripts/hud/character_info_overlay_perk_presenter.gd")
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LanguageSettings := preload("res://scripts/core/language_settings.gd")

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
	for language in languages:
		LanguageSettings.set_test_locale_override(language)
		var data := CommonSkillCatalog.get_skill_data()
		_expect(str(data.get("korean", "")).strip_edges() != "", "%s should provide a display name" % language)
		_expect(str(data.get("description", "")).split("\n").size() <= 3, "%s description must stay within three lines" % language)
		_expect(str(data.get("how_to_use", "")).find("\n") < 0, "%s how_to_use must be one sentence" % language)
		_expect(not bool(data.get("show_cooldown", true)), "%s tooltip must suppress cooldown" % language)
		_expect(int(data.get("fixed_level", 0)) == 1, "%s should expose fixed level one" % language)
		_expect(not bool(data.get("cooldown_reduction_eligible", true)), "%s must opt out of cooldown reduction" % language)
	var icon_renderer := RuntimePerkIconRenderer.new()
	_expect(icon_renderer.has_icon(CommonSkillCatalog.SOUL_SUMMON_ART_ID), "active orb id must have an exact procedural icon branch")
	_expect(icon_renderer.has_icon(CommonSkillCatalog.SOUL_SUMMON_ART_UNLOCK_ID), "unlock card id must have an exact procedural icon branch")
	var icon_source := FileAccess.get_file_as_string("res://scripts/hud/runtime_perk_icon_renderer.gd")
	var manual_body := _function_body(icon_source, "func _draw_soul_summon_art_manual_icon")
	_expect(icon_source.find("if skill_id == \"unlock_soul_summon_art\"") >= 0, "unlock card must route to a distinct manual presentation")
	_expect(manual_body.find("var jade := Color(") >= 0 and manual_body.find("canvas.draw_rect(cover") >= 0, "common manual must use the jade book silhouette rather than the battle egg symbol")
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
