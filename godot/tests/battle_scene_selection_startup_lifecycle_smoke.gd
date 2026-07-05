extends SceneTree

const BattleSceneSelectionStartupLifecycle := preload("res://scripts/core/battle_scene_selection_startup_lifecycle.gd")
const BattleSceneState := preload("res://scripts/core/battle_scene_state.gd")
const BattleSceneStartupController := preload("res://scripts/core/battle_scene_startup_controller.gd")

var _failures: Array[String] = []


class FakeSelectionState:
	extends RefCounted

	var selection: Dictionary = {}

	func get_selection() -> Dictionary:
		return selection


class FakeOwner:
	extends RefCounted

	var data: Dictionary = {}
	var selection_state := FakeSelectionState.new()

	func get_node_or_null(path: NodePath) -> Object:
		if str(path) == "/root/GameSelectionState":
			return selection_state
		return null

	func _set(property: StringName, value: Variant) -> bool:
		data[str(property)] = value
		return true


class FakeSelectionStartupLifecycle:
	extends RefCounted

	var apply_calls := 0
	var normalize_league_calls := 0
	var normalize_runtime_calls := 0

	func apply_selection_state(_owner: Object) -> void:
		apply_calls += 1

	func normalize_league_mode(_mode: String) -> String:
		normalize_league_calls += 1
		return "champion"

	func normalize_runtime_character_id(_value: Variant) -> String:
		normalize_runtime_calls += 1
		return "smasher"


func _init() -> void:
	_verify_selection_startup_lifecycle_applies_battle_state()
	_verify_selection_startup_lifecycle_normalizes_fallbacks()
	_verify_selection_startup_lifecycle_defaults_missing_league_to_junior()
	_verify_selection_startup_lifecycle_accepts_junior()
	_verify_selection_startup_lifecycle_accepts_optimus()
	_verify_selection_startup_lifecycle_randomizes_stage1_boss_variant()
	_verify_selection_startup_lifecycle_applies_stage1_boss_variant()
	_verify_startup_controller_delegates_selection_surface()

	if _failures.is_empty():
		print("battle_scene_selection_startup_lifecycle_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_selection_startup_lifecycle_applies_battle_state() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": 3,
		"character_id": "viper",
		"runtime_character_id": "viper",
		"character_name": "Viper",
		"league_mode": "mythic league",
	}

	lifecycle.apply_selection_state(owner)

	_expect(int(owner.data.get("current_stage", 0)) == 3, "selection startup should apply selected stage")
	_expect(str(owner.data.get("selected_character_id", "")) == "viper", "selection startup should apply character id")
	_expect(str(owner.data.get("selected_runtime_character_id", "")) == "viper", "selection startup should apply runtime id")
	_expect(str(owner.data.get("selected_character_type", "")) == "viper", "selection startup should mirror runtime character type")
	_expect(str(owner.data.get("selected_character_name", "")) == "Viper", "selection startup should apply character display name")
	_expect(str(owner.data.get("ai_mode", "")) == "mythic", "selection startup should normalize mythic league")


func _verify_selection_startup_lifecycle_normalizes_fallbacks() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": -5,
		"character_id": "soldier",
		"runtime_character_id": "soldier",
		"league_mode": "unknown",
	}

	lifecycle.apply_selection_state(owner)

	_expect(int(owner.data.get("current_stage", 0)) == 1, "selection startup should clamp stage to at least one")
	_expect(str(owner.data.get("selected_runtime_character_id", "")) == "soldier", "selection startup should preserve the supported Commando runtime id")
	_expect(str(owner.data.get("selected_character_type", "")) == "soldier", "selection startup should mirror the Commando runtime type")
	_expect(str(owner.data.get("ai_mode", "")) == "champion", "selection startup should fall back unknown league mode")


func _verify_selection_startup_lifecycle_defaults_missing_league_to_junior() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": 1,
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
	}

	lifecycle.apply_selection_state(owner)

	_expect(str(owner.data.get("ai_mode", "")) == "junior", "selection startup should default missing league mode to Junior League")


func _verify_selection_startup_lifecycle_accepts_junior() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": 1,
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
		"league_mode": "junior league",
	}

	lifecycle.apply_selection_state(owner)

	_expect(str(owner.data.get("ai_mode", "")) == "junior", "selection startup should preserve junior league")


func _verify_selection_startup_lifecycle_accepts_optimus() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": 2,
		"character_id": "optimus",
		"runtime_character_id": "optimus",
		"character_name": "\uc774\uc624",
		"league_mode": "champion",
	}

	lifecycle.apply_selection_state(owner)

	_expect(str(owner.data.get("selected_runtime_character_id", "")) == "optimus", "selection startup should preserve Optimus runtime id")
	_expect(str(owner.data.get("selected_character_type", "")) == "optimus", "selection startup should mirror Optimus runtime type")


func _verify_selection_startup_lifecycle_applies_stage1_boss_variant() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	var owner := FakeOwner.new()
	owner.selection_state.selection = {
		"stage_id": 1,
		"stage1_boss_variant": "gaksital",
		"stage1_boss_variant_explicit": true,
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
	}

	lifecycle.apply_selection_state(owner)

	_expect(str(owner.data.get("stage1_boss_variant", "")) == "gaksi", "selection startup should normalize the Gaksital Stage 1 variant")
	_expect(str(BattleSceneState.DEFAULT_VALUES.get("stage1_boss_variant", "")) == "dalji", "battle state defaults should keep Dalji as the Stage 1 variant")

	var podo_owner := FakeOwner.new()
	podo_owner.selection_state.selection = {
		"stage_id": 1,
		"stage1_boss_variant": "pododaejang",
		"stage1_boss_variant_explicit": true,
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
	}

	lifecycle.apply_selection_state(podo_owner)

	_expect(str(podo_owner.data.get("stage1_boss_variant", "")) == "podo", "selection startup should normalize the Pododaejang Stage 1 variant")

	var stage2_owner := FakeOwner.new()
	stage2_owner.selection_state.selection = {
		"stage_id": 2,
		"stage1_boss_variant": "gaksi",
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
	}

	lifecycle.apply_selection_state(stage2_owner)

	_expect(str(stage2_owner.data.get("stage1_boss_variant", "")) == "dalji", "non-Stage 1 startup should discard the Stage 1 boss variant")


func _verify_selection_startup_lifecycle_randomizes_stage1_boss_variant() -> void:
	var lifecycle: Object = BattleSceneSelectionStartupLifecycle.new()
	lifecycle.set_stage1_boss_rng_seed_for_test(7321)
	var random_pool: Array[String] = lifecycle.get_stage1_random_boss_variants()
	_expect(random_pool == ["dalji"], "Stage 1 player-facing pool should stay Dalji-only until Gaksital / Pododaejang are release-ready (2026-07-04 decision)")
	var seen := {}
	for _i in range(48):
		var owner := FakeOwner.new()
		owner.selection_state.selection = {
			"stage_id": 1,
			"stage1_boss_variant": "dalji",
			"character_id": "ufo_player",
			"runtime_character_id": "smasher",
		}

		lifecycle.apply_selection_state(owner)

		var variant: String = str(owner.data.get("stage1_boss_variant", ""))
		_expect(variant == "dalji", "non-explicit Stage 1 startup must always resolve Dalji while the pool is Dalji-only")
		seen[variant] = true
	_expect(bool(seen.get("dalji", false)), "seeded Stage 1 startup should select Dalji")
	_expect(not bool(seen.get("gaksi", false)), "Stage 1 player-facing startup must not roll Gaksital until it rejoins the pool")
	_expect(not bool(seen.get("podo", false)), "Stage 1 player-facing startup must not roll Pododaejang until it rejoins the pool")

	var explicit_dalji_owner := FakeOwner.new()
	explicit_dalji_owner.selection_state.selection = {
		"stage_id": 1,
		"stage1_boss_variant": "dalji",
		"stage1_boss_variant_explicit": true,
		"character_id": "ufo_player",
		"runtime_character_id": "smasher",
	}
	lifecycle.apply_selection_state(explicit_dalji_owner)
	_expect(str(explicit_dalji_owner.data.get("stage1_boss_variant", "")) == "dalji", "explicit Stage 1 Dalji debug selection should bypass random startup")


func _verify_startup_controller_delegates_selection_surface() -> void:
	var startup: Object = BattleSceneStartupController.new()
	var fake := FakeSelectionStartupLifecycle.new()
	startup.selection_startup_lifecycle = fake

	startup._apply_selection_state(FakeOwner.new())
	_expect(fake.apply_calls == 1, "startup controller should delegate selection apply")
	_expect(startup._normalize_league_mode("mythic") == "champion", "startup controller should delegate league normalization")
	_expect(fake.normalize_league_calls == 1, "selection helper should receive league normalization")
	_expect(startup._normalize_runtime_character_id("viper") == "smasher", "startup controller should delegate runtime normalization")
	_expect(fake.normalize_runtime_calls == 1, "selection helper should receive runtime normalization")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
