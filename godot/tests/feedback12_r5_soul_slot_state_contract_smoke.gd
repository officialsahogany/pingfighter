extends SceneTree

const LingpetDurationState := preload("res://scripts/lingpet/lingpet_duration_state.gd")
const LingpetEggRuntime := preload("res://scripts/lingpet/lingpet_egg_runtime.gd")
const BattleLingpetInteractionInputRouter := preload(
	"res://scripts/core/battle_lingpet_interaction_input_router.gd"
)
const LingpetRailCardSurfaceBuilder := preload(
	"res://scripts/lingpet/lingpet_rail_card_surface_builder.gd"
)
const Stage1PillarHudSceneDrawer := preload(
	"res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd"
)
const Stage1PillarUiLayout := preload("res://scripts/hud/stage1_pillar_ui_layout.gd")
const SmasherSkillOrbRenderer := preload("res://scripts/hud/smasher_skill_orb_renderer.gd")
const LingpetRuntimeSmoke := preload("res://tests/lingpet_egg_runtime_smoke.gd")

const SOUL_SUMMON_ART_ID := "soul_summon_art"
const FILL_ONLY_STYLE := "filled_recovery"
const PROBE_SKILL_ID := "feedback12_r5_fill_only_probe"
const POOL_MAX := 60.0
const RAW_BLOCKED_RATIO := 0.29999
const RAW_READY_RATIO := 0.30

var _failures: Array[String] = []


class ModuleHolder:
	extends RefCounted

	var modules: Dictionary = {}

	func get_module(key: String) -> Object:
		var value: Variant = modules.get(key, null)
		return value as Object if value is Object else null


class FakeSkillConfig:
	extends RefCounted

	func get_snapshot() -> Dictionary:
		return {
			"max_slots": 1,
			"equipped_skills": [SOUL_SUMMON_ART_ID],
			"skill_costs": {SOUL_SUMMON_ART_ID: 0.0},
			"skill_colors": {SOUL_SUMMON_ART_ID: Color(0.32, 0.86, 0.68)},
			"cooldown_seconds": {SOUL_SUMMON_ART_ID: 0.0},
		}


class FakePillarUiRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_context: Dictionary = {}

	func draw(
		_canvas: CanvasItem,
		_game_offset: Vector2,
		_game_size: Vector2,
		_time_seconds: float,
		context: Dictionary
	) -> void:
		draw_calls += 1
		last_context = context.duplicate(true)


class FakeOrbHudState:
	extends RefCounted

	func get_gauge_spin_angle(_now_msec: int) -> float:
		return 0.0

	func get_dash_token_spin_angle(_now_msec: int) -> float:
		return 0.0


class FakeSlotContextRenderer:
	extends RefCounted

	var draw_calls := 0
	var last_context: Dictionary = {}

	func draw(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_positions: Array[Vector2],
		_time_seconds: float,
		_scale_factor: float,
		context: Dictionary
	) -> void:
		draw_calls += 1
		last_context = context.duplicate(true)


class FakeSocketRenderer:
	extends RefCounted

	func draw_socket(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_socket_overlap: float,
		_bg_color: Color,
		_border_color: Color
	) -> void:
		pass

	func draw_activation_flash(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_scale_factor: float,
		_progress: float,
		_skill_color: Color
	) -> void:
		pass

	func draw_ready_glow(
		_canvas: CanvasItem,
		_center: Vector2,
		_radius: float,
		_time_seconds: float,
		_phase_offset: float,
		_color: Color
	) -> void:
		pass


class FakeCooldownRenderer:
	extends RefCounted

	var generic_draw_calls := 0
	var filled_recovery_calls := 0
	var last_filled_ratio := -1.0

	func draw(
		_canvas: CanvasItem,
		_center: Vector2,
		_radius: float,
		_cooldown_ratio: float,
		_pillar_drawer: Variant,
		_static_hud_lod: bool = false
	) -> void:
		generic_draw_calls += 1

	func draw_filled_recovery(
		_canvas: CanvasItem,
		_center: Vector2,
		_radius: float,
		cooldown_ratio: float,
		_time_seconds: float,
		_phase_offset: float,
		_skill_color: Color,
		_static_hud_lod: bool = false
	) -> void:
		filled_recovery_calls += 1
		last_filled_ratio = cooldown_ratio


class FakeSymbolRenderer:
	extends RefCounted

	var active_states: Array[bool] = []

	func draw(
		_canvas: CanvasItem,
		_center: Vector2,
		_icon_radius: float,
		_skill_name: String,
		_color: Color,
		is_active: bool
	) -> void:
		active_states.append(is_active)


class FakeDualSkillState:
	extends RefCounted

	var cooldown := 0.0
	var ready := false
	var winding_up := false

	func _init(next_cooldown: float, next_ready: bool, next_winding_up: bool) -> void:
		cooldown = next_cooldown
		ready = next_ready
		winding_up = next_winding_up

	func get_snapshot(
		_active: bool,
		_skill_id: String,
		cooldown_duration: float,
		windup_seconds: float,
		_flash_seconds: float,
		suffix: String = ""
	) -> Dictionary:
		return {
			"companion_skill_cooldown%s" % suffix: cooldown,
			"companion_skill_cooldown_duration%s" % suffix: cooldown_duration,
			"companion_skill_windup_seconds%s" % suffix: windup_seconds,
			"companion_skill_windup_ratio%s" % suffix: 0.5 if winding_up else 0.0,
			"companion_skill_ready%s" % suffix: ready,
			"companion_skill_last_gain%s" % suffix: 0.0,
			"companion_skill_trigger_count%s" % suffix: 0,
			"companion_skill_flash_timer%s" % suffix: 0.0,
			"companion_skill_flash_ratio%s" % suffix: 0.0,
			"companion_skill_winding_up%s" % suffix: winding_up,
			"companion_skill_origin%s" % suffix: Vector2.ZERO,
		}


class FakeDualSkillRuntimeSurface:
	extends RefCounted

	var primary_surface: Dictionary
	var second_surface: Dictionary

	func _init() -> void:
		primary_surface = {
			"active_skill": {
				"id": "guardian_primary",
				"name": "Primary",
				"description": "Primary guardian active",
				"cooldown": 8.0,
				"enabled": true,
			},
			"skill_state": FakeDualSkillState.new(2.5, true, false),
			"windup_seconds": 0.4,
		}
		second_surface = {
			"active_skill": {
				"id": "guardian_second",
				"name": "Second",
				"description": "Second guardian active",
				"cooldown": 12.0,
				"enabled": true,
			},
			"skill_state": FakeDualSkillState.new(4.5, false, true),
			"windup_seconds": 0.8,
		}

	func get_active_slot_count(
		_current_profile: Object,
		_active_skill_slot_resolver: Object,
		_skill_runtime_host: Object
	) -> int:
		return 2

	func get_active_surface_for_slot(
		_current_profile: Object,
		_active_skill_slot_resolver: Object,
		_companion_skill_persistence: Object,
		_companion_skill_states: Array,
		_skill_runtime_host: Object,
		_default_windup_seconds: float,
		_slot_index: int,
		_active_slot_count: int
	) -> Dictionary:
		return primary_surface

	func get_second_active_surface(
		_current_profile: Object,
		_active_skill_slot_resolver: Object,
		_companion_skill_persistence: Object,
		_companion_skill_states: Array,
		_skill_runtime_host: Object,
		_default_windup_seconds: float,
		_active_slot_count: int
	) -> Dictionary:
		return second_surface


func _init() -> void:
	_verify_raw_resummon_boundary()
	_verify_lifecycle_and_ctrl_use_the_same_boundary()
	_verify_scene_drawer_layout_and_soul_slot_state()
	_verify_fill_only_ctrl_cooling_branch()
	_verify_dual_guardian_suffix_parity()
	_verify_shared_owner_source_contract()

	if _failures.is_empty():
		print("feedback12_r5_soul_slot_state_contract_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_raw_resummon_boundary() -> void:
	var blocked := _recover_duration_state_to_ratio(RAW_BLOCKED_RATIO)
	var ready := _recover_duration_state_to_ratio(RAW_READY_RATIO)
	_expect(blocked.get_pool_pct() == 30, "29.999 percent fixture must demonstrate why rounded HUD percent is not a gate")
	_expect(not blocked.can_resummon(), "raw 29.999 percent must remain below the resummon predicate")
	_expect(ready.get_pool_pct() == 30, "exact 30.000 percent fixture must publish 30 percent")
	_expect(ready.can_resummon(), "raw 30.000 percent must satisfy the inclusive resummon predicate")


func _verify_lifecycle_and_ctrl_use_the_same_boundary() -> void:
	var blocked_fixture: Dictionary = _make_stowed_runtime_fixture(RAW_BLOCKED_RATIO)
	var blocked_runtime: Object = blocked_fixture.get("runtime", null)
	var blocked_owner: Object = blocked_fixture.get("owner", null)
	var blocked_registry: Object = blocked_fixture.get("registry", null)
	var blocked_slot_state: Dictionary = _get_guardian_toggle_slot_state(blocked_runtime)
	_expect(not bool(blocked_slot_state.get("ready", true)), "stowed guardian at raw 29.999 percent must publish Soul slot ready=false")
	_expect(float(blocked_slot_state.get("cooldown_ratio", 0.0)) > 0.0, "stowed guardian below 30 percent must publish positive Ctrl cooling")
	var blocked_consumed := _send_ctrl_toggle(blocked_runtime, blocked_owner, blocked_registry)
	_expect(blocked_consumed, "Ctrl below the threshold must be consumed by the guardian input route")
	_expect(_guardian_transition_mode(blocked_runtime) != "summon", "Ctrl at raw 29.999 percent must not start the summon lifecycle")
	blocked_runtime.update(0.60, blocked_owner, blocked_registry)
	_expect(blocked_runtime.is_guardian_stowed(), "raw 29.999 percent must remain stowed after the real input/lifecycle route")
	_cleanup_runtime(blocked_runtime)

	var ready_fixture: Dictionary = _make_stowed_runtime_fixture(RAW_READY_RATIO)
	var ready_runtime: Object = ready_fixture.get("runtime", null)
	var ready_owner: Object = ready_fixture.get("owner", null)
	var ready_registry: Object = ready_fixture.get("registry", null)
	var ready_slot_state: Dictionary = _get_guardian_toggle_slot_state(ready_runtime)
	_expect(bool(ready_slot_state.get("ready", false)), "stowed guardian at raw 30.000 percent must publish Soul slot ready=true")
	_expect(is_zero_approx(float(ready_slot_state.get("cooldown_ratio", -1.0))), "exactly ready guardian must publish zero Ctrl cooling")
	var ready_consumed := _send_ctrl_toggle(ready_runtime, ready_owner, ready_registry)
	_expect(ready_consumed, "Ctrl at the inclusive threshold must be consumed by the guardian input route")
	_expect(_guardian_transition_mode(ready_runtime) == "summon", "Ctrl at raw 30.000 percent must start the summon lifecycle")
	ready_runtime.update(0.60, ready_owner, ready_registry)
	_expect(not ready_runtime.is_guardian_stowed(), "raw 30.000 percent must complete the real resummon lifecycle")
	_cleanup_runtime(ready_runtime)


func _verify_scene_drawer_layout_and_soul_slot_state() -> void:
	var blocked_fixture: Dictionary = _make_stowed_runtime_fixture(RAW_BLOCKED_RATIO)
	var blocked_context: Dictionary = _capture_production_soul_slot_context(
		blocked_fixture.get("runtime", null),
		blocked_fixture.get("registry", null)
	)
	_assert_soul_slot_context(blocked_context, false, true, "29.999 percent")
	_cleanup_runtime(blocked_fixture.get("runtime", null))

	var ready_fixture: Dictionary = _make_stowed_runtime_fixture(RAW_READY_RATIO)
	var ready_context: Dictionary = _capture_production_soul_slot_context(
		ready_fixture.get("runtime", null),
		ready_fixture.get("registry", null)
	)
	_assert_soul_slot_context(ready_context, true, false, "30.000 percent")
	_cleanup_runtime(ready_fixture.get("runtime", null))


func _verify_fill_only_ctrl_cooling_branch() -> void:
	var layout := Stage1PillarUiLayout.new()
	var orb_context: Dictionary = layout.build_skill_orb_context({
		"selected_character_type": "smasher",
		"pillar_hud_static_lod": false,
		"special_gauge": 100.0,
		"skill_ready_overrides": {PROBE_SKILL_ID: false},
		"skill_cooldown_remaining_ratios": {PROBE_SKILL_ID: 0.625},
		"skill_cooldown_visual_styles": {PROBE_SKILL_ID: FILL_ONLY_STYLE},
		"skill_config_snapshot": {
			"max_slots": 1,
			"equipped_skills": [PROBE_SKILL_ID],
			"skill_costs": {PROBE_SKILL_ID: 0.0},
			"skill_colors": {PROBE_SKILL_ID: Color(0.32, 0.86, 0.68)},
			"cooldown_seconds": {PROBE_SKILL_ID: 0.0},
		},
	}, null)
	var styles: Dictionary = _get_dict(orb_context.get("skill_cooldown_visual_styles", {}))
	_expect(str(styles.get(PROBE_SKILL_ID, "")) == FILL_ONLY_STYLE, "layout must preserve the fill-only Ctrl cooling style")

	var renderer := SmasherSkillOrbRenderer.new()
	var socket := FakeSocketRenderer.new()
	var cooldown := FakeCooldownRenderer.new()
	var symbol := FakeSymbolRenderer.new()
	renderer.slot_renderer.socket_renderer = socket
	renderer.slot_renderer.cooldown_renderer = cooldown
	renderer.slot_renderer.symbol_renderer = symbol
	var canvas := Node2D.new()
	renderer.draw_orbs(canvas, Vector2.ZERO, 55.0, 0.25, 1.0, orb_context)
	canvas.free()
	_expect(cooldown.filled_recovery_calls == 1, "filled_recovery style must call the fill-only Ctrl cooling primitive")
	_expect(cooldown.generic_draw_calls == 0, "Soul-style Ctrl cooling must bypass the generic arc cooldown renderer")
	_expect(is_equal_approx(cooldown.last_filled_ratio, 0.625), "fill-only Ctrl cooling must receive the exact state ratio")
	_expect(symbol.active_states.size() == 1 and not bool(symbol.active_states[0]), "cooling slot must remain visually inactive")

	var cooldown_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_cooldown_renderer.gd")
	var slot_source := FileAccess.get_file_as_string("res://scripts/hud/smasher_skill_orb_slot_renderer.gd")
	var fill_body: String = _extract_function_body(cooldown_source, "func draw_filled_recovery(")
	var compact_body: String = _compact_whitespace(fill_body)
	_expect(slot_source.find("draw_filled_recovery(") >= 0, "Soul-style cooldown branch must call draw_filled_recovery")
	_expect(not fill_body.is_empty(), "cooldown renderer must own a dedicated fill-only recovery primitive")
	_expect(
		fill_body.find("draw_circle(") >= 0 or fill_body.find("draw_colored_polygon(") >= 0,
		"Ctrl cooling must be composed from filled circles or filled polygons"
	)
	for forbidden_token in ["draw_arc(", "draw_line(", "draw_polyline(", "draw_multiline(", "draw_dashed_line("]:
		_expect(
			fill_body.find(forbidden_token) < 0,
			"fill-only Ctrl cooling must not use an arc, outline, or dash primitive: %s" % forbidden_token
		)
	_expect(compact_body.find(", false") < 0, "fill-only Ctrl cooling must not request an unfilled primitive")


func _verify_dual_guardian_suffix_parity() -> void:
	var builder := LingpetRailCardSurfaceBuilder.new()
	var runtime_surface := FakeDualSkillRuntimeSurface.new()
	var summoned: Dictionary = builder._build_surface_uncached(
		"companion",
		true,
		null,
		null,
		null,
		null,
		[],
		null,
		runtime_surface,
		0.4,
		0.2
	)
	for base_key in [
		"companion_skill_id",
		"companion_skill_cooldown",
		"companion_skill_cooldown_duration",
		"companion_skill_ready",
		"companion_skill_winding_up",
	]:
		_expect(summoned.has(base_key), "dual guardian surface must publish primary key: %s" % base_key)
		_expect(summoned.has(base_key + "_1"), "dual guardian surface must publish matching second-slot key: %s_1" % base_key)
	_expect(str(summoned.get("companion_skill_id", "")) == "guardian_primary", "primary guardian card must keep its active id")
	_expect(str(summoned.get("companion_skill_id_1", "")) == "guardian_second", "second guardian card must keep its _1 active id")
	_expect(is_equal_approx(float(summoned.get("companion_skill_cooldown", -1.0)), 2.5), "primary cooldown must keep the unsuffixed value")
	_expect(is_equal_approx(float(summoned.get("companion_skill_cooldown_1", -1.0)), 4.5), "second cooldown must keep the _1 value")
	_expect(bool(summoned.get("companion_skill_ready", false)), "primary ready surface must remain true")
	_expect(not bool(summoned.get("companion_skill_ready_1", true)), "second ready surface must preserve its independent false state")
	_expect(not bool(summoned.get("companion_skill_winding_up", true)), "primary windup surface must remain false")
	_expect(bool(summoned.get("companion_skill_winding_up_1", false)), "second windup surface must preserve its independent true state")

	var stowed: Dictionary = builder._build_surface_uncached(
		"companion",
		false,
		null,
		null,
		null,
		null,
		[],
		null,
		runtime_surface,
		0.4,
		0.2
	)
	_expect(str(stowed.get("companion_skill_id", "")) == "", "stow must suppress the primary guardian card")
	_expect(str(stowed.get("companion_skill_id_1", "")) == "", "stow must suppress the second guardian card with _1 parity")
	_expect(not bool(stowed.get("companion_skill_ready", true)), "stow must clear primary ready state")
	_expect(not bool(stowed.get("companion_skill_ready_1", true)), "stow must clear second ready state with _1 parity")


func _verify_shared_owner_source_contract() -> void:
	var duration_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_duration_state.gd")
	var lifecycle_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_guardian_duration_lifecycle_coordinator.gd")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_lingpet_interaction_input_router.gd")
	var scene_source := FileAccess.get_file_as_string("res://scripts/stages/stage1/stage1_pillar_hud_scene_drawer.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_runtime_snapshot_builder.gd")
	var can_resummon_body := _extract_function_body(duration_source, "func can_resummon(")
	var try_toggle_body := _extract_function_body(lifecycle_source, "func try_toggle(")
	var slot_state_body := _extract_function_body(lifecycle_source, "func get_toggle_slot_state(")
	var runtime_slot_body := _extract_function_body(runtime_source, "func get_guardian_toggle_slot_state(")
	var input_body := _extract_function_body(input_source, "func _handle_guardian_toggle(")

	_expect(duration_source.find("RESUMMON_THRESHOLD_RATIO := 0.30") >= 0, "duration owner must declare the 30 percent ratio, not a fixed-second threshold")
	_expect(duration_source.count("_meets_resummon_threshold()") >= 5, "import, recovery, restore, and can_resummon must share one raw threshold predicate")
	_expect(can_resummon_body.find("_meets_resummon_threshold()") >= 0, "can_resummon must use the shared raw predicate")
	_expect(can_resummon_body.find("get_pool_pct()") < 0, "can_resummon must not gate on rounded HUD percent")
	_expect(try_toggle_body.find("get_toggle_slot_state(") >= 0, "lifecycle toggle must consume the same state published to the Soul slot")
	_expect(slot_state_body.find("can_resummon_guardian") >= 0, "stowed lifecycle slot state must delegate to the duration owner's predicate")
	_expect(runtime_slot_body.find("get_toggle_slot_state(") >= 0, "egg runtime must expose the lifecycle-owned guardian toggle slot state")
	_expect(input_body.find("try_toggle_guardian_stow") >= 0, "Ctrl input must stay routed through the real guardian lifecycle toggle")
	_expect(scene_source.find("get_guardian_toggle_slot_state") >= 0, "pillar scene drawer must read the real guardian toggle slot state")
	_expect(scene_source.find("skill_cooldown_visual_styles") >= 0, "pillar scene drawer must mark Soul recovery as fill-only")
	var second_snapshot_body := _extract_function_body(snapshot_source, "func _build_second_skill_state_snapshot(")
	_expect(second_snapshot_body.find("\"_1\"") >= 0, "runtime snapshot builder must preserve the second guardian active suffix")


func _recover_duration_state_to_ratio(target_ratio: float) -> Object:
	var state := LingpetDurationState.new()
	state.set_pool_for_tests(0.0, POOL_MAX)
	var target_value := POOL_MAX * target_ratio
	state.advance_pool(target_value / LingpetDurationState.REST_RECOVERY_RATIO, false)
	_expect(
		is_equal_approx(state.get_pool_current() / state.get_pool_max(), target_ratio),
		"duration fixture must reach the requested raw ratio"
	)
	return state


func _make_stowed_runtime_fixture(target_ratio: float) -> Dictionary:
	var owner := _make_runtime_owner()
	var registry := LingpetRuntimeSmoke.FakeRegistry.new()
	var runtime: Object = LingpetEggRuntime.new()
	registry.instances["lingpet_egg_runtime"] = runtime
	_expect(runtime.debug_grant_and_activate_pet("maribo", owner, false, "", "", registry), "fixture must activate a guardian")
	runtime.set_duration_pool_for_tests(POOL_MAX, POOL_MAX)
	runtime.update(6.10, owner, registry)
	_expect(runtime.try_toggle_guardian_stow(owner, registry), "fixture stow edge must be consumed")
	runtime.update(0.47, owner, registry)
	_expect(runtime.is_guardian_stowed(), "fixture guardian must complete stow before applying the raw boundary")
	var run_state: Object = runtime.get("_guardian_run_state") as Object
	run_state.set_duration_pool_for_tests(POOL_MAX * target_ratio, POOL_MAX)
	_expect(
		is_equal_approx(runtime.get_duration_pool_current() / runtime.get_duration_pool_max(), target_ratio),
		"runtime fixture must preserve the requested raw duration ratio"
	)
	return {
		"owner": owner,
		"registry": registry,
		"runtime": runtime,
	}


func _capture_production_soul_slot_context(runtime: Object, registry: Object) -> Dictionary:
	var capture := FakePillarUiRenderer.new()
	registry.instances["stage1_pillar_ui_renderer"] = capture
	registry.instances["smasher_skill_config"] = FakeSkillConfig.new()
	registry.instances["lingpet_egg_runtime"] = runtime
	var drawer := Stage1PillarHudSceneDrawer.new()
	drawer._draw_stage1_pillar_ui(
		null,
		{
			"height": 750.0,
			"current_stage": 1,
			"selected_character_type": "smasher",
			"special_gauge": 100.0,
			"gauge_max": 500.0,
		},
		registry,
		{"orb_hud_state": FakeOrbHudState.new()},
		Vector2.ZERO,
		Vector2(760.0, 750.0),
		0.25
	)
	_expect(capture.draw_calls == 1, "pillar scene drawer must call the production UI renderer")
	var layout := Stage1PillarUiLayout.new()
	var orb_context: Dictionary = layout.build_skill_orb_context(capture.last_context, null)
	var orb_renderer := SmasherSkillOrbRenderer.new()
	var slot_capture := FakeSlotContextRenderer.new()
	orb_renderer.slot_renderer = slot_capture
	var canvas := Node2D.new()
	orb_renderer.draw_orbs(canvas, Vector2.ZERO, 55.0, 0.25, 1.0, orb_context)
	canvas.free()
	_expect(slot_capture.draw_calls == 1, "production orb renderer must hand the layout context to its slot renderer")
	return slot_capture.last_context


func _assert_soul_slot_context(
	context: Dictionary,
	expected_ready: bool,
	expected_cooling: bool,
	label: String
) -> void:
	var ready_overrides: Dictionary = _get_dict(context.get("skill_ready_overrides", {}))
	var cooldown_ratios: Dictionary = _get_dict(context.get("skill_cooldown_remaining_ratios", {}))
	var visual_styles: Dictionary = _get_dict(context.get("skill_cooldown_visual_styles", {}))
	_expect(ready_overrides.has(SOUL_SUMMON_ART_ID), "%s Soul slot must carry a production ready override" % label)
	_expect(bool(ready_overrides.get(SOUL_SUMMON_ART_ID, not expected_ready)) == expected_ready, "%s Soul slot readiness must match the real toggle predicate" % label)
	_expect(cooldown_ratios.has(SOUL_SUMMON_ART_ID), "%s Soul slot must carry a production Ctrl cooling ratio" % label)
	var cooldown_ratio := float(cooldown_ratios.get(SOUL_SUMMON_ART_ID, -1.0))
	_expect((cooldown_ratio > 0.0) == expected_cooling, "%s Soul slot cooling must stop exactly when the real gate opens" % label)
	_expect(str(visual_styles.get(SOUL_SUMMON_ART_ID, "")) == FILL_ONLY_STYLE, "%s Soul slot must select fill-only cooling" % label)


func _get_guardian_toggle_slot_state(runtime: Object) -> Dictionary:
	if runtime == null or not runtime.has_method("get_guardian_toggle_slot_state"):
		_expect(false, "lingpet runtime must expose get_guardian_toggle_slot_state for the shared HUD/input gate")
		return {}
	var value: Variant = runtime.call("get_guardian_toggle_slot_state")
	return value as Dictionary if value is Dictionary else {}


func _send_ctrl_toggle(runtime: Object, owner: Object, registry: Object) -> bool:
	var holder := ModuleHolder.new()
	holder.modules["lingpet_egg_runtime"] = runtime
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_CTRL
	event.physical_keycode = KEY_CTRL
	return bool(BattleLingpetInteractionInputRouter.new().handle_companion_input(
		event,
		owner,
		registry,
		Callable(holder, "get_module")
	))


func _guardian_transition_mode(runtime: Object) -> String:
	if runtime == null:
		return ""
	var snapshot: Dictionary = runtime.get_snapshot()
	var transition: Dictionary = _get_dict(snapshot.get("guardian_transition", {}))
	return str(transition.get("mode", ""))


func _make_runtime_owner() -> Object:
	var owner := LingpetRuntimeSmoke.FakeOwner.new()
	owner.ai_mode = "champion"
	owner.lingpet_owned_pet_ids = ["maribo"]
	owner.owned_lingpet_ids = ["maribo"]
	owner.owned_ringpet_ids = ["maribo"]
	owner.lingpet_slots = ["maribo", "", ""]
	owner.ringpet_slots = owner.lingpet_slots.duplicate()
	owner.lingpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.ringpet_slot_pet_ids = owner.lingpet_slots.duplicate()
	owner.lingpet_active_slot_index = 0
	owner.ringpet_active_slot_index = 0
	return owner


func _cleanup_runtime(runtime: Object) -> void:
	if runtime != null and runtime.has_method("reset_for_tests"):
		runtime.reset_for_tests()


func _extract_function_body(source: String, signature: String) -> String:
	var start: int = source.find(signature)
	if start < 0:
		return ""
	var finish: int = source.find("\nfunc ", start + signature.length())
	if finish < 0:
		finish = source.length()
	return source.substr(start, finish - start)


func _compact_whitespace(value: String) -> String:
	var compact := value.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while compact.find("  ") >= 0:
		compact = compact.replace("  ", " ")
	return compact


func _get_dict(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
