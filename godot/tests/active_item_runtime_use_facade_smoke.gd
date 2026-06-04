extends SceneTree

const ActiveItemRuntime := preload("res://scripts/items/active_item_runtime.gd")
const ActiveItemRuntimeUseFacade := preload("res://scripts/items/active_item_runtime_use_facade.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")

var _failures: Array[String] = []


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_pandora() -> void:
		calls.append("play_pandora")

	func play_active_item() -> void:
		calls.append("play_active_item")

	func play_throw_before() -> void:
		calls.append("play_throw_before")

	func play_throw() -> void:
		calls.append("play_throw")

	func stop_dynamite_fuse(_fuse_player: Variant) -> void:
		calls.append("stop_dynamite_fuse")

	func play_dynamite_explosion() -> void:
		calls.append("play_dynamite_explosion")


class FakeHudState:
	extends RefCounted

	var selected_index := -1

	func set_selected_index(index: int) -> void:
		selected_index = index


class FakeRoundState:
	extends RefCounted

	var waiting_for_serve := false

	func is_waiting_for_serve() -> bool:
		return waiting_for_serve


class FakeIntro:
	extends RefCounted

	var active := false

	func is_active() -> bool:
		return active


class FakeRegistry:
	extends RefCounted

	var audio := FakeAudio.new()
	var hud_state := FakeHudState.new()
	var round_state := FakeRoundState.new()
	var stage_landing_intro := FakeIntro.new()
	var stage_ball_spawn_intro := FakeIntro.new()

	func get_instance(key: String) -> Object:
		if key == "game_audio":
			return audio
		if key == "active_item_hud_state":
			return hud_state
		if key == "round_flow_state":
			return round_state
		if key == "stage_landing_intro":
			return stage_landing_intro
		if key == "stage_ball_spawn_intro":
			return stage_ball_spawn_intro
		return null


class FakeOwner:
	extends RefCounted

	var active_item_slots: Array = []
	var player_pos := Vector2(310.0, 690.0)
	var boss_pos := Vector2(330.0, 25.0)
	var special_gauge := 0.0
	var special_gauge_max := 500.0
	var ball_pos := Vector2(420.0, 710.0)
	var ball_vel := Vector2(1.0, 22.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0


class FakeUseFacade:
	extends RefCounted

	var use_calls := 0
	var recovery_calls := 0
	var defense_calls := 0
	var restore_calls := 0
	var dimension_calls := 0
	var apply_calls := 0
	var backup_calls := 0

	func use_slot(_runtime: Object, _slot_index: int, _owner: Object, _registry: Object) -> bool:
		use_calls += 1
		return true

	func try_smartphone_auto_recovery(_runtime: Object, _owner: Object, _registry: Object, _gauge_threshold: float = 120.0) -> String:
		recovery_calls += 1
		return "gauge_charge"

	func try_smartphone_auto_defense(_runtime: Object, _owner: Object, _registry: Object) -> String:
		defense_calls += 1
		return "holy_barrier"

	func restore_pending_throw_item_on_round_end(_runtime: Object, _owner: Object, _registry: Object) -> bool:
		restore_calls += 1
		return true

	func activate_dimension_gate(_runtime: Object, _registry: Object = null) -> bool:
		dimension_calls += 1
		return true

	func is_dimension_gate_active(_runtime: Object) -> bool:
		return true

	func apply_item_effect(_runtime: Object, _item_data: Dictionary, _owner: Object, _registry: Object) -> bool:
		apply_calls += 1
		return true

	func backup_pending_throw_item(
		_runtime: Object,
		_item_data: Dictionary,
		_slot_index: int,
		_owner: Object,
		_registry: Object
	) -> void:
		backup_calls += 1


func _init() -> void:
	_verify_use_facade_owns_pandora_slot_use()
	_verify_use_facade_routes_milk_bottle_slot_use()
	_verify_use_facade_accepts_item_id_only_slot()
	_verify_use_facade_blocks_serve_wait_slot_use()
	_verify_use_facade_blocks_intro_auto_use()
	_verify_use_facade_routes_pending_throw_backup()
	_verify_runtime_round_end_detonates_counting_dynamite()
	_verify_runtime_delegates_use_surface()

	if _failures.is_empty():
		print("active_item_runtime_use_facade_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_use_facade_owns_pandora_slot_use() -> void:
	var facade: Object = ActiveItemRuntimeUseFacade.new()
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.active_item_slots = [runtime.item_catalog.build_item_by_name("pandora_box")]

	_expect(facade.use_slot(runtime, 0, owner, registry), "use facade should use Pandora from an active slot")
	_expect(owner.active_item_slots.is_empty(), "Pandora use should consume the active slot")
	_expect(runtime.field_spawn_controller.is_dimension_gate_active(), "Pandora use should activate Dimension Gate")
	_expect(registry.audio.calls == ["play_pandora"], "Pandora use should play the Pandora audio cue")


func _verify_use_facade_routes_milk_bottle_slot_use() -> void:
	var facade: Object = ActiveItemRuntimeUseFacade.new()
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.active_item_slots = [runtime.item_catalog.build_item_by_name("milk_bottle")]

	_expect(facade.use_slot(runtime, 0, owner, registry), "use facade should route milk bottle from an active slot")
	_expect(owner.active_item_slots.is_empty(), "milk bottle slot use should consume the active item")
	_expect(runtime.effect_controller.is_milk_bottle_active(), "milk bottle slot use should activate the milk bottle effect")
	_expect(is_equal_approx(runtime.effect_controller.get_player_paddle_scale(), 1.20), "milk bottle slot use should report a 1.2 active item paddle scale")
	_expect(is_equal_approx(owner.player_paddle_width, 186.0), "milk bottle slot use should enlarge the owner paddle width by 20 percent")


func _verify_use_facade_accepts_item_id_only_slot() -> void:
	var facade: Object = ActiveItemRuntimeUseFacade.new()
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	owner.active_item_slots = [{
		"item_id": "gauge_charge",
		"consumable": true,
		"last_use_msec": -1,
	}]

	_expect(facade.use_slot(runtime, 0, owner, registry), "item_id-only active item slot should be usable")
	_expect(owner.active_item_slots.is_empty(), "item_id-only consumable active item should be consumed")
	_expect(owner.special_gauge > 0.0, "item_id-only gauge charge should apply its runtime effect")


func _verify_use_facade_blocks_serve_wait_slot_use() -> void:
	var facade: Object = ActiveItemRuntimeUseFacade.new()
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.round_state.waiting_for_serve = true
	owner.active_item_slots = [runtime.item_catalog.build_item_by_name("pandora_box")]

	_expect(not facade.use_slot(runtime, 0, owner, registry), "serve wait should block direct active item slot use")
	_expect(owner.active_item_slots.size() == 1, "serve wait should not consume the active item slot")
	_expect(not runtime.field_spawn_controller.is_dimension_gate_active(), "serve wait should not apply the item effect")
	_expect(registry.audio.calls.is_empty(), "serve wait should not play active item audio")


func _verify_use_facade_blocks_intro_auto_use() -> void:
	var facade: Object = ActiveItemRuntimeUseFacade.new()
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	registry.stage_ball_spawn_intro.active = true
	owner.active_item_slots = [runtime.item_catalog.build_item_by_name("gauge_charge")]

	_expect(facade.try_smartphone_auto_recovery(runtime, owner, registry) == "", "spawn intro should block smartphone active item auto-use")
	_expect(owner.active_item_slots.size() == 1, "spawn intro auto-use should not consume the active item slot")
	_expect(owner.special_gauge == 0.0, "spawn intro auto-use should not apply recovery effects")


func _verify_use_facade_routes_pending_throw_backup() -> void:
	var facade: Object = ActiveItemRuntimeUseFacade.new()
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var molotov: Dictionary = runtime.item_catalog.build_item_by_name("molotov")

	_expect(runtime.throw_controller.activate_molotov(owner, registry), "setup should create a Molotov windup")
	facade.backup_pending_throw_item(runtime, molotov, 0, owner, registry)
	_expect(runtime.pending_throw_recovery.has_pending_backup(), "use facade should delegate pending throwable backup")


func _verify_runtime_round_end_detonates_counting_dynamite() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var placed_dynamites: Array[Dictionary] = [{
		"position": Vector2(380.0, 75.0),
		"countdown_frames": runtime.throw_controller.DYNAMITE_COUNTDOWN_FRAMES * 0.5,
		"max_countdown_frames": runtime.throw_controller.DYNAMITE_COUNTDOWN_FRAMES,
		"pulse_timer": 0.0,
		"nudge_vx": 0.0,
		"wobble_angle": 0.0,
		"wobble_vel": 0.0,
		"fuse_player": "round-end-fuse-token",
	}]
	runtime.throw_controller.placed_dynamites = placed_dynamites

	_expect(runtime.restore_pending_throw_item_on_round_end(owner, registry), "runtime round-end hook should report counting dynamite resolution")
	_expect(runtime.throw_controller.get_placed_dynamites().is_empty(), "runtime round-end hook should clear counting dynamites")
	_expect(runtime.throw_controller.get_dynamite_explosions().size() == 1, "runtime round-end hook should create a dynamite explosion")
	_expect(registry.audio.calls == ["stop_dynamite_fuse", "play_dynamite_explosion"], "runtime round-end hook should use dynamite explosion audio path")
	_expect(bool(runtime.get_boss_ai_context().get("active_item_grenade_stun_active", false)), "round-end dynamite hit should still apply stun before round reset")

	BallRoundActorCleanup.new().reset_actor_round_state({
		"active_item_runtime": runtime,
	})

	_expect(not bool(runtime.get_boss_ai_context().get("active_item_grenade_stun_active", false)), "next round cleanup should clear round-end dynamite stun")
	_expect(not bool(runtime.get_boss_ai_context().get("active_item_grenade_knockback_active", false)), "next round cleanup should clear round-end dynamite knockback")


func _verify_runtime_delegates_use_surface() -> void:
	var runtime: Object = ActiveItemRuntime.new()
	_finish_runtime_initialization(runtime)
	var facade := FakeUseFacade.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	runtime.use_facade = facade

	_expect(runtime.use_slot(0, owner, registry), "runtime use_slot should delegate")
	_expect(runtime.try_smartphone_auto_recovery(owner, registry) == "gauge_charge", "runtime recovery should delegate")
	_expect(runtime.try_smartphone_auto_defense(owner, registry) == "holy_barrier", "runtime defense should delegate")
	_expect(runtime.restore_pending_throw_item_on_round_end(owner, registry), "runtime restore should delegate")
	_expect(runtime.activate_dimension_gate(registry), "runtime dimension activation should delegate")
	_expect(runtime.is_dimension_gate_active(), "runtime dimension active query should delegate")
	_expect(runtime._apply_item_effect({"name": "gauge_charge"}, owner, registry), "runtime item effect callback should delegate")
	runtime._backup_pending_throw_item({"name": "molotov"}, 0, owner, registry)

	_expect(facade.use_calls == 1, "runtime should call use facade once for slot use")
	_expect(facade.recovery_calls == 1, "runtime should call use facade once for recovery")
	_expect(facade.defense_calls == 1, "runtime should call use facade once for defense")
	_expect(facade.restore_calls == 1, "runtime should call use facade once for restore")
	_expect(facade.dimension_calls == 1, "runtime should call use facade once for dimension gate")
	_expect(facade.apply_calls == 1, "runtime should call use facade once for item effect callback")
	_expect(facade.backup_calls == 1, "runtime should call use facade once for backup callback")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish_runtime_initialization(runtime: Object) -> void:
	var guard := 0
	while runtime != null and runtime.has_method("prewarm_initialization_step") and not bool(runtime.prewarm_initialization_step()):
		guard += 1
		if guard > 64:
			_failures.append("active item runtime staged initialization did not finish")
			return
