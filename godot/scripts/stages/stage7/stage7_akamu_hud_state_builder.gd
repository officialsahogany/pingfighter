extends RefCounted

# Pure Stage 7 boss-skill HUD projection.
#
# Skill owners retain their clocks and transaction rules. This builder owns
# only card order plus shared paused/blocked inputs passed into their existing
# build_hud_skill projections.


func build_skills(
	boss_gauge: float,
	awakened: bool,
	status: String,
	skill_cooldown_paused: bool,
	clone_state: Object,
	shuriken_state: Object,
	cloud_state: Object,
	escape_state: Object,
	superspeed_state: Object,
	motion_state: Object
) -> Array:
	var skill_paused := skill_cooldown_paused or status == "paused"
	var superspeed_active: bool = bool(superspeed_state.active)
	var escape_active: bool = bool(escape_state.active)
	var cloud_active: bool = bool(cloud_state.dash_active)
	var clone_active: bool = bool(clone_state.casting)
	var shuriken_active: bool = bool(shuriken_state.casting)

	var clone_blocked := (
		shuriken_active
		or cloud_active
		or escape_active
		or superspeed_active
	)
	var shuriken_blocked := (
		clone_active
		or int(clone_state.get_live_count()) > 0
		or cloud_active
		or escape_active
		or superspeed_active
	)
	var cloud_blocked: bool = motion_state.has_scripted_skill_conflict_fields(
		"cloud",
		escape_active,
		cloud_active,
		superspeed_active,
		clone_active,
		shuriken_active
	)
	var superspeed_blocked := (
		escape_active
		or bool(motion_state.external_scripted_motion_active)
	)

	return [
		clone_state.build_hud_skill(boss_gauge, skill_paused, clone_blocked),
		shuriken_state.build_hud_skill(boss_gauge, skill_paused, shuriken_blocked),
		cloud_state.build_hud_skill(boss_gauge, skill_paused, cloud_blocked),
		superspeed_state.build_hud_skill(
			boss_gauge,
			awakened,
			skill_paused,
			superspeed_blocked
		),
	]
