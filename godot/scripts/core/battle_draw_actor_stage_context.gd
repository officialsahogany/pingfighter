extends RefCounted

## Owns Stage 1-8 actor-source capture and merge precedence.
## Captured dictionaries are borrowed until merge_into() and then released.

var _current_stage := 0
var _whip_context: Variant = null
var _spinning_top_context: Variant = null
var _stage1_boss_cooldown_context: Variant = null
var _stage1_wall_flash_context: Variant = null
var _stage2_context: Variant = null
var _stage2_skill_context: Variant = null
var _stage3_skill_context: Variant = null
var _stage4_map_context: Variant = null
var _stage4_wall_flash_context: Variant = null
var _stage5_hongryun_context: Variant = null
var _stage5_hongryun_fire_machine_context: Variant = null
var _stage6_tetriser_context: Variant = null
var _stage7_akamu_context: Variant = null
var _stage8_minotaur_context: Variant = null


func capture_sources(current_stage: int, stage1_boss_variant: String, deps: Dictionary) -> void:
	_clear_sources()
	_current_stage = current_stage
	match current_stage:
		1:
			_capture_stage1(stage1_boss_variant, deps)
		2:
			_capture_stage2(deps)
		3:
			_capture_stage3(deps)
		4:
			_capture_stage4(deps)
		5:
			_capture_stage5(deps)
		6:
			_capture_stage6(deps)
		7:
			_capture_stage7(deps)
		8:
			_capture_stage8(deps)


func merge_into(actor_context: Dictionary) -> void:
	_merge_if_dictionary(actor_context, _whip_context)
	_merge_if_dictionary(actor_context, _spinning_top_context)
	_merge_if_dictionary(actor_context, _stage1_boss_cooldown_context)
	_merge_if_dictionary(actor_context, _stage1_wall_flash_context)
	match _current_stage:
		2:
			_merge_if_dictionary(actor_context, _stage2_context)
			_merge_if_dictionary(actor_context, _stage2_skill_context)
		3:
			_merge_if_dictionary(actor_context, _stage3_skill_context)
		4:
			_merge_if_dictionary(actor_context, _stage4_map_context)
			_merge_if_dictionary(actor_context, _stage4_wall_flash_context)
		5:
			_merge_if_dictionary(actor_context, _stage5_hongryun_context)
			_merge_if_dictionary(actor_context, _stage5_hongryun_fire_machine_context)
		6:
			_merge_if_dictionary(actor_context, _stage6_tetriser_context)
		7:
			_merge_if_dictionary(actor_context, _stage7_akamu_context)
		8:
			_merge_if_dictionary(actor_context, _stage8_minotaur_context)
	_clear_sources()


func _capture_stage1(stage1_boss_variant: String, deps: Dictionary) -> void:
	if stage1_boss_variant == "gaksi":
		var fan_throw_state: Object = deps.get("stage1_gaksital_fan_throw_skill_state", null) as Object
		_spinning_top_context = fan_throw_state.get_draw_context() if fan_throw_state != null and fan_throw_state.has_method("get_draw_context") else null
		var fan_wind_state: Object = deps.get("stage1_gaksital_fan_wind_skill_state", null) as Object
		if fan_wind_state != null and fan_wind_state.has_method("get_draw_context"):
			if not _spinning_top_context is Dictionary:
				_spinning_top_context = {}
			(_spinning_top_context as Dictionary).merge(fan_wind_state.get_draw_context(), true)
		var gaksital_cooldown_state: Object = deps.get("stage1_gaksital_boss_skill_cooldown_state", null) as Object
		_stage1_boss_cooldown_context = gaksital_cooldown_state.get_hud_context() if gaksital_cooldown_state != null and gaksital_cooldown_state.has_method("get_hud_context") else null
	elif stage1_boss_variant == "podo":
		var patrol_guards_state: Object = deps.get("stage1_pododaejang_patrol_guards_skill_state", null) as Object
		_spinning_top_context = patrol_guards_state.get_draw_context() if patrol_guards_state != null and patrol_guards_state.has_method("get_draw_context") else null
		var arrest_rope_state: Object = deps.get("stage1_pododaejang_arrest_rope_skill_state", null) as Object
		if arrest_rope_state != null and arrest_rope_state.has_method("get_draw_context"):
			if not _spinning_top_context is Dictionary:
				_spinning_top_context = {}
			(_spinning_top_context as Dictionary).merge(arrest_rope_state.get_draw_context(), true)
		var pododaejang_cooldown_state: Object = deps.get("stage1_pododaejang_boss_skill_cooldown_state", null) as Object
		_stage1_boss_cooldown_context = pododaejang_cooldown_state.get_hud_context() if pododaejang_cooldown_state != null and pododaejang_cooldown_state.has_method("get_hud_context") else null
	elif stage1_boss_variant == "dalji":
		var whip_state: Object = deps.get("stage1_dalji_whip_skill_state", null) as Object
		_whip_context = whip_state.get_draw_context() if whip_state != null and whip_state.has_method("get_draw_context") else null
		var spinning_top_state: Object = deps.get("stage1_dalji_spinning_top_skill_state", null) as Object
		_spinning_top_context = spinning_top_state.get_draw_context() if spinning_top_state != null and spinning_top_state.has_method("get_draw_context") else null
		var dalji_cooldown_state: Object = deps.get("stage1_dalji_boss_skill_cooldown_state", null) as Object
		_stage1_boss_cooldown_context = dalji_cooldown_state.get_hud_context() if dalji_cooldown_state != null and dalji_cooldown_state.has_method("get_hud_context") else null
	_stage1_wall_flash_context = _build_wall_flash_context(deps.get("impact_effects", null), "stage1")


func _capture_stage2(deps: Dictionary) -> void:
	var stage2_background: Object = deps.get("stage2_pillar_background", null) as Object
	_stage2_context = stage2_background.get_actor_draw_context() if stage2_background != null and stage2_background.has_method("get_actor_draw_context") else null
	var stage2_skill_state: Object = deps.get("stage2_boss_skill_state", null) as Object
	_stage2_skill_context = stage2_skill_state.get_actor_draw_context() if stage2_skill_state != null and stage2_skill_state.has_method("get_actor_draw_context") else null


func _capture_stage3(deps: Dictionary) -> void:
	var stage3_skill_state: Object = deps.get("stage3_boss_skill_state", null) as Object
	_stage3_skill_context = stage3_skill_state.get_actor_draw_context() if stage3_skill_state != null and stage3_skill_state.has_method("get_actor_draw_context") else null


func _capture_stage4(deps: Dictionary) -> void:
	var stage4_map_state: Object = deps.get("stage4_map_state", null) as Object
	_stage4_map_context = stage4_map_state.get_actor_draw_context({
		"stage4_temple_destruction_event": deps.get("stage4_temple_destruction_event", null),
		"stage4_moon_event": deps.get("stage4_moon_event", null),
		"stage4_bird_event": deps.get("stage4_bird_event", null),
		"stage4_brazier_monk_event": deps.get("stage4_brazier_monk_event", null),
		"stage4_ponk_skill_state": deps.get("stage4_ponk_skill_state", null),
	}) if stage4_map_state != null and stage4_map_state.has_method("get_actor_draw_context") else null
	_stage4_wall_flash_context = _build_wall_flash_context(deps.get("impact_effects", null), "stage4")


func _capture_stage5(deps: Dictionary) -> void:
	var stage5_hongryun_state: Object = deps.get("stage5_hongryun_state", null) as Object
	_stage5_hongryun_context = stage5_hongryun_state.get_actor_draw_context() if stage5_hongryun_state != null and stage5_hongryun_state.has_method("get_actor_draw_context") else null
	var stage5_fire_machine: Object = deps.get("stage5_hongryun_fire_machine_event", null) as Object
	_stage5_hongryun_fire_machine_context = stage5_fire_machine.get_actor_draw_context() if _should_read_actor_draw_context(stage5_fire_machine) else null


func _capture_stage6(deps: Dictionary) -> void:
	var stage6_tetriser_state: Object = deps.get("stage6_tetriser_state", null) as Object
	_stage6_tetriser_context = stage6_tetriser_state.get_actor_draw_context() if stage6_tetriser_state != null and stage6_tetriser_state.has_method("get_actor_draw_context") else null


func _capture_stage7(deps: Dictionary) -> void:
	var stage7_akamu_state: Object = deps.get("stage7_akamu_state", null) as Object
	_stage7_akamu_context = stage7_akamu_state.get_actor_draw_context() if stage7_akamu_state != null and stage7_akamu_state.has_method("get_actor_draw_context") else null


func _capture_stage8(deps: Dictionary) -> void:
	var stage8_minotaur_state: Object = deps.get("stage8_minotaur_state", null) as Object
	_stage8_minotaur_context = stage8_minotaur_state.get_actor_draw_context() if stage8_minotaur_state != null and stage8_minotaur_state.has_method("get_actor_draw_context") else null


func _build_wall_flash_context(impact_effects_value: Variant, key_prefix: String) -> Variant:
	var impact_effects: Object = impact_effects_value as Object
	if impact_effects == null or not impact_effects.has_method("get_wall_border_flash_timer"):
		return null
	return {
		"%s_wall_flash_timer" % key_prefix: float(impact_effects.get_wall_border_flash_timer()),
		"%s_wall_flash_duration" % key_prefix: float(impact_effects.get_wall_border_flash_duration()),
		"%s_wall_flash_position" % key_prefix: impact_effects.get_wall_border_flash_position(),
		"%s_wall_flash_side" % key_prefix: str(impact_effects.get_wall_border_flash_side()),
		"%s_wall_flash_speed" % key_prefix: float(impact_effects.get_wall_border_flash_speed()),
	}


func _should_read_actor_draw_context(source: Object) -> bool:
	if source == null or not source.has_method("get_actor_draw_context"):
		return false
	if source.has_method("has_actor_draw_context"):
		return bool(source.has_actor_draw_context())
	return true


func _merge_if_dictionary(target: Dictionary, value: Variant) -> void:
	if value is Dictionary:
		target.merge(value, true)


func _clear_sources() -> void:
	_current_stage = 0
	_whip_context = null
	_spinning_top_context = null
	_stage1_boss_cooldown_context = null
	_stage1_wall_flash_context = null
	_stage2_context = null
	_stage2_skill_context = null
	_stage3_skill_context = null
	_stage4_map_context = null
	_stage4_wall_flash_context = null
	_stage5_hongryun_context = null
	_stage5_hongryun_fire_machine_context = null
	_stage6_tetriser_context = null
	_stage7_akamu_context = null
	_stage8_minotaur_context = null
