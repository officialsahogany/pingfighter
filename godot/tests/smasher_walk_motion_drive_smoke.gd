extends SceneTree

# 한미량 걷기 구동 씰.
#
# 1. 걷기 프레임은 시간이 아니라 "실제로 그려진 이동량"으로 진행한다.
# 2. GRT-012 부정 레그: 벽에 눌려 위치가 클램프되면(= 그려진 이동 0) 의도
#    속도가 최고속이어도 걷기 프레임은 진행하지 않는다.
# 3. 걷기 프레임 수·격자는 런타임 상수와 일치한다.
# 4. 대기·걷기·대쉬 시트는 같은 계열 경로 규약을 지킨다(시점은 코드로 단언할
#    수 없으므로 경로로 잠근다).

const PlayerActorAnimationState := preload("res://scripts/characters/player_actor_animation_state.gd")
const SpriteContextBuilder := preload("res://scripts/core/battle_update_effects_sprite_context_builder.gd")
const SmasherSpritePaths := preload("res://scripts/resources/battle_smasher_sprite_paths.gd")
const Stage1PlayerSpriteRenderer := preload("res://scripts/stages/stage1/stage1_player_sprite_renderer.gd")

const TICK := 1.0 / 60.0
const MAX_SPEED := 6.0  # player_movement_state.gd PADDLE_MAX_SPEED


func _init() -> void:
	_test_frame_count_parity()
	_test_sheet_family_path_contract()
	_test_full_speed_cadence_is_preserved()
	_test_half_speed_halves_the_cadence()
	_test_wall_clamped_walk_does_not_advance()
	_test_idle_does_not_advance_walk()
	_test_per_character_budget_preserves_each_cadence()
	_test_missing_budget_falls_back_to_constant()

	print("smasher_walk_motion_drive_smoke: ok")
	quit(0)


# --- helpers ---------------------------------------------------------------

func _walk_context(speed: float, x: float) -> Dictionary:
	return {
		"player_speed": speed,
		"dash_active": false,
		"player_has_sprite": true,
		"player_has_idle_sprite": true,
		"player_sprite_frame_count": SpriteContextBuilder.SMASHER_DIRECTIONAL_WALK_FRAME_COUNT,
		"player_sprite_animation_speed": SpriteContextBuilder.SMASHER_DIRECTIONAL_WALK_FRAME_SPEED,
		"player_pos": Vector2(x, 700.0),
		"player_walk_distance_per_frame": PlayerActorAnimationState.WALK_DISTANCE_PER_FRAME_PX,
	}


## Drive `ticks` physics ticks at `speed`, moving x by `travel_per_tick`.
## Returns how many times the walk frame advanced.
func _drive(state: Object, ticks: int, speed: float, travel_per_tick: float) -> int:
	var x := 0.0
	# Seed the odometer anchor so the first tick measures a real delta.
	state.update(TICK, _walk_context(speed, x))
	var previous: int = int(state.sprite_frame)
	var advances := 0
	for _i in range(ticks):
		x += travel_per_tick
		state.update(TICK, _walk_context(speed, x))
		if int(state.sprite_frame) != previous:
			advances += 1
			previous = int(state.sprite_frame)
	return advances


# --- assertions ------------------------------------------------------------

func _test_frame_count_parity() -> void:
	_expect(
		SpriteContextBuilder.SMASHER_DIRECTIONAL_WALK_FRAME_COUNT == 8,
		"smasher directional walk frame count must stay 8"
	)
	_expect(
		Stage1PlayerSpriteRenderer.DEFAULT_PLAYER_DIRECTIONAL_WALK_FRAME_COUNT
			== SpriteContextBuilder.SMASHER_DIRECTIONAL_WALK_FRAME_COUNT,
		"renderer fallback frame count must match the context builder (4x2 grid = 8 frames)"
	)
	# 18px 는 최고속에서 구 타이머와 같은 케이던스가 되도록 유도된 값이다.
	# 상수 셋 중 하나가 바뀌면 이 씰이 먼저 터져야 한다.
	_expect(
		is_equal_approx(
			PlayerActorAnimationState.WALK_DISTANCE_PER_FRAME_PX,
			MAX_SPEED * 60.0 * SpriteContextBuilder.SMASHER_DIRECTIONAL_WALK_FRAME_SPEED
		),
		"walk distance budget must stay derived from PADDLE_MAX_SPEED x fps x frame speed"
	)


func _test_sheet_family_path_contract() -> void:
	# 대기·대쉬·걷기가 같은 계열이어야 대기<->걷기 전환에서 정체성이 튀지 않는다.
	var family := "hanmiryang_rear_cloud_"
	_expect(
		String(SmasherSpritePaths.SMASHER_IDLE_SHEET_PATH).contains(family),
		"idle sheet must stay in the rear_cloud family"
	)
	_expect(
		String(SmasherSpritePaths.PLAYER_WALK_LEFT_SPRITE_PATH).contains(family)
			and String(SmasherSpritePaths.PLAYER_WALK_RIGHT_SPRITE_PATH).contains(family),
		"walk sheets must stay in the same family as idle/dash (no cross-family walk sheet)"
	)
	_expect(
		String(SmasherSpritePaths.PLAYER_DASH_LEFT_SPRITE_PATH).contains(family)
			and String(SmasherSpritePaths.PLAYER_DASH_RIGHT_SPRITE_PATH).contains(family),
		"dash sheets must stay in the rear_cloud family"
	)
	_expect(
		String(SmasherSpritePaths.PLAYER_WALK_LEFT_SPRITE_PATH).contains("4x2")
			and String(SmasherSpritePaths.PLAYER_WALK_RIGHT_SPRITE_PATH).contains("4x2"),
		"walk sheets must stay on the 4x2 (8 frame) grid the runtime constant expects"
	)


func _test_full_speed_cadence_is_preserved() -> void:
	# 최고속 6px/tick x 18틱 = 108px = 6프레임. 구 타이머(0.050s = 3틱마다 1장)와 동일.
	var state := PlayerActorAnimationState.new()
	var advances := _drive(state, 18, MAX_SPEED, MAX_SPEED)
	_expect(
		advances == 6,
		"full speed must keep the legacy cadence (18 ticks -> 6 frames), got %d" % advances
	)


func _test_half_speed_halves_the_cadence() -> void:
	# 핵심 수정: 절반 속도면 프레임도 절반만 진행해야 발이 바닥과 맞는다.
	var state := PlayerActorAnimationState.new()
	var advances := _drive(state, 18, MAX_SPEED * 0.5, MAX_SPEED * 0.5)
	_expect(
		advances == 3,
		"half speed must advance half as many frames (expected 3), got %d" % advances
	)


func _test_wall_clamped_walk_does_not_advance() -> void:
	# GRT-012 부정 레그: 의도 속도는 최고속인데 위치는 클램프되어 안 움직인다.
	var state := PlayerActorAnimationState.new()
	var advances := _drive(state, 60, MAX_SPEED, 0.0)
	_expect(
		advances == 0,
		"wall-clamped player must not advance walk frames (treadmill), got %d" % advances
	)
	_expect(
		int(state.sprite_frame) == 0,
		"wall-clamped player must rest on the neutral walk frame"
	)


func _test_idle_does_not_advance_walk() -> void:
	var state := PlayerActorAnimationState.new()
	var advances := _drive(state, 60, 0.0, 0.0)
	_expect(advances == 0, "idle player must not advance walk frames, got %d" % advances)
	_expect(int(state.idle_frame) > 0, "idle player must still animate the idle sheet")


## 캐릭터마다 최고속이 다르므로(스매셔 6.0 / 바이퍼·옵티머스 4.0) 예산도 달라야
## 각자의 "최고속 케이던스"가 보존된다. 하드코딩 18 이면 4.0 계열이 느려진다.
func _test_per_character_budget_preserves_each_cadence() -> void:
	var builder := SpriteContextBuilder.new()
	for probe in [
		{"character": "smasher", "top_speed": 6.0},
		{"character": "viper", "top_speed": 4.0},
		{"character": "soldier", "top_speed": 6.0},
	]:
		var character := String(probe["character"])
		var top_speed := float(probe["top_speed"])
		var frame_speed: float = 0.10 if character == "viper" else SpriteContextBuilder.SMASHER_DIRECTIONAL_WALK_FRAME_SPEED
		var budget: float = float(builder.call("_walk_distance_per_frame", character, frame_speed))
		var expected: float = top_speed * SpriteContextBuilder.MOVEMENT_REFERENCE_FPS * frame_speed
		_expect(
			is_equal_approx(budget, expected),
			"%s walk budget must be top_speed x fps x frame_speed (expected %f, got %f)" % [character, expected, budget]
		)
		# 예산 / 최고속 = 프레임당 틱 수. 구 타이머(frame_speed x 60)와 같아야 한다.
		_expect(
			is_equal_approx(budget / top_speed, frame_speed * SpriteContextBuilder.MOVEMENT_REFERENCE_FPS),
			"%s must keep its legacy full-speed cadence" % character
		)


## 예산 키가 없거나 0 이면 1px 예산으로 무너지지 않고 상수로 폴백해야 한다.
func _test_missing_budget_falls_back_to_constant() -> void:
	for bad_budget in [null, 0.0, -5.0]:
		var state := PlayerActorAnimationState.new()
		var x := 0.0
		var context := _walk_context(MAX_SPEED, x)
		if bad_budget == null:
			context.erase("player_walk_distance_per_frame")
		else:
			context["player_walk_distance_per_frame"] = float(bad_budget)
		state.update(TICK, context)
		var previous := int(state.sprite_frame)
		var advances := 0
		for _i in range(18):
			x += MAX_SPEED
			context = _walk_context(MAX_SPEED, x)
			if bad_budget == null:
				context.erase("player_walk_distance_per_frame")
			else:
				context["player_walk_distance_per_frame"] = float(bad_budget)
			state.update(TICK, context)
			if int(state.sprite_frame) != previous:
				advances += 1
				previous = int(state.sprite_frame)
		_expect(
			advances == 6,
			"budget %s must fall back to the 18px constant (expected 6 advances), got %d" % [str(bad_budget), advances]
		)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
