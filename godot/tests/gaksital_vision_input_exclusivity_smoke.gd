extends SceneTree

const CharacterInfoOverlayInputHandler := preload("res://scripts/hud/character_info_overlay_input_handler.gd")
const BattleSceneActorUpdateDriver := preload("res://scripts/core/battle_scene_actor_update_driver.gd")
const BattleSceneBallUpdateDriver := preload("res://scripts/core/battle_scene_ball_update_driver.gd")
const CheongringwiVisionChosikState := preload("res://scripts/characters/cheongringwi_vision_chosik_state.gd")
const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const DaljiVisionChosikState := preload("res://scripts/characters/dalji_vision_chosik_state.gd")
const GaksitalVisionChosikState := preload("res://scripts/characters/gaksital_vision_chosik_state.gd")
const LingpetMountState := preload("res://scripts/lingpet/lingpet_mount_state.gd")
const LingpetCompanionPlayerRuntimeResolver := preload("res://scripts/lingpet/lingpet_companion_player_runtime_resolver.gd")
const PauseMenuInputCommandRouter := preload("res://scripts/hud/pause_menu_input_command_router.gd")
const PauseMenuPointerCommandRouter := preload("res://scripts/hud/pause_menu_pointer_command_router.gd")
const PaddleBounceSkillRouter := preload("res://scripts/ball/paddle_bounce_skill_router.gd")
const MythicItemHornStrawberryMaskRuntime := preload("res://scripts/items/mythic_item_horn_strawberry_mask_runtime.gd")
const MythicItemOdinsEyeRuntime := preload("res://scripts/items/mythic_item_odins_eye_runtime.gd")
const SmasherOverdriveState := preload("res://scripts/characters/smasher_overdrive_state.gd")
const SmasherPowerSmashActivationController := preload("res://scripts/characters/smasher_power_smash_activation_controller.gd")
const SmasherVoidPhantomState := preload("res://scripts/characters/smasher_void_phantom_state.gd")
const Stage3CurseControlInputProxy := preload("res://scripts/stages/stage3/stage3_curse_control_input_proxy.gd")
const ViperWallLeapTestSupport := preload("res://tests/wall_leap_test_support.gd")
const VisionInputExclusivePolicy := preload("res://scripts/characters/vision_input_exclusive_policy.gd")
const VisionModifierInputProxy := preload("res://scripts/characters/vision_modifier_input_proxy.gd")
const YeonmyoVisionChosikState := preload("res://scripts/characters/yeonmyo_vision_chosik_state.gd")

const DISCARD_LATCH_FIXTURE_ENV := "GAKSITAL_VISION_DISCARD_LATCH_FIXTURE"
const READER_SPLIT_FIXTURE_ENV := "GAKSITAL_VISION_READER_SPLIT_FIXTURE"
const SHARED_PROXY_FIXTURE_ENV := "GAKSITAL_VISION_SHARED_PROXY_FIXTURE"

var _failures: Array[String] = []
var _observed_split_raw_reader_calls := -1


class FakeInputReader:
	extends RefCounted

	var calls := 0
	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		calls += 1
		return snapshot.duplicate(true)


class FakeStunStatus:
	extends RefCounted

	func is_player_stun_active() -> bool:
		return true


class LegacyReaderScopedVisionFrame:
	extends RefCounted

	var proxy: Object = VisionModifierInputProxy.new()
	var cached_frame_key := -1
	var cached_owner_id := 0
	var cached_reader_id := 0
	var cached_frame: Dictionary = {}

	func prepare(
		frame_key: int,
		owner: Object,
		input_reader: Object,
		exclusive_active: bool
	) -> Dictionary:
		var owner_id := owner.get_instance_id()
		var reader_id := input_reader.get_instance_id() if input_reader != null else 0
		if (
			frame_key == cached_frame_key
			and owner_id == cached_owner_id
			and reader_id == cached_reader_id
			and not cached_frame.is_empty()
		):
			return cached_frame.duplicate()
		var snapshot: Dictionary = {}
		if input_reader != null and input_reader.has_method("get_snapshot"):
			var value: Variant = input_reader.get_snapshot()
			if value is Dictionary:
				snapshot = (value as Dictionary).duplicate(true)
		proxy.configure_snapshot(input_reader, snapshot, exclusive_active)
		cached_frame_key = frame_key
		cached_owner_id = owner_id
		cached_reader_id = reader_id
		cached_frame = {"input_reader": proxy, "raw_snapshot": snapshot}
		return cached_frame.duplicate()


class FakeSkillConfig:
	extends RefCounted

	var equipped: Array[String] = []

	func _init(skill_ids: Array[String] = []) -> void:
		equipped = skill_ids.duplicate()

	func is_skill_equipped(skill_id: String) -> bool:
		return equipped.has(skill_id)

	func get_cooldown_seconds(skill_id: String) -> float:
		return float(CommonSkillCatalog.get_skill_data(skill_id).get("cooldown", 5.0))

	func get_skill_cost(_skill_id: String) -> float:
		return 1.0


class FakeOwner:
	extends RefCounted

	var special_gauge := 500.0
	var selected_character_type := "smasher"
	var player_pos := Vector2(300.0, 680.0)
	var player_paddle_width := 155.0
	var player_speed := 0.0
	var gameplay_frame_counter := 0
	var activated := false


class FakeRegistry:
	extends RefCounted

	var instances := {}

	func _init(next_instances: Dictionary = {}) -> void:
		instances = next_instances

	func get_cached_instance(key: String) -> Object:
		return instances.get(key, null)

	func get_instance(key: String) -> Object:
		return instances.get(key, null)


class FakeContextBuilder:
	extends RefCounted

	var deps: Dictionary = {}

	func build_player_control_deps(_registry: Object, _character_type: String) -> Dictionary:
		return deps.duplicate()


class FakeConfigBuilder:
	extends RefCounted

	var config: Dictionary = {}

	func build_config(_owner: Object, _registry: Object, _character_type: String, _context_builder: Object) -> Dictionary:
		return config.duplicate(true)


class FakeController:
	extends RefCounted

	var calls := 0
	var snapshot: Dictionary = {}
	var dash_snapshot: Dictionary = {}
	var config_snapshot: Dictionary = {}

	func update(
		_delta: float,
		frame_counter: int,
		player_pos: Vector2,
		player_speed: float,
		config: Dictionary,
		deps: Dictionary
	) -> Dictionary:
		calls += 1
		config_snapshot = config.duplicate(true)
		var input_reader: Object = deps.get("input_reader", null)
		snapshot = input_reader.get_snapshot()
		var dash_input_reader: Object = deps.get("dash_input_reader", null)
		if dash_input_reader != null and dash_input_reader != input_reader:
			dash_snapshot = dash_input_reader.get_snapshot()
		else:
			dash_snapshot = snapshot.duplicate(true)
		return {
			"frame_counter": frame_counter + 1,
			"player_pos": player_pos,
			"player_speed": player_speed,
			"special_gauge": float(config.get("special_gauge", 0.0)),
		}


class FakePowerState:
	extends RefCounted

	var begin_calls := 0

	func can_activate(
		_waiting_for_serve: bool,
		_ball_active: bool,
		_special_gauge: float,
		_gauge_cost: float,
		_frame_cooldown_blocked: bool,
		_cooldown_remaining: float
	) -> bool:
		return true

	func begin_activation(
		_direction: int,
		_arc_strength: float,
		_combo_consumed: int,
		_text_duration_frames: float,
		_is_ghost_shot: bool,
		_current_msec: int,
		_freeze_duration: float
	) -> void:
		begin_calls += 1


class FakeHornRuntime:
	extends RefCounted

	func _safe_owner_get(owner: Object, key: String, fallback: Variant) -> Variant:
		if owner == null:
			return fallback
		var value: Variant = owner.get(key)
		return fallback if value == null else value


class FakeResultApplier:
	extends RefCounted

	func apply_player_result(owner: Object, _registry: Object, result: Dictionary) -> void:
		for key: String in result:
			owner.set(key, result[key])

	func apply_boss_result(_owner: Object, _result: Dictionary) -> void:
		pass


class MountInputProbe:
	extends RefCounted

	var rmb_pressed := false

	func is_rmb_pressed() -> bool:
		return rmb_pressed

	func is_down_pressed() -> bool:
		return false


class FakeCharacterInfoTarget:
	extends RefCounted

	var active := true
	var _drag_active := true
	var drag_cancel_calls := 0
	var redraw_calls := 0

	func _is_discard_confirm_active() -> bool:
		return false

	func _drag_cancel() -> void:
		drag_cancel_calls += 1
		_drag_active = false

	func _reset_hover_and_request_redraw(_force: bool) -> void:
		redraw_calls += 1


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if OS.get_environment(DISCARD_LATCH_FIXTURE_ENV) == "1":
		print("[GaksitalVisionInputCounterproof] DISCARD_LATCH_REMOVED=EXPECTED_RED")
		_verify_release_leak_negative_fixture()
		_finish()
		return
	if OS.get_environment(SHARED_PROXY_FIXTURE_ENV) == "1":
		print("[GaksitalVisionInputCounterproof] SHARED_PROXY_BYPASSED=EXPECTED_RED")
		_verify_paddle_and_mythic_production_consumers(true)
		_finish()
		return
	if OS.get_environment(READER_SPLIT_FIXTURE_ENV) == "1":
		print("[GaksitalVisionInputCounterproof] READER_SCOPED_CACHE=EXPECTED_RED")
		_verify_reader_split_legacy_counterproof()
		_finish()
		return
	_verify_project_action_and_single_snapshot()
	_verify_actor_driver_production_path()
	_verify_split_production_readers_share_frame_snapshot()
	_verify_release_latch_survives_split_release_frame()
	_verify_no_vision_production_status_passthrough()
	_verify_consumer_negative_legs()
	_verify_paddle_and_mythic_production_consumers()
	_verify_gaksital_positive_leg()
	_verify_existing_visions_and_shared_gauge()
	_verify_release_discard_until_release()
	_verify_no_vision_passthrough()
	_verify_ui_priority_legs()
	if _failures.is_empty():
		print("[GaksitalVisionInputExclusivitySeal] CONSUMERS=GREEN smasher=0 viper=0 commando=0 baekrin_mount=0")
		print("[GaksitalVisionInputExclusivitySeal] PADDLE_CONTACT=GREEN power_smash=0 void_phantom=0 shared_proxy=true")
		print("[GaksitalVisionInputExclusivitySeal] MYTHIC=GREEN odins_eye=0 horn_strawberry=0 shared_proxy=true")
		print("[GaksitalVisionInputExclusivitySeal] POSITIVE=GREEN gaksital=1 cost=80 cooldown=5")
		print("[GaksitalVisionInputExclusivitySeal] VISIONS=GREEN dalji=1 yeonmyo=1 cheongringwi_lrl=1 shared_gauge=unlocked")
		print("[GaksitalVisionInputExclusivitySeal] RELEASE=GREEN discard_until_release=true delayed_combat=0")
		print("[GaksitalVisionInputExclusivitySeal] NO_VISION=GREEN policy=passthrough smasher_baseline=1")
		print("[GaksitalVisionInputExclusivitySeal] UI=GREEN pause_rmb=preserved character_info_rmb=preserved map_priority=preserved")
		print(
			"[GaksitalVisionInputExclusivitySeal] SNAPSHOT=GREEN raw_reader_calls=%d reader_split=status_proxy_vs_raw cache_key=frame_owner"
			% _observed_split_raw_reader_calls
		)
	_finish()


func _verify_project_action_and_single_snapshot() -> void:
	_expect(InputMap.has_action("vision_modifier"), "project input map must declare vision_modifier")
	var has_shift := false
	for event: InputEvent in InputMap.action_get_events("vision_modifier"):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT:
				has_shift = true
	_expect(has_shift, "vision_modifier must map to Shift")
	var reader := FakeInputReader.new()
	reader.snapshot = _combat_snapshot()
	var raw_snapshot := reader.get_snapshot()
	var proxy: Object = VisionModifierInputProxy.new().configure_snapshot(reader, raw_snapshot, true)
	var filtered: Dictionary = proxy.get_snapshot()
	_expect_eq(proxy.get_snapshot(), filtered, "filtered proxy snapshot must be same-frame idempotent")
	_expect_eq(reader.calls, 1, "Vision layer and controller must share one reader snapshot")
	_verify_all_combat_channels_blocked(filtered, true)
	_expect(bool(raw_snapshot.get("secondary_action_just_pressed", false)), "raw Vision snapshot must retain RMB edge")
	var actor_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_actor_update_driver.gd")
	_expect_eq(actor_source.count("canonical_input_reader.get_snapshot()"), 1, "production actor driver must sample the canonical reader once")
	_expect(
		actor_source.contains("_vision_modifier_input_proxy.configure_snapshot(")
		and actor_source.contains("canonical_input_reader"),
		"production controller must configure its proxy from the canonical raw snapshot"
	)
	_expect(not actor_source.contains("_vision_input_reader_id"), "production frame cache must not key by caller reader identity")


func _verify_actor_driver_production_path() -> void:
	var reader := FakeInputReader.new()
	reader.snapshot = _combat_snapshot()
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var gaksital := GaksitalVisionChosikState.new()
	var context_builder := FakeContextBuilder.new()
	context_builder.deps = {
		"input_reader": reader,
		"skill_config": skill_config,
		"gaksital_vision_chosik_state": gaksital,
	}
	var config_builder := FakeConfigBuilder.new()
	config_builder.config = _vision_config(100.0)
	var controller := FakeController.new()
	var registry := FakeRegistry.new({
		"battle_update_context": context_builder,
		"battle_scene_player_control_config_builder": config_builder,
		"battle_scene_actor_update_result_applier": FakeResultApplier.new(),
		"smasher_player_controller": controller,
	})
	var owner := FakeOwner.new()
	owner.special_gauge = 100.0
	Input.action_press("vision_modifier")
	BattleSceneActorUpdateDriver.new().update_player_control(owner, registry, 0.0)
	Input.action_release("vision_modifier")
	_expect_eq(reader.calls, 1, "production actor driver must read the stateful input reader once")
	_expect_eq(controller.calls, 1, "production character controller must run once")
	_verify_all_combat_channels_blocked(controller.snapshot, false)
	_expect(not bool(controller.config_snapshot.get("horizontal_input_locked", false)), "Gaksital-only Vision must not engage the controller horizontal lock")
	_expect(bool(controller.config_snapshot.get("vision_input_exclusive", false)), "Gaksital-only Vision must still own non-movement combat input")
	_expect_eq(gaksital.fans.size(), 1, "production raw Vision layer must activate one Gaksital fan")
	_expect_eq(owner.special_gauge, 20.0, "production actor path must apply the 80-vigor spend")


func _verify_split_production_readers_share_frame_snapshot() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = _combat_snapshot()
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		FakeStunStatus.new()
	)
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	context_builder.deps = {
		"input_reader": status_reader,
		"dash_input_reader": status_reader,
		"skill_config": skill_config,
		"gaksital_vision_chosik_state": GaksitalVisionChosikState.new(),
	}
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_actor_update_driver": actor_driver,
		"battle_scene_player_control_config_builder": FakeConfigBuilder.new(),
		"battle_scene_actor_update_result_applier": FakeResultApplier.new(),
		"battle_update_context": context_builder,
		"smasher_input_reader": raw_reader,
		"smasher_skill_config": skill_config,
		"smasher_player_controller": controller,
	})
	(registry.get_instance("battle_scene_player_control_config_builder") as FakeConfigBuilder).config = _vision_config(500.0)
	Input.action_press("vision_modifier")
	# Production order: mythic/raw first, player-control/status proxy next,
	# ball/raw afterward, then the second mythic raw lookup.
	var odin_reader: Object = MythicItemOdinsEyeRuntime.new()._get_vision_aware_input_reader(
		owner,
		registry,
		raw_reader
	)
	actor_driver.update_player_control(owner, registry, 0.0)
	var ball_deps := {"input_reader": raw_reader, "skill_config": skill_config}
	BattleSceneBallUpdateDriver.new()._apply_vision_input_reader(ball_deps, owner, registry)
	var horn_reader: Object = MythicItemHornStrawberryMaskRuntime.new()._get_input_reader(
		FakeHornRuntime.new(),
		owner,
		registry
	)
	Input.action_release("vision_modifier")
	_observed_split_raw_reader_calls = raw_reader.calls
	_expect(odin_reader == ball_deps.get("input_reader", null), "mythic/raw and ball/raw callers must share the frame proxy")
	_expect(horn_reader == odin_reader, "both mythic raw callers must share the frame proxy")
	_expect_eq(controller.calls, 1, "split-reader player controller call count")
	_expect_eq(controller.snapshot, controller.dash_snapshot, "player control and dash lanes must share the canonical snapshot")
	_expect_eq(raw_reader.calls, 1, "status-proxy player control and raw ball/mythic callers must sample raw input once")


func _verify_release_latch_survives_split_release_frame() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {"down_pressed": true}
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		FakeStunStatus.new()
	)
	var skill_config := FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_actor_update_driver": actor_driver,
		"smasher_input_reader": raw_reader,
		"smasher_skill_config": skill_config,
	})
	Input.action_press("vision_modifier")
	var shared_reader: Object = actor_driver.get_vision_aware_input_reader(owner, registry, raw_reader, skill_config)
	_expect(shared_reader.has_pending_release_suppression(), "Vision hold frame must arm the release latch")
	actor_driver.reset_vision_input_frame_cache_for_test()
	Input.action_release("vision_modifier")
	var calls_before_release_frame := raw_reader.calls
	var mythic_reader: Object = actor_driver.get_vision_aware_input_reader(owner, registry, raw_reader, skill_config)
	var player_reader: Object = actor_driver.get_vision_aware_input_reader(owner, registry, status_reader, skill_config)
	var ball_reader: Object = actor_driver.get_vision_aware_input_reader(owner, registry, raw_reader, skill_config)
	_expect(mythic_reader == player_reader and player_reader == ball_reader, "release-frame split callers must retain one proxy")
	_expect_eq(raw_reader.calls - calls_before_release_frame, 1, "release frame must sample only the canonical raw reader")
	_expect(not bool(ball_reader.get_snapshot().get("down_pressed", false)), "held combat input must not leak after Shift release")
	_expect(ball_reader.has_pending_release_suppression(), "held raw input must keep the release latch armed")
	raw_reader.snapshot = {}
	actor_driver.reset_vision_input_frame_cache_for_test()
	var released_reader: Object = actor_driver.get_vision_aware_input_reader(owner, registry, raw_reader, skill_config)
	_expect(not released_reader.has_pending_release_suppression(), "canonical physical release must clear the latch on the next frame")


func _verify_no_vision_production_status_passthrough() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = _combat_snapshot()
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		FakeStunStatus.new()
	)
	var no_vision := FakeSkillConfig.new(["smasher_overdrive"])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	var controller := FakeController.new()
	var context_builder := FakeContextBuilder.new()
	context_builder.deps = {
		"input_reader": status_reader,
		"dash_input_reader": status_reader,
		"skill_config": no_vision,
	}
	var config_builder := FakeConfigBuilder.new()
	config_builder.config = _vision_config(500.0)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_actor_update_driver": actor_driver,
		"battle_scene_player_control_config_builder": config_builder,
		"battle_scene_actor_update_result_applier": FakeResultApplier.new(),
		"battle_update_context": context_builder,
		"smasher_input_reader": raw_reader,
		"smasher_skill_config": no_vision,
		"smasher_player_controller": controller,
	})
	Input.action_release("vision_modifier")
	actor_driver.update_player_control(owner, registry, 0.0)
	_expect(bool(controller.snapshot.get("player_stun_active", false)), "no-Vision production control must preserve the status proxy")
	_expect(not bool(controller.snapshot.get("down_pressed", false)), "no-Vision production control must retain stun input suppression")


func _verify_reader_split_legacy_counterproof() -> void:
	var raw_reader := FakeInputReader.new()
	raw_reader.snapshot = {"down_pressed": true}
	var status_reader: Object = Stage3CurseControlInputProxy.new().configure(
		raw_reader,
		null,
		FakeStunStatus.new()
	)
	var owner := FakeOwner.new()
	var legacy := LegacyReaderScopedVisionFrame.new()
	legacy.prepare(10, owner, raw_reader, true)
	var calls_before_release_frame := raw_reader.calls
	legacy.prepare(11, owner, raw_reader, false)
	legacy.prepare(11, owner, status_reader, false)
	var leaked_reader: Object = legacy.prepare(11, owner, raw_reader, false).get("input_reader", null)
	_expect_eq(raw_reader.calls - calls_before_release_frame, 1, "reader-scoped cache counterproof must catch repeated raw sampling")
	_expect(not bool(leaked_reader.get_snapshot().get("down_pressed", false)), "reader-scoped cache counterproof must catch the mid-frame release leak")


func _verify_consumer_negative_legs() -> void:
	var raw := _combat_snapshot()
	var proxy: Object = VisionModifierInputProxy.new().configure_snapshot(null, raw, true)
	var filtered: Dictionary = proxy.get_snapshot()
	var smasher := SmasherOverdriveState.new()
	var smasher_config := FakeSkillConfig.new(["smasher_overdrive", CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var smasher_result := smasher.update_input(
		filtered, 0, 500.0, Vector2.ZERO,
		{"ball_active": true, "player_skill_input_locked": false, "ball_vel": Vector2.UP * 8.0},
		{"skill_config": smasher_config}
	)
	_expect(not bool(smasher_result.get("activated", false)) and not smasher.is_active(), "Shift Vision must block Smasher overdrive")
	var wall_support := ViperWallLeapTestSupport.new()
	var wall_fixture: Dictionary = wall_support.make_fixture()
	wall_support.route_once(wall_fixture, filtered)
	_expect(str(wall_fixture["runtime"].get_snapshot().get("wall_leap_raid_state", "")) == "idle", "Shift Vision must block Viper wall-leap RMB")
	var commando_config := CommandoSkillConfig.new()
	var commando_state := CommandoSkillState.new()
	var supply := CommandoSupplyDropState.new()
	var supply_result := supply.update_input(
		filtered, 1.0, 500.0, commando_config, commando_state,
		{"skill_config": commando_config, "skill_state": commando_state}
	)
	_expect(not bool(supply_result.get("activated", false)), "Shift Vision must block Commando supply hold")
	var mount := LingpetMountState.new()
	var mount_probe := MountInputProbe.new()
	var mount_owner := FakeOwner.new()
	mount.set_pet_id("baekrin")
	mount.set_input_probe(mount_probe)
	mount_probe.rmb_pressed = true
	var mount_registry := FakeRegistry.new({
		"smasher_skill_config": FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID]),
	})
	Input.action_press("vision_modifier")
	var right_click_claimed := LingpetCompanionPlayerRuntimeResolver.new().is_right_click_claimed_by_player_skill(
		mount_owner,
		mount_registry
	)
	Input.action_release("vision_modifier")
	_expect(right_click_claimed, "equipped Vision Shift must claim direct-polled RMB from the mount path")
	var mount_result := mount.advance(mount_owner, Vector2(377.5, 690.0), true, right_click_claimed, 0.0, true, false, false)
	_expect(not bool(mount_result.get("toggled", false)) and not mount.is_mounted(), "Shift Vision must block direct-polled Baekrin mount")


func _verify_paddle_and_mythic_production_consumers(bypass_shared_proxy: bool = false) -> void:
	var reader := FakeInputReader.new()
	reader.snapshot = _combat_snapshot()
	var skill_config := FakeSkillConfig.new([
		"power_smashing",
		"void_phantom",
		CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID,
	])
	var actor_driver := BattleSceneActorUpdateDriver.new()
	if bypass_shared_proxy:
		actor_driver.set_vision_proxy_enabled_for_test(false)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new({
		"battle_scene_actor_update_driver": actor_driver,
		"smasher_input_reader": reader,
		"smasher_skill_config": skill_config,
	})
	Input.action_press("vision_modifier")
	var shared_reader: Object = actor_driver.get_vision_aware_input_reader(
		owner,
		registry,
		reader,
		skill_config
	)

	# Actual ball-driver injection must retain the actor driver's one proxy. The
	# contact router then reaches both the power controller and void-phantom
	# claim predicate with that filtered reader.
	var ball_deps := {
		"input_reader": reader,
		"skill_config": skill_config,
	}
	BattleSceneBallUpdateDriver.new()._apply_vision_input_reader(ball_deps, owner, registry)
	_expect(ball_deps.get("input_reader", null) == shared_reader, "ball contact deps must reuse the actor driver's single Vision proxy")
	var power_state := FakePowerState.new()
	var void_state := SmasherVoidPhantomState.new()
	ball_deps.merge({
		"power_activation_controller": SmasherPowerSmashActivationController.new(),
		"power_state": power_state,
		"smasher_void_phantom_state": void_state,
	}, true)
	var contact_context := {
		"ball_active": true,
		"special_gauge": 500.0,
		"power_smash_gauge_cost": 1.0,
		"current_msec": 1000,
	}
	var power_result: Dictionary = PaddleBounceSkillRouter.new().try_activate_power_smashing(
		Vector2(380.0, 680.0),
		true,
		500.0,
		contact_context,
		ball_deps,
		{}
	)
	_expect(not bool(power_result.get("activated", false)), "Shift Vision must block power-smash at paddle contact")
	_expect_eq(power_state.begin_calls, 0, "paddle-contact power activation count")
	_expect(not void_state.is_contact_claimed(contact_context, ball_deps), "Shift Vision must block void phantom at paddle contact")
	_expect_eq(void_state.roll_count, 0, "paddle-contact void phantom activation count")

	# Both direct-registry mythic readers run before player control, so they must
	# obtain the already-sampled shared proxy rather than polling raw Input.
	var odin_reader: Object = MythicItemOdinsEyeRuntime.new()._get_vision_aware_input_reader(
		owner,
		registry,
		reader
	)
	var horn_reader: Object = MythicItemHornStrawberryMaskRuntime.new()._get_input_reader(
		FakeHornRuntime.new(),
		owner,
		registry
	)
	_expect(odin_reader == shared_reader, "Odin runtime must reuse the single Vision proxy")
	_expect(horn_reader == shared_reader, "horn-strawberry runtime must reuse the single Vision proxy")
	var odin_snapshot: Dictionary = odin_reader.get_snapshot()
	var horn_snapshot: Dictionary = horn_reader.get_snapshot()
	_expect(not bool(odin_snapshot.get("mouse_left_just_pressed", false)), "Shift Vision must block Odin dark-swamp LMB")
	_expect(
		not bool(horn_snapshot.get("left_pressed", true))
		and not bool(horn_snapshot.get("right_pressed", true))
		and bool(horn_snapshot.get("movement_left_pressed", false))
		and bool(horn_snapshot.get("movement_right_pressed", false))
		and not bool(horn_snapshot.get("down_pressed", false)),
		"Gaksital-only Vision must split horizontal movement from blocked command lanes"
	)
	_expect(bool(horn_snapshot.get("vision_input_exclusive", false)), "horn command listener must receive the Vision ownership marker")
	_expect_eq(reader.calls, 1, "paddle and mythic consumers must share one raw reader sample")
	Input.action_release("vision_modifier")


func _verify_gaksital_positive_leg() -> void:
	var state := GaksitalVisionChosikState.new()
	var owner := FakeOwner.new()
	owner.special_gauge = 100.0
	var result := state.update(
		0.0,
		{"secondary_action_pressed": true, "secondary_action_just_pressed": true},
		true,
		Vector2(300.0, 680.0),
		_vision_config(100.0),
		{"owner": owner, "skill_config": FakeSkillConfig.new([CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])}
	)
	_expect(bool(result.get("activated", false)), "Shift+RMB must activate Gaksital Vision")
	_expect_eq(owner.special_gauge, 20.0, "Shift+RMB must spend exactly 80 vigor")
	_expect_eq(state.cooldown_remaining, 5.0, "Shift+RMB must arm the five-second cooldown")


func _verify_existing_visions_and_shared_gauge() -> void:
	var dalji := DaljiVisionChosikState.new()
	var dalji_owner := FakeOwner.new()
	var dalji_result := dalji.update(
		0.0, {"up_pressed": true}, true, Vector2(300.0, 680.0), _vision_config(500.0),
		{"owner": dalji_owner, "skill_config": FakeSkillConfig.new([CommonSkillCatalog.DALJI_VISION_CHAIN_TOP_ID])}
	)
	_expect(bool(dalji_result.get("activated", false)), "Dalji Shift+Up must still activate from raw input")
	var yeonmyo := YeonmyoVisionChosikState.new()
	var yeonmyo_owner := FakeOwner.new()
	var yeonmyo_result := yeonmyo.update(
		0.0, {"down_pressed": true}, true, Vector2(300.0, 680.0), _vision_config(500.0),
		{"owner": yeonmyo_owner, "skill_config": FakeSkillConfig.new([CommonSkillCatalog.YEONMYO_VISION_BONGHONGWE_ID])}
	)
	_expect(bool(yeonmyo_result.get("activated", false)), "Yeonmyo Shift+Down must still activate from raw input")
	var gaksital := GaksitalVisionChosikState.new()
	var cheong := CheongringwiVisionChosikState.new()
	var shared_owner := FakeOwner.new()
	shared_owner.special_gauge = 330.0
	var shared_config := _vision_config(330.0)
	var shared_skills := FakeSkillConfig.new([
		CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID,
		CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID,
	])
	var shared_deps := {"owner": shared_owner, "skill_config": shared_skills}
	var fan_result := gaksital.update(
		0.0, {"secondary_action_pressed": true, "secondary_action_just_pressed": true}, true,
		Vector2(300.0, 680.0), shared_config, shared_deps
	)
	_expect(bool(fan_result.get("activated", false)), "shared loadout RMB must activate only Gaksital")
	shared_config["special_gauge"] = float(fan_result.get("special_gauge", 330.0))
	var cheong_rmb := cheong.update(
		0.0, {"secondary_action_pressed": true, "secondary_action_just_pressed": true}, true,
		Vector2.ZERO, shared_config, shared_deps
	)
	_expect(not bool(cheong_rmb.get("activated", false)) and cheong.command_step == 0, "Gaksital RMB must not touch Cheong command state")
	gaksital.update(0.0, {}, true, Vector2.ZERO, shared_config, shared_deps)
	cheong.update(0.0, {}, true, Vector2.ZERO, shared_config, shared_deps)
	var fan_activations_during_command := 0
	var cheong_result: Dictionary = {}
	for snapshot: Dictionary in [
		{"left_pressed": true}, {}, {"right_pressed": true}, {}, {"left_pressed": true},
	]:
		var fan_command_result := gaksital.update(0.0, snapshot, true, Vector2.ZERO, shared_config, shared_deps)
		if bool(fan_command_result.get("activated", false)):
			fan_activations_during_command += 1
		cheong_result = cheong.update(0.0, snapshot, true, Vector2.ZERO, shared_config, shared_deps)
		if cheong_result.has("special_gauge"):
			shared_config["special_gauge"] = float(cheong_result.get("special_gauge", 0.0))
	_expect_eq(fan_activations_during_command, 0, "Cheong L-R-L must not parasitically activate Gaksital")
	_expect(bool(cheong_result.get("activated", false)), "Cheong L-R-L must complete after Gaksital spends 80")
	_expect_eq(float(shared_config.get("special_gauge", -1.0)), 0.0, "330 vigor must fund Gaksital 80 then Cheong 250 without lockout")


func _verify_release_discard_until_release() -> void:
	var proxy := VisionModifierInputProxy.new()
	var skill_config := FakeSkillConfig.new(["smasher_overdrive", CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	var overdrive := SmasherOverdriveState.new()
	var config := {"ball_active": true, "player_skill_input_locked": false, "ball_vel": Vector2.UP * 8.0}
	var raw_hold := _combat_snapshot()
	var blocked: Dictionary = proxy.configure_snapshot(null, raw_hold, true).get_snapshot()
	overdrive.update_input(blocked, 0, 500.0, Vector2.ZERO, config, {"skill_config": skill_config})
	var held_after_shift_release := raw_hold.duplicate(true)
	held_after_shift_release["secondary_action_just_pressed"] = false
	var drained: Dictionary = proxy.configure_snapshot(null, held_after_shift_release, false).get_snapshot()
	overdrive.update_input(drained, 1, 500.0, Vector2.ZERO, config, {"skill_config": skill_config})
	_expect(not overdrive.is_active(), "RMB held across Shift release must not activate Smasher late")
	var released: Dictionary = proxy.configure_snapshot(null, {"action_just_released": true}, false).get_snapshot()
	_expect(not bool(released.get("action_just_released", false)), "blocked action release edge must be discarded")
	_expect(proxy.should_filter_current_snapshot(), "the physical release frame must still route through the proxy")
	_expect(not proxy.has_pending_release_suppression(), "release drain must clear after physical release")
	proxy.configure_snapshot(null, {}, false)
	_expect(not proxy.should_filter_current_snapshot(), "the frame after release must return to the raw reader")
	var fresh_press: Dictionary = proxy.configure_snapshot(null, _combat_snapshot(), false).get_snapshot()
	var fresh_result := overdrive.update_input(fresh_press, 2, 500.0, Vector2.ZERO, config, {"skill_config": skill_config})
	_expect(bool(fresh_result.get("activated", false)), "a fresh post-release combat chord must work")


func _verify_release_leak_negative_fixture() -> void:
	var proxy := VisionModifierInputProxy.new()
	proxy.set_discard_latch_enabled_for_test(false)
	var overdrive := SmasherOverdriveState.new()
	var skill_config := FakeSkillConfig.new(["smasher_overdrive", CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID])
	proxy.configure_snapshot(null, _combat_snapshot(), true)
	# Toggle the production latch off. A held chord then escapes on Shift release;
	# this assertion is GREEN with the latch and intentionally RED without it.
	var leaked_snapshot: Dictionary = proxy.configure_snapshot(null, _combat_snapshot(), false).get_snapshot()
	var result := overdrive.update_input(
		leaked_snapshot, 1, 500.0, Vector2.ZERO,
		{"ball_active": true, "player_skill_input_locked": false, "ball_vel": Vector2.UP * 8.0},
		{"skill_config": skill_config}
	)
	_expect(not bool(result.get("activated", false)), "discard-latch counterproof must catch a deferred Smasher edge")


func _verify_no_vision_passthrough() -> void:
	var no_vision := FakeSkillConfig.new(["smasher_overdrive"])
	_expect(not VisionInputExclusivePolicy.is_active(true, no_vision), "Shift without equipped Vision must not own combat input")
	var proxy: Object = VisionModifierInputProxy.new().configure_snapshot(null, _combat_snapshot(), false)
	var passthrough: Dictionary = proxy.get_snapshot()
	_expect(bool(passthrough.get("secondary_action_just_pressed", false)), "no-Vision Shift must preserve RMB edge")
	var overdrive := SmasherOverdriveState.new()
	var result := overdrive.update_input(
		passthrough, 0, 500.0, Vector2.ZERO,
		{"ball_active": true, "player_skill_input_locked": false, "ball_vel": Vector2.UP * 8.0},
		{"skill_config": no_vision}
	)
	_expect(bool(result.get("activated", false)) and overdrive.is_active(), "no-Vision policy must preserve the existing Smasher Down+RMB chord")


func _verify_ui_priority_legs() -> void:
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	var pause_command := PauseMenuPointerCommandRouter.new().route_button(
		right_click, false, "", "keyboard_mouse", Vector2(2020.0, 1246.0), 4
	)
	_expect_eq(str(pause_command.get("command", "")), str(PauseMenuInputCommandRouter.COMMAND_CLOSE_MAIN), "pause-menu RMB close must remain intact")
	var character_info := FakeCharacterInfoTarget.new()
	_expect(CharacterInfoOverlayInputHandler.handle_input(character_info, right_click, null, null), "character-info RMB must remain handled by the overlay")
	_expect_eq(character_info.drag_cancel_calls, 1, "character-info RMB must still cancel a held item")
	var input_source := FileAccess.get_file_as_string("res://scripts/core/battle_scene_input_controller.gd")
	var overlay_index := input_source.find("_get_overlay_input_controller")
	var map_index := input_source.find("_tower_map_overlay_input_router.handle_open_shortcut")
	var vision_index := input_source.find("VisionInputExclusivePolicy.is_active_for_owner")
	var combat_index := input_source.find("_handle_active_item_hud_input", vision_index)
	_expect(overlay_index >= 0 and overlay_index < vision_index, "system/UI overlay routing must stay above Vision ownership")
	_expect(map_index >= 0 and map_index < vision_index, "Tower-map toggle must stay above Vision ownership")
	_expect(vision_index >= 0 and vision_index < combat_index, "Vision ownership must intercept only the remaining combat layer")


func _combat_snapshot() -> Dictionary:
	return {
		"left_pressed": true, "right_pressed": true, "up_pressed": true, "down_pressed": true,
		"up_just_pressed": true, "action_pressed": true, "action_just_pressed": true,
		"action_just_released": true, "mouse_left_pressed": true, "mouse_left_just_pressed": true,
		"mouse_middle_pressed": true, "mouse_middle_just_pressed": true,
		"firearm_reset_just_pressed": true, "secondary_action_pressed": true,
		"secondary_action_just_pressed": true, "supply_drop_hold_pressed": true,
		"commando_supply_drop_hold_pressed": true, "mouse_right_pressed": true,
		"gamepad_supply_hold_pressed": true, "jetpack_pressed": true,
		"direction": 1.0, "power_smash_direction": 1, "blacksmith_swing_direction": 1,
	}


func _vision_config(gauge: float) -> Dictionary:
	return {
		"ball_active": true, "player_skill_input_locked": false, "special_gauge": gauge,
		"paddle_width": 155.0, "paddle_height": 50.0, "boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0, "boss_hitbox_height": 40.0,
		"width": 760.0, "height": 750.0, "current_stage": 1,
	}


func _verify_all_combat_channels_blocked(filtered: Dictionary, horizontal_blocked: bool) -> void:
	for key in [
		"up_pressed", "down_pressed", "up_just_pressed",
		"action_pressed", "action_just_pressed", "action_just_released", "mouse_left_pressed",
		"mouse_left_just_pressed", "mouse_middle_pressed", "mouse_middle_just_pressed",
		"firearm_reset_just_pressed", "secondary_action_pressed", "secondary_action_just_pressed",
		"supply_drop_hold_pressed", "commando_supply_drop_hold_pressed", "mouse_right_pressed",
		"gamepad_supply_hold_pressed", "jetpack_pressed",
	]:
		_expect(not bool(filtered.get(key, false)), "exclusive Vision proxy must block %s" % key)
	if horizontal_blocked:
		_expect(not bool(filtered.get("left_pressed", false)), "horizontal-owning Vision must block left input")
		_expect(not bool(filtered.get("right_pressed", false)), "horizontal-owning Vision must block right input")
		_expect_eq(float(filtered.get("direction", 1.0)), 0.0, "horizontal-owning Vision movement direction")
		_expect(not bool(filtered.get("movement_left_pressed", false)), "horizontal-owning Vision must block movement left")
		_expect(not bool(filtered.get("movement_right_pressed", false)), "horizontal-owning Vision must block movement right")
	else:
		_expect(not bool(filtered.get("left_pressed", true)), "Gaksital-only Vision must block command left")
		_expect(not bool(filtered.get("right_pressed", true)), "Gaksital-only Vision must block command right")
		_expect_eq(float(filtered.get("direction", 1.0)), 0.0, "Gaksital-only Vision must block command direction")
		_expect(bool(filtered.get("movement_left_pressed", false)), "Gaksital-only Vision must pass held movement left")
		_expect(bool(filtered.get("movement_right_pressed", false)), "Gaksital-only Vision must pass held movement right")
		_expect_eq(float(filtered.get("movement_direction", 0.0)), 1.0, "Gaksital-only Vision must preserve the authoritative movement direction")
	_expect_eq(int(filtered.get("power_smash_direction", 1)), 0, "exclusive Smasher direction")
	_expect_eq(int(filtered.get("blacksmith_swing_direction", 1)), 0, "exclusive Blacksmith direction")


func _finish() -> void:
	if _failures.is_empty():
		print("gaksital_vision_input_exclusivity_smoke: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
