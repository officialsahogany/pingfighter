extends SceneTree

const BattleSceneSkillTooltipDriver := preload(
	"res://scripts/core/battle_scene_skill_tooltip_driver.gd"
)
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const LingpetEnhancementBuffStore := preload(
	"res://scripts/lingpet/lingpet_enhancement_buff_store.gd"
)
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")

const MODAL_REWIND_MSEC := 1000

var _failures: Array[String] = []


class DynamicOwner:
	extends RefCounted

	var values: Dictionary = {
		"selected_character_type": "smasher",
		"current_stage": 1,
		"runtime_perk_levels": {},
		"runtime_perk_effective_levels": {},
		"runtime_perk_pending_choices": 0,
		"runtime_perk_starpoints": 0,
		"runtime_perk_gold": 0,
		"runtime_perk_choice_active": false,
		"runtime_accessory_slot_bonus": 0,
		"runtime_laurel_leaf_count": 0,
		"runtime_paddle_scale": 1.0,
		"runtime_paddle_base_width": 155.0,
		"runtime_paddle_base_height": 50.0,
		"player_paddle_width": 155.0,
		"player_paddle_height": 50.0,
		"player_paddle_scale": 1.0,
		"player_pos": Vector2(300.0, 700.0),
		"item_perk_level_bonus": 0,
		"viper_ignition_aura_active": false,
		"ball_vel": Vector2(0.0, 12.0),
		"player_collision_cooldown": 0.0,
		"lingpet_owned_pet_ids": ["maribo"],
		"owned_lingpet_ids": ["maribo"],
		"owned_ringpet_ids": ["maribo"],
		"lingpet_collection": {"maribo": true},
		"ringpet_collection": {"maribo": true},
		"owned_lingpets": {"maribo": true},
		"owned_ringpets": {"maribo": true},
		"lingpet_slots": ["maribo", "", ""],
		"ringpet_slots": ["maribo", "", ""],
		"lingpet_slot_pet_ids": ["maribo", "", ""],
		"ringpet_slot_pet_ids": ["maribo", "", ""],
		"lingpet_active_slot_index": 0,
		"ringpet_active_slot_index": 0,
	}

	func _get(property: StringName) -> Variant:
		return values.get(str(property), null)

	func _set(property: StringName, value: Variant) -> bool:
		values[str(property)] = value
		return true


class FakeCatalog:
	extends RefCounted

	var choices: Array = []

	func get_choices(
		_character_type: String,
		_levels: Dictionary,
		_exclude_instant: bool,
		_target_count: int,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return choices.duplicate(true)


class ClockSkillState:
	extends RefCounted

	var cooldown_anchor_msec := 1200
	var pause_started_msec := -1
	var pause_calls := 0
	var resume_calls := 0

	func pause_cooldowns(current_msec: int) -> void:
		if pause_started_msec >= 0:
			return
		pause_started_msec = current_msec
		pause_calls += 1

	func resume_cooldowns(current_msec: int) -> void:
		if pause_started_msec < 0:
			return
		cooldown_anchor_msec += maxi(0, current_msec - pause_started_msec)
		pause_started_msec = -1
		resume_calls += 1


class ModalWindowState:
	extends RefCounted

	var activation_end_msec := 4200
	var reserved_at_msec := 2600
	var pause_started_msec := -1
	var pause_calls := 0
	var resume_calls := 0

	func pause_runtime_perk_modal_time(current_msec: int) -> void:
		if pause_started_msec >= 0:
			return
		pause_started_msec = current_msec
		pause_calls += 1

	func resume_runtime_perk_modal_time(current_msec: int) -> void:
		if pause_started_msec < 0:
			return
		var shift_msec := maxi(0, current_msec - pause_started_msec)
		activation_end_msec += shift_msec
		reserved_at_msec += shift_msec
		pause_started_msec = -1
		resume_calls += 1


class FakeCutinHost:
	extends RefCounted

	func prewarm_pet_assets_step(
		_pet_id: String,
		_allow_sync_fallback: bool = false,
		_perf_logger: Object = null,
		_perf_label_prefix: String = ""
	) -> bool:
		return true

	func is_pet_panel_anim_ready(_pet_id: String) -> bool:
		return true

	func prewarm_result_icon_path(_icon_path: String) -> bool:
		return true

	func get_animation_contract(_pet_id: String) -> Dictionary:
		return {
			"visual_key": "companion_click_reaction_anim",
			"idle_fallback": false,
			"cols": 1,
			"rows": 1,
			"frame_count": 1,
			"frame_interval": 0.01,
			"draw_size": 96.0,
		}


class FakeAudio:
	extends RefCounted

	var stop_calls := 0

	func stop_lingpet_guardian_enhance_cutin_loop() -> void:
		stop_calls += 1


class FakeRegistry:
	extends RefCounted

	var instances: Dictionary = {}

	func get_instance(key: String) -> Object:
		var value: Variant = instances.get(key, null)
		return value as Object if typeof(value) == TYPE_OBJECT else null

	func get_cached_instance(key: String) -> Object:
		return get_instance(key)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_perk_entry_keeps_modal_time_frozen_until_auto_close()
	_verify_absorption_entry_owns_pause_and_cancel_release()
	if _failures.is_empty():
		print("guardian_enhance_modal_time_freeze_smoke: ok")
		call_deferred("_finish", 0)
	else:
		for failure: String in _failures:
			push_error(failure)
		call_deferred("_finish", 1)


func _finish(exit_code: int) -> void:
	await process_frame
	quit(exit_code)


func _verify_perk_entry_keeps_modal_time_frozen_until_auto_close() -> void:
	var fixture := _make_fixture()
	var perk_state: Object = fixture.perk_state
	var lingpet_runtime: Object = fixture.lingpet_runtime
	var owner: Object = fixture.owner
	var registry: Object = fixture.registry
	var catalog: FakeCatalog = fixture.catalog
	var skill_clock: ClockSkillState = fixture.skill_clock
	var modal_clock: ModalWindowState = fixture.modal_clock

	catalog.choices = [_guardian_choice()]
	_expect(
		perk_state.collect_star_points(1, "smasher", catalog, owner, registry),
		"perk entry must open the real runtime choice path"
	)
	_expect(skill_clock.pause_calls == 1, "choice open must pause the real tooltip-driver path")
	perk_state.animation_time = 0.30
	perk_state.choose_selected(owner, registry, Vector2(1280.0, 720.0))
	_expect(lingpet_runtime.is_guardian_enhance_cutin_active(), "perk commit must start the compact cutin")
	_expect(
		perk_state._skill_cooldown_pause.is_active(),
		"post-choice blocker must retain the shared pause while the cutin is active"
	)
	_expect(skill_clock.resume_calls == 0, "choice finish must not resume on the cutin start frame")

	var before := _capture_clock_values(skill_clock, modal_clock)
	_rewind_pause_markers(skill_clock, modal_clock)
	lingpet_runtime.advance_guardian_enhance_cutin(0.10, registry)
	_expect(
		_capture_clock_values(skill_clock, modal_clock) == before,
		"cooldown, activation-window, and reservation anchors must remain unchanged during the cutin"
	)
	_finish_cutin_by_advancing(lingpet_runtime, registry)
	_expect(not lingpet_runtime.is_guardian_enhance_cutin_active(), "automatic completion must close the cutin")
	_verify_release_results(fixture, before, "perk")
	_cleanup_fixture(fixture)


func _verify_absorption_entry_owns_pause_and_cancel_release() -> void:
	var fixture := _make_fixture()
	var perk_state: Object = fixture.perk_state
	var lingpet_runtime: Object = fixture.lingpet_runtime
	var owner: Object = fixture.owner
	var registry: Object = fixture.registry
	var skill_clock: ClockSkillState = fixture.skill_clock
	var modal_clock: ModalWindowState = fixture.modal_clock

	var result: Dictionary = lingpet_runtime.trigger_guardian_enhancement_from_absorption(
		owner,
		registry
	)
	_expect(bool(result.get("accepted", false)), "absorption entry must apply one enhancement")
	_expect(lingpet_runtime.is_guardian_enhance_cutin_active(), "absorption must start the same compact cutin")
	_expect(perk_state._skill_cooldown_pause.is_active(), "absorption must own the shared modal pause")
	_expect(skill_clock.pause_calls == 1, "absorption must enter the real tooltip-driver pause path")

	var before := _capture_clock_values(skill_clock, modal_clock)
	_rewind_pause_markers(skill_clock, modal_clock)
	_expect(
		lingpet_runtime.cancel_guardian_enhance_cutin(registry),
		"absorption cutin cancel must close immediately"
	)
	_verify_release_results(fixture, before, "absorption")
	_cleanup_fixture(fixture)


func _make_fixture() -> Dictionary:
	var owner := DynamicOwner.new()
	var perk_state := RuntimePerkState.new()
	var lingpet_runtime := LingpetEggRuntime.new()
	var catalog := FakeCatalog.new()
	var skill_clock := ClockSkillState.new()
	var modal_clock := ModalWindowState.new()
	var registry := FakeRegistry.new()
	registry.instances = {
		"runtime_perk_state": perk_state,
		"runtime_perk_catalog": catalog,
		"lingpet_egg_runtime": lingpet_runtime,
		"lingpet_guardian_enhance_cutin_overlay_host": FakeCutinHost.new(),
		"battle_scene_skill_tooltip_driver": BattleSceneSkillTooltipDriver.new(),
		"smasher_skill_state": skill_clock,
		"smasher_wheel_state": modal_clock,
		"game_audio": FakeAudio.new(),
	}
	_expect(
		lingpet_runtime.debug_grant_and_activate_pet(
			"maribo",
			owner,
			false,
			"maribo_spear_throw",
			"maribo_hydro_resonance",
			registry
		),
		"fixture must activate an owned guardian"
	)
	return {
		"owner": owner,
		"perk_state": perk_state,
		"lingpet_runtime": lingpet_runtime,
		"registry": registry,
		"catalog": catalog,
		"skill_clock": skill_clock,
		"modal_clock": modal_clock,
	}


func _guardian_choice() -> Dictionary:
	return {
		"id": "lingpet_guardian_enhance",
		"name": "수호령강화",
		"guardian_enhance_candidates": [{
			"type": LingpetEnhancementBuffStore.REWARD_TYPE_DURATION,
			"weight": 1.0,
		}],
	}


func _rewind_pause_markers(skill_clock: ClockSkillState, modal_clock: ModalWindowState) -> void:
	var rewound_msec := maxi(0, Time.get_ticks_msec() - MODAL_REWIND_MSEC)
	skill_clock.pause_started_msec = rewound_msec
	modal_clock.pause_started_msec = rewound_msec


func _capture_clock_values(
	skill_clock: ClockSkillState,
	modal_clock: ModalWindowState
) -> Vector3i:
	return Vector3i(
		skill_clock.cooldown_anchor_msec,
		modal_clock.activation_end_msec,
		modal_clock.reserved_at_msec
	)


func _finish_cutin_by_advancing(lingpet_runtime: Object, registry: Object) -> void:
	for _step in range(12):
		if not lingpet_runtime.is_guardian_enhance_cutin_active():
			return
		lingpet_runtime.advance_guardian_enhance_cutin(10.0, registry)


func _verify_release_results(fixture: Dictionary, before: Vector3i, label: String) -> void:
	var perk_state: Object = fixture.perk_state
	var owner: Object = fixture.owner
	var skill_clock: ClockSkillState = fixture.skill_clock
	var modal_clock: ModalWindowState = fixture.modal_clock
	var after := _capture_clock_values(skill_clock, modal_clock)
	_expect(not perk_state._skill_cooldown_pause.is_active(), "%s close must release the shared pause" % label)
	_expect(skill_clock.resume_calls == 1, "%s close must resume cooldown clocks exactly once" % label)
	_expect(modal_clock.resume_calls == 1, "%s close must resume modal wall-clock anchors exactly once" % label)
	_expect(after.x > before.x, "%s close must shift the cooldown anchor" % label)
	_expect(after.y > before.y, "%s close must shift the activation-window deadline" % label)
	_expect(after.z > before.z, "%s close must shift the reservation timestamp" % label)
	_expect(owner.get("ball_vel") == Vector2.ZERO, "%s close must arm a real resume freeze" % label)
	_expect(
		bool(perk_state.get_ball_resume_context().get("perk_resume_score_blocking", false)),
		"%s close must arm the real score-blocking resume safety" % label
	)


func _cleanup_fixture(fixture: Dictionary) -> void:
	var lingpet_runtime: Object = fixture.lingpet_runtime
	var perk_state: Object = fixture.perk_state
	lingpet_runtime.reset_for_tests()
	perk_state.reset()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
