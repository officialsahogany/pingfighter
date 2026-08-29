extends SceneTree

const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const GameAudio := preload("res://scripts/audio/game_audio.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const PaddleBounceFrameState := preload("res://scripts/ball/paddle_bounce_frame_state.gd")
const PaddleBouncePostHitHandler := preload("res://scripts/ball/paddle_bounce_post_hit_handler.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const Stage2BattleAudio := preload("res://scripts/audio/stage2_battle_audio.gd")

const SPINNING_CLAW_SOUND_PATH := "res://assets/sounds/clue.wav"
const SPINNING_CLAW_LINEAR_GAIN := 0.5


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


class FakeBallOwner:
	extends RefCounted
	var current_stage := 2
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := "molewang"
	var selected_character_type := "smasher"
	var ai_mode := "champion"
	var battle_textures := {}
	var ball_active := true
	var ball_pos := Vector2(380.0, 300.0)
	var ball_vel := Vector2(2.0, -8.0)
	var ball_size := 32.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_vel := 0.0
	var boss_paddle_width := 124.0
	var boss_hitbox_height := 40.0
	var player_pos := Vector2(302.5, 700.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge_max := 500.0


class FakeAudio:
	var claw_hits := 0
	var tunnel_cries := 0
	var spike_spawns := 0
	var tunnel_impacts := 0
	var friend_mole_spawns := 0
	var friend_mole_hits := 0

	func play_stage2_molewang_spinning_claw() -> void:
		claw_hits += 1

	func play_stage2_molewang_tunnel_start() -> void:
		tunnel_cries += 1

	func play_stage2_molewang_tunnel_spike() -> void:
		spike_spawns += 1

	func play_stage2_molewang_tunnel_impact() -> void:
		tunnel_impacts += 1

	func play_stage2_friend_mole_spawn() -> void:
		friend_mole_spawns += 1

	func play_stage2_friend_mole_hit() -> void:
		friend_mole_hits += 1


class SpyGameAudio:
	extends GameAudio
	var played_players: Array[AudioStreamPlayer] = []
	var played_pitches: Array[float] = []

	func _play_with_pitch(player: AudioStreamPlayer, pitch: float) -> bool:
		played_players.append(player)
		played_pitches.append(pitch)
		return player != null and player.stream != null


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
	var stage2_audio := Stage2BattleAudio.new()
	_expect(str(stage2_audio.get_spec("friend_mole_spawn").get("path", "")) == "res://assets/sounds/bonemake.wav", "friend-mole spawn must use the original existing bonemake asset")
	_expect(str(stage2_audio.get_spec("friend_mole_hit").get("path", "")) == "res://assets/sounds/smallboyhit.wav", "friend-mole hit must use the original existing smallboyhit asset")
	_expect(str(stage2_audio.get_spec("molewang_tunnel_spike").get("path", "")) == "res://assets/sounds/odinspirit.wav", "Tunnel Raid spikes must wire the original existing odinspirit asset")
	_expect(bool(stage2_audio.get_spec("molewang_tunnel_spike").get("source_parity", false)), "the odinspirit mapping must be recorded as source parity")
	_expect(str(stage2_audio.get_spec("molewang_tunnel_start").get("substitution_for", "")) == "lurker_attack.wav", "missing lurker_attack must retain an explicit approved substitution")
	_expect(str(stage2_audio.get_spec("molewang_tunnel_impact").get("substitution_for", "")) == "rocking.wav", "missing rocking must retain an explicit approved substitution")
	var spinning_claw_spec: Dictionary = stage2_audio.get_spec("molewang_spinning_claw")
	_expect(str(spinning_claw_spec.get("path", "")) == SPINNING_CLAW_SOUND_PATH, "Spinning Claw must use the original clue.wav asset")
	_expect(bool(spinning_claw_spec.get("source_parity", false)), "Spinning Claw clue.wav must be recorded as source parity")
	_expect(not spinning_claw_spec.has("substitution_for") and not spinning_claw_spec.has("approved_deviation"), "Spinning Claw must not retain the prior arbitrary substitute metadata")
	_expect(is_equal_approx(db_to_linear(float(spinning_claw_spec.get("gain_db", 0.0))), SPINNING_CLAW_LINEAR_GAIN), "Spinning Claw must preserve the original linear volume 0.5")
	_verify_spinning_claw_production_audio()
	_expect(bool(stage2_audio.get_spec("molewang_tunnel_start").get("approved_deviation", false)), "missing source cues must be marked as approved deviations")
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


func _verify_spinning_claw_production_audio() -> void:
	_expect(FileAccess.file_exists(SPINNING_CLAW_SOUND_PATH), "the promoted clue.wav asset must exist")
	var stream: AudioStream = load(SPINNING_CLAW_SOUND_PATH)
	_expect(stream != null, "the promoted clue.wav asset must load as an AudioStream")
	var player := AudioStreamPlayer.new()
	player.stream = stream
	var spy := SpyGameAudio.new()
	_expect(spy.has_method("play_stage2_molewang_spinning_claw"), "GameAudio must expose the duck-typed Spinning Claw method")
	spy.stage2_molewang_spinning_claw_sfx = player
	spy.play_stage2_molewang_spinning_claw()
	_expect(spy.played_players == [player], "the production Spinning Claw method must route the clue.wav player")
	_expect(spy.played_pitches.size() == 1 and spy.played_pitches[0] >= 0.97 and spy.played_pitches[0] <= 1.04, "the production Spinning Claw method must preserve its pitch policy")
	spy.stage2_molewang_spinning_claw_sfx = null
	spy = null
	player.free()


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
	var context: Dictionary = BallUpdateContext.new().build_update_context(FakeBallOwner.new())
	context["waiting_for_serve"] = false
	context["boss_y"] = 25.0
	_expect(is_equal_approx(float(context.get("boss_paddle_width", 0.0)), 124.0), "the production ball context must carry the nonzero live boss paddle width")
	_expect(is_equal_approx(float(context.get("ball_size", 0.0)), 32.0), "the production ball context must carry the nonzero live ball size")
	var deps := {
		"audio": audio,
		"movement_state": movement,
		"status_effect_state": status_effects,
		"stage_background": background,
		"stage2_boss_skill_state": state,
	}
	state.update(0.0, context, deps)
	state.molewang_state.tunnel_cooldown = 4.0
	state.molewang_state.spinning_claw_cooldown = 10.0
	var hud_skills: Array = state.get_hud_context().get("stage2_boss_skill_hud_skills", [])
	_expect(hud_skills.size() == 3, "Molewang HUD producer must publish all three skill cards")
	_expect(str(hud_skills[0].get("status", "")) == "charging" and not bool(hud_skills[0].get("ready", true)), "Tunnel Raid HUD card must expose charging and not-ready")
	_expect(is_equal_approx(float(hud_skills[0].get("progress", -1.0)), 0.5), "Tunnel Raid HUD progress must track its live cooldown")
	_expect(is_zero_approx(float(hud_skills[1].get("progress", -1.0))), "Spinning Claw HUD progress must remain empty while its activation gauge is empty")
	_expect(is_zero_approx(float(hud_skills[1].get("activation_gauge_progress", -1.0))), "Spinning Claw HUD must publish its gauge-starved activation progress")
	_expect(is_equal_approx(float(hud_skills[2].get("progress", -1.0)), 0.0), "inactive Friend Moles HUD progress must begin at zero")
	state.molewang_state.friend_moles_active = true
	hud_skills = state.get_hud_context().get("stage2_boss_skill_hud_skills", [])
	_expect(str(hud_skills[2].get("status", "")) == "casting" and is_equal_approx(float(hud_skills[2].get("progress", 0.0)), 1.0), "active Friend Moles HUD card must expose casting at full progress")
	state.reset()
	state.molewang_state.spinning_claw_cooldown = 0.0
	var post_hit_handler: Object = PaddleBouncePostHitHandler.new()
	post_hit_handler.event_router = FakeBounceEventRouter.new()
	context["ball_pos"] = Vector2(300.0, 60.0)
	var hit_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(5.0, 8.0), 0.15, context, deps)
	_expect(_as_vector2(hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(4.0, 6.4)), "Spinning Claw must return the exact x0.8 ball velocity through the production post-hit handler")
	_expect(is_equal_approx(float(hit_result.get("ball_spin_strength", 0.0)), 0.55), "Spinning Claw must return the original 0.55 spin strength through the production post-hit handler")
	var left_final_snapshot := _build_final_ball_snapshot(context, hit_result)
	_expect(int(left_final_snapshot.get("ball_spin_direction", 0)) == 1, "a ball left of the boss center must finish the production frame with spin direction +1")
	_expect(audio.claw_hits == 1, "Spinning Claw must route contact audio")
	_expect(state.get_boss_special_gauge() <= 0.001, "Spinning Claw must consume its 60-point hit gain")
	state.reset()
	state.molewang_state.spinning_claw_cooldown = 0.0
	context["ball_pos"] = Vector2(450.0, 60.0)
	var right_hit_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(-5.0, 8.0), 0.15, context, deps)
	_expect(_as_vector2(right_hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(-4.0, 6.4)), "right-side Spinning Claw must slow both velocity axes without changing their signs")
	var right_final_snapshot := _build_final_ball_snapshot(context, right_hit_result)
	_expect(int(right_final_snapshot.get("ball_spin_direction", 0)) == -1, "a ball right of the boss center must finish the production frame with spin direction -1")
	print("[MolewangParityR2] boss_paddle_width=%.1f ball_size=%.1f final_spin_left=%d final_spin_right=%d" % [
		float(context.get("boss_paddle_width", 0.0)),
		float(context.get("ball_size", 0.0)),
		int(left_final_snapshot.get("ball_spin_direction", 0)),
		int(right_final_snapshot.get("ball_spin_direction", 0)),
	])
	state.reset()
	context["stage_boss_variant"] = "arachne"
	var sibling_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(5.0, 8.0), 0.15, context, deps)
	_expect(_as_vector2(sibling_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(5.0, 8.0)), "non-Mole Stage 2 contacts must not inherit Spinning Claw slowdown")
	_expect(is_equal_approx(float(sibling_result.get("ball_spin_strength", 0.0)), 0.15), "non-Mole Stage 2 contacts must preserve their incoming spin strength")
	_expect(not sibling_result.has("ball_spin_direction"), "non-Mole Stage 2 contacts must not leak a Spinning Claw direction")
	for sibling_stage in [1, 3, 4]:
		state.reset()
		context["current_stage"] = sibling_stage
		context["stage_boss_variant"] = "molewang"
		var cross_stage_result: Dictionary = _apply_boss_post_hit(post_hit_handler, Vector2(5.0, 8.0), 0.15, context, deps)
		_expect(_as_vector2(cross_stage_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).is_equal_approx(Vector2(5.0, 8.0)), "Stage %d must preserve velocity through the shared boss post-hit handler" % sibling_stage)
		_expect(is_equal_approx(float(cross_stage_result.get("ball_spin_strength", 0.0)), 0.15), "Stage %d must preserve spin strength through the shared boss post-hit handler" % sibling_stage)
		_expect(not cross_stage_result.has("ball_spin_direction"), "Stage %d must not inherit Molewang spin direction" % sibling_stage)
	state.reset()
	context["current_stage"] = 2
	context["stage_boss_variant"] = "molewang"
	state.molewang_state.spinning_claw_timer = 0.0
	state.molewang_state.tunnel_cooldown = 0.0
	state.molewang_state.boss_special_gauge = 499.0
	var blocked_tunnel_result: Dictionary = state.update(0.0, context, deps)
	_expect(state.get_status() == "charging" and not state.molewang_state.tunnel_active, "Tunnel Raid must remain blocked below the unchanged 500 gauge gate")
	_expect(not blocked_tunnel_result.has("boss_pos") and audio.tunnel_cries == 0, "blocked Tunnel Raid must have no movement or audio side effect")
	state.molewang_state.boss_special_gauge = 500.0
	var tunnel_result: Dictionary = state.update(0.0, context, deps)
	_expect(state.get_status() == "tunnel_warn", "full gauge must activate Tunnel Raid through the per-frame scheduler")
	_expect(not tunnel_result.has("boss_pos"), "GRT-052: Tunnel Raid visual travel must not displace the live paddle collision owner")
	_expect(audio.tunnel_cries == 1, "Tunnel Raid activation must route boss audio")
	_expect(not bool(state.get_boss_ai_context().get("stage2_boss_movement_locked", true)), "GRT-053: Tunnel Raid must not invent a shared-AI movement lock absent from the original caller")
	var warning_context: Dictionary = context.duplicate()
	warning_context.merge(state.get_actor_draw_context(), true)
	var warning_geometry: Dictionary = actor_renderer.variant_boss_renderer.build_tunnel_warning_geometry(warning_context)
	_expect((warning_geometry.get("boss_exclamation_triangle", PackedVector2Array()) as PackedVector2Array).size() == 3, "Tunnel Raid warning must expose the boss exclamation geometry through the production variant renderer")
	var warning_cross: PackedVector2Array = warning_geometry.get("player_foot_cross_a", PackedVector2Array())
	_expect(warning_cross.size() == 2 and is_equal_approx((warning_cross[0].x + warning_cross[1].x) * 0.5, 380.0), "Tunnel Raid warning must center the X marker at the player's feet")
	context["player_pos"] = Vector2(80.0, 700.0)
	for _index in range(12):
		state.update(0.05, context, deps)
	_expect(is_equal_approx(state.molewang_state.tunnel_target_x, 157.5), "Tunnel Raid must retarget the live player center when the 30-frame warning ends")
	var post_warning_context: Dictionary = context.duplicate()
	post_warning_context.merge(state.get_actor_draw_context(), true)
	_expect(actor_renderer.variant_boss_renderer.build_tunnel_warning_geometry(post_warning_context).is_empty(), "warning markers must disappear after the warning phase")
	for _index in range(20):
		if state.molewang_state.tunnel_phase == "strike":
			break
		state.update(0.05, context, deps)
	_expect(state.molewang_state.tunnel_spikes.size() == 10, "Tunnel Raid must spawn exactly ten sequential spikes")
	_expect(audio.spike_spawns == 10, "Tunnel Raid must play the original odinspirit cue once per sequential spike")
	state.update(0.01, context, deps)
	_expect(movement.knockback_count == 1 and absf(movement.last_velocity) == 14.0, "locked-target close strike must apply the original 14-speed knockback")
	_expect(status_effects.stun_count == 1 and status_effects.last_frames == 60.0, "locked-target close strike must apply the original one-second stun")
	_expect(audio.tunnel_impacts == 1, "Tunnel Raid strike must route impact audio once")

	state.reset()
	context["waiting_for_serve"] = true
	context["ball_active"] = false
	state.handle_score_event("player", {"player_score": 3}, deps)
	BallRoundActorCleanup.new().reset_actor_round_state({"stage2_boss_skill_state": state})
	state.update(1.0, context, deps)
	_expect(not state.molewang_state.friend_moles_pending and not state.molewang_state.friend_moles_triggered and not state.molewang_state.friend_moles_active, "friend moles must remain locked below the unchanged exact four-point gate")
	state.handle_score_event("player", {"player_score": 4}, deps)
	BallRoundActorCleanup.new().reset_actor_round_state({"stage2_boss_skill_state": state})
	state.update(1.0, context, deps)
	_expect(state.molewang_state.friend_moles_triggered and not state.molewang_state.friend_moles_active, "the exact four-point unlock must remain pending through serve wait")
	_expect(state.molewang_state.friend_moles_duration_ticks_remaining == 0 and state.molewang_state.friend_moles_cooldown_ticks_remaining == 0, "serve wait must not advance or activate friend-mole physics timers")
	context["waiting_for_serve"] = false
	context["ball_active"] = true
	state.update(0.0, context, deps)
	_expect(state.molewang_state.friend_moles_active, "the first live physics tick after the exact four-point unlock must activate friend moles")
	_expect(state.molewang_state.friend_moles_duration_ticks_remaining == 720 and state.molewang_state.friend_moles_cooldown_ticks_remaining == 2880, "friend moles must start with exact 10-second and 40-second timers at 72 Hz")
	for _index in range(109):
		state.update(1.0 / 72.0, context, deps)
	_expect(state.molewang_state.friend_moles.size() == 1, "friend moles must spawn by the first 72 Hz tick after the original 90-frame interval")
	_expect(audio.friend_mole_spawns == 1, "friend-mole spawn must route the original bonemake cue")
	_expect(_count_particle_kind(state.molewang_state.friend_mole_particles, "dirt") == 8, "friend-mole spawn must emit the original eight dirt particles")
	var mole_pos: Vector2 = state.molewang_state.friend_moles[0].get("pos", Vector2.ZERO)
	for _index in range(15):
		state.update(1.0 / 72.0, context, deps)
	context["ball_pos"] = Vector2.ZERO
	context["tear_gas_zones"] = [{"position": mole_pos, "radius": 45.0, "radius_x": 60.0, "opacity": 0.8}]
	state.update(1.0 / 72.0, context, deps)
	_expect(str(state.molewang_state.friend_moles[0].get("phase", "")) == "falling", "an active tear-gas zone must send a rising or held friend mole immediately into falling")
	_expect(_count_particle_kind(state.molewang_state.friend_mole_particles, "smoke") == 6, "smoke dismissal must emit the original six grey puff particles")
	for _index in range(15):
		state.update(1.0 / 72.0, context, deps)
	_expect(state.molewang_state.friend_moles.is_empty(), "smoke-dismissed friend moles must leave after the 12-frame fall")
	context.erase("tear_gas_zones")
	state.molewang_state.friend_moles.append({"pos": mole_pos, "age": 0.2, "phase": "hold", "phase_age": 0.0, "golden": true, "hit": false})
	context["ball_pos"] = mole_pos
	context["ball_vel"] = Vector2(0.0, 8.0)
	var mole_hit_result: Dictionary = state.update(1.0 / 72.0, context, deps)
	_expect(_as_vector2(mole_hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y < 0.0, "friend-mole contact must reflect the ball")
	_expect(str(state.molewang_state.friend_moles[0].get("phase", "")) == "falling", "friend-mole contact must begin falling immediately instead of waiting out the hold")
	_expect(_count_particle_kind(state.molewang_state.friend_mole_particles, "hit") == 10, "friend-mole contact must emit ten hit particles")
	_expect(_count_particle_kind(state.molewang_state.friend_mole_particles, "star") == 6, "friend-mole contact must emit six star particles")
	_expect(audio.friend_mole_hits == 1, "friend-mole contact must route the original smallboyhit cue")
	_expect(background.starpoint_count == 1, "golden friend moles must emit a starpoint through the Stage 2 owner")
	var score_cleanup_cooldown: int = state.molewang_state.friend_moles_cooldown_ticks_remaining
	state.handle_score_event("boss", {"player_score": 4}, deps)
	_expect(not state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_duration_ticks_remaining == 0, "score events must end the active friend-mole window immediately")
	_expect(state.molewang_state.friend_moles.is_empty() and state.molewang_state.friend_mole_particles.is_empty(), "score cleanup must remove detached friend moles and particles")
	_expect(state.molewang_state.friend_moles_cooldown_ticks_remaining == score_cleanup_cooldown, "score cleanup must preserve the physics-tick cooldown")
	context["waiting_for_serve"] = true
	context["ball_active"] = false
	for _index in range(72):
		state.update(1.0 / 72.0, context, deps)
	_expect(state.molewang_state.friend_moles_cooldown_ticks_remaining == score_cleanup_cooldown, "serve wait must pause the friend-mole cooldown")
	state.molewang_state.spinning_claw_cooldown = 12.0
	state.reset_round()
	_expect(is_zero_approx(state.molewang_state.spinning_claw_cooldown), "round reset must make Spinning Claw available on the next round's first contact")
	_expect(not state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_cooldown_ticks_remaining == score_cleanup_cooldown, "round reset must clear active actors while preserving the unlocked cooldown")

	state.reset()
	context["waiting_for_serve"] = false
	context["ball_active"] = true
	context["ball_pos"] = Vector2.ZERO
	context["ball_vel"] = Vector2.ZERO
	state.handle_score_event("player", {"player_score": 4}, deps)
	state.reset_round()
	state.update(0.0, context, deps)
	_expect(state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_duration_ticks_remaining == 720 and state.molewang_state.friend_moles_cooldown_ticks_remaining == 2880, "canonical friend-mole timing must activate at 720/2880 ticks")
	for _index in range(719):
		state.update(0.0, context, deps)
	_expect(state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_duration_ticks_remaining == 1 and state.molewang_state.friend_moles_cooldown_ticks_remaining == 2161, "friend moles must remain active through physics tick 719")
	state.update(0.0, context, deps)
	_expect(not state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_duration_ticks_remaining == 0 and state.molewang_state.friend_moles_cooldown_ticks_remaining == 2160, "friend moles must end exactly after 720 live physics ticks")
	for _index in range(2159):
		state.update(0.0, context, deps)
	_expect(not state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_cooldown_ticks_remaining == 1, "friend moles must remain inactive before the 2880-tick cycle boundary")
	state.update(0.0, context, deps)
	_expect(state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_duration_ticks_remaining == 720 and state.molewang_state.friend_moles_cooldown_ticks_remaining == 2880, "friend moles must reactivate exactly 2880 live physics ticks after activation")
	state.reset_round()
	_expect(not state.molewang_state.friend_moles_active and state.molewang_state.friend_moles_cooldown_ticks_remaining == 2880 and state.molewang_state.friend_moles_triggered, "round reset must stop active friend moles without relocking or erasing cooldown")
	print("[MolewangParityR2] friend_duration_ticks=720 friend_cooldown_ticks=2880 score_cleanup=true serve_pause=true")
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


func _build_final_ball_snapshot(context: Dictionary, post_hit_result: Dictionary) -> Dictionary:
	var frame_state := PaddleBounceFrameState.new()
	var ball_vel := _as_vector2(post_hit_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	var frame: Dictionary = frame_state.build(context, null, ball_vel, ball_vel.length(), 0.0)
	frame_state.apply_post_hit_result(frame, post_hit_result)
	return frame_state.build_result_snapshot(
		frame,
		_as_vector2(post_hit_result.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO),
		ball_vel,
		float(post_hit_result.get("player_speed", context.get("player_speed", 0.0))),
		float(post_hit_result.get("boss_vel", context.get("boss_vel", 0.0)))
	)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback


func _count_particle_kind(particles: Array, kind: String) -> int:
	var count := 0
	for value in particles:
		if value is Dictionary and str(value.get("kind", "")) == kind:
			count += 1
	return count
