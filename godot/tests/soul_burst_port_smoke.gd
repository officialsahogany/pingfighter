extends SceneTree

const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const MythicItemSoulBurstRuntime := preload("res://scripts/items/mythic_item_soul_burst_runtime.gd")
const ActiveItemFieldSpawnPool := preload("res://scripts/items/active_item_field_spawn_pool.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const SmasherDashState := preload("res://scripts/characters/smasher_dash_state.gd")
const SmasherPlayerDashController := preload("res://scripts/characters/smasher_player_dash_controller.gd")


class FakeOwner:
	var player_pos := Vector2(300.0, 650.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge := 200.0
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var soul_burst_equipped := false
	var soul_burst_active := false
	var soul_burst_gauge_cost := 0.0
	var soul_burst_dash_active := false
	var redraw_queued := false

	func queue_redraw() -> void:
		redraw_queued = true


class FakeAudio:
	var soul_burst_calls := 0
	var dash_start_calls := 0
	var half_dash_calls := 0
	var stopped_delay := false

	func play_soul_burst_dash() -> void:
		soul_burst_calls += 1

	func play_dash_start(is_half: bool) -> void:
		dash_start_calls += 1
		if is_half:
			half_dash_calls += 1

	func stop_dash_delay() -> void:
		stopped_delay = true


class FakeFeedback:
	var shake_amount := 0.0
	var shake_intensity := 0.0

	func set_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = amount
		shake_intensity = intensity

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = max(shake_amount, amount)
		shake_intensity = max(shake_intensity, intensity)


class FakeOrbHudState:
	var dash_spin_count := 0
	var gauge_spin_count := 0

	func trigger_dash_token_spin(_msec: int) -> void:
		dash_spin_count += 1

	func trigger_gauge_spin(_msec: int) -> void:
		gauge_spin_count += 1


class FakeRegistry:
	var runtime: Object
	var dash_state: Object
	var audio: Object
	var feedback: Object

	func _init(runtime_ref: Object, dash_ref: Object, audio_ref: Object, feedback_ref: Object) -> void:
		runtime = runtime_ref
		dash_state = dash_ref
		audio = audio_ref
		feedback = feedback_ref

	func get_instance(key: String) -> Object:
		match key:
			"mythic_item_runtime":
				return runtime
			"smasher_dash_state":
				return dash_state
			"game_audio":
				return audio
			"battle_feedback_state":
				return feedback
		return null


func _init() -> void:
	_verify_runtime_constant_ownership()

	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("soul_burst")
	_expect(not item_data.is_empty(), "Soul Burst should be registered in the passive item catalog")
	_expect(str(item_data.get("slot", "")) == "knee", "Soul Burst should use the knee equipment slot")
	_expect(_array_has_item(catalog.get_field_spawn_items(), "soul_burst"), "Soul Burst should be in the field-spawn passive pool")
	_expect(_array_has_item(catalog.get_debug_items(), "soul_burst"), "Soul Burst should be in the passive debug item list")
	var gauge_option: Dictionary = _find_roll_option(item_data, "soul_burst_gauge_cost")
	_expect(is_equal_approx(float(gauge_option.get("min", 0.0)), 110.0), "Soul Burst gauge-cost roll should start at 110")
	_expect(is_equal_approx(float(gauge_option.get("max", 0.0)), 160.0), "Soul Burst gauge-cost roll should cap at 160")
	_expect(is_equal_approx(float(gauge_option.get("default", 0.0)), 160.0), "Soul Burst default gauge cost should match Python")
	_expect(ProjectResourceLoader.load_texture("res://assets/sprites/items/soul_burst.png") != null, "Soul Burst icon should load from Godot assets")
	_expect(ProjectResourceLoader.load_audio_stream("res://assets/sounds/soulbust.wav") != null, "Soul Burst dash sound should load from Godot assets")

	var runtime: Object = MythicItemRuntime.new()
	var dash_state: Object = SmasherDashState.new()
	var owner := FakeOwner.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, dash_state, audio, feedback)
	var field_spawn_pool: Object = ActiveItemFieldSpawnPool.new()
	_expect(
		field_spawn_pool.get_field_spawn_candidate_names(registry, owner).has("soul_burst"),
		"shared field-spawn pool should expose Soul Burst as a passive pickup candidate"
	)
	_expect(
		runtime.equip_item("soul_burst", owner, registry, {"soul_burst_gauge_cost": 140.0}, false),
		"Soul Burst should equip through mythic_item_runtime"
	)
	_expect(owner.soul_burst_equipped, "owner sync should expose Soul Burst equipped state")
	_expect(is_equal_approx(owner.soul_burst_gauge_cost, 140.0), "owner sync should expose the rolled gauge cost")
	_expect(not runtime.can_soul_burst_dash(139.0), "Soul Burst should not fire below its rolled gauge cost")
	_expect(runtime.can_soul_burst_dash(140.0), "Soul Burst should fire at its rolled gauge cost")

	# The consumed gauge is returned in "special_gauge" — that return value is the
	# single source of truth (caller -> controller result -> result applier ->
	# owner). The helper deliberately does NOT write the owner directly; the
	# end-to-end owner write is sealed by commando_soul_burst_dash_smoke through
	# the real result applier. See docs/character_skill_perk_checklist.md §3.5.
	var consume_result: Dictionary = runtime.try_consume_soul_burst_dash(
		200.0,
		Vector2(120.0, 660.0),
		-1.0,
		registry
	)
	_expect(bool(consume_result.get("activated", false)), "Soul Burst consume helper should activate when gauge is sufficient")
	_expect(is_equal_approx(float(consume_result.get("special_gauge", 0.0)), 60.0), "Soul Burst should subtract its rolled gauge cost")
	_expect(audio.soul_burst_calls == 1, "Soul Burst activation should play the dedicated dash sound")
	var runtime_snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(runtime_snapshot.get("soul_burst_effect_active", false)), "Soul Burst should start its dash VFX runtime")
	_expect(bool(runtime.get_actor_draw_context().get("soul_burst_dash_active", false)), "actor draw context should expose Soul Burst tint state")

	dash_state.reset_full(1)
	dash_state.token_state.dash_tokens = 0
	dash_state.token_state.dash_charge_timer = 220.0
	dash_state.token_state.dash_consecutive_count = 0
	owner.special_gauge = 200.0
	audio.soul_burst_calls = 0
	audio.dash_start_calls = 0
	var dash_controller: Object = SmasherPlayerDashController.new()
	var orb_hud_state := FakeOrbHudState.new()
	var dash_config := {
		"special_gauge": 200.0,
		"paddle_width": 155.0,
		"paddle_height": 50.0,
		"play_left": 0.0,
		"play_right": 760.0,
	}
	var dash_result: Dictionary = dash_controller.handle_dash_input(
		true,
		1.0,
		Vector2(300.0, 650.0),
		0.0,
		dash_config,
		{
			"dash_state": dash_state,
			"registry": registry,
			"audio": audio,
			"feedback": feedback,
			"orb_hud_state": orb_hud_state,
			"owner": owner,
		}
	)
	_expect(bool(dash_result.get("handled_by_dash", false)), "dash input should be handled with zero dash tokens")
	_expect(is_equal_approx(float(dash_result.get("special_gauge", 0.0)), 60.0), "dash controller should spend Soul Burst gauge on the replacement full dash")
	var dash_snapshot: Dictionary = dash_state.get_snapshot()
	_expect(bool(dash_snapshot.get("active", false)), "Soul Burst should start an actual dash")
	_expect(not bool(dash_snapshot.get("is_half", true)), "Soul Burst should replace the half-dash fallback with a full dash")
	_expect(int(dash_snapshot.get("tokens", -1)) == 0, "Soul Burst should not create or consume a dash token")
	_expect(is_equal_approx(float(dash_snapshot.get("charge_timer", 0.0)), 220.0), "Soul Burst should preserve the existing token recharge timer")
	_expect(audio.soul_burst_calls == 1, "dash replacement should play Soul Burst audio once")
	_expect(audio.half_dash_calls == 0, "dash replacement should not play the half-dash cue")
	_expect(orb_hud_state.gauge_spin_count == 1 and orb_hud_state.dash_spin_count == 0, "Soul Burst dash replacement should pulse the gauge orb instead of a missing token")

	runtime.update(owner, registry, 0.5)
	_expect(not bool(runtime.get_snapshot().get("soul_burst_dash_active", true)), "Soul Burst dash-active tint should expire through runtime update")

	print("soul_burst_port_smoke: ok")
	quit(0)


func _verify_runtime_constant_ownership() -> void:
	_expect(is_equal_approx(MythicItemSoulBurstRuntime.DEFAULT_GAUGE_COST, 160.0), "Soul Burst helper should own default gauge cost")
	_expect(MythicItemSoulBurstRuntime.PARTICLE_COUNT == 30, "Soul Burst helper should own particle count")
	var runtime_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_runtime.gd")
	var helper_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_soul_burst_runtime.gd")
	_expect(runtime_source != "", "mythic runtime source should be readable")
	_expect(helper_source != "", "Soul Burst helper source should be readable")
	_expect(not runtime_source.contains("SOUL_BURST_CONSTANTS"), "runtime facade should not regain SOUL_BURST_CONSTANTS")
	_expect(not runtime_source.contains("const SOUL_BURST_DEFAULT"), "runtime facade should not regain Soul Burst gauge-cost constants")
	_expect(not runtime_source.contains("const SOUL_BURST_EFFECT"), "runtime facade should not regain Soul Burst effect timing constants")
	_expect(not runtime_source.contains("const SOUL_BURST_PARTICLE"), "runtime facade should not regain Soul Burst particle constants")
	_expect(not runtime_source.contains("const SOUL_BURST_WIND"), "runtime facade should not regain Soul Burst wind-trail constants")
	_expect(runtime_source.find("return soul_burst_runtime.is_equipped(self)") >= 0, "runtime facade should delegate Soul Burst equipped checks")
	_expect(runtime_source.find("return soul_burst_runtime.get_gauge_cost(self)") >= 0, "runtime facade should delegate Soul Burst gauge-cost rolls")
	_expect(runtime_source.find("roll_query.get_equipped_roll_value(self, ITEM_SOUL_BURST") < 0, "runtime facade should not keep Soul Burst roll math inline")
	_expect(helper_source.contains("const PARTICLE_ALPHA_CUTOFF"), "Soul Burst helper should keep alpha cutoff constants")
	_expect(helper_source.find("func get_gauge_cost(") >= 0, "Soul Burst helper should own gauge-cost roll math")
	_expect(helper_source.find("func can_dash(") >= 0, "Soul Burst helper should own dash affordability checks")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _find_roll_option(item_data: Dictionary, key: String) -> Dictionary:
	for option_value in item_data.get("roll_options", []):
		if option_value is Dictionary and str(option_value.get("key", "")) == key:
			return option_value
	return {}


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
