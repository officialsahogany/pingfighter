extends RefCounted

const PlayerCharacterRuntime := preload("res://scripts/characters/player_character_runtime.gd")
const Stage4PonkAwakenAuraFxHost := preload("res://scripts/stages/stage4/stage4_ponk_awaken_aura_fx_host.gd")


static func get_score_snapshot(registry: Object) -> Dictionary:
	var score_state: Object = get_instance(registry, "match_score_state")
	if score_state != null and score_state.has_method("get_snapshot"):
		var snapshot: Variant = score_state.get_snapshot()
		if snapshot is Dictionary:
			return snapshot

	var scoreboard_state: Object = get_instance(registry, "scoreboard_state")
	if scoreboard_state != null:
		return {
			"player_score": _call_int(scoreboard_state, "get_player_points", 0),
			"boss_score": _call_int(scoreboard_state, "get_boss_points", 0),
		}
	return {}


static func get_current_stage(owner: Object) -> int:
	if owner != null:
		var value: Variant = owner.get("current_stage")
		if value != null:
			return maxi(1, int(value))
	return 1


static func get_selected_character_type(owner: Object) -> String:
	if owner == null:
		return PlayerCharacterRuntime.SMASHER
	var value: Variant = owner.get("selected_character_type")
	return PlayerCharacterRuntime.new().normalize(value if value != null else PlayerCharacterRuntime.SMASHER)


static func get_result_victory_character_type(owner: Object) -> String:
	var selected_character_type: String = get_selected_character_type(owner)
	var character_runtime := PlayerCharacterRuntime.new()
	if character_runtime.is_commando(selected_character_type):
		return PlayerCharacterRuntime.COMMANDO
	if character_runtime.is_blacksmith(selected_character_type):
		return PlayerCharacterRuntime.BLACKSMITH
	return PlayerCharacterRuntime.SMASHER


static func get_instance(registry: Object, key: String) -> Object:
	if registry == null or not registry.has_method("get_instance"):
		return null
	var instance: Variant = registry.get_instance(key)
	return instance if instance is Object else null


static func reset_stage_for_result(registry: Object, stage_id: int) -> void:
	Stage4PonkAwakenAuraFxHost.hide_all_existing_hosts()
	reset_stage4_for_result(registry, stage_id)
	reset_stage5_for_result(registry, stage_id)
	reset_stage6_for_result(registry, stage_id)


static func reset_stage4_for_result(registry: Object, stage_id: int) -> void:
	if stage_id != 4:
		return
	var stage4_ponk_skill_state: Object = get_instance(registry, "stage4_ponk_skill_state")
	if stage4_ponk_skill_state != null and stage4_ponk_skill_state.has_method("reset_for_result"):
		stage4_ponk_skill_state.reset_for_result()


static func reset_stage5_for_result(registry: Object, stage_id: int) -> void:
	if stage_id != 5:
		return
	var stage5_hongryun_state: Object = get_instance(registry, "stage5_hongryun_state")
	if stage5_hongryun_state != null and stage5_hongryun_state.has_method("reset_for_result"):
		stage5_hongryun_state.reset_for_result()
	var stage5_hongryun_fire_machine_event: Object = get_instance(registry, "stage5_hongryun_fire_machine_event")
	if stage5_hongryun_fire_machine_event != null and stage5_hongryun_fire_machine_event.has_method("reset_for_result"):
		stage5_hongryun_fire_machine_event.reset_for_result()
	var stage5_hongryun_actor_renderer: Object = get_instance(registry, "stage5_hongryun_actor_renderer")
	if stage5_hongryun_actor_renderer != null:
		if stage5_hongryun_actor_renderer.has_method("reset_round_fx"):
			stage5_hongryun_actor_renderer.reset_round_fx()
		elif stage5_hongryun_actor_renderer.has_method("reset"):
			stage5_hongryun_actor_renderer.reset()


static func reset_stage6_for_result(registry: Object, stage_id: int) -> void:
	if stage_id != 6:
		return
	var stage6_tetriser_state: Object = get_instance(registry, "stage6_tetriser_state")
	if stage6_tetriser_state != null and stage6_tetriser_state.has_method("reset_for_result"):
		stage6_tetriser_state.reset_for_result()


static func _call_int(target: Object, method_name: String, fallback: int) -> int:
	if target == null or not target.has_method(method_name):
		return fallback
	return int(target.call(method_name))
