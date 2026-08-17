extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const CheongringwiVisionChosikRenderer := preload(
	"res://scripts/characters/cheongringwi_vision_chosik_renderer.gd"
)
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const Stage2PillarAssets := preload("res://scripts/stages/stage2/stage2_pillar_assets.gd")
const Stage2QuakeCoordinator := preload("res://scripts/stages/stage2/stage2_quake_coordinator.gd")
const Stage2QuakeRockDropState := preload(
	"res://scripts/stages/stage2/stage2_quake_rock_drop_state.gd"
)
const Stage2QuakeRockOffsetState := preload(
	"res://scripts/stages/stage2/stage2_quake_rock_offset_state.gd"
)
const Stage2QuakeRuntimeState := preload(
	"res://scripts/stages/stage2/stage2_quake_runtime_state.gd"
)
const Stage2QuakeScreenShakeState := preload(
	"res://scripts/stages/stage2/stage2_quake_screen_shake_state.gd"
)
const Stage2RockFeedbackCoordinator := preload(
	"res://scripts/stages/stage2/stage2_rock_feedback_coordinator.gd"
)
const Stage2RockFragmentMotionState := preload(
	"res://scripts/stages/stage2/stage2_rock_fragment_motion_state.gd"
)
const Stage2RockVisualFactory := preload(
	"res://scripts/stages/stage2/stage2_rock_visual_factory.gd"
)
const Stage2WaterCannonPayloadFactory := preload(
	"res://scripts/stages/stage2/stage2_water_cannon_payload_factory.gd"
)
const Stage2WaterFragmentPlayerHitApplier := preload(
	"res://scripts/stages/stage2/stage2_water_fragment_player_hit_applier.gd"
)

# Compatibility IDs stay unchanged so existing unlock/equip data keeps working
# after the player-facing skill changed from a water torrent to an earth quake.
const SKILL_ID := CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_ID
const COST := CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COST
const BASE_COOLDOWN_SEC := CommonSkillCatalog.CHEONGRINGWI_VISION_DRAGON_TORRENT_COOLDOWN
const COMMAND_GAP_SEC := 0.45
const QUAKE_DURATION_SEC := Stage2QuakeCoordinator.DEFAULT_DURATION_SEC
const ROCK_MIN_COUNT := 3
const ROCK_MAX_COUNT := 5
const ROCK_DROP_BASE_SEC := 0.56
const ROCK_DROP_DELAY_SEC := 0.11
const ROCK_LAND_FLASH_SEC := 0.30
const ROCK_COLLISION_COOLDOWN_SEC := 0.18
const ROCK_MIN_RADIUS := 31.0
const ROCK_MAX_RADIUS := 43.0
const FIELD_SIDE_MARGIN := 74.0
const ROCK_TARGET_Y_MIN := 50.0
const ROCK_TARGET_Y_MAX := 700.0
const ROCK_START_Y_MIN := -300.0
const ROCK_START_Y_MAX := -100.0

var cooldown_remaining := 0.0
var cooldown_duration := BASE_COOLDOWN_SEC
var command_step := 0
var command_gap_remaining := 0.0
var phase := "idle"
var rocks: Array = []
var impacts: Array = []
var _last_left_pressed := false
var _last_right_pressed := false
var _rng := RandomNumberGenerator.new()
var _rock_visual_factory: Object = Stage2RockVisualFactory.new()
var _quake_runtime_state: Object = Stage2QuakeRuntimeState.new()
var _quake_motion_coordinator: Object = Stage2QuakeCoordinator.new()
var _rock_feedback_coordinator: Object = Stage2RockFeedbackCoordinator.new()
var _rock_fragment_state: Object = Stage2RockFragmentMotionState.new()
var _cached_audio: Object = null
var _rock_texture: Texture2D = null
var _rock_debris_texture: Texture2D = null
var _rock_asset_prewarm_done := false
var _rock_debris_asset_prewarm_done := false
var renderer: Object = CheongringwiVisionChosikRenderer.new()

var quake_timer: float:
	get:
		return float(_quake_runtime_state.timer) if _quake_runtime_state != null else 0.0
	set(value):
		if _quake_runtime_state != null:
			_quake_runtime_state.timer = maxf(0.0, value)


func _init() -> void:
	_rng.seed = 2207
	_quake_runtime_state.reset(QUAKE_DURATION_SEC, 0.0)
	_quake_runtime_state.seed_random_sources(2208, 2209)
	_quake_motion_coordinator.configure(
		_quake_runtime_state,
		null,
		null,
		null,
		null,
		null
	)


func update(
	delta: float,
	input_snapshot: Dictionary,
	modifier_pressed: bool,
	_player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	cooldown_remaining = maxf(0.0, cooldown_remaining - safe_delta)
	_update_effects(safe_delta, config, deps)
	if command_gap_remaining > 0.0:
		command_gap_remaining = maxf(0.0, command_gap_remaining - safe_delta)
		if command_gap_remaining <= 0.0:
			_reset_command()
	var left_pressed := bool(input_snapshot.get("left_pressed", false))
	var right_pressed := bool(input_snapshot.get("right_pressed", false))
	var left_edge := left_pressed and not _last_left_pressed
	var right_edge := right_pressed and not _last_right_pressed
	_last_left_pressed = left_pressed
	_last_right_pressed = right_pressed
	if not modifier_pressed:
		_reset_command()
		return {"activated": false, "movement_locked": false}
	if not _can_listen_for_command(config, deps):
		_reset_command()
		return {"activated": false, "movement_locked": false}
	if left_edge and right_edge:
		_reset_command()
		return {"activated": false, "movement_locked": false}
	var direction: int = -1 if left_edge else (1 if right_edge else 0)
	if direction == 0:
		return {"activated": false, "movement_locked": false}
	var expected: Array[int] = [-1, 1, -1]
	if direction != int(expected[command_step]):
		_reset_command()
		if direction == -1:
			command_step = 1
			command_gap_remaining = COMMAND_GAP_SEC
		return {"activated": false, "movement_locked": false}
	command_step += 1
	command_gap_remaining = COMMAND_GAP_SEC
	if command_step < expected.size():
		return {"activated": false, "movement_locked": false}
	_reset_command()
	return _activate(config, deps)


func apply_ball_motion(
	ball_pos: Vector2,
	ball_vel: Vector2,
	ball_size: float,
	boss_pos: Vector2,
	boss_width: float,
	boss_height: float,
	last_hit_by: String,
	motion_context: Dictionary = {},
	fps_scale: float = 1.0
) -> Dictionary:
	var scene := {
		"ball_pos": ball_pos,
		"ball_vel": ball_vel,
		"ball_impact_boost": float(motion_context.get("ball_impact_boost", 1.0)),
		"max_ball_speed": float(motion_context.get("max_ball_speed", Stage2QuakeCoordinator.BALL_EFFECTIVE_SPEED_CAP)),
		"impact_boost_max_ball_speed": float(motion_context.get("impact_boost_max_ball_speed", Stage2QuakeCoordinator.BALL_EFFECTIVE_SPEED_CAP)),
	}
	var quake_context: Dictionary = motion_context.duplicate()
	quake_context["boss_pos"] = boss_pos
	quake_context["boss_paddle_width"] = boss_width
	quake_context["boss_hitbox_height"] = boss_height
	var quake_motion_applied: bool = _quake_motion_coordinator.apply_active_ball_motion(
		scene,
		quake_context,
		fps_scale
	)
	ball_pos = _get_vector2(scene.get("ball_pos", ball_pos), ball_pos)
	ball_vel = _get_vector2(scene.get("ball_vel", ball_vel), ball_vel)
	if rocks.is_empty() or last_hit_by.strip_edges().to_lower() != "boss":
		return scene if quake_motion_applied else {}
	for rock_index in range(rocks.size()):
		var rock: Dictionary = rocks[rock_index] as Dictionary
		if bool(rock.get("falling", true)) or float(rock.get("drop_delay", 0.0)) > 0.0:
			continue
		if float(rock.get("collision_cooldown", 0.0)) > 0.0:
			continue
		var rock_pos := _get_vector2(rock.get("pos", Vector2.ZERO), Vector2.ZERO) \
			+ _get_vector2(rock.get("quake_offset", Vector2.ZERO), Vector2.ZERO)
		var collision_radius := maxf(1.0, float(rock.get("radius", ROCK_MIN_RADIUS))) + maxf(1.0, ball_size * 0.5)
		if ball_pos.distance_squared_to(rock_pos) > collision_radius * collision_radius:
			continue
		var boss_center := boss_pos + Vector2(maxf(1.0, boss_width) * 0.5, maxf(1.0, boss_height) * 0.5)
		var bossward := (boss_center - ball_pos).normalized()
		if bossward.length_squared() <= 0.0001:
			bossward = Vector2.UP
		bossward = bossward.rotated(_rng.randf_range(-0.16, 0.16)).normalized()
		# Yongso Torrent sprays the same debris cone downward at the player.
		# Vision Chosik mirrors that cone upward into the boss field.
		_rock_feedback_coordinator.emit_fragment_burst(
			rock,
			rock_pos,
			_rock_fragment_state,
			_rng,
			Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA.size(),
			Stage2RockFeedbackCoordinator.DEFAULT_MAX_ROCK_FRAGMENTS,
			Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_LIFE_SEC,
			{
				"fragment_min_count": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_MIN_COUNT,
				"fragment_max_count": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_MAX_COUNT,
				"fragment_gravity": -Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_GRAVITY,
				"fragment_bounce": 0.0,
				"fragment_can_hit_boss": true,
				"fragment_direction_axis": Vector2.UP,
				"fragment_directional_chance": 1.0,
				"fragment_direction_spread": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_CONE_HALF_ANGLE,
				"fragment_speed_min": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SPEED_MIN_PER_FRAME * 60.0,
				"fragment_speed_max": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SPEED_MAX_PER_FRAME * 60.0,
				"fragment_size_min": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SIZE_MIN,
				"fragment_size_max": Stage2WaterCannonPayloadFactory.DEFAULT_ROCK_FRAGMENT_SIZE_MAX,
				"fragment_spawn_spread": float(rock.get("radius", ROCK_MIN_RADIUS)) / 3.0,
			}
		)
		rocks.remove_at(rock_index)
		_append_impact(rock_pos, float(rock.get("radius", ROCK_MIN_RADIUS)) * 1.15)
		scene["ball_pos"] = ball_pos
		scene["ball_vel"] = bossward * maxf(0.001, ball_vel.length())
		scene["cheongringwi_vision_reflected"] = true
		scene["cheongringwi_vision_impact_pos"] = rock_pos
		scene["cheongringwi_vision_broken_rock"] = rock
		return scene
	return scene if quake_motion_applied else {}


func is_ready(special_gauge: float, equipped: bool = true) -> bool:
	return equipped and cooldown_remaining <= 0.0 and phase == "idle" and special_gauge >= COST


func is_movement_locked() -> bool:
	return false


func has_visible_effects() -> bool:
	return (
		phase != "idle"
		or not rocks.is_empty()
		or not impacts.is_empty()
		or not _rock_fragment_state.fragments.is_empty()
	)


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if renderer != null and has_visible_effects():
		renderer.draw(canvas, get_snapshot(), shake_offset)


func get_cooldown_ratio() -> float:
	return clampf(cooldown_remaining / maxf(0.001, cooldown_duration), 0.0, 1.0)


func get_snapshot() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"cooldown_ratio": get_cooldown_ratio(),
		"command_step": command_step,
		"phase": phase,
		"quake_timer": quake_timer,
		"quake_duration": QUAKE_DURATION_SEC,
		"rocks": rocks.duplicate(true),
		"impacts": impacts.duplicate(true),
		"rock_fragments": _rock_fragment_state.fragments.duplicate(true),
		"rock_texture": _rock_texture,
		"rock_source_regions": Stage2PillarAssets.ROCK_SOURCE_REGION_DATA,
		"rock_debris_texture": _rock_debris_texture,
		"rock_debris_source_regions": Stage2PillarAssets.ROCK_DEBRIS_SOURCE_REGION_DATA,
		"rock_fragment_life_sec": Stage2RockFeedbackCoordinator.DEFAULT_ROCK_FRAGMENT_LIFE_SEC,
		"width": 760.0,
		"height": 750.0,
	}


func reset_round() -> void:
	_stop_quake_audio()
	_reset_command()
	phase = "idle"
	_quake_runtime_state.clear_round_state()
	_last_left_pressed = false
	_last_right_pressed = false
	for rock_index in range(rocks.size()):
		var rock: Dictionary = rocks[rock_index] as Dictionary
		rock["quake_offset"] = Vector2.ZERO
		rock["flash"] = 0.0
		rock["collision_cooldown"] = 0.0
		rocks[rock_index] = rock
	impacts.clear()
	_rock_fragment_state.reset()


func reset_cooldowns() -> void:
	cooldown_remaining = 0.0


func reduce_all_cooldowns_by_fraction(reduction_fraction: float, _time_now: int = -1) -> int:
	var fraction := clampf(reduction_fraction, 0.0, 0.95)
	if fraction <= 0.0 or cooldown_remaining <= 0.0:
		return 0
	cooldown_remaining = maxf(0.0, cooldown_remaining - cooldown_duration * fraction)
	return 1


func advance_cooldowns_by_msec(bonus_msec: int, _time_now: int = -1) -> int:
	var bonus_seconds := float(maxi(0, bonus_msec)) / 1000.0
	if bonus_seconds <= 0.0 or cooldown_remaining <= 0.0:
		return 0
	cooldown_remaining = maxf(0.0, cooldown_remaining - bonus_seconds)
	return 1


func reset() -> void:
	reset_round()
	rocks.clear()
	cooldown_remaining = 0.0
	cooldown_duration = BASE_COOLDOWN_SEC


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _rock_asset_prewarm_done and _rock_debris_asset_prewarm_done:
		return true
	if not _rock_asset_prewarm_done:
		if _rock_texture != null:
			_rock_asset_prewarm_done = true
		else:
			var rock_result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
				Stage2PillarAssets.ROCK_TEXTURE_PATH
			)
			if not bool(rock_result.get("done", true)):
				return false
			_rock_texture = rock_result.get("texture", null) as Texture2D
			_rock_asset_prewarm_done = true
		return false
	if _rock_debris_texture != null:
		_rock_debris_asset_prewarm_done = true
		return true
	var debris_result: Dictionary = ProjectResourceLoader.prewarm_texture_threaded_step(
		Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH
	)
	if not bool(debris_result.get("done", true)):
		return false
	_rock_debris_texture = debris_result.get("texture", null) as Texture2D
	_rock_debris_asset_prewarm_done = true
	return true


func _activate(config: Dictionary, deps: Dictionary) -> Dictionary:
	phase = "quake"
	_quake_motion_coordinator.activate(QUAKE_DURATION_SEC, 0, false, false)
	_ensure_rock_textures()
	rocks = _build_rocks(config)
	impacts.clear()
	var cooldown := BASE_COOLDOWN_SEC
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config != null and skill_config.has_method("get_cooldown_seconds"):
		cooldown = maxf(0.0, float(skill_config.get_cooldown_seconds(SKILL_ID)))
	cooldown_remaining = cooldown
	cooldown_duration = maxf(0.001, cooldown)
	var next_gauge := maxf(0.0, float(config.get("special_gauge", 0.0)) - COST)
	var owner: Object = deps.get("owner", null)
	if owner != null:
		owner.set("special_gauge", next_gauge)
	var audio: Object = deps.get("audio", null)
	if audio != null:
		_cached_audio = audio
	Stage2AudioRouter.play_rock_spawn(deps)
	_quake_runtime_state.audio_active = Stage2AudioRouter.play_quake_loop(
		deps,
		_cached_audio,
		bool(_quake_runtime_state.audio_active)
	)
	return {"activated": true, "movement_locked": false, "special_gauge": next_gauge}


func _update_effects(delta: float, config: Dictionary, deps: Dictionary) -> void:
	_advance_impacts(delta)
	_rock_fragment_state.advance(delta, 700.0)
	_resolve_fragment_boss_hits(config, deps)
	if phase == "idle" and rocks.is_empty():
		return
	_quake_runtime_state.advance_timing(delta, false)
	_quake_runtime_state.audio_active = Stage2AudioRouter.sync_quake_loop(
		quake_timer,
		bool(_quake_runtime_state.audio_active),
		deps,
		_cached_audio
	)
	for rock_index in range(rocks.size() - 1, -1, -1):
		var rock: Dictionary = rocks[rock_index] as Dictionary
		rock["collision_cooldown"] = maxf(0.0, float(rock.get("collision_cooldown", 0.0)) - delta)
		rock["flash"] = maxf(0.0, float(rock.get("flash", 0.0)) - delta)
		var target_pos := _get_vector2(rock.get("target_pos", rock.get("pos", Vector2.ZERO)), Vector2.ZERO)
		var was_falling := bool(rock.get("falling", false))
		var drop_result := Stage2QuakeRockDropState.update_drop(
			rock,
			delta,
			target_pos,
			ROCK_LAND_FLASH_SEC,
			ROCK_DROP_BASE_SEC
		)
		if bool(drop_result.get("landed", false)):
			rock["shadow_scale"] = 1.0
		if bool(rock.get("falling", false)):
			rock["shadow_scale"] = 0.20 + 0.80 * clampf(float(rock.get("fall_progress", 0.0)), 0.0, 1.0)
		elif not was_falling or bool(drop_result.get("landed", false)):
			rock["shadow_scale"] = 1.0
		Stage2QuakeRockOffsetState.update_offset(
			rock,
			delta,
			quake_timer,
			QUAKE_DURATION_SEC
		)
		rocks[rock_index] = rock
	if rocks.is_empty() and quake_timer <= 0.0:
		phase = "idle"


func _resolve_fragment_boss_hits(config: Dictionary, deps: Dictionary) -> int:
	var fragments: Array = _rock_fragment_state.fragments as Array
	if fragments.is_empty():
		return 0
	var ai_state: Object = deps.get("ai_state", null)
	if ai_state == null or not ai_state.has_method("start_paddle_hit_knockback"):
		return 0
	var boss_pos := _get_vector2(config.get("boss_pos", Vector2.ZERO), Vector2.ZERO)
	var boss_size := Vector2(
		maxf(1.0, float(config.get("boss_paddle_width", 100.0))),
		maxf(1.0, float(config.get("boss_hitbox_height", 40.0)))
	)
	var boss_rect := Rect2(boss_pos, boss_size)
	var boss_center := boss_rect.get_center()
	var hit_count := 0
	for fragment_index in range(fragments.size() - 1, -1, -1):
		var fragment: Dictionary = fragments[fragment_index] as Dictionary
		if not bool(fragment.get("can_hit_boss", false)):
			continue
		var fragment_pos := _get_vector2(fragment.get("pos", Vector2.ZERO), Vector2.ZERO)
		var fragment_radius := maxf(3.0, float(fragment.get("size", 8.0)) * 0.5)
		if not _circle_overlaps_rect(fragment_pos, fragment_radius, boss_rect):
			continue
		var fragment_velocity := _get_vector2(fragment.get("vel", Vector2.ZERO), Vector2.ZERO)
		fragments.remove_at(fragment_index)
		hit_count += 1
		_append_impact(fragment_pos, float(fragment.get("size", 8.0)) * 1.15)
		var feedback: Object = deps.get("feedback", null)
		if feedback != null and feedback.has_method("max_screen_shake"):
			feedback.max_screen_shake(
				Stage2WaterFragmentPlayerHitApplier.SHAKE_DURATION_SEC,
				Stage2WaterFragmentPlayerHitApplier.SHAKE_STRENGTH
			)
		var impact_effects: Object = deps.get("impact_effects", null)
		if impact_effects != null and impact_effects.has_method("spawn_hit_particles"):
			impact_effects.spawn_hit_particles(
				fragment_pos,
				Stage2WaterFragmentPlayerHitApplier.IMPACT_COLOR,
				fragment_velocity,
				Stage2WaterFragmentPlayerHitApplier.IMPACT_SCALE,
				fragment_velocity.length()
			)
		Stage2AudioRouter.play_rock_hit(deps)
		var direction := 1.0 if fragment_velocity.x >= 0.0 else -1.0
		if absf(fragment_velocity.x) <= 0.01:
			direction = 1.0 if fragment_pos.x >= boss_center.x else -1.0
		ai_state.start_paddle_hit_knockback(
			direction * Stage2WaterFragmentPlayerHitApplier.KNOCKBACK_SPEED,
			Stage2WaterFragmentPlayerHitApplier.KNOCKBACK_FRAMES,
			Stage2WaterFragmentPlayerHitApplier.KNOCKBACK_DECAY,
			true
		)
	return hit_count


func _circle_overlaps_rect(center: Vector2, radius: float, rect: Rect2) -> bool:
	var closest := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)
	return center.distance_squared_to(closest) <= radius * radius


func publish_screen_shake(feedback: Object) -> bool:
	if quake_timer <= 0.0 or feedback == null:
		return false
	if feedback.has_method("push_fixed_shake_offset"):
		feedback.push_fixed_shake_offset(Stage2QuakeScreenShakeState.get_offset(
			quake_timer,
			QUAKE_DURATION_SEC,
			_quake_runtime_state.motion_rng as RandomNumberGenerator
		))
		return true
	if feedback.has_method("max_screen_shake"):
		var ratio := quake_timer / maxf(0.001, QUAKE_DURATION_SEC)
		feedback.max_screen_shake(0.040 + ratio * 0.025, 1.6 + ratio * 1.2)
		return true
	return false


func publish_rock_break_feedback(rock: Dictionary, deps: Dictionary) -> void:
	Stage2AudioRouter.play_rock_break(rock, deps)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(
			Stage2RockFeedbackCoordinator.HIT_SHAKE_DURATION_SEC,
			Stage2RockFeedbackCoordinator.HIT_SHAKE_STRENGTH
		)


func _ensure_rock_textures() -> void:
	if _rock_texture == null:
		_rock_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_TEXTURE_PATH)
	if _rock_debris_texture == null:
		_rock_debris_texture = ProjectResourceLoader.load_texture(Stage2PillarAssets.ROCK_DEBRIS_TEXTURE_PATH)
	_rock_asset_prewarm_done = true
	_rock_debris_asset_prewarm_done = true


func _stop_quake_audio() -> void:
	Stage2AudioRouter.stop_quake_loop({}, _cached_audio)
	_cached_audio = null


func _build_rocks(config: Dictionary) -> Array:
	var width := maxf(1.0, float(config.get("width", 760.0)))
	var height := maxf(1.0, float(config.get("height", 750.0)))
	var min_x := minf(FIELD_SIDE_MARGIN, width * 0.25)
	var max_x := maxf(min_x, width - min_x)
	var min_y := clampf(ROCK_TARGET_Y_MIN, 0.0, height)
	var max_y := clampf(ROCK_TARGET_Y_MAX, min_y, height)
	var rock_count := _rng.randi_range(ROCK_MIN_COUNT, ROCK_MAX_COUNT)
	var lane_width := (max_x - min_x) / float(rock_count)
	var result: Array = []
	for rock_index in range(rock_count):
		var seed_value := 22070 + rock_index * 137
		var target_x := min_x + lane_width * (float(rock_index) + 0.5) + _rng.randf_range(-lane_width * 0.24, lane_width * 0.24)
		var target_y := float(_rng.randi_range(int(round(min_y)), int(round(max_y))))
		var target_pos := Vector2(clampf(target_x, min_x, max_x), clampf(target_y, min_y, max_y))
		var radius := _rng.randf_range(ROCK_MIN_RADIUS, ROCK_MAX_RADIUS)
		var start_pos := Vector2(
			target_pos.x + _rng.randf_range(-28.0, 28.0),
			float(_rng.randi_range(int(ROCK_START_Y_MIN), int(ROCK_START_Y_MAX)))
		)
		var fall_total := ROCK_DROP_BASE_SEC + _rng.randf_range(-0.06, 0.08)
		var rock := {
			"pos": start_pos,
			"start_pos": start_pos,
			"target_pos": target_pos,
			"drop_delay": float(rock_index) * ROCK_DROP_DELAY_SEC,
			"fall_timer": fall_total,
			"fall_total": fall_total,
			"falling": true,
			"fall_progress": 0.0,
			"collision_cooldown": 0.0,
			"flash": 0.0,
			"shadow_scale": 0.20,
			"quake_offset": Vector2.ZERO,
			"radius": radius * 0.80,
			"base_visual_radius": radius,
		}
		var visual_data: Dictionary = _rock_visual_factory.build_visual_data(radius, false, seed_value, _rng)
		rock.merge(visual_data, true)
		rock["phase"] = float(seed_value % 628) / 100.0
		# build_visual_data publishes visual_radius; keep an immutable radius for fading.
		rock["base_visual_radius"] = radius
		result.append(rock)
	return result


func _append_impact(pos: Vector2, radius: float) -> void:
	impacts.append({
		"pos": pos,
		"radius": radius,
		"life": 0.34,
		"max_life": 0.34,
	})
	if impacts.size() > 12:
		impacts.pop_front()


func _advance_impacts(delta: float) -> void:
	for impact_index in range(impacts.size() - 1, -1, -1):
		var impact: Dictionary = impacts[impact_index] as Dictionary
		impact["life"] = maxf(0.0, float(impact.get("life", 0.0)) - delta)
		if float(impact.get("life", 0.0)) <= 0.0:
			impacts.remove_at(impact_index)
		else:
			impacts[impact_index] = impact


func _can_listen_for_command(config: Dictionary, deps: Dictionary) -> bool:
	if phase != "idle" or cooldown_remaining > 0.0:
		return false
	if not bool(config.get("ball_active", false)) or bool(config.get("player_skill_input_locked", false)):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config == null or not skill_config.has_method("is_skill_equipped"):
		return false
	if not bool(skill_config.is_skill_equipped(SKILL_ID)):
		return false
	return float(config.get("special_gauge", 0.0)) >= COST


func _reset_command() -> void:
	command_step = 0
	command_gap_remaining = 0.0


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
