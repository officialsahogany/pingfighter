extends SceneTree

const CommandoSkillConfig := preload("res://scripts/characters/commando_skill_config.gd")
const CommandoSkillState := preload("res://scripts/characters/commando_skill_state.gd")
const CommandoSupplyDropState := preload("res://scripts/characters/commando_supply_drop_state.gd")
const EFFECT_STATE_PATH := "res://scripts/characters/commando_supply_drop_effect_state.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


func _init() -> void:
	_verify_owner_boundary()
	_verify_drop_effect_motion_and_expiry()
	_verify_aircraft_hit_and_smoke_recipes()
	_verify_ground_explosion_recipe_and_motion()
	_verify_snapshot_isolation_and_restore()
	_verify_host_facade_uses_effect_state()

	if _failures.is_empty():
		print("commando_supply_drop_effect_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(EFFECT_STATE_PATH), "Commando Supply Drop transient effects should have a focused state owner")
	if not FileAccess.file_exists(EFFECT_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(EFFECT_STATE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropEffectState := preload(\"%s\")" % EFFECT_STATE_PATH) >= 0,
		"Supply Drop host should preload the focused effect state"
	)
	_expect(
		host_source.find("var _effect_state: Object = CommandoSupplyDropEffectState.new()") >= 0,
		"Supply Drop host should retain one effect state instance"
	)
	for marker in [
		"func reset(",
		"func advance(",
		"func spawn_drop(",
		"func spawn_aircraft_hit(",
		"func spawn_aircraft_smoke(",
		"func spawn_aircraft_explosion(",
		"func has_effects(",
		"func get_snapshot(",
		"func restore(",
	]:
		_expect(owner_source.find(marker) >= 0, "effect state should implement %s" % marker)
	for moved_marker in [
		"var drop_effects: Array[Dictionary]",
		"var explosion_effects: Array[Dictionary]",
		"func _spawn_drop_effect(",
		"func _update_drop_effects(",
		"func _spawn_aircraft_hit_effects(",
		"func _spawn_aircraft_smoke_effect(",
		"func _spawn_aircraft_explosion_effects(",
		"func _update_explosion_effects(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop host should not retain transient effect marker %s" % moved_marker)
	_expect(
		host_source.find("_effect_state.advance(safe_delta)") >= 0,
		"frame update should delegate transient effect motion to the focused owner"
	)
	_expect(
		host_source.find("_effect_state.spawn_drop(drop, drop_position)") >= 0,
		"resolved payload dispatch should delegate its fading drop effect"
	)
	_expect(
		host_source.find("_effect_state.spawn_aircraft_explosion(impact_pos)") >= 0,
		"ground impact should delegate its debris recipe"
	)


func _verify_drop_effect_motion_and_expiry() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.spawn_drop({
		"type": "field_item",
		"item_id": "grenade",
		"drop_position": Vector2(100.0, 200.0),
	}, Vector2(20.0, 30.0))
	var effects: Array = state.get_drop_effects()
	_expect(effects.size() == 1, "resolved payload should create one fading drop effect")
	if not effects.is_empty():
		var effect: Dictionary = effects[0]
		_expect(str(effect.get("item_id", "")) == "grenade", "drop effect should retain its item identity")
		_expect(is_equal_approx(float(effect.get("life", 0.0)), 0.55), "drop effect should retain the shipped 0.55-second lifetime")
		_expect(effect.get("pos", Vector2.ZERO) == Vector2(100.0, 200.0), "drop effect should start at the resolved payload position")
	state.advance(0.25)
	effects = state.get_drop_effects()
	if not effects.is_empty():
		var moved: Dictionary = effects[0]
		_expect(is_equal_approx(float(moved.get("life", 0.0)), 0.30), "drop effect should decrement by safe frame delta")
		_expect((moved.get("pos", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(100.0, 221.0)), "drop effect should fall at 84 pixels per second")
	state.advance(0.31)
	_expect(state.get_drop_effects().is_empty(), "expired drop effect should leave the live array")


func _verify_aircraft_hit_and_smoke_recipes() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.spawn_aircraft_hit(Vector2(300.0, 100.0))
	var effects: Array = state.get_explosion_effects()
	_expect(effects.size() == 19, "aircraft hit should create 12 sparks and 7 smoke puffs")
	_expect(_count_kind(effects, "spark") == 12, "aircraft hit should preserve its 12-spark ring")
	_expect(_count_kind(effects, "smoke") == 7, "aircraft hit should preserve its 7-smoke trail")
	state.reset()
	state.spawn_aircraft_smoke(Vector2(100.0, 100.0), "left_to_right")
	effects = state.get_explosion_effects()
	if not effects.is_empty():
		var left_to_right: Dictionary = effects[0]
		_expect(left_to_right.get("pos", Vector2.ZERO) == Vector2(76.0, 108.0), "left-to-right damage smoke should trail behind the aircraft")
		_expect(left_to_right.get("vel", Vector2.ZERO) == Vector2(-18.0, -34.0), "left-to-right damage smoke should drift backward and up")
	state.reset()
	state.spawn_aircraft_smoke(Vector2(100.0, 100.0), "right_to_left")
	effects = state.get_explosion_effects()
	if not effects.is_empty():
		var right_to_left: Dictionary = effects[0]
		_expect(right_to_left.get("pos", Vector2.ZERO) == Vector2(124.0, 108.0), "right-to-left damage smoke should mirror its trail")
		_expect(right_to_left.get("vel", Vector2.ZERO) == Vector2(18.0, -34.0), "right-to-left damage smoke velocity should mirror")


func _verify_ground_explosion_recipe_and_motion() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.spawn_aircraft_explosion(Vector2(100.0, 100.0))
	var effects: Array = state.get_explosion_effects()
	_expect(effects.size() == 42, "ground crash should create its 18-spark, 14-smoke, 10-debris recipe")
	_expect(_count_kind(effects, "spark") == 18, "ground crash should preserve 18 sparks")
	_expect(_count_kind(effects, "smoke") == 14, "ground crash should preserve 14 smoke puffs")
	_expect(_count_kind(effects, "debris") == 10, "ground crash should preserve 10 debris pieces")
	state.advance(0.1)
	effects = state.get_explosion_effects()
	if not effects.is_empty():
		var moved: Dictionary = effects[0]
		var moved_pos: Vector2 = moved.get("pos", Vector2.ZERO)
		_expect(moved_pos.x > 100.0 and moved_pos.y > 100.0, "explosion particle should apply velocity after downward gravity")
		_expect(is_equal_approx(float(moved.get("life", 0.0)), 0.48), "spark lifetime should decrement by frame delta")
	state.advance(1.0)
	_expect(state.get_explosion_effects().is_empty(), "all crash particles should expire after their longest 0.96-second lifetime")


func _verify_snapshot_isolation_and_restore() -> void:
	var state: Object = _new_state()
	if state == null:
		return
	state.spawn_drop({"type": "field_item", "item_id": "flare"}, Vector2(10.0, 20.0))
	state.spawn_aircraft_smoke(Vector2(30.0, 40.0), "left_to_right")
	var snapshot: Dictionary = state.get_snapshot()
	(snapshot.get("drop_effects", []) as Array)[0]["item_id"] = "changed"
	_expect(str((state.get_drop_effects()[0] as Dictionary).get("item_id", "")) == "flare", "effect snapshot should deep-copy mutable entries")
	state.restore({
		"drop_effects": [{"life": 0.2, "pos": Vector2.ONE}, "invalid"],
		"explosion_effects": ["invalid", {"life": 0.3, "pos": Vector2(2.0, 3.0)}],
	})
	_expect(state.get_drop_effects().size() == 1, "restore should filter invalid drop effect entries")
	_expect(state.get_explosion_effects().size() == 1, "restore should filter invalid explosion effect entries")
	state.reset()
	_expect(not state.has_effects(), "reset should clear both transient effect arrays")


func _verify_host_facade_uses_effect_state() -> void:
	var state: Object = CommandoSupplyDropState.new()
	var deps := {
		"commando_supply_drop_payload_count": 1,
		"commando_supply_drop_forced_payloads": [
			{"type": "field_item", "item_id": "grenade"},
		],
		"commando_supply_drop_aircraft_arrival_delay": 0.0,
		"commando_supply_drop_payload_delays": [1.15],
		"current_stage": 1,
	}
	var activated: Dictionary = state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	_expect(bool(activated.get("activated", false)), "production host should activate for effect-state integration")
	var resolved: Dictionary = state.update(4.2, deps)
	_expect(bool(resolved.get("drop_resolved", false)), "production host should resolve a payload through the effect owner")
	_expect((state.get_snapshot().get("drop_effects", []) as Array).size() == 1, "production payload dispatch should expose one fading effect")
	state.update(0.56, deps)
	_expect((state.get_snapshot().get("drop_effects", []) as Array).is_empty(), "production update should expire the delegated drop effect")

	state.reset()
	state.update_input(
		{"down_pressed": true, "action_pressed": true},
		1.0,
		500.0,
		CommandoSkillConfig.new(),
		CommandoSkillState.new(),
		deps
	)
	state.update(0.35, deps)
	var aircraft_pos: Vector2 = state.get_snapshot().get("aircraft_pos", Vector2.ZERO)
	var hit: bool = state.resolve_ball_collision({
		"previous_ball_pos": aircraft_pos + Vector2(0.0, 22.0),
		"ball_pos": aircraft_pos,
		"ball_vel": Vector2(0.0, -12.0),
	}, {"ball_size": 28.6, "last_hit_by": "player"}, deps)
	_expect(hit, "production aircraft hit should route its impact recipe to the effect owner")
	_expect((state.get_snapshot().get("explosion_effects", []) as Array).size() == 19, "production shoot-down should expose the 19-piece hit recipe")
	state.update(CommandoSupplyDropState.AIRCRAFT_CRASH_SECONDS + 0.05, deps)
	var impact_snapshot: Dictionary = state.get_snapshot()
	var impact_effects: Array = impact_snapshot.get("explosion_effects", [])
	_expect(impact_effects.size() >= 42, "production ground impact should expose the 42-piece crash recipe plus any final descent smoke")
	var impact_center: Vector2 = impact_snapshot.get("crash_blast_center", Vector2.ZERO)
	state.update(0.1, deps)
	var moved_effects: Array = state.get_snapshot().get("explosion_effects", [])
	var moved_spark: Dictionary = _find_kind(moved_effects, "spark")
	if not moved_spark.is_empty():
		var moved_pos: Vector2 = moved_spark.get("pos", Vector2.ZERO)
		_expect(moved_pos.y > impact_center.y, "production crash particle should apply the delegated downward gravity")


func _new_state() -> Object:
	if not FileAccess.file_exists(EFFECT_STATE_PATH):
		return null
	var state_script: Script = load(EFFECT_STATE_PATH)
	return state_script.new()


func _count_kind(effects: Array, kind: String) -> int:
	var count := 0
	for effect_value in effects:
		if effect_value is Dictionary and str((effect_value as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _find_kind(effects: Array, kind: String) -> Dictionary:
	for effect_value in effects:
		if effect_value is Dictionary and str((effect_value as Dictionary).get("kind", "")) == kind:
			return effect_value as Dictionary
	return {}


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
