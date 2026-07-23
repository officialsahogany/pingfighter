extends SceneTree

# 플레이필드 클립 봉인(WIP 파괴 후 재검수 회귀 수정):
# 플라즈마 오브 레이어가 좌/우 레터박스 필러까지 새어나가던 회귀.
# 호스트가 ①760x750 게임 영역으로 clip_contents 클립을 켜고 ②4개 오브 레이어를
# 클립 Control 아래로 넣으며 ③클립 월드 rect가 정확히 game_offset ..
# game_offset + 760x750*render_scale인지 = 실제 플레이필드인지, 그리고
# ④기존 좌표 계약(host.position/scale)이 보존되는지를 구조적으로 검증한다.
# (헤드리스는 클립 픽셀 판독 불가 → 구조 봉인. 실제 레터박스 0픽셀은 라이브 QA.)

const SmasherPlasmaFxHost := preload("res://scripts/characters/smasher_plasma_fx_host.gd")

const RENDER_SCALE := 1.18
const GAME_OFFSET := Vector2(190.0, 35.0)
const PLAYFIELD_ORB := Vector2(20.0, 300.0)  # 왼쪽 가장자리 근처(레터박스 침범 유발 위치)
const GAME_SIZE := Vector2(760.0, 750.0)

var _failed := false
var _host: Node = null


func _init() -> void:
	_host = SmasherPlasmaFxHost.new()
	_host.name = "SmasherPlasmaFxHost"
	get_root().add_child(_host)
	call_deferred("_run")


func _run() -> void:
	var screen_pos: Vector2 = GAME_OFFSET + PLAYFIELD_ORB * RENDER_SCALE
	_host.sync_state({
		"phase_active": true,
		"phase": "wave",
		"pos": screen_pos,
		"render_scale": RENDER_SCALE,
		"radius": 130.0,
		"intensity": 0.9,
		"enraged": false,
		"quality_scale": 1.0,
		"clip_position": GAME_OFFSET,
	}, true)
	await process_frame
	await process_frame

	var dbg: Dictionary = _host.get_debug_status()

	# (1) 클립 활성 + (2) 4레이어가 클립 아래로 재부모화
	_expect(bool(dbg.get("playfield_clip_active", false)), "playfield clip must be active (clip_contents on, size 760x750)")
	_expect(bool(dbg.get("layers_clipped_to_playfield", false)), "all 4 orb layers must be parented under the playfield clip")

	# (3) 클립 월드 rect == 정확한 플레이필드 (game_offset .. game_offset + 760x750*scale)
	var clip_origin: Vector2 = dbg.get("clip_world_origin", Vector2.ZERO)
	var clip_extent: Vector2 = dbg.get("clip_world_extent", Vector2.ZERO)
	var expected_extent: Vector2 = GAME_OFFSET + GAME_SIZE * RENDER_SCALE
	_expect(clip_origin.distance_to(GAME_OFFSET) < 0.05, "clip world origin must equal game_offset (got %s expected %s)" % [str(clip_origin), str(GAME_OFFSET)])
	_expect(clip_extent.distance_to(expected_extent) < 0.05, "clip world extent must equal the 760x750 playfield rect (got %s expected %s)" % [str(clip_extent), str(expected_extent)])

	# (4) 기존 좌표 계약 보존: host.position == screen orb pos, scale == render_scale
	_expect((_host as Node2D).position.distance_to(screen_pos) < 0.05, "host position must stay at the orb screen pos (coordinate seal): got %s expected %s" % [str((_host as Node2D).position), str(screen_pos)])
	_expect((_host as Node2D).scale.distance_to(Vector2(RENDER_SCALE, RENDER_SCALE)) < 0.001, "host scale must equal render_scale")

	# 클립 없이(clip_position 부재) 활성화하면 클립을 끄고 오브를 그대로 그린다(스모크/폴백 안전).
	_host.sync_state({
		"phase_active": true,
		"phase": "wave",
		"pos": screen_pos,
		"render_scale": RENDER_SCALE,
		"radius": 130.0,
		"intensity": 0.9,
		"quality_scale": 1.0,
	}, true)
	await process_frame
	var dbg2: Dictionary = _host.get_debug_status()
	_expect(not bool(dbg2.get("playfield_clip_active", true)), "clip must disable when clip_position is absent (fallback keeps orb unclipped)")

	# 실제 레터박스 0픽셀(클립 효능)은 비헤드리스 픽셀 봉인
	# smasher_plasma_clip_letterbox_pixel_smoke가 담당한다(구조 씰은 헤드리스
	# 순수 — clip_contents/부모/월드rect 구조만 검증. 구조 GREEN인데 픽셀이
	# 새는 공허-GREEN은 픽셀 씰이 잡는다).
	_host.queue_free()
	if _failed:
		quit(1)
		return
	print("smasher_plasma_playfield_clip_smoke: ok")
	quit(0)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
