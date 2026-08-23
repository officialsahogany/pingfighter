extends SceneTree

const BallDependencyContext := preload("res://scripts/ball/ball_dependency_context.gd")
const BattleBossSpritePaths := preload("res://scripts/resources/battle_boss_sprite_paths.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const BattleSceneMatchEventDriver := preload(
	"res://scripts/core/battle_scene_match_event_driver.gd"
)
const BattleSceneSelectionStartupLifecycle := preload(
	"res://scripts/core/battle_scene_selection_startup_lifecycle.gd"
)
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const TowerAscentBossRegistry := preload(
	"res://scripts/tower_ascent/tower_ascent_boss_registry.gd"
)
const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentFlowRenderer := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
)
const TowerAuditionBuildConfig := preload(
	"res://scripts/tower_ascent/tower_audition_build_config.gd"
)

var _failures: Array[String] = []
var _leg_count := 0


class FakeOwner:
	extends RefCounted

	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var selected_character_type := "smasher"
	var ai_mode := "champion"
	var arena_mode_enabled := false
	var weather_type := ""
	var weather_event_active := false
	var weather_event_context := {}
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var battle_textures := {}
	var smasher_skill_icon_textures := {}
	var viper_skill_icon_textures := {}
	var commando_skill_icon_textures := {}
	var redraw_calls := 0

	func get_node_or_null(_path: NodePath) -> Object:
		return null

	func queue_redraw() -> void:
		redraw_calls += 1


class FakeBallPhysics:
	extends RefCounted

	func configure_context(
		_stage_id: int,
		_ai_mode: String,
		_arena_enabled: bool,
		_weather_type: String
	) -> void:
		pass


class FakeMatchFlowDriver:
	extends RefCounted

	func reset_for_stage_transition(
		_owner: Object,
		_registry: Object,
		_reset_drive_input_frames_callback: Callable,
		_reset_ball_callback: Callable
	) -> void:
		pass


class FakeLoadingRenderer:
	extends RefCounted

	func draw(
		_canvas: CanvasItem,
		_owner: Object,
		_module_getter: Callable,
		_view_size: Vector2,
		_context: Dictionary = {}
	) -> void:
		pass


class RecordingBattleResources:
	extends RefCounted

	var delegate: Object = BattleResources.new()
	var load_all_calls := 0
	var last_context: Dictionary = {}

	func reset_transition_texture_prewarm() -> void:
		delegate.reset_transition_texture_prewarm()

	func load_all(context: Dictionary = {}) -> Dictionary:
		load_all_calls += 1
		last_context = context.duplicate(true)
		return delegate.load_all(context)


class FakeRegistry:
	extends RefCounted

	var battle_resources := RecordingBattleResources.new()
	var ball_physics := FakeBallPhysics.new()
	var match_flow_driver := FakeMatchFlowDriver.new()
	var loading_renderer := FakeLoadingRenderer.new()
	var requested_script_keys: Array[String] = []
	var round_dep_instances: Dictionary = {}

	func request_threaded_script(key: String) -> bool:
		if not requested_script_keys.has(key):
			requested_script_keys.append(key)
		return true

	func is_threaded_script_ready(_key: String) -> bool:
		return true

	func get_instance(key: String) -> Object:
		match key:
			"battle_resources":
				return battle_resources
			"ball_physics":
				return ball_physics
			"battle_scene_match_flow_driver":
				return match_flow_driver
			"battle_loading_screen_renderer":
				return loading_renderer
		if key.begins_with("stage1_"):
			if not round_dep_instances.has(key):
				round_dep_instances[key] = RefCounted.new()
			return round_dep_instances[key]
		return null

	func get_cached_instance(key: String) -> Object:
		return round_dep_instances.get(key, null)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	TowerAuditionBuildConfig.debug_set_enabled(false)
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	_verify_seed_is_single_authority_and_rerolls()
	_verify_floor_one_roster_and_icon_parity()
	_verify_stage1_transition_variant_parity("gaksi")
	_verify_stage1_transition_variant_parity("podo")
	_verify_legacy_flag_off_keeps_seed_zero()
	TowerAuditionBuildConfig.debug_clear_enabled_override()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	_expect(_leg_count == 5, "all five floor-one identity legs must execute")

	if _failures.is_empty():
		print("floor_one_boss_identity_smoke: legs=%d" % _leg_count)
		print("floor_one_boss_identity_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _verify_seed_is_single_authority_and_rerolls() -> void:
	_leg_count += 1
	var selection_state := GameSelectionState.new()
	selection_state.request_tower_start_card_entry()
	var first_seed := int(selection_state.get_selection().get("tower_map_seed", 0))
	selection_state.request_tower_start_card_entry()
	var second_selection: Dictionary = selection_state.get_selection()
	var second_seed := int(second_selection.get("tower_map_seed", 0))
	_expect(first_seed != 0, "vertical-slice run one must receive a nonzero map seed")
	_expect(second_seed != 0, "vertical-slice run two must receive a nonzero map seed")
	_expect(second_seed != first_seed, "a second run in the same session must reroll the map seed")

	var registry := TowerAscentBossRegistry.new()
	var seeded_slots := registry.get_seeded_floor_slots(1, second_seed)
	_expect(seeded_slots.size() == 3, "seeded first-floor authority must expose all three bosses")
	if seeded_slots.size() == 3:
		var expected_variant := str(seeded_slots[0].get("variant", ""))
		var lifecycle := BattleSceneSelectionStartupLifecycle.new()
		var random_seed := _find_random_counterproof_seed(lifecycle, expected_variant)
		_expect(random_seed >= 0, "counterproof must find an old roulette result that differs from the gate")
		lifecycle.set_stage1_boss_rng_seed_for_test(random_seed)
		var opening_variant := lifecycle.resolve_stage1_boss_variant(second_selection, 1)
		_expect(
			opening_variant == expected_variant,
			"opening variant %s must equal seeded gate variant %s"
			% [opening_variant, expected_variant]
		)
	selection_state.free()


func _verify_floor_one_roster_and_icon_parity() -> void:
	_leg_count += 1
	var selection_state := GameSelectionState.new()
	selection_state.request_tower_start_card_entry()
	var selection: Dictionary = selection_state.get_selection()
	var map_seed := int(selection.get("tower_map_seed", 0))
	var lifecycle := BattleSceneSelectionStartupLifecycle.new()
	var opening_variant := lifecycle.resolve_stage1_boss_variant(selection, 1)
	var owner := FakeOwner.new()
	owner.stage1_boss_variant = opening_variant
	var flow := TowerAscentFlowOwner.new()
	_expect(
		flow.prepare_vertical_slice_combat(owner, {
			"run_id": "floor-one-boss-identity-smoke",
			"current_stage": 1,
			"map_seed": map_seed,
		}),
		"production tower flow must prepare from the selection map seed"
	)
	_expect(flow.get_map_seed() == map_seed, "tower flow must retain the exact selection seed")

	var registry := TowerAscentBossRegistry.new()
	var renderer := TowerAscentFlowRenderer.new()
	var seeded_slots := registry.get_seeded_floor_slots(1, map_seed)
	var floor_one_nodes: Array[Dictionary] = []
	for node in flow.get_graph_nodes():
		if (
			int(node.get("segment_floor", node.get("floor", 0))) == 1
			and str(node.get("kind", "")) in TowerAscentBossRegistry.COMBAT_NODE_KINDS
			and str(node.get("content_state", "")) == TowerAscentBossRegistry.CONTENT_GENERATED
		):
			floor_one_nodes.append(node)
	_expect(floor_one_nodes.size() == 3, "opening plus two choices must expose three first-floor combat nodes")

	var encounter_keys: Dictionary = {}
	var icon_ids: Dictionary = {}
	var gate_node: Dictionary = {}
	for node in floor_one_nodes:
		var encounter_key := registry.canonical_encounter_key(node.get("standin", {}))
		var presentation := renderer.build_map_icon_presentation(node)
		var icon_id := str(presentation.get("boss_id", ""))
		_expect(not encounter_key.is_empty(), "every first-floor node must resolve a canonical encounter key")
		_expect(not encounter_keys.has(encounter_key), "first-floor canonical encounters must not repeat: %s" % encounter_key)
		encounter_keys[encounter_key] = true
		_expect(not icon_id.is_empty(), "every first-floor node must resolve its production icon identity")
		_expect(not icon_ids.has(icon_id), "first-floor production icon identities must be distinct: %s" % icon_id)
		icon_ids[icon_id] = true
		_expect(
			FileAccess.file_exists(str(presentation.get("icon_path", ""))),
			"first-floor icon source PNG must exist: %s" % icon_id
		)
		_expect(presentation.get("icon_texture", null) is Texture2D, "first-floor icon PNG must load: %s" % icon_id)
		if presentation.get("icon_texture", null) is Texture2D:
			_expect(
				(presentation.get("icon_texture") as Texture2D).get_size() == Vector2(256.0, 256.0),
				"first-floor icon must keep the 256x256 runtime contract: %s" % icon_id
			)
		if str(node.get("id", "")) == flow.get_current_node_id():
			gate_node = node
	_expect(encounter_keys.size() == 3, "the first-floor real combat set must cover all three bosses")
	_expect(icon_ids.size() == 3, "the actual map draw path must expose three different first-floor icons")
	_expect(not gate_node.is_empty(), "the flow entry must resolve the opening gate node")
	if not gate_node.is_empty():
		var gate_variant := str((gate_node.get("standin", {}) as Dictionary).get("variant", ""))
		var gate_icon := str(renderer.build_map_icon_presentation(gate_node).get("boss_id", ""))
		_expect(
			seeded_slots.size() == 3
			and str(gate_node.get("boss_slot_id", "")) == str(seeded_slots[0].get("slot_id", "")),
			"graph gate first-unused slot must remain structurally identical to seeded slots[0]"
		)
		_expect(gate_variant == opening_variant, "opening combat must equal the graph gate encounter")
		_expect(gate_icon == _icon_id_for_variant(opening_variant), "gate icon must equal the opening combat identity")
		var positive_report := registry.analyze_boss_node_identity(gate_node, opening_variant)
		_expect(bool(positive_report.get("valid", false)), "canonical opening/gate fixture must be GREEN")
		var forced_opening := "gaksi" if opening_variant != "gaksi" else "podo"
		var forced_report := registry.analyze_boss_node_identity(gate_node, forced_opening)
		_expect(not bool(forced_report.get("valid", true)), "forced opening/gate mismatch fixture must be RED")
		_expect(
			_has_issue_prefix(forced_report, "opening_gate_mismatch="),
			"forced opening/gate RED must identify the canonical-key mismatch"
		)
		var corrupted_node := gate_node.duplicate(true)
		corrupted_node["boss_encounter_key"] = "1:corrupted_counterproof"
		var corrupted_report := registry.analyze_boss_node_identity(corrupted_node)
		_expect(not bool(corrupted_report.get("valid", true)), "corrupted node identity fixture must be RED")
		_expect(
			_has_issue_prefix(corrupted_report, "standin_key_mismatch=")
			and _has_issue_prefix(corrupted_report, "slot_key_mismatch="),
			"corrupted node RED must identify both stand-in and slot key drift"
		)
		_expect(
			bool(flow.call("_warn_boss_identity_mismatch", corrupted_node)),
			"runtime mismatch guard must emit the shared warning range for a corrupted node"
		)
	var ending_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_ending_progress.gd"
	)
	_expect(
		ending_source.find("_warn_boss_identity_mismatch(arrived_node)") >= 0,
		"map-transition completion must call the canonical identity warning guard"
	)
	selection_state.free()


func _verify_stage1_transition_variant_parity(variant: String) -> void:
	_leg_count += 1
	var driver := BattleSceneMatchEventDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var encounter := _encounter_for_variant(variant)
	_expect(driver.begin_tower_boss_transition(owner, registry, encounter), "%s transition must begin" % variant)
	_expect(owner.stage1_boss_variant == variant, "%s transition must apply owner identity before prewarm" % variant)

	var expected_dep_keys := BallDependencyContext.get_stage_round_dep_keys(1, variant)
	for key in expected_dep_keys:
		_expect(registry.requested_script_keys.has(key), "%s transition must request round dep %s" % [variant, key])
	var wrong_variant := "podo" if variant == "gaksi" else "gaksi"
	for wrong_key in BallDependencyContext.get_stage_round_dep_keys(1, wrong_variant):
		if not expected_dep_keys.has(wrong_key):
			_expect(not registry.requested_script_keys.has(wrong_key), "%s transition must not request sibling dep %s" % [variant, wrong_key])

	var canvas := Node2D.new()
	get_root().add_child(canvas)
	driver.draw_stage_transition_loading(
		canvas,
		owner,
		registry,
		Callable(registry, "get_instance"),
		Vector2(1280.0, 750.0)
	)
	canvas.queue_free()
	for _index in range(32):
		driver.update_stage_transition_loading(0.05, owner, registry)
		if registry.battle_resources.load_all_calls > 0:
			break
	_expect(registry.battle_resources.load_all_calls == 1, "%s real transition must reload battle textures once" % variant)
	_expect(
		str(registry.battle_resources.last_context.get("stage1_boss_variant", "")) == variant,
		"%s transition texture context must carry its Stage 1 variant" % variant
	)
	var expected_paths := _generic_texture_paths_for_variant(variant)
	for texture_key in expected_paths:
		var actual_path := _texture_resource_path(owner.battle_textures.get(texture_key, null))
		_expect(
			actual_path == str(expected_paths[texture_key]),
			"%s transition generic key %s must resolve %s, got %s"
			% [variant, texture_key, str(expected_paths[texture_key]), actual_path]
		)
	var key_context := registry.battle_resources.last_context.duplicate(true)
	var variant_prewarm_key: String = registry.battle_resources.delegate.build_transition_texture_prewarm_key(
		key_context
	)
	var sibling_context := key_context.duplicate(true)
	sibling_context["stage1_boss_variant"] = "podo" if variant == "gaksi" else "gaksi"
	var sibling_prewarm_key: String = registry.battle_resources.delegate.build_transition_texture_prewarm_key(
		sibling_context
	)
	var missing_variant_context := key_context.duplicate(true)
	missing_variant_context.erase("stage1_boss_variant")
	var missing_variant_key: String = registry.battle_resources.delegate.build_transition_texture_prewarm_key(
		missing_variant_context
	)
	_expect(
		variant_prewarm_key != sibling_prewarm_key,
		"Stage 1 transition prewarm key must differ between %s and its sibling" % variant
	)
	_expect(
		variant_prewarm_key.find(":%s:" % variant) >= 0,
		"Stage 1 transition prewarm key must include %s" % variant
	)
	_expect(
		missing_variant_key.find(":dalji:") >= 0 and missing_variant_key != variant_prewarm_key,
		"missing-variant counterproof must fall back to a different Dalji prewarm key"
	)


func _verify_legacy_flag_off_keeps_seed_zero() -> void:
	_leg_count += 1
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(false)
	var selection_state := GameSelectionState.new()
	selection_state.request_tower_start_card_entry()
	_expect(
		int(selection_state.get_selection().get("tower_map_seed", -1)) == 0,
		"explicit vertical-slice OFF must preserve the legacy seed-zero campaign route"
	)
	selection_state.free()
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)


func _find_random_counterproof_seed(lifecycle: Object, gate_variant: String) -> int:
	for candidate_seed in range(1, 256):
		lifecycle.set_stage1_boss_rng_seed_for_test(candidate_seed)
		if lifecycle.select_random_stage1_boss_variant() != gate_variant:
			return candidate_seed
	return -1


func _encounter_for_variant(variant: String) -> Dictionary:
	var slot_id := "floor_01_gaksital" if variant == "gaksi" else "floor_01_podo"
	return TowerAscentBossRegistry.new().resolve_battle_encounter(slot_id)


func _generic_texture_paths_for_variant(variant: String) -> Dictionary:
	if variant == "gaksi":
		return {
			"boss_walk_right_sheet": BattleBossSpritePaths.GAKSITAL_BOSS_WALK_RIGHT_PATH,
			"boss_idle_sheet": BattleBossSpritePaths.GAKSITAL_BOSS_IDLE_PATH,
			"boss_attack_sheet": BattleBossSpritePaths.GAKSITAL_BOSS_ATTACK_PATH,
		}
	return {
		"boss_walk_right_sheet": BattleBossSpritePaths.PODODAEJANG_BOSS_WALK_PATH,
		"boss_idle_sheet": BattleBossSpritePaths.PODODAEJANG_BOSS_IDLE_PATH,
		"boss_attack_sheet": BattleBossSpritePaths.PODODAEJANG_BOSS_ATTACK_PATH,
	}


func _texture_resource_path(value: Variant) -> String:
	return str((value as Resource).resource_path) if value is Resource else ""


func _icon_id_for_variant(variant: String) -> String:
	return "gaksital" if variant == "gaksi" else variant


func _has_issue_prefix(report: Dictionary, prefix: String) -> bool:
	for issue_variant in report.get("issues", []):
		if str(issue_variant).begins_with(prefix):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
