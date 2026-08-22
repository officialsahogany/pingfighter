extends RefCounted

const TetriserGuardState := preload("res://scripts/stages/stage6/stage6_tetriser_guard_state.gd")
const TetriserSuperState := preload("res://scripts/stages/stage6/stage6_tetriser_super_state.gd")
const TetriserTetrominoState := preload("res://scripts/stages/stage6/stage6_tetriser_tetromino_state.gd")
const TetriserWallState := preload("res://scripts/stages/stage6/stage6_tetriser_wall_state.gd")

const BOSS_NAME := "테트리서"


func build_context(
	boss_gauge: float,
	host_status: String,
	gauge_max: float,
	gauge_charge_per_sec: float,
	tetromino_state: Object,
	guard_state: Object,
	wall_state: Object,
	super_state: Object
) -> Dictionary:
	var super_active: bool = super_state.is_active()
	return {
		"stage6_boss_skill_hud_active": true,
		"stage6_boss_skill_hud_boss_name": BOSS_NAME,
		"stage6_boss_skill_hud_status": host_status,
		"stage6_boss_skill_hud_gauge": boss_gauge,
		"stage6_boss_skill_hud_gauge_max": gauge_max,
		"stage6_boss_skill_hud_super_active": super_active,
		"stage6_boss_skill_hud_skills": [
			_build_cost_skill(
				"stage6_tetro_drop",
				"낙하 테트로",
				Color(0.45, 0.70, 1.0),
				TetriserTetrominoState.GAUGE_COST,
				tetromino_state.get_timer_remaining(),
				tetromino_state.get_timer_total(),
				boss_gauge,
				gauge_charge_per_sec,
				super_active
			),
			_build_cost_skill(
				"stage6_guard",
				"가드 블록",
				TetriserGuardState.COLOR,
				TetriserGuardState.COST_SINGLE,
				guard_state.get_timer_remaining(),
				guard_state.get_timer_total(),
				boss_gauge,
				gauge_charge_per_sec,
				super_active
			),
			_build_cost_skill(
				"stage6_wall",
				"테트로 벽",
				Color(0.74, 0.62, 0.48),
				TetriserWallState.COST,
				wall_state.get_timer_remaining(),
				wall_state.get_timer_total(),
				boss_gauge,
				gauge_charge_per_sec,
				super_active
			),
			_build_super_skill(boss_gauge, super_active),
		],
	}


func _build_cost_skill(
	id: String,
	skill_name: String,
	color: Color,
	cost: float,
	timer_remaining: float,
	timer_total: float,
	boss_gauge: float,
	gauge_charge_per_sec: float,
	super_active: bool
) -> Dictionary:
	# Card progress follows the auto-fire timer. Gauge is only the secondary
	# activation gate after that timer reaches zero.
	var safe_total: float = maxf(0.001, timer_total)
	var remaining: float = maxf(0.0, timer_remaining)
	var progress: float = clampf(1.0 - remaining / safe_total, 0.0, 1.0)
	var timer_ready: bool = timer_remaining <= 0.0
	var gauge_ok: bool = boss_gauge >= cost
	var gauge_remaining: float = maxf(0.0, cost - boss_gauge)
	var gauge_remaining_seconds: float = gauge_remaining / maxf(0.001, gauge_charge_per_sec)
	var next_activation_remaining: float = maxf(remaining, gauge_remaining_seconds)
	var ready: bool = timer_ready and gauge_ok and not super_active
	var skill_status := "charging"
	if super_active or (timer_ready and not gauge_ok):
		skill_status = "paused"
	elif ready:
		skill_status = "ready"
	return {
		"id": id,
		"name": skill_name,
		"color": color,
		"cost": cost,
		"progress": progress,
		"cooldown_remaining": remaining,
		"cooldown_total": safe_total,
		"next_activation_remaining": next_activation_remaining,
		"ready": ready,
		"cooldown_contract": "time",
		"initial_ready_allowed": false,
		"active": false,
		"status": skill_status,
	}


func _build_super_skill(boss_gauge: float, super_active: bool) -> Dictionary:
	var ready: bool = boss_gauge >= TetriserSuperState.ACTIVATE_GAUGE and not super_active
	var remaining: float = maxf(0.0, TetriserSuperState.ACTIVATE_GAUGE - boss_gauge)
	return {
		"id": "stage6_super",
		"name": "초인테트리서",
		"color": Color(1.0, 0.45, 0.18),
		"progress": clampf(boss_gauge / TetriserSuperState.ACTIVATE_GAUGE, 0.0, 1.0),
		"cooldown_remaining": remaining,
		"cooldown_total": TetriserSuperState.ACTIVATE_GAUGE,
		"cooldown_contract": "resource_gauge",
		"initial_ready_allowed": false,
		"ready": ready,
		"active": super_active,
		"status": "casting" if super_active else ("ready" if ready else "charging"),
	}
