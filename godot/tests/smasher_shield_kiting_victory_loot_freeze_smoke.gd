extends SceneTree

# 회귀 씰: 승리 전리품 페이즈(보스 패배 -> 상자 드랍) 중 회천비륜이 발동하면
# 캐릭터가 영구 정지하던 버그.
#
# 원인 = 두 사실의 곱.
#  (1) 매치 종료 득점은 reset_ball을 거치지 않는다(match_scoreboard_flow_controller는
#      update_start_serve에서만 reset_ball을 부른다) -> owner.ball_active가 마지막
#      랠리의 true 그대로 전리품 페이즈까지 살아 있다.
#  (2) battle_frame_flow_controller의 loot 분기는 update_player_control만 돌리고
#      update_ball은 동결한다 -> 회천비륜 투사체를 전진시키는 유일한 경로
#      (update_and_collide, 볼 패스 전용)가 한 번도 실행되지 않는다.
# 결과: WIND_UP 투사체가 영원히 발사되지 않고 is_movement_locked()가 true로 고정 ->
# 플레이어가 상자를 주우러 갈 수 없어 전리품 페이즈가 끝나지 않는 소프트락.
#
# 봉인 지점 2곳:
#  A. 공용 게이트 - player-control config의 ball_active를 victory_loot_phase_active와
#     함께 닫는다(공-의존 스킬 전체의 신규 발동 차단).
#  B. 자기치유 - 공 게이트가 닫힌 프레임에 살아있는 투사체를 해제해, 페이즈 진입
#     직전에 이미 감기고 있던 투사체의 이동잠금도 풀리게 한다.

const PlayerControlConfigBuilder := preload("res://scripts/core/battle_scene_player_control_config_builder.gd")
const SmasherShieldKitingState := preload("res://scripts/characters/smasher_shield_kiting_state.gd")

var _failures: Array[String] = []


class FakeOwner:
	extends RefCounted

	var selected_character_type := "smasher"
	var player_pos := Vector2(302.5, 690.0)
	var player_speed := 0.0
	var player_paddle_width := 155.0
	var player_paddle_height := 50.0
	var special_gauge := 500.0
	var special_gauge_max := 500.0
	var current_stage := 1
	var ball_active := true
	var ball_pos := Vector2(315.0, 410.0)
	var ball_vel := Vector2(0.0, 8.0)
	var ball_impact_boost := 1.0
	var boss_pos := Vector2(345.0, 25.0)
	var victory_loot_phase_active := false


class FakeRegistry:
	extends RefCounted

	func get_instance(_key: String) -> Object:
		return null


class FakeContextBuilder:
	extends RefCounted

	func build_player_control_config(_character_type: String = "smasher") -> Dictionary:
		return {
			"paddle_width": 155.0,
			"paddle_speed": 6.0,
			"paddle_max_speed": 10.0,
			"paddle_accel": 2.0,
			"paddle_decel": 3.0,
			"paddle_turn_decel": 4.0,
		}


class FakeSkillConfig:
	extends RefCounted

	func is_skill_equipped(skill_name: String) -> bool:
		return skill_name == "shield_kiting"

	func get_skill_cost(_skill_name: String) -> float:
		return 130.0

	func get_cooldown_seconds(_skill_name: String) -> float:
		return 12.0


class FakeSkillState:
	extends RefCounted

	var triggered_skill := ""

	func trigger_configured_cooldown(skill_name: String, _time_now: int, _skill_config: Object) -> void:
		triggered_skill = skill_name

	func get_configured_cooldown_remaining(_skill_name: String, _time_now: int, _skill_config: Object) -> float:
		return 0.0


class FakeAudio:
	extends RefCounted

	var wind_up_playing := false
	var stop_calls := 0

	func play_shield_kiting_wind_up() -> void:
		wind_up_playing = true

	func stop_shield_kiting_wind_up() -> void:
		wind_up_playing = false
		stop_calls += 1

	func is_shield_kiting_wind_up_playing() -> bool:
		return wind_up_playing


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_loot_phase_closes_ball_gate()
	_verify_loot_phase_blocks_new_activation()
	_verify_live_windup_releases_when_ball_gate_closes()

	if _failures.is_empty():
		print("smasher_shield_kiting_victory_loot_freeze_smoke: ok")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _verify_loot_phase_closes_ball_gate() -> void:
	var builder: Object = PlayerControlConfigBuilder.new()
	var registry := FakeRegistry.new()

	# 대조군: 일반 랠리 프레임은 ball_active를 그대로 통과시켜야 한다.
	var rally_owner := FakeOwner.new()
	var rally_config: Dictionary = builder.build_config(rally_owner, registry, "smasher", FakeContextBuilder.new())
	_expect(
		bool(rally_config.get("ball_active", false)),
		"rally frame should keep the live ball gate open"
	)

	# 전리품 페이즈: owner.ball_active가 아직 true여도 게이트는 닫혀야 한다.
	var loot_owner := FakeOwner.new()
	loot_owner.victory_loot_phase_active = true
	var loot_config: Dictionary = builder.build_config(loot_owner, registry, "smasher", FakeContextBuilder.new())
	_expect(
		loot_owner.ball_active,
		"victory loot phase must still be reached with a stale live ball flag (repro precondition)"
	)
	_expect(
		not bool(loot_config.get("ball_active", true)),
		"victory loot phase must close the player-control ball gate"
	)


func _verify_loot_phase_blocks_new_activation() -> void:
	var builder: Object = PlayerControlConfigBuilder.new()
	var owner := FakeOwner.new()
	owner.victory_loot_phase_active = true
	var config: Dictionary = builder.build_config(owner, FakeRegistry.new(), "smasher", FakeContextBuilder.new())
	config["player_paddle_size"] = Vector2(155.0, 50.0)

	var shield_state := SmasherShieldKitingState.new()
	var deps: Dictionary = {
		"skill_config": FakeSkillConfig.new(),
		"skill_state": FakeSkillState.new(),
		"audio": FakeAudio.new(),
	}
	var now_msec: int = Time.get_ticks_msec()
	# 더블탭 발동 에지를 그대로 재현한다(첫 탭 -> 임계 안쪽 두 번째 탭).
	shield_state.last_action_edge_msec = now_msec - 120
	var activation: Dictionary = shield_state.update_input(
		{"action_pressed": true},
		now_msec,
		500.0,
		owner.player_pos,
		config,
		deps
	)

	_expect(
		not bool(activation.get("activated", false)),
		"Shield Kiting must not activate during the victory loot phase"
	)
	_expect(
		not bool(activation.get("movement_locked", false)),
		"Victory loot phase Shield Kiting input must not lock Smasher movement"
	)
	_expect(
		not shield_state.is_movement_locked(),
		"Victory loot phase must leave Shield Kiting without a movement-locking projectile"
	)


func _verify_live_windup_releases_when_ball_gate_closes() -> void:
	var shield_state := SmasherShieldKitingState.new()
	var audio := FakeAudio.new()
	var deps: Dictionary = {
		"skill_config": FakeSkillConfig.new(),
		"skill_state": FakeSkillState.new(),
		"audio": audio,
	}
	var live_config: Dictionary = {
		"ball_active": true,
		"ball_pos": Vector2(315.0, 410.0),
		"ball_vel": Vector2(0.0, 8.0),
		"player_paddle_size": Vector2(155.0, 50.0),
		"paddle_width": 155.0,
		"paddle_height": 50.0,
	}
	var now_msec: int = Time.get_ticks_msec()
	shield_state.last_action_edge_msec = now_msec - 120
	var activation: Dictionary = shield_state.update_input(
		{"action_pressed": true},
		now_msec,
		500.0,
		Vector2(302.5, 690.0),
		live_config,
		deps
	)
	_expect(bool(activation.get("activated", false)), "control leg: Shield Kiting should activate on a live rally frame")
	_expect(shield_state.is_movement_locked(), "control leg: Shield Kiting wind-up should lock movement while the ball is live")
	_expect(audio.wind_up_playing, "control leg: Shield Kiting wind-up loop should be playing")

	# 매치 종료 득점 -> 스코어보드 -> 전리품 페이즈. 볼 패스는 다시 돌지 않으므로
	# 다음 플레이어-컨트롤 프레임에서 잠금이 풀리지 않으면 영구 정지가 된다.
	var loot_config: Dictionary = live_config.duplicate()
	loot_config["ball_active"] = false
	var loot_result: Dictionary = shield_state.update_input(
		{"action_pressed": false},
		now_msec + 16,
		float(activation.get("special_gauge", 370.0)),
		Vector2(302.5, 690.0),
		loot_config,
		deps
	)

	_expect(
		not bool(loot_result.get("movement_locked", true)),
		"closed ball gate must report Shield Kiting movement as unlocked"
	)
	_expect(
		not shield_state.is_movement_locked(),
		"stalled Shield Kiting wind-up must release its movement lock when the ball path is frozen"
	)
	_expect(
		shield_state.projectile.is_empty(),
		"stalled Shield Kiting projectile must be cleared when the ball path is frozen"
	)
	_expect(
		audio.stop_calls >= 1 and not audio.wind_up_playing,
		"stalled Shield Kiting release must stop the wind-up loop SFX"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
