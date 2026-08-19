extends RefCounted

# Stage 7's single boss-position publication boundary.
#
# Skill owners retain their own trajectories. This coordinator composes those
# authored positions in one priority order, owns one-frame release delivery,
# and merges clone/external ball-intangibility contributors.

const RESERVED_CLONE_INTANGIBLE_SOURCE := "shadow_clone"

var boss_ball_intangible := false
var intangible_sources: Dictionary = {}
var scripted_motion_active := false
var scripted_boss_pos := Vector2.ZERO
var scripted_source := ""
var debug_scripted_motion_active := false
var debug_scripted_boss_pos := Vector2.ZERO
var external_scripted_motion_active := false
var release_pending := false
var release_pos := Vector2.ZERO


func reset_full() -> void:
	clear_round_transients()


func clear_round_transients() -> void:
	boss_ball_intangible = false
	intangible_sources.clear()
	scripted_motion_active = false
	scripted_boss_pos = Vector2.ZERO
	scripted_source = ""
	debug_scripted_motion_active = false
	debug_scripted_boss_pos = Vector2.ZERO
	external_scripted_motion_active = false
	release_pending = false
	release_pos = Vector2.ZERO


func begin_frame() -> void:
	# A completed motion owns exactly one advancing frame. Timing-freeze early
	# returns intentionally do not call this, matching the prior host behavior.
	release_pending = false


func set_external_scripted_motion_active(active: bool) -> void:
	external_scripted_motion_active = active


func set_boss_ball_intangible_source(
	source: String,
	active: bool,
	clone_intangible: bool
) -> void:
	var normalized_source := source.strip_edges()
	if normalized_source == "" or normalized_source == RESERVED_CLONE_INTANGIBLE_SOURCE:
		return
	if active:
		intangible_sources[normalized_source] = true
	else:
		intangible_sources.erase(normalized_source)
	refresh_boss_ball_intangible(clone_intangible)


func refresh_boss_ball_intangible(clone_intangible: bool) -> void:
	boss_ball_intangible = clone_intangible or not intangible_sources.is_empty()


func set_debug_scripted_position(active: bool, pos: Vector2 = Vector2.ZERO) -> void:
	debug_scripted_motion_active = active
	debug_scripted_boss_pos = pos if active else Vector2.ZERO


func refresh_scripted_motion(sources: Dictionary) -> void:
	if bool(sources.get("escape_active", false)):
		_set_scripted_source("escape", sources.get("escape_pos", Vector2.ZERO) as Vector2)
	elif bool(sources.get("cloud_active", false)):
		_set_scripted_source("cloud", sources.get("cloud_pos", Vector2.ZERO) as Vector2)
	elif bool(sources.get("clone_active", false)):
		_set_scripted_source("clone", sources.get("clone_pos", Vector2.ZERO) as Vector2)
	elif bool(sources.get("shuriken_active", false)):
		_set_scripted_source("shuriken", sources.get("shuriken_pos", Vector2.ZERO) as Vector2)
	elif debug_scripted_motion_active:
		_set_scripted_source("debug", debug_scripted_boss_pos)
	else:
		_set_scripted_source("", Vector2.ZERO)


func publish_release(pos: Vector2) -> void:
	release_pending = true
	release_pos = pos


func has_scripted_skill_conflict(
	requester: String,
	sources: Dictionary,
	superspeed_active: bool
) -> bool:
	return has_scripted_skill_conflict_fields(
		requester,
		bool(sources.get("escape_active", false)),
		bool(sources.get("cloud_active", false)),
		superspeed_active,
		bool(sources.get("clone_active", false)),
		bool(sources.get("shuriken_active", false))
	)


func has_scripted_skill_conflict_fields(
	requester: String,
	escape_active: bool,
	cloud_active: bool,
	superspeed_active: bool,
	clone_active: bool,
	shuriken_active: bool
) -> bool:
	if external_scripted_motion_active or release_pending:
		return true
	if requester != "escape" and escape_active:
		return true
	if requester != "cloud" and cloud_active:
		return true
	if requester != "superspeed" and superspeed_active:
		return true
	if requester != "clone" and clone_active:
		return true
	if requester != "shuriken" and shuriken_active:
		return true
	return debug_scripted_motion_active


func build_position_result(
	odin_knockback_window_active: bool,
	odin_stun_residual: float
) -> Dictionary:
	if scripted_motion_active:
		# Clone/shuriken pins run after BossAI. During Odin knockback they must
		# yield entirely; during the stun tail they preserve the AI residual on
		# top of the captured pin. Escape/cloud remain authoritative trajectories.
		var casting_pin_active := scripted_source == "clone" or scripted_source == "shuriken"
		if casting_pin_active and odin_knockback_window_active:
			return {}
		if casting_pin_active and absf(odin_stun_residual) > 0.0:
			return {
				"boss_pos": scripted_boss_pos + Vector2(odin_stun_residual, 0.0),
				"boss_vel": 0.0,
			}
		return {
			"boss_pos": scripted_boss_pos,
			"boss_vel": 0.0,
		}
	if release_pending:
		return {
			"boss_pos": release_pos,
			"boss_vel": 0.0,
		}
	return {}


func has_runtime_state() -> bool:
	return boss_ball_intangible \
		or scripted_motion_active \
		or debug_scripted_motion_active \
		or external_scripted_motion_active \
		or release_pending \
		or not intangible_sources.is_empty()


func get_snapshot() -> Dictionary:
	return {
		"boss_ball_intangible": boss_ball_intangible,
		"intangible_sources": intangible_sources.duplicate(),
		"scripted_motion_active": scripted_motion_active,
		"scripted_boss_pos": scripted_boss_pos,
		"scripted_source": scripted_source,
		"debug_scripted_motion_active": debug_scripted_motion_active,
		"external_scripted_motion_active": external_scripted_motion_active,
		"release_pending": release_pending,
		"release_pos": release_pos,
	}


func _set_scripted_source(source: String, pos: Vector2) -> void:
	scripted_source = source
	scripted_motion_active = source != ""
	scripted_boss_pos = pos if scripted_motion_active else Vector2.ZERO
