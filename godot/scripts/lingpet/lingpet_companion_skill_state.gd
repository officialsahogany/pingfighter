extends RefCounted

var cooldown := 0.0
# S2 permit: interaction_permit 슬롯은 공유 쿨다운을 전달받지 않는다 (수신 면역).
# egg runtime이 프로필 경유로 매 프레임 동기화한다 — 장착 교체를 따라간다.
var shared_cooldown_immune := false
var flash_timer := 0.0
var trigger_count := 0
var last_gain := 0.0
var windup_active := false
var windup_elapsed := 0.0
var origin := Vector2.ZERO


func advance(delta: float) -> void:
	var safe_delta: float = maxf(0.0, delta)
	cooldown = maxf(0.0, cooldown - safe_delta)
	flash_timer = maxf(0.0, flash_timer - safe_delta)


func reset_all() -> void:
	cooldown = 0.0
	flash_timer = 0.0
	trigger_count = 0
	last_gain = 0.0
	cancel_windup()
	origin = Vector2.ZERO


func reset_round_transients() -> void:
	cancel_windup()
	flash_timer = 0.0


func cancel_windup() -> void:
	windup_active = false
	windup_elapsed = 0.0


func can_arm() -> bool:
	return cooldown <= 0.0 and not windup_active


func arm_windup() -> void:
	windup_active = true
	windup_elapsed = 0.0
	flash_timer = 0.0


func advance_windup(delta: float, windup_seconds: float) -> bool:
	if not windup_active:
		return false
	windup_elapsed += maxf(0.0, delta)
	return windup_elapsed >= maxf(0.0, windup_seconds)


func complete_launch(launch_origin: Vector2, cooldown_seconds: float, flash_seconds: float) -> void:
	cancel_windup()
	last_gain = 0.0
	trigger_count += 1
	cooldown = maxf(0.0, cooldown_seconds)
	flash_timer = maxf(0.0, flash_seconds)
	origin = launch_origin


func get_persistent_snapshot() -> Dictionary:
	return {
		"cooldown": cooldown,
		"trigger_count": trigger_count,
		"last_gain": last_gain,
		"origin": origin,
	}


func apply_persistent_snapshot(snapshot: Dictionary) -> void:
	reset_all()
	cooldown = maxf(0.0, float(snapshot.get("cooldown", 0.0)))
	trigger_count = maxi(0, int(snapshot.get("trigger_count", 0)))
	last_gain = maxf(0.0, float(snapshot.get("last_gain", 0.0)))
	var origin_value: Variant = snapshot.get("origin", Vector2.ZERO)
	origin = origin_value if origin_value is Vector2 else Vector2.ZERO


func get_flash_ratio(flash_seconds: float) -> float:
	if flash_seconds <= 0.0:
		return 0.0
	return clampf(flash_timer / flash_seconds, 0.0, 1.0)


func get_windup_frame(windup_seconds: float, frame_count: int) -> int:
	var max_frame: int = maxi(0, frame_count - 1)
	if windup_seconds <= 0.0:
		return max_frame
	var progress: float = clampf(windup_elapsed / windup_seconds, 0.0, 1.0)
	return clampi(int(progress * float(frame_count)), 0, max_frame)


func get_snapshot(
	companion_active: bool,
	skill_id: String,
	skill_cooldown_duration: float,
	skill_windup_seconds: float,
	flash_seconds: float,
	key_suffix: String = ""
) -> Dictionary:
	var suffix := key_suffix.strip_edges()
	var snapshot := {}
	snapshot["companion_skill_cooldown%s" % suffix] = cooldown
	snapshot["companion_skill_cooldown_duration%s" % suffix] = skill_cooldown_duration
	snapshot["companion_skill_windup_seconds%s" % suffix] = skill_windup_seconds if companion_active else 0.0
	snapshot["companion_skill_windup_ratio%s" % suffix] = _get_windup_ratio(companion_active, skill_windup_seconds)
	snapshot["companion_skill_ready%s" % suffix] = companion_active and skill_id != "" and cooldown <= 0.0
	snapshot["companion_skill_last_gain%s" % suffix] = last_gain
	snapshot["companion_skill_trigger_count%s" % suffix] = trigger_count
	snapshot["companion_skill_flash_timer%s" % suffix] = flash_timer
	snapshot["companion_skill_flash_ratio%s" % suffix] = get_flash_ratio(flash_seconds)
	snapshot["companion_skill_winding_up%s" % suffix] = windup_active
	snapshot["companion_skill_origin%s" % suffix] = origin
	return snapshot


func _get_windup_ratio(companion_active: bool, skill_windup_seconds: float) -> float:
	if not companion_active or not windup_active:
		return 0.0
	if skill_windup_seconds <= 0.0:
		return 1.0
	return clampf(windup_elapsed / skill_windup_seconds, 0.0, 1.0)
