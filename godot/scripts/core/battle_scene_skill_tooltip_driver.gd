extends RefCounted

const BattleSceneOwnerReader := preload("res://scripts/core/battle_scene_owner_reader.gd")
const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")

# 퍽 선택 모달은 물리 프레임을 막지만 벽시계는 막지 못한다. 쿨타임 앵커만
# 밀어서는 부족하고, `Time.get_ticks_msec()` 에 걸린 **발동창 / 입력창 / 예약
# 시각**도 같이 밀어야 모달을 닫았을 때 스킬이 이어진다(풍운천선무 발동창이
# 퍽 고르는 사이에 만료되던 사례). 자세한 규칙은
# `res://scripts/core/runtime_perk_modal_time_shift.gd` 주석 참조.
#
# ⚠️새 스킬 상태가 벽시계 앵커를 가지면 여기에 **레지스트리 키를 등재하고**
# 그 상태에 `pause_runtime_perk_modal_time` / `resume_runtime_perk_modal_time`
# 를 구현해야 한다. 둘 중 하나만 하면 조용히 no-op 이다.
const RUNTIME_PERK_MODAL_TIME_STATE_KEYS: Array[String] = [
	"smasher_wheel_state",
	"smasher_warp_gate_state",
	"smasher_magnum_grip_state",
	"smasher_shield_kiting_state",
	"smasher_power_smash_state",
	"viper_skill_runtime",
	"commando_emergency_supply_state",
	"commando_weapon_controller",
	"commando_firearm_runtime",
	"blacksmith_thor_shield_state",
	"round_flow_state",
]

var _character_runtime: Object = PlayerCharacterRuntime.new()


func pause_skill_cooldowns(owner: Object, registry: Object) -> void:
	var current_msec: int = Time.get_ticks_msec()
	var skill_state: Object = _get_active_skill_state(owner, registry)
	if skill_state != null and skill_state.has_method("pause_cooldowns"):
		skill_state.pause_cooldowns(current_msec)
	_pause_active_item_cooldowns(owner, registry)
	_pause_runtime_perk_modal_time(registry, current_msec)


func resume_skill_cooldowns(owner: Object, registry: Object) -> void:
	var current_msec: int = Time.get_ticks_msec()
	var skill_state: Object = _get_active_skill_state(owner, registry)
	if skill_state != null and skill_state.has_method("resume_cooldowns"):
		skill_state.resume_cooldowns(current_msec)
	_resume_active_item_cooldowns(owner, registry)
	_resume_runtime_perk_modal_time(registry, current_msec)


func queue_tooltip_overlay_redraw(owner: Object, registry: Object) -> void:
	var overlay_host: Object = _get_instance(registry, "skill_orb_tooltip_overlay_host")
	if overlay_host != null and overlay_host.has_method("queue_redraw"):
		overlay_host.queue_redraw(owner, registry)


func cycle_gamepad_tooltip(owner: Object, registry: Object) -> bool:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state == null or not hover_state.has_method("cycle_gamepad_tooltip"):
		return false
	var result: Dictionary = hover_state.cycle_gamepad_tooltip(owner, registry)
	if not bool(result.get("handled", false)):
		return false
	if bool(result.get("active", false)):
		queue_tooltip_overlay_redraw(owner, registry)
	else:
		hide_tooltip_overlay(registry)
	return true


func hide_tooltip_overlay(registry: Object) -> void:
	var hover_state: Object = _get_instance(registry, "skill_orb_tooltip_hover_state")
	if hover_state != null and hover_state.has_method("clear_gamepad_tooltip_selection"):
		hover_state.clear_gamepad_tooltip_selection()
	var overlay_host: Object = _get_instance(registry, "skill_orb_tooltip_overlay_host")
	if overlay_host != null and overlay_host.has_method("hide"):
		overlay_host.hide()


func _get_active_skill_state(owner: Object, registry: Object) -> Object:
	if registry == null:
		return null
	var character_type: String = _character_runtime.normalize(str(
		BattleSceneOwnerReader.get_value(owner, "selected_character_type", "smasher")
	))
	return _get_instance(registry, _character_runtime.get_skill_state_key(character_type))


func _pause_active_item_cooldowns(owner: Object, registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("pause_cooldowns"):
		active_item_runtime.pause_cooldowns(owner, registry)


func _resume_active_item_cooldowns(owner: Object, registry: Object) -> void:
	var active_item_runtime: Object = _get_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("resume_cooldowns"):
		active_item_runtime.resume_cooldowns(owner, registry)


func _pause_runtime_perk_modal_time(registry: Object, current_msec: int) -> void:
	for state_key: String in RUNTIME_PERK_MODAL_TIME_STATE_KEYS:
		var state: Object = _get_cached_instance(registry, state_key)
		if state != null and state.has_method("pause_runtime_perk_modal_time"):
			state.pause_runtime_perk_modal_time(current_msec)
	var active_item_runtime: Object = _get_cached_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("pause_runtime_perk_modal_time"):
		active_item_runtime.pause_runtime_perk_modal_time(current_msec)


func _resume_runtime_perk_modal_time(registry: Object, current_msec: int) -> void:
	for state_key: String in RUNTIME_PERK_MODAL_TIME_STATE_KEYS:
		var state: Object = _get_cached_instance(registry, state_key)
		if state != null and state.has_method("resume_runtime_perk_modal_time"):
			state.resume_runtime_perk_modal_time(current_msec)
	var active_item_runtime: Object = _get_cached_instance(registry, "active_item_runtime")
	if active_item_runtime != null and active_item_runtime.has_method("resume_runtime_perk_modal_time"):
		active_item_runtime.resume_runtime_perk_modal_time(current_msec)


func _get_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "" or not registry.has_method("get_instance"):
		return null
	return registry.get_instance(key)


# 모달 개폐는 프레임당 경로는 아니지만, 여기서 `get_instance` 를 쓰면 아직 한
# 번도 안 쓴 캐릭터 / 아이템 모듈까지 전부 콜드 생성되어 모달 열림 프레임에
# 스톨이 얹힌다. 인스턴스가 없다 = 밀어야 할 살아있는 타이머도 없다는 뜻이므로
# 비-생성 peek 만 쓴다(핫패스 lazy-init 트랩).
func _get_cached_instance(registry: Object, key: String) -> Object:
	if registry == null or key == "":
		return null
	if not registry.has_method("get_cached_instance"):
		return _get_instance(registry, key)
	var cached: Variant = registry.get_cached_instance(key)
	if typeof(cached) == TYPE_OBJECT and is_instance_valid(cached):
		return cached as Object
	return null
