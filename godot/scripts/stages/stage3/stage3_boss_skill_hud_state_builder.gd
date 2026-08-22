extends RefCounted

const Stage3CurseChestState := preload("res://scripts/stages/stage3/stage3_curse_chest_state.gd")
const Stage3PsychoballState := preload("res://scripts/stages/stage3/stage3_psychoball_state.gd")
const Stage3TearShowerState := preload("res://scripts/stages/stage3/stage3_tear_shower_state.gd")
const StageBossVariantCatalog := preload("res://scripts/stages/common/stage_boss_variant_catalog.gd")

# Pure Stage 3 boss-skill HUD projection. Skill owners retain their clocks and
# activation transactions; this builder owns only the public payload shape,
# authored card order, labels/colors, and cooldown progress/status projection.


func build_context(
	host_status: String,
	boss_gauge: float,
	boss_gauge_max: float,
	tear_shower_state: Object,
	curse_chest_state: Object,
	psychoball_state: Object,
	stage_boss_variant: String = "yeonmyo"
) -> Dictionary:
	var boss_entry: Dictionary = StageBossVariantCatalog.get_entry(3, stage_boss_variant)
	return {
		"stage3_boss_skill_hud_active": true,
		"stage3_boss_skill_hud_boss_name": str(boss_entry.get("display_name", "보스")),
		"stage3_boss_skill_hud_status": host_status,
		"stage3_boss_skill_hud_boss_gauge": boss_gauge,
		"stage3_boss_skill_hud_boss_gauge_max": boss_gauge_max,
		"stage3_boss_skill_hud_boss_gauge_progress": clamp(
			boss_gauge / max(0.001, boss_gauge_max),
			0.0,
			1.0
		),
		"stage3_boss_skill_hud_show_boss_gauge": false,
		"stage3_boss_skill_hud_skills": [
			_build_cooldown_skill(
				"tear_shower",
				"환루천우",
				bool(tear_shower_state.tears_active),
				float(tear_shower_state.tears_cooldown),
				Stage3TearShowerState.COOLDOWN_SEC,
				Color(0.29, 0.66, 0.56, 1.0)
			),
			_build_cooldown_skill(
				"curse_chest",
				"봉혼궤",
				str(curse_chest_state.curse_phase) != "idle",
				float(curse_chest_state.curse_cooldown),
				Stage3CurseChestState.COOLDOWN_SEC,
				Color(0.75, 0.24, 0.16, 1.0)
			),
			_build_psychoball_skill(psychoball_state),
		],
	}


func _build_psychoball_skill(psychoball_state: Object) -> Dictionary:
	var active: bool = bool(psychoball_state.overdrive_active)
	var cooldown: float = float(psychoball_state.psycho_cooldown)
	return {
		"id": "psycho_ball",
		"label": "환구전이",
		"status": "casting" if active else ("ready" if cooldown <= 0.0 else "charging"),
		"cooldown_remaining": cooldown,
		"cooldown_total": Stage3PsychoballState.COOLDOWN_SEC,
		"progress": 1.0 if active else _cooldown_progress(cooldown, Stage3PsychoballState.COOLDOWN_SEC),
		"ready": not active and cooldown <= 0.0,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": "hit",
		"color": Color(0.88, 0.62, 0.22, 1.0),
	}


func _build_cooldown_skill(
	id: String,
	label: String,
	active: bool,
	cooldown: float,
	total: float,
	color: Color
) -> Dictionary:
	var status_text := "casting" if active else ("ready" if cooldown <= 0.0 else "charging")
	return {
		"id": id,
		"label": label,
		"status": status_text,
		"cooldown_remaining": cooldown,
		"cooldown_total": total,
		"progress": 1.0 if active else _cooldown_progress(cooldown, total),
		"ready": status_text == "ready",
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"trigger_type": "auto",
		"color": color,
	}


func _cooldown_progress(remaining: float, total: float) -> float:
	return clamp(1.0 - max(0.0, remaining) / max(0.001, total), 0.0, 1.0)
