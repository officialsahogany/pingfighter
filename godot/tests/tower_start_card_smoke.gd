extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentTuning := preload(
	"res://scripts/tower_ascent/tower_ascent_tuning.gd"
)
const TowerStartCardOfferBuilder := preload(
	"res://scripts/tower_ascent/tower_start_card_offer_builder.gd"
)
const TowerStartCardState := preload(
	"res://scripts/tower_ascent/tower_start_card_state.gd"
)
const RuntimePerkChoiceApplyFlow := preload(
	"res://scripts/characters/runtime_perk_choice_apply_flow.gd"
)
const RuntimePerkChoiceStandardPath := preload(
	"res://scripts/characters/runtime_perk_choice_standard_path.gd"
)
const RuntimePerkLevelSideEffects := preload(
	"res://scripts/characters/runtime_perk_level_side_effects.gd"
)
const RuntimePerkState := preload(
	"res://scripts/characters/runtime_perk_state.gd"
)
const BattleSceneShell := preload(
	"res://scripts/core/battle_scene_shell.gd"
)
const BattleSceneFlowController := preload(
	"res://scripts/core/battle_scene_flow_controller.gd"
)
const BattleSceneFrameController := preload(
	"res://scripts/core/battle_scene_frame_controller.gd"
)
const BattleSceneIntroFrameController := preload(
	"res://scripts/core/battle_scene_intro_frame_controller.gd"
)
const BattleSceneReadinessController := preload(
	"res://scripts/core/battle_scene_readiness_controller.gd"
)
const BattleSceneModalGateController := preload(
	"res://scripts/core/battle_scene_modal_gate_controller.gd"
)
const BattleSceneInputController := preload(
	"res://scripts/core/battle_scene_input_controller.gd"
)
const BattleSceneTeardownLifecycle := preload(
	"res://scripts/core/battle_scene_teardown_lifecycle.gd"
)
const GameSelectionState := preload(
	"res://scripts/core/game_selection_state.gd"
)
const TowerStartCardLocalization := preload(
	"res://scripts/tower_ascent/tower_start_card_localization.gd"
)

var _failures: Array[String] = []
var _leg_count := 0


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var selection_state: Object = null

	func get_node_or_null(path: NodePath) -> Object:
		if path == NodePath("/root/GameSelectionState"):
			return selection_state
		return null


class FakeSelectionState:
	extends RefCounted

	var requested := true

	func consume_tower_start_card_entry_request() -> bool:
		var result := requested
		requested = false
		return result


class FakeFlowOwner:
	extends RefCounted

	var run_id := "tower-start-card-run"

	func get_run_id() -> String:
		return run_id


class FakeUnlockStore:
	extends RefCounted

	var locked_ids: Dictionary = {}

	func is_unlocked(_content_type: String, content_id: String) -> bool:
		return not locked_ids.has(content_id)


class FakeSkillConfig:
	extends RefCounted

	var max_slots := 4
	var equipped_skills: Array[String] = ["base_skill"]
	var known_skills: Dictionary = {
		"base_skill": {"name": "Base"},
		"skill_alpha": {"name": "Alpha"},
		"skill_beta": {"name": "Beta"},
		"skill_gamma": {"name": "Gamma"},
		"skill_delta": {"name": "Delta"},
	}

	func is_shared_slot_full() -> bool:
		return equipped_skills.size() >= max_slots

	func get_skill_data(skill_id: String) -> Dictionary:
		var value: Variant = known_skills.get(skill_id, {})
		return (value as Dictionary).duplicate(true) if value is Dictionary else {}

	func unlock_and_equip_skill(skill_id: String) -> bool:
		if not known_skills.has(skill_id) or is_shared_slot_full():
			return false
		if not equipped_skills.has(skill_id):
			equipped_skills.append(skill_id)
		return true


class FakeCatalog:
	extends RefCounted

	var all_calls := 0
	var data: Dictionary = {}

	func get_all_perk_data() -> Dictionary:
		all_calls += 1
		return data.duplicate(true)


class FakeRuntimeState:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var current_choice_context: Dictionary = {"source": "before_start_card"}
	var apply_calls := 0
	var target_apply_calls := 0
	var cancel_calls := 0
	var force_pending_swap := false
	var pending_swap := false
	var seen_context: Dictionary = {}
	var skill_config: FakeSkillConfig
	var stats_capture_calls := 0
	var stats_context_active := false

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_calls += 1
		seen_context = current_choice_context.duplicate(true)
		if force_pending_swap:
			pending_swap = true
			return false
		var perk_id := str(choice.get("id", ""))
		var unlocked_skill := str(choice.get("unlocks_skill", ""))
		if perk_id.is_empty():
			return false
		if not unlocked_skill.is_empty():
			if not skill_config.unlock_and_equip_skill(unlocked_skill):
				return false
			runtime_skill_levels[perk_id] = 1
		else:
			runtime_skill_levels[perk_id] = int(runtime_skill_levels.get(perk_id, 0)) + 1
		return true

	func apply_choice_at_target_level(
		choice: Dictionary,
		target_level: int,
		_owner: Object,
		_registry: Object
	) -> bool:
		target_apply_calls += 1
		seen_context = current_choice_context.duplicate(true)
		var perk_id := str(choice.get("id", ""))
		if perk_id.is_empty() or target_level > int(choice.get("max_level", 0)):
			return false
		runtime_skill_levels[perk_id] = target_level
		return true

	func has_pending_unlock_swap() -> bool:
		return pending_swap

	func cancel_pending_unlock_swap(_owner: Object = null) -> bool:
		if not pending_swap:
			return false
		pending_swap = false
		cancel_calls += 1
		return true

	func capture_stats_context(owner: Object, registry: Object) -> bool:
		stats_capture_calls += 1
		stats_context_active = owner != null and registry != null
		return stats_context_active


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Variant:
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		return instances.get(key, null)


class ShellRegistry:
	extends RefCounted

	var instances: Dictionary = {}
	var instance_calls: Dictionary = {}
	var cached_calls: Dictionary = {}
	var clear_calls := 0

	func get_instance(key: String) -> Variant:
		instance_calls[key] = int(instance_calls.get(key, 0)) + 1
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		cached_calls[key] = int(cached_calls.get(key, 0)) + 1
		return instances.get(key, null)

	func clear_all() -> void:
		clear_calls += 1


class FakeWarmup:
	extends RefCounted

	var finished := false

	func is_finished() -> bool:
		return finished


class FakeLoadingRenderer:
	extends RefCounted

	var hold := false
	var hold_calls := 0
	var draw_calls := 0
	var hide_calls := 0

	func should_hold_completion(_owner: Object, _module_getter: Callable) -> bool:
		hold_calls += 1
		return hold

	func draw(
		_canvas: CanvasItem,
		_owner: Object,
		_module_getter: Callable,
		_view_size: Vector2,
		_context: Dictionary
	) -> void:
		draw_calls += 1

	func hide_loading() -> void:
		hide_calls += 1

	func release_stained_glass_hosts(_owner: Object) -> void:
		pass


class FakeStageAudio:
	extends RefCounted

	var play_calls := 0
	var stop_calls := 0

	func play_stage_bgm(_stage: int) -> void:
		play_calls += 1

	func stop_bgm() -> void:
		stop_calls += 1


class FakeLandingIntro:
	extends RefCounted

	var begin_calls := 0

	func begin(_owner: Object, _registry: Object) -> bool:
		begin_calls += 1
		return false

	func is_active() -> bool:
		return false


class FakeBattleUpdateDriver:
	extends RefCounted

	var update_calls := 0
	var scoreboard_visual_calls := 0

	func update(_owner: Object, _registry: Object, _delta: float) -> void:
		update_calls += 1

	func update_scoreboard_visuals(
		_owner: Object,
		_registry: Object,
		_delta: float
	) -> void:
		scoreboard_visual_calls += 1


class FakeHanMiryangPrologue:
	extends RefCounted

	var active := false
	var input_calls := 0

	func is_active() -> bool:
		return active

	func handle_input(_event: InputEvent, _owner: Object, _registry: Object) -> bool:
		input_calls += 1
		return true

	func begin(_owner: Object, _registry: Object) -> bool:
		return false


class TargetLevelRuntimeProbe:
	extends RefCounted

	var runtime_skill_levels: Dictionary = {}
	var pending_skill_choices := 0
	var starpoint_for_skills := 0
	var side_effect_calls := 0
	var feedback_calls := 0
	var _choice_standard_path: Object = RuntimePerkChoiceStandardPath.new()
	var _level_side_effects: Object = RuntimePerkLevelSideEffects.new()

	func _should_defer_full_gauge_until_spawn_intro_end() -> bool:
		return false

	func _should_defer_dimension_gate_until_spawn_intro_end() -> bool:
		return false

	func _apply_level_side_effect(
		_choice: Dictionary,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object = null
	) -> void:
		side_effect_calls += 1

	func _apply_choice_feedback_result(
		_result: Dictionary,
		_choice: Dictionary,
		_fallback_timer: float
	) -> bool:
		feedback_calls += 1
		return true

	func _apply_unlock_choice(
		_choice: Dictionary,
		_owner: Object,
		_registry: Object,
		_perf_logger: Object = null
	) -> bool:
		return false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_offer_shape_and_filters()
	_verify_determinism_and_global_rng_isolation()
	_verify_fallback_matrix()
	_verify_target_level_path_is_single_shot()
	_verify_apply_and_single_pick_contract()
	_verify_pending_swap_fails_closed()
	_verify_render_and_localization_contract()
	await _verify_real_battle_scene_shell_wiring()
	_verify_source_contract()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(_leg_count == 9, "all nine start-card S1/S2/S3 smoke legs must execute")
	if _failures.is_empty():
		print("tower_start_card_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_offer_shape_and_filters() -> void:
	_leg_count += 1
	var fixture := _build_fixture(_standard_catalog())
	(fixture.unlock_store as FakeUnlockStore).locked_ids["mugong_locked"] = true
	var offer := TowerStartCardOfferBuilder.new().build_offer(
		"shape-run",
		fixture.owner,
		fixture.registry
	)
	var choices := _offer_choices(offer)
	_expect(bool(offer.get("accepted", false)), "one Chosik plus two Mugong must build")
	_expect(choices.size() == 3, "start-card offer must contain exactly three cards")
	var chosik_count := _kind_count(choices, "chosik")
	_expect(chosik_count in [1, 2], "normal offer must contain one or two Chosik")
	_expect(_kind_count(choices, "mugong") == 3 - chosik_count, "Mugong must fill the three-card remainder")
	var ids := _choice_ids(choices)
	for excluded_id in [
		"mugong_mythic",
		"mugong_instant",
		"mugong_training",
		"mugong_locked",
		"mugong_other_character",
		"mugong_single_rank",
	]:
		_expect(not ids.has(excluded_id), "excluded candidate leaked into offer: %s" % excluded_id)
	_expect((fixture.catalog as FakeCatalog).all_calls == 1, "one offer must call get_all_perk_data exactly once")
	for choice in choices:
		_expect(bool(choice.get("enabled", false)), "every fresh card must be enabled")
		_expect(not choice.has("reward_pick_cost"), "start card must not expose reward cost")
		_expect(not choice.has("reward_pick_price_text"), "start card must not expose price text")
		_expect(not choice.has("balance_text"), "start card must not expose balance text")


func _verify_determinism_and_global_rng_isolation() -> void:
	_leg_count += 1
	var builder := TowerStartCardOfferBuilder.new()
	var first := _build_fixture(_standard_catalog())
	var second := _build_fixture(_standard_catalog())
	var third := _build_fixture(_standard_catalog())
	var first_ids := _choice_ids(_offer_choices(builder.build_offer(
		"deterministic-run",
		first.owner,
		first.registry
	)))
	var second_ids := _choice_ids(_offer_choices(builder.build_offer(
		"deterministic-run",
		second.owner,
		second.registry
	)))
	var third_ids := _choice_ids(_offer_choices(builder.build_offer(
		"different-run",
		third.owner,
		third.registry
	)))
	_expect(first_ids == second_ids, "same run and character must reproduce the same three IDs")
	_expect(first_ids != third_ids, "changing run_id must change the deterministic offer fixture")
	var one_mix_fixture := _build_fixture(_standard_catalog())
	var one_mix := builder.build_offer(
		"mix-seed-0",
		one_mix_fixture.owner,
		one_mix_fixture.registry
	)
	_expect(_kind_count(_offer_choices(one_mix), "chosik") == 1, "fixed mix-seed-0 must produce one Chosik")
	var two_mix_fixture := _build_fixture(_standard_catalog())
	var two_mix := builder.build_offer(
		"mix-seed-1",
		two_mix_fixture.owner,
		two_mix_fixture.registry
	)
	_expect(_kind_count(_offer_choices(two_mix), "chosik") == 2, "fixed mix-seed-1 must produce two Chosik")

	seed(90210)
	var observed_first := randi()
	var rng_fixture := _build_fixture(_standard_catalog())
	builder.build_offer("rng-isolation", rng_fixture.owner, rng_fixture.registry)
	var observed_second := randi()
	seed(90210)
	var expected_first := randi()
	var expected_second := randi()
	_expect(
		observed_first == expected_first and observed_second == expected_second,
		"start-card generation must not advance global gameplay RNG"
	)


func _verify_fallback_matrix() -> void:
	_leg_count += 1
	var full_fixture := _build_fixture(_standard_catalog())
	(full_fixture.skill_config as FakeSkillConfig).max_slots = 1
	var full_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"full-slot",
		full_fixture.owner,
		full_fixture.registry
	))
	_expect(_kind_count(full_choices, "chosik") == 0, "full shared slots must suppress Chosik cards")
	_expect(_kind_count(full_choices, "mugong") == 3, "full shared slots must fall back to three Mugong")

	var no_chosik := _build_fixture({
		"m1": _mugong("m1"),
		"m2": _mugong("m2"),
		"m3": _mugong("m3"),
	})
	var no_chosik_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"no-chosik",
		no_chosik.owner,
		no_chosik.registry
	))
	_expect(_kind_count(no_chosik_choices, "mugong") == 3, "zero Chosik candidates must fall back to three Mugong")

	var one_mugong := _build_fixture({
		"m1": _mugong("m1"),
		"c1": _chosik("c1", "skill_alpha"),
		"c2": _chosik("c2", "skill_beta"),
	})
	var one_mugong_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"one-mugong",
		one_mugong.owner,
		one_mugong.registry
	))
	_expect(_kind_count(one_mugong_choices, "mugong") == 1, "one Mugong fixture must keep its Mugong")
	_expect(_kind_count(one_mugong_choices, "chosik") == 2, "one Mugong fixture must fill with two Chosik")

	var insufficient := _build_fixture({
		"m1": _mugong("m1"),
		"c1": _chosik("c1", "skill_alpha"),
	})
	var skipped := TowerStartCardOfferBuilder.new().build_offer(
		"insufficient",
		insufficient.owner,
		insufficient.registry
	)
	_expect(not bool(skipped.get("accepted", true)), "fewer than three total candidates must skip")
	_expect(str(skipped.get("reason", "")) == "start_card_skipped", "insufficient stock must use the explicit skip reason")

	var blacksmith := _build_fixture(_standard_catalog(), "blacksmith")
	var blacksmith_choices := _offer_choices(TowerStartCardOfferBuilder.new().build_offer(
		"blacksmith-no-chosik",
		blacksmith.owner,
		blacksmith.registry
	))
	_expect(blacksmith_choices.size() == 3, "Blacksmith must still receive three cards")
	_expect(_kind_count(blacksmith_choices, "chosik") == 0, "Blacksmith must not receive another character's Chosik")
	_expect(_kind_count(blacksmith_choices, "mugong") == 3, "Blacksmith must receive three Mugong cards")


func _verify_target_level_path_is_single_shot() -> void:
	_leg_count += 1
	var runtime := TargetLevelRuntimeProbe.new()
	var result := RuntimePerkChoiceApplyFlow.new().apply_choice_at_target_level_from_runtime_state(
		runtime,
		_mugong("target_level_mugong"),
		2,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(bool(result.get("accepted", false)), "target-level grant path must accept a regular Mugong")
	_expect(int(runtime.runtime_skill_levels.get("target_level_mugong", 0)) == 2, "target-level grant must set the actual runtime value to two")
	_expect(runtime.side_effect_calls == 1, "one two-star grant must fire level side effects exactly once")
	_expect(runtime.feedback_calls == 1, "one two-star grant must fire acquisition feedback exactly once")
	var blocked := RuntimePerkChoiceApplyFlow.new().apply_choice_at_target_level_from_runtime_state(
		runtime,
		_mugong("single_rank", {"max_level": 1}),
		2,
		FakeOwner.new(),
		FakeRegistry.new()
	)
	_expect(not bool(blocked.get("accepted", true)), "max-level-one Mugong must reject a two-star target grant")
	_expect(runtime.side_effect_calls == 1 and runtime.feedback_calls == 1, "rejected target grants must not fire side effects")
	var production_runtime := RuntimePerkState.new()
	_expect(
		production_runtime.apply_choice_at_target_level(
			_mugong("production_target_level"),
			2,
			null,
			null
		),
		"production RuntimePerkState must expose the target-level grant"
	)
	_expect(
		int(production_runtime.runtime_skill_levels.get("production_target_level", 0)) == 2,
		"production target-level entry must commit an actual level-two value"
	)
	_expect(
		production_runtime.apply_choice(_mugong("legacy_single_level"), null, null),
		"existing one-level apply_choice must remain accepted"
	)
	_expect(
		int(production_runtime.runtime_skill_levels.get("legacy_single_level", 0)) == 1,
		"existing apply_choice consumers must still gain exactly one level"
	)


func _verify_apply_and_single_pick_contract() -> void:
	_leg_count += 1
	var mugong_fixture := _build_fixture(_standard_catalog())
	var mugong_state := TowerStartCardState.new()
	_expect(mugong_state.begin(mugong_fixture.owner, mugong_fixture.registry), "state must begin with a valid offer")
	var mugong_index := _find_kind_index(mugong_state.get_card_choices(), "mugong")
	_expect(mugong_state.select_slot(mugong_index), "Mugong start card must apply")
	var mugong_result := mugong_state.get_selection_result()
	var mugong_id := str(mugong_result.get("picked_perk_id", ""))
	_expect(int((mugong_fixture.runtime_state as FakeRuntimeState).runtime_skill_levels.get(mugong_id, 0)) == 2, "Mugong choice must set the actual runtime level to two")
	_expect((mugong_fixture.runtime_state as FakeRuntimeState).target_apply_calls == 1, "Mugong two-star grant must call the target-level entry exactly once")
	_expect((mugong_fixture.runtime_state as FakeRuntimeState).apply_calls == 0, "Mugong two-star grant must not call the one-level entry twice")
	_expect(str((mugong_fixture.runtime_state as FakeRuntimeState).seen_context.get("source", "")) == "tower_start_card", "grant must expose tower_start_card source")
	_expect((mugong_fixture.runtime_state as FakeRuntimeState).current_choice_context == {"source": "before_start_card"}, "grant must restore the previous choice context")
	_expect(not mugong_state.select_slot(mugong_index), "a second click after the one pick must be a no-op")
	var frozen_cards := mugong_state.get_card_choices()
	_expect(frozen_cards.size() == 3, "selection must preserve all three card slots")
	for choice in frozen_cards:
		_expect(not bool(choice.get("enabled", true)), "selection must disable every remaining card")
	mugong_state.update(TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC)
	_expect(mugong_state.is_completed() and not mugong_state.is_active(), "absorb completion must end the phase")

	var chosik_fixture := _build_fixture(_standard_catalog())
	var chosik_state := TowerStartCardState.new()
	_expect(chosik_state.begin(chosik_fixture.owner, chosik_fixture.registry), "Chosik fixture must begin")
	var chosik_index := _find_kind_index(chosik_state.get_card_choices(), "chosik")
	var chosik_choice := chosik_state.get_card_choices()[chosik_index]
	_expect(chosik_state.select_slot(chosik_index), "Chosik start card must apply")
	_expect((chosik_fixture.skill_config as FakeSkillConfig).equipped_skills.has(str(chosik_choice.get("unlocks_skill", ""))), "Chosik choice must equip its unlocked skill")


func _verify_pending_swap_fails_closed() -> void:
	_leg_count += 1
	var fixture := _build_fixture(_standard_catalog())
	(fixture.runtime_state as FakeRuntimeState).force_pending_swap = true
	var state := TowerStartCardState.new()
	_expect(state.begin(fixture.owner, fixture.registry), "pending-swap fixture must begin")
	var chosik_index := _find_kind_index(state.get_card_choices(), "chosik")
	_expect(not state.select_slot(chosik_index), "a pending Chosik swap must fail closed")
	_expect((fixture.runtime_state as FakeRuntimeState).cancel_calls == 1, "pending swap must be explicitly canceled")
	_expect(not (fixture.runtime_state as FakeRuntimeState).pending_swap, "pending swap state must not leak past the start card")
	_expect(state.is_completed() and state.was_skipped(), "failed grant must end instead of hanging")


func _verify_render_and_localization_contract() -> void:
	_leg_count += 1
	var locales := TowerStartCardLocalization.get_supported_locales()
	_expect(locales == ["ko", "en", "zh", "ja", "es", "pt-BR", "ru"], "start-card copy must cover the seven supported locales")
	for locale in locales:
		for copy_key in ["title", "instruction", "confirmed"]:
			_expect(TowerStartCardLocalization.text_for_locale(copy_key, locale) != "", "%s %s copy must not be empty" % [locale, copy_key])
	_expect(TowerStartCardLocalization.text_for_locale("title", "ko").find("—") < 0, "Korean start-card copy must not use an em dash")
	_expect(TowerStartCardLocalization.text_for_locale("instruction", "ko").find("—") < 0, "Korean instruction copy must not use an em dash")
	_expect(TowerStartCardLocalization.text_for_locale("confirmed", "ko").find("—") < 0, "Korean confirmation copy must not use an em dash")

	var fixture := _build_fixture(_standard_catalog())
	var state := TowerStartCardState.new()
	_expect(state.begin(fixture.owner, fixture.registry), "render fixture must begin")
	state.update(TowerAscentTuning.TEMP_START_CARD_INTRO_ANIM_SEC)
	var view_size := Vector2(2020.0, 1246.0)
	var view_model := state.build_view_model(view_size)
	var rects: Array = view_model.get("card_rects", [])
	_expect(rects.size() == 3, "start-card view model must expose three card rects")
	_expect(bool(view_model.get("stats_band_enabled", false)), "available stats context must request the shared stats band")
	for choice_value in view_model.get("choices", []):
		var choice: Dictionary = choice_value if choice_value is Dictionary else {}
		for forbidden_key in ["reward_pick_cost", "reward_pick_price_text", "balance_text"]:
			_expect(not choice.has(forbidden_key), "start-card view model must omit %s" % forbidden_key)
	for index in range(rects.size()):
		var rect: Rect2 = rects[index]
		_expect(state.get_card_index_at(rect.get_center(), view_size) == index, "draw and hit-test layout must agree for slot %d" % index)
	var mugong_index := _find_kind_index(state.get_card_choices(), "mugong")
	var hit_view_size := Vector2(760.0, 750.0)
	var hit_rects := state.get_card_rects(hit_view_size)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = (hit_rects[mugong_index] as Rect2).get_center()
	state.handle_input(click, fixture.owner, fixture.registry)
	_expect(bool(state.get_selection_result().get("accepted", false)), "clicking a rendered Mugong card must apply it")
	_expect(int((fixture.runtime_state as FakeRuntimeState).runtime_skill_levels.get(str(state.get_selection_result().get("picked_perk_id", "")), 0)) == 2, "rendered Mugong selection must still grant actual level two")
	var selected_model := state.build_view_model(view_size)
	_expect(str(selected_model.get("status_text", "")) == TowerStartCardLocalization.text("confirmed"), "selected view model must show the localized confirmation")
	state.tear_down()
	_expect(not (fixture.runtime_state as FakeRuntimeState).stats_context_active, "start-card teardown must release the shared runtime stats context")

	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/hud/runtime_perk_overlay_renderer.gd"
	)
	var start_index := renderer_source.find("func draw_tower_start_card(")
	var reward_index := renderer_source.find("func draw_tower_reward_pick(")
	_expect(start_index >= 0 and reward_index > start_index, "renderer must expose a separate start-card entry point")
	var start_source := renderer_source.substr(start_index, reward_index - start_index)
	for shared_drawer in ["_draw_card(", "_draw_per_card_descriptions(", "_draw_status_panel(", "_draw_stats_band("]:
		_expect(start_source.find(shared_drawer) >= 0, "start-card renderer must reuse %s" % shared_drawer)
	for forbidden_surface in ["reward_pick_price_text", "balance_text", "continue_text", "draw_backdrop("]:
		_expect(start_source.find(forbidden_surface) < 0, "start-card renderer must omit %s" % forbidden_surface)


func _verify_real_battle_scene_shell_wiring() -> void:
	_leg_count += 1
	var selection_state: Object = get_root().get_node_or_null("GameSelectionState")
	var owns_selection_state := false
	if selection_state == null:
		selection_state = GameSelectionState.new()
		selection_state.name = "GameSelectionState"
		get_root().add_child(selection_state)
		owns_selection_state = true
	while bool(selection_state.consume_tower_start_card_entry_request()):
		pass

	var flow_owner := FakeFlowOwner.new()
	var unlock_store := FakeUnlockStore.new()
	var skill_config := FakeSkillConfig.new()
	var catalog := FakeCatalog.new()
	catalog.data = _standard_catalog()
	var runtime_state := FakeRuntimeState.new()
	runtime_state.skill_config = skill_config
	var start_card := TowerStartCardState.new()
	var flow := BattleSceneFlowController.new()
	flow.set("_battle_initialized", true)
	var warmup := FakeWarmup.new()
	var loading := FakeLoadingRenderer.new()
	var audio := FakeStageAudio.new()
	var landing := FakeLandingIntro.new()
	var update_driver := FakeBattleUpdateDriver.new()
	var han_prologue := FakeHanMiryangPrologue.new()
	var modal_gate := BattleSceneModalGateController.new()
	var registry := ShellRegistry.new()
	registry.instances = {
		"tower_start_card_state": start_card,
		"tower_ascent_flow_owner": flow_owner,
		"tower_ascent_unlock_store": unlock_store,
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": skill_config,
		"battle_scene_flow_controller": flow,
		"battle_scene_frame_controller": BattleSceneFrameController.new(),
		"battle_scene_intro_frame_controller": BattleSceneIntroFrameController.new(),
		"battle_scene_readiness_controller": BattleSceneReadinessController.new(),
		"battle_scene_modal_gate_controller": modal_gate,
		"battle_scene_input_controller": BattleSceneInputController.new(),
		"battle_boot_warmup_controller": warmup,
		"battle_loading_screen_renderer": loading,
		"stage_landing_intro": landing,
		"stage1_han_miryang_prologue_presentation": han_prologue,
		"game_audio": audio,
		"battle_scene_update_driver": update_driver,
	}
	var shell: Node2D = BattleSceneShell.new()
	shell.gameplay_modules = registry
	shell.set_process(false)
	shell.set_physics_process(false)
	shell.set("selected_runtime_character_id", "viper")
	get_root().add_child(shell)

	selection_state.request_tower_start_card_entry()
	shell._process(1.0 / 60.0)
	_expect(not start_card.is_active(), "start card must not open before boot warmup finishes")
	_expect(selection_state.peek_tower_start_card_entry_request(), "unfinished warmup must preserve the one-shot entry token")
	warmup.finished = true
	shell._process(1.0 / 60.0)
	_expect(start_card.is_active(), "real BattleSceneShell must open the start card after warmup")
	_expect(not selection_state.peek_tower_start_card_entry_request(), "real shell entry must consume the token exactly once")
	_expect(not flow.is_stage_landing_intro_started(), "start card must not arm the landing latch")
	_expect(not bool(flow.get("_battle_bgm_started")) and audio.play_calls == 0, "start card must keep stage BGM stopped")
	_expect(landing.begin_calls == 0, "landing intro must wait behind the start card")

	shell._process(0.05)
	_expect(float(start_card.get_status_for_tests().get("elapsed_sec", 0.0)) > 0.0, "real shell idle frames must advance the start card")
	_expect(update_driver.update_calls == 0, "start-card idle frames must not leak into battle update")
	shell.queue_redraw()
	await process_frame
	_expect(loading.draw_calls == 0, "active start card must preempt the loading renderer")
	_expect(loading.hide_calls > 0, "active start card draw must hide the loading host")
	var readiness: Object = registry.instances["battle_scene_readiness_controller"]
	_expect(readiness.is_intro_or_warmup_blocking(Callable(shell, "_get_module"), true, false), "readiness must report the start card as blocking")
	_expect(not readiness.is_mobile_touch_scene_ready(Callable(shell, "_get_module"), true, true), "mobile controls must remain disabled during the start card")

	flow.set("_stage_landing_intro_started", true)
	shell._physics_process(1.0 / 60.0)
	_expect(update_driver.update_calls == 0, "real shell physics must stop at the start-card modal gate")
	_expect(modal_gate.should_block_battle_physics(Callable(shell, "_get_module")), "modal gate must expose the active start card")
	flow.set("_stage_landing_intro_started", false)
	han_prologue.active = true
	var choose_first := InputEventKey.new()
	choose_first.pressed = true
	choose_first.keycode = KEY_1
	shell._unhandled_input(choose_first)
	_expect(bool(start_card.get_selection_result().get("accepted", false)), "real shell input must apply one start card")
	_expect(han_prologue.input_calls == 0, "start-card input must be consumed before the prologue router")
	han_prologue.active = false

	loading.hold = true
	var hold_calls_before_completion := loading.hold_calls
	shell._process(TowerAscentTuning.TEMP_START_CARD_ABSORB_DURATION_SEC)
	_expect(start_card.is_completed() and not start_card.is_active(), "selection absorb must complete through the real shell frame")
	_expect(flow.is_stage_landing_intro_started(), "the completion frame must continue directly into landing")
	_expect(bool(flow.get("_battle_bgm_started")) and audio.play_calls == 1, "the existing landing path must start BGM exactly once after completion")
	_expect(landing.begin_calls == 1, "the existing landing intro must begin on the completion frame")
	_expect(loading.hold_calls == hold_calls_before_completion, "completion must not re-enter the loading hold")
	shell._physics_process(1.0 / 60.0)
	_expect(update_driver.update_calls == 1, "battle physics must resume after the start card completes")

	start_card.tear_down()
	flow = BattleSceneFlowController.new()
	flow.set("_battle_initialized", true)
	registry.instances["battle_scene_flow_controller"] = flow
	catalog.data = {
		"m1": _mugong("m1"),
		"c1": _chosik("c1", "skill_alpha"),
	}
	loading.hold = false
	selection_state.request_tower_start_card_entry()
	shell._begin_stage_landing_intro()
	_expect(start_card.was_skipped() and not start_card.is_active(), "insufficient candidates must skip instead of opening an empty screen")
	_expect(flow.is_stage_landing_intro_started(), "insufficient stock must continue into landing in the same call")

	start_card.tear_down()
	flow = BattleSceneFlowController.new()
	flow.set("_battle_initialized", true)
	registry.instances["battle_scene_flow_controller"] = flow
	selection_state.request_tower_start_card_entry()
	var start_card_lookups_before_off := int(registry.instance_calls.get("tower_start_card_state", 0))
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	shell._begin_stage_landing_intro()
	_expect(flow.is_stage_landing_intro_started(), "flag OFF must preserve the existing landing path")
	shell._process(1.0 / 60.0)
	shell._physics_process(1.0 / 60.0)
	var off_input := InputEventKey.new()
	off_input.pressed = true
	off_input.keycode = KEY_1
	shell._unhandled_input(off_input)
	shell.queue_redraw()
	await process_frame
	var off_readiness: Object = registry.instances["battle_scene_readiness_controller"]
	off_readiness.is_intro_or_warmup_blocking(Callable(shell, "_get_module"), true, true)
	off_readiness.is_mobile_touch_scene_ready(Callable(shell, "_get_module"), true, true)
	modal_gate.should_block_battle_physics(Callable(shell, "_get_module"))
	_expect(int(registry.instance_calls.get("tower_start_card_state", 0)) == start_card_lookups_before_off, "flag OFF must bypass the start-card module at all six shell seams")
	_expect(selection_state.peek_tower_start_card_entry_request(), "flag OFF must not consume the tower entry token")
	selection_state.consume_tower_start_card_entry_request()

	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_expect(not start_card.begin(shell, registry), "direct battle entry without a token must not open the start card")
	start_card.capture_stats_context(shell, registry)
	BattleSceneTeardownLifecycle.new().exit_tree(
		shell,
		registry,
		Callable(shell, "_get_cached_module"),
		{}
	)
	var teardown_status := start_card.get_status_for_tests()
	_expect(not bool(teardown_status.get("owner_attached", true)), "teardown must release the start-card owner")
	_expect(not bool(teardown_status.get("registry_attached", true)), "teardown must release the start-card registry")
	_expect(not bool(teardown_status.get("stats_owner_attached", true)), "teardown must release the stats owner")
	_expect(not bool(teardown_status.get("stats_registry_attached", true)), "teardown must release the stats registry")
	shell.free()
	if owns_selection_state:
		selection_state.free()


func _verify_source_contract() -> void:
	_leg_count += 1
	var builder_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_start_card_offer_builder.gd"
	)
	var state_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_start_card_state.gd"
	)
	_expect(builder_source.count("get_all_perk_data") == 2, "builder source must contain one call plus one contract comment")
	_expect(builder_source.find("get_perk_data") < 0, "builder must not repeat per-ID catalog lookups")
	_expect(builder_source.find("choices.shuffle") < 0, "builder must not use global Array shuffle")
	_expect(builder_source.find("RandomNumberGenerator.new()") >= 0, "builder must own a private RNG")
	for forbidden_method in [
		"apply_reward_pick_purchase",
		"finalize_reward_pick",
		"get_reward_pick_context",
		"apply_once",
	]:
		_expect(state_source.find(forbidden_method) < 0, "state must not enter reward transaction path: %s" % forbidden_method)


func _build_fixture(
	catalog_data: Dictionary,
	character_type: String = "smasher"
) -> Dictionary:
	var owner := FakeOwner.new()
	owner.selected_character_type = character_type
	owner.selection_state = FakeSelectionState.new()
	var flow_owner := FakeFlowOwner.new()
	var unlock_store := FakeUnlockStore.new()
	var skill_config := FakeSkillConfig.new()
	var catalog := FakeCatalog.new()
	catalog.data = catalog_data.duplicate(true)
	var runtime_state := FakeRuntimeState.new()
	runtime_state.skill_config = skill_config
	var registry := FakeRegistry.new()
	registry.instances = {
		"tower_ascent_flow_owner": flow_owner,
		"tower_ascent_unlock_store": unlock_store,
		"runtime_perk_state": runtime_state,
		"runtime_perk_catalog": catalog,
		"smasher_skill_config": skill_config,
		"blacksmith_skill_config": skill_config,
	}
	return {
		"owner": owner,
		"flow_owner": flow_owner,
		"unlock_store": unlock_store,
		"skill_config": skill_config,
		"catalog": catalog,
		"runtime_state": runtime_state,
		"registry": registry,
	}


func _standard_catalog() -> Dictionary:
	return {
		"mugong_alpha": _mugong("mugong_alpha"),
		"mugong_beta": _mugong("mugong_beta"),
		"mugong_gamma": _mugong("mugong_gamma"),
		"mugong_delta": _mugong("mugong_delta"),
		"mugong_epsilon": _mugong("mugong_epsilon"),
		"mugong_zeta": _mugong("mugong_zeta"),
		"chosik_alpha": _chosik("chosik_alpha", "skill_alpha"),
		"chosik_beta": _chosik("chosik_beta", "skill_beta"),
		"chosik_gamma": _chosik("chosik_gamma", "skill_gamma"),
		"chosik_delta": _chosik("chosik_delta", "skill_delta"),
		"mugong_mythic": _mugong("mugong_mythic", {"rarity": "mythic"}),
		"mugong_instant": _mugong("mugong_instant", {"is_instant": true}),
		"mugong_training": _mugong("mugong_training", {"is_physique_training": true}),
		"mugong_locked": _mugong("mugong_locked"),
		"mugong_other_character": _mugong("mugong_other_character", {"character_restriction": "viper"}),
		"mugong_single_rank": _mugong("mugong_single_rank", {"max_level": 1}),
	}


func _mugong(perk_id: String, extra: Dictionary = {}) -> Dictionary:
	var data := {
		"id": perk_id,
		"name": perk_id,
		"max_level": 5,
	}
	data.merge(extra, true)
	return data


func _chosik(perk_id: String, skill_id: String) -> Dictionary:
	return {
		"id": perk_id,
		"name": perk_id,
		"max_level": 1,
		"unlocks_skill": skill_id,
		"character_restriction": "smasher",
	}


func _offer_choices(offer: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var value: Variant = offer.get("choices", [])
	if value is Array:
		for choice_value in value as Array:
			if choice_value is Dictionary:
				result.append(choice_value as Dictionary)
	return result


func _choice_ids(choices: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for choice in choices:
		result.append(str(choice.get("id", "")))
	return result


func _kind_count(choices: Array[Dictionary], kind: String) -> int:
	var count := 0
	for choice in choices:
		if str(choice.get("start_card_kind", "")) == kind:
			count += 1
	return count


func _find_kind_index(choices: Array[Dictionary], kind: String) -> int:
	for index in range(choices.size()):
		if str(choices[index].get("start_card_kind", "")) == kind:
			return index
	return -1


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
