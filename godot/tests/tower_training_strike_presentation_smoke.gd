extends SceneTree

const TowerAscentFeatureFlags := preload(
	"res://scripts/tower_ascent/tower_ascent_feature_flags.gd"
)
const TowerAscentFlowOwner := preload(
	"res://scripts/tower_ascent/tower_ascent_flow_owner.gd"
)
const TowerAscentNodeArrivalTestFixture := preload(
	"res://tests/tower_ascent_node_arrival_test_fixture.gd"
)
const TowerAscentUnlockFilter := preload(
	"res://scripts/tower_ascent/tower_ascent_unlock_filter.gd"
)
const TowerTrainingStrikePresentationState := preload(
	"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
)

const CHARACTER_LEGS := {
	"smasher": {
		"motion_kind": "directional_attack",
		"weapon_kind": "paddle",
		"source_key": "player_attack_right_sheet",
		"contact_msec": 360,
		"contact_frame": 8,
	},
	"viper": {
		"motion_kind": "directional_attack",
		"weapon_kind": "arm_blade",
		"source_key": "viper_player_attack_right_sheet",
		"contact_msec": 360,
		"contact_frame": 4,
	},
	"soldier": {
		"motion_kind": "commando_pistol_fire",
		"weapon_kind": "firearm",
		"source_key": "commando_player_pistol_fire_sheet",
		"contact_msec": 360,
		"contact_frame": 4,
	},
	"blacksmith": {
		"motion_kind": "directional_attack",
		"weapon_kind": "hammer",
		"source_key": "blacksmith_player_attack_right_sheet",
		"contact_msec": 360,
		"contact_frame": 8,
	},
	"optimus": {
		"motion_kind": "optimus_idle_tween",
		"weapon_kind": "energy_paddle",
		"source_key": "optimus_player_idle_sheet",
		"contact_msec": 90,
		"contact_frame": 0,
	},
}

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var current_stage := 4
	var selected_character_type := "smasher"
	var redraw_requests := 0

	func request_battle_redraw() -> void:
		redraw_requests += 1


class FakeUnlockStore:
	extends RefCounted

	func is_unlocked(_content_type: String, _content_id: String) -> bool:
		return true


class FakeRuntimePerkState:
	extends RefCounted
	var runtime_skill_levels: Dictionary = {}
	var training_counts: Dictionary = {}
	var apply_calls := 0

	func _capture_resume_pre_choice_velocity(_owner: Object) -> void:
		pass

	func _pause_skill_cooldowns_for_choice(_owner: Object, _registry: Object) -> void:
		pass

	func _resume_skill_cooldowns_for_choice() -> void:
		pass

	func _try_arm_resume_safety(_owner: Object, _registry: Object) -> void:
		pass

	func get_physique_training_count(training_id: String) -> int:
		return int(training_counts.get(training_id, 0))

	func get_physique_training_multiplier() -> float:
		return 1.0

	func is_physique_training_saturated(
		_training_id: String,
		_registry: Object = null
	) -> bool:
		return false

	func apply_choice(choice: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_calls += 1
		var choice_id := str(choice.get("id", ""))
		training_counts[choice_id] = int(training_counts.get(choice_id, 0)) + 1
		return true

	func build_unlock_save_snapshot() -> Dictionary:
		return {
			"runtime_skill_levels": runtime_skill_levels.duplicate(true),
			"physique_training": {"counts": training_counts.duplicate(true)},
		}


class FakeBattleResources:
	extends RefCounted
	var cache: Dictionary

	func _init(cache_value: Dictionary) -> void:
		cache = cache_value

	func get_resource_cache() -> Dictionary:
		return cache


class FakeAudio:
	extends RefCounted
	var play_count := 0
	var stop_count := 0
	var playing := false
	var last_source_x := 0.0

	func play_training_strike_hit(source_x: float) -> void:
		play_count += 1
		playing = true
		last_source_x = source_x

	func stop_training_strike_audio() -> void:
		stop_count += 1
		playing = false


class CountingRegistry:
	extends RefCounted
	var instances: Dictionary = {}
	var requests: Dictionary = {}

	func get_instance(key: String) -> Variant:
		requests[key] = int(requests.get(key, 0)) + 1
		return instances.get(key, null)

	func get_cached_instance(key: String) -> Variant:
		requests[key] = int(requests.get(key, 0)) + 1
		return instances.get(key, null)

	func request_count(key: String) -> int:
		return int(requests.get(key, 0))


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_all_character_motion_legs()
	_verify_production_pointer_and_idle_gates()
	_verify_source_and_host_contracts()
	TowerAscentFeatureFlags.debug_clear_vertical_slice_override()
	if _failures.is_empty():
		print("tower_training_strike_presentation_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_all_character_motion_legs() -> void:
	var texture_cache := _build_texture_cache()
	for character_value in CHARACTER_LEGS.keys():
		var character_type := str(character_value)
		var expected: Dictionary = CHARACTER_LEGS[character_type]
		var audio := FakeAudio.new()
		var state := TowerTrainingStrikePresentationState.new()
		state.configure(character_type, texture_cache, audio)
		var idle_debug: Dictionary = state.get_debug_state()
		var idle_model: Dictionary = state.get_visual_model()
		_expect(bool(idle_debug.get("configured", false)), "%s training presenter must configure" % character_type)
		_expect(not bool(idle_debug.get("active", true)), "%s idle timeline must be inactive" % character_type)
		_expect(int(idle_debug.get("active_update_count", -1)) == 0, "%s idle must perform zero strike updates" % character_type)
		_expect(int(idle_debug.get("active_model_build_count", -1)) == 0, "%s idle must perform zero dynamic model builds" % character_type)
		_expect(int(idle_debug.get("dynamic_layer_count", -1)) == 0, "%s idle must own zero dynamic layers" % character_type)
		_expect(int(idle_debug.get("host_node_count", -1)) == 0, "%s must own no Node host" % character_type)
		_expect(str(idle_debug.get("motion_kind", "")) == str(expected.get("motion_kind", "")), "%s must select its approved motion owner" % character_type)
		_expect(str(idle_debug.get("weapon_kind", "")) == str(expected.get("weapon_kind", "")), "%s must retain its own weapon identity" % character_type)
		_expect(str(idle_debug.get("sprite_source_key", "")) == str(expected.get("source_key", "")), "%s must resolve the production cache key" % character_type)
		_expect(bool(idle_debug.get("asset_present", false)), "%s approved source texture must be present" % character_type)
		_expect(_has_resolved_sprite(idle_model), "%s idle must draw a visible production sprite" % character_type)

		state.set_clock_msec_for_tests(1000)
		_expect(state.start(), "%s card strike must start" % character_type)
		var contact_msec := int(expected.get("contact_msec", 360))
		state.set_clock_msec_for_tests(1000 + contact_msec - 1)
		state.update_wall_clock()
		_expect(audio.play_count == 0, "%s must not emit contact audio before contact" % character_type)
		state.set_clock_msec_for_tests(1000 + contact_msec)
		state.update_wall_clock()
		var contact_model: Dictionary = state.get_visual_model()
		_expect(audio.play_count == 1, "%s must emit one contact event" % character_type)
		_expect(int(contact_model.get("frame_index", -1)) == int(expected.get("contact_frame", -2)), "%s must hold the approved production contact frame" % character_type)
		_expect(bool(contact_model.get("hitstop_active", false)), "%s contact must enter the 45ms lower-stage hitstop" % character_type)
		_expect(float((contact_model.get("stage_shake_offset", Vector2.ZERO) as Vector2).length()) <= TowerTrainingStrikePresentationState.STAGE_SHAKE_MAX_PX + 0.001, "%s shake magnitude must stay at or below 3px" % character_type)

		state.set_clock_msec_for_tests(1000 + contact_msec + 44)
		state.update_wall_clock()
		var hitstop_model: Dictionary = state.get_visual_model()
		_expect(int(hitstop_model.get("local_timeline_msec", -1)) == contact_msec, "%s lower timeline must remain frozen through hitstop ms 44" % character_type)
		_expect(int(hitstop_model.get("frame_index", -1)) == int(contact_model.get("frame_index", -2)), "%s character frame must freeze while wall time advances" % character_type)
		_expect(is_zero_approx(float(hitstop_model.get("dummy_rotation_radians", 1.0))), "%s dummy reaction must also freeze during hitstop" % character_type)

		state.set_clock_msec_for_tests(1000 + contact_msec + 45 + 55)
		state.update_wall_clock()
		var away_model: Dictionary = state.get_visual_model()
		_expect(is_equal_approx(rad_to_deg(float(away_model.get("dummy_rotation_radians", 0.0))), 7.0), "%s dummy must reach +7deg after 55ms" % character_type)
		state.set_clock_msec_for_tests(1000 + contact_msec + 45 + 120)
		state.update_wall_clock()
		var rebound_model: Dictionary = state.get_visual_model()
		_expect(is_equal_approx(rad_to_deg(float(rebound_model.get("dummy_rotation_radians", 0.0))), -2.0), "%s dummy must reach -2deg after the 65ms rebound" % character_type)
		state.set_clock_msec_for_tests(1000 + contact_msec + 45 + 239)
		state.update_wall_clock()
		var return_model: Dictionary = state.get_visual_model()
		_expect(absf(rad_to_deg(float(return_model.get("dummy_rotation_radians", 0.0)))) < 0.001, "%s dummy must be visually back at zero by the 240ms boundary" % character_type)
		if character_type == "optimus":
			_expect(is_equal_approx(float(contact_model.get("character_offset_x", 0.0)), 14.0), "Optimus must visibly lunge 14px in 90ms instead of drawing nothing")
			_expect(str(contact_model.get("motion_kind", "")) == "optimus_idle_tween", "Optimus must render idle-sheet plus forward/back tween")

		state.set_clock_msec_for_tests(4000)
		state.start()
		state.set_clock_msec_for_tests(4000 + contact_msec)
		state.update_wall_clock()
		var stops_before_cancel := audio.stop_count
		state.cancel()
		var cancelled: Dictionary = state.get_debug_state()
		_expect(not bool(cancelled.get("active", true)) and not bool(cancelled.get("audio_active", true)), "%s cancel must clear timeline and audio state" % character_type)
		_expect(audio.stop_count == stops_before_cancel + 1 and not audio.playing, "%s cancel must explicitly stop the shared impact audio" % character_type)


func _verify_production_pointer_and_idle_gates() -> void:
	TowerAscentFeatureFlags.debug_set_vertical_slice_enabled(true)
	var runtime_state := FakeRuntimePerkState.new()
	var audio := FakeAudio.new()
	var registry := CountingRegistry.new()
	registry.instances = {
		"runtime_perk_state": runtime_state,
		TowerAscentUnlockFilter.STORE_KEY: FakeUnlockStore.new(),
		"battle_resources": FakeBattleResources.new(_build_texture_cache()),
		"game_audio": audio,
	}
	var owner := FakeOwner.new()
	var flow := TowerAscentFlowOwner.new()
	_expect(flow.begin_vertical_slice(owner, Callable(), {
		"run_id": "training-strike-pointer",
		"map_seed": 23,
		"node_modal_kind": "training",
		"run_state": {"muhon": 30, "gold": 0, "chance_gems": 0},
		"registry": registry,
	}), "production flow must begin the training fixture")
	_expect(TowerAscentNodeArrivalTestFixture.advance_to_node_modal(flow, "training", owner), "production flow must arrive at NODE_MODAL")
	var idle_debug: Dictionary = flow.get_training_stage_presentation_debug_state()
	_expect(bool(idle_debug.get("configured", false)) and not bool(idle_debug.get("active", true)), "training modal entry must cache one static presentation without starting a strike")
	var resource_requests_before := registry.request_count("battle_resources")
	var audio_requests_before := registry.request_count("game_audio")
	for _frame in range(4):
		flow.get_node_modal_view_model()
		flow.get_node_modal_render_context()
	var after_idle: Dictionary = flow.get_training_stage_presentation_debug_state()
	_expect(int(after_idle.get("active_update_count", -1)) == 0, "GRT-043 idle frames must execute zero strike updates")
	_expect(int(after_idle.get("active_model_build_count", -1)) == 0, "GRT-043 idle frames must assemble zero dynamic strike models")
	_expect(registry.request_count("battle_resources") == resource_requests_before, "GRT-043 idle render contexts must perform zero additional battle-resource lookups")
	_expect(registry.request_count("game_audio") == audio_requests_before, "GRT-043 idle render contexts must perform zero additional audio lookups")

	flow.set_training_stage_clock_msec_for_tests(1000)
	flow.set_node_modal_clock_msec_for_tests(1000)
	var model: Dictionary = flow.get_node_modal_view_model()
	var actions: Array = model.get("actions", [])
	var rects: Array = model.get("action_rects", [])
	var training_index := _find_training_action_index(actions)
	_expect(training_index >= 0, "production modal must expose a training card")
	if training_index < 0:
		return
	var click_position := (rects[training_index] as Rect2).position + Vector2(2.0, 2.0)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = click_position
	flow.handle_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = click_position
	flow.handle_input(release)
	var clicked_debug: Dictionary = flow.get_training_stage_presentation_debug_state()
	_expect(int(clicked_debug.get("start_count", 0)) == 1, "one completed card click must start exactly one strike")
	_expect(runtime_state.apply_calls == 1, "one completed card click must still apply exactly one training action")

	flow.set_training_stage_clock_msec_for_tests(1360)
	flow.set_node_modal_clock_msec_for_tests(1360)
	flow.update_selective(0.0, owner)
	var contact_model: Dictionary = flow.get_training_stage_visual_model_for_tests()
	var contact_modal: Dictionary = flow.get_node_modal_view_model()
	flow.set_training_stage_clock_msec_for_tests(1404)
	flow.set_node_modal_clock_msec_for_tests(1404)
	flow.update_selective(0.0, owner)
	var hitstop_model: Dictionary = flow.get_training_stage_visual_model_for_tests()
	var hitstop_modal: Dictionary = flow.get_node_modal_view_model()
	_expect(int(contact_model.get("frame_index", -1)) == int(hitstop_model.get("frame_index", -2)), "production lower character frame must freeze across the 45ms hitstop")
	_expect(int(contact_model.get("local_timeline_msec", -1)) == int(hitstop_model.get("local_timeline_msec", -2)), "production dummy and character must share the frozen local timeline")
	var contact_card_progress := _success_progress(contact_modal, training_index)
	var hitstop_card_progress := _success_progress(hitstop_modal, training_index)
	_expect(hitstop_card_progress > contact_card_progress, "card receipt must continue on wall time while the lower timeline is stopped")
	_expect(audio.play_count == 1 and audio.playing, "production contact must play one reusable impact sound")

	flow.debug_advance_to_route_aim()
	var closed_debug: Dictionary = flow.get_training_stage_presentation_debug_state()
	_expect(not bool(closed_debug.get("configured", true)) and int(closed_debug.get("host_node_count", -1)) == 0, "GRT-058 modal close must leave no training host")
	_expect(not audio.playing and audio.stop_count >= 1, "GRT-058 modal close during the strike must stop impact audio")
	_finish_flow(flow, owner)


func _verify_source_and_host_contracts() -> void:
	var state_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_training_strike_presentation_state.gd"
	)
	var flow_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_node_progress.gd"
	)
	var renderer_source := FileAccess.get_file_as_string(
		"res://scripts/tower_ascent/tower_ascent_flow_renderer.gd"
	)
	_expect(state_source.begins_with("extends RefCounted"), "training strike state must stay RefCounted")
	_expect(not state_source.contains("Node.new") and not state_source.contains("add_child"), "GRT-039/GRT-058 strike state must create no Node host")
	_expect(
		state_source.contains("RandomNumberGenerator")
		and not state_source.contains("_gameplay_rng_state"),
		"S4 strike presentation RNG must remain structurally separate from Tower gameplay RNG"
	)
	_expect(flow_source.count("_node_modal_state.begin_training_strike()") == 1, "production pointer release must contain exactly one strike start site")
	_expect(flow_source.contains("not pointer_action.is_empty()"), "keyboard confirmation must stay outside the card-click strike site")
	var impact_start := renderer_source.find("func _draw_training_impact_effect")
	var impact_end := renderer_source.find("func _training_dummy_point", impact_start)
	var impact_source := renderer_source.substr(impact_start, impact_end - impact_start)
	_expect(not impact_source.contains("draw_arc") and not impact_source.contains("draw_polyline") and not impact_source.contains("draw_dashed_line"), "impact effect must contain no rings, polygon outlines, or dotted strokes")
	_expect(impact_source.contains("22.0 * content_scale") and impact_source.contains("broad_alpha := 0.02"), "impact effect must use the approved broad low-alpha filled strokes")


func _build_texture_cache() -> Dictionary:
	var idle_texture := _atlas_texture(Vector2i(640, 320), Color(0.38, 0.62, 0.86, 1.0))
	var attack_eight := _atlas_texture(Vector2i(640, 320), Color(0.92, 0.44, 0.20, 1.0))
	var attack_sixteen := _atlas_texture(Vector2i(640, 640), Color(0.84, 0.66, 0.18, 1.0))
	return {
		"player_idle_back_sheet": idle_texture,
		"player_attack_right_sheet": attack_sixteen,
		"player_attack_sheet": attack_eight,
		"viper_player_idle_sheet": idle_texture,
		"viper_player_attack_right_sheet": attack_eight,
		"commando_player_idle_sheet": idle_texture,
		"commando_player_pistol_fire_sheet": attack_eight,
		"commando_player_attack_sheet": attack_eight,
		"blacksmith_player_idle_sheet": idle_texture,
		"blacksmith_player_attack_right_sheet": attack_sixteen,
		"optimus_player_idle_sheet": idle_texture,
	}


func _atlas_texture(size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _has_resolved_sprite(model: Dictionary) -> bool:
	var sprite_value: Variant = model.get("sprite", {})
	if not (sprite_value is Dictionary):
		return false
	var sprite := sprite_value as Dictionary
	return sprite.get("texture", null) is Texture2D and (sprite.get("region", Rect2()) as Rect2).has_area()


func _find_training_action_index(actions: Array) -> int:
	for index in range(actions.size()):
		if actions[index] is Dictionary and str((actions[index] as Dictionary).get("id", "")).begins_with("training_stat:"):
			return index
	return -1


func _success_progress(model: Dictionary, action_index: int) -> float:
	var visuals: Array = model.get("interaction_visuals", [])
	if action_index < 0 or action_index >= visuals.size() or not (visuals[action_index] is Dictionary):
		return -1.0
	return float((visuals[action_index] as Dictionary).get("success_progress", -1.0))


func _finish_flow(flow: Object, owner: Object) -> void:
	if flow == null or not flow.is_active():
		return
	if flow.get_phase_name() == "NODE_MODAL":
		flow.debug_advance_to_route_aim()
	if flow.get_phase_name() == "ROUTE_AIM":
		flow.debug_launch_at_target(0)
		flow.update_selective(1.5, owner)
	if flow.get_phase_name() == "MAP_TRANSITION":
		flow.update_selective(1.0, owner)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
