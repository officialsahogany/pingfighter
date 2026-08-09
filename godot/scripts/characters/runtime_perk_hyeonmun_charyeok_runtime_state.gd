extends RefCounted

const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")
const PerkConversionFlags := preload("res://scripts/characters/perk_conversion_flags.gd")
const RuntimePerkHyeonmunCharyeokState := preload("res://scripts/characters/runtime_perk_hyeonmun_charyeok_state.gd")
const RuntimePerkHyeonmunCharyeokRenderer := preload("res://scripts/characters/runtime_perk_hyeonmun_charyeok_renderer.gd")

var _state: Object = RuntimePerkHyeonmunCharyeokState.new()
var _renderer: Object = RuntimePerkHyeonmunCharyeokRenderer.new()


func get_state() -> Object:
	return _state


func set_state(value: Object) -> void:
	_state = value


func get_renderer() -> Object:
	return _renderer


func set_renderer(value: Object) -> void:
	_renderer = value


func try_proc_from_runtime_state(
	runtime_state: Object,
	context: Dictionary = {},
	deps: Dictionary = {}
) -> Dictionary:
	if runtime_state == null or not PerkConversionFlags.is_enabled():
		return {"activated": false, "reason": "conversion_disabled"}
	var invested_level := maxi(
		0,
		RuntimePerkRuntimeStateAccess.call_int(
			runtime_state,
			"_get_raw_runtime_perk_level",
			[RuntimePerkHyeonmunCharyeokState.PERK_ID]
		)
	)
	var roll_unit := float(context.get(RuntimePerkHyeonmunCharyeokState.ROLL_OVERRIDE_KEY, -1.0))
	var result: Dictionary = _state.try_proc(invested_level, roll_unit)
	if bool(result.get("activated", false)):
		_sync_effective_level_bonus(
			runtime_state,
			int(result.get("previous_level_bonus", 0)),
			deps
		)
		result["item_perk_level_bonus"] = RuntimePerkRuntimeStateAccess.call_int(
			runtime_state,
			"get_item_perk_level_bonus"
		)
	return result


func update_from_runtime_state(
	runtime_state: Object,
	delta: float,
	owner: Object = null,
	registry: Object = null
) -> bool:
	var update_result: Dictionary = _state.update(delta)
	if bool(update_result.get("expired", false)):
		_sync_effective_level_bonus(
			runtime_state,
			int(update_result.get("previous_level_bonus", 0)),
			{"owner": owner, "registry": registry}
		)
	return bool(update_result.get("was_active", false))


func reset_round_from_runtime_state(
	runtime_state: Object,
	registry: Object = null,
	owner: Object = null
) -> bool:
	var reset_result: Dictionary = _state.reset()
	if not bool(reset_result.get("changed", false)):
		return false
	_sync_effective_level_bonus(
		runtime_state,
		int(reset_result.get("previous_level_bonus", 0)),
		{"owner": owner, "registry": registry}
	)
	return true


func reset_state() -> void:
	_state.reset()


func is_active() -> bool:
	return bool(_state.is_active())


func get_level_bonus() -> int:
	return int(_state.get_level_bonus())


func get_snapshot() -> Dictionary:
	return _state.get_snapshot()


func draw_timer(canvas: CanvasItem, timer_stack: Object = null) -> void:
	_renderer.draw(canvas, timer_stack, get_snapshot())


func _sync_effective_level_bonus(
	runtime_state: Object,
	previous_bonus: int,
	deps: Dictionary
) -> void:
	if runtime_state == null:
		return
	var registry: Object = deps.get("registry", null)
	var owner: Object = deps.get("owner", null)
	var mythic_item_runtime: Object = deps.get("mythic_item_runtime", null)
	if mythic_item_runtime == null:
		mythic_item_runtime = RuntimePerkRuntimeStateAccess.call_object(
			runtime_state,
			"_get_instance",
			[registry, "mythic_item_runtime"]
		)
	var next_total := maxi(
		0,
		RuntimePerkRuntimeStateAccess.call_int(runtime_state, "get_item_perk_level_bonus")
			- maxi(0, previous_bonus)
			+ get_level_bonus()
	)
	if PerkConversionFlags.is_enabled() and mythic_item_runtime != null:
		var crown_bonus := 0
		if mythic_item_runtime.has_method("get_transcendent_crown_skill_bonus"):
			crown_bonus = maxi(0, int(mythic_item_runtime.get_transcendent_crown_skill_bonus()))
		next_total = crown_bonus + get_level_bonus()
	elif (
		mythic_item_runtime != null
		and mythic_item_runtime.has_method("get_total_item_perk_level_bonus")
	):
		next_total = maxi(0, int(mythic_item_runtime.get_total_item_perk_level_bonus()))
	if RuntimePerkRuntimeStateAccess.call_bool(
		runtime_state,
		"set_item_perk_level_bonus",
		[next_total]
	):
		if runtime_state.has_method("refresh_item_perk_level_bonus_dynamic_effects"):
			runtime_state.call(
				"refresh_item_perk_level_bonus_dynamic_effects",
				registry,
				owner
			)
