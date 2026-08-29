extends RefCounted

const RuntimePerkChoiceCompletion := preload("res://scripts/characters/runtime_perk_choice_completion.gd")
const RuntimePerkPayloadAccess := preload("res://scripts/characters/runtime_perk_payload_access.gd")
const RuntimePerkRuntimeStateAccess := preload("res://scripts/characters/runtime_perk_runtime_state_access.gd")

var _choice_completion: Object = RuntimePerkChoiceCompletion.new()


func build(state: Object, starpoint_absorption: Object, deferred_instants: Object) -> Dictionary:
	if state == null:
		return {}
	return {
		"runtime_skill_levels": RuntimePerkPayloadAccess.copy_dict(state.get("runtime_skill_levels")),
		"effective_runtime_skill_levels": RuntimePerkRuntimeStateAccess.call_dict(state, "get_effective_runtime_skill_levels"),
		"starpoint_for_skills": int(state.get("starpoint_for_skills")),
		"pending_skill_choices": int(state.get("pending_skill_choices")),
		"choice_active": bool(state.get("choice_active")),
		"current_choices": RuntimePerkPayloadAccess.copy_array(state.get("current_choices")),
		"selected_index": int(state.get("selected_index")),
		"animation_time": float(state.get("animation_time")),
		"particles": RuntimePerkPayloadAccess.as_array(state.get("particles")),
		"gold_from_perks": int(state.get("gold_from_perks")),
		"item_gold_gain_multiplier": float(state.get("item_gold_gain_multiplier")),
		"item_perk_level_bonus": int(state.get("item_perk_level_bonus")),
		"viper_ignition_aura_active": bool(state.get("viper_ignition_aura_active")),
		"tower_bag_expansion_count": RuntimePerkRuntimeStateAccess.call_int(
			state,
			"get_tower_bag_expansion_count"
		),
		"viper_ignition_aura_level_bonus": RuntimePerkRuntimeStateAccess.call_int(state, "get_viper_ignition_aura_level_bonus"),
		"viper_ignition_aura_gold_bonus": RuntimePerkRuntimeStateAccess.call_int(state, "get_viper_ignition_aura_gold_bonus"),
		"hyeonmun_charyeok": RuntimePerkRuntimeStateAccess.call_dict(state, "get_hyeonmun_charyeok_snapshot"),
		"pending_unlock_swap": RuntimePerkPayloadAccess.copy_dict(state.get("pending_unlock_swap")),
		"unlock_swap_selected_index": int(state.get("unlock_swap_selected_index")),
		"choice_flight_effect": RuntimePerkPayloadAccess.copy_dict(state.get("choice_flight_effect")),
		"unlock_showcase": RuntimePerkPayloadAccess.copy_dict(state.get("unlock_showcase")),
		"starpoint_absorption_effect": RuntimePerkRuntimeStateAccess.call_dict(starpoint_absorption, "get_snapshot"),
		"feedback_text": RuntimePerkPayloadAccess.get_string(state, "feedback_text"),
		"feedback_timer": float(state.get("feedback_timer")),
		"last_selected_id": RuntimePerkPayloadAccess.get_string(state, "last_selected_id"),
		"last_selected_choice": RuntimePerkPayloadAccess.copy_dict(state.get("last_selected_choice")),
		"selected_choice_sequence": int(state.get("selected_choice_sequence")),
		"current_choice_context": RuntimePerkPayloadAccess.copy_dict(state.get("current_choice_context")),
		"perk_slot_status": RuntimePerkPayloadAccess.copy_dict(state.get("current_perk_slot_status")),
		# 융합 표시 projection(접힘 정본): TAB/오버레이 소비자가 스냅샷에서
		# 그대로 읽는다 — state 소유 기본 카탈로그로 캐시 경유(핫패스 안전).
		"perk_fusion_display_projection": RuntimePerkRuntimeStateAccess.call_dict(state, "get_perk_fusion_display_projection"),
		# 융합 core: 정본 리비전 + 세이브/복원용 record 스냅샷(딥카피).
		"fusion_revision": RuntimePerkRuntimeStateAccess.call_int(state, "get_perk_fusion_revision"),
		"perk_fusion": RuntimePerkRuntimeStateAccess.call_dict(state, "get_perk_fusion_snapshot"),
		# 주사위: 게임플레이 상태 스냅샷 + 전용 표시 projection + 정본 revision
		# — 소비자는 합성 채널(perk_fusion_display_projection)에 병합된 dice
		# synthetic 엔트리를 기본으로 읽고, 전용 채널은 dice 전용 UI가 쓴다.
		"mystic_dice": RuntimePerkRuntimeStateAccess.call_dict(state, "get_mystic_dice_snapshot"),
		"mystic_dice_revision": RuntimePerkRuntimeStateAccess.call_int(state, "get_mystic_dice_revision"),
		"mystic_dice_display_projection": RuntimePerkRuntimeStateAccess.call_dict(state, "get_mystic_dice_display_projection"),
		"physique_training": RuntimePerkRuntimeStateAccess.call_dict(state, "get_physique_training_snapshot"),
		"angel_blessing": RuntimePerkRuntimeStateAccess.call_dict(state, "get_angel_blessing_snapshot"),
		"angel_blessing_acquisition": RuntimePerkRuntimeStateAccess.call_dict(state, "get_angel_blessing_acquisition_snapshot"),
		"pending_dimension_gate_after_spawn_intro": RuntimePerkRuntimeStateAccess.call_bool(deferred_instants, "has_pending_dimension_gate"),
		"pending_dimension_gate_origin_stage": RuntimePerkRuntimeStateAccess.call_int(deferred_instants, "get_dimension_gate_origin_stage"),
		"pending_full_gauge_after_spawn_intro": RuntimePerkRuntimeStateAccess.call_bool(deferred_instants, "has_pending_full_gauge"),
		"pending_full_gauge_origin_stage": RuntimePerkRuntimeStateAccess.call_int(deferred_instants, "get_full_gauge_origin_stage"),
	}


func build_from_runtime_state(runtime_state: Object) -> Dictionary:
	return build(
		runtime_state,
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_starpoint_absorption"),
		RuntimePerkRuntimeStateAccess.get_object(runtime_state, "_deferred_instants")
	)


func build_selected_choice(choice_id: String, choice: Dictionary, runtime_skill_levels: Dictionary) -> Dictionary:
	return _choice_completion.build_selected_choice_snapshot(choice_id, choice, runtime_skill_levels)
