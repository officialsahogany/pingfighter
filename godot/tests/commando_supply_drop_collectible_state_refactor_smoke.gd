extends SceneTree

const COLLECTIBLE_STATE_PATH := "res://scripts/characters/commando_supply_drop_collectible_state.gd"
const HOST_PATH := "res://scripts/characters/commando_supply_drop_state.gd"

var _failures: Array[String] = []


class FakeWeaponController:
	extends RefCounted

	var grant_result := true
	var calls: Array = []

	func add_rental_weapon(weapon_id: String, stage: int, duration: int, from_supply: bool, switch_now: bool) -> bool:
		calls.append([weapon_id, stage, duration, from_supply, switch_now])
		return grant_result


class FakeAudio:
	extends RefCounted

	var calls: Array[String] = []

	func play_commando_weapon_change() -> void:
		calls.append("play_commando_weapon_change")

	func play_item_get() -> void:
		calls.append("play_item_get")

	func play_commando_supply_drop() -> void:
		calls.append("play_commando_supply_drop")


class FakeActiveItemRuntime:
	extends RefCounted

	var collect_result := false
	var calls: Array = []

	func collect_item_by_name(item_id: String, pos: Vector2, owner: Object, registry: Object) -> bool:
		calls.append([item_id, pos, owner, registry])
		return collect_result


func _init() -> void:
	_verify_owner_boundary()
	_verify_spawn_motion_snapshot_and_despawn()
	_verify_rental_pickup_routing()
	_verify_rejected_field_item_retention()

	if _failures.is_empty():
		print("commando_supply_drop_collectible_state_refactor_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_owner_boundary() -> void:
	_expect(FileAccess.file_exists(COLLECTIBLE_STATE_PATH), "Commando Supply Drop collectibles should have a focused lifecycle owner")
	if not FileAccess.file_exists(COLLECTIBLE_STATE_PATH):
		return
	var host_source := FileAccess.get_file_as_string(HOST_PATH)
	var owner_source := FileAccess.get_file_as_string(COLLECTIBLE_STATE_PATH)
	_expect(
		host_source.find("const CommandoSupplyDropCollectibleState := preload(\"%s\")" % COLLECTIBLE_STATE_PATH) >= 0,
		"Supply Drop state should preload the focused collectible owner"
	)
	_expect(
		host_source.find("var _collectible_state: Object = CommandoSupplyDropCollectibleState.new()") >= 0,
		"Supply Drop state should retain one collectible owner instance"
	)
	for marker in [
		"func reset(",
		"func restore(",
		"func get_snapshot(",
		"func spawn(",
		"func update(",
		"func resolve_pickups(",
		"func get_drop_rect(",
	]:
		_expect(owner_source.find(marker) >= 0, "collectible owner should implement %s" % marker)
	for moved_marker in [
		"var collectible_drops:",
		"func _spawn_field_item(",
		"func _spawn_collectible_drop(",
		"func _update_collectible_drops(",
		"func _collect_drop(",
		"func _collect_field_item_drop(",
		"func _collectible_drop_hits_player(",
		"func _get_collectible_drop_rect(",
	]:
		_expect(host_source.find(moved_marker) < 0, "Supply Drop state should not retain collectible marker %s" % moved_marker)
	_expect(
		host_source.find("_collectible_state.update(safe_delta, deps)") >= 0,
		"frame update should delegate collectible motion to the focused owner"
	)
	_expect(
		host_source.find("_collectible_state.spawn(drop, drop_position)") >= 0,
		"payload resolution should delegate collectible spawn to the focused owner"
	)
	_expect(
		host_source.find("return _collectible_state.resolve_pickups(player_rect, deps)") >= 0,
		"pickup facade should delegate reward resolution to the focused owner"
	)


func _verify_spawn_motion_snapshot_and_despawn() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.spawn({
		"type": "rental_weapon",
		"weapon_id": "ak47",
		"payload_index": 2,
		"drop_position": Vector2(100.0, 100.0),
	}, Vector2(380.0, 160.0))
	_expect(owner.drops.size() == 1, "spawn should append one collectible")
	var spawned: Dictionary = owner.drops[0]
	_expect(spawned.get("pos", Vector2.ZERO) == Vector2(100.0, 100.0), "spawn should prefer the payload drop position")
	_expect_close(float(spawned.get("sway_phase", 0.0)), 1.66, "payload index should deterministically seed sway phase")
	_expect_close(float(spawned.get("vy", 0.0)), 184.0, "payload index should stagger fall speed by eight pixels per second")
	_expect(bool(spawned.get("active", false)), "spawned collectible should be active")
	var snapshot: Array[Dictionary] = owner.get_snapshot()
	snapshot[0]["pos"] = Vector2.ZERO
	_expect(owner.drops[0].get("pos", Vector2.ZERO) == Vector2(100.0, 100.0), "snapshot mutation must not alias live collectible state")

	owner.update(1.0, {"play_width": 200.0, "play_height": 800.0})
	var moved: Dictionary = owner.drops[0]
	var moved_pos: Vector2 = moved.get("pos", Vector2.ZERO)
	_expect(moved_pos.x >= 32.0 and moved_pos.x <= 168.0, "sway should stay inside the shipped safe margins")
	_expect_close(moved_pos.y, 284.0, "fall motion should use the payload-index-adjusted velocity")
	_expect_close(float(moved.get("rotation", 0.0)), 120.0, "collectible rotation should advance at 120 degrees per second")
	var drop_rect: Rect2 = owner.get_drop_rect(moved)
	_expect(drop_rect.size == Vector2(40.0, 30.0), "pickup hitbox should preserve the shipped 40x30 box")
	_expect(drop_rect.get_center().is_equal_approx(moved_pos), "pickup hitbox should remain centered on the collectible")

	owner.restore([{ "pos": Vector2(100.0, 849.0), "vy": 20.0 }, "invalid"])
	_expect(owner.drops.size() == 1, "restore should retain only dictionary entries")
	owner.update(0.1, {"play_height": 800.0})
	_expect(owner.drops.is_empty(), "collectible below play height plus 50px margin should despawn")


func _verify_rental_pickup_routing() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.spawn({
		"type": "rental_weapon",
		"weapon_id": "bazooka",
		"drop_position": Vector2(100.0, 100.0),
	}, Vector2.ZERO)
	var weapons := FakeWeaponController.new()
	var audio := FakeAudio.new()
	var result: Dictionary = owner.resolve_pickups(
		Rect2(70.0, 70.0, 60.0, 60.0),
		{
			"commando_weapon_controller": weapons,
			"current_stage": 4,
			"audio": audio,
		}
	)
	_expect(bool(result.get("pickup_resolved", false)), "overlapping rental collectible should resolve")
	_expect(owner.drops.is_empty(), "resolved rental collectible should be consumed")
	_expect(weapons.calls == [["bazooka", 4, -1, true, true]], "rental pickup should route the exact production grant arguments")
	_expect(audio.calls == ["play_commando_weapon_change", "play_item_get"], "granted rental should play weapon-change then first pickup cue")
	var picked: Dictionary = result.get("picked_drop", {})
	_expect(bool(picked.get("rental_granted", false)), "pickup result should publish the granted rental state")


func _verify_rejected_field_item_retention() -> void:
	var owner: Object = _new_owner()
	if owner == null:
		return
	owner.spawn({
		"type": "field_item",
		"item_id": "ammo_box",
		"drop_position": Vector2(100.0, 100.0),
	}, Vector2.ZERO)
	var active_items := FakeActiveItemRuntime.new()
	var owner_token := RefCounted.new()
	var registry_token := RefCounted.new()
	var rejected: Dictionary = owner.resolve_pickups(
		Rect2(70.0, 70.0, 60.0, 60.0),
		{
			"active_item_runtime": active_items,
			"owner": owner_token,
			"registry": registry_token,
		}
	)
	_expect(bool(rejected.get("pickup_rejected", false)), "rejected field item should publish rejection")
	_expect(int(rejected.get("rejected_pickups", 0)) == 1, "rejected field item should increment the rejection count")
	_expect(owner.drops.size() == 1, "rejected field item should stay as a collectible")
	_expect(active_items.calls.size() == 1, "field-item pickup should call the production collect route once")
	active_items.collect_result = true
	var accepted: Dictionary = owner.resolve_pickups(
		Rect2(70.0, 70.0, 60.0, 60.0),
		{
			"active_item_runtime": active_items,
			"owner": owner_token,
			"registry": registry_token,
		}
	)
	_expect(bool(accepted.get("pickup_resolved", false)), "accepted field item should resolve on the next overlap")
	_expect(owner.drops.is_empty(), "accepted field item should consume the retained collectible")
	var picked: Dictionary = accepted.get("picked_drop", {})
	_expect(bool(picked.get("field_item_collected", false)), "accepted field item should publish collection success")


func _new_owner() -> Object:
	if not FileAccess.file_exists(COLLECTIBLE_STATE_PATH):
		return null
	var owner_script: Script = load(COLLECTIBLE_STATE_PATH)
	return owner_script.new()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _expect_close(actual: float, expected: float, message: String, tolerance: float = 0.0001) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.5f, got %.5f)" % [message, expected, actual])
