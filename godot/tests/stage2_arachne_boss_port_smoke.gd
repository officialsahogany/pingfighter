extends SceneTree

const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const GameSelectionState := preload("res://scripts/core/game_selection_state.gd")
const GameplayModuleRegistry := preload("res://scripts/resources/gameplay_module_registry.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")


class FakeSelectionOwner:
	extends RefCounted
	var selection_state: Object
	var current_stage := 1
	var stage1_boss_variant := "dalji"
	var stage_boss_variant := ""
	var boss_paddle_width := 100.0
	var boss_hitbox_height := 40.0
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
	var net_count := 0
	var break_count := 0
	var strike_count := 0

	func play_commando_net_gun_capture() -> void:
		net_count += 1

	func play_spider_mine_setup() -> void:
		break_count += 1

	func play_stage3_tail() -> void:
		strike_count += 1


class FakeStatusEffectState:
	var slow_count := 0
	var last_multiplier := 1.0

	func apply_status(target: String, status_id: String, _frames: float, data: Dictionary = {}, _source: String = "") -> void:
		if target == "player" and status_id == "slow":
			slow_count += 1
			last_multiplier = float(data.get("multiplier", 1.0))


class FakeStageBackground:
	var starpoint_count := 0

	func spawn_starpoint_drop(_pos: Vector2, source_type: String = "", _deps: Dictionary = {}, _context: Dictionary = {}) -> void:
		if source_type == "golden_web":
			starpoint_count += 1


class FakeFeedback:
	var shake_count := 0

	func max_screen_shake(_duration: float, _amount: float) -> void:
		shake_count += 1


func _init() -> void:
	_verify_catalog_selection_and_size_route()
	_verify_arachne_skill_routes()
	print("stage2_arachne_boss_port_smoke: ok")
	quit(0)


func _verify_catalog_selection_and_size_route() -> void:
	_expect(StageBossVariantCatalog.normalize_variant(2, "arachne") == "arachne", "Arachne must register in the Stage 2 pool")
	_expect(StageBossVariantCatalog.normalize_variant(3, "arachne") == "yeonmyo", "Arachne must not cross into the Stage 3 pool")
	var selection_state: Object = GameSelectionState.new()
	selection_state.set_stage(2, "dalji", false, "arachne")
	var owner := FakeSelectionOwner.new(selection_state)
	BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
	_expect(owner.stage_boss_variant == "arachne", "selection startup must carry the Arachne variant")
	_expect(owner.boss_paddle_width == 130.0 and owner.boss_hitbox_height == 52.0, "Arachne must apply the original +30% paddle ratio to Godot's live base size")
	selection_state.set_stage(2, "dalji", false, "unknown")
	BattleSceneSelectionStartupLifecycle.new().apply_selection_state(owner)
	_expect(owner.stage_boss_variant == "cheongringwi" and owner.boss_paddle_width == 100.0, "unknown Stage 2 variants must preserve headline size and identity")
	owner.selection_state = null
	selection_state.free()


func _verify_arachne_skill_routes() -> void:
	var registry: Object = GameplayModuleRegistry.new()
	var state: Object = registry.get_instance("stage2_boss_skill_state")
	var audio := FakeAudio.new()
	var statuses := FakeStatusEffectState.new()
	var background := FakeStageBackground.new()
	var feedback := FakeFeedback.new()
	var deps := {
		"audio": audio,
		"status_effect_state": statuses,
		"stage_background": background,
		"feedback": feedback,
	}
	var context := {
		"current_stage": 2,
		"stage_boss_variant": "arachne",
		"ball_active": true,
		"waiting_for_serve": false,
		"ball_pos": Vector2(380.0, 300.0),
		"ball_vel": Vector2(2.0, -8.0),
		"ball_size": 28.6,
		"boss_pos": Vector2(315.0, 25.0),
		"boss_paddle_width": 130.0,
		"boss_hitbox_height": 52.0,
		"player_pos": Vector2(302.5, 700.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"dash_snapshot": {"active": false},
	}
	var size_result: Dictionary = state.update(0.0, context, deps)
	_expect(float(size_result.get("boss_paddle_width", 0.0)) == 130.0 and float(size_result.get("boss_hitbox_height", 0.0)) == 52.0, "production update must keep Arachne collision size on the owner result route")
	state.arachne_state.boss_special_gauge = 440.0
	var hit_result: Dictionary = state.register_boss_hit(Vector2(3.0, 8.0), context, deps)
	_expect(bool(hit_result.get("arachne_web_trap_triggered", false)), "boss contact must add 60 then trigger the 500-cost Web Trap")
	_expect(state.get_boss_special_gauge() <= 0.001 and audio.net_count == 1, "Web Trap must consume the full gauge and route the original net sound")
	for _index in range(12):
		state.update(0.05, context, deps)
	_expect(state.arachne_state.web_trap_projectile.is_empty() and state.arachne_state.web_traps.size() == 1, "Web Trap must land after the original 35-frame travel")
	var trap: Dictionary = state.arachne_state.web_traps[0]
	trap["expand"] = 0.0
	trap["golden"] = true
	state.arachne_state.web_traps[0] = trap
	var trap_pos: Vector2 = trap.get("pos", Vector2.ZERO)
	context["player_pos"] = trap_pos - Vector2(60.0, 25.0)
	state.update(0.05, context, deps)
	_expect(statuses.slow_count == 1 and statuses.last_multiplier == 0.40, "expanded web overlap must apply the original 0.40 player-speed multiplier")
	context["dash_snapshot"] = {"active": true}
	state.update(0.05, context, deps)
	_expect(state.arachne_state.web_traps.is_empty(), "dash overlap must destroy an expanded web")
	for _index in range(16):
		state.update(0.05, context, deps)
	_expect(background.starpoint_count == 1, "destroyed golden web must spawn a starpoint after 48 frames")

	state.arachne_state.web_trap_cooldown = 0.0
	state.arachne_state.boss_special_gauge = 50.0
	context["dash_snapshot"] = {"active": false}
	context["player_pos"] = Vector2(302.5, 700.0)
	context["ball_pos"] = Vector2(390.0, 20.0)
	context["ball_vel"] = Vector2(1.0, -9.0)
	var rescue_result: Dictionary = state.update(0.01, context, deps)
	_expect(bool(rescue_result.get("skip_ball_motion_step", false)) and state.arachne_state.web_rescue_phase == "shoot", "top-bound upward ball must enter Web Rescue and freeze motion")
	var moved_boss := false
	for _index in range(90):
		rescue_result = state.update(0.05, context, deps)
		if rescue_result.get("boss_pos", null) is Vector2:
			context["boss_pos"] = rescue_result["boss_pos"]
			moved_boss = true
		if not state.arachne_state.web_rescue_active:
			break
	_expect(moved_boss, "Web Rescue pull phase must move the live boss toward the caught ball")
	var released_vel := _as_vector2(rescue_result.get("ball_vel", Vector2.ZERO), Vector2.ZERO)
	_expect(not state.arachne_state.web_rescue_active and absf(released_vel.length() - 18.0) < 0.01 and released_vel.y > 0.0, "Web Rescue must release downward at fixed speed 18")
	_expect(audio.strike_count == 1, "Web Rescue strike must route paddle-impact audio once")

	state.handle_score_event("player", {"player_score": 4}, deps)
	state.reset_round()
	_expect(state.arachne_state.rage_active and state.arachne_state.rage_triggered, "four-point event must start Spider Rage on the following round")
	for _index in range(27):
		state.update(0.05, context, deps)
	_expect(state.arachne_state.rage_frame >= 80 and not state.arachne_state.rage_projectiles.is_empty(), "Spider Rage must launch its first red web at frame 80")
	for _index in range(40):
		state.update(0.05, context, deps)
	var rage_trap_count := 0
	for value in state.arachne_state.web_traps:
		if value is Dictionary and bool(value.get("rage", false)):
			rage_trap_count += 1
	_expect(rage_trap_count == 3 and not state.arachne_state.rage_active, "Spider Rage must land three persistent red webs and finish after frame 120")
	state.reset_round()
	_expect(state.arachne_state.rage_active, "triggered Spider Rage must repeat on subsequent rounds")
	_expect(feedback.shake_count > 0 and audio.break_count > 0, "Spider Rage must route stomp shake and spider-impact audio")

	# Smoke is a true negative/counter route: a web projectile dissolves before landing.
	state.reset()
	state.update(0.0, context, deps)
	state.arachne_state.boss_special_gauge = 500.0
	state.register_boss_hit(Vector2(2.0, 8.0), context, deps)
	var projectile_pos: Vector2 = state.arachne_state._get_projectile_pos(state.arachne_state.web_trap_projectile)
	context["smoke_zones"] = [{"position": projectile_pos, "radius": 120.0, "opacity": 1.0}]
	state.update(0.01, context, deps)
	_expect(state.arachne_state.web_trap_projectile.is_empty() and state.arachne_state.web_traps.is_empty(), "dense smoke must dissolve a web projectile before it becomes a trap")

	state = null
	registry.clear_all()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
