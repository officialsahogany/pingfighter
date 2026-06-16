extends SceneTree

const BattleSceneSkillTooltipDriver := preload("res://scripts/core/battle_scene_skill_tooltip_driver.gd")
const RuntimePerkState := preload("res://scripts/characters/runtime_perk_state.gd")
const SmasherSkillState := preload("res://scripts/characters/smasher_skill_state.gd")


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var runtime_perk_levels: Dictionary = {}
	var runtime_perk_effective_levels: Dictionary = {}
	var runtime_perk_pending_choices := 0
	var runtime_perk_starpoints := 0
	var runtime_perk_gold := 0
	var runtime_perk_choice_active := false
	var runtime_accessory_slot_bonus := 0
	var runtime_laurel_leaf_count := 0
	var runtime_paddle_scale := 1.0
	var runtime_paddle_base_width := 155.0
	var runtime_paddle_base_height := 50.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var player_paddle_scale := 1.0
	var player_pos := Vector2(300.0, 700.0)
	var item_perk_level_bonus := 0
	var viper_ignition_aura_active := false
	var ball_vel := Vector2.ZERO
	var player_collision_cooldown := 0.0


class FakeRuntimePerkCatalog:
	extends RefCounted

	var choices: Array = []

	func get_choices(
		_character_type: String,
		_levels: Dictionary,
		_exclude_instant: bool,
		_target_count: int,
		_owner: Object = null,
		_registry: Object = null
	) -> Array:
		return choices.duplicate(true)


class FakeRegistry:
	extends RefCounted

	var runtime_perk_catalog := FakeRuntimePerkCatalog.new()
	var skill_tooltip_driver := BattleSceneSkillTooltipDriver.new()
	var skill_state := SmasherSkillState.new()

	func get_instance(key: String) -> Object:
		match key:
			"runtime_perk_catalog":
				return runtime_perk_catalog
			"battle_scene_skill_tooltip_driver":
				return skill_tooltip_driver
			"smasher_skill_state":
				return skill_state
		return null


func _init() -> void:
	_verify_perk_choice_pauses_wall_clock_skill_cooldowns()
	print("runtime_perk_skill_cooldown_pause_smoke: ok")
	quit(0)


func _verify_perk_choice_pauses_wall_clock_skill_cooldowns() -> void:
	var state := RuntimePerkState.new()
	var owner := FakeOwner.new()
	var registry := FakeRegistry.new()
	var skill_state: Object = registry.skill_state
	var cooldown_seconds := 10.0
	var start_msec: int = Time.get_ticks_msec()
	skill_state.trigger_cooldown("drive", start_msec, cooldown_seconds)

	_expect(
		is_equal_approx(float(skill_state.get_cooldown_remaining("drive", start_msec + 15000, cooldown_seconds)), 0.0),
		"unpaused skill cooldown should expire against wall-clock time"
	)

	registry.runtime_perk_catalog.choices = [_build_basic_choice("stability_training")]
	var opened: bool = state.collect_star_points(1, "smasher", registry.runtime_perk_catalog, owner, registry)

	_expect(opened, "collecting a starpoint should open the perk choice modal")
	_expect(state.is_choice_active(), "perk choice should be active after starpoint collection")
	var pause_started_msec: int = int(skill_state.get("cooldown_pause_started_msec"))
	_expect(pause_started_msec >= start_msec, "opening the perk choice should pause player skill cooldowns")
	_expect(
		float(skill_state.get_cooldown_remaining("drive", pause_started_msec + 15000, cooldown_seconds)) > 0.9,
		"paused perk choice cooldown should stay pinned while wall-clock time advances"
	)

	skill_state.set("cooldown_pause_started_msec", 0)
	state.animation_time = 0.30
	state.choose_selected(owner, registry, Vector2(1280.0, 720.0))

	_expect(not state.is_choice_active(), "selecting the final perk should close the modal")
	var resumed_pause_marker: int = int(skill_state.get("cooldown_pause_started_msec"))
	_expect(resumed_pause_marker == -1, "closing the perk choice should resume skill cooldowns, got %d" % resumed_pause_marker)
	_expect(
		float(skill_state.get_cooldown_remaining("drive", start_msec + int(cooldown_seconds * 1000.0), cooldown_seconds)) > 0.0,
		"resumed cooldown should shift its start time by the modal pause duration"
	)


func _build_basic_choice(choice_id: String) -> Dictionary:
	return {
		"id": choice_id,
		"name": choice_id,
		"character_restriction": "smasher",
		"icon_color": Color(0.45, 0.75, 1.0),
		"tree": "training",
		"max_level": 5,
		"current_level": 0,
		"next_level": 1,
	}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
