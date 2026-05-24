extends SceneTree

const BallUpdateController := preload("res://scripts/ball/ball_update_controller.gd")
const MythicItemCatalog := preload("res://scripts/items/mythic_item_catalog.gd")
const MythicItemRuntime := preload("res://scripts/items/mythic_item_runtime.gd")
const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")


class FakeOwner:
	var player_pos := Vector2(300.0, 650.0)
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge := 100.0
	var equipment_slots: Dictionary = {}
	var passive_item_inventory: Array = []
	var passive_item_slots: Dictionary = {}
	var equipped_passive_items: Dictionary = {}
	var mythic_item_state: Dictionary = {}
	var megingjord_equipped := false
	var dowsing_pendulum_equipped := false
	var dowsing_pendulum_range := 0.0
	var dowsing_pendulum_context: Dictionary = {}
	var slot_add_equipped := false
	var slot_add_active_item_slot_bonus := 0
	var active_item_slot_capacity_bonus := 0
	var active_item_slot_capacity := 3
	var cooltime_equipped := false
	var cooltime_active_item_cooldown_reduction_pct := 0.0
	var active_item_cooldown_reduction_pct := 0.0
	var poseidon_trident_equipped := false
	var poseidon_trident_context: Dictionary = {}
	var redraw_queued := false

	func queue_redraw() -> void:
		redraw_queued = true


class FakeDashState:
	var snapshot: Dictionary = {
		"active": false,
		"recovering": false,
		"direction": 0.0,
	}

	func get_snapshot() -> Dictionary:
		return snapshot.duplicate(true)


class FakeAudio:
	var poseidon_wave_calls := 0
	var poseidon_charge_calls := 0

	func play_poseidon_wave() -> void:
		poseidon_wave_calls += 1

	func play_poseidon_charge() -> void:
		poseidon_charge_calls += 1


class FakeFeedback:
	var shake_amount := 0.0
	var shake_intensity := 0.0

	func max_screen_shake(amount: float, intensity: float) -> void:
		shake_amount = max(shake_amount, amount)
		shake_intensity = max(shake_intensity, intensity)


class FakeRegistry:
	var runtime: Object
	var dash_state: Object
	var audio: Object
	var feedback: Object

	func _init(
		new_runtime: Object,
		new_dash_state: Object,
		new_audio: Object,
		new_feedback: Object
	) -> void:
		runtime = new_runtime
		dash_state = new_dash_state
		audio = new_audio
		feedback = new_feedback

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
	var catalog: Object = MythicItemCatalog.new()
	var item_data: Dictionary = catalog.build_item_by_name("poseidon_trident")
	_expect(not item_data.is_empty(), "Poseidon Trident should exist in the mythic catalog")
	_expect(str(item_data.get("slot", "")) == "arm", "Poseidon Trident should route through the shared arm equipment slots")
	_expect(str(item_data.get("icon_sheet_path", "")) != "", "Poseidon Trident should use an animated icon sheet")
	_expect(int(item_data.get("icon_frame_count", 0)) == 32, "Poseidon Trident should expose 32 smooth icon frames")
	_expect(bool(item_data.get("icon_fill_slot", false)), "Poseidon Trident icon should fill the slot box")
	_expect_original_icon_assets(item_data, "Poseidon Trident")
	_expect(ResourceLoader.exists("res://assets/sounds/poseidon.wav"), "Poseidon wave sound should load")
	_expect(ResourceLoader.exists("res://assets/sounds/poseidoncharge.wav"), "Poseidon charge-ready sound should load")
	_expect_poseidon_query_ownership()

	var field_spawn_items: Array = catalog.get_field_spawn_items()
	_expect(_array_has_item(field_spawn_items, "poseidon_trident"), "Poseidon Trident should be in the mythic field-spawn list")

	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var dash_state := FakeDashState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, dash_state, audio, feedback)

	_expect(
		runtime.equip_item(
			"poseidon_trident",
			owner,
			registry,
			{"cooldown": 0.1, "gauge_cost": 30.0, "vortex_size": 200.0},
			false
		),
		"Poseidon Trident should equip through mythic_item_runtime"
	)
	_expect(owner.equipment_slots.has("left_arm"), "first equipped arm item should occupy the left arm slot")
	_expect(str(owner.equipment_slots["left_arm"].get("_equipped_slot", "")) == "left_arm", "synced Poseidon Trident should expose the resolved left arm slot")
	_expect(owner.poseidon_trident_equipped, "owner should receive Poseidon equipped sync")

	dash_state.snapshot = {"active": true, "recovering": false, "direction": -1.0}
	runtime.update(owner, registry, 1.0 / 60.0)
	dash_state.snapshot = {"active": false, "recovering": true, "direction": -1.0}
	runtime.update(owner, registry, 1.0 / 60.0)

	var snapshot: Dictionary = runtime.get_snapshot()
	_expect(bool(snapshot.get("poseidon_trident_vortex_active", false)), "dash recovery should trigger Poseidon vortex")
	_expect(is_equal_approx(owner.special_gauge, 70.0), "Poseidon trigger should consume the rolled gauge cost")
	_expect(audio.poseidon_wave_calls == 1, "Poseidon trigger should play its wave sound")
	_expect(feedback.shake_amount > 0.0 and feedback.shake_intensity > 0.0, "Poseidon trigger should request screen feedback")
	_expect(owner.redraw_queued, "Poseidon trigger should queue a redraw")
	_expect(runtime.poseidon_particles.size() <= MythicItemRuntime.POSEIDON_MAX_PARTICLES, "Poseidon trigger should stay within the runtime particle budget")

	for _i in range(20):
		runtime.update(owner, registry, 1.0 / 60.0)
	_expect(runtime.poseidon_particles.size() <= MythicItemRuntime.POSEIDON_MAX_PARTICLES, "Poseidon update should keep particles capped")
	_expect(runtime.poseidon_explosion_particles.size() <= MythicItemRuntime.POSEIDON_EXPLOSION_PARTICLE_COUNT, "Poseidon charge flash should keep explosion particles capped")
	_expect(audio.poseidon_charge_calls == 1, "Poseidon cooldown completion should play its charge-ready sound once")

	var anchor := owner.player_pos + Vector2(owner.player_paddle_width * 0.5, owner.player_paddle_height * 0.5)
	var scene := {
		"ball_pos": anchor + Vector2(-120.0, -70.0),
		"ball_vel": Vector2(0.0, 11.0),
		"ball_impact_boost": 1.0,
	}
	var wave_result: Dictionary = runtime.apply_poseidon_wave_to_ball(scene, 1.0, {}, {
		"registry": registry,
		"feedback": feedback,
	})
	_expect(bool(wave_result.get("poseidon_trident_captured", false)), "ball inside the Poseidon vortex should be captured first")
	_expect(bool(wave_result.get("skip_ball_motion_step", false)), "captured Poseidon ball should skip normal motion")
	_expect(bool(runtime.get_snapshot().get("poseidon_trident_capture_active", false)), "Poseidon capture state should be visible in the snapshot")
	_expect(bool(runtime.get_ball_draw_context().get("poseidon_trident_ball_active", false)), "Poseidon captured ball should expose water overlay context")

	var start_capture_pos: Vector2 = scene["ball_pos"]
	var released := false
	var reflected_vel := Vector2.ZERO
	for _capture_frame in range(48):
		if wave_result.has("ball_pos"):
			scene["ball_pos"] = wave_result["ball_pos"]
		if wave_result.has("ball_vel"):
			scene["ball_vel"] = wave_result["ball_vel"]
		if wave_result.has("skip_ball_motion_step"):
			scene["skip_ball_motion_step"] = bool(wave_result.get("skip_ball_motion_step", false))
		if wave_result.has("ball_impact_boost"):
			scene["ball_impact_boost"] = wave_result["ball_impact_boost"]
		if bool(wave_result.get("poseidon_trident_released", false)):
			released = true
			reflected_vel = wave_result["ball_vel"]
			break
		wave_result = runtime.apply_poseidon_wave_to_ball(scene, 1.0, {}, {
			"registry": registry,
			"feedback": feedback,
		})

	_expect(released, "Poseidon captured ball should release after a short spiral")
	_expect((scene["ball_pos"] as Vector2).y < start_capture_pos.y - 80.0, "Poseidon captured ball should spiral upward before release")
	_expect(reflected_vel.y < 0.0, "Poseidon vortex should release boss-hit balls upward")
	_expect(not bool(scene.get("skip_ball_motion_step", true)), "Poseidon release should resume the normal ball motion step")
	var release_deviation_deg: float = abs(rad_to_deg(atan2(reflected_vel.x, -reflected_vel.y)))
	_expect(release_deviation_deg <= 45.01, "Poseidon release should stay within the upward -45 to +45 degree fan")
	_expect(float(scene.get("ball_impact_boost", 1.0)) > 1.0, "Poseidon release should preserve a strong impact boost")

	var boss_result: Dictionary = runtime.apply_poseidon_boss_hit(Vector2(8.0, -20.0))
	_expect(boss_result.has("ball_vel"), "boss hit should clear Poseidon water momentum")
	_expect(is_equal_approx((boss_result["ball_vel"] as Vector2).length(), Vector2(8.0, -20.0).length() * 0.5), "boss hit should soften the Poseidon-reflected ball")

	_expect_poseidon_releases_through_ball_update_controller()

	print("poseidon_trident_port_smoke: ok")
	quit(0)


func _expect_poseidon_releases_through_ball_update_controller() -> void:
	var runtime: Object = MythicItemRuntime.new()
	var owner := FakeOwner.new()
	var dash_state := FakeDashState.new()
	var audio := FakeAudio.new()
	var feedback := FakeFeedback.new()
	var registry := FakeRegistry.new(runtime, dash_state, audio, feedback)
	_expect(
		runtime.equip_item(
			"poseidon_trident",
			owner,
			registry,
			{"cooldown": 2.0, "gauge_cost": 20.0, "vortex_size": 200.0},
			false
		),
		"controller Poseidon setup should equip the trident"
	)
	dash_state.snapshot = {"active": true, "recovering": false, "direction": 1.0}
	runtime.update(owner, registry, 1.0 / 60.0)
	dash_state.snapshot = {"active": false, "recovering": true, "direction": 1.0}
	runtime.update(owner, registry, 1.0 / 60.0)
	for _warmup_frame in range(20):
		runtime.update(owner, registry, 1.0 / 60.0)

	var anchor := owner.player_pos + Vector2(owner.player_paddle_width * 0.5, owner.player_paddle_height * 0.5)
	var context := {
		"ball_active": true,
		"ball_pos": anchor + Vector2(120.0, -70.0),
		"ball_vel": Vector2(0.0, 11.0),
		"skip_ball_motion_step": false,
		"ball_impact_boost": 1.0,
		"ball_boost_decay_rate": 0.975,
		"ball_min_boost": 0.70,
		"player_collision_cooldown": 0.0,
		"boss_collision_cooldown": 0.0,
		"vertical_bounce_count": 0,
		"ball_spin_strength": 0.0,
		"ball_spin_direction": 0,
		"drive_ball_active": false,
		"drive_hit_boss": false,
		"drive_speed_increase": 0.0,
		"drive_text_timer_frames": 0.0,
		"special_gauge": owner.special_gauge,
		"selected_character_type": "smasher",
		"player_pos": owner.player_pos,
		"player_paddle_size": Vector2(owner.player_paddle_width, owner.player_paddle_height),
	}
	var deps := {
		"registry": registry,
		"mythic_item_runtime": runtime,
		"feedback": feedback,
	}
	var controller := BallUpdateController.new()
	var capture_started := false
	var released := false
	var start_capture_pos := Vector2.ZERO
	for _frame in range(80):
		var result: Dictionary = controller.update(1.0 / 60.0, context, deps)
		var snapshot: Variant = result.get("snapshot", {})
		if snapshot is Dictionary:
			context.merge(snapshot, true)
		if bool(context.get("skip_ball_motion_step", false)):
			capture_started = true
			if start_capture_pos == Vector2.ZERO:
				start_capture_pos = context["ball_pos"]
		elif capture_started:
			released = true
			break

	_expect(capture_started, "ball-update controller should enter Poseidon capture on vortex contact")
	_expect(released, "ball-update controller should continue Poseidon capture instead of freezing behind skip_ball_motion_step")
	_expect(not bool(context.get("skip_ball_motion_step", true)), "controller Poseidon release should clear the motion-skip flag")
	_expect(_as_vector2(context.get("ball_pos", Vector2.ZERO), Vector2.ZERO).y < start_capture_pos.y - 80.0, "controller Poseidon capture should spiral upward before release")
	_expect(_as_vector2(context.get("ball_vel", Vector2.ZERO), Vector2.ZERO).y < 0.0, "controller Poseidon release should launch the ball upward")


func _expect_poseidon_query_ownership() -> void:
	var poseidon_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_poseidon_runtime.gd")
	var context_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_context_builder.gd")
	var snapshot_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_snapshot_builder.gd")
	var syncer_source := FileAccess.get_file_as_string("res://scripts/items/mythic_item_owner_syncer.gd")
	_expect(poseidon_source.find("func is_equipped(") >= 0, "Poseidon helper should own equipped checks")
	_expect(poseidon_source.find("runtime.is_equipped(ITEM_POSEIDON_TRIDENT)") < 0, "Poseidon helper should not call the generic runtime equipped facade")
	_expect(context_source.find("poseidon_runtime.is_equipped(runtime)") >= 0, "Poseidon context should delegate equipped checks to the helper")
	_expect(snapshot_source.find("\"poseidon_trident_equipped\": runtime.poseidon_runtime.is_equipped(runtime)") >= 0, "Poseidon snapshot should delegate equipped checks to the helper")
	_expect(syncer_source.find("owner.set(\"poseidon_trident_equipped\", runtime.poseidon_runtime.is_equipped(runtime))") >= 0, "Poseidon owner sync should delegate equipped checks to the helper")


func _array_has_item(items: Array, item_name: String) -> bool:
	for item_value in items:
		if item_value is Dictionary and str(item_value.get("name", "")) == item_name:
			return true
	return false


func _expect_original_icon_assets(item_data: Dictionary, item_label: String) -> void:
	var icon: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_path", "")))
	_expect(icon != null, "%s static icon should load" % item_label)
	if icon != null:
		_expect(icon.get_width() == 32 and icon.get_height() == 32, "%s static icon should be the original 32px render" % item_label)

	var sheet: Texture2D = ProjectResourceLoader.load_texture(str(item_data.get("icon_sheet_path", "")))
	_expect(sheet != null, "%s animated icon sheet should load" % item_label)
	if sheet != null:
		_expect(sheet.get_width() == 1024 and sheet.get_height() == 32, "%s animated icon sheet should be the smooth 32-frame render" % item_label)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)


func _as_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
