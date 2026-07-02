extends SceneTree

const LingpetLoadoutCacheKeyBuilder := preload("res://scripts/lingpet/lingpet_loadout_cache_key_builder.gd")

var _failures: Array[String] = []


func _init() -> void:
	_verify_slot_signature_filters_empty_ids_and_defaults_missing_levels()
	_verify_cache_key_shape_includes_slots_and_reward_signature()
	_verify_runtime_delegates_loadout_cache_key_builder()

	if _failures.is_empty():
		print("lingpet_loadout_cache_key_builder_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_slot_signature_filters_empty_ids_and_defaults_missing_levels() -> void:
	var builder := LingpetLoadoutCacheKeyBuilder.new()
	var loadout := {
		"active_skill_ids": ["maribo_hydro_sphere", "", "maribo_bubble_trap"],
		"active_skill_levels": {"maribo_hydro_sphere": 2},
	}
	_expect(
		builder.slot_signature(loadout, "active_skill_ids", "active_skill_levels") == "maribo_hydro_sphere:2,maribo_bubble_trap:0",
		"slot signature should skip empty ids and default missing levels to zero"
	)
	_expect(
		builder.slot_signature({"active_skill_ids": "not-an-array"}, "active_skill_ids", "active_skill_levels") == "",
		"slot signature should tolerate malformed id containers"
	)
	_expect(
		builder.slot_signature({"active_skill_ids": ["x"], "active_skill_levels": "bad"}, "active_skill_ids", "active_skill_levels") == "x:0",
		"slot signature should tolerate malformed level dictionaries"
	)


func _verify_cache_key_shape_includes_slots_and_reward_signature() -> void:
	var builder := LingpetLoadoutCacheKeyBuilder.new()
	var loadout := {
		"active_skill_ids": ["red_dragon_dragon_breath", "red_dragon_dragon_wing"],
		"active_skill_levels": {"red_dragon_dragon_breath": 3, "red_dragon_dragon_wing": 2},
		"active_slot_count": 2,
		"passive_skill_ids": ["lingpet_resonance_boost"],
		"passive_skill_levels": {"lingpet_resonance_boost": 5},
		"passive_slot_count": 1,
	}
	_expect(
		builder.build_key("red_dragon", loadout, "affinity-v3-lv22") == "red_dragon|red_dragon_dragon_breath:3,red_dragon_dragon_wing:2|2|lingpet_resonance_boost:5|1|affinity-v3-lv22",
		"cache key should include pet id, active signature/count, passive signature/count, and reward signature"
	)


func _verify_runtime_delegates_loadout_cache_key_builder() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var applier_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_current_loadout_applier.gd")
	var builder_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_loadout_cache_key_builder.gd")
	_expect(runtime_source.find("LingpetCurrentLoadoutApplier") >= 0, "egg runtime should preload the current-loadout applier")
	_expect(runtime_source.find("func _build_loadout_key") < 0, "egg runtime should not keep a single-use loadout cache-key wrapper")
	_expect(runtime_source.find("_current_loadout_applier.apply") >= 0, "runtime loadout apply path should delegate to the current-loadout applier")
	_expect(applier_source.find("LingpetLoadoutCacheKeyBuilder") >= 0, "current-loadout applier should preload the cache-key builder")
	_expect(applier_source.find("_loadout_cache_key_builder.build_key") >= 0, "current-loadout applier should call the cache-key builder directly")
	_expect(runtime_source.find("func _loadout_slot_signature") < 0, "egg runtime should not retain inline slot-signature construction")
	_expect(builder_source.find("func slot_signature") >= 0, "builder should own slot signature construction")
	_expect(builder_source.find("reward_signature") >= 0, "builder key shape should include reward signature input")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
