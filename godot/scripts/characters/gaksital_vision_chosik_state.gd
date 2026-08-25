extends RefCounted

const CommonSkillCatalog := preload("res://scripts/characters/common_skill_catalog.gd")
const ProjectResourceLoader := preload(
	"res://scripts/resources/project_resource_loader.gd"
)
const Stage1GaksitalFanProjectileContract := preload(
	"res://scripts/stages/stage1/stage1_gaksital_fan_projectile_contract.gd"
)
const Stage1GaksitalFanThrowRenderer := preload(
	"res://scripts/stages/stage1/stage1_gaksital_fan_throw_renderer.gd"
)
const StarpointDropOverlapQuery := preload(
	"res://scripts/stages/common/starpoint_drop_overlap_query.gd"
)

const SKILL_ID := CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_ID
const COST := CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_COST
const BASE_COOLDOWN_SEC := CommonSkillCatalog.GAKSITAL_VISION_FAN_THROW_COOLDOWN
const STATUS_SOURCE := "gaksital_vision_fan_throw"
const HIT_EFFECT_FRAMES := 24.0

var cooldown_remaining := 0.0
var cooldown_duration := BASE_COOLDOWN_SEC
var fans: Array = []
var hit_effect_timer := 0.0
var hit_effect_pos := Vector2.ZERO
var visual_time := 0.0
var _last_secondary_action_pressed := false
var _projectile_texture: Texture2D = null
var _projectile_texture_prewarm_done := false
var _rng := RandomNumberGenerator.new()
var renderer: Object = Stage1GaksitalFanThrowRenderer.new()


func _init() -> void:
	_rng.randomize()


func update(
	delta: float,
	input_snapshot: Dictionary,
	modifier_pressed: bool,
	player_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> Dictionary:
	var safe_delta := maxf(0.0, delta)
	var fps_scale := safe_delta * 60.0
	visual_time += safe_delta
	cooldown_remaining = maxf(0.0, cooldown_remaining - safe_delta)
	hit_effect_timer = maxf(0.0, hit_effect_timer - fps_scale)
	_advance_projectiles(fps_scale, config, deps)

	var secondary_action_pressed := bool(input_snapshot.get("secondary_action_pressed", false))
	var secondary_action_edge := (
		bool(input_snapshot.get("secondary_action_just_pressed", false))
		or (secondary_action_pressed and not _last_secondary_action_pressed)
	)
	_last_secondary_action_pressed = secondary_action_pressed
	if not modifier_pressed or not secondary_action_edge:
		return {"activated": false, "movement_locked": false}
	if not _can_activate(config, deps):
		return {"activated": false, "movement_locked": false}
	return _activate(player_pos, config, deps)


func is_ready(special_gauge: float, equipped: bool = true) -> bool:
	return equipped and cooldown_remaining <= 0.0 and special_gauge >= COST


func is_movement_locked() -> bool:
	return false


func has_visible_effects() -> bool:
	return not fans.is_empty() or hit_effect_timer > 0.0


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if renderer == null or not has_visible_effects():
		return
	if renderer.has_method("draw_projectiles"):
		renderer.draw_projectiles(canvas, fans, _projectile_texture, shake_offset)
	if hit_effect_timer > 0.0 and renderer.has_method("draw_shared_hit_effect"):
		renderer.draw_shared_hit_effect(
			canvas,
			hit_effect_timer,
			hit_effect_pos,
			shake_offset
		)


func get_cooldown_ratio() -> float:
	return clampf(cooldown_remaining / maxf(0.001, cooldown_duration), 0.0, 1.0)


func get_snapshot() -> Dictionary:
	return {
		"cooldown_remaining": cooldown_remaining,
		"cooldown_ratio": get_cooldown_ratio(),
		"fans": fans.duplicate(true),
		"hit_effect_timer": hit_effect_timer,
		"hit_effect_pos": hit_effect_pos,
		"visual_time": visual_time,
		"projectile_texture_loaded": _projectile_texture != null,
	}


func reset_round() -> void:
	fans.clear()
	hit_effect_timer = 0.0
	hit_effect_pos = Vector2.ZERO
	visual_time = 0.0
	_last_secondary_action_pressed = false


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
	cooldown_remaining = 0.0
	cooldown_duration = BASE_COOLDOWN_SEC


func prewarm_assets() -> void:
	while not prewarm_assets_step():
		pass


func prewarm_assets_step() -> bool:
	if _projectile_texture_prewarm_done:
		return true
	if _projectile_texture != null:
		_projectile_texture_prewarm_done = true
		return true
	var result := ProjectResourceLoader.prewarm_texture_threaded_step(
		Stage1GaksitalFanProjectileContract.PROJECTILE_TEXTURE_PATH
	)
	if not bool(result.get("done", true)):
		return false
	_projectile_texture = result.get("texture", null) as Texture2D
	_projectile_texture_prewarm_done = true
	return true


func set_rng_seed_for_tests(seed_value: int) -> void:
	_rng.seed = seed_value


func set_projectile_texture_for_tests(texture: Texture2D) -> void:
	_projectile_texture = texture
	_projectile_texture_prewarm_done = texture != null


func _can_activate(config: Dictionary, deps: Dictionary) -> bool:
	if cooldown_remaining > 0.0:
		return false
	if not bool(config.get("ball_active", false)) or bool(config.get("player_skill_input_locked", false)):
		return false
	var skill_config: Object = deps.get("skill_config", null)
	if skill_config == null or not skill_config.has_method("is_skill_equipped"):
		return false
	if not bool(skill_config.is_skill_equipped(SKILL_ID)):
		return false
	return float(config.get("special_gauge", 0.0)) >= COST


func _activate(player_pos: Vector2, config: Dictionary, deps: Dictionary) -> Dictionary:
	var player_width := maxf(1.0, float(config.get("paddle_width", 155.0)))
	var player_height := maxf(1.0, float(config.get("paddle_height", 50.0)))
	var launch_pos := player_pos + Vector2(player_width * 0.5, player_height * 0.15)
	var boss_rect := _get_boss_rect(config)
	var direction := boss_rect.get_center() - launch_pos
	if direction.length_squared() <= 0.001:
		direction = Vector2.UP
	fans.append(Stage1GaksitalFanProjectileContract.build_projectile(
		launch_pos,
		direction,
		Stage1GaksitalFanProjectileContract.DRAW_SIZE,
		Color.WHITE,
		Stage1GaksitalFanProjectileContract.MAIN_FAN_SOUND_VOLUME,
		Stage1GaksitalFanProjectileContract.MAIN_HIT_SOUND_VOLUME,
		_rng.randf_range(
			-Stage1GaksitalFanProjectileContract.VX_JITTER,
			Stage1GaksitalFanProjectileContract.VX_JITTER
		)
	))

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
	return {
		"activated": true,
		"movement_locked": false,
		"special_gauge": next_gauge,
		"activation_class": "instant",
	}


func _advance_projectiles(fps_scale: float, config: Dictionary, deps: Dictionary) -> void:
	if fans.is_empty():
		return
	var width := maxf(1.0, float(config.get("width", 760.0)))
	var height := maxf(1.0, float(config.get("height", 750.0)))
	var boss_rect := _get_boss_rect(config)
	var next_fans: Array = []
	for fan_value: Variant in fans:
		if not (fan_value is Dictionary):
			continue
		var motion := Stage1GaksitalFanProjectileContract.advance_projectile(
			fan_value as Dictionary,
			fps_scale
		)
		var fan: Dictionary = motion.get("projectile", {})
		if bool(motion.get("spin_boundary_crossed", false)):
			Stage1GaksitalFanProjectileContract.play_fan_audio(
				deps,
				float(fan.get("fan_sound_volume", Stage1GaksitalFanProjectileContract.MAIN_FAN_SOUND_VOLUME))
			)
		if Stage1GaksitalFanProjectileContract.is_expired_or_out_of_bounds(fan, width, height):
			continue
		var fan_pos := Stage1GaksitalFanProjectileContract.get_position(fan)
		if StarpointDropOverlapQuery.circle_rect_overlap(
			fan_pos,
			Stage1GaksitalFanProjectileContract.HIT_RADIUS,
			boss_rect
		):
			_apply_boss_hit(fan, fan_pos, config, deps)
			continue
		next_fans.append(fan)
	fans = next_fans


func _apply_boss_hit(
	projectile: Dictionary,
	hit_pos: Vector2,
	config: Dictionary,
	deps: Dictionary
) -> void:
	hit_effect_timer = HIT_EFFECT_FRAMES
	hit_effect_pos = hit_pos
	_spawn_impact(hit_pos, deps)
	if not _is_boss_status_immune(config, deps):
		var knockback_velocity := Stage1GaksitalFanProjectileContract.roll_knockback_velocity(_rng)
		var status_effect_state: Object = deps.get("status_effect_state", null)
		if status_effect_state != null and status_effect_state.has_method("apply_status"):
			status_effect_state.apply_status(
				"boss",
				"stun",
				Stage1GaksitalFanProjectileContract.STUN_FRAMES,
				Stage1GaksitalFanProjectileContract.build_boss_stun_status_data(
					knockback_velocity,
					STATUS_SOURCE
				),
				STATUS_SOURCE
			)
	Stage1GaksitalFanProjectileContract.play_hit_audio(
		deps,
		float(projectile.get("hit_sound_volume", Stage1GaksitalFanProjectileContract.MAIN_HIT_SOUND_VOLUME))
	)


func _spawn_impact(pos: Vector2, deps: Dictionary) -> void:
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects == null:
		return
	if impact_effects.has_method("create_energy_explosion"):
		impact_effects.create_energy_explosion(pos, 0.55, 1.0)
	if impact_effects.has_method("spawn_paddle_hit_particles"):
		impact_effects.spawn_paddle_hit_particles(pos, false, Vector2.DOWN, 1.0)


func _is_boss_status_immune(config: Dictionary, deps: Dictionary) -> bool:
	if int(config.get("current_stage", 0)) != 2:
		return false
	if bool(config.get("stage2_speed_defense_status_immunity_active", false)) or bool(config.get("stage2_speed_defense_active", false)):
		return true
	var registry: Object = deps.get("registry", null)
	var stage2_state: Object = null
	if registry != null and registry.has_method("get_instance"):
		stage2_state = registry.get_instance("stage2_boss_skill_state")
	return stage2_state != null and stage2_state.has_method("is_boss_status_immune") and bool(stage2_state.is_boss_status_immune())


func _get_boss_rect(config: Dictionary) -> Rect2:
	var boss_pos := _as_vector2(config.get("boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_width := maxf(1.0, float(config.get("boss_paddle_width", 100.0)))
	var boss_height := maxf(1.0, float(config.get("boss_hitbox_height", 40.0)))
	return Rect2(boss_pos, Vector2(boss_width, boss_height))


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	return value if value is Vector2 else fallback
