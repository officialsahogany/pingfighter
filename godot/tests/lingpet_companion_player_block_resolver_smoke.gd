extends SceneTree

const LingpetCompanionPlayerBlockResolver := preload("res://scripts/lingpet/lingpet_companion_player_block_resolver.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var player_pos := Vector2(300.0, 700.0)
	var player_paddle_width := 170.0
	var ball_pos := Vector2(300.0, 650.0)
	var ball_size := 28.6


func _init() -> void:
	_verify_null_and_missing_player_guards()
	_verify_horizontal_player_reach_contract()
	_verify_runtime_delegates_player_block_resolver()

	if _failures.is_empty():
		print("lingpet_companion_player_block_resolver_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_null_and_missing_player_guards() -> void:
	var resolver := LingpetCompanionPlayerBlockResolver.new()
	_expect(not resolver.can_player_block(null, 14.3, 155.0), "null owner should not block companion hits")

	var owner := FakeOwner.new()
	owner.player_pos = Vector2.ZERO
	owner.ball_pos = Vector2(320.0, 650.0)
	_expect(not resolver.can_player_block(owner, 14.3, 155.0), "missing player position should not silently disable companion guard")


func _verify_horizontal_player_reach_contract() -> void:
	var resolver := LingpetCompanionPlayerBlockResolver.new()
	var owner := FakeOwner.new()
	owner.player_pos = Vector2(300.0, 700.0)
	owner.player_paddle_width = 170.0
	owner.ball_size = 28.6

	owner.ball_pos = Vector2(300.0 - 14.3, 650.0)
	_expect(resolver.can_player_block(owner, 14.3, 155.0), "left ball-radius edge should count as player reach")
	owner.ball_pos = Vector2(300.0 + 170.0 + 14.3, 650.0)
	_expect(resolver.can_player_block(owner, 14.3, 155.0), "right paddle-plus-radius edge should count as player reach")

	owner.ball_pos = Vector2(300.0 - 14.4, 650.0)
	_expect(not resolver.can_player_block(owner, 14.3, 155.0), "ball just left of player reach should stay companion-eligible")
	owner.ball_pos = Vector2(300.0 + 170.0 + 14.4, 650.0)
	_expect(not resolver.can_player_block(owner, 14.3, 155.0), "ball just right of player reach should stay companion-eligible")

	owner.ball_size = 0.0
	owner.player_paddle_width = 0.0
	owner.ball_pos = Vector2(301.0, 650.0)
	_expect(resolver.can_player_block(owner, 14.3, 155.0), "zero-sized values should clamp to a minimum usable reach")


func _verify_runtime_delegates_player_block_resolver() -> void:
	var runtime_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_egg_runtime.gd")
	var resolver_source := FileAccess.get_file_as_string("res://scripts/lingpet/lingpet_companion_player_block_resolver.gd")
	_expect(runtime_source.find("LingpetCompanionPlayerBlockResolver") >= 0, "egg runtime should preload the player-block resolver")
	_expect(runtime_source.find("_companion_player_block_resolver.can_player_block") >= 0, "runtime player-priority wrapper should delegate")
	_expect(resolver_source.find("BattleSceneOwnerReader") >= 0, "resolver should own owner-field reads")
	_expect(resolver_source.find("player_paddle_width") >= 0 and resolver_source.find("ball_size") >= 0, "resolver should own the player reach width/radius fields")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
