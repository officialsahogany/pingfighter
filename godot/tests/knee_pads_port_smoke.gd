extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemKneePadsRuntime := preload("res://scripts/items/mythic_item_knee_pads_runtime.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var accessory_slot_count := 2
	var runtime_accessory_slot_bonus := 0
	var runtime_perk_levels: Dictionary = {}
	var selected_character_type := "smasher"
	var knee_pads_equipped := false
	var knee_pads_charge_pct := 0.0

	func queue_redraw() -> void:
		pass


class FakeDashState:
	var snapshot: Dictionary = {}

	func get_snapshot() -> Dictionary:
		return snapshot


class FakeAudio:
	var active_item_calls := 0

	func play_active_item() -> void:
		active_item_calls += 1


class FakeFeedback:
	var gauge_flash_calls := 0
	var shake_amount := 0.0
	var shake_intensity := 0.0

	func trigger_gauge_flash() -> void:
		gauge_flash_calls += 1

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = max(shake_amount, amount)
		shake_intensity = max(shake_intensity, intensity)


class FakeOrbHudState:
	var gauge_spin_calls := 0

	func trigger_gauge_spin(_now_msec: int) -> void:
		gauge_spin_calls += 1


class FakeRegistry:
	var runtime: Object
	var audio: Object
	var feedback: Object

	func _init(runtime_ref: Object, audio_ref: Object, feedback_ref: Object) -> void:
		runtime = runtime_ref
		audio = audio_ref
		feedback = feedback_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return runtime
			"game_audio":
				return audio
			"battle_feedback_state":
				return feedback
		return null


func _init() -> void:
	_verify_runtime_constant_ownership()
	var catalog := MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("knee_pads")
	_expect(not item_data.is_empty(), "Knee Pads should be registered in the passive catalog")
	_expect(str(item_data.get("slot", "")) == "knee", "Knee Pads should use the knee equipment slot")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/items/knee_pads.png") != null, "Knee Pads icon should load")
	var roll_options: Array = catalog.get_roll_options("knee_pads")
	var charge_roll: Dictionary = _find_roll(roll_options, "knee_charge_pct")
	_expect(is_equal_approx(float(charge_roll.get("min", 0.0)), 30.0), "Knee Pads charge roll min should match parity")
	_expect(is_equal_approx(float(charge_roll.get("max", 0.0)), 60.0), "Knee Pads charge roll max should match parity")
	_expect(is_equal_approx(float(charge_roll.get("default", 0.0)), 50.0), "Knee Pads charge roll default should match parity")

	var runtime := MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, audio, feedback)
	_expect(
		runtime.equip_item("knee_pads", owner, registry, {"knee_charge_pct": 100.0}, false),
		"Knee Pads should equip through mythic_item_runtime"
	)
	_expect(owner.knee_pads_equipped, "owner sync should expose Knee Pads equipped")
	_expect(is_equal_approx(owner.knee_pads_charge_pct, 100.0), "owner sync should expose Knee Pads charge pct")

	var dash_state := FakeDashState.new()
	var orb_hud_state := FakeOrbHudState.new()
	var deps := {
		"dash_state": dash_state,
		"registry": registry,
		"feedback": feedback,
		"orb_hud_state": orb_hud_state,
	}
	var inactive_result: Dictionary = runtime.try_apply_knee_pads_player_hit(
		Vector2(360.0, 650.0),
		40.0,
		{"selected_character_type": "soldier", "gauge_max": 500.0},
		deps
	)
	_expect(inactive_result.is_empty(), "Knee Pads should not activate outside a half-dash window")

	dash_state.snapshot = {"is_half": true, "active": true, "timer": 4.0}
	var active_context := {"selected_character_type": "soldier", "gauge_max": 500.0}
	var audio_calls_before_activation: int = audio.active_item_calls
	var active_result: Dictionary = runtime.try_apply_knee_pads_player_hit(
		Vector2(360.0, 650.0),
		40.0,
		active_context,
		deps
	)
	_expect(bool(active_result.get("activated", false)), "Knee Pads should activate during a half-dash window")
	_expect_close(float(active_result.get("special_gauge", 0.0)), 100.0, "Soldier Knee Pads charge should use 60 base gauge at 100%")
	_expect_close(float(active_result.get("charge_amount", 0.0)), 60.0, "Knee Pads should report the actual charged gauge")
	_expect(
		audio.active_item_calls == audio_calls_before_activation + 1,
		"Knee Pads should play its routed item audio once on activation, got %d expected %d" % [
			audio.active_item_calls,
			audio_calls_before_activation + 1,
		]
	)
	_expect(feedback.gauge_flash_calls == 1, "Knee Pads should trigger gauge feedback")
	_expect(orb_hud_state.gauge_spin_calls == 1, "Knee Pads should pulse the gauge orb")
	_expect(feedback.shake_amount > 0.0 and feedback.shake_intensity > 0.0, "Knee Pads should request hit feedback shake")
	_expect(runtime.knee_pads_particles.size() == 20, "Knee Pads should create the expected flash particles")
	_expect(bool(runtime.get_snapshot().get("knee_pads_effect_active", false)), "Knee Pads snapshot should expose active VFX")

	var repeated_result: Dictionary = runtime.try_apply_knee_pads_player_hit(
		Vector2(360.0, 650.0),
		100.0,
		active_context,
		deps
	)
	_expect(repeated_result.is_empty(), "Knee Pads should only charge once per half-dash window")

	dash_state.snapshot = {"is_half": false, "active": false}
	var reset_result: Dictionary = runtime.try_apply_knee_pads_player_hit(
		Vector2(360.0, 650.0),
		100.0,
		active_context,
		deps
	)
	_expect(reset_result.is_empty(), "leaving half-dash should reset the consumed state without activating")

	dash_state.snapshot = {"is_half": true, "recovering": true, "timer": 0.0}
	var blacksmith_result: Dictionary = runtime.try_apply_knee_pads_player_hit(
		Vector2(360.0, 650.0),
		100.0,
		{"selected_character_type": "blacksmith", "gauge_max": 500.0},
		deps
	)
	_expect_close(float(blacksmith_result.get("special_gauge", 0.0)), 130.0, "Blacksmith Knee Pads charge should use 30 base gauge at 100%")

	runtime.update(owner, registry, 31.0)
	_expect(runtime.knee_pads_particles.is_empty(), "Knee Pads update should expire flash particles")
	_expect(not bool(runtime.get_snapshot().get("knee_pads_effect_active", true)), "Knee Pads VFX should expire through runtime update")

	print("knee_pads_port_smoke: ok")
	quit(0)


func _verify_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemKneePadsRuntime.FLASH_DURATION_FRAMES, 30.0), "Knee Pads helper should own flash timing")
	_expect(MythicItemKneePadsRuntime.PARTICLE_COUNT == 20, "Knee Pads helper should own particle count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_knee_pads_runtime.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "Knee Pads helper source should be readable")
	_expect(not runtime_source.contains("KNEE_PADS_CONSTANTS"), "runtime facade should not regain KNEE_PADS_CONSTANTS")
	_expect(not runtime_source.contains("const KNEE_PADS_FLASH"), "runtime facade should not regain Knee Pads flash constants")
	_expect(not runtime_source.contains("const KNEE_PADS_PARTICLE"), "runtime facade should not regain Knee Pads particle constants")
	_expect(not runtime_source.contains("const KNEE_PADS_SHAKE"), "runtime facade should not regain Knee Pads shake constants")
	_expect(helper_source.contains("const SHAKE_INTENSITY"), "Knee Pads helper should keep shake constants")


func _find_roll(rolls: Array, key: String) -> Dictionary:
	for roll_value in rolls:
		var roll: Dictionary = roll_value if roll_value is Dictionary else {}
		if str(roll.get("key", "")) == key:
			return roll
	return {}


func _expect_close(actual: float, expected: float, message: String) -> void:
	_expect(abs(actual - expected) <= 0.0001, "%s: got %.6f expected %.6f" % [message, actual, expected])


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
