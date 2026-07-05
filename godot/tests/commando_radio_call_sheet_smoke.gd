extends SceneTree

const BattleDrawActorContext := preload("res://scripts/core/battle_draw_actor_context.gd")
const BattleDrawContext := preload("res://scripts/core/battle_draw_context.gd")
const BattleResources := preload("res://scripts/resources/battle_resources.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const RADIO_CALL_SHEET_PATH := "res://assets/sprites/characters/commando/commando_subculture_radio_call_sheet.png"

var _failures: Array[String] = []


func _init() -> void:
	_verify_sheet_loads_for_soldier()
	_verify_supply_drop_radio_motion_activates_pose()
	_verify_emergency_supply_radio_phase_activates_pose()
	_verify_fire_support_radio_phase_activates_pose()
	_verify_scene_deps_feed_supply_and_reload_radio_motion()
	_verify_weapon_fire_and_pistol_fire_take_priority()
	_verify_non_commando_skips_radio_pose()
	_verify_frame_region_mapping()

	if _failures.is_empty():
		print("commando_radio_call_sheet_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_sheet_loads_for_soldier() -> void:
	var direct: Texture2D = load(RADIO_CALL_SHEET_PATH)
	_expect(direct != null, "Commando radio-call sheet should load directly")
	if direct != null:
		_expect(direct.get_width() == 640, "radio-call sheet width must be 640")
		_expect(direct.get_height() == 320, "radio-call sheet height must be 320")

	var textures: Dictionary = _load_commando_textures()
	_expect(
		textures.get("commando_player_radio_call_sheet", null) is Texture2D,
		"Commando radio-call sheet should load through BattleResources"
	)


func _verify_supply_drop_radio_motion_activates_pose() -> void:
	var ctx: Dictionary = _build_actor_context({
		"commando_supply_drop_state": FakeSupplyDropState.new(true),
	})
	_expect(bool(ctx.get("commando_radio_call_source_active", false)), "supply_drop radio_motion should mark radio-call source active")
	_expect(bool(ctx.get("commando_radio_call_active", false)), "supply_drop radio_motion should activate the radio-call pose")
	_expect(ctx.get("commando_radio_call_sheet", null) is Texture2D, "radio-call pose should expose its texture")
	_expect(int(ctx.get("commando_radio_call_frame", -1)) == 3, "current_msec=330 should map radio-call loop to frame 3")
	_expect(int(ctx.get("commando_radio_call_frame_count", 0)) == 8, "radio-call frame count should be 8")
	_expect(int(ctx.get("commando_radio_call_grid_cols", 0)) == 4, "radio-call grid cols should be 4")
	_expect(int(ctx.get("commando_radio_call_grid_rows", 0)) == 2, "radio-call grid rows should be 2")


func _verify_emergency_supply_radio_phase_activates_pose() -> void:
	var ctx: Dictionary = _build_actor_context({
		"commando_reload_delivery_state": FakeReloadDeliveryState.new(true),
	})
	_expect(bool(ctx.get("commando_radio_call_active", false)), "emergency_supply delivery radio phase should activate the radio-call pose")

	var inactive_ctx: Dictionary = _build_actor_context({
		"commando_reload_delivery_state": FakeReloadDeliveryState.new(false),
	})
	_expect(not bool(inactive_ctx.get("commando_radio_call_active", true)), "non-radio delivery phase should not activate the radio-call pose")


func _verify_fire_support_radio_phase_activates_pose() -> void:
	var ctx: Dictionary = _build_actor_context({
		"commando_firearm_runtime": FakeFirearmRuntime.new(true, false, false),
		"commando_weapon_controller": FakeWeaponController.new("fire_support"),
	})
	_expect(bool(ctx.get("commando_radio_call_source_active", false)), "fire_support radio support-call should mark radio-call source active")
	_expect(bool(ctx.get("commando_radio_call_active", false)), "fire_support radio support-call should activate the radio-call pose")


func _verify_scene_deps_feed_supply_and_reload_radio_motion() -> void:
	var supply_registry := FakeDrawRegistry.new()
	supply_registry.instances["commando_supply_drop_state"] = FakeSupplyDropState.new(true)
	supply_registry.instances["commando_reload_delivery_state"] = FakeReloadDeliveryState.new(false)
	supply_registry.instances["commando_firearm_runtime"] = FakeFirearmRuntime.new(false, false, false)
	supply_registry.instances["commando_weapon_controller"] = FakeWeaponController.new("pistol")
	var supply_result: Dictionary = _build_actor_context_from_scene_deps(supply_registry)
	var supply_deps: Dictionary = supply_result.get("deps", {})
	var supply_ctx: Dictionary = supply_result.get("actor_context", {})
	_expect(
		supply_deps.get("commando_supply_drop_state", null) == supply_registry.instances["commando_supply_drop_state"],
		"scoped soldier draw deps should include Commando supply-drop state"
	)
	_expect(
		supply_deps.get("commando_reload_delivery_state", null) == supply_registry.instances["commando_reload_delivery_state"],
		"scoped soldier draw deps should include Commando reload-delivery state"
	)
	_expect(supply_registry.requested_keys.has("commando_supply_drop_state"), "scoped soldier draw deps should request supply-drop state")
	_expect(supply_registry.requested_keys.has("commando_reload_delivery_state"), "scoped soldier draw deps should request reload-delivery state")
	_expect(bool(supply_ctx.get("commando_radio_call_active", false)), "scene-built deps should activate supply_drop radio-call pose")

	var reload_registry := FakeDrawRegistry.new()
	reload_registry.instances["commando_supply_drop_state"] = FakeSupplyDropState.new(false)
	reload_registry.instances["commando_reload_delivery_state"] = FakeReloadDeliveryState.new(true)
	reload_registry.instances["commando_firearm_runtime"] = FakeFirearmRuntime.new(false, false, false)
	reload_registry.instances["commando_weapon_controller"] = FakeWeaponController.new("pistol")
	var reload_result: Dictionary = _build_actor_context_from_scene_deps(reload_registry)
	var reload_ctx: Dictionary = reload_result.get("actor_context", {})
	_expect(bool(reload_ctx.get("commando_radio_call_active", false)), "scene-built deps should activate emergency_supply radio-call pose")

	var full_registry := FakeDrawRegistry.new()
	full_registry.instances["commando_supply_drop_state"] = FakeSupplyDropState.new(false)
	full_registry.instances["commando_reload_delivery_state"] = FakeReloadDeliveryState.new(false)
	var draw_builder := BattleDrawContext.new()
	var full_deps: Dictionary = draw_builder.build_scene_deps(full_registry, null, null)
	_expect(
		full_deps.get("commando_supply_drop_state", null) == full_registry.instances["commando_supply_drop_state"],
		"full draw deps should include Commando supply-drop state fallback"
	)
	_expect(
		full_deps.get("commando_reload_delivery_state", null) == full_registry.instances["commando_reload_delivery_state"],
		"full draw deps should include Commando reload-delivery state fallback"
	)


func _verify_weapon_fire_and_pistol_fire_take_priority() -> void:
	var weapon_ctx: Dictionary = _build_actor_context({
		"commando_supply_drop_state": FakeSupplyDropState.new(true),
		"commando_firearm_runtime": FakeFirearmRuntime.new(false, true, false),
		"commando_weapon_controller": FakeWeaponController.new("ak47"),
	})
	_expect(bool(weapon_ctx.get("commando_radio_call_source_active", false)), "radio source should remain visible to diagnostics during weapon-fire priority")
	_expect(bool(weapon_ctx.get("commando_weapon_fire_active", false)), "weapon fire should be active in priority test")
	_expect(not bool(weapon_ctx.get("commando_radio_call_active", true)), "weapon-fire sheet should take priority over radio-call pose")

	var pistol_ctx: Dictionary = _build_actor_context({
		"commando_supply_drop_state": FakeSupplyDropState.new(true),
		"commando_firearm_runtime": FakeFirearmRuntime.new(false, false, true),
	})
	_expect(bool(pistol_ctx.get("commando_pistol_fire_active", false)), "pistol-fire should be active in priority test")
	_expect(not bool(pistol_ctx.get("commando_radio_call_active", true)), "pistol-fire sheet should take priority over radio-call pose")


func _verify_non_commando_skips_radio_pose() -> void:
	var ctx: Dictionary = _build_actor_context({
		"commando_supply_drop_state": FakeSupplyDropState.new(true),
	}, "smasher")
	_expect(not bool(ctx.get("commando_radio_call_active", false)), "non-Commando characters must not activate radio-call pose")
	_expect(ctx.get("commando_radio_call_sheet", null) == null, "non-Commando context should not expose radio-call sheet")


func _verify_frame_region_mapping() -> void:
	var renderer := Stage1PlayerSpriteRenderer.new()
	for frame in range(8):
		var ctx := {
			"commando_radio_call_grid_cols": 4,
			"commando_radio_call_grid_rows": 2,
			"commando_radio_call_frame_count": 8,
			"commando_radio_call_cell_width": 160.0,
			"commando_radio_call_cell_height": 160.0,
			"commando_radio_call_frame": frame,
		}
		var region: Rect2 = renderer._get_commando_radio_call_sprite_region(ctx)
		var expected_col: int = frame % 4
		@warning_ignore("integer_division")
		var expected_row: int = int(frame / 4)
		_expect_rect(
			region,
			Rect2(Vector2(expected_col * 160.0, expected_row * 160.0), Vector2(160.0, 160.0)),
			"radio-call frame %d region" % frame
		)


func _build_actor_context(deps: Dictionary, character_type: String = "soldier") -> Dictionary:
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": character_type,
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var draw_builder := BattleDrawActorContext.new()
	return draw_builder.build({
		"selected_character_type": character_type,
		"textures": textures,
		"current_msec": 330,
		"player_pos": Vector2(320.0, 650.0),
		"player_paddle_size": Vector2(100.0, 50.0),
	}, deps)


func _build_actor_context_from_scene_deps(registry: FakeDrawRegistry) -> Dictionary:
	var draw_builder := BattleDrawContext.new()
	var resources := BattleResources.new()
	var textures: Dictionary = resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})
	var draw_context := {
		"selected_character_type": "soldier",
		"textures": textures,
		"current_stage": 1,
		"current_msec": 330,
		"player_pos": Vector2(320.0, 650.0),
		"player_paddle_size": Vector2(100.0, 50.0),
	}
	var deps: Dictionary = draw_builder.build_scene_deps(registry, null, null, draw_context)
	return {
		"deps": deps,
		"actor_context": draw_builder.build_actor_context(draw_context, deps),
	}


func _load_commando_textures() -> Dictionary:
	var resources := BattleResources.new()
	return resources.load_all({
		"selected_character_type": "soldier",
		"current_stage": 1,
		"include_all_characters": false,
		"include_all_stages": false,
		"include_result_sheets": false,
	})


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_rect(actual: Rect2, expected: Rect2, label: String) -> void:
	if (
		abs(actual.position.x - expected.position.x) > 0.001
		or abs(actual.position.y - expected.position.y) > 0.001
		or abs(actual.size.x - expected.size.x) > 0.001
		or abs(actual.size.y - expected.size.y) > 0.001
	):
		_failures.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


class FakeSupplyDropState extends RefCounted:
	var active: bool

	func _init(p_active: bool) -> void:
		active = p_active

	func get_snapshot() -> Dictionary:
		return {
			"radio_motion": active,
			"radio_timer": 0.2 if active else 0.0,
		}


class FakeReloadDeliveryState extends RefCounted:
	var active: bool
	var phase: String

	func _init(radio_phase: bool) -> void:
		active = radio_phase
		phase = "radio" if radio_phase else "run"

	func get_snapshot() -> Dictionary:
		return {
			"radio_visible": active,
			"radio_alpha": 1.0 if active else 0.0,
		}


class FakeWeaponController extends RefCounted:
	var current_weapon_id: String

	func _init(weapon_id: String) -> void:
		current_weapon_id = weapon_id


class FakeFirearmRuntime extends RefCounted:
	var support_radio_active: bool
	var weapon_fire_active: bool
	var pistol_fire_active: bool

	func _init(p_support_radio_active: bool, p_weapon_fire_active: bool, p_pistol_fire_active: bool) -> void:
		support_radio_active = p_support_radio_active
		weapon_fire_active = p_weapon_fire_active
		pistol_fire_active = p_pistol_fire_active

	func get_actor_draw_context() -> Dictionary:
		return {
			"commando_firearm_support_calls": [{
				"weapon_id": "fire_support",
				"radio_active": support_radio_active,
				"radio_timer_frames": 42.0 if support_radio_active else 0.0,
				"state": "calling" if support_radio_active else "inbound",
			}] if support_radio_active else [],
			"commando_firearm_weapon_fire_sheet_state": {
				"active": weapon_fire_active,
				"weapon_id": "ak47" if weapon_fire_active else "",
				"timer_frames": 40.0 if weapon_fire_active else 0.0,
				"timer_max_frames": 40.0,
				"frame_count": 8,
			},
			"commando_firearm_pistol_state": {
				"fire_delay_frames": 12.0 if pistol_fire_active else 0.0,
				"fire_delay_max_frames": 24.0,
				"post_fire_animation_frames": 0.0,
				"post_fire_animation_max_frames": 18.0,
				"animation_active": pistol_fire_active,
			},
			"commando_firearm_suicide_drone_state": {},
		}


class FakeDrawRegistry extends RefCounted:
	var instances: Dictionary = {}
	var requested_keys: Array[String] = []

	func get_instance(key: String) -> Object:
		requested_keys.append(key)
		return instances.get(key, null)
