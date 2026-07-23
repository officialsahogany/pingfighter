extends SceneTree

# 플레이필드 클립 픽셀 봉인(비헤드리스): 구조 씰(clip_contents/부모/rect)이 GREEN
# 이어도 실제 클립이 안 되면 잡지 못하는 공허-GREEN을 막는다. 오브를 왼쪽
# 가장자리에 두고 렌더해 좌측 레터박스(x < game_offset)의 시안 픽셀이
# 클립 OFF에서는 존재(bleed 감지 가능), 클립 ON에서는 0인지 실측한다.
# 헤드리스에서는 뷰포트 픽셀 판독 불가 → skip. 로컬/디스플레이 있는 게이트에서만 실행.
# (CLIP_CHILDREN 마스크는 구조 GREEN이지만 픽셀은 안 잘렸다 — 이 씰이 그걸 잡는다.)

const SmasherPlasmaFxHost := preload("res://scripts/characters/smasher_plasma_fx_host.gd")

const RENDER_SCALE := 1.18
const GAME_OFFSET := Vector2(190.0, 35.0)
const PLAYFIELD_EDGE_ORB := Vector2(8.0, 300.0)  # 왼쪽 가장자리 아주 근처(레터박스 침범 유발)
const VIEW := Vector2i(1180, 900)

var _failed := false
var _host: Node = null


func _init() -> void:
	get_root().size = VIEW
	RenderingServer.set_default_clear_color(Color(0.0, 0.0, 0.0, 1.0))
	_host = SmasherPlasmaFxHost.new()
	_host.name = "SmasherPlasmaFxHost"
	get_root().add_child(_host)
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name().to_lower().find("headless") >= 0:
		print("smasher_plasma_clip_letterbox_pixel_smoke: pixel QA skipped under headless display server")
		print("smasher_plasma_clip_letterbox_pixel_smoke: ok")
		quit(0)
		return

	# 클립 없이: 레터박스에 새어나가는 픽셀이 존재해야 테스트가 유효(bleed 감지 가능).
	# 비헤드리스(윈도우드 QA)인데 뷰포트 텍스처를 못 얻으면 fail-closed — 실제
	# 판정 없이 성공 종료하면 클립 회귀를 조용히 통과시킨다.
	var uncl_lb: int = await _render_and_count_letterbox(false)
	_expect(uncl_lb >= 0, "windowed QA must obtain a viewport texture to verify the clip (fail-closed on missing texture)")
	if uncl_lb < 0:
		quit(1)
		return
	_expect(uncl_lb > 0, "unclipped orb near the left edge must bleed into the letterbox (else the test can't detect a clip regression)")

	# 클립 켜면: 좌측 레터박스 시안 픽셀 0.
	var clip_lb: int = await _render_and_count_letterbox(true)
	_expect(clip_lb == 0, "clipped plasma orb must leave ZERO lit pixels in the left letterbox (got %d)" % clip_lb)

	_host.queue_free()
	if _failed:
		quit(1)
		return
	print("smasher_plasma_clip_letterbox_pixel_smoke: ok")
	quit(0)


func _render_and_count_letterbox(clip_on: bool) -> int:
	var screen_pos: Vector2 = GAME_OFFSET + PLAYFIELD_EDGE_ORB * RENDER_SCALE
	var state := {
		"phase_active": true,
		"phase": "wave",
		"pos": screen_pos,
		"render_scale": RENDER_SCALE,
		"radius": 130.0,
		"intensity": 1.0,
		"enraged": false,
		"quality_scale": 1.0,
	}
	if clip_on:
		state["clip_position"] = GAME_OFFSET
	_host.sync_state(state, true)
	for _i in range(6):
		await process_frame
	var tex := get_root().get_texture()
	if tex == null:
		return -1
	var img := tex.get_image()
	if img == null or img.is_empty():
		return -1
	var count := 0
	var x_max: int = mini(int(GAME_OFFSET.x), img.get_width())
	for y in range(0, img.get_height(), 2):
		for x in range(0, x_max, 1):
			var c := img.get_pixel(x, y)
			if c.r + c.g + c.b > 0.15:
				count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
