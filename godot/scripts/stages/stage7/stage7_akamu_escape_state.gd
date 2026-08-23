extends RefCounted

const LEGACY_FPS := 60.0
const FIELD_WIDTH := 760.0
const TRIGGER_CHANCE := 0.40
const NET_DELAY_SEC := 0.30
const DURATION_SEC := 0.50
const GAUGE_COST := 30.0
const HOLOGRAM_FADE_SEC := 0.40
const GHOST_COUNT := 5
const GHOST_DELAY_SEC := 0.060
const MAX_DISTANCE := 260.0
const SIDE_MIN_SPACE := 80.0
const WALL_MARGIN := 20.0
const FALLBACK_MIN_DISTANCE := 50.0
const INTANGIBLE_SOURCE := "stage7_stun_escape"

var active := false
var elapsed_sec := 0.0
var start_boss_pos := Vector2.ZERO
var target_boss_pos := Vector2.ZERO
var boss_size := Vector2(100.0, 40.0)
var visual_scale := 1.0
var episode_active := false
var attempted := false
var ready_remaining_sec := 0.0
var pity_failures := 0
var last_released_net_count := 0
var afterimages: Array = []
var hologram_draw_context: Dictionary = {}


func reset_full() -> void:
	clear_round_transients()
	pity_failures = 0


func clear_round_transients() -> void:
	active = false
	elapsed_sec = 0.0
	start_boss_pos = Vector2.ZERO
	target_boss_pos = Vector2.ZERO
	boss_size = Vector2(100.0, 40.0)
	visual_scale = 1.0
	episode_active = false
	attempted = false
	ready_remaining_sec = 0.0
	last_released_net_count = 0
	afterimages.clear()
	hologram_draw_context.clear()


func has_runtime_state() -> bool:
	return (
		active
		or episode_active
		or attempted
		or ready_remaining_sec > 0.0
		or not afterimages.is_empty()
		or not hologram_draw_context.is_empty()
	)


func get_snapshot() -> Dictionary:
	return {
		"trigger_chance": TRIGGER_CHANCE,
		"active": active,
		"elapsed_sec": elapsed_sec,
		"progress": clampf(elapsed_sec / DURATION_SEC, 0.0, 1.0),
		"start_boss_pos": start_boss_pos,
		"target_boss_pos": target_boss_pos,
		"boss_pos": get_boss_pos(),
		"visual_scale": visual_scale,
		"episode_active": episode_active,
		"attempted": attempted,
		"ready_remaining_sec": ready_remaining_sec,
		"pity_failures": pity_failures,
		"released_net_count": last_released_net_count,
		"afterimage_count": afterimages.size(),
		"hologram_active": not hologram_draw_context.is_empty(),
		"hologram": hologram_draw_context.duplicate(true),
	}


func update_trigger(
	delta: float,
	context: Dictionary,
	deps: Dictionary,
	boss_gauge: float,
	blocked_by_other_skill: bool,
	odin_knockback_rewind_x: float,
	rng: RandomNumberGenerator
) -> Dictionary:
	if active:
		return {}
	var disable_context: Dictionary = get_disable_context(deps)
	var stun_active: bool = bool(disable_context.get("stun_active", false))
	var net_trapped: bool = bool(disable_context.get("net_trapped", false))
	if not stun_active and not net_trapped:
		episode_active = false
		attempted = false
		ready_remaining_sec = 0.0
		return {}
	if not episode_active:
		episode_active = true
		attempted = false
		ready_remaining_sec = NET_DELAY_SEC if net_trapped and not stun_active else 0.0
	elif ready_remaining_sec > 0.0:
		ready_remaining_sec = maxf(0.0, ready_remaining_sec - delta)
	if ready_remaining_sec > 0.000001 or attempted:
		return {}
	if (
		boss_gauge < GAUGE_COST
		or blocked_by_other_skill
		or bool(context.get("lingpet_puppet_grab_active", false))
	):
		return {}
	attempted = true
	var effective_chance := minf(
		1.0,
		TRIGGER_CHANCE * (1.0 + float(pity_failures))
	)
	if rng.randf() > effective_chance:
		pity_failures += 1
		return {}
	return try_start(
		context,
		deps,
		disable_context,
		false,
		boss_gauge,
		blocked_by_other_skill,
		odin_knockback_rewind_x
	)


func try_start(
	context: Dictionary,
	deps: Dictionary,
	disable_context: Dictionary,
	free_cast: bool,
	boss_gauge: float,
	blocked_by_other_skill: bool,
	odin_knockback_rewind_x: float = 0.0
) -> Dictionary:
	if (
		active
		or blocked_by_other_skill
		or bool(context.get("lingpet_puppet_grab_active", false))
		or (not free_cast and boss_gauge < GAUGE_COST)
	):
		return {}
	var context_boss_pos: Vector2 = _as_vector2(
		context.get("boss_pos", Vector2(330.0, 25.0)),
		Vector2(330.0, 25.0)
	)
	context_boss_pos.x -= odin_knockback_rewind_x
	var context_boss_size: Vector2 = _as_vector2(
		context.get("boss_paddle_size", Vector2(
			float(context.get("boss_paddle_width", 100.0)),
			float(context.get("boss_hitbox_height", 40.0))
		)),
		Vector2(100.0, 40.0)
	)
	var ball_pos: Vector2 = _as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO)
	var ball_center_x: float = ball_pos.x
	var boss_center_x: float = context_boss_pos.x + context_boss_size.x * 0.5
	var play_left: float = float(context.get("play_left", 0.0))
	var play_right: float = float(context.get("play_right", context.get("width", FIELD_WIDTH)))
	var left_space: float = maxf(0.0, context_boss_pos.x - play_left)
	var right_space: float = maxf(
		0.0,
		play_right - (context_boss_pos.x + context_boss_size.x)
	)
	var direction := -1.0 if ball_center_x >= boss_center_x else 1.0
	var chosen_space: float = left_space if direction < 0.0 else right_space
	if chosen_space < SIDE_MIN_SPACE:
		direction = -1.0 if left_space > right_space else 1.0
		chosen_space = left_space if direction < 0.0 else right_space
	var distance: float = (
		minf(MAX_DISTANCE, chosen_space - WALL_MARGIN)
		if chosen_space > WALL_MARGIN * 2.0
		else chosen_space
	)
	if distance < SIDE_MIN_SPACE:
		distance = maxf(FALLBACK_MIN_DISTANCE, chosen_space * 0.7)
	var target_x: float = clampf(
		context_boss_pos.x + direction * distance,
		play_left,
		play_right - context_boss_size.x
	)

	active = true
	pity_failures = 0
	elapsed_sec = 0.0
	start_boss_pos = context_boss_pos
	target_boss_pos = Vector2(target_x, context_boss_pos.y)
	boss_size = context_boss_size
	visual_scale = clampf(float(context.get("boss_paddle_shrink_scale", 1.0)), 0.2, 1.0)
	episode_active = true
	attempted = true
	ready_remaining_sec = 0.0
	var stun_remaining_sec: float = maxf(
		0.0,
		float(disable_context.get("stun_remaining_sec", 0.0))
	)
	var hologram_total_sec: float = stun_remaining_sec + HOLOGRAM_FADE_SEC
	hologram_draw_context = {
		"active": true,
		"center": context_boss_pos + context_boss_size * 0.5,
		"size": context_boss_size,
		"visual_scale": visual_scale,
		"alpha": 180.0 / 255.0,
		"remaining_sec": hologram_total_sec,
		"total_sec": hologram_total_sec,
	}
	_refresh_afterimages()
	last_released_net_count = clear_disable_effects(deps)
	return {
		"started": true,
		"boss_gauge": boss_gauge if free_cast else maxf(0.0, boss_gauge - GAUGE_COST),
		"attack_target_x": target_boss_pos.x + context_boss_size.x * 0.5,
		"released_net_count": last_released_net_count,
	}


func advance(delta: float) -> Dictionary:
	if not active:
		return {}
	elapsed_sec = minf(DURATION_SEC, elapsed_sec + delta)
	_refresh_afterimages()
	if elapsed_sec + 0.000001 < DURATION_SEC:
		return {}
	active = false
	elapsed_sec = DURATION_SEC
	afterimages.clear()
	episode_active = false
	attempted = false
	ready_remaining_sec = 0.0
	return {
		"released": true,
		"release_pos": target_boss_pos,
	}


func update_hologram(delta: float) -> void:
	if hologram_draw_context.is_empty():
		return
	var remaining_sec: float = maxf(
		0.0,
		float(hologram_draw_context.get("remaining_sec", 0.0)) - delta
	)
	if remaining_sec <= 0.000001:
		hologram_draw_context.clear()
		return
	hologram_draw_context["remaining_sec"] = remaining_sec
	var fade_ratio := 1.0
	if remaining_sec <= HOLOGRAM_FADE_SEC:
		fade_ratio = remaining_sec / HOLOGRAM_FADE_SEC
	hologram_draw_context["alpha"] = (180.0 / 255.0) * clampf(fade_ratio, 0.0, 1.0)


func get_disable_context(deps: Dictionary) -> Dictionary:
	var stun_active := false
	var stun_remaining_frames := 0.0
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("get_status"):
		var status_stun: Variant = status_state.get_status("boss", "stun")
		if status_stun is Dictionary and not (status_stun as Dictionary).is_empty():
			stun_active = true
			stun_remaining_frames = maxf(
				stun_remaining_frames,
				float((status_stun as Dictionary).get("remaining_frames", 0.0))
			)
	for runtime_key in ["active_item_runtime", "mythic_item_runtime"]:
		var runtime: Object = deps.get(runtime_key, null)
		if runtime == null or not runtime.has_method("get_boss_disable_context"):
			continue
		var runtime_context: Variant = runtime.get_boss_disable_context()
		if runtime_context is Dictionary and bool((runtime_context as Dictionary).get("stun_active", false)):
			stun_active = true
			stun_remaining_frames = maxf(
				stun_remaining_frames,
				float((runtime_context as Dictionary).get("stun_remaining_frames", 0.0))
			)
	var net_count := 0
	var commando_runtime: Object = deps.get("commando_firearm_runtime", null)
	if commando_runtime != null and commando_runtime.has_method("get_boss_net_trap_context"):
		var net_context: Variant = commando_runtime.get_boss_net_trap_context()
		if net_context is Dictionary:
			net_count = max(0, int((net_context as Dictionary).get(
				"trapped_count",
				(net_context as Dictionary).get("count", 0)
			)))
			if bool((net_context as Dictionary).get("boss_trapped", false)):
				net_count = maxi(1, net_count)
	return {
		"stun_active": stun_active,
		"stun_remaining_sec": stun_remaining_frames / LEGACY_FPS,
		"net_trapped": net_count > 0,
		"net_count": net_count,
	}


func clear_disable_effects(deps: Dictionary) -> int:
	var status_state: Object = deps.get("status_effect_state", null)
	if status_state != null and status_state.has_method("clear_status"):
		status_state.clear_status("boss", "stun")
	var active_runtime: Object = deps.get("active_item_runtime", null)
	if active_runtime != null and active_runtime.has_method("clear_boss_disable_effects"):
		active_runtime.clear_boss_disable_effects()
	var mythic_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_runtime != null and mythic_runtime.has_method("clear_boss_disable_effects_for_escape"):
		mythic_runtime.clear_boss_disable_effects_for_escape(deps.get("registry", null))
	elif mythic_runtime != null and mythic_runtime.has_method("clear_boss_disable_effects"):
		mythic_runtime.clear_boss_disable_effects(deps.get("registry", null))
	var commando_runtime: Object = deps.get("commando_firearm_runtime", null)
	if commando_runtime != null and commando_runtime.has_method("release_boss_net_traps"):
		return max(0, int(commando_runtime.release_boss_net_traps()))
	return 0


func get_boss_pos() -> Vector2:
	var progress: float = clampf(elapsed_sec / DURATION_SEC, 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 2.0)
	return start_boss_pos.lerp(target_boss_pos, eased)


func _refresh_afterimages() -> void:
	afterimages.clear()
	if not active:
		return
	for index in range(GHOST_COUNT):
		var delay_sec: float = float(index) * GHOST_DELAY_SEC
		var local_elapsed: float = elapsed_sec - delay_sec
		if local_elapsed < 0.0:
			continue
		var duration_sec: float = maxf(0.001, DURATION_SEC - delay_sec)
		var progress: float = clampf(local_elapsed / duration_sec, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 2.0)
		var alpha: float = float(255 - index * 40) / 255.0
		if progress > 0.70:
			alpha *= clampf((1.0 - progress) / 0.30, 0.0, 1.0)
		var ghost_pos: Vector2 = start_boss_pos.lerp(target_boss_pos, eased)
		afterimages.append({
			"kind": "escape",
			"index": index,
			"center": ghost_pos + boss_size * 0.5,
			"size": boss_size,
			"visual_scale": visual_scale,
			"alpha": alpha,
			"progress": progress,
		})


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
