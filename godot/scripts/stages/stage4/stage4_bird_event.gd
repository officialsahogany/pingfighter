extends RefCounted

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const BattleRenderQuality := preload("res://scripts/core/battle_render_quality.gd")
const CommonStarpointVisualHost := preload("res://scripts/effects/common_starpoint_visual_host.gd")
const LingpetStarlightTrackingBridge := preload("res://scripts/stages/common/lingpet_starlight_tracking_bridge.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")
const StarpointCollectionCompaction := preload("res://scripts/stages/common/starpoint_collection_compaction.gd")
const StarpointCollectionRewardPolicy := preload("res://scripts/stages/common/starpoint_collection_reward_policy.gd")
const StarpointDropMotionState := preload("res://scripts/stages/common/starpoint_drop_motion_state.gd")
const StarpointDropOverlapQuery := preload("res://scripts/stages/common/starpoint_drop_overlap_query.gd")
const StarpointParticleState := preload("res://scripts/stages/common/starpoint_particle_state.gd")
const StarpointPayloadFactory := preload("res://scripts/stages/common/starpoint_payload_factory.gd")
const StageActorDrawContextArrays := preload("res://scripts/stages/common/stage_actor_draw_context_arrays.gd")
const StagePlayerInteractionRects := preload("res://scripts/stages/common/stage_player_interaction_rects.gd")
const StagePlayfieldBounds := preload("res://scripts/stages/common/stage_playfield_bounds.gd")
const Stage4BirdPayloadFactory := preload("res://scripts/stages/stage4/stage4_bird_payload_factory.gd")

const WIDTH := 760.0
const HEIGHT := 750.0
const STAR_BIRD_SHEET_PATH := "res://assets/sprites/hud/stage4_star_bird_flight_sheet_imagegen_v1.png"
const STAR_BIRD_FRAME_COUNT := 4
const MAX_ACTIVE_BIRDS := 3
const SPAWN_MIN_SEC := 12.0
const SPAWN_MAX_SEC := 23.0
const GOLD_DUST_MAX := 84
const STARPOINT_DROP_SIZE := 12.0
const STARPOINT_DROP_LIFETIME := 600.0
const STARPOINT_DROP_ACCELERATION := 0.25
const STARPOINT_DROP_MAX_FALL_SPEED := 12.0
const STARPOINT_DROP_BOUNCE_DAMPING := 0.7
const STARPOINT_PARTICLE_COUNT := 20
const STARPOINT_PARTICLE_LIFE := 60.0
const STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES := [-36.0, -24.0, 24.0, 36.0]
const MAX_STAGE4_STARPOINT_DROPS := 12
const MAX_STAGE4_STARPOINT_PARTICLES := 96
const GOLD_DUST_RENDER_LIMIT := 36
const GOLD_DUST_RENDER_LIMIT_LOD := 18
const CROW_FRAGMENT_RENDER_LIMIT := 24
const CROW_FRAGMENT_RENDER_LIMIT_LOD := 12
const CROW_PARTICLE_RENDER_LIMIT := 32
const CROW_PARTICLE_RENDER_LIMIT_LOD := 16
const STARPOINT_PARTICLE_RENDER_LIMIT := 48
const STARPOINT_PARTICLE_RENDER_LIMIT_LOD := 24

var rng := RandomNumberGenerator.new()
var star_bird_sheet: Texture2D = null
var textures_loaded := false
var crows: Array = []
var crow_fragments: Array = []
var crow_particles: Array = []
var starpoint_drops: Array = []
var starpoint_particles: Array = []
var spawn_timer := 0.0
var spawn_interval := SPAWN_MIN_SEC
var time_sec := 0.0


func _init() -> void:
	rng.randomize()
	spawn_interval = rng.randf_range(SPAWN_MIN_SEC, SPAWN_MAX_SEC)


func prewarm_assets() -> void:
	_ensure_textures()


func reset() -> void:
	crows.clear()
	crow_fragments.clear()
	crow_particles.clear()
	var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
	starpoint_drops.clear()
	starpoint_particles.clear()
	if had_starpoints:
		CommonStarpointVisualHost.hide_all_existing_hosts()
	spawn_timer = 0.0
	spawn_interval = rng.randf_range(SPAWN_MIN_SEC, SPAWN_MAX_SEC)
	time_sec = 0.0


func update(delta: float, context: Dictionary = {}, deps: Dictionary = {}) -> Dictionary:
	if int(context.get("current_stage", 4)) != 4:
		# Drop mid-flight starpoints when the player leaves Stage 4 so they
		# don't reappear frozen at their last position when the player returns.
		var had_starpoints := not starpoint_drops.is_empty() or not starpoint_particles.is_empty()
		if not starpoint_drops.is_empty():
			starpoint_drops.clear()
		if not starpoint_particles.is_empty():
			starpoint_particles.clear()
		if had_starpoints:
			CommonStarpointVisualHost.hide_all_existing_hosts()
		return {}
	var clamped_delta: float = clampf(delta, 0.0, 0.1)
	var fps_scale: float = clamped_delta * 60.0
	time_sec += clamped_delta
	_update_crows(fps_scale)
	_update_fragments(fps_scale)
	_update_particles(fps_scale)
	_update_starpoint_drops(fps_scale, context, deps)
	_update_starpoint_particles(fps_scale)
	spawn_timer += clamped_delta
	if spawn_timer >= spawn_interval:
		force_spawn_bird()
		spawn_timer = 0.0
		spawn_interval = rng.randf_range(SPAWN_MIN_SEC, SPAWN_MAX_SEC)
	return {}


func draw(canvas: CanvasItem, context: Dictionary = {}, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null:
		return
	_ensure_textures()
	var quality_scale: float = _get_render_quality_scale(context)
	var fragment_render_limit: int = _get_lod_count(CROW_FRAGMENT_RENDER_LIMIT, CROW_FRAGMENT_RENDER_LIMIT_LOD, quality_scale)
	var particle_render_limit: int = _get_lod_count(CROW_PARTICLE_RENDER_LIMIT, CROW_PARTICLE_RENDER_LIMIT_LOD, quality_scale)
	var birds: Array = _as_array(context.get("stage4_star_birds", crows))
	for bird_value in birds:
		if bird_value is Dictionary:
			_draw_gold_dust(canvas, bird_value as Dictionary, shake_offset, quality_scale)
	var fragments: Array = _as_array(context.get("stage4_star_bird_fragments", crow_fragments))
	for fragment_index in range(_recent_start(fragments, fragment_render_limit), fragments.size()):
		var fragment_value: Variant = fragments[fragment_index]
		if fragment_value is Dictionary:
			_draw_fragment(canvas, fragment_value as Dictionary, shake_offset)
	var particles: Array = _as_array(context.get("stage4_star_bird_particles", crow_particles))
	for particle_index in range(_recent_start(particles, particle_render_limit), particles.size()):
		var particle_value: Variant = particles[particle_index]
		if particle_value is Dictionary:
			_draw_particle(canvas, particle_value as Dictionary, shake_offset)
	_draw_starpoint_particles(canvas, context, shake_offset, quality_scale)
	_draw_starpoint_drops(canvas, context, shake_offset)
	for bird_value in birds:
		if bird_value is Dictionary:
			_draw_bird(canvas, bird_value as Dictionary, shake_offset)


func force_spawn_bird(side: String = "") -> bool:
	return _spawn_crow(side)


func get_crow_positions() -> Array:
	var result: Array = []
	for idx in range(crows.size()):
		var crow_value: Variant = crows[idx]
		if not (crow_value is Dictionary):
			continue
		var crow: Dictionary = crow_value
		if bool(crow.get("caught", false)):
			continue
		result.append({
			"x": float(crow.get("x", 0.0)),
			"y": float(crow.get("y", 0.0)),
			"radius": float(crow.get("hitbox_radius", 25.0)),
			"index": idx,
		})
	return result


func get_bird_positions() -> Array:
	return get_crow_positions()


func catch_crow(index: int, deps: Dictionary = {}, context: Dictionary = {}) -> bool:
	if index < 0 or index >= crows.size():
		return false
	var crow_value: Variant = crows[index]
	if not (crow_value is Dictionary):
		return false
	var crow: Dictionary = crow_value
	_create_crow_explosion(
		float(crow.get("x", 0.0)),
		float(crow.get("y", 0.0)),
		int(crow.get("size", 24))
	)
	_spawn_crow_starpoint_drop(Vector2(float(crow.get("x", 0.0)), float(crow.get("y", 0.0))), deps, context)
	crows.remove_at(index)
	return true


func catch_bird(index: int, deps: Dictionary = {}, context: Dictionary = {}) -> bool:
	return catch_crow(index, deps, context)


func resolve_ball_collision(scene: Dictionary, context: Dictionary = {}, deps: Dictionary = {}) -> bool:
	if int(context.get("current_stage", 4)) != 4:
		return false
	var ball_pos: Vector2 = _as_vector2(scene.get("ball_pos", context.get("ball_pos", Vector2.ZERO)), Vector2.ZERO)
	var base_ball_radius: float = float(context.get("ball_size", 28.6)) * 0.5
	var ball_radius: float = maxf(base_ball_radius, float(context.get("ball_render_radius", base_ball_radius)))
	for crow_value in get_crow_positions():
		if not (crow_value is Dictionary):
			continue
		var crow: Dictionary = crow_value
		var crow_pos := Vector2(float(crow.get("x", 0.0)), float(crow.get("y", 0.0)))
		var crow_radius: float = maxf(1.0, float(crow.get("radius", 25.0)))
		if ball_pos.distance_to(crow_pos) > crow_radius + ball_radius:
			continue
		var crow_index: int = int(crow.get("index", -1))
		if not catch_crow(crow_index, deps, context):
			continue
		scene["stage4_star_bird_caught"] = true
		scene["stage4_star_bird_caught_index"] = crow_index
		scene["stage4_star_bird_caught_pos"] = crow_pos
		scene["stage4_star_bird_caught_count"] = int(scene.get("stage4_star_bird_caught_count", 0)) + 1
		_play_star_bird_hit_audio(deps)
		return true
	return false


func get_actor_draw_context(copy_arrays: bool = false) -> Dictionary:
	return {
		"stage4_star_birds": _draw_array(crows, copy_arrays),
		"stage4_star_bird_fragments": _draw_array(crow_fragments, copy_arrays),
		"stage4_star_bird_particles": _draw_array(crow_particles, copy_arrays),
		"stage4_starpoint_drops": _draw_array(starpoint_drops, copy_arrays),
		"stage4_starpoint_particles": _draw_array(starpoint_particles, copy_arrays),
		"stage4_star_bird_count": crows.size(),
		"stage4_starpoint_drop_count": starpoint_drops.size(),
	}


func get_debug_snapshot() -> Dictionary:
	return {
		"active_bird_count": crows.size(),
		"fragment_count": crow_fragments.size(),
		"particle_count": crow_particles.size(),
		"starpoint_drop_count": starpoint_drops.size(),
		"starpoint_particle_count": starpoint_particles.size(),
		"spawn_timer": spawn_timer,
		"spawn_interval": spawn_interval,
		"spawn_min_sec": SPAWN_MIN_SEC,
		"spawn_max_sec": SPAWN_MAX_SEC,
		"gold_dust_max": GOLD_DUST_MAX,
	}


func get_asset_status() -> Dictionary:
	_ensure_textures()
	return {
		"star_bird_sheet": star_bird_sheet != null,
		"star_bird_frame_count": STAR_BIRD_FRAME_COUNT,
		"star_bird_gold_dust_max": GOLD_DUST_MAX,
		"star_bird_gold_dust_render_limit": GOLD_DUST_RENDER_LIMIT,
		"star_bird_gold_dust_render_limit_lod": GOLD_DUST_RENDER_LIMIT_LOD,
		"star_bird_fragment_render_limit": CROW_FRAGMENT_RENDER_LIMIT,
		"star_bird_fragment_render_limit_lod": CROW_FRAGMENT_RENDER_LIMIT_LOD,
		"star_bird_particle_render_limit": CROW_PARTICLE_RENDER_LIMIT,
		"star_bird_particle_render_limit_lod": CROW_PARTICLE_RENDER_LIMIT_LOD,
		"starpoint_particle_render_limit": STARPOINT_PARTICLE_RENDER_LIMIT,
		"starpoint_particle_render_limit_lod": STARPOINT_PARTICLE_RENDER_LIMIT_LOD,
		"shared_render_quality_lod_supported": true,
	}


func _ensure_textures() -> void:
	if textures_loaded:
		return
	textures_loaded = true
	star_bird_sheet = ProjectResourceLoader.load_texture(STAR_BIRD_SHEET_PATH)


func _spawn_crow(side_override: String = "") -> bool:
	if crows.size() >= MAX_ACTIVE_BIRDS:
		return false
	crows.append(Stage4BirdPayloadFactory.build_crow(side_override, rng, WIDTH))
	return true


func _update_crows(fps_scale: float) -> void:
	var alive: Array = []
	for crow_value in crows:
		if not (crow_value is Dictionary):
			continue
		var crow: Dictionary = crow_value
		if not bool(crow.get("caught", false)):
			var prev_x: float = float(crow.get("x", 0.0))
			var prev_y: float = float(crow.get("y", 0.0))
			crow["x"] = prev_x + float(crow.get("vx", 0.0)) * fps_scale
			crow["y"] = prev_y + float(crow.get("vy", 0.0)) * fps_scale
			crow["vy"] = float(crow.get("vy", 0.0)) + sin(time_sec * 3.0) * 0.02 * fps_scale
			crow["wing_phase"] = float(crow.get("wing_phase", 0.0)) + float(crow.get("wing_speed", 0.2)) * fps_scale
			_update_gold_dust(crow, prev_x, prev_y, fps_scale)
			crow["last_x"] = float(crow.get("x", 0.0))
			crow["last_y"] = float(crow.get("y", 0.0))
			if float(crow.get("x", 0.0)) < -100.0 or float(crow.get("x", 0.0)) > WIDTH + 100.0:
				continue
		alive.append(crow)
	crows = alive


func _update_gold_dust(crow: Dictionary, prev_x: float, prev_y: float, fps_scale: float) -> void:
	var dust: Array = _as_array(crow.get("gold_dust", []))
	var direction := 1.0 if float(crow.get("vx", 0.0)) >= 0.0 else -1.0
	var size: float = maxf(18.0, float(crow.get("size", 24.0)))
	var x: float = float(crow.get("x", prev_x))
	var y: float = float(crow.get("y", prev_y))
	if -80.0 <= x and x <= WIDTH + 80.0 and -80.0 <= y and y <= HEIGHT + 40.0:
		var travel: float = Vector2(x - prev_x, y - prev_y).length()
		var spawn_accum: float = float(crow.get("dust_spawn_accum", 0.0)) + maxf(0.75, travel * 0.58)
		var spawn_count: int = mini(4, int(spawn_accum))
		crow["dust_spawn_accum"] = spawn_accum - float(spawn_count)
		for _idx in range(spawn_count):
			dust.append(Stage4BirdPayloadFactory.build_gold_dust_particle(
				crow,
				Vector2(prev_x, prev_y),
				Vector2(x, y),
				direction,
				size,
				rng
			))
	var write_index := 0
	var dust_count := dust.size()
	for index in range(dust_count):
		var particle_value: Variant = dust[index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["vx"] = float(particle.get("vx", 0.0)) * pow(0.988, fps_scale)
		particle["vy"] = float(particle.get("vy", 0.0)) + float(particle.get("gravity", 0.012)) * fps_scale
		particle["phase"] = float(particle.get("phase", 0.0)) + float(particle.get("phase_speed", 0.18)) * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		var px: float = float(particle.get("x", 0.0))
		var py: float = float(particle.get("y", 0.0))
		if float(particle.get("life", 0.0)) > 0.0 and -60.0 <= px and px <= WIDTH + 60.0 and -70.0 <= py and py <= HEIGHT + 60.0:
			dust[write_index] = particle
			write_index += 1
	if write_index < dust_count:
		dust.resize(write_index)
	_trim_array_from_front(dust, GOLD_DUST_MAX)
	crow["gold_dust"] = dust


func _create_crow_explosion(x: float, y: float, size: int) -> void:
	crow_fragments.append_array(Stage4BirdPayloadFactory.build_crow_fragments(x, y, size, rng))
	crow_particles.append_array(Stage4BirdPayloadFactory.build_crow_debris_particles(x, y, 8, rng))


func _spawn_crow_starpoint_drop(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var drop_pos := Vector2(
		clamp(
			pos.x,
			StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_right(context, WIDTH) - STARPOINT_DROP_SIZE
		),
		clamp(
			pos.y,
			STARPOINT_DROP_SIZE,
			StagePlayfieldBounds.get_height(context, HEIGHT) - STARPOINT_DROP_SIZE
		)
	)
	_spawn_starpoint_drop_at(drop_pos, deps, context, true, false, "crow")


func _spawn_starpoint_drop_at(
	pos: Vector2,
	deps: Dictionary = {},
	context: Dictionary = {},
	allow_star_detector_bonus: bool = true,
	star_detector_bonus: bool = false,
	source_type: String = "crow"
) -> void:
	starpoint_drops.append(StarpointPayloadFactory.build_drop(
		pos,
		rng,
		star_detector_bonus,
		STARPOINT_DROP_SIZE,
		STARPOINT_DROP_LIFETIME,
		0.05,
		0.1,
		source_type
	))
	if starpoint_drops.size() > MAX_STAGE4_STARPOINT_DROPS:
		_trim_array_from_front(starpoint_drops, MAX_STAGE4_STARPOINT_DROPS)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + (6 if star_detector_bonus else 0), 1.2 if star_detector_bonus else 1.0)
	if allow_star_detector_bonus:
		_spawn_star_detector_bonus_drops(pos, deps, context)


func _spawn_star_detector_bonus_drops(pos: Vector2, deps: Dictionary, context: Dictionary) -> void:
	var bonus_count: int = StarpointBonusDropPolicy.roll_star_detector_bonus_drop_count(deps, context)
	for _idx in range(bonus_count):
		var bonus_pos := Vector2(
			clamp(
				pos.x + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				StagePlayfieldBounds.get_left(context) + STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_right(context, WIDTH) - STARPOINT_DROP_SIZE
			),
			clamp(
				pos.y + float(STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES[rng.randi_range(0, STAR_DETECTOR_BONUS_DROP_OFFSET_CHOICES.size() - 1)]),
				STARPOINT_DROP_SIZE,
				StagePlayfieldBounds.get_height(context, HEIGHT) - STARPOINT_DROP_SIZE
			)
		)
		_spawn_starpoint_drop_at(bonus_pos, deps, context, false, true, "crow")


func _update_fragments(fps_scale: float) -> void:
	var write_index := 0
	var fragment_count := crow_fragments.size()
	for index in range(fragment_count):
		var fragment_value: Variant = crow_fragments[index]
		if not (fragment_value is Dictionary):
			continue
		var fragment: Dictionary = fragment_value
		fragment["x"] = float(fragment.get("x", 0.0)) + float(fragment.get("vx", 0.0)) * fps_scale
		fragment["y"] = float(fragment.get("y", 0.0)) + float(fragment.get("vy", 0.0)) * fps_scale
		fragment["vy"] = float(fragment.get("vy", 0.0)) + float(fragment.get("gravity", 0.15)) * fps_scale
		fragment["vx"] = float(fragment.get("vx", 0.0)) * pow(0.98, fps_scale)
		fragment["rotation"] = float(fragment.get("rotation", 0.0)) + float(fragment.get("rotation_speed", 0.0)) * fps_scale
		fragment["life"] = float(fragment.get("life", 0.0)) - fps_scale
		if float(fragment.get("life", 0.0)) < 30.0:
			fragment["opacity"] = clampf(float(fragment.get("life", 0.0)) / 30.0, 0.0, 1.0)
		if float(fragment.get("life", 0.0)) > 0.0 and float(fragment.get("y", 0.0)) <= HEIGHT + 50.0:
			crow_fragments[write_index] = fragment
			write_index += 1
	if write_index < fragment_count:
		crow_fragments.resize(write_index)


func _update_particles(fps_scale: float) -> void:
	var write_index := 0
	var particle_count := crow_particles.size()
	for index in range(particle_count):
		var particle_value: Variant = crow_particles[index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		particle["x"] = float(particle.get("x", 0.0)) + float(particle.get("vx", 0.0)) * fps_scale
		particle["y"] = float(particle.get("y", 0.0)) + float(particle.get("vy", 0.0)) * fps_scale
		particle["vy"] = float(particle.get("vy", 0.0)) + 0.1 * fps_scale
		particle["life"] = float(particle.get("life", 0.0)) - fps_scale
		particle["opacity"] = float(particle.get("opacity", 0.0)) * pow(0.95, fps_scale)
		if float(particle.get("life", 0.0)) > 0.0 and float(particle.get("opacity", 0.0)) >= 0.04:
			crow_particles[write_index] = particle
			write_index += 1
	if write_index < particle_count:
		crow_particles.resize(write_index)


func _update_starpoint_drops(fps_scale: float, context: Dictionary, deps: Dictionary) -> void:
	if starpoint_drops.is_empty():
		return
	var player_rect := Rect2(
		_as_vector2(context.get("player_pos", Vector2.ZERO), Vector2.ZERO),
		_as_vector2(context.get("player_paddle_size", Vector2(155.0, 50.0)), Vector2(155.0, 50.0))
	)
	var player_rects: Array[Rect2] = StagePlayerInteractionRects.get_player_interaction_rects(player_rect, deps)
	var play_left: float = StagePlayfieldBounds.get_left(context)
	var play_right: float = StagePlayfieldBounds.get_right(context, WIDTH)
	var play_height: float = StagePlayfieldBounds.get_height(context, HEIGHT)
	var write_index := 0
	var drop_count := starpoint_drops.size()
	for index in range(drop_count):
		var drop_value: Variant = starpoint_drops[index]
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		if not StarpointDropMotionState.update_drop(
			drop,
			fps_scale,
			play_left,
			play_right,
			play_height,
			STARPOINT_DROP_SIZE,
			STARPOINT_DROP_MAX_FALL_SPEED,
			STARPOINT_DROP_ACCELERATION,
			STARPOINT_DROP_BOUNCE_DAMPING
		):
			continue

		var starlight_tracking_result := LingpetStarlightTrackingBridge.update_drop(drop, fps_scale, context, deps)
		if bool(starlight_tracking_result.get("delivered", false)):
			if _collect_starpoint_drop(drop, context, deps):
				StarpointCollectionCompaction.finish_in_place(starpoint_drops, index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		if bool(starlight_tracking_result.get("claimed", false)):
			starpoint_drops[write_index] = drop
			write_index += 1
			continue

		if StarpointDropOverlapQuery.overlaps_any_circle_player(drop, player_rects, STARPOINT_DROP_SIZE):
			if _collect_starpoint_drop(drop, context, deps):
				StarpointCollectionCompaction.finish_in_place(starpoint_drops, index, write_index, drop_count)
				return
			if starpoint_drops.size() < drop_count:
				return
			continue
		starpoint_drops[write_index] = drop
		write_index += 1
	if write_index < drop_count:
		starpoint_drops.resize(write_index)


func _update_starpoint_particles(fps_scale: float) -> void:
	StarpointParticleState.update_particles(starpoint_particles, fps_scale)


func _draw_gold_dust(canvas: CanvasItem, crow: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var dust: Array = _as_array(crow.get("gold_dust", []))
	var lod_active: bool = _is_render_lod_active(quality_scale)
	var render_limit: int = _get_lod_count(GOLD_DUST_RENDER_LIMIT, GOLD_DUST_RENDER_LIMIT_LOD, quality_scale)
	for particle_index in range(_recent_start(dust, render_limit), dust.size()):
		var particle_value: Variant = dust[particle_index]
		if not (particle_value is Dictionary):
			continue
		var particle: Dictionary = particle_value
		var life_ratio: float = clampf(float(particle.get("life", 0.0)) / maxf(1.0, float(particle.get("max_life", 1.0))), 0.0, 1.0)
		var twinkle: float = 0.66 + 0.34 * sin(float(particle.get("phase", 0.0)))
		var alpha: float = 0.80 * life_ratio * twinkle
		if alpha <= 0.03:
			continue
		var center := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
		var radius: float = maxf(1.0, float(particle.get("size", 1.6)) * (0.75 + 0.45 * twinkle))
		if not lod_active:
			canvas.draw_circle(center, radius * 3.0, Color(1.0, 0.70, 0.16, alpha * 0.16))
		canvas.draw_circle(center, radius + 1.0, Color(1.0, 0.84, 0.32, alpha * 0.45))
		canvas.draw_circle(center, radius, Color(1.0, 0.96, 0.68, alpha))
		if not lod_active and alpha > 0.43 and radius <= 2.4:
			canvas.draw_line(center + Vector2(-radius * 3.0, 0.0), center + Vector2(radius * 3.0, 0.0), Color(1.0, 0.88, 0.49, alpha * 0.32), 1.0, true)
			canvas.draw_line(center + Vector2(0.0, -radius * 3.0), center + Vector2(0.0, radius * 3.0), Color(1.0, 0.88, 0.49, alpha * 0.32), 1.0, true)


func _draw_bird(canvas: CanvasItem, crow: Dictionary, shake_offset: Vector2) -> void:
	var center := Vector2(float(crow.get("x", 0.0)), float(crow.get("y", 0.0))) + shake_offset
	var size: float = float(crow.get("size", 24.0))
	if star_bird_sheet != null:
		var sheet_size: Vector2 = star_bird_sheet.get_size()
		var cell_w: float = sheet_size.x / float(STAR_BIRD_FRAME_COUNT)
		var phase: float = fposmod(float(crow.get("wing_phase", 0.0)), TAU)
		var frame: int = int((phase / TAU) * float(STAR_BIRD_FRAME_COUNT)) % STAR_BIRD_FRAME_COUNT
		var draw_size: float = maxf(78.0, size * 3.5)
		var target_rect := Rect2(center - Vector2(draw_size, draw_size) * 0.5, Vector2(draw_size, draw_size))
		var source_rect := Rect2(float(frame) * cell_w, 0.0, cell_w, sheet_size.y)
		if _should_flip_bird_sheet(crow):
			_draw_flipped_texture_region(canvas, star_bird_sheet, source_rect, target_rect, Color.WHITE)
		else:
			canvas.draw_texture_rect_region(
				star_bird_sheet,
				target_rect,
				source_rect,
				Color.WHITE,
				false,
				true
			)
		return
	_draw_fallback_bird(canvas, crow, center)


func _draw_fallback_bird(canvas: CanvasItem, crow: Dictionary, center: Vector2) -> void:
	var size: float = float(crow.get("size", 24.0))
	var flap: float = sin(float(crow.get("wing_phase", 0.0)))
	var facing_sign := _get_bird_facing_sign(crow)
	var body_color := Color(0.06, 0.04, 0.08, 0.96)
	var wing_lift: float = absf(flap) * 15.0
	var wing_spread: float = size * 0.86
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(-6.0 * facing_sign, -2.0),
		center + Vector2(-wing_spread * facing_sign, -wing_lift),
		center + Vector2(-wing_spread * 0.54 * facing_sign, 7.0 + wing_lift * 0.20),
	]), body_color)
	canvas.draw_colored_polygon(PackedVector2Array([
		center + Vector2(6.0 * facing_sign, -2.0),
		center + Vector2(wing_spread * facing_sign, -wing_lift),
		center + Vector2(wing_spread * 0.54 * facing_sign, 7.0 + wing_lift * 0.20),
	]), body_color)
	_draw_ellipse_polygon(canvas, center, Vector2(size * 0.46, size * 0.20), body_color)
	canvas.draw_circle(center + Vector2(size * 0.42 * facing_sign, -2.0), size * 0.22, body_color)
	canvas.draw_circle(center + Vector2(size * 0.52 * facing_sign, -4.0), 2.0, Color(0.78, 0.16, 0.14, 0.95))


func _should_flip_bird_sheet(crow: Dictionary) -> bool:
	return _get_bird_facing_sign(crow) < 0.0


func _get_bird_facing_sign(crow: Dictionary) -> float:
	return -1.0 if float(crow.get("vx", 0.0)) < 0.0 else 1.0


func _draw_flipped_texture_region(
	canvas: CanvasItem,
	texture: Texture2D,
	source_rect: Rect2,
	target_rect: Rect2,
	modulate: Color
) -> void:
	var texture_size := texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return
	var points := PackedVector2Array([
		target_rect.position,
		Vector2(target_rect.end.x, target_rect.position.y),
		target_rect.end,
		Vector2(target_rect.position.x, target_rect.end.y),
	])
	var uv_min := Vector2(source_rect.position.x / texture_size.x, source_rect.position.y / texture_size.y)
	var uv_max := Vector2(source_rect.end.x / texture_size.x, source_rect.end.y / texture_size.y)
	var uvs := PackedVector2Array([
		Vector2(uv_max.x, uv_min.y),
		Vector2(uv_min.x, uv_min.y),
		Vector2(uv_min.x, uv_max.y),
		Vector2(uv_max.x, uv_max.y),
	])
	var colors := PackedColorArray([modulate, modulate, modulate, modulate])
	canvas.draw_polygon(points, colors, uvs, texture)


func _draw_fragment(canvas: CanvasItem, fragment: Dictionary, shake_offset: Vector2) -> void:
	var center := Vector2(float(fragment.get("x", 0.0)), float(fragment.get("y", 0.0))) + shake_offset
	var size: float = maxf(2.0, float(fragment.get("size", 4.0)))
	var color: Color = _as_color(fragment.get("color", Color(0.08, 0.06, 0.10, 1.0)))
	color.a *= clampf(float(fragment.get("opacity", 1.0)), 0.0, 1.0)
	var num_points: int = max(4, int(fragment.get("num_points", 6)))
	var offsets: Array = _as_array(fragment.get("shape_offsets", []))
	var points := PackedVector2Array()
	var rotation: float = deg_to_rad(float(fragment.get("rotation", 0.0)))
	for idx in range(num_points):
		var radius: float = size
		if str(fragment.get("type", "")) == "feather" and idx % 2 == 1:
			radius *= 0.5
		elif idx < offsets.size():
			radius *= float(offsets[idx])
		var angle: float = (float(idx) / float(num_points)) * TAU + rotation
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	if points.size() >= 3:
		canvas.draw_colored_polygon(points, color)


func _draw_particle(canvas: CanvasItem, particle: Dictionary, shake_offset: Vector2) -> void:
	var center := Vector2(float(particle.get("x", 0.0)), float(particle.get("y", 0.0))) + shake_offset
	var size: float = maxf(1.0, float(particle.get("size", 2.0)))
	var color: Color = _as_color(particle.get("color", Color(0.16, 0.14, 0.18, 1.0)))
	color.a *= clampf(float(particle.get("opacity", 0.7)), 0.0, 1.0)
	canvas.draw_circle(center, size, color)


func _draw_starpoint_particles(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2, quality_scale: float) -> void:
	var particles: Array = _as_array(context.get("stage4_starpoint_particles", starpoint_particles))
	var render_limit: int = _get_lod_count(STARPOINT_PARTICLE_RENDER_LIMIT, STARPOINT_PARTICLE_RENDER_LIMIT_LOD, quality_scale)
	for particle_index in range(_recent_start(particles, render_limit), particles.size()):
		var particle_value: Variant = particles[particle_index]
		var particle: Dictionary = particle_value if particle_value is Dictionary else {}
		var alpha: float = clampf(float(particle.get("alpha", 0.0)), 0.0, 1.0)
		if alpha <= 0.0:
			continue
		var pos: Vector2 = _as_vector2(particle.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var color: Color = _get_starpoint_particle_color(float(particle.get("color_shift", 0.5)), alpha)
		canvas.draw_circle(pos, maxf(1.0, float(particle.get("size", 2.0))), color)


func _draw_starpoint_drops(canvas: CanvasItem, context: Dictionary, shake_offset: Vector2) -> void:
	var drops: Array = _as_array(context.get("stage4_starpoint_drops", starpoint_drops))
	if drops.is_empty():
		CommonStarpointVisualHost.hide_on_canvas(canvas)
		return
	# Stage 4 uses the gold/orange palette (vs. Stages 1/2/3 scrap pink/red).
	# Detector-bonus drops share the cyan/white palette across all stages.
	# Convert playfield-local drop positions and sizes into rendered-playfield
	# screen coordinates since the host is a child of the outer canvas (outside
	# the playfield's draw_set_transform window).
	var game_offset: Vector2 = _as_vector2(context.get("game_offset", Vector2.ZERO), Vector2.ZERO)
	var render_scale: float = maxf(0.001, float(context.get("render_scale", 1.0)))
	var host: Node = CommonStarpointVisualHost.get_or_create_on_canvas(canvas)
	if host != null and host.has_method("sync_drop"):
		host.begin_frame()
		var elapsed: float = float(Time.get_ticks_msec()) / 1000.0
		for drop_value in drops:
			var drop: Dictionary = drop_value if drop_value is Dictionary else {}
			var star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
			var playfield_pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
			host.sync_drop({
				"pos": game_offset + playfield_pos * render_scale,
				"size": float(drop.get("size", STARPOINT_DROP_SIZE)) * render_scale,
				"life": float(drop.get("life", 0.0)),
				"rotation": float(drop.get("rotation", 0.0)),
				"glow_intensity": float(drop.get("glow_intensity", 1.0)),
				"star_detector_bonus": star_detector_bonus,
				"elapsed": elapsed,
				"glow_color": Color(0.30, 0.92, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.64, 0.16, 1.0),
				"fill_color": Color(0.16, 0.82, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.68, 0.05, 1.0),
				"outline_color": Color(1.0, 1.0, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.98, 0.52, 1.0),
			})
		host.end_frame()
		return
	for drop_value in drops:
		var drop: Dictionary = drop_value if drop_value is Dictionary else {}
		var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO) + shake_offset
		var size: float = maxf(1.0, float(drop.get("size", STARPOINT_DROP_SIZE)))
		var alpha: float = clampf(float(drop.get("life", 0.0)) * 2.0 / 255.0, 0.0, 1.0)
		var glow_intensity: float = clampf(float(drop.get("glow_intensity", 1.0)), 0.0, 1.0)
		var glow_alpha: float = alpha * 0.5 * glow_intensity
		var star_detector_bonus: bool = bool(drop.get("star_detector_bonus", false))
		var glow_color := Color(0.30, 0.92, 1.0, 1.0) if star_detector_bonus else Color(1.0, 0.64, 0.16, 1.0)
		var fill_color := Color(0.16, 0.82, 1.0, alpha) if star_detector_bonus else Color(1.0, 0.68, 0.05, alpha)
		var outline_color := Color(1.0, 1.0, 1.0, alpha) if star_detector_bonus else Color(1.0, 0.98, 0.52, alpha)
		for layer in range(4):
			var glow_radius: float = size * (4.0 - float(layer) * 0.7)
			var layer_alpha: float = glow_alpha / float(4 - layer)
			canvas.draw_circle(pos, glow_radius, Color(glow_color.r, glow_color.g, glow_color.b, layer_alpha))

		var points := PackedVector2Array()
		var rotation: float = float(drop.get("rotation", 0.0))
		for point_index in range(10):
			var point_radius: float = size if point_index % 2 == 0 else size * 0.5
			var angle: float = rotation + float(point_index) * PI / 5.0
			points.append(pos + Vector2(cos(angle), sin(angle)) * point_radius)
		if points.size() >= 3:
			canvas.draw_colored_polygon(points, fill_color)
			for point_index in range(points.size()):
				canvas.draw_line(points[point_index], points[(point_index + 1) % points.size()], outline_color, 3.0, true)
		canvas.draw_circle(pos, 3.0, Color(1.0, 1.0, 1.0, alpha * glow_intensity))


func _get_starpoint_particle_color(color_shift: float, alpha: float) -> Color:
	var clamped_shift: float = clampf(color_shift, 0.0, 1.0)
	if clamped_shift < 0.33:
		var warm_t: float = clamped_shift * 3.0
		return Color(1.0, 1.0, (100.0 + 155.0 * warm_t) / 255.0, alpha)
	if clamped_shift < 0.66:
		var blue_t: float = (clamped_shift - 0.33) * 3.0
		return Color((255.0 - 55.0 * blue_t) / 255.0, (255.0 - 30.0 * blue_t) / 255.0, 1.0, alpha)
	var cyan_t: float = (clamped_shift - 0.66) * 3.0
	return Color((200.0 - 100.0 * cyan_t) / 255.0, (225.0 + 30.0 * cyan_t) / 255.0, 1.0, alpha)


func _draw_ellipse_polygon(canvas: CanvasItem, center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for idx in range(20):
		var angle: float = TAU * float(idx) / 20.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	canvas.draw_colored_polygon(points, color)


func _draw_array(source: Array, copy_arrays: bool) -> Array:
	return StageActorDrawContextArrays.snapshot(source, copy_arrays)


func _recent_start(source: Array, render_limit: int) -> int:
	if render_limit <= 0:
		return source.size()
	return max(0, source.size() - render_limit)


func _get_render_quality_scale(context: Dictionary) -> float:
	return BattleRenderQuality.effect_scale(context)


func _is_render_lod_active(quality_scale: float) -> bool:
	return quality_scale < 0.85


func _get_lod_count(base_count: int, lod_count: int, quality_scale: float) -> int:
	if base_count <= 0:
		return 0
	if not _is_render_lod_active(quality_scale):
		return base_count
	return clampi(lod_count, 0, base_count)


func _trim_array_from_front(source: Array, max_size: int) -> void:
	if max_size <= 0:
		source.clear()
		return
	var overflow := source.size() - max_size
	if overflow <= 0:
		return
	var write_index := 0
	for read_index in range(overflow, source.size()):
		source[write_index] = source[read_index]
		write_index += 1
	source.resize(write_index)


func _collect_starpoint_drop(drop: Dictionary, context: Dictionary, deps: Dictionary) -> bool:
	var opened_choice: bool = StarpointCollectionRewardPolicy.collect_starpoint_reward(context, deps)
	var pos: Vector2 = _as_vector2(drop.get("pos", Vector2.ZERO), Vector2.ZERO)
	_spawn_starpoint_particles(pos, STARPOINT_PARTICLE_COUNT + 10, 1.4)
	_play_starpoint_collect_sound(deps)
	StarpointCollectionRewardPolicy.request_owner_redraw(context)
	return opened_choice


func _spawn_starpoint_particles(pos: Vector2, count: int, intensity: float) -> void:
	starpoint_particles.append_array(StarpointPayloadFactory.build_particles(
		pos,
		count,
		intensity,
		rng,
		STARPOINT_PARTICLE_LIFE
	))
	if starpoint_particles.size() > MAX_STAGE4_STARPOINT_PARTICLES:
		_trim_array_from_front(starpoint_particles, MAX_STAGE4_STARPOINT_PARTICLES)


func _play_starpoint_collect_sound(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio != null and audio.has_method("play_starpoint_collect"):
		audio.play_starpoint_collect()


func _play_star_bird_hit_audio(deps: Dictionary) -> void:
	var audio: Object = deps.get("audio", null)
	if audio == null:
		return
	if audio.has_method("play_stage4_birdkill"):
		audio.play_stage4_birdkill()
	elif audio.has_method("play_stage4_fragment_shoot"):
		audio.play_stage4_fragment_shoot()


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback


func _as_array(value: Variant) -> Array:
	if value is Array:
		return value
	return []


func _as_color(value: Variant) -> Color:
	if value is Color:
		return value
	return Color(1.0, 1.0, 1.0, 1.0)
