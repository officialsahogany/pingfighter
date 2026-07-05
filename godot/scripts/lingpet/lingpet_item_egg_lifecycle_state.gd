extends RefCounted

const LingpetCurrentProfile := preload("res://scripts/lingpet/lingpet_current_profile.gd")

var active := false
var pet_id := ""
var awaiting_absorb := false
var absorb_ready := false
var absorb_pet_id := ""
var absorb_origin := Vector2.ZERO
var _profile: Object = LingpetCurrentProfile.new()


func reset() -> void:
	active = false
	pet_id = ""
	awaiting_absorb = false
	absorb_ready = false
	absorb_pet_id = ""
	absorb_origin = Vector2.ZERO
	_profile.set_pet_id("")


func clear_runtime_state(egg_state: Object, absorb_vfx: Object, acquire_cutin_state: Object) -> void:
	reset()
	if egg_state != null and egg_state.has_method("reset_all"):
		egg_state.call("reset_all")
	if absorb_vfx != null and absorb_vfx.has_method("reset"):
		absorb_vfx.call("reset")
	if acquire_cutin_state != null and acquire_cutin_state.has_method("clear_display_pet_id"):
		acquire_cutin_state.call("clear_display_pet_id")


func advance_incubation_for_reveal(
	delta: float,
	owner: Object,
	registry: Object,
	egg_state: Object,
	required_hits_fallback: int,
	on_ball_hit: Callable = Callable()
) -> String:
	if not is_active() or egg_state == null:
		return ""
	if egg_state.has_method("update_player_contact"):
		egg_state.call("update_player_contact", delta, owner, registry)
	var hit_result: Dictionary = {}
	if egg_state.has_method("resolve_ball_hit"):
		# The egg state's own spawn-time required-hits roll wins; the incubating
		# pet's profile value is only the fallback for unrolled states.
		var required_hits: int = get_required_hits(required_hits_fallback)
		if egg_state.has_method("get_required_hits"):
			required_hits = int(egg_state.call("get_required_hits", required_hits))
		var raw_hit_result: Variant = egg_state.call(
			"resolve_ball_hit",
			owner,
			required_hits
		)
		if raw_hit_result is Dictionary:
			hit_result = raw_hit_result as Dictionary
	# 공에 맞은 프레임마다 히트 콜백을 울린다(메인 알과 대칭 — 부화 여부와 무관).
	if bool(hit_result.get("hit", false)) and on_ball_hit.is_valid():
		on_ball_hit.call()
	if not bool(hit_result.get("hatched", false)):
		return ""
	var origin := Vector2.ZERO
	var raw_origin: Variant = egg_state.get("pos")
	if raw_origin is Vector2:
		origin = raw_origin
	var hatched_pet_id := str(finish_incubation_for_reveal(origin))
	if egg_state.has_method("reset_all"):
		egg_state.call("reset_all")
	if hatched_pet_id == "":
		return ""
	ensure_profile_pet_id(hatched_pet_id)
	return hatched_pet_id


func is_active() -> bool:
	return bool(active)


func get_pet_id() -> String:
	return str(pet_id)


func get_profile() -> Object:
	return _profile


func get_required_hits(fallback: int) -> int:
	return int(_profile.get_required_hits(fallback))


func ensure_profile_pet_id(new_pet_id: String) -> String:
	return str(_profile.set_pet_id(new_pet_id))


func has_blocking_incubation() -> bool:
	return bool(active) or bool(awaiting_absorb) or bool(absorb_ready)


func has_pending_absorb() -> bool:
	return bool(awaiting_absorb) or bool(absorb_ready)


func is_absorb_ready() -> bool:
	return bool(absorb_ready)


func begin_incubation(new_pet_id: String) -> bool:
	var normalized_pet_id := new_pet_id.strip_edges()
	if normalized_pet_id == "":
		return false
	active = true
	pet_id = normalized_pet_id
	_profile.set_pet_id(normalized_pet_id)
	awaiting_absorb = false
	absorb_ready = false
	absorb_pet_id = ""
	absorb_origin = Vector2.ZERO
	return true


func finish_incubation_for_reveal(origin: Vector2) -> String:
	var hatched_pet_id := str(pet_id)
	active = false
	pet_id = ""
	if hatched_pet_id == "":
		absorb_origin = Vector2.ZERO
		return ""
	absorb_origin = origin
	absorb_pet_id = hatched_pet_id
	awaiting_absorb = true
	absorb_ready = false
	return hatched_pet_id


func mark_absorb_ready_if_awaiting() -> bool:
	if not bool(awaiting_absorb):
		return false
	absorb_ready = true
	return true


func consume_ready_absorb() -> Dictionary:
	var context := {
		"ready": bool(absorb_ready),
		"pet_id": str(absorb_pet_id),
		"origin": absorb_origin,
	}
	awaiting_absorb = false
	absorb_ready = false
	absorb_pet_id = ""
	absorb_origin = Vector2.ZERO
	return context
