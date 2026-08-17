extends RefCounted

const Stage2AudioRouter := preload("res://scripts/stages/stage2/stage2_audio_router.gd")
const StarpointBonusDropPolicy := preload("res://scripts/stages/common/starpoint_bonus_drop_policy.gd")

const HIT_FLASH_SEC := 0.24
const HIT_COOLDOWN_FRAMES := 30.0
const SHAKE_DURATION_SEC := 0.048
const SHAKE_STRENGTH := 2.5
const IMPACT_COLOR := Color(0.62, 0.90, 1.0, 1.0)
const IMPACT_SCALE := 0.8
const KNOCKBACK_SPEED := 20.0
const KNOCKBACK_FRAMES := 40.0
const KNOCKBACK_DECAY := 0.85
const IMMUNITY_SOURCE := "stage2_water_fragment"
const IMMUNITY_EFFECT_TYPE := "knockback"


func apply(
	index: int,
	splash: Dictionary,
	pos: Vector2,
	player_rect: Rect2,
	water_splashes: Array,
	fragment_hit_flash_state: Object,
	deps: Dictionary,
	context: Dictionary = {}
) -> Dictionary:
	if index < 0 or index >= water_splashes.size():
		return {"handled": false, "applied": false, "immune": false}

	splash["can_hit_player"] = false
	splash["hit_cooldown"] = HIT_COOLDOWN_FRAMES
	water_splashes[index] = splash
	if _is_player_status_immune(deps, context):
		return {"handled": true, "applied": false, "immune": true}

	if fragment_hit_flash_state != null and fragment_hit_flash_state.has_method("trigger"):
		fragment_hit_flash_state.trigger(HIT_FLASH_SEC)
	var feedback: Object = deps.get("feedback", null)
	if feedback != null and feedback.has_method("max_screen_shake"):
		feedback.max_screen_shake(SHAKE_DURATION_SEC, SHAKE_STRENGTH)
	var velocity: Vector2 = _get_vector2(splash.get("vel", Vector2.ZERO), Vector2.ZERO)
	var impact_effects: Object = deps.get("impact_effects", null)
	if impact_effects != null and impact_effects.has_method("spawn_hit_particles"):
		impact_effects.spawn_hit_particles(
			pos,
			IMPACT_COLOR,
			velocity,
			IMPACT_SCALE,
			velocity.length()
		)
	Stage2AudioRouter.play_rock_hit(deps)

	var movement_state: Object = deps.get("movement_state", null)
	if movement_state == null or not movement_state.has_method("start_knockback"):
		return {"handled": true, "applied": true, "immune": false, "knockback": false}
	var direction := 1.0 if velocity.x >= 0.0 else -1.0
	if abs(velocity.x) <= 0.01:
		direction = 1.0 if pos.x >= player_rect.get_center().x else -1.0
	movement_state.start_knockback(
		direction * KNOCKBACK_SPEED,
		KNOCKBACK_FRAMES,
		KNOCKBACK_DECAY,
		true
	)
	return {"handled": true, "applied": true, "immune": false, "knockback": true}


func _is_player_status_immune(deps: Dictionary, context: Dictionary) -> bool:
	var cleanse_state: Object = deps.get("smasher_cleanse_state", null)
	if cleanse_state != null and cleanse_state.has_method("is_immune"):
		if bool(cleanse_state.is_immune()):
			return true
	var mythic_item_runtime: Object = StarpointBonusDropPolicy.get_mythic_item_runtime(deps, context)
	if mythic_item_runtime == null or not mythic_item_runtime.has_method("try_consume_celestial_armor_immunity"):
		return false
	var status_deps: Dictionary = deps.duplicate()
	status_deps["context"] = context
	if context.get("owner", null) is Object:
		status_deps["owner"] = context.get("owner", null)
	return bool(mythic_item_runtime.try_consume_celestial_armor_immunity(
		IMMUNITY_SOURCE,
		IMMUNITY_EFFECT_TYPE,
		status_deps
	))


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
