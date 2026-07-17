extends SceneTree

# 신비의 주사위 패들 오라 windowed 픽셀 QA 하니스.
#
# 헤드리스 스모크는 상태·배선만 봉인할 수 있고 실제 픽셀은 보지 못한다 —
# 이 하니스는 창모드 실렌더에서 실 호스트(MysticDicePaddleFxHost)를 중간
# 진행 상태로 동기화해 뷰포트를 캡처하고, 오라 영역의 발광 픽셀 수를
# 단언한 뒤 증적 PNG를 백업 사이드카 디렉터리에 남긴다.
#
# 실행(창모드 — --headless 금지):
#   Godot_console.exe --path godot -s res://tools/mystic_dice_paddle_aura_qa.gd

const MysticDicePaddleFxHost := preload("res://scripts/characters/mystic_dice_paddle_fx_host.gd")

const EVIDENCE_DIR := "C:/Users/woduq/bosspong_backups"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	# 기본 clear color(회색 0.3)는 발광 문턱을 전 픽셀 통과시켜 QA를 공허하게
	# 만든다 — 검정으로 강제해 오라 픽셀만 계수되게 한다.
	RenderingServer.set_default_clear_color(Color.BLACK)
	var host: Control = MysticDicePaddleFxHost.new()
	root.add_child(host)
	var screen_center := Vector2(480.0, 520.0)
	host.sync_state({
		"active": true,
		"screen_pos": screen_center,
		"clip_position": Vector2(40.0, 10.0),
		"clip_size": Vector2(950.0, 700.0),
		"paddle_size": Vector2(155.0, 50.0),
		"render_scale": 1.25,
		"elapsed_seconds": 1.20,
		"intensity": 0.60,
	}, true)
	for _frame_index: int in range(8):
		await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("mystic_dice_paddle_aura_qa: viewport capture failed")
		quit(1)
		return
	# 오라 영역(패들 중심 주변 220px 박스)의 발광 픽셀: 검정 배경보다 밝은
	# 유채색 픽셀 수를 센다.
	# 프로젝트 stretch 매핑과 무관하게: 씬에는 호스트 하나뿐이므로 전체
	# 이미지의 발광 픽셀 = 오라 픽셀이다. ①오라가 실제로 그려졌고(≥200px)
	# ②전면 오염이 아니며(<20% — 배경/스트레치 오염이면 전 화면 발광)
	# ③단일 클러스터(오라 bbox 밖 발광 근사 0)임을 단언한다.
	var lit_pixels := 0
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	var centroid := Vector2.ZERO
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var pixel: Color = image.get_pixel(x, y)
			if pixel.r + pixel.g + pixel.b > 0.18:
				lit_pixels += 1
				centroid += Vector2(x, y)
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if lit_pixels > 0:
		centroid /= float(lit_pixels)
	var total_pixels: int = image.get_width() * image.get_height()
	var timestamp := Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var evidence_path := "%s/qa_mystic_dice_paddle_aura_%s.png" % [EVIDENCE_DIR, timestamp]
	# 증적 저장은 fail-closed: 디렉터리 부재/권한/충돌로 PNG가 없으면 QA
	# 자체를 실패시킨다(증적 없는 ok 금지).
	DirAccess.make_dir_recursive_absolute(EVIDENCE_DIR)
	var save_error := image.save_png(evidence_path)
	print("mystic_dice_paddle_aura_qa: lit_pixels=%d/%d bbox=(%d,%d..%d,%d) centroid=%s evidence=%s save=%d" % [lit_pixels, total_pixels, min_x, min_y, max_x, max_y, str(centroid.round()), evidence_path, save_error])
	if save_error != OK or not FileAccess.file_exists(evidence_path):
		push_error("mystic_dice_paddle_aura_qa: evidence PNG save failed (error=%d)" % save_error)
		quit(1)
		return
	var evidence_bytes := FileAccess.get_file_as_bytes(evidence_path)
	if evidence_bytes.is_empty():
		push_error("mystic_dice_paddle_aura_qa: evidence PNG is empty on disk")
		quit(1)
		return
	print("mystic_dice_paddle_aura_qa: evidence_md5=%s bytes=%d" % [FileAccess.get_md5(evidence_path), evidence_bytes.size()])
	if lit_pixels < 200:
		push_error("mystic_dice_paddle_aura_qa: aura has too few lit pixels (%d)" % lit_pixels)
		quit(1)
		return
	if lit_pixels * 5 > total_pixels:
		push_error("mystic_dice_paddle_aura_qa: over 20%% of the frame lights up (%d/%d) — background contamination voids the QA" % [lit_pixels, total_pixels])
		quit(1)
		return
	var bbox_area: int = maxi(1, (max_x - min_x + 1) * (max_y - min_y + 1))
	if bbox_area * 3 > total_pixels:
		push_error("mystic_dice_paddle_aura_qa: lit bbox spans over a third of the frame — not a localized paddle aura")
		quit(1)
		return
	print("mystic_dice_paddle_aura_qa: ok")
	quit(0)
