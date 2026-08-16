extends RefCounted

const GameplayLoopAudioCleanup := preload(
	"res://scripts/audio/gameplay_loop_audio_cleanup.gd"
)

var _active := false
var _owner: Object = null
var _registry: Object = null
var _runtime_perk_state: Object = null


func enter(owner: Object, registry: Object) -> Dictionary:
	if _active:
		return {"accepted": true, "changed": false, "reason": "already_active"}
	# Unit-level flow fixtures do not own the battle module registry. The only
	# production entry point passes it explicitly and is sealed by the focused
	# match-flow smoke below.
	if owner == null or registry == null:
		return {"accepted": true, "changed": false, "reason": "headless_fixture"}
	var runtime_state := _get_instance(registry, "runtime_perk_state")
	if not _has_required_runtime_contract(runtime_state):
		return {"accepted": false, "changed": false, "reason": "missing_modal_runtime_contract"}
	runtime_state.call("_capture_resume_pre_choice_velocity", owner)
	runtime_state.call("_pause_skill_cooldowns_for_choice", owner, registry)
	var audio := _get_instance(registry, "game_audio")
	GameplayLoopAudioCleanup.stop_all(audio)
	_active = true
	_owner = owner
	_registry = registry
	_runtime_perk_state = runtime_state
	return {"accepted": true, "changed": true, "reason": "entered"}


func leave() -> Dictionary:
	if not _active:
		return {"accepted": true, "changed": false, "reason": "already_inactive"}
	var runtime_state := _runtime_perk_state
	if _has_required_runtime_contract(runtime_state):
		runtime_state.call("_resume_skill_cooldowns_for_choice")
		runtime_state.call("_try_arm_resume_safety", _owner, _registry)
	_active = false
	_owner = null
	_registry = null
	_runtime_perk_state = null
	return {"accepted": true, "changed": true, "reason": "left"}


func is_active() -> bool:
	return _active


func _has_required_runtime_contract(runtime_state: Object) -> bool:
	if runtime_state == null:
		return false
	for method_name in [
		"_capture_resume_pre_choice_velocity",
		"_pause_skill_cooldowns_for_choice",
		"_resume_skill_cooldowns_for_choice",
		"_try_arm_resume_safety",
	]:
		if not runtime_state.has_method(method_name):
			return false
	return true


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null:
		return null
	for method_name in ["get_instance", "get_cached_instance"]:
		if not registry.has_method(method_name):
			continue
		var value: Variant = registry.call(method_name, key)
		if value is Object and value != null:
			return value as Object
	return null
