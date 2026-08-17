extends SceneTree

const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")
const AliceBossState := preload("res://scripts/stages/stage3/stage3_alice_boss_state.gd")
const Stage3BossVariantSkillState := preload("res://scripts/stages/stage3/stage3_boss_variant_skill_state.gd")
const BallUpdateContext := preload("res://scripts/ball/ball_update_context.gd")
const BallRoundActorCleanup := preload("res://scripts/ball/ball_round_actor_cleanup.gd")
const BattleSceneEffectsUpdateResultApplier := preload("res://scripts/core/battle_scene_effects_update_result_applier.gd")
const BattleSceneDrawer := preload("res://scripts/core/battle_scene_drawer.gd")

var failures: Array[String] = []


class FakeOwner:
	extends RefCounted
	var current_stage := 3
	var stage_boss_variant := "alice"
	var stage3_alice_mirror_active := false
	var stage3_alice_mirror_ratio := 0.0
	var ball_size := 28.6
	var ball_pos := Vector2(380.0, 400.0)
	var ball_vel := Vector2(5.0, 8.0)
	var ball_visual_type := "energy"
	var player_pos := Vector2(302.5, 680.0)
	var player_paddle_width := 155.0
	var boss_pos := Vector2(330.0, 25.0)
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
	var ai_mode := "champion"


class FakeMovementState:
	extends RefCounted
	var calls: Array = []

	func start_knockback(velocity: float, frames: float = 18.0, decay: float = 0.86, replace: bool = false, cleansable: bool = true) -> bool:
		calls.append({"velocity": velocity, "frames": frames, "decay": decay, "replace": replace, "cleansable": cleansable})
		return true


class FakeAudio:
	extends RefCounted
	var calls: Array[String] = []

	func play_stage3_dollcurse() -> void:
		calls.append("mirror")

	func play_lingpet_gravity_accel_cast() -> void:
		calls.append("size")

	func play_lingpet_dwarf_magic_cast() -> void:
		calls.append("rabbit_cast")

	func play_lingpet_dwarf_magic_hit() -> void:
		calls.append("rabbit_hit")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_and_proxy()
	_verify_mirror_contract_and_playfield_transform()
	_verify_dynamic_ball_size_consumers_and_restore()
	_verify_rabbit_lifecycle_smoke_dash_and_knockback()
	_verify_cleanup_hud_and_negative_route()
	if failures.is_empty():
		print("stage3_alice_boss_port_smoke: ok")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_catalog_and_proxy() -> void:
	_expect(StageBossVariantCatalog.normalize_variant(3, "alice") == "alice", "Alice must register as a Stage 3 variant")
	_expect(StageBossVariantCatalog.normalize_variant(2, "alice") == "cheongringwi", "Alice must fail closed outside Stage 3")
	_expect(StageBossVariantCatalog.normalize_variant(3, "unknown") == "yeonmyo", "unknown Stage 3 variants must preserve Yeonmyo")
	var proxy := Stage3BossVariantSkillState.new()
	var result := proxy.update(0.0, _context(), {})
	_expect(proxy.active_variant == "alice", "Stage 3 proxy must route Alice")
	_expect(result.get("stage3_alice_mirror_active", true) == false, "idle Alice route must project mirror-off state")
	var headline := _context()
	headline["stage_boss_variant"] = "yeonmyo"
	proxy.update(0.0, headline, {})
	_expect(proxy.active_variant == "yeonmyo", "Stage 3 headline route must remain intact")
	_expect(not proxy.is_curse_reverse_active(), "idle headline reverse state must remain false")


func _verify_mirror_contract_and_playfield_transform() -> void:
	var state := AliceBossState.new()
	var audio := FakeAudio.new()
	state.boss_special_gauge = 450.0
	var hit_result := state.register_boss_hit(Vector2.ZERO, _context(), {"audio": audio})
	_expect(bool(hit_result.get("alice_mirror_triggered", false)), "full gauge contact must auto-trigger mirror")
	_expect(is_equal_approx(state.boss_special_gauge, 0.0), "mirror must consume the full 500 gauge")
	_expect(not bool(hit_result.get("alice_size_shift_triggered", true)), "same contact must not trigger size after mirror consumes gauge")
	_expect(audio.calls.has("mirror"), "mirror must route its explicit Stage 3 fallback audio")
	state.update(0.25, _context(), {})
	_expect(state.mirror_active and float(state.get_actor_draw_context().get("stage3_alice_mirror_ratio", 0.0)) > 0.0, "mirror must expose its 30f fade window")
	var owner := FakeOwner.new()
	owner.stage3_alice_mirror_active = true
	var transform := BattleSceneDrawer.new()._resolve_playfield_transform({
		"width": 760.0,
		"render_scale": 1.5,
		"game_offset": Vector2(80.0, 0.0),
		"shake_offset": Vector2(2.0, 3.0),
		"context_owner": owner,
	})
	_expect(bool(transform.get("mirrored", false)), "real playfield transform must detect active Alice mirror")
	_expect(Vector2(transform.get("scale", Vector2.ZERO)).is_equal_approx(Vector2(-1.5, 1.5)), "mirror must flip only the playfield X scale")
	_expect(Vector2(transform.get("origin", Vector2.ZERO)).is_equal_approx(Vector2(1223.0, 4.5)), "mirrored transform must retain game offset and shake")
	for _index in range(60):
		state.update(0.05, _context(), {})
	_expect(not state.mirror_active, "mirror must expire after 180f")
	_expect(state.mirror_cooldown > 11.9, "180f duration must leave about 12s of the 900f cooldown")


func _verify_dynamic_ball_size_consumers_and_restore() -> void:
	var state := AliceBossState.new()
	var audio := FakeAudio.new()
	var context := _context()
	context["ball_size"] = 30.0
	state._activate_size_shift(context, {"audio": audio}, 2.0)
	var result := state.update(0.0, context, {})
	_expect(is_equal_approx(float(result.get("ball_size", 0.0)), 60.0), "large shift must double the live ball size")
	_expect(audio.calls.has("size"), "size shift must route gravityaccel audio")
	var owner := FakeOwner.new()
	BattleSceneEffectsUpdateResultApplier.new().apply_effects_result(owner, result)
	_expect(is_equal_approx(owner.ball_size, 60.0), "effects result must reach the production owner")
	var update_config := {"ball_size": 28.6, "ball_render_radius": 26.6175}
	BallUpdateContext.new()._apply_ball_owner_state(update_config, owner)
	_expect(is_equal_approx(float(update_config.get("ball_size", 0.0)), 60.0), "ball physics context must consume the owner size")
	_expect(is_equal_approx(float(update_config.get("ball_render_radius", 0.0)), 26.6175 * 60.0 / 28.6), "render radius must scale with collision size")
	var serve_config := BallUpdateContext.new().build_serve_config(owner)
	_expect(is_equal_approx(float(serve_config.get("ball_size", 0.0)), 60.0), "serve placement must consume the shifted size")
	for _index in range(81):
		result = state.update(0.05, context, {})
	_expect(not state.size_shift_active and is_equal_approx(float(result.get("ball_size", 0.0)), 30.0), "size shift must restore the exact pre-shift size after 240f")
	owner.ball_size = 60.0
	state.original_ball_size = 30.0
	state.size_shift_active = true
	var proxy := Stage3BossVariantSkillState.new()
	proxy.active_variant = "alice"
	proxy.alice_state = state
	BallRoundActorCleanup.new().reset_actor_round_state({
		"stage3_boss_skill_state": proxy,
		"owner": owner,
	})
	_expect(is_equal_approx(owner.ball_size, 30.0), "round cleanup must restore size before clearing Alice state")


func _verify_rabbit_lifecycle_smoke_dash_and_knockback() -> void:
	var state := AliceBossState.new()
	var audio := FakeAudio.new()
	var movement := FakeMovementState.new()
	var context := _context()
	state._activate_rabbits()
	for _index in range(11):
		state.update(0.05, context, {"audio": audio, "movement_state": movement})
	_expect(state.rabbit_projectiles.size() >= 3 and state.rabbit_projectiles.size() <= 4, "30f windup must launch 3..4 rabbits")
	_expect(audio.calls.has("rabbit_cast"), "rabbit launch must route smallboyshoot audio")
	var rabbit: Dictionary = state.rabbit_projectiles[0]
	rabbit["pos"] = _player_center(context)
	rabbit["vel"] = Vector2.ZERO
	state.rabbit_projectiles[0] = rabbit
	state.update(1.0 / 60.0, context, {"audio": audio, "movement_state": movement})
	_expect(not state.perched_rabbits.is_empty(), "rabbit-player contact must attach to the paddle for 120f")
	for _index in range(31):
		state.update(1.0 / 60.0, context, {"movement_state": movement})
	_expect(not movement.calls.is_empty(), "perched rabbit must apply its 30f knockback through player movement state")
	var before_smoke := state.rabbit_projectiles.size()
	if before_smoke > 0:
		var smoke_rabbit: Dictionary = state.rabbit_projectiles[0]
		var smoke_pos := Vector2(180.0, 240.0)
		smoke_rabbit["pos"] = smoke_pos
		state.rabbit_projectiles[0] = smoke_rabbit
		var smoke_context := context.duplicate(true)
		smoke_context["smoke_zones"] = [{"center": smoke_pos, "radius": 45.0, "opacity": 1.0}]
		state.update(1.0 / 60.0, smoke_context, {})
		_expect(state.rabbit_projectiles.size() == before_smoke - 1, "dense smoke must neutralize a flying rabbit")
	var perched_before_dash := state.perched_rabbits.size()
	var dash_context := context.duplicate(true)
	dash_context["dash_snapshot"] = {"active": true}
	state.update(1.0 / 60.0, dash_context, {"audio": audio})
	_expect(perched_before_dash > 0 and state.perched_rabbits.is_empty(), "active dash must instantly destroy perched rabbits")
	_expect(state.rabbit_burst_particles.size() == perched_before_dash * 10, "dash neutralization must spawn ten particles per rabbit")


func _verify_cleanup_hud_and_negative_route() -> void:
	var state := AliceBossState.new()
	state.boss_special_gauge = 275.0
	state.mirror_cooldown = 2.0
	state.rabbit_projectiles = [{"pos": Vector2.ONE}]
	state.rabbit_active = true
	var hud := state.get_hud_context()
	_expect(hud.get("stage3_boss_skill_hud_boss_name", "") == "엘리스", "HUD must use the registry-facing Korean boss name")
	_expect((hud.get("stage3_boss_skill_hud_skills", []) as Array).size() == 3, "Alice HUD must list all three skills")
	state.reset_round()
	_expect(is_equal_approx(state.boss_special_gauge, 275.0), "round cleanup must preserve Alice gauge")
	_expect(state.rabbit_projectiles.is_empty() and state.mirror_cooldown <= 0.0, "round cleanup must clear hazards and legacy cooldowns")
	var wrong_stage := _context()
	wrong_stage["current_stage"] = 2
	var before := state.boss_special_gauge
	_expect(state.register_boss_hit(Vector2.ZERO, wrong_stage, {}).is_empty(), "wrong-stage contact must fail closed")
	_expect(is_equal_approx(state.boss_special_gauge, before), "wrong-stage contact must not mutate Alice gauge")
	state.reset()
	_expect(is_equal_approx(state.boss_special_gauge, 0.0), "match reset must clear Alice gauge")


func _context() -> Dictionary:
	return {
		"current_stage": 3,
		"stage_boss_variant": "alice",
		"ball_active": true,
		"waiting_for_serve": false,
		"boss_pos": Vector2(330.0, 25.0),
		"boss_paddle_width": 100.0,
		"boss_hitbox_height": 40.0,
		"player_pos": Vector2(302.5, 680.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"ball_pos": Vector2(380.0, 400.0),
		"ball_vel": Vector2(5.0, 8.0),
		"ball_size": 28.6,
		"dash_snapshot": {"active": false},
	}


func _player_center(context: Dictionary) -> Vector2:
	return Vector2(context["player_pos"]) + Vector2(context["player_paddle_size"]) * 0.5


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
