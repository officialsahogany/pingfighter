extends RefCounted

# 승리 전리품 페이즈: 매치 승리 스코어보드가 끝난 뒤 결과화면으로 바로 넘어가지
# 않고, 패배한 보스 몸에서 보상 상자를 떨어뜨려 플레이어가 패들로 주워 열게 하는
# 인게임 페이즈. 모든 상자를 열면 finish_callback(결과화면 진입)을 1회 호출한다.
# 보상 롤/지급은 결과화면 상자 이벤트가 쓰던 stage_clear_reward_resolver를 그대로
# 재사용하므로 확률·롤옵션·시네마틱 계약이 결과화면 시절과 동일하다.

const ProjectResourceLoader := preload("res://scripts/resources/project_resource_loader.gd")
const StageClearRewardPlanBuilder := preload("res://scripts/core/stage_clear_result_reward_plan_builder.gd")

const FIELD_WIDTH := 760.0
const FIELD_HEIGHT := 750.0

const BOX_KIND_NORMAL := "normal"
const BOX_KIND_ADVANCED := "advanced"
const BOX_KIND_GUARANTEED_MYTHIC := "guaranteed_mythic"
const LEGACY_BOX_KIND_MYTHIC := "mythic"

# 시트 계약은 stage_clear_result_box_draw_helper와 동일(4x4 그리드 · 256px 셀 ·
# 16프레임, common 시트는 12프레임까지만 안전).
const BOX_SHEET_FRAME_COUNT := 16
const BOX_SHEET_GRID_COLS := 4
const BOX_SHEET_CELL_SIZE := Vector2(256.0, 256.0)
const BOX_COMMON_SAFE_LAST_FRAME := 12
const BOX_MYTHIC_SAFE_LAST_FRAME := BOX_SHEET_FRAME_COUNT - 1
const BOX_FRAME_ASSET_GUARD_SCALE := 0.90
const BOX_DRAW_SIZE := 78.0 / BOX_FRAME_ASSET_GUARD_SCALE

const BOX_SHEET_PATHS := {
	BOX_KIND_NORMAL: "res://assets/sprites/result_boxes/result_box_common_open_16f.png",
	BOX_KIND_ADVANCED: "res://assets/sprites/result_boxes/result_box_mythic_open_16f.png",
	BOX_KIND_GUARANTEED_MYTHIC: "res://assets/sprites/result_boxes/result_box_guaranteed_mythic_open_16f.png",
}

# 인트로: 스코어보드의 파워로스 진동이 끝난 뒤, 보스가 힘을 잃고 패배 라투디를
# 0프레임부터 재생하는 구간. 상자 드랍은 이 구간이 끝난 뒤에 시작한다.
const INTRO_DEFEAT_SEC := 1.6

# 낙하/안착/개봉 물리 상수. px/frame 계열은 fps_scale(delta * 60) 곱으로 적분한다.
# 드랍은 보스 몸에서 살짝 위로 떠올랐다가(팝업) 포물선으로 떨어지고, 바닥에서
# 짧게 튕긴 뒤 완전히 안착해야 픽업(개봉)이 가능하다.
const DROP_INTERVAL_SEC := 0.55
const DROP_GRAVITY_PX_PER_FRAME2 := 0.42
const DROP_MAX_FALL_SPEED_PX_PER_FRAME := 11.0
const DROP_POP_SPEED_PX_PER_FRAME := 5.4
const DROP_BOUNCE_RESTITUTION := 0.38
const DROP_BOUNCE_MIN_SPEED_PX_PER_FRAME := 2.6
const DROP_MAX_BOUNCES := 2
const DROP_SWAY_SPEED := 3.4
const DROP_SWAY_AMOUNT_PX := 10.0
const DROP_X_SPREAD_PX := 96.0
const DROP_X_MARGIN_PX := 70.0
const REST_Y := 692.0
const REST_BOB_AMPLITUDE_PX := 3.0
const REST_BOB_SPEED := 2.2
const PICKUP_HALF_SIZE := Vector2(30.0, 26.0)
const OPEN_DURATION_SEC := 0.60
const OPEN_GRANT_PROGRESS := 0.55
const FINISH_LINGER_SEC := 0.75

# 보스 defeat 프레임 클럭: battle_draw_actor_result_context의 defeat 시트 상수
# 미러. 최종 승리 스코어보드는 파워로스 진동만 틀므로, 슬럼프는 전리품 인트로
# 에서 0프레임부터 재생된다.
const BOSS_RESULT_FRAME_SPEED := 0.18
const BOSS_RESULT_FRAME_COUNT := 8
const BOSS_STAGE2_DEFEAT_FRAME_SPEED := 0.025
const BOSS_STAGE2_DEFEAT_FRAME_COUNT := 64

const BOX_PHASE_PENDING := "pending"
const BOX_PHASE_DROP := "drop"
const BOX_PHASE_REST := "rest"
const BOX_PHASE_OPENING := "opening"
const BOX_PHASE_DONE := "done"

var active: bool = false
var elapsed_sec: float = 0.0
# 보스 defeat 클럭: 최종 승리 스코어보드는 defeat 대신 파워로스 진동을 재생하므로
# (battle_draw_actor_result_context의 pending_game_reset 분기), 패배 라투디는
# 전리품 인트로에서 elapsed_sec 기준 0프레임부터 새로 재생하는 것이 설계 의도다.
var boxes: Array = []
var collected_rewards: Array = []
var finish_callback: Callable = Callable()
var _finish_timer: float = -1.0
var _finish_fired: bool = false
var _owner: Object = null
var _registry: Object = null
var _current_stage: int = 1
var _plan_builder: Object = StageClearRewardPlanBuilder.new()
var _reward_resolver: Object = null


func start(
	owner: Object,
	registry: Object,
	player_score: int,
	boss_score: int,
	new_finish_callback: Callable
) -> bool:
	if active:
		return false
	if player_score <= boss_score:
		return false
	var plan: Dictionary = _plan_builder.build_reward_plan(player_score, boss_score)
	var plan_boxes_value: Variant = plan.get("boxes", [])
	var plan_boxes: Array = plan_boxes_value if plan_boxes_value is Array else []
	if plan_boxes.is_empty():
		return false
	_owner = owner
	_registry = registry
	_current_stage = int(_get_owner_value(owner, "current_stage", 1))
	_ensure_reward_resolver()
	boxes = _build_boxes(plan_boxes, owner)
	_prewarm_box_textures()
	collected_rewards = []
	finish_callback = new_finish_callback
	_finish_timer = -1.0
	_finish_fired = false
	elapsed_sec = 0.0
	active = true
	_write_owner_state(owner)
	return true


func reset(owner: Object = null) -> void:
	active = false
	elapsed_sec = 0.0
	boxes = []
	collected_rewards = []
	finish_callback = Callable()
	_finish_timer = -1.0
	_finish_fired = false
	var flag_owner: Object = owner if owner != null else _owner
	_owner = null
	_registry = null
	_write_owner_state(flag_owner)


func is_active() -> bool:
	return active


func update(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(0.0, delta)
	elapsed_sec += safe_delta
	var fps_scale: float = safe_delta * 60.0
	var pickup_consumed_this_frame: bool = false
	var player_rect: Rect2 = _get_player_rect(_owner)
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		match str(box.get("phase", BOX_PHASE_PENDING)):
			BOX_PHASE_PENDING:
				if elapsed_sec >= float(box.get("drop_at_sec", 0.0)):
					box["phase"] = BOX_PHASE_DROP
			BOX_PHASE_DROP:
				_advance_drop(box, fps_scale)
			BOX_PHASE_REST:
				if not pickup_consumed_this_frame and _is_box_picked_up(box, player_rect):
					pickup_consumed_this_frame = true
					_begin_opening(box)
			BOX_PHASE_OPENING:
				var open_progress: float = float(box.get("open_progress", 0.0)) + safe_delta / OPEN_DURATION_SEC
				box["open_progress"] = open_progress
				if open_progress >= OPEN_GRANT_PROGRESS and not bool(box.get("reward_granted", false)):
					box["reward_granted"] = true
					_grant_box_reward(box)
				if open_progress >= 1.0:
					box["phase"] = BOX_PHASE_DONE
	_update_finish(safe_delta)


func has_actor_draw_context() -> bool:
	return active


func get_actor_draw_context() -> Dictionary:
	if not active:
		return {}
	# 스코어보드 파워로스 진동 직후, 힘을 잃는 슬럼프를 0프레임부터 재생하고
	# 마지막 프레임에서 홀드한다(인트로 -> 드랍 구간 내내 쓰러진 채 유지).
	var frame: int = mini(BOSS_RESULT_FRAME_COUNT - 1, int(floor(elapsed_sec / BOSS_RESULT_FRAME_SPEED)))
	var stage2_defeat_frame: int = mini(
		BOSS_STAGE2_DEFEAT_FRAME_COUNT - 1,
		int(floor(elapsed_sec / BOSS_STAGE2_DEFEAT_FRAME_SPEED))
	)
	return {
		"boss_defeat_active": true,
		"boss_result_frame": frame,
		"boss_defeat_frame": stage2_defeat_frame if _current_stage == 2 else frame,
	}


func draw(canvas: CanvasItem, shake_offset: Vector2 = Vector2.ZERO) -> void:
	if canvas == null or not active:
		return
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var box: Dictionary = box_value
		var phase: String = str(box.get("phase", BOX_PHASE_PENDING))
		if phase == BOX_PHASE_PENDING or phase == BOX_PHASE_DONE:
			continue
		_draw_box(canvas, box, phase, shake_offset)


func get_status_for_tests() -> Dictionary:
	return {
		"active": active,
		"elapsed": elapsed_sec,
		"box_count": boxes.size(),
		"box_phases": boxes.map(func(box): return str((box as Dictionary).get("phase", "")) if box is Dictionary else ""),
		"collected_reward_count": collected_rewards.size(),
		"finish_fired": _finish_fired,
		"finish_timer": _finish_timer,
	}


func set_reward_resolver_for_test(reward_resolver: Object) -> void:
	_reward_resolver = reward_resolver


func force_box_rest_for_test(box_index: int) -> void:
	if box_index < 0 or box_index >= boxes.size():
		return
	var box_value: Variant = boxes[box_index]
	if not (box_value is Dictionary):
		return
	var box: Dictionary = box_value
	box["phase"] = BOX_PHASE_REST
	var pos: Vector2 = _get_vector2(box.get("pos", Vector2.ZERO), Vector2.ZERO)
	box["pos"] = Vector2(pos.x, REST_Y)


func _build_boxes(plan_boxes: Array, owner: Object) -> Array:
	var origin: Vector2 = _get_boss_drop_origin(owner)
	var built: Array = []
	var count: int = plan_boxes.size()
	for index in range(count):
		var plan_box_value: Variant = plan_boxes[index]
		var kind: String = BOX_KIND_NORMAL
		if plan_box_value is Dictionary:
			kind = _normalize_box_kind(str((plan_box_value as Dictionary).get("kind", BOX_KIND_NORMAL)))
		var spread_step: float = 0.0
		if count > 1:
			spread_step = (float(index) - float(count - 1) * 0.5) * DROP_X_SPREAD_PX
		var rest_x: float = clampf(
			origin.x + spread_step,
			DROP_X_MARGIN_PX,
			FIELD_WIDTH - DROP_X_MARGIN_PX
		)
		built.append({
			"kind": kind,
			"pos": Vector2(origin.x, origin.y),
			"base_x": rest_x,
			"fall_speed": -DROP_POP_SPEED_PX_PER_FRAME,
			"bounce_count": 0,
			"phase": BOX_PHASE_PENDING,
			"drop_at_sec": INTRO_DEFEAT_SEC + float(index) * DROP_INTERVAL_SEC,
			"sway_phase": float(index) * 1.7,
			"open_progress": 0.0,
			"reward_granted": false,
		})
	return built


func _advance_drop(box: Dictionary, fps_scale: float) -> void:
	var fall_speed: float = float(box.get("fall_speed", 0.0))
	fall_speed = minf(
		DROP_MAX_FALL_SPEED_PX_PER_FRAME,
		fall_speed + DROP_GRAVITY_PX_PER_FRAME2 * fps_scale
	)
	box["fall_speed"] = fall_speed
	var pos: Vector2 = _get_vector2(box.get("pos", Vector2.ZERO), Vector2.ZERO)
	var next_y: float = pos.y + fall_speed * fps_scale
	var base_x: float = float(box.get("base_x", pos.x))
	var height_ratio: float = clampf(1.0 - (next_y / maxf(1.0, REST_Y)), 0.0, 1.0)
	var sway: float = sin(elapsed_sec * DROP_SWAY_SPEED + float(box.get("sway_phase", 0.0))) * DROP_SWAY_AMOUNT_PX * height_ratio
	var origin_x: float = pos.x
	var settle: float = clampf(next_y / maxf(1.0, REST_Y), 0.0, 1.0)
	var next_x: float = lerpf(origin_x, base_x + sway, minf(1.0, settle * 1.6))
	if next_y >= REST_Y and fall_speed > 0.0:
		# 바닥 접촉: 남은 낙하 에너지가 있으면 짧게 튕기고, 다 소진되면 완전
		# 안착(REST) — 픽업(개봉)은 안착 후에만 가능하다.
		var bounce_count: int = int(box.get("bounce_count", 0))
		if fall_speed >= DROP_BOUNCE_MIN_SPEED_PX_PER_FRAME and bounce_count < DROP_MAX_BOUNCES:
			box["bounce_count"] = bounce_count + 1
			box["fall_speed"] = -fall_speed * DROP_BOUNCE_RESTITUTION
			box["pos"] = Vector2(next_x, REST_Y)
			return
		box["phase"] = BOX_PHASE_REST
		box["pos"] = Vector2(base_x, REST_Y)
		return
	box["pos"] = Vector2(next_x, next_y)


func _is_box_picked_up(box: Dictionary, player_rect: Rect2) -> bool:
	if player_rect.size.x <= 0.0 or player_rect.size.y <= 0.0:
		return false
	var pos: Vector2 = _get_vector2(box.get("pos", Vector2.ZERO), Vector2.ZERO)
	var box_rect := Rect2(pos - PICKUP_HALF_SIZE, PICKUP_HALF_SIZE * 2.0)
	return box_rect.intersects(player_rect)


func _begin_opening(box: Dictionary) -> void:
	box["phase"] = BOX_PHASE_OPENING
	box["open_progress"] = 0.0
	_play_box_open_audio()


func _grant_box_reward(box: Dictionary) -> void:
	if _reward_resolver == null:
		return
	var kind: String = str(box.get("kind", BOX_KIND_NORMAL))
	var pos: Vector2 = _get_vector2(box.get("pos", Vector2.ZERO), Vector2.ZERO)
	var reward_value: Variant = _reward_resolver.roll_reward(kind, _owner, _registry)
	if not (reward_value is Dictionary):
		return
	var reward: Dictionary = reward_value
	reward["pickup_position"] = pos
	var reward_type: String = str(reward.get("type", ""))
	if reward_type == "passive" or reward_type == "mythic":
		# 결과화면 상자와 동일하게 전설/신화급 장비는 인게임 획득 시네마틱으로 리빌.
		reward["show_acquisition_cinematic"] = true
	if reward_type == "starpoint":
		# 인게임 필드 스타포인트와 동일하게 즉시 퍽 선택을 연다.
		reward["defer_choice_open"] = false
	if reward_type == "active" and _try_collect_active_reward(reward, pos):
		collected_rewards.append(reward)
		return
	if _grant_reward_through_resolver(reward):
		collected_rewards.append(reward)
		return
	# 리졸버 지급 실패: allow_overflow조차 can_store_item 게이트(동일 액티브 효과
	# 진행 중 — 예: 자기장 지속 중 자기장 보상)보다 뒤에 검사되므로 실전에서
	# 도달 가능한 실패다. 보상 소실 금지 — 확정 스타포인트로 대체 지급한다.
	var fallback_reward: Dictionary = _build_starpoint_fallback_reward(reward)
	if _grant_reward_through_resolver(fallback_reward):
		collected_rewards.append(fallback_reward)
		return
	# 스타포인트 인프라마저 없으면 지급 수단이 없다 — 소실을 기록만 하고 상자
	# 완료는 유지한다(전리품 페이즈 소프트락 방지).
	reward["grant_failed"] = true
	collected_rewards.append(reward)


func _grant_reward_through_resolver(reward: Dictionary) -> bool:
	var summary_value: Variant = _reward_resolver.grant_rewards([reward], _owner, _registry)
	if not (summary_value is Dictionary):
		return false
	return int((summary_value as Dictionary).get("granted", 0)) > 0


func _build_starpoint_fallback_reward(original_reward: Dictionary) -> Dictionary:
	# 리졸버의 starpoint 보상 dict 형태를 미러링한다(_roll_starpoint_reward 계약).
	return {
		"type": "starpoint",
		"label": "★ 1",
		"amount": 1,
		"defer_choice_open": false,
		"pickup_position": original_reward.get("pickup_position", Vector2.ZERO),
		"fallback_from_type": str(original_reward.get("type", "")),
		"fallback_from_item_name": str(original_reward.get("item_name", "")),
	}


func _try_collect_active_reward(reward: Dictionary, pos: Vector2) -> bool:
	# 액티브 아이템은 필드 픽업 라우터를 태워 기존 획득 팝업/사운드/슬롯 규칙을
	# 그대로 재사용한다. 슬롯 만석 등으로 수납이 실패하면 false를 돌려 리졸버
	# 그랜트(allow_overflow) 경로가 이어받는다 — 필드 아이템으로 남기면 결과화면
	# 전환(물리 게이트) + 다음 스테이지 field_spawn_controller 리셋에 보상이
	# 소실되므로 절대 필드 스폰으로 대체하지 말 것.
	var item_name: String = str(reward.get("item_name", ""))
	if item_name == "":
		return false
	var active_item_runtime: Object = _get_registry_instance("active_item_runtime")
	if active_item_runtime == null or not active_item_runtime.has_method("collect_item_by_name"):
		return false
	return bool(active_item_runtime.collect_item_by_name(item_name, pos, _owner, _registry))


func _update_finish(safe_delta: float) -> void:
	if _finish_fired:
		return
	if not _all_boxes_done():
		_finish_timer = -1.0
		return
	if _finish_timer < 0.0:
		_finish_timer = FINISH_LINGER_SEC
		return
	_finish_timer -= safe_delta
	if _finish_timer > 0.0:
		return
	_finish_fired = true
	active = false
	_write_owner_state(_owner)
	var callback: Callable = finish_callback
	finish_callback = Callable()
	if callback.is_valid():
		callback.call()


func _all_boxes_done() -> bool:
	if boxes.is_empty():
		return true
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		if str((box_value as Dictionary).get("phase", BOX_PHASE_PENDING)) != BOX_PHASE_DONE:
			return false
	return true


func _draw_box(canvas: CanvasItem, box: Dictionary, phase: String, shake_offset: Vector2) -> void:
	var pos: Vector2 = _get_vector2(box.get("pos", Vector2.ZERO), Vector2.ZERO)
	var kind: String = str(box.get("kind", BOX_KIND_NORMAL))
	var draw_center: Vector2 = pos + shake_offset
	if phase == BOX_PHASE_REST:
		draw_center.y += sin(elapsed_sec * REST_BOB_SPEED + float(box.get("sway_phase", 0.0))) * REST_BOB_AMPLITUDE_PX
	elif phase == BOX_PHASE_OPENING:
		var open_progress: float = float(box.get("open_progress", 0.0))
		if open_progress < OPEN_GRANT_PROGRESS:
			var shake_intensity: float = 1.0 - open_progress / OPEN_GRANT_PROGRESS
			draw_center += Vector2(
				sin(elapsed_sec * 30.0) * 3.2 * shake_intensity,
				cos(elapsed_sec * 39.0) * 1.4 * shake_intensity
			)
	_draw_box_shadow(canvas, box, pos, shake_offset)
	var texture: Texture2D = ProjectResourceLoader.get_cached_texture(str(BOX_SHEET_PATHS.get(kind, BOX_SHEET_PATHS[BOX_KIND_NORMAL])))
	if texture == null:
		var fallback_rect := Rect2(draw_center - Vector2(28.0, 22.0), Vector2(56.0, 44.0))
		canvas.draw_rect(fallback_rect, Color(0.62, 0.46, 0.22, 0.95))
		canvas.draw_rect(fallback_rect, Color(0.95, 0.82, 0.42, 0.9), false, 2.0)
		return
	var frame: int = 0
	if phase == BOX_PHASE_OPENING:
		var safe_last_frame: int = BOX_COMMON_SAFE_LAST_FRAME if kind == BOX_KIND_NORMAL else BOX_MYTHIC_SAFE_LAST_FRAME
		frame = clampi(
			int(floor(float(box.get("open_progress", 0.0)) * float(safe_last_frame + 1))),
			0,
			safe_last_frame
		)
	var frame_row: int = floori(float(frame) / float(BOX_SHEET_GRID_COLS))
	var src_rect := Rect2(
		Vector2(
			float(frame % BOX_SHEET_GRID_COLS) * BOX_SHEET_CELL_SIZE.x,
			float(frame_row) * BOX_SHEET_CELL_SIZE.y
		),
		BOX_SHEET_CELL_SIZE
	)
	var dest_rect := Rect2(draw_center - Vector2(BOX_DRAW_SIZE, BOX_DRAW_SIZE) * 0.5, Vector2(BOX_DRAW_SIZE, BOX_DRAW_SIZE))
	canvas.draw_texture_rect_region(texture, dest_rect, src_rect)


func _draw_box_shadow(canvas: CanvasItem, box: Dictionary, pos: Vector2, shake_offset: Vector2) -> void:
	var height_ratio: float = clampf(pos.y / maxf(1.0, REST_Y), 0.0, 1.0)
	var shadow_scale: float = 0.35 + 0.65 * height_ratio
	var shadow_center := Vector2(pos.x, REST_Y + 26.0) + shake_offset
	var shadow_size := Vector2(46.0 * shadow_scale, 10.0 * shadow_scale)
	canvas.draw_rect(
		Rect2(shadow_center - shadow_size * 0.5, shadow_size),
		Color(0.0, 0.0, 0.0, 0.28 * shadow_scale)
	)


func _prewarm_box_textures() -> void:
	var seen_kinds := {}
	for box_value in boxes:
		if not (box_value is Dictionary):
			continue
		var kind: String = str((box_value as Dictionary).get("kind", BOX_KIND_NORMAL))
		if seen_kinds.has(kind):
			continue
		seen_kinds[kind] = true
		ProjectResourceLoader.load_imported_texture(
			str(BOX_SHEET_PATHS.get(kind, BOX_SHEET_PATHS[BOX_KIND_NORMAL])),
			"Missing victory loot box sheet at %s",
			"Failed to load victory loot box sheet at %s"
		)


func _ensure_reward_resolver() -> void:
	if _reward_resolver != null:
		return
	_reward_resolver = load("res://scripts/core/stage_clear_reward_resolver.gd").new()


func _normalize_box_kind(kind: String) -> String:
	if kind == LEGACY_BOX_KIND_MYTHIC:
		return BOX_KIND_ADVANCED
	if kind == BOX_KIND_ADVANCED or kind == BOX_KIND_GUARANTEED_MYTHIC:
		return kind
	return BOX_KIND_NORMAL


func _get_boss_drop_origin(owner: Object) -> Vector2:
	var boss_pos: Vector2 = _get_vector2(_get_owner_value(owner, "boss_pos", Vector2(330.0, 25.0)), Vector2(330.0, 25.0))
	var boss_size: Vector2 = _get_vector2(_get_owner_value(owner, "boss_paddle_size", Vector2(100.0, 40.0)), Vector2(100.0, 40.0))
	return boss_pos + Vector2(boss_size.x * 0.5, boss_size.y + 10.0)


func _get_player_rect(owner: Object) -> Rect2:
	if owner == null:
		return Rect2()
	var player_pos: Vector2 = _get_vector2(_get_owner_value(owner, "player_pos", Vector2.ZERO), Vector2.ZERO)
	var width: float = float(_get_owner_value(owner, "player_paddle_width", 155.0))
	var height: float = float(_get_owner_value(owner, "player_paddle_height", 50.0))
	return Rect2(player_pos, Vector2(maxf(1.0, width), maxf(1.0, height)))


func _play_box_open_audio() -> void:
	var game_audio: Object = _get_registry_instance("game_audio")
	if game_audio != null and game_audio.has_method("play_result_box_open"):
		game_audio.play_result_box_open()


func _write_owner_state(owner: Object) -> void:
	if owner == null:
		return
	owner.set("victory_loot_phase_active", active)


func _get_registry_instance(key: String) -> Object:
	if _registry == null or not _registry.has_method("get_instance"):
		return null
	return _registry.get_instance(key)


func _get_owner_value(owner: Object, key: String, fallback: Variant) -> Variant:
	if owner == null:
		return fallback
	var value: Variant = owner.get(key)
	if value == null:
		return fallback
	return value


func _get_vector2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	return fallback
