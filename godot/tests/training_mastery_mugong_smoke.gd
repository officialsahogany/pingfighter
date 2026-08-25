extends SceneTree

const LanguageSettings := preload("res://scripts/core/language_settings.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const PerkFusionCatalog := preload("res://scripts/characters/perk_fusion_catalog.gd")
const PhysiqueTrainingCatalog := preload("res://scripts/characters/physique_training_catalog.gd")
const PhysiqueTrainingOfferPlanner := preload("res://scripts/characters/physique_training_offer_planner.gd")
const RuntimePerkCatalog := preload("res://scripts/characters/runtime_perk_catalog.gd")
const RuntimePerkIconRenderer := preload("res://scripts/hud/runtime_perk_icon_renderer.gd")
const RuntimePerkOverflowDescriptions := preload("res://scripts/characters/runtime_perk_overflow_descriptions.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const PERK_ID := "training_mastery"
const ICON_PATH := "res://assets/sprites/perks/training_mastery_perk_icon.png"
const MANIFEST_PATH := "res://assets/sprites/perks/training_mastery_perk_icon_manifest.json"

var _failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	PerkConversionFlags.debug_set_enabled(true)
	_verify_catalog_and_offer_gate()
	_verify_runtime_scaling_and_reverse_leg()
	_verify_effective_level_and_polish_composition()
	_verify_live_training_offer_value()
	_verify_save_restore()
	_verify_localization_and_icon()
	LanguageSettings.set_test_locale_override("")
	PerkConversionFlags.debug_set_enabled(false)
	if _failed:
		quit(1)
		return
	print("training_mastery_mugong_smoke: ok")
	quit(0)


func _verify_catalog_and_offer_gate() -> void:
	var catalog := RuntimePerkCatalog.new()
	var data: Dictionary = catalog.get_perk_data(PERK_ID)
	var descriptions: Dictionary = data.get("descriptions", {}) as Dictionary
	_expect(str(data.get("name", "")) == "연공심법", "the new Mugong should use the Korean name 연공심법")
	_expect(int(data.get("max_level", 0)) == 3, "연공심법 should have three authored stars")
	_expect(str(descriptions.get(1, "")) == "모든 수련의 능력치 효과 25% 증폭", "1-star should amplify numeric training stats by 25 percent")
	_expect(str(descriptions.get(3, "")) == "모든 수련의 능력치 효과 100% 증폭", "3-star should amplify numeric training stats by 100 percent")
	_expect(RuntimePerkCatalog.is_slot_consuming_perk(data), "연공심법 should consume one normal Mugong slot")
	_expect(PERK_ID in _ids(catalog.get_choices("smasher", {}, true, 500, null, UnlockAllRegistry.new())), "flag-ON offers should include 연공심법")
	_expect(bool(PerkFusionCatalog.LIMIT_BREAK_ELIGIBLE_IDS.get(PERK_ID, false)), "연공심법 should keep scaling through effective Lv.6+")
	_expect(RuntimePerkOverflowDescriptions.generate_stats_text(PERK_ID, 4) == "모든 수련의 능력치 효과 120% 증폭", "effective star 4 overflow text should continue at 20 percent per level")
	PerkConversionFlags.debug_set_enabled(false)
	_expect(not PERK_ID in _ids(catalog.get_choices("smasher", {}, true, 500, null, UnlockAllRegistry.new())), "flag-OFF offers must hide a training-dependent Mugong")
	PerkConversionFlags.debug_set_enabled(true)


func _verify_runtime_scaling_and_reverse_leg() -> void:
	var training_catalog := PhysiqueTrainingCatalog.new()
	var base_state := RuntimePerkState.new()
	_expect(base_state._apply_physique_training_choice(training_catalog.build_card("physique_move_speed", 0), null, null), "fixture move-speed training should apply")
	_expect(is_equal_approx(base_state.get_physique_training_multiplier(), 1.0), "no mastery should keep a neutral training multiplier")
	_expect(is_equal_approx(base_state.get_physique_training_bonus("move_speed_bonus_pct"), 4.0), "reverse leg: one move-speed training should remain 4 percent")
	_expect(is_equal_approx(base_state.get_player_speed_multiplier(), 1.04), "reverse leg: the gameplay speed consumer should remain 1.04")

	var level_one := RuntimePerkState.new()
	level_one.runtime_skill_levels[PERK_ID] = 1
	_expect(level_one._apply_physique_training_choice(training_catalog.build_card("physique_move_speed", 0), null, null), "Lv.1 fixture training should apply")
	_expect(is_equal_approx(level_one.get_physique_training_multiplier(), 1.25), "1-star should expose a 1.25 multiplier")
	_expect(is_equal_approx(level_one.get_physique_training_bonus("move_speed_bonus_pct"), 5.0), "1-star should turn a 4 percent training into 5 percent")
	_expect(is_equal_approx(level_one.get_player_speed_multiplier(), 1.05), "1-star should reach the production movement-speed query")

	var level_three := RuntimePerkState.new()
	level_three.runtime_skill_levels[PERK_ID] = 3
	_expect(level_three._apply_physique_training_choice(training_catalog.build_card("physique_move_speed", 0), null, null), "3-star move-speed training should apply")
	_expect(level_three._apply_physique_training_choice(training_catalog.build_card("physique_max_gauge", 0), null, null), "3-star max-vigor training should apply")
	_expect(level_three._apply_physique_training_choice(training_catalog.build_card("physique_chosik_cooldown", 0), null, null), "3-star Chosik training should apply")
	_expect(level_three._apply_physique_training_choice(training_catalog.build_card("physique_storage", 0), null, null), "3-star storage training should apply")
	_expect(is_equal_approx(level_three.get_physique_training_multiplier(), 2.0), "3-star should double numeric training stats")
	_expect(is_equal_approx(level_three.get_physique_training_bonus("move_speed_bonus_pct"), 8.0), "3-star should double move-speed training from 4 to 8 percent")
	_expect(is_equal_approx(level_three.get_physique_training_bonus("max_gauge_flat"), 60.0), "3-star should double flat max-vigor training from 30 to 60")
	_expect(is_equal_approx(level_three.get_player_skill_cooldown_multiplier(), 0.94), "3-star should double one Chosik training from 3 to 6 percent")
	_expect(is_equal_approx(level_three.get_physique_training_bonus("active_item_slot_bonus"), 1.0), "structural storage slots must not be multiplied")
	_expect(level_three.get_active_item_slot_capacity(3) == 4, "3-star should still add exactly one storage slot")


func _verify_effective_level_and_polish_composition() -> void:
	var training_catalog := PhysiqueTrainingCatalog.new()
	var overflow_state := RuntimePerkState.new()
	overflow_state.runtime_skill_levels[PERK_ID] = 3
	overflow_state.item_perk_level_bonus = 2
	_expect(overflow_state._apply_physique_training_choice(training_catalog.build_card("physique_move_speed", 0), null, null), "overflow fixture training should apply")
	_expect(overflow_state.get_runtime_skill_level(PERK_ID) == 5, "effective-level bonuses should raise 연공심법 above authored 3-star")
	_expect(is_equal_approx(overflow_state.get_physique_training_multiplier(), 2.4), "effective star 5 should amplify training by 140 percent")
	_expect(is_equal_approx(overflow_state.get_physique_training_bonus("move_speed_bonus_pct"), 9.6), "effective star 5 should turn 4 percent into 9.6 percent")

	var polish_state := RuntimePerkState.new()
	polish_state.runtime_skill_levels = {PERK_ID: 1, "item_polish": 3}
	_expect(polish_state._apply_physique_training_choice(training_catalog.build_card("physique_move_speed", 0), null, null), "Polish-composition fixture training should apply")
	_expect(is_equal_approx(polish_state.get_perk_amplify_multiplier(PERK_ID), 1.25), "3-star 개광결 should amplify 연공심법 by 25 percent")
	_expect(is_equal_approx(polish_state.get_runtime_skill_bonus(PERK_ID), 0.3125), "1-star 연공심법 should expose a polished 31.25-percent runtime lane")
	_expect(is_equal_approx(polish_state.get_physique_training_multiplier(), 1.3125), "the polished 연공심법 lane should become the canonical training multiplier")
	_expect(is_equal_approx(polish_state.get_physique_training_bonus("move_speed_bonus_pct"), 5.25), "1-star 연공심법 plus 3-star 개광결 should turn 4 percent into 5.25 percent")
	var descriptions: Dictionary = RuntimePerkCatalog.new().get_perk_data(PERK_ID).get("descriptions", {})
	var polished_text := RuntimePerkOverflowDescriptions.resolve_stats_text_with_polish(
		PERK_ID,
		descriptions,
		1,
		polish_state
	)
	_expect(polished_text == "모든 수련의 능력치 효과 25% (+6.25%) 증폭", "연공심법 tooltip should expose its realizable 개광결 delta: %s" % polished_text)


func _verify_live_training_offer_value() -> void:
	var runtime_state := RuntimePerkState.new()
	runtime_state.runtime_skill_levels[PERK_ID] = 3
	var planner := PhysiqueTrainingOfferPlanner.new()
	var planned: Dictionary = planner.plan_offer(
		[{"id": "replaceable", "offer_lane": "replaceable", "offer_protected": false}],
		PhysiqueTrainingOfferPlanner.OFFER_SOURCE_BATTLE_STARPOINT,
		runtime_state._physique_training_state,
		PhysiqueTrainingCatalog.new(),
		0.0,
		0.31,
		0.0,
		runtime_state,
		null
	)
	_expect(bool(planned.get("appeared", false)), "the production planner should inject a training card")
	var choices: Array = planned.get("choices", []) as Array
	var card: Dictionary = {}
	if not choices.is_empty() and choices[0] is Dictionary:
		card = choices[0] as Dictionary
	_expect(str(card.get("id", "")) == "physique_move_speed", "the deterministic weighted roll should select move-speed training")
	_expect(is_equal_approx(float(card.get("training_multiplier", 0.0)), 2.0), "the live offer card should carry the 3-star multiplier")
	# Live card copy must expose the same mastery-scaled increment that apply uses.
	_expect(str(card.get("description", "")) == "이동 속도 8% 증가", "the first live card should show the effective 8-percent per-level value without an empty accumulation suffix")


func _verify_save_restore() -> void:
	var training_catalog := PhysiqueTrainingCatalog.new()
	var state := RuntimePerkState.new()
	state.runtime_skill_levels[PERK_ID] = 3
	state._apply_physique_training_choice(training_catalog.build_card("physique_move_speed", 0), null, null)
	var restored := RuntimePerkState.new()
	var restore_result: Dictionary = restored.apply_unlock_save_snapshot(state.build_unlock_save_snapshot())
	_expect(bool(restore_result.get("restored", false)), "run save should restore 연공심법 and training state")
	_expect(restored.get_runtime_skill_level(PERK_ID) == 3, "restored 연공심법 should remain 3-star")
	_expect(is_equal_approx(restored.get_physique_training_bonus("move_speed_bonus_pct"), 8.0), "restored training should retain the 3-star doubled value")
	print("training_mastery_mugong_smoke: mastery=1.25/2.0/2.4 polish=1.3125 storage=1")


func _verify_localization_and_icon() -> void:
	var catalog := RuntimePerkCatalog.new()
	for locale: String in LanguageSettings.SUPPORTED_LANGUAGES:
		LanguageSettings.set_test_locale_override(locale)
		var data: Dictionary = catalog.get_perk_data(PERK_ID)
		_expect(not str(data.get("name", "")).strip_edges().is_empty(), "%s should localize the perk name" % locale)
		_expect(not str(data.get("detail", "")).strip_edges().is_empty(), "%s should localize the perk detail" % locale)
	LanguageSettings.set_test_locale_override(LanguageSettings.LANGUAGE_KOREAN)
	var renderer := RuntimePerkIconRenderer.new()
	_expect(str(RuntimePerkIconRenderer.PERK_ICON_PATHS.get(PERK_ID, "")) == ICON_PATH, "the renderer should own the new icon path")
	_expect(renderer.has_icon(PERK_ID), "the production renderer should load the new icon")
	_expect(not renderer.has_animated_icon(PERK_ID), "common Mugong art should remain static")
	var image := Image.new()
	_expect(image.load(ProjectSettings.globalize_path(ICON_PATH)) == OK, "the new icon PNG should load")
	if not image.is_empty():
		_expect(Vector2i(image.get_width(), image.get_height()) == Vector2i(256, 256), "the icon should stay 256x256")
		var used_rect := image.get_used_rect()
		_expect(used_rect.position.x >= 8 and used_rect.position.y >= 8, "the icon should keep top-left alpha padding")
		_expect(used_rect.end.x <= 248 and used_rect.end.y <= 248, "the icon should keep bottom-right alpha padding")
		for corner in [Vector2i(0, 0), Vector2i(255, 0), Vector2i(0, 255), Vector2i(255, 255)]:
			_expect(is_zero_approx(image.get_pixelv(corner).a), "the icon corners should stay transparent")
	var manifest_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_expect(manifest_value is Dictionary, "the icon manifest should parse")
	if manifest_value is Dictionary:
		var manifest: Dictionary = manifest_value
		_expect(str(manifest.get("perk_id", "")) == PERK_ID, "the icon manifest should preserve the compatibility id")
		_expect(str((manifest.get("qa", {}) as Dictionary).get("sha256", "")) == FileAccess.get_sha256(ICON_PATH), "the icon manifest hash should match the final PNG")


func _ids(entries: Array) -> Array[String]:
	var result: Array[String] = []
	for entry_value: Variant in entries:
		if entry_value is Dictionary:
			result.append(str((entry_value as Dictionary).get("id", "")))
	return result


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error("training_mastery_mugong_smoke FAIL: " + message)


class UnlockAllRegistry:
	extends RefCounted

	var _store := UnlockAllStore.new()

	func get_instance(key: String) -> Object:
		return _store if key == "tower_ascent_unlock_store" else null


class UnlockAllStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true
