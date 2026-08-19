extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")


class FakeSelectionOwner:
	extends RefCounted
	var selection_state: Object
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var selected_character_id := ""
	var selected_runtime_character_id := ""
	var selected_character_type := ""
	var selected_character_name := ""
	var ai_mode := ""
	var chance_gems_count := 0
	var chance_gems_max := 3

	func _init(value: Object) -> void:
		selection_state = value

	func get_node_or_null(path: NodePath) -> Object:
		return selection_state if str(path) == "/root/GameSelectionState" else null


class FakeAudio:
	var claw_hits := 0
	var tunnel_cries := 0
	var spike_spawns := 0
	var tunnel_impacts := 0

	func play_stage2_speed_defense_hit() -> void:
		claw_hits += 1

	func play_stage2_boss_cry() -> void:
		tunnel_cries += 1

	func play_stage2_rock_spawn() -> void:
		spike_spawns += 1

	func play_stage2_stonebreak() -> void:
		tunnel_impacts += 1


class FakeMovementState:
	var knockback_count := 0
	var last_velocity := 0.0

	func start_knockback(velocity: float, _frames: float = 18.0, _decay: float = 0.92, _replace: bool = false) -> bool:
		knockback_count += 1
		last_velocity = velocity
		return true


class FakeStatusEffectState:
	var stun_count := 0
	var last_frames := 0.0

	func apply_status(target: String, status_id: String, frames: float, _data: Dictionary = {}, _source: String = "") -> void:
		if target == "player" and status_id == "stun":
			stun_count += 1
			last_frames = frames


class FakeStageBackground:
	var starpoint_count := 0

	func spawn_starpoint_drop(_pos: Vector2, source_type: String = "", _deps: Dictionary = {}, _context: Dictionary = {}) -> void:
		if source_type == "golden_mole":
			starpoint_count += 1


class FakeBounceEventRouter:
	func apply_drive_boss_counter(
		_ball_vel: Vector2,
		_ball_spin_strength: float,
		_drive_speed_increase: float,
		_drive_ball_active: bool,
		_drive_hit_boss: bool,
		_deps: Dictionary
	) -> Dictionary:
		return {}

	func trigger_boss_hit_anim(_boss_vel: float, _context: Dictionary, _deps: Dictionary) -> void:
		pass

	func register_rally_feedback(
		_ball_pos: Vector2,
		_ball_vel: Vector2,
		_is_player: bool,
		_power_activated: bool,
		_deps: Dictionary,
		_context: Dictionary = {},
		_special_gauge: float = -1.0,
		_drive_activated: bool = false
	) -> Dictionary:
		return {}


func _init() -> void:
	_verify_catalog_and_selection_route()
	_verify_molewang_production_state()
	print("stage2_molewang_boss_port_smoke: ok")
	quit(0)


func _verify_catalog_and_selection_route() -> void:
	_expect(StageBossVariantCatalog.normalize_variant(2, "molewang") == "molewang", "Molewang must register as a Stage 2 variant")
	_expect(StageBossVariantCatalog.normalize_variant(3, "molewang") == "yeonmyo", "Molewang must not cross into the Stage 3 pool")
	_expect(StageBossVariantCatalog.normalize_variant(2, "unknown") == "cheongringwi", "unknown Stage 2 variants must preserve the headline boss")
	var selection_state: Object = GameSelectionState.new()
	selection_state.set_stage(2, "dalji", false, "molewang")
	var owner := FakeSelectionOwner.new(selection_state)
	BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
	_expect(owner.current_stage == 2, "selection startup must carry the Stage 2 route")
	_expect(owner.stage_boss_variant == "molewang", "selection startup must carry the Molewang variant id")
	selection_state.set_stage(2, "dalji", false, "not_ported")
	BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
	_expect(owner.stage_boss_variant == "cheongringwi", "selection startup negative leg must fall back to Cheongringwi")
	owner.selection_state = null
	selection_state.free()


func _verify_molewang_production_state() -> void:
	var registry: Object = GameplayModuleRegistry.new()
	var state: Object = registry.get_instance("stage2_boss_skill_state")
	var actor_renderer: Object = registry.get_instance("stage2_actor_renderer")
	_expect(state != null and state.get_script().resource_path.ends_with("stage2_boss_variant_skill_state.gd"), "production module catalog must load the Stage 2 variant state")
	_expect(actor_renderer != null and actor_renderer.has_method("draw"), "production Stage 2 actor route must remain constructible")
	var audio := FakeAudio.new()
	var movement := FakeMovementState.new()
	var status_effects := FakeStatusEffectState.new()
	var background := FakeStageBackground.new()
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "molewang",
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 300.0),
		"ball_vel": Vector2(2.0, -8.0),
		"ball_size": 28.6,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_y": 25.0,
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
	}
	var deps := {
		"audio": audio,
		"movement_state": movement,
		"status_effect_state": status_effects,
		"stage_background": background,
		"stage2_boss_skill_state": state,
	}
	state.update(0.0, context, deps)
	var post_hit_handler: Object = PaddleBouncePostHitHandler.new()
	post_hit_handler.event_router = FakeBounceEventRouter.new()
	context["ball_pos"] = Vector2(300.0, 60.0)
	var hit_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(5.0, 8.0), 0.15, context, deps)
	_expect(_as_vector2(hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(4.0, 6.4)), "Spinning Claw must return the exact x0.8 ball velocity through the production post-hit handler")
	_expect(is_equal_approx(float(hit_result.get("ball_spin_strength", 0.0)), 0.55), "Spinning Claw must return the original 0.55 spin strength through the production post-hit handler")
	_expect(int(hit_result.get("ball_spin_direction", 0)) == 1, "a ball left of the boss center must curve right with spin direction +1")
	_expect(audio.claw_hits == 1, "Spinning Claw must route contact audio")
	_expect(state.get_boss_special_gauge() <= 0.001, "Spinning Claw must consume its 60-point hit gain")
	state.reset()
	context["ball_pos"] = Vector2(430.0, 60.0)
	var right_hit_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(-5.0, 8.0), 0.15, context, deps)
	_expect(_as_vector2(right_hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(-4.0, 6.4)), "right-side Spinning Claw must slow both velocity axes without changing their signs")
	_expect(int(right_hit_result.get("ball_spin_direction", 0)) == -1, "a ball right of the boss center must curve left with spin direction -1")
	state.reset()
	context["stage_boss_variant"] = "arachne"
	var sibling_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(5.0, 8.0), 0.15, context, deps)
	_expect(_as_vector2(sibling_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(5.0, 8.0)), "non-Mole Stage 2 contacts must not inherit Spinning Claw slowdown")
	_expect(is_equal_approx(float(sibling_result.get("ball_spin_strength", 0.0)), 0.15), "non-Mole Stage 2 contacts must preserve their incoming spin strength")
	_expect(not sibling_result.has("ball_spin_direction"), "non-Mole Stage 2 contacts must not leak a Spinning Claw direction")
	state.reset()
	context["stage_boss_variant"] = "molewang"
	state.molewang_state.spinning_claw_timer = 0.0
	state.molewang_state.boss_special_gauge = 500.0
	var tunnel_result: Dictionary = state.update(0.0, context, deps)
	_expect(state.get_status() == "tunnel_warn", "full gauge must activate Tunnel Raid through the per-frame scheduler")
	_expect(not tunnel_result.has("boss_pos"), "GRT-052: Tunnel Raid visual travel must not displace the live paddle collision owner")
	_expect(audio.tunnel_cries == 1, "Tunnel Raid activation must route boss audio")
	for _index in range(12):
		state.update(0.05, context, deps)
	for _index in range(20):
		if state.molewang_state.tunnel_phase == "strike":
			break
		state.update(0.05, context, deps)
	_expect(state.molewang_state.tunnel_spikes.size() == 10, "Tunnel Raid must spawn exactly ten sequential spikes")
	state.update(0.01, context, deps)
	_expect(movement.knockback_count == 1 and absf(movement.last_velocity) == 14.0, "locked-target close strike must apply the original 14-speed knockback")
	_expect(status_effects.stun_count == 1 and status_effects.last_frames == 60.0, "locked-target close strike must apply the original one-second stun")
	_expect(audio.tunnel_impacts == 1, "Tunnel Raid strike must route impact audio once")

	state.handle_score_event("player", {"player_score": 4}, deps)
	BallRoundActorCleanup.new().reset_actor_round_state({"stage2_boss_skill_state": state})
	_expect(state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_round_count == 1, "four-point event must begin on the following round")
	for _index in range(30):
		state.update(0.05, context, deps)
	_expect(state.molewang_state.friend_moles.size() == 1, "friend moles must use the original 90-frame spawn interval")
	var mole_pos: Vector2 = state.molewang_state.friend_moles[0].get("pos", Vector2.ZERO)
	for _index in range(4):
		state.update(0.05, context, deps)
	context["ball_pos"] = mole_pos
	context["ball_vel"] = Vector2(0.0, 8.0)
	var mole_hit_result: Dictionary = state.update(0.21, context, deps)
	_expect(_as_vector2(mole_hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y < 0.0, "friend-mole contact must reflect the ball")
	_expect(background.starpoint_count == 1, "golden friend moles must emit a starpoint through the Stage 2 owner")
	state.reset_round()
	_expect(state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_round_count == 2, "friend moles must remain active for the second round")
	state.reset_round()
	_expect(not state.molewang_state.friend_moles_active, "friend moles negative leg must end after two rounds")
	state = null
	actor_renderer = null
	registry.clear_all()


func _apply_boss_post_hit(
	handler: Object,
	ball_vel: Vector2,
	ball_spin_strength: float,
	context: Dictionary,
	deps: Dictionary
) -> Dictionary:
	return handler.apply(
		false,
		_as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO),
		ball_vel,
		0.0,
		float(context.get("boss_paddle_width", 100.0)),
		false,
		false,
		false,
		ball_spin_strength,
		0.0,
		false,
		false,
		0.0,
		context,
		deps
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
